import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

/// Telas que devem se adaptar a aparelhos pequenos, tablets e texto ampliado.
///
/// Diferente da versão anterior, as telas são abertas com os dados da conta
/// de demonstração carregados: listas, cartões e folhas aparecem de verdade.
const _authenticatedRoutes = <String>[
  '/inicio',
  '/acoes',
  '/acoes?categoria=Água',
  '/desafios',
  '/comunidade',
  '/perfil',
  '/progresso',
  '/conquistas',
  '/preferencias',
  '/notificacoes',
  '/meu-historico',
  '/recompensas',
  '/detalhes-desafio/1', // em andamento
  '/detalhes-desafio/2', // concluído
  '/detalhes-desafio/4', // disponível
  '/detalhes-desafio/999', // inexistente
  '/registro-acao/1',
  '/registro-acao/6', // limite semanal atingido
  '/registro-acao/999', // inexistente
  '/confirmacao-registro',
  '/endereco-que-nao-existe',
];

const _sizes = <Size>[
  Size(320, 568), // celular pequeno
  Size(360, 640), // celular comum
  Size(768, 1024), // tablet
];

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  testWidgets(
    'rotas autenticadas não estouram em telas pequenas nem com texto ampliado',
    (tester) async {
      await signInDemo();
      // Deixa um registro recente para a tela de confirmação ter o que mostrar.
      await ActionHistoryService.instance.submitAction(actionId: 5, quantity: 1);

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in _sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        // Recria a árvore para não manter dois shells durante a troca de rotas.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(const EcoApp());
        await tester.pump();

        for (final route in _authenticatedRoutes) {
          await _open(tester, route);
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
    expect(AuthService.instance.isAuthenticated, isFalse);

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    for (final route in ['/login', '/registro', '/esqueci-senha']) {
      await _open(tester, route);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Erro de layout em $route em tela pequena',
      );
    }
  });

  testWidgets('sem sessão, rotas protegidas levam ao login', (tester) async {
    await tester.pumpWidget(const EcoApp());
    await _open(tester, '/recompensas');
    expect(
      AppRouter.router.routerDelegate.currentConfiguration.uri.path,
      '/login',
    );
    expect(tester.takeException(), isNull);
  });
}
