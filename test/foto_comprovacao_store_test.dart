import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:eco_app/core/services/photo_file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _wednesday = DateTime.utc(2026, 11, 11, 18);

/// Armazenamento que devolve um retrato fixo (como um banco antigo).
class _SnapshotStore extends MemoryStore {
  _SnapshotStore(this.snapshot);

  final Map<String, List<DbRow>> snapshot;

  @override
  Future<Map<String, List<DbRow>>> load() async => snapshot;
}

Future<String> _login(LocalApi api) async {
  final data = await api.handle(
    'POST',
    '/auth/login',
    body: {'email': LocalSeed.demoEmail, 'password': LocalSeed.demoPassword},
  );
  return data['token'] as String;
}

void main() {
  group('bancos antigos, sem a tabela de fotos', () {
    test('um retrato sem record_photos abre e aceita fotos novas', () async {
      // Monta um banco completo e tira a tabela nova, como no celular que
      // ainda tem a versão anterior do app.
      final full = LocalDatabase(MemoryStore());
      await LocalApi(
        full,
        clock: () => _wednesday,
        random: Random(7),
      ).ensureReady();
      final old = <String, List<DbRow>>{
        for (final name in localSchema.keys)
          if (name != 'record_photos')
            name: [for (final row in full.table(name)) DbRow.from(row)],
      };

      final db = LocalDatabase(_SnapshotStore(old));
      final api = LocalApi(db, clock: () => _wednesday, random: Random(7));
      await api.ensureReady();
      expect(db.table('record_photos'), isEmpty);
      expect(db.table('action_records'), isNotEmpty, reason: 'dados mantidos');

      final token = await _login(api);
      final records = await api.handle('GET', '/records', token: token);
      expect(
        (records['records'] as List).every((r) => r['photo'] == null),
        isTrue,
      );
      final result = await api.handle(
        'POST',
        '/actions/5/records',
        body: {'quantity': 1, 'photo': 'foto_teste_1.jpg'},
        token: token,
      );
      expect(result['record']['photo'], {'file': 'foto_teste_1.jpg'});
      expect(db.table('record_photos'), hasLength(1));
    });

    test('o JSON do navegador sem a tabela nova também abre', () async {
      // Grava um banco pelo PrefsStore e apaga a tabela nova do JSON salvo.
      SharedPreferences.setMockInitialValues({});
      final first = LocalDatabase(PrefsStore());
      await LocalApi(
        first,
        clock: () => _wednesday,
        random: Random(7),
      ).ensureReady();
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().single;
      final saved = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      expect(saved.containsKey('record_photos'), isTrue);
      saved.remove('record_photos');
      await prefs.setString(key, jsonEncode(saved));

      final db = LocalDatabase(PrefsStore());
      final api = LocalApi(db, clock: () => _wednesday, random: Random(7));
      await api.ensureReady();
      expect(db.table('record_photos'), isEmpty);
      expect(db.table('users'), isNotEmpty, reason: 'não recriou o banco');

      final token = await _login(api);
      await api.handle(
        'POST',
        '/actions/5/records',
        body: {'quantity': 1, 'photo': 'foto_teste_1.jpg'},
        token: token,
      );

      // Reabrindo, a foto continua lá.
      final reopened = LocalDatabase(PrefsStore());
      await reopened.open();
      expect(reopened.table('record_photos'), hasLength(1));
      expect(
        reopened.table('record_photos').single['file'],
        'foto_teste_1.jpg',
      );
    });
  });

  group('pasta de fotos do aparelho', () {
    late Directory temp;
    late DocumentsPhotoFileStore store;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('eco_fotos_');
      store = DocumentsPhotoFileStore(baseDirectory: () async => temp);
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('copia a foto, guarda só o nome e encontra de novo', () async {
      final source = File('${temp.path}/da_camera.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);
      final name = await store.save(source.path);

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(r'\')));
      expect(DocumentsPhotoFileStore.validName.hasMatch(name), isTrue);
      final found = await store.find(name);
      expect(found, isNotNull);
      expect(found!.readAsBytesSync(), [1, 2, 3, 4]);
      expect(found.parent.path, endsWith('fotos'));

      final other = await store.save(source.path);
      expect(other, isNot(name), reason: 'cada foto tem um nome novo');
    });

    test('arquivo sumido ou nome estranho não quebra nada', () async {
      expect(await store.find('foto_que_nao_existe.jpg'), isNull);
      expect(await store.find('../segredo.jpg'), isNull);
      await store.delete('foto_que_nao_existe.jpg');
      await store.deleteAll(); // pasta ainda nem existe
    });

    test('apagar uma foto e apagar todas', () async {
      final source = File('${temp.path}/da_galeria.png')
        ..writeAsBytesSync([9, 9]);
      final a = await store.save(source.path);
      final b = await store.save(source.path);
      expect(a, endsWith('.png'));

      await store.delete(a);
      expect(await store.find(a), isNull);
      expect(await store.find(b), isNotNull);

      await store.deleteAll();
      expect(await store.find(b), isNull);
      expect(Directory('${temp.path}/fotos').existsSync(), isFalse);
      expect(source.existsSync(), isTrue, reason: 'o original não é tocado');
    });
  });
}
