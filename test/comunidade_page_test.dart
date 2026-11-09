import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/community_service.dart';
import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:eco_app/core/services/user_progress_service.dart';
import 'package:eco_app/features/comunidade/presentation/pages/comunidade_page.dart';
import 'package:eco_app/features/comunidade/presentation/widgets/collection_points_section.dart';
import 'package:eco_app/features/comunidade/presentation/widgets/community_numbers.dart';
import 'package:eco_app/features/comunidade/presentation/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openCommunity(WidgetTester tester) async {
  await tester.pumpWidget(const EcoApp());
  await tester.pump();
  AppRouter.router.go('/comunidade');
  await _settle(tester);
}

/// A lista principal da tela (e não a de uma folha ou do menu).
Finder get _pageList =>
    find
        .descendant(
          of: find.byType(ComunidadePage),
          matching: find.byType(Scrollable),
        )
        .first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _pageList);
  await tester.pump();
}

void _expectStat(Key key, int value, String label) {
  final card = find.byKey(key);
  expect(card, findsOneWidget);
  expect(
    find.descendant(
      of: card,
      matching: find.text(UserProgressService.formatNumber(value)),
    ),
    findsOneWidget,
  );
  expect(find.descendant(of: card, matching: find.text(label)), findsOneWidget);
}

void main() {
  setUp(() async {
    await useLocalBackend();
    await signInDemo();
  });

  testWidgets('mostra os números do banco e acompanha uma ação registrada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCommunity(tester);
    expect(tester.takeException(), isNull);

    final stats = NeighborhoodService.instance.stats!;
    _expectStat(
      activeNeighborsStatKey,
      stats.activeNeighbors,
      stats.activeNeighbors == 1 ? 'vizinho ativo' : 'vizinhos ativos',
    );
    expect(find.text('nos últimos 7 dias'), findsOneWidget);
    _expectStat(
      actionsTodayStatKey,
      stats.actionsToday,
      stats.actionsToday == 1 ? 'ação hoje' : 'ações hoje',
    );
    _expectStat(
      actionsWeekStatKey,
      stats.actionsThisWeek,
      stats.actionsThisWeek == 1 ? 'ação nesta semana' : 'ações nesta semana',
    );

    // Meta coletiva.
    expect(find.text('157 de 400 ações'), findsOneWidget);
    expect(find.text(stats.goal!.percentLabel), findsOneWidget);
    expect(find.text('Registrar ação'), findsOneWidget);

    // Registrar uma ação sobe a meta e os números sem recarregar a tela.
    await ActionHistoryService.instance.submitAction(actionId: 5, quantity: 1);
    await _settle(tester);
    expect(find.text('158 de 400 ações'), findsOneWidget);
    expect(find.text('157 de 400 ações'), findsNothing);
    final updated = NeighborhoodService.instance.stats!;
    expect(updated.actionsThisWeek, stats.actionsThisWeek + 1);
    _expectStat(
      actionsWeekStatKey,
      updated.actionsThisWeek,
      'ações nesta semana',
    );

    // Ranking: a linha do usuário aparece destacada.
    await _scrollTo(tester, find.text('Ranking da semana'));
    expect(updated.ranking.any((entry) => entry.isMe), isTrue);
    expect(find.text('Você'), findsOneWidget);
    expect(
      find.text(
        'Conta os pontos de ações desta semana. Com o teto semanal de '
        'pontos, a disputa é justa.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pontos de coleta: mais próximos, detalhes e lista completa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCommunity(tester);

    final points = NeighborhoodService.instance.collectionPoints;
    expect(points.length, greaterThan(3));
    // A API devolve do mais perto ao mais longe.
    final firstThree = points.take(3).map((p) => p.distanceMeters!).toList();
    expect(firstThree[0], lessThanOrEqualTo(firstThree[1]));
    expect(firstThree[1], lessThanOrEqualTo(firstThree[2]));

    // Na tela: três pontos de tipos diferentes, do mais perto ao mais longe.
    final shown = pickNearestVaried(points, collectionPointsPreview);
    expect(shown, hasLength(3));
    expect(shown.map((p) => p.type).toSet(), hasLength(3));
    final distances = shown.map((p) => p.distanceMeters!).toList();
    expect(distances[0], lessThanOrEqualTo(distances[1]));
    expect(distances[1], lessThanOrEqualTo(distances[2]));

    final cards = find.byType(CollectionPointCard);
    await _scrollTo(tester, find.text('Ver todos (${points.length})'));
    expect(cards, findsNWidgets(3));
    final tops = [
      for (final point in shown)
        tester
            .getTopLeft(
              find.descendant(of: cards, matching: find.text(point.name)),
            )
            .dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
    expect(
      find.text('As distâncias são medidas a partir da região do seu bairro.'),
      findsOneWidget,
    );

    // Folha de detalhes. O primeiro cartão pode ter saído da área visível
    // quando a tela rolou até os botões: volta até ele antes de tocar.
    final firstCard = find.descendant(
      of: cards,
      matching: find.text(shown.first.name),
    );
    await tester.ensureVisible(firstCard);
    await _settle(tester);
    await tester.tap(firstCard);
    await _settle(tester);
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(
      find.text('Informação a confirmar no local'),
      shown.first.isConfirmed ? findsNothing : findsOneWidget,
    );
    await tester.tap(find.byTooltip('Fechar'));
    await _settle(tester);

    // Lista completa com busca e filtro por tipo.
    await tester.tap(find.text('Ver todos (${points.length})'));
    await _settle(tester);
    expect(find.text('Todos (${points.length})'), findsOneWidget);
    final target = points.first;
    await tester.enterText(find.byType(TextField), target.name);
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(target.name),
      ),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('Fechar'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o feed continua com as publicações e a curtida funciona', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openCommunity(tester);

    final post = CommunityService.instance.posts.first;
    final likes = post.likes;
    final liked = post.likedByMe;
    await _scrollTo(tester, find.text(post.content));
    expect(find.text(post.content), findsOneWidget);
    final likeButton = find.descendant(
      of: find.ancestor(
        of: find.text(post.content),
        matching: find.byType(CommunityPostCard),
      ),
      matching: find.text('Curtir ($likes)'),
    );
    await tester.ensureVisible(likeButton);
    await tester.pump();

    await tester.tap(likeButton);
    await _settle(tester);
    final after = CommunityService.instance.posts.firstWhere(
      (p) => p.id == post.id,
    );
    expect(after.likedByMe, !liked);
    expect(after.likes, liked ? likes - 1 : likes + 1);
    expect(find.text('Curtir (${after.likes})'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe em 320x568 com texto 1,3x, inclusive com as folhas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openCommunity(tester);
    expect(tester.takeException(), isNull);

    final points = NeighborhoodService.instance.collectionPoints;
    final shown = pickNearestVaried(points, collectionPointsPreview);
    final firstCard = find.descendant(
      of: find.byType(CollectionPointCard),
      matching: find.text(shown.first.name),
    );
    await _scrollTo(tester, firstCard);
    expect(tester.takeException(), isNull);

    await tester.tap(firstCard);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Fechar'));
    await _settle(tester);

    final seeAll = find.text('Ver todos (${points.length})');
    await _scrollTo(tester, seeAll);
    await tester.tap(seeAll);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    // Filtra por um tipo e volta.
    final typeChip = find.byType(FilterChip).at(1);
    await tester.ensureVisible(typeChip);
    await tester.pump();
    await tester.tap(typeChip);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final selected = tester.widget<FilterChip>(typeChip);
    expect(selected.selected, isTrue);
    // Volta ao topo da folha (o `ensureVisible` rolou a lista).
    final sheetList = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(sheetList).position.jumpTo(0);
    await tester.pump();
    final close = find.byTooltip('Fechar');
    // A lista mostra só os pontos do tipo escolhido.
    expect(find.textContaining(' de ${points.length} pontos'), findsOneWidget);
    await tester.tap(close);
    await _settle(tester);

    // Até o fim do feed.
    await tester.drag(_pageList, const Offset(0, -6000));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
