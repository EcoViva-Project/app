import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/device_locator.dart';
import 'package:eco_app/core/services/my_location_service.dart';
import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:eco_app/features/mapa/presentation/pages/mapa_page.dart';
import 'package:eco_app/features/mapa/presentation/widgets/base_map.dart';
import 'package:eco_app/features/mapa/presentation/widgets/map_markers.dart';
import 'package:eco_app/features/mapa/presentation/widgets/my_position_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'support/fake_locator.dart';
import 'support/local_app.dart';

/// Espera as respostas da API local sem `pumpAndSettle` (o mapa e o
/// "Localizando…" ficam animando).
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

Future<void> _openPage(WidgetTester tester) async {
  await tester.runAsync(BaseMap.loadTiles);
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app());
  await _wait(tester);
  expect(find.text('Carregando o mapa...'), findsNothing);
}

/// Posição do próprio marcador no mapa, ou `null` se não há marcador.
LatLng? _mePoint(WidgetTester tester) {
  final layer = find.byKey(const ValueKey('mapa-voce'));
  if (layer.evaluate().isEmpty) return null;
  return tester.widget<MarkerLayer>(layer).markers.single.point;
}

Future<void> _tapMe(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MeMarker),
      matching: find.byType(MapMarkerButton),
    ),
  );
  await _wait(tester, 3);
}

MyLocationService get _service => MyLocationService.instance;

void main() {
  setUp(() async {
    await useLocalBackend();
    await signInDemo();
  });

  testWidgets('o próprio marcador vai para a posição do celular e diz "Você"', (
    tester,
  ) async {
    _service.useLocator(FakeDeviceLocator(current: posicaoNoCentro));
    final map = await NeighborhoodService.instance.loadMap();
    await _openPage(tester);

    expect(find.text('Você'), findsOneWidget);
    expect(
      _mePoint(tester),
      const LatLng(-20.8123, -49.3801),
      reason: 'posição exata do celular, não a região do bairro',
    );
    expect(_mePoint(tester), isNot(LatLng(map.myLat!, map.myLon!)));
    expect(find.text(kExactPositionPrivacy), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // Nada de explicação: a permissão já estava dada.
    expect(find.text('Mostrar onde você está?'), findsNothing);

    // A folha "Você" conta de onde vem a posição.
    await _tapMe(tester);
    expect(
      find.text('Sua posição: pela localização do celular.'),
      findsOneWidget,
    );
    expect(find.text('Voltar para a região do bairro'), findsOneWidget);
    await tester.tap(find.text('Voltar para a região do bairro'));
    await _wait(tester, 3);
    expect(_service.position, isNull);
    expect(_mePoint(tester), LatLng(map.myLat!, map.myLon!));
    expect(
      find.text(
        'As pessoas aparecem só na região do bairro, nunca no endereço.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a explicação aparece uma vez só; "Agora não" é lembrado', (
    tester,
  ) async {
    final fake = FakeDeviceLocator(
      permission: LocatorPermission.denied,
      current: posicaoNoCentro,
    );
    _service.useLocator(fake);
    final map = await NeighborhoodService.instance.loadMap();
    await _openPage(tester);

    expect(find.text('Mostrar onde você está?'), findsOneWidget);
    expect(find.text(kExactPositionPrivacy), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await _wait(tester, 3);
    expect(find.text('Mostrar onde você está?'), findsNothing);
    expect(fake.permissionRequests, 0);
    expect(_mePoint(tester), LatLng(map.myLat!, map.myLon!));

    // Abrindo o mapa de novo, não pergunta outra vez.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await _wait(tester);
    expect(find.text('Mostrar onde você está?'), findsNothing);
    expect(fake.permissionRequests, 0);

    // O botão de centralizar ainda pede a localização.
    fake.permissionAfterRequest = LocatorPermission.granted;
    await tester.tap(find.byTooltip('Centralizar em mim'));
    await _wait(tester, 3);
    expect(fake.permissionRequests, 1);
    expect(_mePoint(tester), const LatLng(-20.8123, -49.3801));
    expect(tester.takeException(), isNull);
  });

  testWidgets('aceitar a explicação pede a permissão e usa a posição', (
    tester,
  ) async {
    final fake = FakeDeviceLocator(
      permission: LocatorPermission.denied,
      permissionAfterRequest: LocatorPermission.granted,
      current: posicaoNoNorte,
    );
    _service.useLocator(fake);
    await _openPage(tester);

    await tester.tap(find.text('Usar minha localização'));
    await _wait(tester, 3);
    expect(fake.permissionRequests, 1);
    expect(_mePoint(tester), const LatLng(-20.76, -49.35));
  });

  testWidgets('falha mantém a região do bairro e avisa em uma frase', (
    tester,
  ) async {
    _service.useLocator(FakeDeviceLocator(timesOut: true));
    final map = await NeighborhoodService.instance.loadMap();
    await _openPage(tester);

    expect(_mePoint(tester), LatLng(map.myLat!, map.myLon!));
    expect(
      find.text(
        'O celular não achou sua localização a tempo, então seguimos com a '
        'região do seu bairro.',
      ),
      findsOneWidget,
    );
    expect(find.text('Localizando…'), findsNothing);

    // A mensagem oferece "Ajustar no mapa".
    await tester.tap(find.widgetWithText(SnackBarAction, 'Ajustar no mapa'));
    await _wait(tester, 3);
    expect(find.text('Toque no mapa onde você está'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await _wait(tester, 2);
    expect(find.text('Toque no mapa onde você está'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ajustar no mapa" marca a posição com um toque', (tester) async {
    final map = await NeighborhoodService.instance.loadMap();
    await _openPage(tester);
    final before = _mePoint(tester)!;
    expect(before, LatLng(map.myLat!, map.myLon!));

    // Esconde pontos e vizinhos para o toque cair no mapa.
    await tester.tap(find.textContaining('Pontos de coleta ('));
    await tester.tap(find.textContaining('Vizinhos ('));
    await _wait(tester, 2);

    await _tapMe(tester);
    expect(find.text('Você'), findsWidgets);
    expect(
      find.textContaining('Sua posição: região do bairro Boa Vista'),
      findsOneWidget,
    );
    expect(find.text('Voltar para a região do bairro'), findsNothing);
    await tester.tap(find.text('Ajustar no mapa'));
    await _wait(tester, 3);
    expect(find.text('Toque no mapa onde você está'), findsOneWidget);

    // Abaixo e à direita do centro: mais ao sul e mais a leste.
    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(center + const Offset(90, 90));
    await _wait(tester, 4);

    final position = _service.position!;
    expect(position.source, MyPositionSource.manual);
    expect(position.lat, lessThan(before.latitude));
    expect(position.lon, greaterThan(before.longitude));
    expect(_mePoint(tester), LatLng(position.lat, position.lon));
    expect(find.text('Toque no mapa onde você está'), findsNothing);

    await _tapMe(tester);
    expect(find.text('Sua posição: ajustada por você.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bairro fora da lista: faixa com "Editar perfil"', (
    tester,
  ) async {
    await AuthService.instance.updateProfile(neighborhood: 'Bairro Inventado');
    _service.useLocator(
      FakeDeviceLocator(current: posicaoNoCentro)
        ..permission = LocatorPermission.deniedForever,
    );
    await _openPage(tester);

    expect(
      find.textContaining('Não achamos o bairro "Bairro Inventado"'),
      findsOneWidget,
    );
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.byType(MeMarker), findsNothing);

    // "Usar minha localização" com a permissão bloqueada avisa e oferece o
    // ajuste no mapa.
    await tester.tap(find.text('Usar minha localização'));
    await _wait(tester, 3);
    expect(find.textContaining('bloqueada'), findsOneWidget);
    expect(find.textContaining('"Ajustar no mapa"'), findsOneWidget);

    // Editar perfil abre o diálogo com o aviso do bairro.
    await tester.tap(find.text('Editar perfil'));
    await _wait(tester, 3);
    expect(find.text('Editar dados'), findsOneWidget);
    expect(
      find.text(
        'Não achamos esse bairro na lista de Rio Preto. Escolha uma sugestão '
        'para aparecer no mapa.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('perfil-bairro')),
      'Vl Toninho',
    );
    await _wait(tester, 2);
    expect(
      find.text('Vamos usar o bairro Vila Toninho no mapa.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Salvar'));
    await _wait(tester, 6);
    expect(find.textContaining('Não achamos o bairro'), findsNothing);
    final location = AuthService.instance.location!;
    expect(_mePoint(tester), LatLng(location.lat, location.lon));
    // O mapa vai até a nova posição.
    expect(find.byType(MeMarker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
