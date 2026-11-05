import 'package:flutter/foundation.dart';

import 'api_client.dart';

enum NotificationCategory { conquista, desafio, comunidade, sistema }

class AppNotification {
  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.read = false,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String message;
  final String timeLabel;
  bool read;

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
      read: json['read'] as bool? ?? false,
    );
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final List<AppNotification> _notifications = [
    AppNotification(
      id: 'n1',
      category: NotificationCategory.conquista,
      title: 'Novo selo desbloqueado!',
      message:
          'Você conquistou o selo "Guardião da Água" ao economizar 120 litros nesta semana.',
      timeLabel: 'Há 10 min',
    ),
    AppNotification(
      id: 'n2',
      category: NotificationCategory.desafio,
      title: 'Meta coletiva quase lá',
      message:
          'Faltam 120 ações para o bairro alcançar a meta "Nossa Comunidade Mais Verde".',
      timeLabel: 'Há 2 horas',
    ),
    AppNotification(
      id: 'n3',
      category: NotificationCategory.comunidade,
      title: 'Mariana comentou na sua ação',
      message: '"Que atitude linda! Vou levar os meus resíduos amanhã também."',
      timeLabel: 'Há 3 horas',
    ),
    AppNotification(
      id: 'n4',
      category: NotificationCategory.sistema,
      title: 'Lembrete gentil',
      message:
          'Que tal registrar as ações sustentáveis de hoje e manter sua sequência?',
      timeLabel: 'Ontem',
      read: true,
    ),
    AppNotification(
      id: 'n5',
      category: NotificationCategory.conquista,
      title: 'Semana consciente concluída',
      message: 'Você registrou ações em 5 dias seguidos. Continue assim!',
      timeLabel: 'Há 2 dias',
      read: true,
    ),
  ];

  int _nextId = 6;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> load() async {
    final data = await ApiClient.instance.get('/notifications');
    final list = (data['notifications'] as List?) ?? const [];
    _notifications
      ..clear()
      ..addAll(
        list.map(
          (item) => AppNotification.fromApi(item as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  void add({
    required NotificationCategory category,
    required String title,
    required String message,
    String timeLabel = 'Agora',
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: 'n${_nextId++}',
        category: category,
        title: title,
        message: message,
        timeLabel: timeLabel,
      ),
    );
    notifyListeners();
  }

  void markAsRead(String id) {
    final notification = _find(id);
    if (notification == null || notification.read) return;
    notification.read = true;
    notifyListeners();
    final numericId = int.tryParse(id);
    if (numericId != null) {
      ApiClient.instance
          .patch('/notifications/$numericId/read')
          .catchError((_) => null);
    }
  }

  void toggleRead(String id) {
    final notification = _find(id);
    if (notification == null) return;
    if (notification.read) {
      // A API não expõe "desmarcar como lida"; apenas atualizamos o estado local.
      notification.read = false;
      notifyListeners();
      return;
    }
    markAsRead(id);
  }

  void markAllAsRead() {
    if (unreadCount == 0) return;
    for (final notification in _notifications) {
      notification.read = true;
    }
    notifyListeners();
    ApiClient.instance.post('/notifications/read-all').catchError((_) => null);
  }

  void remove(String id) {
    final before = _notifications.length;
    _notifications.removeWhere((n) => n.id == id);
    if (_notifications.length != before) {
      notifyListeners();
      final numericId = int.tryParse(id);
      if (numericId != null) {
        ApiClient.instance
            .delete('/notifications/$numericId')
            .catchError((_) => null);
      }
    }
  }

  void clear() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
    ApiClient.instance.delete('/notifications').catchError((_) => null);
  }

  void reset() {
    _notifications.clear();
    notifyListeners();
  }

  AppNotification? _find(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) {
        return notification;
      }
    }
    return null;
  }
}
