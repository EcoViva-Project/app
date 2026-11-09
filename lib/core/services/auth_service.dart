import 'package:flutter/foundation.dart';

import 'achievement_service.dart';
import 'action_history_service.dart';
import 'api_client.dart';
import 'challenge_service.dart';
import 'community_service.dart';
import 'notification_service.dart';
import 'reward_service.dart';
import 'session_service.dart';
import 'user_progress_service.dart';

/// Autenticação, sessão e hidratação dos dados do usuário.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _initialized = false;
  bool _busy = false;

  bool get initialized => _initialized;

  bool get busy => _busy;

  bool get isAuthenticated => SessionService.instance.isAuthenticated;

  Map<String, dynamic>? get user => SessionService.instance.user;

  String get userName => user?['name'] as String? ?? 'Clara Mendes';

  String get userInitials => user?['initials'] as String? ?? 'CM';

  String get neighborhood =>
      user?['neighborhood'] as String? ?? 'Jardim das Flores';

  Map<String, dynamic> get preferences =>
      (user?['preferences'] as Map<String, dynamic>?) ?? const {};

  Future<void> initialize() async {
    await SessionService.instance.load();
    if (isAuthenticated) {
      try {
        final data = await ApiClient.instance.get('/auth/me');
        await SessionService.instance.updateUser(
          data['user'] as Map<String, dynamic>,
        );
        await _hydrateData();
      } catch (_) {
        await SessionService.instance.clear();
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _setBusy(true);
    try {
      final data = await ApiClient.instance.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await _applySession(data);
      await _hydrateData();
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
      await _hydrateData();
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
    UserProgressService.instance.reset();
    AchievementService.instance.reset();
    ActionHistoryService.instance.clear();
    NotificationService.instance.reset();
    ChallengeService.instance.reset();
    CommunityService.instance.reset();
    RewardService.instance.reset();
    notifyListeners();
  }

  /// Atualiza os dados depois de registrar uma ação ou concluir um desafio.
  Future<void> refreshProgress() async {
    await UserProgressService.instance.load();
    await AchievementService.instance.load();
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    await SessionService.instance.save(
      token: data['token'] as String,
      user: data['user'] as Map<String, dynamic>,
    );
  }

  Future<void> _hydrateData() async {
    Future<void> safely(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        // Uma falha em um módulo não deve bloquear o acesso ao aplicativo.
      }
    }

    await Future.wait([
      safely(UserProgressService.instance.load),
      safely(AchievementService.instance.load),
      safely(ActionHistoryService.instance.load),
      safely(NotificationService.instance.load),
      safely(ChallengeService.instance.load),
      safely(CommunityService.instance.load),
      safely(RewardService.instance.load),
    ]);
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> debugSignIn({
    String name = 'Clara Mendes',
    String email = 'clara@eco.app',
  }) async {
    await SessionService.instance.save(
      token: 'debug-token',
      user: {
        'id': 1,
        'name': name,
        'email': email,
        'initials': 'CM',
        'neighborhood': 'Jardim das Flores',
        'preferences': const <String, dynamic>{},
      },
    );
    _initialized = true;
    notifyListeners();
  }
}
