import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:eco_app/features/mapa/presentation/pages/mapa_page.dart';
import 'package:eco_app/features/mapa/presentation/widgets/base_map.dart';
import 'package:eco_app/features/mapa/presentation/widgets/map_markers.dart';
import 'package:eco_app/features/mapa/presentation/widgets/map_sheets.dart';
import 'package:eco_app/features/mapa/presentation/widgets/point_types.dart';
import 'package:eco_app/features/mapa/presentation/widgets/points_cluster_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/local_app.dart';

/// Espera as respostas da API local sem `pumpAndSettle`.
Future<void> _wait(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Widget _app() => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const MapaPage()),
      GoRoute(
        path: '/preferencias',
        builder: (_, _) => const Scaffold(body: Text('Preferências')),
      ),
    ],
  ),
);

/// Abre a página com a lista de imagens do mapa-base já lida.
Future<void> _openPage(WidgetTester tester) async {
  final tiles = await tester.runAsync(BaseMap.loadTiles);
  expect(tiles, contains(BaseMap.blankTile));
  expect(tiles!.length, greaterThan(1000));
  await tester.pumpWidget(_app());
  await _wait(tester);
  expect(find.byType(MapaPage), findsOneWidget);
  expect(find.text('Carregando o mapa...'), findsNothing);
}

/// Toca o primeiro grupo visível até aparecer um marcador individual.
Future<Finder> _findPointMarker(WidgetTester tester) async {
  final marker = find.byType(CollectionPointMarker).hitTestable();
  for (var i = 0; i < 5 && marker.evaluate().isEmpty; i++) {
    final cluster = find.byType(ClusterMarker).hitTestable();
    expect(cluster, findsWidgets);
    await tester.tap(cluster.first);
    await _wait(tester, 3);
  }
  expect(marker, findsWidgets);
  return marker.first;
}

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  testWidgets('mostra o mapa, os filtros, os marcadores e a lista', (
    tester,
  ) async {
    final clock = Stopwatch()..start();
    await signInDemo();
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final expected = await NeighborhoodService.instance.loadMap();
    final positioned = expected.points.where((p) => p.hasPosition).toList();
    expect(positioned, isNotEmpty);
    // Pontos em escolas começam escondidos e ficam fora das contagens.
    final schools = positioned.where(isSchoolPoint).length;
    final withoutSchools = positioned.length - schools;
    expect(schools, greaterThan(0));

    await _openPage(tester);
    expect(tester.takeException(), isNull);

    // Crédito obrigatório e contagens dos filtros.
    expect(find.text(expected.attribution), findsOneWidget);
    expect(find.text('© colaboradores do OpenStreetMap'), findsOneWidget);
    expect(find.text('Pontos de coleta ($withoutSchools)'), findsOneWidget);
    expect(find.text('Mostrar pontos em escolas ($schools)'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      find.text('Vizinhos (${expected.neighbors.length})'),
      findsOneWidget,
    );
    expect(
      find.text(
        'As pessoas aparecem só na região do bairro, nunca no endereço.',
      ),
      findsOneWidget,
    );
    // Vizinhos aparecem no mapa.
    expect(find.byType(NeighborMarker), findsWidgets);

    // Tocar num ponto de coleta abre a folha com o nome.
    final markerFinder = await _findPointMarker(tester);
    final point = tester.widget<CollectionPointMarker>(markerFinder).point;
    await tester.tap(markerFinder);
    await _wait(tester, 3);
    expect(find.text(point.name), findsOneWidget);
    expect(find.text(point.typeLabel), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(20, 20)); // fecha a folha
    await _wait(tester, 3);

    // Desligar os vizinhos tira os marcadores.
    await tester.tap(find.text('Vizinhos (${expected.neighbors.length})'));
    await _wait(tester, 2);
    expect(find.byType(NeighborMarker), findsNothing);

    // Lista: do mais perto ao mais longe, sem os pontos em escolas.
    await tester.tap(find.text('Ver como lista'));
    await _wait(tester, 3);
    expect(find.textContaining('fontes públicas consultadas'), findsOneWidget);
    expect(
      find.textContaining('Confirme no local antes de levar o material'),
      findsOneWidget,
    );
    final sorted = sortByDistance([
      for (final point in expected.points)
        if (!isSchoolPoint(point)) point,
    ]);
    final tops = <double>[];
    for (final item in sorted.take(3)) {
      final tile = find.byKey(ValueKey('lista-ponto-${item.id}'));
      expect(tile, findsOneWidget);
      tops.add(tester.getTopLeft(tile).dy);
    }
    expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);

    // Busca.
    final last = sorted.last;
    await tester.enterText(find.byType(TextField), last.name);
    await _wait(tester, 2);
    expect(find.byKey(ValueKey('lista-ponto-${last.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('lista-ponto-${sorted.first.id}')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(20, 20)); // fecha a lista
    await _wait(tester, 3);

    // Ligar o interruptor mostra os pontos em escolas e atualiza a contagem.
    await tester.tap(find.byType(Switch));
    await _wait(tester, 2);
    expect(
      find.text('Pontos de coleta (${positioned.length})'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // ignore: avoid_print
    print('Tempo do teste do mapa: ${clock.elapsedMilliseconds} ms');
  });

  testWidgets('pontos no mesmo endereço viram grupo que lista o local', (
    tester,
  ) async {
    await signInDemo();
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final expected = await NeighborhoodService.instance.loadMap();
    final byPlace = <String, List<CollectionPoint>>{};
    for (final point in expected.points) {
      if (!point.hasPosition || isSchoolPoint(point)) continue;
      byPlace.putIfAbsent('${point.lat},${point.lon}', () => []).add(point);
    }
    final place = byPlace.values.firstWhere((list) => list.length > 1);
    // Um ponto sem horário nem telefone, para conferir que nada vazio aparece.
    final bare = expected.points.firstWhere(
      (p) => !isSchoolPoint(p) && p.hours == null && p.phone == null,
    );

    await _openPage(tester);

    // Abre um ponto sem horário nem telefone pela lista.
    await tester.tap(find.text('Ver como lista'));
    await _wait(tester, 3);
    await tester.enterText(find.byType(TextField), bare.name);
    await _wait(tester, 2);
    await tester.tap(find.byKey(ValueKey('lista-ponto-${bare.id}')));
    await _wait(tester, 4);
    expect(find.text(bare.name), findsWidgets);
    expect(find.textContaining('null'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Horário')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Telefone')), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await _wait(tester, 3);

    // Vai até o endereço compartilhado e aproxima até o máximo.
    await tester.tap(find.text('Ver como lista'));
    await _wait(tester, 3);
    await tester.enterText(find.byType(TextField), place.first.name);
    await _wait(tester, 2);
    await tester.tap(find.byKey(ValueKey('lista-ponto-${place.first.id}')));
    await _wait(tester, 4);
    await tester.tapAt(const Offset(20, 20));
    await _wait(tester, 3);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Aproximar'));
      await tester.pump();
    }
    await _wait(tester, 2);

    // O grupo continua no zoom máximo e, ao tocar, lista os pontos do local.
    final group =
        find
            .byWidgetPredicate((w) => w is ClusterMarker && w.samePlace)
            .hitTestable();
    expect(group, findsWidgets);
    await tester.tap(group.first);
    await _wait(tester, 4);
    expect(find.textContaining('pontos de coleta neste local'), findsOneWidget);
    expect(find.text(place.first.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('não estoura em 320x568 com texto 1,3x', (tester) async {
    await signInDemo();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openPage(tester);
    expect(find.textContaining('Pontos de coleta ('), findsWidgets);
    expect(find.text('© colaboradores do OpenStreetMap'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Aproxima até o limite e volta.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Aproximar'));
      await tester.pump();
    }
    await _wait(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Afastar'));
    await _wait(tester, 2);

    // Legenda.
    await tester.tap(find.byTooltip('Legenda do mapa'));
    await _wait(tester, 3);
    expect(find.text('Legenda'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(10, 10));
    await _wait(tester, 3);

    // Lista.
    await tester.tap(find.text('Ver como lista'));
    await _wait(tester, 3);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
