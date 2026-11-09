import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Uma linha de tabela, com as mesmas colunas do banco do servidor.
typedef DbRow = Map<String, Object?>;

/// Esquema do banco local: mesmas tabelas do `eco-backend/src/db.js`.
///
/// Usado para criar as tabelas no SQLite do aparelho e para validar o
/// armazenamento em memória dos testes.
const Map<String, String> localSchema = {
  'users': '''
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    neighborhood TEXT NOT NULL,
    cep TEXT,
    street TEXT,
    number TEXT,
    complement TEXT,
    city TEXT,
    state TEXT,
    lat REAL,
    lon REAL,
    initials TEXT NOT NULL,
    monthly_goal INTEGER NOT NULL DEFAULT 17,
    weekly_goal INTEGER NOT NULL DEFAULT 5,
    notifications_enabled INTEGER NOT NULL DEFAULT 1,
    reminders_enabled INTEGER NOT NULL DEFAULT 1,
    privacy_profile INTEGER NOT NULL DEFAULT 1,
    privacy_location INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL''',
  'password_resets': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    used INTEGER NOT NULL DEFAULT 0''',
  'actions': '''
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    category_label TEXT NOT NULL,
    icon TEXT NOT NULL,
    points INTEGER NOT NULL,
    liters INTEGER NOT NULL DEFAULT 0,
    daily_limit INTEGER,
    weekly_limit INTEGER,
    info TEXT,
    info_icon TEXT,
    tags TEXT NOT NULL DEFAULT '[]',
    footer_info TEXT,
    footer_icon TEXT''',
  'action_records': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    action_id INTEGER,
    kind TEXT NOT NULL DEFAULT 'action',
    title TEXT NOT NULL,
    category_label TEXT NOT NULL,
    icon TEXT NOT NULL,
    points INTEGER NOT NULL,
    base_points INTEGER NOT NULL,
    liters INTEGER NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TEXT NOT NULL,
    local_date TEXT NOT NULL''',
  'notifications': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target TEXT,
    read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL''',
  'challenges': '''
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    icon TEXT NOT NULL,
    target_steps INTEGER NOT NULL,
    step_mode TEXT NOT NULL DEFAULT 'days',
    points_reward INTEGER NOT NULL,
    base_participants INTEGER NOT NULL DEFAULT 0,
    duration_days INTEGER NOT NULL DEFAULT 7,
    is_weekly INTEGER NOT NULL DEFAULT 0''',
  'challenge_progress': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    challenge_id INTEGER NOT NULL,
    completed_steps INTEGER NOT NULL DEFAULT 0,
    joined INTEGER NOT NULL DEFAULT 0,
    completed INTEGER NOT NULL DEFAULT 0,
    joined_at TEXT,
    completed_at TEXT,
    last_step_date TEXT''',
  'partners': '''
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    logo_icon TEXT NOT NULL DEFAULT 'storefront',
    address TEXT,
    pin TEXT NOT NULL,
    created_at TEXT NOT NULL''',
  'rewards': '''
    id INTEGER PRIMARY KEY,
    partner_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    category_label TEXT NOT NULL,
    icon TEXT NOT NULL,
    points_cost INTEGER NOT NULL,
    value_cents INTEGER NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    terms TEXT,
    validity_days INTEGER NOT NULL DEFAULT 30,
    per_user_limit INTEGER,
    is_featured INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL''',
  'redemptions': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    reward_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    points_spent INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT''',
  'posts': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    author_name TEXT NOT NULL,
    author_initials TEXT NOT NULL,
    content TEXT NOT NULL,
    base_likes INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL''',
  'post_likes': '''
    id INTEGER PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL''',
  'post_comments': '''
    id INTEGER PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER,
    author_name TEXT NOT NULL,
    author_initials TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TEXT NOT NULL''',
  'user_achievements': '''
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    achievement_key TEXT NOT NULL,
    unlocked_at TEXT NOT NULL''',
  'collection_points': '''
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    materials TEXT NOT NULL DEFAULT '[]',
    address TEXT,
    neighborhood TEXT,
    cep TEXT,
    hours TEXT,
    phone TEXT,
    responsible TEXT,
    lat REAL,
    lon REAL,
    coord_precision TEXT,
    source_url TEXT,
    source_date TEXT,
    confidence TEXT,
    notes TEXT''',
  'community_goals': '''
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    target_actions INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 1''',
  'tips': '''
    id INTEGER PRIMARY KEY,
    text TEXT NOT NULL,
    category_label TEXT NOT NULL,
    icon TEXT NOT NULL''',
};

/// Onde o banco local é gravado.
abstract class LocalStore {
  /// Lê todas as tabelas.
  Future<Map<String, List<DbRow>>> load();

  Future<void> insert(String table, DbRow row);

  Future<void> update(String table, int id, DbRow values);

  Future<void> delete(String table, int id);

  /// Substitui todo o conteúdo do banco de uma vez (carga inicial e restauração).
  Future<void> replaceAll(Map<String, List<DbRow>> tables);
}

/// Armazenamento só em memória: usado nos testes.
class MemoryStore implements LocalStore {
  @override
  Future<Map<String, List<DbRow>>> load() async => {};

  @override
  Future<void> insert(String table, DbRow row) async {}

  @override
  Future<void> update(String table, int id, DbRow values) async {}

  @override
  Future<void> delete(String table, int id) async {}

  @override
  Future<void> replaceAll(Map<String, List<DbRow>> tables) async {}
}

/// Armazenamento em `shared_preferences`, para as plataformas sem SQLite
/// (navegador). Guarda o banco inteiro como um documento JSON.
class PrefsStore implements LocalStore {
  static const String _key = 'eco_local_db_v1';

  final Map<String, List<DbRow>> _data = {};
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<Map<String, List<DbRow>>> load() async {
    final raw = (await _instance).getString(_key);
    _data.clear();
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((table, rows) {
          _data[table] = [
            for (final row in rows as List) DbRow.from(row as Map),
          ];
        });
      } catch (_) {
        _data.clear();
      }
    }
    return {
      for (final entry in _data.entries)
        entry.key: [for (final row in entry.value) DbRow.from(row)],
    };
  }

  Future<void> _save() async {
    await (await _instance).setString(_key, jsonEncode(_data));
  }

  @override
  Future<void> insert(String table, DbRow row) async {
    _data.putIfAbsent(table, () => []).add(DbRow.from(row));
    await _save();
  }

  @override
  Future<void> update(String table, int id, DbRow values) async {
    for (final row in _data[table] ?? const <DbRow>[]) {
      if (row['id'] == id) row.addAll(values);
    }
    await _save();
  }

  @override
  Future<void> delete(String table, int id) async {
    _data[table]?.removeWhere((row) => row['id'] == id);
    await _save();
  }

  @override
  Future<void> replaceAll(Map<String, List<DbRow>> tables) async {
    _data
      ..clear()
      ..addAll({
        for (final entry in tables.entries)
          entry.key: [for (final row in entry.value) DbRow.from(row)],
      });
    await _save();
  }
}

/// Banco local em memória com gravação imediata no [LocalStore].
///
/// As regras de negócio trabalham sobre as listas em memória; cada alteração
/// é gravada no armazenamento antes de a operação terminar.
class LocalDatabase {
  LocalDatabase(this.store);

  final LocalStore store;

  final Map<String, List<DbRow>> _tables = {
    for (final name in localSchema.keys) name: <DbRow>[],
  };
  final Map<String, int> _nextId = {};
  bool _bulk = false;
  bool _opened = false;

  bool get isOpen => _opened;

  bool get isEmpty => _tables['users']!.isEmpty;

  Future<void> open() async {
    final data = await store.load();
    for (final name in localSchema.keys) {
      _tables[name]!
        ..clear()
        ..addAll(data[name] ?? const <DbRow>[]);
    }
    _recountIds();
    _opened = true;
  }

  void _recountIds() {
    for (final name in localSchema.keys) {
      var max = 0;
      for (final row in _tables[name]!) {
        final id = row['id'];
        if (id is int && id > max) max = id;
      }
      _nextId[name] = max + 1;
    }
  }

  List<DbRow> table(String name) => _tables[name]!;

  DbRow? byId(String name, Object? id) {
    final wanted = id is int ? id : int.tryParse('$id');
    if (wanted == null) return null;
    for (final row in _tables[name]!) {
      if (row['id'] == wanted) return row;
    }
    return null;
  }

  Future<DbRow> insert(String name, DbRow values) async {
    final id = _nextId[name]!;
    _nextId[name] = id + 1;
    final row = <String, Object?>{'id': id, ...values};
    _tables[name]!.add(row);
    if (!_bulk) await store.insert(name, row);
    return row;
  }

  Future<void> update(String name, DbRow row, DbRow values) async {
    row.addAll(values);
    if (!_bulk) await store.update(name, row['id'] as int, values);
  }

  Future<void> removeWhere(String name, bool Function(DbRow row) test) async {
    final removed = _tables[name]!.where(test).toList();
    _tables[name]!.removeWhere(test);
    if (_bulk) return;
    for (final row in removed) {
      await store.delete(name, row['id'] as int);
    }
  }

  /// Executa [body] sem gravar a cada linha e grava tudo de uma vez no fim.
  Future<void> bulk(Future<void> Function() body) async {
    _bulk = true;
    try {
      await body();
    } finally {
      _bulk = false;
    }
    await store.replaceAll(_tables);
  }

  /// Apaga todos os dados.
  Future<void> wipe() async {
    for (final rows in _tables.values) {
      rows.clear();
    }
    _recountIds();
    await store.replaceAll(_tables);
  }
}
