import 'package:flutter/foundation.dart';

import 'achievement_service.dart';
import 'action_catalog_service.dart';
import 'action_history_service.dart';
import 'api_client.dart';
import 'challenge_service.dart';
import 'community_service.dart';
import 'notification_service.dart';
import 'reward_service.dart';
import 'session_service.dart';
import 'user_progress_service.dart';

/// Autenticação, sessão e carga dos dados do usuário.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Conta de demonstração criada no modo local.
  static const String demoEmail = 'clara@eco.app';
  static const String demoPassword = 'eco1234';

  bool _initialized = false;
  bool _busy = false;
  bool _signingOut = false;

  bool get initialized => _initialized;

  bool get busy => _busy;

  bool get isAuthenticated => SessionService.instance.isAuthenticated;

  /// O app está usando o banco do próprio aparelho, sem servidor.
  bool get isLocalMode => ApiClient.isLocalMode;

  Map<String, dynamic>? get user => SessionService.instance.user;

  String get userName => user?['name'] as String? ?? '';

  String get firstName {
    final parts = userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  String get userInitials {
    final initials = user?['initials'] as String?;
    if (initials != null && initials.isNotEmpty) return initials;
    return userName.isEmpty ? '?' : userName[0].toUpperCase();
  }

  String get userEmail => user?['email'] as String? ?? '';

  String get neighborhood => user?['neighborhood'] as String? ?? '';

  int get weeklyGoal => (user?['weeklyGoal'] as num?)?.toInt() ?? 5;

  int get monthlyGoal => (user?['monthlyGoal'] as num?)?.toInt() ?? 17;

  Map<String, dynamic> get preferences =>
      (user?['preferences'] as Map<String, dynamic>?) ?? const {};

  /// Abre a sessão salva, se houver, e carrega os dados.
  ///
  /// A sessão só é apagada quando a API recusa o token. Falta de rede não
  /// desloga ninguém.
  Future<void> initialize() async {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
    try {
      await SessionService.instance.load();
      if (isAuthenticated) {
        try {
          final data = await ApiClient.instance.get('/auth/me');
          await SessionService.instance.updateUser(
            data['user'] as Map<String, dynamic>,
          );
        } on ApiException catch (error) {
          if (error.isUnauthorized) await SessionService.instance.clear();
        } catch (_) {
          // Mantém a sessão; as telas mostram o erro de carga de cada módulo.
        }
        if (isAuthenticated) await loadAll();
      }
    } catch (_) {
      // Sem acesso ao armazenamento: segue para o login.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setBusy(true);
    try {
      final data = await ApiClient.instance.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await _applySession(data);
      await loadAll();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? neighborhood,
  }) async {
    _setBusy(true);
    try {
      final data = await ApiClient.instance.post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (neighborhood != null && neighborhood.trim().isNotEmpty)
          'neighborhood': neighborhood.trim(),
      });
      await _applySession(data);
      await loadAll();
    } finally {
      _setBusy(false);
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final data = await ApiClient.instance.post('/auth/forgot-password', {
      'email': email.trim(),
    });
    return data as Map<String, dynamic>;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await ApiClient.instance.post('/auth/reset-password', {
      'email': email.trim(),
      'code': code.trim(),
      'password': password,
    });
  }

  Future<void> updateProfile({
    String? name,
    String? neighborhood,
    int? monthlyGoal,
    int? weeklyGoal,
  }) async {
    final data = await ApiClient.instance.patch('/users/me', {
      if (name != null) 'name': name,
      if (neighborhood != null) 'neighborhood': neighborhood,
      if (monthlyGoal != null) 'monthlyGoal': monthlyGoal,
      if (weeklyGoal != null) 'weeklyGoal': weeklyGoal,
    });
    await SessionService.instance.updateUser(
      data['user'] as Map<String, dynamic>,
    );
    notifyListeners();
    if (monthlyGoal != null) {
      UserProgressService.instance.load().catchError((_) {});
    }
    if (name != null) CommunityService.instance.load().catchError((_) {});
  }

  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    final data = await ApiClient.instance.patch(
      '/users/me/preferences',
      preferences,
    );
    await SessionService.instance.updateUser(
      data['user'] as Map<String, dynamic>,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await SessionService.instance.clear();
    _resetServices();
    notifyListeners();
  }

  /// Modo local: apaga os dados deste aparelho, recria a demonstração e sai
  /// da conta, deixando o app pronto para a próxima apresentação.
  Future<void> resetDemo() async {
    await ApiClient.instance.post('/demo/reset');
    await logout();
  }

  /// Carrega (ou recarrega) todos os módulos. A falha de um módulo não
  /// impede os outros; cada serviço guarda o próprio erro para a tela mostrar.
  Future<void> loadAll() async {
    Future<void> safely(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        // O serviço já registrou o erro em `error`.
      }
    }

    await Future.wait([
      safely(UserProgressService.instance.load),
      safely(AchievementService.instance.load),
      safely(ActionHistoryService.instance.load),
      safely(ActionCatalogService.instance.load),
      safely(NotificationService.instance.load),
      safely(ChallengeService.instance.load),
      safely(CommunityService.instance.load),
      safely(RewardService.instance.load),
    ]);
    notifyListeners();
  }

  void _resetServices() {
    UserProgressService.instance.reset();
    AchievementService.instance.reset();
    ActionHistoryService.instance.clear();
    ActionCatalogService.instance.reset();
    NotificationService.instance.reset();
    ChallengeService.instance.reset();
    CommunityService.instance.reset();
    RewardService.instance.reset();
  }

  /// A API recusou o token: encerra a sessão para o roteador levar ao login.
  void _handleUnauthorized() {
    if (_signingOut || !isAuthenticated) return;
    _signingOut = true;
    logout().whenComplete(() => _signingOut = false);
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    await SessionService.instance.save(
      token: data['token'] as String,
      user: data['user'] as Map<String, dynamic>,
    );
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
