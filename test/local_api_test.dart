import 'dart:math';

import 'package:eco_app/core/local/economy.dart';
import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:eco_app/core/local/places.dart';
import 'package:eco_app/core/services/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quarta-feira, 11/11/2026, 15:00 em Brasília (dia da feira).
final DateTime _wednesday = DateTime.utc(2026, 11, 11, 18);

class _Harness {
  _Harness({LocalStore? store, DateTime? start})
    : clock = start ?? _wednesday,
      db = LocalDatabase(store ?? MemoryStore()) {
    api = LocalApi(db, clock: () => clock, random: Random(7));
  }

  DateTime clock;
  final LocalDatabase db;
  late final LocalApi api;
  String? token;

  Future<dynamic> call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool anonymous = false,
  }) => api.handle(
    method,
    path,
    body: body,
    query: query,
    token: anonymous ? null : token,
  );

  Future<void> loginDemo() async {
    final data = await call(
      'POST',
      '/auth/login',
      body: {'email': LocalSeed.demoEmail, 'password': LocalSeed.demoPassword},
      anonymous: true,
    );
    token = data['token'] as String;
  }

  Future<Map<String, dynamic>> summary() async =>
      (await call('GET', '/progress'))['summary'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> action(int id) async =>
      (await call('GET', '/actions/$id'))['action'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> register(int id, {int quantity = 1}) async =>
      await call('POST', '/actions/$id/records', body: {'quantity': quantity})
          as Map<String, dynamic>;
}

Matcher _apiError(int status) => throwsA(
  isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
);

void main() {
  group('regras de calendário', () {
    test('semana começa na segunda 00:00 de Brasília', () {
      // Domingo 23:30 em Brasília ainda é a semana anterior.
      final sundayNight = DateTime.utc(2026, 11, 9, 2, 30);
      expect(Economy.dateKey(sundayNight), '2026-11-08');
      expect(Economy.weekStartKey(sundayNight), '2026-11-02');
      // Segunda 00:10 em Brasília já é a semana nova.
      final mondayEarly = DateTime.utc(2026, 11, 9, 3, 10);
      expect(Economy.weekStartKey(mondayEarly), '2026-11-09');
      expect(Economy.nextWeekReset(_wednesday), DateTime.utc(2026, 11, 16, 3));
    });

    test('níveis seguem os pontos ganhos', () {
      expect(Economy.levelFor(0).label, 'Semente • Nível 1');
      expect(Economy.levelFor(299).number, 1);
      expect(Economy.levelFor(300).label, 'Broto • Nível 2');
      expect(Economy.levelFor(1000).name, 'Muda');
      expect(Economy.levelFor(2500).name, 'Árvore');
      expect(Economy.levelFor(6000).label, 'Floresta • Nível 5');
      expect(Economy.levelFor(6000).next, isNull);
      expect(Economy.levelFor(450).next, 1000);
    });
  });

  group('conta de demonstração', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.loginDemo();
    });

    test('semana atual fica logo abaixo do teto', () async {
      final summary = await h.summary();
      // ignore: avoid_print
      print('resumo da demonstração: $summary');
      expect(summary['weeklyCap'], Economy.weeklyCap);
      expect(summary['weeklyPoints'], 375);
      expect(summary['weeklyRemaining'], 25);
      expect(summary['weekResetsAt'], '2026-11-16T03:00:00.000Z');
      expect(summary['points'], greaterThan(1600));
      expect(summary['pointsSpent'], 1000);
      expect(summary['levelNumber'], greaterThanOrEqualTo(3));
    });

    test('nenhuma semana do histórico passa do teto', () async {
      final byWeek = <String, int>{};
      for (final row in h.db.table('action_records')) {
        if (row['kind'] != 'action') continue;
        final date = DateTime.parse('${row['created_at']}');
        // O teto vale por pessoa: a conta de demonstração e cada vizinho.
        final week = '${row['user_id']}/${Economy.weekStartKey(date)}';
        byWeek[week] = (byWeek[week] ?? 0) + (row['points'] as int);
        expect(row['local_date'], Economy.dateKey(date));
      }
      expect(
        byWeek.keys.where((key) => key.startsWith('1/')).length,
        greaterThanOrEqualTo(9),
      );
      for (final total in byWeek.values) {
        expect(total, lessThanOrEqualTo(Economy.weeklyCap));
      }
    });

    test('desafios, conquistas e cupons têm estados variados', () async {
      final challenges =
          (await h.call('GET', '/challenges'))['challenges'] as List;
      final water = challenges.firstWhere((c) => c['id'] == 1);
      expect(water['joined'], isTrue);
      expect(water['completedSteps'], 3);
      expect(water['stepDoneToday'], isTrue);
      expect(water['daysLeft'], 5);
      final transport = challenges.firstWhere((c) => c['id'] == 2);
      expect(transport['completed'], isTrue);
      expect(challenges.firstWhere((c) => c['id'] == 4)['joined'], isFalse);

      final achievements =
          (await h.call('GET', '/progress/achievements'))['achievements']
              as List;
      expect(achievements.length, 10);
      final energy = achievements.firstWhere(
        (a) => a['key'] == 'guardiao-da-energia',
      );
      expect(energy['isUnlocked'], isFalse);
      expect(energy['current'], 5);
      final first = achievements.firstWhere(
        (a) => a['key'] == 'primeiros-passos',
      );
      expect(first['isUnlocked'], isTrue);
      expect(first['unlockedOn'], isNotNull);

      final redemptions =
          (await h.call('GET', '/rewards/redemptions'))['redemptions'] as List;
      expect(redemptions.map((r) => r['status']).toList(), [
        'active',
        'used',
        'expired',
      ]);
    });
  });

  group('limites por ação e teto semanal', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.loginDemo();
    });

    test('limite diário da ação', () async {
      final tap = await h.action(1);
      expect(tap['dailyLimit'], 2);
      expect(tap['usedToday'], 1);
      expect(tap['remaining'], 1);

      await expectLater(h.register(1, quantity: 2), _apiError(409));
      final ok = await h.register(1);
      expect(ok['record']['points'], 5);
      await expectLater(h.register(1), _apiError(409));
      expect((await h.action(1))['remaining'], 0);
    });

    test('limite semanal do mutirão', () async {
      final cleanup = await h.action(6);
      expect(cleanup['weeklyLimit'], 1);
      expect(cleanup['remaining'], 0);
      await expectLater(h.register(6), _apiError(409));
    });

    test('quantidade precisa ser inteira e positiva', () async {
      await expectLater(
        h.call('POST', '/actions/5/records', body: {'quantity': 2.5}),
        _apiError(400),
      );
      await expectLater(
        h.call('POST', '/actions/5/records', body: {'quantity': 0}),
        _apiError(400),
      );
    });

    test('ao atingir o teto a ação continua valendo, sem pontos', () async {
      final before = await h.summary();

      // Faltam 25 pontos: a compostagem (25) fecha o teto exatamente.
      final compost = await h.register(4);
      expect(compost['record']['points'], 25);
      expect(compost['capReached'], isTrue);

      // Depois do teto, a ação é registrada com zero ponto.
      final bike = await h.register(3);
      expect(bike['record']['basePoints'], 30);
      expect(bike['record']['points'], 0);
      expect(bike['record']['capped'], isTrue);
      expect(bike['capReached'], isFalse);

      final after = bike['summary'] as Map<String, dynamic>;
      expect(after['weeklyPoints'], Economy.weeklyCap);
      expect(after['weeklyRemaining'], 0);
      expect(after['actionsCount'], before['actionsCount'] + 2);
      expect(after['pointsEarned'], before['pointsEarned'] + 25);

      final notifications =
          (await h.call('GET', '/notifications'))['notifications'] as List;
      expect(
        notifications.any((n) => n['title'] == 'Teto semanal atingido'),
        isTrue,
      );
    });

    test('crédito parcial quando a ação passa do teto', () async {
      await h.register(5); // +5 → faltam 20
      final compost = await h.register(4); // vale 25, credita 20
      expect(compost['record']['basePoints'], 25);
      expect(compost['record']['points'], 20);
      expect(compost['record']['capped'], isTrue);
      expect(compost['capReached'], isTrue);
    });

    test('bônus de conquista não entra no teto', () async {
      final before = await h.summary();
      // A sexta ação de Energia destrava "Guardião da Energia" (+80).
      final lights = await h.register(5);
      final unlocked = lights['newAchievements'] as List;
      expect(unlocked.map((a) => a['key']), contains('guardiao-da-energia'));

      final after = lights['summary'] as Map<String, dynamic>;
      expect(after['weeklyPoints'], before['weeklyPoints'] + 5);
      expect(after['pointsEarned'], before['pointsEarned'] + 5 + 80);
    });

    test('o teto zera na segunda-feira', () async {
      await h.register(4);
      expect((await h.summary())['weeklyRemaining'], 0);

      h.clock = DateTime.utc(2026, 11, 16, 3, 5); // segunda, 00:05 em Brasília
      final summary = await h.summary();
      expect(summary['weeklyPoints'], 0);
      expect(summary['weeklyRemaining'], Economy.weeklyCap);
      final bike = await h.register(3);
      expect(bike['record']['points'], 30);
    });
  });

  group('desafios', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.loginDemo();
    });

    test(
      'desafio por dias avança uma etapa por dia, mesmo sem pontos',
      () async {
        final joined = await h.call('POST', '/challenges/4/join');
        expect(joined['challenge']['joined'], isTrue);
        expect(joined['challenge']['daysLeft'], 14);

        await h.register(5);
        await h.register(4); // fecha o teto
        var challenge =
            (await h.call('GET', '/challenges/4'))['challenge']
                as Map<String, dynamic>;
        expect(challenge['completedSteps'], 1);
        expect(challenge['stepDoneToday'], isTrue);

        h.clock = h.clock.add(const Duration(days: 1));
        final next = await h.register(4);
        expect(next['record']['points'], 0);
        final updates = next['challengeUpdates'] as List;
        expect(updates.single['id'], 4);
        expect(updates.single['completedSteps'], 2);
        challenge =
            (await h.call('GET', '/challenges/4'))['challenge']
                as Map<String, dynamic>;
        expect(challenge['daysLeft'], 13);
      },
    );

    test('concluir desafio credita o bônus e avisa', () async {
      // Semana sem desperdício de água: faltam 4 dias (quinta a domingo).
      Map<String, dynamic>? last;
      for (var i = 0; i < 4; i++) {
        h.clock = h.clock.add(const Duration(days: 1));
        last = await h.register(1);
      }
      final water = (last!['challengeUpdates'] as List).single;
      expect(water['completed'], isTrue);
      expect(water['completedSteps'], 7);

      final records = (await h.call('GET', '/records'))['records'] as List;
      final bonus = records.firstWhere((r) => r['kind'] == 'challenge');
      expect(bonus['points'], 100);
      expect(bonus['title'], contains('Semana sem desperdício de água'));
    });

    test('desafio vencido pode ser recomeçado', () async {
      await h.call('POST', '/challenges/4/join');
      await h.register(4);
      h.clock = h.clock.add(const Duration(days: 15));
      var challenge =
          (await h.call('GET', '/challenges/4'))['challenge']
              as Map<String, dynamic>;
      expect(challenge['expired'], isTrue);
      expect(challenge['daysLeft'], 0);

      challenge =
          (await h.call('POST', '/challenges/4/join'))['challenge']
              as Map<String, dynamic>;
      expect(challenge['expired'], isFalse);
      expect(challenge['completedSteps'], 0);
    });

    test('avanço manual de etapa não existe mais', () async {
      await expectLater(
        h.call('POST', '/challenges/1/progress', body: {'steps': 99}),
        _apiError(410),
      );
    });
  });

  group('recompensas e cupons', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.loginDemo();
    });

    Future<Map<String, dynamic>> rewardNamed(String title) async {
      final rewards = (await h.call('GET', '/rewards'))['rewards'] as List;
      return rewards.firstWhere((r) => r['title'] == title)
          as Map<String, dynamic>;
    }

    test('preço segue o valor do benefício', () async {
      final rewards = (await h.call('GET', '/rewards'))['rewards'] as List;
      expect(rewards.length, LocalSeed.rewards.length);
      for (final reward in rewards) {
        final full =
            (reward['valueCents'] as int) * Economy.pointsPerReal ~/ 100;
        final cost = reward['pointsCost'] as int;
        if (reward['category'] == 'jogo') {
          expect(cost, (full * 0.8).round());
        } else {
          expect(cost, full);
        }
      }
    });

    test(
      'resgate gera cupom válido, debita pontos e respeita o limite',
      () async {
        final before = await h.summary();
        final dish = await rewardNamed('Prato do dia vegetariano grátis');
        final result =
            await h.call('POST', '/rewards/${dish['id']}/redeem')
                as Map<String, dynamic>;

        final coupon = result['redemption'] as Map<String, dynamic>;
        expect(coupon['code'], startsWith('ECO-'));
        expect(coupon['status'], 'active');
        expect(coupon['partnerName'], 'Restaurante Sabor da Terra');
        expect(
          DateTime.parse(coupon['expiresAt'] as String),
          h.clock.add(const Duration(days: 30)),
        );
        expect(result['summary']['points'], before['points'] - 1600);
        expect(result['reward']['stock'], dish['stock'] - 1);
        expect(result['reward']['limitReached'], isTrue);

        // Limite de 1 resgate por pessoa a cada 30 dias.
        await expectLater(
          h.call('POST', '/rewards/${dish['id']}/redeem'),
          _apiError(409),
        );
      },
    );

    test('recusa resgate sem saldo ou sem estoque', () async {
      final cleaning = await rewardNamed('Limpeza ecológica residencial');
      await expectLater(
        h.call('POST', '/rewards/${cleaning['id']}/redeem'),
        _apiError(409),
      );
      final shirt = await rewardNamed('Camisa oficial EcoViva');
      expect(shirt['available'], isFalse);
      await expectLater(
        h.call('POST', '/rewards/${shirt['id']}/redeem'),
        _apiError(409),
      );
    });

    test('parceiro confere o cupom com o código dele', () async {
      final redemptions =
          (await h.call('GET', '/rewards/redemptions'))['redemptions'] as List;
      final active = redemptions.firstWhere((r) => r['status'] == 'active');
      final used = redemptions.firstWhere((r) => r['status'] == 'used');
      final expired = redemptions.firstWhere((r) => r['status'] == 'expired');

      await expectLater(
        h.call(
          'POST',
          '/rewards/redemptions/${active['id']}/use',
          body: {'pin': '0000'},
        ),
        _apiError(403),
      );
      final result = await h.call(
        'POST',
        '/rewards/redemptions/${active['id']}/use',
        body: {'pin': LocalSeed.demoPartnerPin},
      );
      expect(result['redemption']['status'], 'used');
      expect(result['redemption']['usedAt'], isNotNull);

      for (final other in [active, used, expired]) {
        await expectLater(
          h.call(
            'POST',
            '/rewards/redemptions/${other['id']}/use',
            body: {'pin': LocalSeed.demoPartnerPin},
          ),
          _apiError(409),
        );
      }
    });

    test('cupom vence depois da validade', () async {
      final combo = await rewardNamed('15% de desconto no combo');
      final result = await h.call('POST', '/rewards/${combo['id']}/redeem');
      final id = result['redemption']['id'];
      h.clock = h.clock.add(const Duration(days: 31));
      final redemptions =
          (await h.call('GET', '/rewards/redemptions'))['redemptions'] as List;
      expect(redemptions.firstWhere((r) => r['id'] == id)['status'], 'expired');
    });
  });

  group('conta e comunidade', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.api.ensureReady();
    });

    test('cadastro valida os dados e não vaza se o e-mail existe', () async {
      Future<dynamic> register(Map<String, dynamic> body) =>
          h.call('POST', '/auth/register', body: body, anonymous: true);

      await expectLater(
        register({'name': '  ', 'email': 'a@b.co', 'password': '123456'}),
        _apiError(400),
      );
      await expectLater(
        register({'name': 'Ana', 'email': 'sem-arroba', 'password': '123456'}),
        _apiError(400),
      );
      await expectLater(
        register({'name': 'Ana', 'email': 'ana@test.app', 'password': '123'}),
        _apiError(400),
      );
      await expectLater(
        register({
          'name': 'Outra Clara',
          'email': 'CLARA@eco.app',
          'password': '123456',
        }),
        _apiError(409),
      );

      final created =
          await register({
                'name': 'Ana Silva',
                'email': 'Ana@Test.app',
                'password': 'segredo1',
              })
              as Map<String, dynamic>;
      expect(created['user']['email'], 'ana@test.app');
      expect(created['user']['initials'], 'AS');
      h.token = created['token'] as String;
      final summary = await h.summary();
      expect(summary['points'], 0);
      expect(summary['level'], 'Semente • Nível 1');

      final known = await h.call(
        'POST',
        '/auth/forgot-password',
        body: {'email': 'ana@test.app'},
        anonymous: true,
      );
      final unknown = await h.call(
        'POST',
        '/auth/forgot-password',
        body: {'email': 'ninguem@test.app'},
        anonymous: true,
      );
      expect(unknown['message'], known['message']);
      expect(unknown['expiresInMinutes'], known['expiresInMinutes']);
    });

    test('login e sessão', () async {
      await expectLater(
        h.call(
          'POST',
          '/auth/login',
          body: {'email': LocalSeed.demoEmail, 'password': 'errada'},
          anonymous: true,
        ),
        _apiError(401),
      );
      await expectLater(
        h.call('GET', '/progress', anonymous: true),
        _apiError(401),
      );
      h.token = 'token-invalido';
      await expectLater(h.call('GET', '/progress'), _apiError(401));
      await h.loginDemo();
      final me = await h.call('GET', '/auth/me');
      expect(me['user']['name'], 'Clara Mendes');
    });

    test('código de recuperação bloqueia depois de 5 erros', () async {
      final forgot = await h.call(
        'POST',
        '/auth/forgot-password',
        body: {'email': LocalSeed.demoEmail},
        anonymous: true,
      );
      final code = forgot['devCode'] as String;
      for (var i = 0; i < 5; i++) {
        await expectLater(
          h.call(
            'POST',
            '/auth/reset-password',
            body: {
              'email': LocalSeed.demoEmail,
              'code': code == '111111' ? '222222' : '111111',
              'password': 'novasenha',
            },
            anonymous: true,
          ),
          _apiError(400),
        );
      }
      await expectLater(
        h.call(
          'POST',
          '/auth/reset-password',
          body: {
            'email': LocalSeed.demoEmail,
            'code': code,
            'password': 'novasenha',
          },
          anonymous: true,
        ),
        _apiError(400),
      );
    });

    test('publicar, curtir, comentar e excluir', () async {
      await h.loginDemo();
      final created = await h.call(
        'POST',
        '/community/posts',
        body: {'content': 'Olá, vizinhança!'},
      );
      final id = created['post']['id'];
      expect(created['post']['isMine'], isTrue);

      final liked = await h.call('POST', '/community/posts/$id/like');
      expect(liked, {'likes': 1, 'likedByMe': true});
      final unliked = await h.call('POST', '/community/posts/$id/like');
      expect(unliked, {'likes': 0, 'likedByMe': false});

      final comment = await h.call(
        'POST',
        '/community/posts/$id/comments',
        body: {'content': 'Primeiro comentário'},
      );
      expect(comment['comment']['authorName'], 'Clara Mendes');

      final feed = (await h.call('GET', '/community/posts'))['posts'] as List;
      expect(feed.first['id'], id);
      expect(feed.first['comments'], hasLength(1));
      final other = feed.firstWhere((p) => p['isMine'] == false);
      await expectLater(
        h.call('DELETE', '/community/posts/${other['id']}'),
        _apiError(403),
      );
      await h.call('DELETE', '/community/posts/$id');
      final after = (await h.call('GET', '/community/posts'))['posts'] as List;
      expect(after.any((p) => p['id'] == id), isFalse);
    });
  });

  group('bairro: estatísticas, mapa e pontos de coleta', () {
    late _Harness h;

    setUp(() async {
      h = _Harness();
      await h.loginDemo();
    });

    test('números do bairro saem dos registros e sobem ao registrar', () async {
      final before =
          await h.call('GET', '/community/stats') as Map<String, dynamic>;
      // ignore: avoid_print
      print('estatísticas do bairro: $before');
      expect(before['members'], LocalSeed.neighbors.length + 1);
      expect(before['activeNeighbors'], greaterThan(12));
      expect(before['actionsToday'], greaterThan(5));
      final goal = before['goal'] as Map<String, dynamic>;
      expect(goal['target'], LocalSeed.weeklyGoalTarget);
      expect(goal['current'], before['actionsThisWeek']);
      // Quarta à tarde: perto de 40% da meta, no ritmo para fechar no domingo.
      expect(goal['progress'], inInclusiveRange(0.3, 0.6));
      expect(goal['daysLeft'], 5);
      expect(goal['contributors'], greaterThan(10));

      final ranking = before['ranking'] as List;
      expect(ranking, hasLength(5));
      expect(ranking.first['position'], 1);
      expect(before['myPosition'], lessThanOrEqualTo(3));
      expect(before['myWeeklyPoints'], 375);
      for (final entry in ranking) {
        expect(entry['points'], lessThanOrEqualTo(Economy.weeklyCap));
      }

      await h.register(5);
      final after =
          await h.call('GET', '/community/stats') as Map<String, dynamic>;
      expect(after['actionsThisWeek'], before['actionsThisWeek'] + 1);
      expect(after['actionsToday'], before['actionsToday'] + 1);
      expect(after['goal']['current'], goal['current'] + 1);
      expect(after['myWeeklyPoints'], 380);
    });

    test('ao abrir, refaz a posição de contas antigas pelo bairro', () async {
      (Object?, Object?) spot(Map<String, dynamic> u) => (u['lat'], u['lon']);
      final users = h.db.table('users');
      final before = {for (final u in users) u['id']: spot(u)};

      // Duas contas como as versões anteriores deixavam: bairro abreviado e
      // bairro inventado, ambos no centro da cidade.
      final abbreviated = users[1];
      final unknown = users[2];
      for (final (row, name) in [
        (abbreviated, 'Jd. Nazareth'),
        (unknown, 'Bairro Inventado'),
      ]) {
        await h.db.update('users', row, {
          'neighborhood': name,
          'lat': Places.cityCenter.lat,
          'lon': Places.cityCenter.lon,
        });
      }

      // O app abre de novo sobre o mesmo banco.
      final reopened = LocalApi(h.db, clock: () => h.clock, random: Random(7));
      await reopened.ensureReady();

      final fixed =
          Places.approximatePosition(
            'Jardim Nazareth',
            '${abbreviated['email']}',
          )!;
      expect(spot(abbreviated), (fixed.lat, fixed.lon));
      expect(spot(unknown), (null, null));
      // Quem já estava certo não muda.
      for (final u in users) {
        if (u['id'] == abbreviated['id'] || u['id'] == unknown['id']) continue;
        expect(spot(u), before[u['id']], reason: '${u['name']}');
      }
    });

    test('ranking não mostra o bairro de quem saiu do mapa', () async {
      Future<List> ranking() async =>
          (await h.call('GET', '/community/stats'))['ranking'] as List;

      final other = (await ranking()).firstWhere((e) => e['isMe'] != true);
      expect(other['neighborhood'], isNotNull);
      final row = h.db
          .table('users')
          .firstWhere((u) => LocalApi.shortName(u['name']) == other['name']);

      // O vizinho e a própria pessoa desligam "aparecer no mapa".
      await h.db.update('users', row, {'privacy_location': 0});
      final me = h.db
          .table('users')
          .firstWhere((u) => u['email'] == LocalSeed.demoEmail);
      await h.db.update('users', me, {'privacy_location': 0});

      final after = await ranking();
      final hidden = after.firstWhere((e) => e['name'] == other['name']);
      expect(hidden['neighborhood'], isNull);
      expect(hidden['points'], other['points']);
      // A própria pessoa continua vendo o seu bairro.
      final mine = after.firstWhere((e) => e['isMe'] == true);
      expect(mine['neighborhood'], isNotNull);
    });

    test('cada ação diz quantos vizinhos registraram hoje', () async {
      final actions = (await h.call('GET', '/actions'))['actions'] as List;
      final tap = actions.firstWhere((a) => a['id'] == 1);
      expect(tap['neighborsToday'], greaterThan(3));
      final total = actions.fold<int>(
        0,
        (sum, a) => sum + (a['neighborsToday'] as int),
      );
      expect(total, greaterThan(8));
    });

    test('participantes dos desafios são contados de verdade', () async {
      final challenges =
          (await h.call('GET', '/challenges'))['challenges'] as List;
      expect(challenges.firstWhere((c) => c['id'] == 1)['participants'], 10);
      final before = challenges.firstWhere((c) => c['id'] == 4)['participants'];
      final joined = await h.call('POST', '/challenges/4/join');
      expect(joined['challenge']['participants'], before + 1);
    });

    test(
      'pessoa aparece no mapa na região do bairro, nunca no ponto exato',
      () async {
        final me =
            (await h.call('GET', '/auth/me'))['user'] as Map<String, dynamic>;
        expect(me['neighborhood'], 'Boa Vista');
        expect(me['city'], 'São José do Rio Preto');
        final location = me['location'] as Map<String, dynamic>;
        final boaVista = Places.findNeighborhood('boa vista')!;
        final distance = Places.distanceMeters(
          boaVista.lat,
          boaVista.lon,
          location['lat'] as double,
          location['lon'] as double,
        );
        expect(distance, inInclusiveRange(1, 600));

        final map =
            await h.call('GET', '/community/map') as Map<String, dynamic>;
        expect(map['neighbors'], hasLength(LocalSeed.neighbors.length));
        expect(map['me']['visible'], isTrue);
        expect(map['attribution'], contains('OpenStreetMap'));
        for (final neighbor in map['neighbors'] as List) {
          expect(neighbor['name'], endsWith('.'));
          expect(neighbor.containsKey('email'), isFalse);
          expect(neighbor.containsKey('address'), isFalse);
        }

        // Quem desliga a preferência some do mapa dos outros.
        await h.call(
          'PATCH',
          '/users/me/preferences',
          body: {'privacyLocation': false},
        );
        final hidden = await h.call('GET', '/community/map');
        expect(hidden['me']['visible'], isFalse);
      },
    );

    test('cadastro com endereço posiciona pelo bairro', () async {
      Future<dynamic> register(Map<String, dynamic> body) =>
          h.call('POST', '/auth/register', body: body, anonymous: true);

      await expectLater(
        register({
          'name': 'Ana Silva',
          'email': 'ana@test.app',
          'password': 'segredo1',
          'cep': '123',
        }),
        _apiError(400),
      );
      final created =
          await register({
                'name': 'Ana Silva',
                'email': 'ana@test.app',
                'password': 'segredo1',
                'cep': '15015110',
                'street': 'Rua Bernardino de Campos',
                'number': '3000',
                'neighborhood': 'vila redentora',
                'city': 'São José do Rio Preto',
                'state': 'sp',
              })
              as Map<String, dynamic>;
      final user = created['user'] as Map<String, dynamic>;
      expect(user['address']['cep'], '15015-110');
      expect(user['address']['street'], 'Rua Bernardino de Campos');
      expect(user['address']['state'], 'SP');
      final redentora = Places.findNeighborhood('Vila Redentora')!;
      expect(
        Places.distanceMeters(
          redentora.lat,
          redentora.lon,
          user['location']['lat'] as double,
          user['location']['lon'] as double,
        ),
        lessThan(600),
      );

      final found = await h.call(
        'GET',
        '/places/neighborhoods',
        query: {'search': 'redent'},
      );
      expect(found['neighborhoods'], contains('Vila Redentora'));
    });

    test('pontos de coleta vêm ordenados pela distância', () async {
      final center = Places.findNeighborhood('Centro')!;
      final far = Places.findNeighborhood('Vila Toninho')!;
      for (final (name, place) in [('Longe', far), ('Perto', center)]) {
        await h.db.insert('collection_points', {
          'name': name,
          'type': 'ecoponto',
          'materials': '["papel","vidro"]',
          'address': 'Endereço de teste',
          'neighborhood': place.name,
          'lat': place.lat,
          'lon': place.lon,
        });
      }
      await h.db.insert('collection_points', {
        'name': 'Sem coordenada',
        'type': 'oleo',
        'materials': '[]',
      });

      final points =
          (await h.call('GET', '/collection-points'))['points'] as List;
      final mine = points.where(
        (p) => ['Perto', 'Longe', 'Sem coordenada'].contains(p['name']),
      );
      expect(mine.map((p) => p['name']).toList(), [
        'Perto',
        'Longe',
        'Sem coordenada',
      ]);
      expect(mine.first['distanceMeters'], lessThan(2500));
      expect(mine.first['materials'], ['papel', 'vidro']);
      expect(mine.last['distanceMeters'], isNull);

      final filtered =
          (await h.call(
                'GET',
                '/collection-points',
                query: {'type': 'oleo'},
              ))['points']
              as List;
      expect(filtered.map((p) => p['name']), contains('Sem coordenada'));
      expect(filtered.any((p) => p['name'] == 'Perto'), isFalse);
    });

    test('dica do dia vem do banco e muda com o dia', () async {
      final today = (await h.call('GET', '/tips/today'))['tip'];
      expect(today['text'], isNotEmpty);
      h.clock = h.clock.add(const Duration(days: 1));
      final tomorrow = (await h.call('GET', '/tips/today'))['tip'];
      expect(tomorrow['id'], isNot(today['id']));
    });
  });

  group('persistência', () {
    test('os dados sobrevivem a fechar e abrir o app', () async {
      SharedPreferences.setMockInitialValues({});
      final first = _Harness(store: PrefsStore());
      await first.loginDemo();
      await first.register(5);
      await first.call(
        'POST',
        '/community/posts',
        body: {'content': 'Gravado no aparelho'},
      );
      final summary = await first.summary();

      // "Reabre" o app: novo banco em memória lendo do mesmo armazenamento.
      final second = _Harness(store: PrefsStore());
      await second.loginDemo();
      expect(await second.summary(), summary);
      final feed =
          (await second.call('GET', '/community/posts'))['posts'] as List;
      expect(feed.first['content'], 'Gravado no aparelho');
    });

    test('restaurar a demonstração volta ao estado inicial', () async {
      final h = _Harness();
      await h.loginDemo();
      final initial = await h.summary();
      await h.register(5);
      await h.register(4);
      expect((await h.summary())['weeklyRemaining'], 0);

      await h.call('POST', '/demo/reset', anonymous: true);
      await h.loginDemo();
      expect(await h.summary(), initial);
    });
  });
}
