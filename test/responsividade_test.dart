import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Telas que devem se adaptar a aparelhos pequenos, tablets e texto ampliado.
const _authenticatedRoutes = <String>[
  '/inicio',
  '/acoes',
  '/desafios',
  '/comunidade',
  '/perfil',
  '/progresso',
  '/conquistas',
  '/preferencias',
  '/notificacoes',
  '/meu-historico',
  '/recompensas',
  '/detalhes-desafio',
  '/registro-acao',
  '/confirmacao-registro',
];

const _sizes = <Size>[
  Size(320, 568), // celular pequeno
  Size(360, 640), // celular comum
  Size(768, 1024), // tablet
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'rotas autenticadas não estouram em telas pequenas nem com texto ampliado',
    (tester) async {
      await AuthService.instance.debugSignIn();
      addTearDown(AuthService.instance.logout);

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const EcoApp());
      await tester.pump();

      for (final size in _sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Recria a árvore para não manter dois shells durante a troca de rotas.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(const EcoApp());
        await tester.pumpAndSettle();

        for (final route in _authenticatedRoutes) {
          AppRouter.router.go(route);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          expect(
            tester.takeException(),
            isNull,
            reason:
                'Erro de layout em $route com ${size.width.toInt()}x'
                '${size.height.toInt()} e texto 1.3x',
          );
        }
      }
    },
  );

  testWidgets('telas de autenticação não estouram em telas pequenas', (
    tester,
  ) async {
    await AuthService.instance.logout();

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    for (final route in ['/login', '/registro', '/esqueci-senha']) {
      AppRouter.router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.takeException(),
        isNull,
        reason: 'Erro de layout em $route em tela pequena',
      );
    }
  });
}
