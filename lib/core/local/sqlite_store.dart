import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_store.dart';

/// Banco SQLite gravado no próprio aparelho (Android e iOS).
///
/// O arquivo fica na pasta de bancos do aplicativo e sobrevive a fechar e
/// reabrir o app. É apagado apenas ao desinstalar o app ou ao limpar os dados.
class SqliteStore implements LocalStore {
  static const String fileName = 'ecoviva.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), fileName);
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        for (final entry in localSchema.entries) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS ${entry.key} (${entry.value})',
          );
        }
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<Map<String, List<DbRow>>> load() async {
    final db = await _open();
    final result = <String, List<DbRow>>{};
    for (final table in localSchema.keys) {
      final rows = await db.query(table, orderBy: 'id ASC');
      result[table] = [for (final row in rows) DbRow.from(row)];
    }
    return result;
  }

  @override
  Future<void> insert(String table, DbRow row) async {
    final db = await _open();
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> update(String table, int id, DbRow values) async {
    final db = await _open();
    await db.update(table, values, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> delete(String table, int id) async {
    final db = await _open();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> replaceAll(Map<String, List<DbRow>> tables) async {
    final db = await _open();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final table in localSchema.keys) {
        batch.delete(table);
        for (final row in tables[table] ?? const <DbRow>[]) {
          batch.insert(table, row);
        }
      }
      await batch.commit(noResult: true);
    });
  }
}
