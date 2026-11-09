import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

/// Rota visível no topo da pilha (inclui telas abertas com `push`).
String _path() {
  final config = AppRouter.router.routerDelegate.currentConfiguration;
  return config.isEmpty ? config.uri.path : config.last.matchedLocation;
}

/// Rola a lista principal até o item existir na árvore.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable:
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
  );
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
  await _reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await _settle(tester);
}

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  testWidgets('notificações, conquistas, perfil e preferências funcionam', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await signInDemo();
    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    // --- Notificações -------------------------------------------------------
    await _open(tester, '/notificacoes');
    expect(find.text('3 notificações não lidas'), findsOneWidget);
    expect(find.text('Toque para ver os detalhes'), findsNWidgets(5));

    // Abre uma notificação e vai para a aba indicada.
    await _tap(tester, find.text('Desafio em andamento'));
    expect(find.text('Ver no aplicativo'), findsOneWidget);
    await _tap(tester, find.text('Ver no aplicativo'));
    expect(_path(), '/desafios');

    // Rota fora das abas abre por cima (push).
    await _open(tester, '/notificacoes');
    await _tap(tester, find.text('Você está perto do teto da semana'));
    await _tap(tester, find.text('Ver no aplicativo'));
    expect(_path(), '/progresso');

    await _open(tester, '/notificacoes');
    expect(NotificationService.instance.unreadCount, 1);
    expect(find.text('1 notificação não lida'), findsOneWidget);
    await _tap(tester, find.text('Marcar todas como lidas'));
    expect(NotificationService.instance.unreadCount, 0);
    expect(find.text('Você está em dia com as novidades.'), findsOneWidget);

    // Excluir pelo botão.
    await _tap(tester, find.byTooltip('Excluir notificação').first);
    expect(NotificationService.instance.notifications.length, 4);

    // --- Conquistas ---------------------------------------------------------
    await _open(tester, '/conquistas');
    expect(find.text('Minhas Conquistas'), findsOneWidget);
    expect(find.textContaining('Concluído em '), findsWidgets);
    expect(find.textContaining('pts de bônus'), findsWidgets);

    // --- Perfil: editar nome e bairro --------------------------------------
    await _open(tester, '/perfil');
    expect(find.text('Clara Mendes'), findsOneWidget);
    await _tap(tester, find.text('Editar dados'));
    await tester.enterText(
      find.byKey(const ValueKey('perfil-nome')),
      'Clara Souza',
    );
    await tester.enterText(
      find.byKey(const ValueKey('perfil-bairro')),
      'Boa Vi',
    );
    await _settle(tester);
    final suggestion = find.descendant(
      of: find.byType(InkWell),
      matching: find.text('Boa Vista'),
    );
    expect(suggestion, findsWidgets);
    await _tap(tester, suggestion.first);
    await _tap(tester, find.text('Salvar'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(AuthService.instance.userName, 'Clara Souza');
    expect(AuthService.instance.neighborhood, 'Boa Vista');
    expect(find.text('Clara Souza'), findsOneWidget);
    expect(find.textContaining('Boa Vista'), findsWidgets);
    expect(find.text('CS'), findsOneWidget);

    // --- Preferências -------------------------------------------------------
    await _open(tester, '/preferencias');
    final currentGoal = AuthService.instance.weeklyGoal;
    final newGoal = currentGoal == 7 ? 10 : 7;
    await _tap(tester, find.byKey(ValueKey('meta-$newGoal')));
    expect(AuthService.instance.weeklyGoal, newGoal);

    final mapBefore =
        AuthService.instance.preferences['privacyLocation'] as bool? ?? true;
    await _tap(
      tester,
      find.byKey(const ValueKey('preferencia-privacyLocation')),
    );
    expect(AuthService.instance.preferences['privacyLocation'], !mapBefore);
    expect(find.text('Resumo semanal'), findsNothing);
    expect(find.text('Aparecer no ranking'), findsNothing);

    // --- Restaurar demonstração --------------------------------------------
    await _open(tester, '/perfil');
    await _tap(tester, find.text('Restaurar demonstração'));
    await _tap(tester, find.text('Restaurar'));
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(_path(), '/login');

    // A demonstração voltou ao estado inicial.
    await signInDemo();
    expect(AuthService.instance.userName, 'Clara Mendes');
    expect(NotificationService.instance.unreadCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('as quatro telas cabem em 320x568 com texto 1,3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await signInDemo();
    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    for (final route in [
      '/notificacoes',
      '/conquistas',
      '/perfil',
      '/preferencias',
    ]) {
      await _open(tester, route);
      expect(tester.takeException(), isNull, reason: 'Erro em $route');
    }

    // Folha de detalhes, diálogo de edição e filtros também cabem.
    await _open(tester, '/notificacoes');
    await _tap(tester, find.text('Novo comentário'));
    expect(tester.takeException(), isNull, reason: 'Folha de detalhes');
    await _tap(tester, find.byTooltip('Fechar'));

    await _open(tester, '/conquistas');
    await _tap(tester, find.textContaining('Em progresso'));
    expect(tester.takeException(), isNull, reason: 'Filtro de conquistas');

    await _open(tester, '/perfil');
    await _tap(tester, find.text('Editar dados'));
    expect(tester.takeException(), isNull, reason: 'Diálogo de edição');
    await _tap(tester, find.text('Cancelar'));

    await _tap(tester, find.text('Sobre o EcoViva'));
    expect(
      find.text('Modo demonstração: os dados ficam neste aparelho.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull, reason: 'Diálogo Sobre');
  });
}
