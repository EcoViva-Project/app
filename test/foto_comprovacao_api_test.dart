import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/api_exception.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/photo_proof.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_photos.dart';
import 'support/local_app.dart';

/// Quarta-feira, 11/11/2026, 15:00 em Brasília (dia da feira).
final DateTime _wednesday = DateTime.utc(2026, 11, 11, 18);

class _Api {
  _Api() : db = LocalDatabase(MemoryStore()) {
    api = LocalApi(db, clock: () => _wednesday, random: Random(7));
  }

  final LocalDatabase db;
  late final LocalApi api;
  String? token;

  Future<dynamic> call(String method, String path, {Object? body}) =>
      api.handle(method, path, body: body, token: token);

  Future<void> loginDemo() async {
    final data = await api.handle(
      'POST',
      '/auth/login',
      body: {'email': LocalSeed.demoEmail, 'password': LocalSeed.demoPassword},
    );
    token = data['token'] as String;
  }

  Future<Map<String, dynamic>> register(int id, {String? photo}) async =>
      await call(
            'POST',
            '/actions/$id/records',
            body: {'quantity': 1, if (photo != null) 'photo': photo},
          )
          as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> records() async => [
    for (final item in (await call('GET', '/records'))['records'] as List)
      item as Map<String, dynamic>,
  ];
}

/// A mesma estrutura sem as chaves `photo`, para comparar respostas.
Object? _withoutPhoto(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != 'photo') entry.key: _withoutPhoto(entry.value),
    };
  }
  if (value is List) return value.map(_withoutPhoto).toList();
  return value;
}

void main() {
  group('foto de comprovação na API local', () {
    test(
      'registro com foto devolve a foto na resposta e no histórico',
      () async {
        final h = _Api();
        await h.loginDemo();

        final result = await h.register(5, photo: 'foto_teste_1.jpg');
        final record = result['record'] as Map<String, dynamic>;
        expect(record['photo'], {'file': 'foto_teste_1.jpg'});

        final history = await h.records();
        final saved = history.firstWhere((r) => r['id'] == record['id']);
        expect(saved['photo'], {'file': 'foto_teste_1.jpg'});
      },
    );

    test('registro sem foto devolve photo nulo', () async {
      final h = _Api();
      await h.loginDemo();

      final result = await h.register(5);
      final record = result['record'] as Map<String, dynamic>;
      expect(record.containsKey('photo'), isTrue);
      expect(record['photo'], isNull);

      final history = await h.records();
      expect(
        history.firstWhere((r) => r['id'] == record['id'])['photo'],
        isNull,
      );
    });

    test('nome de foto inválido é recusado e nada é registrado', () async {
      final h = _Api();
      await h.loginDemo();
      final before = (await h.records()).length;

      for (final bad in ['../ecoviva.db', 'pasta/foto.jpg', 'foto.exe', 42]) {
        await expectLater(
          h.call(
            'POST',
            '/actions/5/records',
            body: {'quantity': 1, 'photo': bad},
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );
      }
      expect((await h.records()).length, before);
    });

    test(
      'pontos, teto, limites, desafios e conquistas não mudam com a foto',
      () async {
        final semFoto = _Api();
        final comFoto = _Api();
        await semFoto.loginDemo();
        await comFoto.loginDemo();

        // Ações variadas, incluindo uma que esbarra no limite do dia (5 duas
        // vezes) e o suficiente para chegar ao teto semanal.
        const sequence = [1, 3, 4, 5, 5, 6];
        var n = 0;
        for (final id in sequence) {
          n++;
          Object? a;
          Object? b;
          try {
            a = await semFoto.register(id);
          } on ApiException catch (error) {
            a = 'erro ${error.statusCode}: ${error.message}';
          }
          try {
            b = await comFoto.register(id, photo: 'foto_$n.jpg');
          } on ApiException catch (error) {
            b = 'erro ${error.statusCode}: ${error.message}';
          }
          expect(
            jsonEncode(_withoutPhoto(b)),
            jsonEncode(_withoutPhoto(a)),
            reason: 'ação $id',
          );
          if (b is Map) {
            expect(b['record']['photo'], {'file': 'foto_$n.jpg'});
          }
        }

        final progressA = await semFoto.call('GET', '/progress');
        final progressB = await comFoto.call('GET', '/progress');
        expect(jsonEncode(progressB), jsonEncode(progressA));
        final challengesA = await semFoto.call('GET', '/challenges');
        final challengesB = await comFoto.call('GET', '/challenges');
        expect(jsonEncode(challengesB), jsonEncode(challengesA));
        // Os históricos só diferem nas fotos.
        expect(
          jsonEncode(_withoutPhoto(await comFoto.records())),
          jsonEncode(_withoutPhoto(await semFoto.records())),
        );
      },
    );

    test('a demonstração traz 3 registros com foto de exemplo', () async {
      final h = _Api();
      await h.loginDemo();

      final withPhoto = [
        for (final record in await h.records())
          if (record['photo'] != null) record,
      ];
      expect(withPhoto, hasLength(3));
      final assets = {
        for (final record in withPhoto)
          (record['photo'] as Map)['asset'] as String,
      };
      expect(assets, LocalSeed.examplePhotos.values.toSet());
      for (final record in withPhoto) {
        final asset = (record['photo'] as Map)['asset'] as String;
        expect(
          LocalSeed.examplePhotos[record['actionId']],
          asset,
          reason: 'cada foto fica na ação certa',
        );
        // O arquivo existe e é leve.
        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: asset);
        expect(file.lengthSync(), lessThan(80 * 1024), reason: asset);
      }
      // Registros recentes: dos últimos dois dias.
      for (final record in withPhoto) {
        final when = DateTime.parse(record['dateTime'] as String);
        expect(_wednesday.difference(when).inHours, lessThan(48));
      }
    });

    test('quem não é dono não vê a foto', () async {
      final h = _Api();
      final created = await h.api.handle(
        'POST',
        '/auth/register',
        body: {
          'name': 'Pessoa Visitante',
          'email': 'visitante@exemplo.com',
          'password': 'segredo123',
        },
      );
      h.token = created['token'] as String;
      await h.register(5, photo: 'foto_visitante.jpg');
      expect(
        (await h.records()).where((r) => r['photo'] != null),
        hasLength(1),
      );

      await h.loginDemo();
      final files = [
        for (final record in await h.records())
          if (record['photo'] is Map &&
              (record['photo'] as Map)['file'] != null)
            record,
      ];
      expect(files, isEmpty);
    });

    test('restaurar a demonstração apaga as fotos tiradas', () async {
      final h = _Api();
      await h.loginDemo();
      await h.register(5, photo: 'foto_teste_1.jpg');
      expect(h.db.table('record_photos'), hasLength(4));

      await h.api.handle('POST', '/demo/reset');
      await h.loginDemo();

      expect(h.db.table('record_photos'), hasLength(3));
      expect(
        h.db.table('record_photos').every((row) => row['file'] == null),
        isTrue,
      );
      final records = await h.records();
      expect(records.where((r) => r['photo'] != null), hasLength(3));
    });
  });

  group('foto de comprovação nos serviços', () {
    late FakePhotoFileStore files;

    setUp(() async {
      await useLocalBackend();
      files = FakePhotoFileStore();
      PhotoProof.files = files;
    });

    tearDown(restorePhotoProof);

    test('a última submissão traz a foto', () async {
      await signInDemo();
      final result = await ActionHistoryService.instance.submitAction(
        actionId: 5,
        quantity: 1,
        photo: 'foto_teste_1.jpg',
      );
      expect(result.record.photo?.file, 'foto_teste_1.jpg');
      expect(
        ActionHistoryService.instance.lastSubmission?.record.photo?.file,
        'foto_teste_1.jpg',
      );
      expect(
        ActionHistoryService.instance.records.first.photo?.file,
        'foto_teste_1.jpg',
      );
    });

    test('Restaurar demonstração apaga os arquivos de foto', () async {
      await signInDemo();
      await AuthService.instance.resetDemo();
      expect(files.deleteAllCalls, 1);
      expect(AuthService.instance.isAuthenticated, isFalse);
    });
  });
}
