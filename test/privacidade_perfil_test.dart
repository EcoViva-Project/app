import 'dart:math';

import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

/// API local em memória, com os dados de demonstração, no dia da feira.
class _Api {
  _Api() : db = LocalDatabase(MemoryStore()) {
    api = LocalApi(db, clock: () => demoNow, random: Random(7));
  }

  final LocalDatabase db;
  late final LocalApi api;

  /// Chama a API como a pessoa dona do [token].
  Future<dynamic> call(
    String? token,
    String method,
    String path, {
    Object? body,
  }) => api.handle(method, path, body: body, token: token);

  Future<String> loginDemo() async {
    final data = await call(
      null,
      'POST',
      '/auth/login',
      body: {'email': LocalSeed.demoEmail, 'password': LocalSeed.demoPassword},
    );
    return data['token'] as String;
  }

  /// Os vizinhos da demonstração não entram pelo login (senha de figuração);
  /// a sessão local só precisa do id da conta.
  String tokenOf(Map<String, dynamic> user) => 'local.${user['id']}.teste';

  Map<String, dynamic> userByEmail(String email) =>
      db.table('users').firstWhere((u) => u['email'] == email);

  Future<void> setProfileVisible(Map<String, dynamic> user, bool visible) =>
      db.update('users', user, {'privacy_profile': visible ? 1 : 0});

  Future<List> ranking(String token) async =>
      (await call(token, 'GET', '/community/stats'))['ranking'] as List;

  Future<List> neighbors(String token) async =>
      (await call(token, 'GET', '/community/map'))['neighbors'] as List;

  Future<List> posts(String token) async =>
      (await call(token, 'GET', '/community/posts'))['posts'] as List;

  Future<List> notifications(String token) async =>
      (await call(token, 'GET', '/notifications'))['notifications'] as List;
}

const String _anonymous = 'Alguém do bairro';
const String _dot = '•';

void main() {
  group('perfil visível para a comunidade', () {
    late _Api a;
    late String demo;

    setUp(() async {
      a = _Api();
      demo = await a.loginDemo();
    });

    test(
      'vizinho com o perfil desligado aparece como "Alguém do bairro"',
      () async {
        final rankingBefore = await a.ranking(demo);
        final mapBefore = await a.neighbors(demo);

        // Um vizinho que está no ranking da semana.
        final other = rankingBefore.firstWhere((e) => e['isMe'] != true);
        final neighbor = a.db
            .table('users')
            .firstWhere((u) => LocalApi.shortName(u['name']) == other['name']);
        final neighborToken = a.tokenOf(neighbor);

        // Antes de desligar: o vizinho publica, e a Clara também.
        await a.call(
          neighborToken,
          'POST',
          '/community/posts',
          body: {'content': 'Publicação de antes de desligar.'},
        );
        final claraPost = await a.call(
          demo,
          'POST',
          '/community/posts',
          body: {'content': 'Quem quer trocar mudas?'},
        );
        final claraPostId = claraPost['post']['id'];

        await a.setProfileVisible(neighbor, false);

        // Depois de desligar, ele comenta na publicação da Clara.
        await a.call(
          neighborToken,
          'POST',
          '/community/posts/$claraPostId/comments',
          body: {'content': 'Eu quero!'},
        );

        // Publicações (inclusive a de antes) e comentário ficam anônimos.
        final feed = await a.posts(demo);
        final neighborPosts = [
          for (final p in feed)
            if (a.db.byId('posts', p['id'])!['user_id'] == neighbor['id']) p,
        ];
        expect(neighborPosts, isNotEmpty);
        for (final p in neighborPosts) {
          expect(p['authorName'], _anonymous);
          expect(p['authorInitials'], _dot);
        }
        final comment =
            (feed.firstWhere((p) => p['id'] == claraPostId)['comments'] as List)
                .single;
        expect(comment['authorName'], _anonymous);
        expect(comment['authorInitials'], _dot);
        final comments =
            (await a.call(
                  demo,
                  'GET',
                  '/community/posts/$claraPostId/comments',
                ))
                as Map;
        expect((comments['comments'] as List).single['authorName'], _anonymous);

        // A notificação para a Clara não traz o nome dele.
        final messages = [
          for (final n in await a.notifications(demo)) '${n['message']}',
        ];
        expect(
          messages.where((m) => m == '$_anonymous comentou na sua publicação.'),
          hasLength(1),
        );
        expect(
          messages.where(
            (m) => m == '${neighbor['name']} comentou na sua publicação.',
          ),
          isEmpty,
        );

        // Ranking: mesma posição e mesmos pontos, sem nome nem iniciais.
        final rankingAfter = await a.ranking(demo);
        expect(rankingAfter, hasLength(rankingBefore.length));
        for (var i = 0; i < rankingBefore.length; i++) {
          final before = rankingBefore[i] as Map;
          final after = rankingAfter[i] as Map;
          if (before['name'] == other['name']) {
            expect(after['name'], _anonymous);
            expect(after['initials'], _dot);
            expect(after['position'], before['position']);
            expect(after['points'], before['points']);
            expect(after['neighborhood'], before['neighborhood']);
          } else {
            // Quem está com o perfil ligado não muda.
            expect(after, before);
          }
        }

        // Mapa: continua lá, só sem o nome.
        final mapAfter = await a.neighbors(demo);
        expect(mapAfter, hasLength(mapBefore.length));
        for (var i = 0; i < mapBefore.length; i++) {
          final before = mapBefore[i] as Map;
          final after = mapAfter[i] as Map;
          if (before['id'] == neighbor['id']) {
            expect(after['name'], _anonymous);
            expect(after['initials'], _dot);
            expect(after['weeklyPoints'], before['weeklyPoints']);
            expect(after['lat'], before['lat']);
          } else {
            expect(after, before);
          }
        }

        // Ligando de novo, o nome volta em todo lugar.
        await a.setProfileVisible(neighbor, true);
        final feedBack = await a.posts(demo);
        for (final p in feedBack) {
          if (a.db.byId('posts', p['id'])!['user_id'] == neighbor['id']) {
            expect(p['authorName'], neighbor['name']);
            expect(p['authorInitials'], neighbor['initials']);
          }
        }
        final commentBack =
            (feedBack.firstWhere((p) => p['id'] == claraPostId)['comments']
                    as List)
                .single;
        expect(commentBack['authorName'], neighbor['name']);
        expect(await a.ranking(demo), rankingBefore);
        expect(await a.neighbors(demo), mapBefore);
      },
    );

    test('quem desliga continua se vendo com o nome real', () async {
      final clara = a.userByEmail(LocalSeed.demoEmail);
      final mine = await a.call(
        demo,
        'POST',
        '/community/posts',
        body: {'content': 'Minha horta está crescendo.'},
      );
      final postId = mine['post']['id'];
      final myRow = (await a.ranking(
        demo,
      )).firstWhere((e) => e['isMe'] == true);

      await a.call(
        demo,
        'PATCH',
        '/users/me/preferences',
        body: {'privacyProfile': false},
      );

      // A própria Clara: nome e iniciais reais.
      final myPost = (await a.posts(demo)).firstWhere((p) => p['id'] == postId);
      expect(myPost['authorName'], clara['name']);
      expect(myPost['authorInitials'], clara['initials']);
      final meAfter = (await a.ranking(
        demo,
      )).firstWhere((e) => e['isMe'] == true);
      expect(meAfter, myRow);
      expect(meAfter['name'], clara['name']);

      // Outra conta vê a Clara como anônima, na mesma posição.
      final created = await a.call(
        null,
        'POST',
        '/auth/register',
        body: {
          'name': 'Ana Silva',
          'email': 'ana@test.app',
          'password': 'segredo1',
        },
      );
      final ana = created['token'] as String;
      final seen = (await a.posts(ana)).firstWhere((p) => p['id'] == postId);
      expect(seen['authorName'], _anonymous);
      expect(seen['authorInitials'], _dot);
      final claraForAna = (await a.ranking(
        ana,
      )).firstWhere((e) => e['position'] == myRow['position']);
      expect(claraForAna['name'], _anonymous);
      expect(claraForAna['initials'], _dot);
      expect(claraForAna['points'], myRow['points']);
      expect(claraForAna['isMe'], isFalse);
    });
  });

  testWidgets('Preferências explica o que cada opção de privacidade faz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await useLocalBackend();
    await signInDemo();
    await tester.pumpWidget(const EcoApp());
    await tester.pump();
    AppRouter.router.go('/preferencias');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(
      find.text(
        'Ligado, seu nome aparece nas publicações, nos comentários e no '
        'ranking. Desligado, você aparece como "Alguém do bairro".',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Mostra só a região do seu bairro, nunca o endereço. Desligado, você '
        'sai do mapa dos vizinhos e seu bairro não aparece no ranking.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
