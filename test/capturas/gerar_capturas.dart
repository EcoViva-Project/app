// Gera imagens PNG das telas com os dados da conta de demonstração.
//
// Não faz parte da suíte (o nome não termina em `_test.dart`). Para rodar:
//   flutter test test/capturas/gerar_capturas.dart
// As imagens saem em build/capturas/ e servem para conferir o visual das
// telas sem precisar de um aparelho.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/local_app.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> _loadFonts() async {
  ByteData read(String path) =>
      ByteData.view(File(path).readAsBytesSync().buffer);

  final jakarta = FontLoader('PlusJakartaSans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    jakarta.addFont(
      Future.value(
        read('assets/fonts/PlusJakartaSans/static/PlusJakartaSans-$weight.ttf'),
      ),
    );
  }
  await jakarta.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final iconsFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconsFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(read(iconsFile.path)));
    await icons.load();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/capturas/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(_loadFonts);

  setUp(() async {
    await useLocalBackend();
  });

  testWidgets('captura as telas', (tester) async {
    // Tela alta: a página inteira cabe em uma imagem só.
    tester.view.physicalSize = const Size(390, 2300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(key: _boundaryKey, child: const EcoApp()),
    );
    await _open(tester, '/login');
    await _capture(tester, '01-login');
    await _open(tester, '/registro');
    await _capture(tester, '02-cadastro');
    await _open(tester, '/esqueci-senha');
    await _capture(tester, '03-esqueci-senha');

    await signInDemo();
    await _open(tester, '/inicio');
    await _capture(tester, '10-inicio');
    await _open(tester, '/acoes');
    await _capture(tester, '11-acoes');
    await _open(tester, '/registro-acao/4');
    await _capture(tester, '12-registro-acao');
    await _open(tester, '/desafios');
    await _capture(tester, '13-desafios');
    await _open(tester, '/detalhes-desafio/1');
    await _capture(tester, '14-desafio-em-andamento');
    await _open(tester, '/detalhes-desafio/4');
    await _capture(tester, '15-desafio-disponivel');
    await _open(tester, '/comunidade');
    await _capture(tester, '16-comunidade');
    await _open(tester, '/perfil');
    await _capture(tester, '17-perfil');
    await _open(tester, '/progresso');
    await _capture(tester, '18-progresso');
    await _open(tester, '/conquistas');
    await _capture(tester, '19-conquistas');
    await _open(tester, '/notificacoes');
    await _capture(tester, '20-notificacoes');
    await _open(tester, '/recompensas');
    await _capture(tester, '21-recompensas');
    await _open(tester, '/meu-historico');
    await _capture(tester, '22-historico');
    await _open(tester, '/preferencias');
    await _capture(tester, '23-preferencias');

    // Depois de registrar: conquista nova, teto atingido e confirmação.
    await ActionHistoryService.instance.submitAction(actionId: 5, quantity: 1);
    await ActionHistoryService.instance.submitAction(actionId: 4, quantity: 1);
    await _open(tester, '/confirmacao-registro');
    await _capture(tester, '30-confirmacao-teto');
    await _open(tester, '/inicio');
    await _capture(tester, '31-inicio-teto-atingido');

    expect(AuthService.instance.isAuthenticated, isTrue);
  });
}
