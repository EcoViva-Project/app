import 'package:flutter/foundation.dart';

import 'api_client.dart';

enum NotificationCategory { conquista, desafio, comunidade, recompensa, sistema }

class AppNotification {
  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.target,
    this.read = false,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String message;
  final String timeLabel;

  /// Rota do app relacionada à notificação (por exemplo `/recompensas`).
  final String? target;
  bool read;

  /// Para onde "Ver no aplicativo" leva.
  String get destination {
    final explicit = target;
    if (explicit != null && explicit.startsWith('/')) return explicit;
    switch (category) {
      case NotificationCategory.conquista:
        return '/conquistas';
      case NotificationCategory.desafio:
        return '/desafios';
      case NotificationCategory.comunidade:
        return '/comunidade';
      case NotificationCategory.recompensa:
        return '/recompensas';
      case NotificationCategory.sistema:
        return '/inicio';
    }
  }

  factory AppNotification.fromApi(Map<String, dynamic> json) {
    final rawCategory = json['category'] as String? ?? 'sistema';
    return AppNotification(
      id: json['id'].toString(),
      category: NotificationCategory.values.firstWhere(
        (value) => value.name == rawCategory,
        orElse: () => NotificationCategory.sistema,
      ),
      title: json['title'] as String? ?? 'Notificação',
      message: json['message'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
      target: json['target'] as String?,
      read: json['read'] as bool? ?? false,
    );
  }
}

/// Notificações do usuário (`/notifications`).
///
/// As alterações aparecem na hora e são desfeitas se a API recusar; nesse
/// caso [lastError] recebe a mensagem para a tela avisar.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final List<AppNotification> _notifications = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  String? _lastError;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  /// Erro da última carga da lista.
  String? get error => _error;

  /// Erro da última alteração (marcar, remover, limpar). Lido uma vez.
  String? takeLastError() {
    final message = _lastError;
    _lastError = null;
    return message;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/notifications');
      final list = (data['notifications'] as List?) ?? const [];
      _notifications
        ..clear()
        ..addAll(
          list.map(
            (item) => AppNotification.fromApi(item as Map<String, dynamic>),
          ),
        );
      _loaded = true;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _attempt(
    Future<void> Function() request,
    VoidCallback undo,
  ) async {
    try {
      await request();
    } on ApiException catch (error) {
      undo();
      _lastError = error.message;
      notifyListeners();
    }
  }

  Future<void> _setRead(AppNotification notification, bool read) async {
    if (notification.read == read) return;
    notification.read = read;
    notifyListeners();
    await _attempt(
      () => ApiClient.instance.patch('/notifications/${notification.id}/read', {
        'read': read,
      }),
      () => notification.read = !read,
    );
  }

  Future<void> markAsRead(String id) async {
    final notification = _find(id);
    if (notification != null) await _setRead(notification, true);
  }

  Future<void> toggleRead(String id) async {
    final notification = _find(id);
    if (notification != null) await _setRead(notification, !notification.read);
  }

  Future<void> markAllAsRead() async {
    final unread = _notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    for (final notification in unread) {
      notification.read = true;
    }
    notifyListeners();
    await _attempt(() => ApiClient.instance.post('/notifications/read-all'), () {
      for (final notification in unread) {
        notification.read = false;
      }
    });
  }

  Future<void> remove(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0) return;
    final removed = _notifications.removeAt(index);
    notifyListeners();
    await _attempt(
      () => ApiClient.instance.delete('/notifications/$id'),
      () => _notifications.insert(
        index.clamp(0, _notifications.length),
        removed,
      ),
    );
  }

  /// Apaga todas as notificações, também no servidor.
  Future<void> clear() async {
    if (_notifications.isEmpty) return;
    final backup = List<AppNotification>.of(_notifications);
    _notifications.clear();
    notifyListeners();
    await _attempt(
      () => ApiClient.instance.delete('/notifications'),
      () => _notifications.addAll(backup),
    );
  }

  void reset() {
    _notifications.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    _lastError = null;
    notifyListeners();
  }

  AppNotification? _find(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) return notification;
    }
    return null;
  }
}
