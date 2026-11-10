import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../services/api_exception.dart';
import 'economy.dart';
import 'local_seed.dart';
import 'local_store.dart';
import 'places.dart';

/// API do EcoViva rodando dentro do aplicativo, sobre o banco local.
///
/// Atende as mesmas rotas e devolve os mesmos formatos JSON do `eco-backend`,
/// para que os serviços e as telas funcionem sem rede e sem alterações.
class LocalApi {
  LocalApi(this.db, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  final LocalDatabase db;
  final DateTime Function() _clock;
  final Random _random;

  DateTime get now => _clock().toUtc();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Abre o banco e, se estiver vazio, cria os dados de demonstração.
  Future<void> ensureReady() async {
    if (!db.isOpen) await db.open();
    if (db.isEmpty) {
      await LocalSeed.run(this);
      _positionsChecked = true;
    } else if (!_positionsChecked) {
      _positionsChecked = true;
      await _refreshApproximatePositions();
    }
  }

  bool _positionsChecked = false;

  /// Refaz, uma vez por execução do app, a posição aproximada de quem já
  /// estava no banco.
  ///
  /// A posição depende só do bairro e do e-mail, então refazer a conta não
  /// muda nada para quem já estava certo. Corrige contas criadas por versões
  /// anteriores, em que um bairro não reconhecido caía, sem aviso, no centro
  /// da cidade: agora elas ganham a posição do bairro (se o nome passou a ser
  /// reconhecido) ou ficam sem posição, e o app avisa.
  Future<void> _refreshApproximatePositions() async {
    for (final user in List.of(db.table('users'))) {
      final position = Places.approximatePosition(
        '${user['neighborhood'] ?? ''}',
        '${user['email']}',
      );
      final lat = (user['lat'] as num?)?.toDouble();
      final lon = (user['lon'] as num?)?.toDouble();
      if (lat == position?.lat && lon == position?.lon) continue;
      await db.update('users', user, {
        'lat': position?.lat,
        'lon': position?.lon,
      });
    }
  }

  /// Apaga tudo e recria os dados de demonstração.
  Future<void> resetDemo() async {
    if (!db.isOpen) await db.open();
    await db.wipe();
    await LocalSeed.run(this);
  }

  // ---------------------------------------------------------------------------
  // Roteamento
  // ---------------------------------------------------------------------------

  Future<dynamic> handle(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    await ensureReady();
    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    final data =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final result = await _dispatch(
      method.toUpperCase(),
      segments,
      query ?? const {},
      data,
      token,
    );
    // Devolve estruturas JSON puras, como as que viriam da rede.
    return jsonDecode(jsonEncode(result));
  }

  Future<Object?> _dispatch(
    String method,
    List<String> path,
    Map<String, String> query,
    Map<String, dynamic> data,
    String? token,
  ) async {
    switch ((method, path)) {
      case ('GET', ['health']):
        return {'status': 'ok', 'service': 'eco-local', 'time': _iso(now)};
      case ('POST', ['auth', 'register']):
        return _register(data);
      case ('POST', ['auth', 'login']):
        return _login(data);
      case ('POST', ['auth', 'forgot-password']):
        return _forgotPassword(data);
      case ('POST', ['auth', 'reset-password']):
        return _resetPassword(data);
      case ('POST', ['demo', 'reset']):
        await resetDemo();
        return {'ok': true};
      // Lista pública de nomes de bairros: o cadastro usa antes de haver sessão.
      case ('GET', ['places', 'neighborhoods']):
        return {
          'neighborhoods': Places.searchNeighborhoods(query['search'] ?? ''),
        };
    }

    final user = _requireUser(token);

    switch ((method, path)) {
      case ('GET', ['auth', 'me']):
        return {'user': _publicUser(user)};
      case ('GET', ['users', 'me']):
        return {
          'user': _publicUser(user),
          'summary': _summary(user),
          'achievements': await _achievements(user),
        };
      case ('PATCH', ['users', 'me']):
        return _updateProfile(user, data);
      case ('PATCH', ['users', 'me', 'preferences']):
        return _updatePreferences(user, data);

      case ('GET', ['actions']):
        return {'actions': _listActions(user, query)};
      case ('GET', ['actions', final id]):
        return {
          'action': _actionJson(
            _requireRow('actions', id, 'Ação não encontrada.'),
            user,
          ),
        };
      case ('POST', ['actions', final id, 'records']):
        return _createRecord(user, id, data);
      case ('GET', ['records']):
        return {'records': _listRecords(user, query)};

      case ('GET', ['progress']):
        return {
          'summary': _summary(user),
          'achievements': await _achievements(user),
        };
      case ('GET', ['progress', 'achievements']):
        return {'achievements': await _achievements(user)};

      case ('GET', ['notifications']):
        return _listNotifications(user);
      case ('POST', ['notifications', 'read-all']):
        for (final row in _notificationsOf(user)) {
          if (!_flag(row['read'])) {
            await db.update('notifications', row, {'read': 1});
          }
        }
        return {'ok': true};
      case ('PATCH', ['notifications', final id, 'read']):
        final row = db.byId('notifications', id);
        if (row == null || row['user_id'] != user['id']) {
          _fail(404, 'Notificação não encontrada.');
        }
        await db.update('notifications', row, {
          'read': data['read'] == false ? 0 : 1,
        });
        return {'ok': true};
      case ('DELETE', ['notifications', final id]):
        final wanted = int.tryParse(id);
        await db.removeWhere(
          'notifications',
          (row) => row['id'] == wanted && row['user_id'] == user['id'],
        );
        return {'ok': true};
      case ('DELETE', ['notifications']):
        await db.removeWhere(
          'notifications',
          (row) => row['user_id'] == user['id'],
        );
        return {'ok': true};

      case ('GET', ['challenges']):
        return {'challenges': _listChallenges(user)};
      case ('GET', ['challenges', final id]):
        return {
          'challenge': _challengeJson(
            _requireRow('challenges', id, 'Desafio não encontrado.'),
            user,
            now,
          ),
        };
      case ('POST', ['challenges', final id, 'join']):
        return _joinChallenge(user, id);
      case ('POST', ['challenges', _, 'progress']):
        _fail(
          410,
          'O desafio agora avança sozinho quando você registra uma ação da categoria dele.',
        );

      case ('GET', ['community', 'stats']):
        return _communityStats(user);
      case ('GET', ['community', 'map']):
        return _communityMap(user);
      case ('GET', ['collection-points']):
        return {'points': _listCollectionPoints(user, query)};
      case ('GET', ['tips', 'today']):
        return {'tip': _tipOfTheDay()};
      case ('GET', ['community', 'posts']):
        return {'posts': _listPosts(user)};
      case ('POST', ['community', 'posts']):
        return _createPost(user, data);
      case ('POST', ['community', 'posts', final id, 'like']):
        return _toggleLike(user, id);
      case ('GET', ['community', 'posts', final id, 'comments']):
        final post = _requireRow('posts', id, 'Publicação não encontrada.');
        return {'comments': _commentsOf(post).map(_commentJson).toList()};
      case ('POST', ['community', 'posts', final id, 'comments']):
        return _createComment(user, id, data);
      case ('DELETE', ['community', 'posts', final id]):
        return _deletePost(user, id);

      case ('GET', ['rewards']):
        return {'rewards': _listRewards(user)};
      case ('GET', ['rewards', 'redemptions']):
        return {
          'redemptions': _redemptionsOf(user).map(_redemptionJson).toList(),
          'summary': _summary(user),
        };
      case ('POST', ['rewards', 'redemptions', final id, 'use']):
        return _useRedemption(user, id, data);
      case ('GET', ['rewards', final id]):
        return {'reward': _rewardJson(_requireReward(id), user)};
      case ('POST', ['rewards', final id, 'redeem']):
        return _redeem(user, id);
    }

    _fail(404, 'Rota não encontrada.');
  }

  // ---------------------------------------------------------------------------
  // Utilitários
  // ---------------------------------------------------------------------------

  Never _fail(int status, String message) =>
      throw ApiException(message, statusCode: status);

  static int _i(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static bool _flag(Object? value) => value == 1 || value == true;

  static String _clean(Object? value) => value is String ? value.trim() : '';

  static String _iso(DateTime instant) => instant.toUtc().toIso8601String();

  String _randomHex(int bytes) =>
      List.generate(
        bytes,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  static String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'EC';
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, min(2, only.length)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  DbRow _requireRow(String table, Object? id, String message) {
    final row = db.byId(table, id);
    if (row == null) _fail(404, message);
    return row;
  }

  DbRow _requireUser(String? token) {
    if (token == null || !token.startsWith('local.')) {
      _fail(401, 'Autenticação necessária.');
    }
    final parts = token.split('.');
    final user = parts.length >= 2 ? db.byId('users', parts[1]) : null;
    if (user == null) _fail(401, 'Sessão expirada ou inválida.');
    return user;
  }

  String _tokenFor(DbRow user) => 'local.${user['id']}.${_randomHex(8)}';

  DbRow? _userByEmail(String email) {
    final wanted = email.trim().toLowerCase();
    for (final row in db.table('users')) {
      if ('${row['email']}'.toLowerCase() == wanted) return row;
    }
    return null;
  }

  Map<String, dynamic> _publicUser(DbRow user) => {
    'id': user['id'],
    'name': user['name'],
    'email': user['email'],
    'neighborhood': user['neighborhood'],
    'city': user['city'],
    'address': {
      'cep': user['cep'],
      'street': user['street'],
      'number': user['number'],
      'complement': user['complement'],
      'neighborhood': user['neighborhood'],
      'city': user['city'],
      'state': user['state'],
    },
    // Posição aproximada (região do bairro), nunca o endereço exato.
    'location':
        user['lat'] == null ? null : {'lat': user['lat'], 'lon': user['lon']},
    'initials': user['initials'],
    'memberSince': user['created_at'],
    'monthlyGoal': user['monthly_goal'],
    'weeklyGoal': user['weekly_goal'],
    'preferences': {
      'notificationsEnabled': _flag(user['notifications_enabled']),
      'remindersEnabled': _flag(user['reminders_enabled']),
      'privacyProfile': _flag(user['privacy_profile']),
      'privacyLocation': _flag(user['privacy_location']),
    },
  };

  /// Texto como "Há 10 min", igual ao do servidor.
  String relativeTime(Object? iso) {
    final date = DateTime.tryParse('$iso');
    if (date == null) return '';
    final minutes = now.difference(date).inMinutes;
    if (minutes < 1) return 'Agora';
    if (minutes < 60) return 'Há $minutes min';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'Há $hours ${hours == 1 ? 'hora' : 'horas'}';
    final days = hours ~/ 24;
    if (days == 1) return 'Ontem';
    if (days < 7) return 'Há $days dias';
    return Economy.longDate(date);
  }

  // ---------------------------------------------------------------------------
  // Autenticação e conta
  // ---------------------------------------------------------------------------

  /// Cria um usuário diretamente (usado pelo cadastro e pela carga inicial).
  Future<DbRow> createUser({
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
    DateTime? createdAt,
  }) async {
    final salt = _randomHex(8);
    final place = neighborhood ?? '';
    final position = Places.approximatePosition(place, email.toLowerCase());
    return db.insert('users', {
      'name': name,
      'email': email.toLowerCase(),
      'password_hash': hashPassword(password, salt),
      'salt': salt,
      'neighborhood': place,
      'cep': cep,
      'street': street,
      'number': number,
      'complement': complement,
      'city': (city == null || city.isEmpty) ? Places.defaultCity : city,
      'state': (state == null || state.isEmpty) ? Places.defaultState : state,
      // Sem posição quando o bairro não está na lista (ver Places).
      'lat': position?.lat,
      'lon': position?.lon,
      'initials': initialsFor(name),
      'monthly_goal': 17,
      'weekly_goal': 5,
      'notifications_enabled': 1,
      'reminders_enabled': 1,
      'privacy_profile': 1,
      'privacy_location': 1,
      'created_at': _iso(createdAt ?? now),
    });
  }

  Future<Map<String, dynamic>> _register(Map<String, dynamic> data) async {
    final name = _clean(data['name']);
    final email = _clean(data['email']).toLowerCase();
    final password =
        data['password'] is String ? data['password'] as String : '';

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _fail(400, 'Nome, e-mail e senha são obrigatórios.');
    }
    if (name.length < 2 || name.length > 80) {
      _fail(400, 'Informe um nome com 2 a 80 caracteres.');
    }
    if (email.length > 120 || !_emailPattern.hasMatch(email)) {
      _fail(400, 'Informe um e-mail válido.');
    }
    if (password.length < 6) {
      _fail(400, 'A senha deve ter pelo menos 6 caracteres.');
    }
    if (_userByEmail(email) != null) {
      _fail(409, 'Já existe uma conta com este e-mail.');
    }

    final address = _addressFrom(data);
    final user = await createUser(
      name: name,
      email: email,
      password: password,
      neighborhood: address['neighborhood'],
      cep: address['cep'],
      street: address['street'],
      number: address['number'],
      complement: address['complement'],
      city: address['city'],
      state: address['state'],
    );
    await notify(
      user,
      'sistema',
      'Boas-vindas ao EcoViva!',
      'Sua conta foi criada. Registre sua primeira ação sustentável e comece a somar pontos.',
      target: '/acoes',
    );
    return {'token': _tokenFor(user), 'user': _publicUser(user)};
  }

  /// Lê e valida os campos de endereço enviados no cadastro ou no perfil.
  Map<String, String?> _addressFrom(Map<String, dynamic> data) {
    String? field(String key, int max, String label) {
      final value = _clean(data[key]);
      if (value.isEmpty) return null;
      if (value.length > max) {
        _fail(400, '$label deve ter no máximo $max caracteres.');
      }
      return value;
    }

    final cep = _clean(data['cep']).replaceAll(RegExp(r'[^0-9]'), '');
    if (cep.isNotEmpty && cep.length != 8) {
      _fail(400, 'Informe um CEP com 8 dígitos.');
    }
    final state = field('state', 2, 'O estado');
    return {
      'cep': cep.isEmpty ? null : '${cep.substring(0, 5)}-${cep.substring(5)}',
      'street': field('street', 120, 'A rua'),
      'number': field('number', 12, 'O número'),
      'complement': field('complement', 60, 'O complemento'),
      'neighborhood': field('neighborhood', 80, 'O bairro') ?? '',
      'city': field('city', 80, 'A cidade'),
      'state': state?.toUpperCase(),
    };
  }

  Future<Map<String, dynamic>> _login(Map<String, dynamic> data) async {
    final email = _clean(data['email']);
    final password =
        data['password'] is String ? data['password'] as String : '';
    if (email.isEmpty || password.isEmpty) {
      _fail(400, 'Informe e-mail e senha.');
    }
    final user = _userByEmail(email);
    if (user == null ||
        hashPassword(password, '${user['salt']}') != user['password_hash']) {
      _fail(401, 'E-mail ou senha inválidos.');
    }
    return {'token': _tokenFor(user), 'user': _publicUser(user)};
  }

  Future<Map<String, dynamic>> _forgotPassword(
    Map<String, dynamic> data,
  ) async {
    final email = _clean(data['email']);
    if (email.isEmpty) _fail(400, 'Informe o e-mail da conta.');

    const message =
        'Se existir uma conta com este e-mail, enviaremos as instruções de recuperação.';
    final user = _userByEmail(email);
    if (user == null) {
      return {'message': message, 'expiresInMinutes': 30};
    }

    for (final row in db.table('password_resets')) {
      if (row['user_id'] == user['id'] && !_flag(row['used'])) {
        await db.update('password_resets', row, {'used': 1});
      }
    }
    final code = (100000 + _random.nextInt(900000)).toString();
    await db.insert('password_resets', {
      'user_id': user['id'],
      'code': code,
      'expires_at': _iso(now.add(const Duration(minutes: 30))),
      'attempts': 0,
      'used': 0,
    });
    // No modo local não existe servidor de e-mail: o código só existe neste
    // aparelho e por isso é mostrado na própria tela.
    return {'message': message, 'expiresInMinutes': 30, 'devCode': code};
  }

  Future<Map<String, dynamic>> _resetPassword(Map<String, dynamic> data) async {
    final email = _clean(data['email']);
    final code = _clean(data['code']);
    final password =
        data['password'] is String ? data['password'] as String : '';
    if (email.isEmpty || code.isEmpty || password.isEmpty) {
      _fail(400, 'Informe e-mail, código e nova senha.');
    }
    if (password.length < 6) {
      _fail(400, 'A senha deve ter pelo menos 6 caracteres.');
    }

    final user = _userByEmail(email);
    DbRow? reset;
    if (user != null) {
      for (final row in db.table('password_resets').reversed) {
        if (row['user_id'] == user['id'] && !_flag(row['used'])) {
          reset = row;
          break;
        }
      }
    }
    final expired =
        reset == null ||
        (DateTime.tryParse('${reset['expires_at']}') ?? now).isBefore(now);
    if (user == null || reset == null || expired) {
      _fail(400, 'Código inválido ou expirado.');
    }
    if (reset['code'] != code) {
      final attempts = _i(reset['attempts']) + 1;
      await db.update('password_resets', reset, {
        'attempts': attempts,
        if (attempts >= 5) 'used': 1,
      });
      _fail(400, 'Código inválido ou expirado.');
    }

    final salt = _randomHex(8);
    await db.update('users', user, {
      'salt': salt,
      'password_hash': hashPassword(password, salt),
    });
    await db.update('password_resets', reset, {'used': 1});
    return {'message': 'Senha redefinida com sucesso.'};
  }

  Future<Map<String, dynamic>> _updateProfile(
    DbRow user,
    Map<String, dynamic> data,
  ) async {
    final values = <String, Object?>{};

    if (data.containsKey('name')) {
      final name = _clean(data['name']);
      if (name.length < 2 || name.length > 80) {
        _fail(400, 'Informe um nome com 2 a 80 caracteres.');
      }
      values['name'] = name;
      values['initials'] = initialsFor(name);
    }
    if (data.containsKey('neighborhood')) {
      final neighborhood = _clean(data['neighborhood']);
      if (neighborhood.isEmpty || neighborhood.length > 80) {
        _fail(400, 'Informe um bairro com até 80 caracteres.');
      }
      values['neighborhood'] = neighborhood;
      // A posição aproximada acompanha o bairro.
      final position = Places.approximatePosition(
        neighborhood,
        '${user['email']}',
      );
      values['lat'] = position?.lat;
      values['lon'] = position?.lon;
    }
    final address = _addressFrom(data);
    for (final key in [
      'cep',
      'street',
      'number',
      'complement',
      'city',
      'state',
    ]) {
      if (data.containsKey(key)) values[key] = address[key];
    }
    for (final (key, column) in [
      ('monthlyGoal', 'monthly_goal'),
      ('weeklyGoal', 'weekly_goal'),
    ]) {
      if (!data.containsKey(key)) continue;
      final goal = data[key];
      if (goal is! int || goal < 1 || goal > 100) {
        _fail(400, 'As metas devem ser números inteiros entre 1 e 100.');
      }
      values[column] = goal;
    }

    if (values.isEmpty) _fail(400, 'Nenhum campo para atualizar.');
    await db.update('users', user, values);

    if (values.containsKey('name')) {
      // Mantém o nome atualizado nas publicações e comentários já feitos.
      for (final table in ['posts', 'post_comments']) {
        for (final row in db.table(table)) {
          if (row['user_id'] == user['id']) {
            await db.update(table, row, {
              'author_name': values['name'],
              'author_initials': values['initials'],
            });
          }
        }
      }
    }
    return {'user': _publicUser(user)};
  }

  Future<Map<String, dynamic>> _updatePreferences(
    DbRow user,
    Map<String, dynamic> data,
  ) async {
    const columns = {
      'notificationsEnabled': 'notifications_enabled',
      'remindersEnabled': 'reminders_enabled',
      'privacyProfile': 'privacy_profile',
      'privacyLocation': 'privacy_location',
    };
    final values = <String, Object?>{};
    columns.forEach((key, column) {
      if (data.containsKey(key)) values[column] = data[key] == true ? 1 : 0;
    });
    if (values.isEmpty) _fail(400, 'Nenhuma preferência informada.');
    await db.update('users', user, values);
    return {'user': _publicUser(user)};
  }

  // ---------------------------------------------------------------------------
  // Notificações
  // ---------------------------------------------------------------------------

  Future<void> notify(
    DbRow user,
    String category,
    String title,
    String message, {
    String? target,
    DateTime? at,
    bool read = false,
  }) async {
    await db.insert('notifications', {
      'user_id': user['id'],
      'category': category,
      'title': title,
      'message': message,
      'target': target,
      'read': read ? 1 : 0,
      'created_at': _iso(at ?? now),
    });
  }

  List<DbRow> _notificationsOf(DbRow user) =>
      db
          .table('notifications')
          .where((n) => n['user_id'] == user['id'])
          .toList();

  Map<String, dynamic> _listNotifications(DbRow user) {
    final rows = _notificationsOf(user)..sort(_newestFirst);
    return {
      'notifications': [
        for (final row in rows.take(100))
          {
            'id': row['id'],
            'category': row['category'],
            'title': row['title'],
            'message': row['message'],
            'target': row['target'],
            'read': _flag(row['read']),
            'timeLabel': relativeTime(row['created_at']),
            'createdAt': row['created_at'],
          },
      ],
      'unreadCount': rows.where((row) => !_flag(row['read'])).length,
    };
  }

  static int _newestFirst(DbRow a, DbRow b) {
    final byDate = '${b['created_at']}'.compareTo('${a['created_at']}');
    return byDate != 0 ? byDate : _i(b['id']).compareTo(_i(a['id']));
  }

  // ---------------------------------------------------------------------------
  // Resumo, níveis e teto semanal
  // ---------------------------------------------------------------------------

  List<DbRow> _recordsOf(Object? userId) =>
      db.table('action_records').where((r) => r['user_id'] == userId).toList();

  /// Pontos de ações creditados na semana local que contém [instant].
  int weekActionPoints(Object? userId, DateTime instant) {
    final start = Economy.weekStartKey(instant);
    final end = Economy.weekEndKey(instant);
    var total = 0;
    for (final row in db.table('action_records')) {
      if (row['user_id'] != userId || row['kind'] != 'action') continue;
      final date = '${row['local_date']}';
      if (date.compareTo(start) >= 0 && date.compareTo(end) <= 0) {
        total += _i(row['points']);
      }
    }
    return total;
  }

  ({int current, int best}) _streaks(Set<String> days, DateTime instant) {
    if (days.isEmpty) return (current: 0, best: 0);
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = Economy.shiftDateKey(sorted[i - 1], 1) == sorted[i] ? run + 1 : 1;
      if (run > best) best = run;
    }
    final today = Economy.dateKey(instant);
    var cursor = days.contains(today) ? today : Economy.shiftDateKey(today, -1);
    var current = 0;
    while (days.contains(cursor)) {
      current++;
      cursor = Economy.shiftDateKey(cursor, -1);
    }
    return (current: current, best: best);
  }

  Map<String, dynamic> _summary(DbRow user) {
    final userId = user['id'];
    final records = _recordsOf(userId);
    final actions = records.where((r) => r['kind'] == 'action').toList();

    final earned = records.fold<int>(0, (sum, r) => sum + _i(r['points']));
    final spent = db
        .table('redemptions')
        .where((r) => r['user_id'] == userId)
        .fold<int>(0, (sum, r) => sum + _i(r['points_spent']));
    final days = actions.map((r) => '${r['local_date']}').toSet();
    final month = Economy.monthKey(now);
    final monthly =
        actions.where((r) => '${r['local_date']}'.startsWith(month)).length;
    final goal = max(1, _i(user['monthly_goal'], 17));
    final weekly = weekActionPoints(userId, now);
    final level = Economy.levelFor(earned);
    final streak = _streaks(days, now);

    return {
      'points': max(earned - spent, 0),
      'pointsEarned': earned,
      'pointsSpent': spent,
      'actionsCount': actions.length,
      'activeDays': days.length,
      'monthlyActions': monthly,
      'monthlyGoal': goal,
      'monthlyGoalProgress': min(monthly / goal, 1.0),
      'litersSaved': actions.fold<int>(0, (sum, r) => sum + _i(r['liters'])),
      'level': level.label,
      'levelNumber': level.number,
      'levelName': level.name,
      'levelFloor': level.floor,
      'nextLevelAt': level.next,
      'weeklyPoints': weekly,
      'weeklyCap': Economy.weeklyCap,
      'weeklyRemaining': max(Economy.weeklyCap - weekly, 0),
      'weekResetsAt': _iso(Economy.nextWeekReset(now)),
      'streakDays': streak.current,
      'bestStreak': streak.best,
    };
  }

  // ---------------------------------------------------------------------------
  // Conquistas
  // ---------------------------------------------------------------------------

  static const List<String> allCategories = [
    'Água',
    'Reciclagem',
    'Alimentação',
    'Transporte',
    'Energia',
    'Espaços Públicos',
  ];

  List<_AchievementState> _achievementStates(DbRow user) {
    final userId = user['id'];
    final actions =
        _recordsOf(userId).where((r) => r['kind'] == 'action').toList();
    final days = actions.map((r) => '${r['local_date']}').toSet();
    final countByCategory = <String, int>{};
    final waterDays = <String>{};
    var liters = 0;
    for (final row in actions) {
      final category = '${row['category_label']}';
      countByCategory[category] =
          (countByCategory[category] ?? 0) + _i(row['quantity'], 1);
      liters += _i(row['liters']);
      if (category == 'Água') waterDays.add('${row['local_date']}');
    }
    final categories = countByCategory.keys.toSet();
    final completedChallenges =
        db
            .table('challenge_progress')
            .where((p) => p['user_id'] == userId && _flag(p['completed']))
            .length;
    final bestStreak = _streaks(days, now).best;
    final missing =
        allCategories.where((c) => !categories.contains(c)).toList();

    return [
      _AchievementState(
        key: 'primeiros-passos',
        icon: 'eco',
        title: 'Primeiros Passos',
        points: 30,
        description: 'Registre sua primeira ação sustentável no aplicativo.',
        current: actions.length,
        target: 1,
      ),
      _AchievementState(
        key: 'guardiao-da-agua',
        icon: 'water_drop',
        title: 'Guardião da Água',
        points: 50,
        description: 'Poupe 100 litros de água com hábitos diários.',
        current: liters,
        target: 100,
        unit: 'litros',
      ),
      _AchievementState(
        key: 'consistencia-verde',
        icon: 'calendar_month',
        title: 'Consistência Verde',
        points: 60,
        description: 'Registre ações por 4 dias seguidos.',
        current: bestStreak,
        target: 4,
        unit: 'dias seguidos',
      ),
      _AchievementState(
        key: 'forca-coletiva',
        icon: 'diversity_1',
        title: 'Força Coletiva',
        points: 80,
        description: 'Conclua seu primeiro desafio coletivo do bairro.',
        current: completedChallenges,
        target: 1,
        unit: 'desafio',
      ),
      _AchievementState(
        key: 'consciencia-plena',
        icon: 'category',
        title: 'Consciência Plena',
        points: 100,
        description: 'Experimente hábitos em 4 categorias diferentes.',
        current: categories.length,
        target: 4,
        unit: 'categorias',
        missing:
            missing.isEmpty || categories.length >= 4
                ? null
                : 'Ainda não experimentou: ${missing.join(', ')}.',
      ),
      _AchievementState(
        key: 'mestre-da-compostagem',
        icon: 'compost',
        title: 'Mestre da Compostagem',
        points: 70,
        description: 'Registre 5 ações de Alimentação, como a compostagem.',
        current: countByCategory['Alimentação'] ?? 0,
        target: 5,
        unit: 'ações',
      ),
      _AchievementState(
        key: 'vizinho-exemplar',
        icon: 'handshake',
        title: 'Vizinho Exemplar',
        points: 150,
        description: 'Conclua 3 desafios coletivos com a comunidade.',
        current: completedChallenges,
        target: 3,
        unit: 'desafios',
      ),
      _AchievementState(
        key: 'economizador-de-agua',
        icon: 'water_drop_outlined',
        title: 'Economizador de Água',
        points: 90,
        description: 'Registre ações de Água em 7 dias diferentes.',
        current: waterDays.length,
        target: 7,
        unit: 'dias',
      ),
      _AchievementState(
        key: 'mobilidade-ativa',
        icon: 'directions_bike',
        title: 'Mobilidade Ativa',
        points: 60,
        description: 'Faça 5 trajetos curtos a pé ou de bicicleta.',
        current: countByCategory['Transporte'] ?? 0,
        target: 5,
        unit: 'trajetos',
      ),
      _AchievementState(
        key: 'guardiao-da-energia',
        icon: 'bolt',
        title: 'Guardião da Energia',
        points: 80,
        description: 'Registre 6 ações de economia de energia.',
        current: countByCategory['Energia'] ?? 0,
        target: 6,
        unit: 'ações',
      ),
    ];
  }

  DbRow? _unlockRow(DbRow user, String key) {
    for (final row in db.table('user_achievements')) {
      if (row['user_id'] == user['id'] && row['achievement_key'] == key) {
        return row;
      }
    }
    return null;
  }

  /// Grava as conquistas recém-atingidas, credita o bônus e avisa o usuário.
  Future<List<Map<String, dynamic>>> syncAchievements(
    DbRow user, {
    DateTime? at,
    bool silent = false,
  }) async {
    final when = at ?? now;
    final unlockedNow = <Map<String, dynamic>>[];
    for (final state in _achievementStates(user)) {
      if (state.current < state.target || _unlockRow(user, state.key) != null) {
        continue;
      }
      final unlock = await db.insert('user_achievements', {
        'user_id': user['id'],
        'achievement_key': state.key,
        'unlocked_at': _iso(when),
      });
      await db.insert('action_records', {
        'user_id': user['id'],
        'action_id': null,
        'kind': 'achievement',
        'title': 'Conquista: ${state.title}',
        'category_label': 'Conquista',
        'icon': state.icon,
        'points': state.points,
        'base_points': state.points,
        'liters': 0,
        'quantity': 1,
        'notes': 'Bônus de conquista',
        'created_at': _iso(when),
        'local_date': Economy.dateKey(when),
      });
      if (!silent) {
        await notify(
          user,
          'conquista',
          'Novo selo desbloqueado!',
          'Você conquistou o selo "${state.title}" e ganhou +${state.points} pontos de bônus.',
          target: '/conquistas',
          at: when,
        );
      }
      unlockedNow.add(state.toJson(unlock));
    }
    return unlockedNow;
  }

  Future<List<Map<String, dynamic>>> _achievements(DbRow user) async {
    await syncAchievements(user);
    return [
      for (final state in _achievementStates(user))
        state.toJson(_unlockRow(user, state.key)),
    ];
  }

  // ---------------------------------------------------------------------------
  // Catálogo de ações e registros
  // ---------------------------------------------------------------------------

  ({int today, int week}) _usage(DbRow user, DbRow action, DateTime instant) {
    final today = Economy.dateKey(instant);
    final start = Economy.weekStartKey(instant);
    final end = Economy.weekEndKey(instant);
    var usedToday = 0;
    var usedWeek = 0;
    for (final row in db.table('action_records')) {
      if (row['user_id'] != user['id'] ||
          row['kind'] != 'action' ||
          row['action_id'] != action['id']) {
        continue;
      }
      final date = '${row['local_date']}';
      final quantity = _i(row['quantity'], 1);
      if (date == today) usedToday += quantity;
      if (date.compareTo(start) >= 0 && date.compareTo(end) <= 0) {
        usedWeek += quantity;
      }
    }
    return (today: usedToday, week: usedWeek);
  }

  int? _remaining(DbRow action, ({int today, int week}) usage) {
    final daily = action['daily_limit'] as int?;
    final weekly = action['weekly_limit'] as int?;
    int? remaining;
    if (daily != null) remaining = max(daily - usage.today, 0);
    if (weekly != null) {
      final left = max(weekly - usage.week, 0);
      remaining = remaining == null ? left : min(remaining, left);
    }
    return remaining;
  }

  /// Quantas outras pessoas registraram esta ação hoje.
  int _neighborsToday(DbRow action, DbRow user) {
    final today = Economy.dateKey(now);
    final people = <Object?>{};
    for (final row in db.table('action_records')) {
      if (row['kind'] == 'action' &&
          row['action_id'] == action['id'] &&
          row['local_date'] == today &&
          row['user_id'] != user['id']) {
        people.add(row['user_id']);
      }
    }
    return people.length;
  }

  Map<String, dynamic> _actionJson(DbRow row, DbRow user) {
    final usage = _usage(user, row, now);
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'category': row['category'],
      'categoryLabel': row['category_label'],
      'icon': row['icon'],
      'points': row['points'],
      'liters': row['liters'],
      'dailyLimit': row['daily_limit'],
      'weeklyLimit': row['weekly_limit'],
      'usedToday': usage.today,
      'usedThisWeek': usage.week,
      'remaining': _remaining(row, usage),
      'neighborsToday': _neighborsToday(row, user),
      'info': row['info'],
      'infoIcon': row['info_icon'],
      'tags': jsonDecode('${row['tags'] ?? '[]'}'),
      'footerInfo': row['footer_info'],
      'footerIcon': row['footer_icon'],
    };
  }

  List<Map<String, dynamic>> _listActions(
    DbRow user,
    Map<String, String> query,
  ) {
    final category = (query['category'] ?? '').toLowerCase();
    final search = (query['search'] ?? '').toLowerCase();
    final rows =
        db.table('actions').where((row) {
          if (category.isNotEmpty && category != 'all') {
            if ('${row['category']}'.toLowerCase() != category &&
                '${row['category_label']}'.toLowerCase() != category) {
              return false;
            }
          }
          if (search.isNotEmpty) {
            final haystack =
                '${row['title']} ${row['description']} ${row['tags']}'
                    .toLowerCase();
            if (!haystack.contains(search)) return false;
          }
          return true;
        }).toList();
    final actions = rows.map((row) => _actionJson(row, user)).toList();
    switch (query['sort']) {
      case 'points':
        actions.sort((a, b) => _i(b['points']).compareTo(_i(a['points'])));
      case 'alphabetical':
        actions.sort((a, b) => '${a['title']}'.compareTo('${b['title']}'));
      default:
        actions.sort((a, b) => _i(a['id']).compareTo(_i(b['id'])));
    }
    return actions;
  }

  Map<String, dynamic> _recordJson(DbRow row) => {
    'id': row['id'],
    'actionId': row['action_id'],
    'kind': row['kind'],
    'title': row['title'],
    'categoryLabel': row['category_label'],
    'icon': row['icon'],
    'points': row['points'],
    'basePoints': row['base_points'],
    'capped': _i(row['base_points']) > _i(row['points']),
    'liters': row['liters'],
    'quantity': row['quantity'],
    'notes': row['notes'],
    'dateTime': row['created_at'],
    'photo': _photoJson(row),
  };

  /// Foto de comprovação do registro: `null`, `{file}` ou `{asset}`.
  Map<String, dynamic>? _photoJson(DbRow record) {
    for (final photo in db.table('record_photos')) {
      if (photo['record_id'] != record['id'] ||
          photo['user_id'] != record['user_id']) {
        continue;
      }
      final asset = photo['asset'];
      if (asset is String && asset.isNotEmpty) return {'asset': asset};
      final file = photo['file'];
      if (file is String && file.isNotEmpty) return {'file': file};
    }
    return null;
  }

  /// Liga uma foto a um registro. É só um selo: não muda pontos, limites,
  /// desafios nem conquistas.
  Future<void> attachPhoto(
    DbRow record, {
    String? file,
    String? asset,
    DateTime? at,
  }) async {
    await db.insert('record_photos', {
      'record_id': record['id'],
      'user_id': record['user_id'],
      'file': file,
      'asset': asset,
      'created_at': _iso(at ?? now),
    });
  }

  /// Nome de arquivo simples, sem pastas (o app resolve a pasta na hora).
  static final RegExp _photoFilePattern = RegExp(
    r'^[A-Za-z0-9_-]{1,64}\.(jpg|png)$',
  );

  List<Map<String, dynamic>> _listRecords(
    DbRow user,
    Map<String, String> query,
  ) {
    final limit = (int.tryParse(query['limit'] ?? '') ?? 100).clamp(1, 500);
    final rows = _recordsOf(user['id'])..sort(_newestFirst);
    return rows.take(limit).map(_recordJson).toList();
  }

  /// Registra uma ação aplicando limites por ação e o teto semanal.
  ///
  /// [at] e [silent] existem para a carga dos dados de demonstração.
  Future<Map<String, dynamic>> registerAction(
    DbRow user,
    DbRow action, {
    int quantity = 1,
    String? notes,
    DateTime? at,
    bool silent = false,
    String? photoFile,
  }) async {
    final when = at ?? now;
    final usage = _usage(user, action, when);
    final daily = action['daily_limit'] as int?;
    final weekly = action['weekly_limit'] as int?;
    if (daily != null && usage.today + quantity > daily) {
      _fail(
        409,
        usage.today >= daily
            ? 'Você já registrou esta ação $daily ${daily == 1 ? 'vez' : 'vezes'} hoje. Ela volta a valer amanhã.'
            : 'Hoje você ainda pode registrar esta ação ${daily - usage.today} ${daily - usage.today == 1 ? 'vez' : 'vezes'}.',
      );
    }
    if (weekly != null && usage.week + quantity > weekly) {
      _fail(
        409,
        'Esta ação pode ser registrada $weekly ${weekly == 1 ? 'vez' : 'vezes'} por semana. Ela volta a valer na segunda-feira.',
      );
    }

    final basePoints = _i(action['points']) * quantity;
    final weekBefore = weekActionPoints(user['id'], when);
    final credited = max(0, min(basePoints, Economy.weeklyCap - weekBefore));

    final record = await db.insert('action_records', {
      'user_id': user['id'],
      'action_id': action['id'],
      'kind': 'action',
      'title': action['title'],
      'category_label': action['category_label'],
      'icon': action['icon'],
      'points': credited,
      'base_points': basePoints,
      'liters': _i(action['liters']) * quantity,
      'quantity': quantity,
      'notes': notes,
      'created_at': _iso(when),
      'local_date': Economy.dateKey(when),
    });
    if (photoFile != null) await attachPhoto(record, file: photoFile, at: when);

    final capReachedNow =
        weekBefore < Economy.weeklyCap &&
        weekBefore + credited >= Economy.weeklyCap;
    if (!silent) {
      await notify(
        user,
        'sistema',
        'Ação registrada!',
        credited == basePoints
            ? 'Você registrou "${action['title']}" e ganhou +$credited pontos.'
            : credited > 0
            ? 'Você registrou "${action['title']}" e ganhou +$credited pontos (o restante passou do teto da semana).'
            : 'Você registrou "${action['title']}". O teto semanal já foi atingido, então a ação conta para o histórico e os desafios, sem pontos.',
        target: '/meu-historico',
        at: when,
      );
      if (capReachedNow) {
        await notify(
          user,
          'sistema',
          'Teto semanal atingido',
          'Você chegou aos ${Economy.weeklyCap} pontos de ações desta semana. Continue registrando: as ações contam para desafios e conquistas, e os pontos voltam na segunda-feira.',
          target: '/progresso',
          at: when,
        );
      }
    }

    final challengeUpdates = await _advanceChallenges(
      user,
      action,
      quantity,
      when,
      silent: silent,
    );
    final unlocked = await syncAchievements(user, at: when, silent: silent);

    return {
      'record': _recordJson(record),
      'capReached': capReachedNow,
      'challengeUpdates': challengeUpdates,
      'newAchievements': unlocked,
    };
  }

  Future<Map<String, dynamic>> _createRecord(
    DbRow user,
    String id,
    Map<String, dynamic> data,
  ) async {
    final action = _requireRow('actions', id, 'Ação não encontrada.');
    final rawQuantity = data['quantity'] ?? 1;
    if (rawQuantity is! int || rawQuantity < 1 || rawQuantity > 50) {
      _fail(400, 'A quantidade deve ser um número inteiro a partir de 1.');
    }
    var notes = _clean(data['notes']);
    if (notes.length > 500) notes = notes.substring(0, 500);
    final photo = data['photo'];
    if (photo != null &&
        (photo is! String || !_photoFilePattern.hasMatch(photo))) {
      _fail(400, 'Não foi possível usar esta foto. Tente escolher outra.');
    }

    final result = await registerAction(
      user,
      action,
      quantity: rawQuantity,
      notes: notes.isEmpty ? null : notes,
      photoFile: photo as String?,
    );
    return {
      ...result,
      'summary': _summary(user),
      'achievements': await _achievements(user),
    };
  }

  // ---------------------------------------------------------------------------
  // Desafios
  // ---------------------------------------------------------------------------

  DbRow? _progressOf(DbRow user, DbRow challenge) {
    for (final row in db.table('challenge_progress')) {
      if (row['user_id'] == user['id'] &&
          row['challenge_id'] == challenge['id']) {
        return row;
      }
    }
    return null;
  }

  /// Fim do prazo pessoal: [duration_days] dias contando o dia em que entrou.
  DateTime? _challengeEnd(DbRow challenge, DbRow? progress) {
    final joinedAt = DateTime.tryParse('${progress?['joined_at'] ?? ''}');
    if (joinedAt == null) return null;
    return Economy.startOfLocalDay(
      joinedAt,
    ).add(Duration(days: _i(challenge['duration_days'], 7)));
  }

  bool _isExpired(DbRow challenge, DbRow? progress, DateTime instant) {
    if (progress == null ||
        !_flag(progress['joined']) ||
        _flag(progress['completed'])) {
      return false;
    }
    final end = _challengeEnd(challenge, progress);
    return end != null && !instant.isBefore(end);
  }

  Map<String, dynamic> _challengeJson(DbRow row, DbRow user, DateTime instant) {
    final progress = _progressOf(user, row);
    final joined = progress != null && _flag(progress['joined']);
    final completed = progress != null && _flag(progress['completed']);
    final expired = _isExpired(row, progress, instant);
    final end = _challengeEnd(row, progress);
    final target = max(1, _i(row['target_steps'], 1));
    final steps = joined ? _i(progress['completed_steps']) : 0;
    final duration = _i(row['duration_days'], 7);
    final daysLeft =
        joined && !completed && end != null
            ? max(0, (end.difference(instant).inMinutes / 1440).ceil())
            : duration;
    final participants =
        _i(row['base_participants']) +
        db
            .table('challenge_progress')
            .where((p) => p['challenge_id'] == row['id'] && _flag(p['joined']))
            .length;

    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'category': row['category'],
      'icon': row['icon'],
      'targetSteps': target,
      'stepMode': row['step_mode'],
      'pointsReward': row['points_reward'],
      'participants': participants,
      'durationDays': duration,
      'daysLeft': daysLeft,
      'isWeekly': _flag(row['is_weekly']),
      'joined': joined,
      'completedSteps': steps,
      'completed': completed,
      'expired': expired,
      'stepDoneToday':
          joined &&
          row['step_mode'] == 'days' &&
          progress['last_step_date'] == Economy.dateKey(instant),
      'endsAt': end == null ? null : _iso(end),
      'completedAt': progress?['completed_at'],
      'progress': min(steps / target, 1.0),
    };
  }

  List<Map<String, dynamic>> _listChallenges(DbRow user) {
    final rows = [...db.table('challenges')]..sort((a, b) {
      final weekly = _i(b['is_weekly']).compareTo(_i(a['is_weekly']));
      return weekly != 0 ? weekly : _i(a['id']).compareTo(_i(b['id']));
    });
    return [for (final row in rows) _challengeJson(row, user, now)];
  }

  /// Entra no desafio (ou recomeça um desafio vencido).
  Future<DbRow> joinChallenge(
    DbRow user,
    DbRow challenge, {
    DateTime? at,
  }) async {
    final when = at ?? now;
    final existing = _progressOf(user, challenge);
    if (existing == null) {
      return db.insert('challenge_progress', {
        'user_id': user['id'],
        'challenge_id': challenge['id'],
        'completed_steps': 0,
        'joined': 1,
        'completed': 0,
        'joined_at': _iso(when),
        'completed_at': null,
        'last_step_date': null,
      });
    }
    if (_isExpired(challenge, existing, when) || !_flag(existing['joined'])) {
      await db.update('challenge_progress', existing, {
        'completed_steps': 0,
        'joined': 1,
        'joined_at': _iso(when),
        'last_step_date': null,
      });
    }
    return existing;
  }

  Future<Map<String, dynamic>> _joinChallenge(DbRow user, String id) async {
    final challenge = _requireRow('challenges', id, 'Desafio não encontrado.');
    await joinChallenge(user, challenge);
    return {'challenge': _challengeJson(challenge, user, now)};
  }

  /// Avança os desafios em andamento da mesma categoria da ação registrada.
  Future<List<Map<String, dynamic>>> _advanceChallenges(
    DbRow user,
    DbRow action,
    int quantity,
    DateTime when, {
    bool silent = false,
  }) async {
    final updated = <Map<String, dynamic>>[];
    final today = Economy.dateKey(when);

    for (final challenge in db.table('challenges')) {
      if (challenge['category'] != action['category_label']) continue;
      final progress = _progressOf(user, challenge);
      if (progress == null ||
          !_flag(progress['joined']) ||
          _flag(progress['completed']) ||
          _isExpired(challenge, progress, when)) {
        continue;
      }

      final target = max(1, _i(challenge['target_steps'], 1));
      var steps = _i(progress['completed_steps']);
      if (challenge['step_mode'] == 'actions') {
        steps = min(steps + quantity, target);
      } else {
        if (progress['last_step_date'] == today) continue;
        steps = min(steps + 1, target);
      }
      final completed = steps >= target;
      await db.update('challenge_progress', progress, {
        'completed_steps': steps,
        'last_step_date': today,
        if (completed) 'completed': 1,
        if (completed) 'completed_at': _iso(when),
      });

      if (completed) {
        final reward = _i(challenge['points_reward']);
        await db.insert('action_records', {
          'user_id': user['id'],
          'action_id': null,
          'kind': 'challenge',
          'title': 'Desafio concluído: ${challenge['title']}',
          'category_label': challenge['category'],
          'icon': challenge['icon'],
          'points': reward,
          'base_points': reward,
          'liters': 0,
          'quantity': 1,
          'notes': 'Bônus de desafio coletivo',
          'created_at': _iso(when),
          'local_date': today,
        });
        if (!silent) {
          await notify(
            user,
            'desafio',
            'Desafio concluído!',
            'Você concluiu "${challenge['title']}" e ganhou +$reward pontos de bônus.',
            target: '/desafios',
            at: when,
          );
        }
      }
      updated.add(_challengeJson(challenge, user, when));
    }
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Comunidade
  // ---------------------------------------------------------------------------

  List<DbRow> _commentsOf(DbRow post) =>
      db
          .table('post_comments')
          .where((c) => c['post_id'] == post['id'])
          .toList()
        ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));

  Map<String, dynamic> _commentJson(DbRow row) => {
    'id': row['id'],
    'authorName': row['author_name'],
    'authorInitials': row['author_initials'],
    'content': row['content'],
    'timeLabel': relativeTime(row['created_at']),
    'createdAt': row['created_at'],
  };

  Map<String, dynamic> _postJson(DbRow row, DbRow user) {
    final likes =
        db.table('post_likes').where((l) => l['post_id'] == row['id']).toList();
    return {
      'id': row['id'],
      'authorName': row['author_name'],
      'authorInitials': row['author_initials'],
      'content': row['content'],
      'likes': _i(row['base_likes']) + likes.length,
      'likedByMe': likes.any((l) => l['user_id'] == user['id']),
      'isMine': row['user_id'] == user['id'],
      'timeLabel': relativeTime(row['created_at']),
      'createdAt': row['created_at'],
      'comments': _commentsOf(row).map(_commentJson).toList(),
    };
  }

  List<Map<String, dynamic>> _listPosts(DbRow user) {
    final rows = [...db.table('posts')]..sort(_newestFirst);
    return [for (final row in rows.take(100)) _postJson(row, user)];
  }

  Future<Map<String, dynamic>> _createPost(
    DbRow user,
    Map<String, dynamic> data,
  ) async {
    final content = _clean(data['content']);
    if (content.length < 3) {
      _fail(400, 'Escreva uma mensagem com pelo menos 3 caracteres.');
    }
    if (content.length > 1000) {
      _fail(400, 'A mensagem deve ter no máximo 1000 caracteres.');
    }
    final post = await db.insert('posts', {
      'user_id': user['id'],
      'author_name': user['name'],
      'author_initials': user['initials'],
      'content': content,
      'base_likes': 0,
      'created_at': _iso(now),
    });
    return {'post': _postJson(post, user)};
  }

  Future<Map<String, dynamic>> _toggleLike(DbRow user, String id) async {
    final post = _requireRow('posts', id, 'Publicação não encontrada.');
    bool mine(DbRow like) =>
        like['post_id'] == post['id'] && like['user_id'] == user['id'];
    if (db.table('post_likes').any(mine)) {
      await db.removeWhere('post_likes', mine);
    } else {
      await db.insert('post_likes', {
        'post_id': post['id'],
        'user_id': user['id'],
      });
    }
    final json = _postJson(post, user);
    return {'likes': json['likes'], 'likedByMe': json['likedByMe']};
  }

  Future<Map<String, dynamic>> _createComment(
    DbRow user,
    String id,
    Map<String, dynamic> data,
  ) async {
    final post = _requireRow('posts', id, 'Publicação não encontrada.');
    final content = _clean(data['content']);
    if (content.isEmpty) _fail(400, 'Escreva um comentário.');
    if (content.length > 500) {
      _fail(400, 'O comentário deve ter no máximo 500 caracteres.');
    }
    final comment = await db.insert('post_comments', {
      'post_id': post['id'],
      'user_id': user['id'],
      'author_name': user['name'],
      'author_initials': user['initials'],
      'content': content,
      'created_at': _iso(now),
    });
    final owner = db.byId('users', post['user_id']);
    if (owner != null && owner['id'] != user['id']) {
      await notify(
        owner,
        'comunidade',
        'Novo comentário',
        '${user['name']} comentou na sua publicação.',
        target: '/comunidade',
      );
    }
    return {'comment': _commentJson(comment)};
  }

  Future<Map<String, dynamic>> _deletePost(DbRow user, String id) async {
    final post = _requireRow('posts', id, 'Publicação não encontrada.');
    if (post['user_id'] != user['id']) {
      _fail(403, 'Você só pode excluir suas publicações.');
    }
    await db.removeWhere('post_comments', (c) => c['post_id'] == post['id']);
    await db.removeWhere('post_likes', (l) => l['post_id'] == post['id']);
    await db.removeWhere('posts', (p) => p['id'] == post['id']);
    return {'ok': true};
  }

  // ---------------------------------------------------------------------------
  // Bairro: estatísticas, meta coletiva, ranking, mapa e pontos de coleta
  // ---------------------------------------------------------------------------

  /// "Marina L.": primeiro nome e inicial do último, para listas públicas.
  static String shortName(Object? fullName) {
    final parts =
        '$fullName'
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }

  /// Registros de ações (de todos) na semana local que contém [instant].
  List<DbRow> _weekActions(DateTime instant) {
    final start = Economy.weekStartKey(instant);
    final end = Economy.weekEndKey(instant);
    return db.table('action_records').where((row) {
      if (row['kind'] != 'action') return false;
      final date = '${row['local_date']}';
      return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
    }).toList();
  }

  Map<String, dynamic> _communityStats(DbRow user) {
    final week = _weekActions(now);
    final today = Economy.dateKey(now);
    final pointsByUser = <Object?, int>{};
    for (final row in week) {
      pointsByUser[row['user_id']] =
          (pointsByUser[row['user_id']] ?? 0) + _i(row['points']);
    }
    final sevenDaysAgo = Economy.shiftDateKey(today, -6);
    final activePeople = <Object?>{};
    for (final row in db.table('action_records')) {
      if (row['kind'] == 'action' &&
          '${row['local_date']}'.compareTo(sevenDaysAgo) >= 0) {
        activePeople.add(row['user_id']);
      }
    }

    final ranked =
        pointsByUser.entries.toList()..sort((a, b) {
          final byPoints = b.value.compareTo(a.value);
          return byPoints != 0 ? byPoints : _i(a.key).compareTo(_i(b.key));
        });
    Map<String, dynamic> rankingEntry(int index) {
      final person = db.byId('users', ranked[index].key);
      final isMe = ranked[index].key == user['id'];
      // Quem desligou "aparecer no mapa" também não tem o bairro mostrado
      // aos outros no ranking.
      final showsNeighborhood =
          isMe || (person != null && _flag(person['privacy_location']));
      return {
        'position': index + 1,
        'name': isMe ? '${user['name']}' : shortName(person?['name']),
        'initials': person?['initials'] ?? '?',
        'neighborhood':
            showsNeighborhood ? (person ?? user)['neighborhood'] : null,
        'points': ranked[index].value,
        'isMe': isMe,
      };
    }

    final myIndex = ranked.indexWhere((entry) => entry.key == user['id']);

    Map<String, dynamic>? goalJson;
    final goals = db.table('community_goals').where((g) => _flag(g['active']));
    if (goals.isNotEmpty) {
      final goal = goals.first;
      final target = max(1, _i(goal['target_actions'], 1));
      final reset = Economy.nextWeekReset(now);
      goalJson = {
        'title': goal['title'],
        'description': goal['description'],
        'target': target,
        'current': week.length,
        'progress': min(week.length / target, 1.0),
        'reached': week.length >= target,
        'contributors': pointsByUser.length,
        'daysLeft': max(0, (reset.difference(now).inMinutes / 1440).ceil()),
        'endsAt': _iso(reset),
      };
    }

    return {
      'city': user['city'] ?? Places.defaultCity,
      'neighborhood': user['neighborhood'],
      'members': db.table('users').length,
      'activeNeighbors': activePeople.length,
      'actionsToday':
          db
              .table('action_records')
              .where((r) => r['kind'] == 'action' && r['local_date'] == today)
              .length,
      'actionsThisWeek': week.length,
      'litersThisWeek': week.fold<int>(0, (sum, r) => sum + _i(r['liters'])),
      'pointsThisWeek': week.fold<int>(0, (sum, r) => sum + _i(r['points'])),
      'goal': goalJson,
      'ranking': [
        for (var i = 0; i < ranked.length && i < 5; i++) rankingEntry(i),
      ],
      'myPosition': myIndex < 0 ? null : myIndex + 1,
      'myWeeklyPoints': pointsByUser[user['id']] ?? 0,
    };
  }

  Map<String, dynamic> _collectionPointJson(DbRow row, DbRow user) {
    final lat = (row['lat'] as num?)?.toDouble();
    final lon = (row['lon'] as num?)?.toDouble();
    final myLat = (user['lat'] as num?)?.toDouble();
    final myLon = (user['lon'] as num?)?.toDouble();
    return {
      'id': row['id'],
      'name': row['name'],
      'type': row['type'],
      'materials': jsonDecode('${row['materials'] ?? '[]'}'),
      'address': row['address'],
      'neighborhood': row['neighborhood'],
      'cep': row['cep'],
      'hours': row['hours'],
      'phone': row['phone'],
      'responsible': row['responsible'],
      'lat': lat,
      'lon': lon,
      'coordPrecision': row['coord_precision'],
      'sourceUrl': row['source_url'],
      'sourceDate': row['source_date'],
      'confidence': row['confidence'],
      'notes': row['notes'],
      // Distância a partir da posição aproximada do usuário.
      'distanceMeters':
          lat == null || lon == null || myLat == null || myLon == null
              ? null
              : Places.distanceMeters(myLat, myLon, lat, lon),
    };
  }

  List<Map<String, dynamic>> _listCollectionPoints(
    DbRow user,
    Map<String, String> query,
  ) {
    final type = (query['type'] ?? '').toLowerCase();
    final search = Places.normalize(query['search'] ?? '');
    final points = [
      for (final row in db.table('collection_points'))
        if ((type.isEmpty || '${row['type']}'.toLowerCase() == type) &&
            (search.isEmpty ||
                Places.normalize(
                  '${row['name']} ${row['address']} ${row['neighborhood']} ${row['materials']}',
                ).contains(search)))
          _collectionPointJson(row, user),
    ];
    points.sort((a, b) {
      final first = a['distanceMeters'] as int?;
      final second = b['distanceMeters'] as int?;
      if (first == null && second == null) {
        return '${a['name']}'.compareTo('${b['name']}');
      }
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });
    return points;
  }

  Map<String, dynamic> _communityMap(DbRow user) {
    final week = _weekActions(now);
    final pointsByUser = <Object?, int>{};
    for (final row in week) {
      pointsByUser[row['user_id']] =
          (pointsByUser[row['user_id']] ?? 0) + _i(row['points']);
    }
    final myLat = (user['lat'] as num?)?.toDouble();
    final myLon = (user['lon'] as num?)?.toDouble();
    return {
      'center': {
        'lat': myLat ?? Places.cityCenter.lat,
        'lon': myLon ?? Places.cityCenter.lon,
      },
      'me':
          myLat == null || myLon == null
              ? null
              : {
                'lat': myLat,
                'lon': myLon,
                'initials': user['initials'],
                'visible': _flag(user['privacy_location']),
              },
      // Só quem aceitou aparecer no mapa, sempre em posição aproximada.
      'neighbors': [
        for (final person in db.table('users'))
          if (person['id'] != user['id'] &&
              _flag(person['privacy_location']) &&
              person['lat'] != null &&
              person['lon'] != null)
            {
              'id': person['id'],
              'name': shortName(person['name']),
              'initials': person['initials'],
              'neighborhood': person['neighborhood'],
              'lat': person['lat'],
              'lon': person['lon'],
              'weeklyPoints': pointsByUser[person['id']] ?? 0,
            },
      ],
      'points': [
        for (final point in _listCollectionPoints(user, const {}))
          if (point['lat'] != null && point['lon'] != null) point,
      ],
      'attribution': '© colaboradores do OpenStreetMap',
    };
  }

  Map<String, dynamic>? _tipOfTheDay() {
    final tips = db.table('tips');
    if (tips.isEmpty) return null;
    final wall = Economy.wallClock(now);
    final dayOfYear = wall.difference(DateTime.utc(wall.year)).inDays;
    final tip = tips[dayOfYear % tips.length];
    return {
      'id': tip['id'],
      'text': tip['text'],
      'categoryLabel': tip['category_label'],
      'icon': tip['icon'],
    };
  }

  // ---------------------------------------------------------------------------
  // Recompensas e cupons
  // ---------------------------------------------------------------------------

  /// Janela, em dias, do limite de resgates por pessoa.
  static const int redeemLimitWindowDays = 30;

  DbRow _requireReward(String id) {
    final row = db.byId('rewards', id);
    if (row == null || !_flag(row['active'])) {
      _fail(404, 'Recompensa não encontrada.');
    }
    return row;
  }

  List<DbRow> _redemptionsOf(DbRow user) =>
      db.table('redemptions').where((r) => r['user_id'] == user['id']).toList()
        ..sort(_newestFirst);

  int _recentRedemptions(DbRow user, DbRow reward) {
    final since = now.subtract(const Duration(days: redeemLimitWindowDays));
    return db.table('redemptions').where((r) {
      if (r['user_id'] != user['id'] || r['reward_id'] != reward['id']) {
        return false;
      }
      final created = DateTime.tryParse('${r['created_at']}');
      return created != null && created.isAfter(since);
    }).length;
  }

  Map<String, dynamic> _rewardJson(DbRow row, DbRow user) {
    final partner = db.byId('partners', row['partner_id']);
    final limit = row['per_user_limit'] as int?;
    final mine = _recentRedemptions(user, row);
    return {
      'id': row['id'],
      'partnerId': row['partner_id'],
      'partnerName': partner?['name'] ?? '',
      'partnerDescription': partner?['description'],
      'partnerIcon': partner?['logo_icon'] ?? 'storefront',
      'partnerAddress': partner?['address'],
      'title': row['title'],
      'description': row['description'],
      'category': row['category'],
      'categoryLabel': row['category_label'],
      'icon': row['icon'],
      'pointsCost': row['points_cost'],
      'valueCents': row['value_cents'],
      'stock': row['stock'],
      'terms': row['terms'],
      'validityDays': row['validity_days'],
      'perUserLimit': limit,
      'redeemedByMe': mine,
      'limitReached': limit != null && mine >= limit,
      'isFeatured': _flag(row['is_featured']),
      'available': _i(row['stock']) > 0,
      'createdAt': row['created_at'],
    };
  }

  List<Map<String, dynamic>> _listRewards(DbRow user) {
    final rows =
        db.table('rewards').where((row) => _flag(row['active'])).toList()
          ..sort((a, b) {
            final featured = _i(
              b['is_featured'],
            ).compareTo(_i(a['is_featured']));
            return featured != 0
                ? featured
                : _i(a['points_cost']).compareTo(_i(b['points_cost']));
          });
    return [for (final row in rows) _rewardJson(row, user)];
  }

  String _redemptionStatus(DbRow row) {
    if (row['used_at'] != null) return 'used';
    final expires = DateTime.tryParse('${row['expires_at']}');
    if (expires != null && !now.isBefore(expires)) return 'expired';
    return 'active';
  }

  Map<String, dynamic> _redemptionJson(DbRow row) {
    final reward = db.byId('rewards', row['reward_id']);
    final partner = db.byId('partners', reward?['partner_id']);
    return {
      'id': row['id'],
      'rewardId': row['reward_id'],
      'rewardTitle': reward?['title'] ?? '',
      'rewardDescription': reward?['description'],
      'partnerName': partner?['name'] ?? '',
      'partnerAddress': partner?['address'],
      'icon': reward?['icon'] ?? 'redeem',
      'code': row['code'],
      'pointsSpent': row['points_spent'],
      'valueCents': reward?['value_cents'] ?? 0,
      'terms': reward?['terms'],
      'status': _redemptionStatus(row),
      'dateTime': row['created_at'],
      'expiresAt': row['expires_at'],
      'usedAt': row['used_at'],
    };
  }

  String _newCode() {
    for (var attempt = 0; attempt < 20; attempt++) {
      final code = 'ECO-${_randomHex(4).toUpperCase()}';
      if (!db.table('redemptions').any((r) => r['code'] == code)) return code;
    }
    _fail(500, 'Não foi possível gerar o código de resgate.');
  }

  /// Resgata uma recompensa. [at] e [silent] existem para a carga de demonstração.
  Future<DbRow> redeemReward(
    DbRow user,
    DbRow reward, {
    DateTime? at,
    bool silent = false,
  }) async {
    final when = at ?? now;
    if (_i(reward['stock']) <= 0) {
      _fail(409, 'Esta recompensa está esgotada.');
    }
    final limit = reward['per_user_limit'] as int?;
    if (limit != null && _recentRedemptions(user, reward) >= limit) {
      _fail(
        409,
        'Você já resgatou esta recompensa $limit ${limit == 1 ? 'vez' : 'vezes'} nos últimos $redeemLimitWindowDays dias.',
      );
    }
    final balance = _i(_summary(user)['points']);
    final cost = _i(reward['points_cost']);
    if (balance < cost) {
      _fail(
        409,
        'Pontos insuficientes. Você tem $balance e esta recompensa custa $cost.',
      );
    }

    await db.update('rewards', reward, {'stock': _i(reward['stock']) - 1});
    final code = _newCode();
    final redemption = await db.insert('redemptions', {
      'user_id': user['id'],
      'reward_id': reward['id'],
      'code': code,
      'points_spent': cost,
      'created_at': _iso(when),
      'expires_at': _iso(
        when.add(Duration(days: max(1, _i(reward['validity_days'], 30)))),
      ),
      'used_at': null,
    });
    if (!silent) {
      final partner = db.byId('partners', reward['partner_id']);
      await notify(
        user,
        'recompensa',
        'Resgate confirmado!',
        'Você resgatou "${reward['title']}" com ${partner?['name'] ?? 'o parceiro'}. Código: $code.',
        target: '/recompensas',
        at: when,
      );
    }
    return redemption;
  }

  Future<Map<String, dynamic>> _redeem(DbRow user, String id) async {
    final reward = _requireReward(id);
    final redemption = await redeemReward(user, reward);
    return {
      'redemption': _redemptionJson(redemption),
      'reward': _rewardJson(reward, user),
      'summary': _summary(user),
    };
  }

  /// Marca o cupom como usado. [pin] é o código do parceiro, digitado pelo
  /// atendente no balcão.
  Future<void> markRedemptionUsed(DbRow redemption, {DateTime? at}) async {
    await db.update('redemptions', redemption, {'used_at': _iso(at ?? now)});
  }

  Future<Map<String, dynamic>> _useRedemption(
    DbRow user,
    String id,
    Map<String, dynamic> data,
  ) async {
    final redemption = db.byId('redemptions', id);
    if (redemption == null || redemption['user_id'] != user['id']) {
      _fail(404, 'Cupom não encontrado.');
    }
    final status = _redemptionStatus(redemption);
    if (status == 'used') _fail(409, 'Este cupom já foi utilizado.');
    if (status == 'expired') _fail(409, 'Este cupom está vencido.');

    final reward = db.byId('rewards', redemption['reward_id']);
    final partner = db.byId('partners', reward?['partner_id']);
    final pin = _clean(data['pin']);
    if (partner == null || pin.isEmpty || pin != '${partner['pin']}') {
      _fail(403, 'Código do parceiro incorreto.');
    }

    await markRedemptionUsed(redemption);
    await notify(
      user,
      'recompensa',
      'Cupom utilizado',
      'O cupom ${redemption['code']} foi conferido por ${partner['name']}. Bom proveito!',
      target: '/recompensas',
    );
    return {'redemption': _redemptionJson(redemption)};
  }
}

/// Situação de uma conquista para um usuário.
class _AchievementState {
  const _AchievementState({
    required this.key,
    required this.icon,
    required this.title,
    required this.points,
    required this.description,
    required this.current,
    required this.target,
    this.unit,
    this.missing,
  });

  final String key;
  final String icon;
  final String title;
  final int points;
  final String description;
  final int current;
  final int target;
  final String? unit;
  final String? missing;

  Map<String, dynamic> toJson(DbRow? unlock) {
    final unlockedAt = DateTime.tryParse('${unlock?['unlocked_at'] ?? ''}');
    final isUnlocked = unlock != null;
    final shown = current > target ? target : current;
    return {
      'key': key,
      'icon': icon,
      'title': title,
      'points': points,
      'description': description,
      'current': isUnlocked ? target : shown,
      'target': target,
      'missing': isUnlocked ? null : missing,
      'isUnlocked': isUnlocked,
      'progress': isUnlocked ? 1.0 : (shown / target).clamp(0.0, 1.0),
      'unlockedAt': unlock?['unlocked_at'],
      'unlockedOn': unlockedAt == null ? null : Economy.longDate(unlockedAt),
      'progressLabel':
          isUnlocked
              ? null
              : '$shown de $target${unit == null ? '' : ' $unit'}',
    };
  }
}
