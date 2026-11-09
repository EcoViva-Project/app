import 'package:flutter/foundation.dart';

import 'achievement_service.dart';
import 'action_catalog_service.dart';
import 'action_history_service.dart';
import 'api_client.dart';
import 'challenge_service.dart';
import 'community_service.dart';
import 'neighborhood_service.dart';
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

  String get city => user?['city'] as String? ?? '';

  /// Endereço informado no cadastro: `cep`, `street`, `number`, `complement`,
  /// `neighborhood`, `city` e `state` (qualquer um pode faltar).
  Map<String, dynamic> get address =>
      (user?['address'] as Map<String, dynamic>?) ?? const {};

  /// "Rua das Acácias, 120 - Boa Vista, São José do Rio Preto - SP".
  String get addressLine {
    String part(String key) => (address[key] as String? ?? '').trim();
    final street = [
      part('street'),
      part('number'),
    ].where((value) => value.isNotEmpty).join(', ');
    final place = [
      neighborhood,
      [city, part('state')].where((value) => value.isNotEmpty).join(' - '),
    ].where((value) => value.isNotEmpty).join(', ');
    return [street, place].where((value) => value.isNotEmpty).join(' - ');
  }

  /// "Boa Vista, São José do Rio Preto" (sem rua nem número).
  String get regionLabel =>
      [neighborhood, city].where((value) => value.isNotEmpty).join(', ');

  /// Posição aproximada (região do bairro), usada para distâncias e mapa.
  ({double lat, double lon})? get location {
    final raw = user?['location'];
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    return lat == null || lon == null ? null : (lat: lat, lon: lon);
  }

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
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? city,
    String? state,
  }) async {
    _setBusy(true);
    try {
      final data = await ApiClient.instance.post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        ..._addressFields(
          neighborhood: neighborhood,
          cep: cep,
          street: street,
          number: number,
          complement: complement,
          city: city,
          state: state,
        ),
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

  /// Só os campos de endereço preenchidos, prontos para enviar à API.
  Map<String, String> _addressFields({
    String? neighborhood,
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? city,
    String? state,
  }) {
    final fields = <String, String>{};
    void put(String key, String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) fields[key] = text;
    }

    put('neighborhood', neighborhood);
    put('cep', cep);
    put('street', street);
    put('number', number);
    put('complement', complement);
    put('city', city);
    put('state', state);
    return fields;
  }

  /// Bairros conhecidos cujo nome contém [query] (para sugerir no cadastro).
  Future<List<String>> searchNeighborhoods(String query) async {
    if (query.trim().length < 2) return const [];
    try {
      final data = await ApiClient.instance.get(
        '/places/neighborhoods',
        query: {'search': query.trim()},
      );
      return [
        for (final item in (data['neighborhoods'] as List?) ?? const [])
          item.toString(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> updateProfile({
    String? name,
    String? neighborhood,
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? city,
    String? state,
    int? monthlyGoal,
    int? weeklyGoal,
  }) async {
    final data = await ApiClient.instance.patch('/users/me', {
      if (name != null) 'name': name,
      ..._addressFields(
        neighborhood: neighborhood,
        cep: cep,
        street: street,
        number: number,
        complement: complement,
        city: city,
        state: state,
      ),
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
      safely(NeighborhoodService.instance.load),
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
    NeighborhoodService.instance.reset();
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
