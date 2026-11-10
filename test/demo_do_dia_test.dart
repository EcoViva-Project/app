import 'dart:math';

import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/local/economy.dart';
import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/my_location_service.dart';
import 'package:eco_app/features/inicio/presentation/widgets/home_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_locator.dart';
import 'support/local_app.dart';

/// Horário de Brasília (UTC-3) como instante real.
DateTime _brasilia(int year, int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(year, month, day, hour + 3, minute);

/// Armazenamento que devolve um retrato fixo (como um banco antigo).
class _SnapshotStore extends MemoryStore {
  _SnapshotStore(this.snapshot);

  final Map<String, List<DbRow>> snapshot;

  @override
  Future<Map<String, List<DbRow>>> load() async => snapshot;
}

class _Api {
  _Api(this.clock, {LocalStore? store})
    : db = LocalDatabase(store ?? MemoryStore()) {
    api = LocalApi(db, clock: () => clock, random: Random(7));
  }

  DateTime clock;
  final LocalDatabase db;
  late final LocalApi api;

  Future<Map<String, dynamic>> login([
    String email = LocalSeed.demoEmail,
    String password = LocalSeed.demoPassword,
  ]) async {
    final data = await api.handle(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Usuário devolvido pelo login, por `auth/me` e por `users/me`.
  Future<List<Map<String, dynamic>>> users() async {
    final data = await login();
    final token = data['token'] as String;
    final me = await api.handle('GET', '/auth/me', token: token);
    final full = await api.handle('GET', '/users/me', token: token);
    return [
      Map<String, dynamic>.from(data['user'] as Map),
      Map<String, dynamic>.from(me['user'] as Map),
      Map<String, dynamic>.from(full['user'] as Map),
    ];
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  await tester.pump();
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await _settle(tester);
}

String _path() {
  final config = AppRouter.router.routerDelegate.currentConfiguration;
  return config.isEmpty ? config.uri.path : config.last.matchedLocation;
}

final Finder _banner = find.textContaining('Os dados de demonstração são');

void main() {
  group('dia da demonstração (API)', () {
    test('recém-criada: nunca desatualizada, a qualquer hora do dia', () async {
      final hours = [
        _brasilia(2026, 11, 11, 0, 0), // meia-noite em ponto
        _brasilia(2026, 11, 11, 0, 1), // logo depois da meia-noite
        _brasilia(2026, 11, 11, 9),
        _brasilia(2026, 11, 11, 15),
        _brasilia(2026, 11, 11, 21), // já é outro dia em UTC
        _brasilia(2026, 11, 11, 23, 59), // fim da noite
      ];
      for (final now in hours) {
        final h = _Api(now);
        for (final user in await h.users()) {
          expect(user['demoSeededOn'], '2026-11-11', reason: '$now');
          expect(user['demoStale'], isFalse, reason: '$now');
        }
        expect(
          h.db.table('app_meta').single,
          containsPair('value', Economy.dateKey(now)),
        );
      }
    });

    test('no dia seguinte: desatualizada, com a data', () async {
      final h = _Api(_brasilia(2026, 11, 9, 22));
      await h.api.ensureReady();

      h.clock = _brasilia(2026, 11, 9, 23, 59);
      expect((await h.users()).first['demoStale'], isFalse);

      h.clock = _brasilia(2026, 11, 10, 0, 1);
      for (final user in await h.users()) {
        expect(user['demoSeededOn'], '2026-11-09');
        expect(user['demoStale'], isTrue);
      }
    });

    test('restaurar grava o dia de hoje e tira o aviso', () async {
      final h = _Api(_brasilia(2026, 11, 9, 10));
      await h.api.ensureReady();
      h.clock = _brasilia(2026, 11, 11, 8);
      expect((await h.users()).first['demoStale'], isTrue);

      await h.api.handle('POST', '/demo/reset');
      final user = (await h.users()).first;
      expect(user['demoSeededOn'], '2026-11-11');
      expect(user['demoStale'], isFalse);
      expect(h.db.table('app_meta'), hasLength(1));
    });

    test('banco antigo, sem a tabela nova: abre e conta como desatualizado, '
        'sem data', () async {
      final now = _brasilia(2026, 11, 11, 15);
      final full = _Api(now);
      await full.api.ensureReady();
      final old = <String, List<DbRow>>{
        for (final name in localSchema.keys)
          if (name != 'app_meta')
            name: [for (final row in full.db.table(name)) DbRow.from(row)],
      };

      final h = _Api(now, store: _SnapshotStore(old));
      await h.api.ensureReady();
      expect(h.db.table('app_meta'), isEmpty);
      expect(
        h.db.table('action_records'),
        isNotEmpty,
        reason: 'dados mantidos',
      );
      for (final user in await h.users()) {
        expect(user.containsKey('demoSeededOn'), isTrue);
        expect(user['demoSeededOn'], isNull);
        expect(user['demoStale'], isTrue);
      }
    });

    test('outras contas nunca recebem o aviso', () async {
      final h = _Api(_brasilia(2026, 11, 9, 10));
      final created = await h.api.handle(
        'POST',
        '/auth/register',
        body: {
          'name': 'Ana Souza',
          'email': 'ana@test.app',
          'password': 'segredo123',
          'neighborhood': 'Centro',
        },
      );
      expect(created['user'].containsKey('demoStale'), isFalse);

      h.clock = _brasilia(2026, 11, 12, 10); // demonstração já é de outro dia
      final token = created['token'] as String;
      final login = await h.login('ana@test.app', 'segredo123');
      final me = await h.api.handle('GET', '/auth/me', token: token);
      for (final user in [login['user'] as Map, me['user'] as Map]) {
        expect(user.containsKey('demoStale'), isFalse);
        expect(user.containsKey('demoSeededOn'), isFalse);
      }
    });
  });

  group('aviso na Início', () {
    setUp(() async {
      await useLocalBackend();
    });

    Future<void> openApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const EcoApp());
      await tester.pump();
      await _open(tester, '/inicio');
    }

    /// Cria a demonstração hoje (11/11) e entra de novo no dia seguinte.
    Future<void> signInNextDay() async {
      await signInDemo();
      testClock = demoNow.add(const Duration(days: 1));
      await signInDemo();
    }

    testWidgets('demonstração de hoje: sem aviso', (tester) async {
      await signInDemo();
      expect(AuthService.instance.demoStale, isFalse);
      await openApp(tester);
      expect(_banner, findsNothing);
    });

    testWidgets('demonstração de ontem: aviso com a data; "Agora não" '
        'esconde', (tester) async {
      await signInNextDay();
      await openApp(tester);

      expect(
        find.text(
          'Os dados de demonstração são de 11/11. Atualize para apresentar '
          'com os números de hoje.',
        ),
        findsOneWidget,
      );
      expect(find.text('Atualizar agora'), findsOneWidget);

      await _tap(tester, find.text('Agora não'));
      expect(_banner, findsNothing);
      expect(AuthService.instance.demoStale, isTrue, reason: 'só escondeu');

      // Continua escondido ao voltar para a Início.
      await _open(tester, '/perfil');
      await _open(tester, '/inicio');
      expect(_banner, findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('sem data conhecida, o aviso fala só em outro dia', () {
      expect(
        HomeDemoStaleBanner.message(null),
        'Os dados de demonstração são de outro dia. Atualize para '
        'apresentar com os números de hoje.',
      );
      expect(
        HomeDemoStaleBanner.message('2026-11-09'),
        startsWith('Os dados de demonstração são de 09/11.'),
      );
    });

    testWidgets('"Atualizar agora" recria a demonstração, entra de novo e '
        'mantém a posição', (tester) async {
      await signInNextDay();
      final location = MyLocationService.instance;
      location.useLocator(FakeDeviceLocator(current: posicaoNoCentro));
      expect(
        location.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon),
        isTrue,
      );
      final takenAt = location.position!.takenAt;

      await openApp(tester);
      expect(_banner, findsOneWidget);

      await _tap(tester, find.text('Atualizar agora'));
      expect(find.text('Restaurar demonstração?'), findsOneWidget);
      expect(
        find.textContaining('Sua posição no mapa continua guardada.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Restaurar'));
      await _settle(tester, 6);

      expect(AuthService.instance.isAuthenticated, isTrue);
      expect(AuthService.instance.userEmail, AuthService.demoEmail);
      expect(_path(), '/inicio');
      expect(_banner, findsNothing);
      expect(AuthService.instance.demoStale, isFalse);
      expect(AuthService.instance.demoSeededOn, '2026-11-12');
      expect(
        find.text('Demonstração atualizada com os números de hoje.'),
        findsOneWidget,
      );

      final position = location.position;
      expect(position?.lat, posicaoNoNorte.lat);
      expect(position?.lon, posicaoNoNorte.lon);
      expect(position?.source, MyPositionSource.manual);
      expect(position?.takenAt, takenAt);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Cancelar" não apaga nada', (tester) async {
      await signInNextDay();
      await openApp(tester);
      await _tap(tester, find.text('Atualizar agora'));
      await _tap(tester, find.text('Cancelar'));
      expect(_banner, findsOneWidget);
      expect(AuthService.instance.demoSeededOn, '2026-11-11');
    });

    testWidgets('o aviso cabe em 320x568 com texto 1,3x', (tester) async {
      await signInNextDay();
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const EcoApp());
      await tester.pump();
      await _open(tester, '/inicio');
      expect(_banner, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
