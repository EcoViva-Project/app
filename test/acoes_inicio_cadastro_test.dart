import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_catalog_service.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _field(String key) => find.byKey(ValueKey<String>(key));

Finder _labeled(String label) => find.widgetWithText(TextFormField, label);

/// Rola a tela até o texto aparecer (a lista de ações é preguiçosa).
Future<bool> _scrollUntilFound(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 40; i++) {
    if (target.evaluate().isNotEmpty) return true;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return target.evaluate().isNotEmpty;
}

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  testWidgets('Ações mostra vizinhos do dia e a linha da comunidade', (
    tester,
  ) async {
    await signInDemo();
    final stats = NeighborhoodService.instance.stats;
    expect(stats, isNotNull);

    await tester.pumpWidget(const EcoApp());
    await tester.pump();
    await _open(tester, '/acoes');

    expect(find.textContaining('Hoje na comunidade: '), findsOneWidget);
    expect(find.textContaining('${stats!.actionsToday}'), findsWidgets);

    final labels = [
      for (final action in ActionCatalogService.instance.actions)
        if (action.neighborsTodayLabel != null) action.neighborsTodayLabel!,
    ];
    expect(labels, isNotEmpty, reason: 'o banco de demonstração tem vizinhos');
    final found = await _scrollUntilFound(tester, find.text(labels.first));
    expect(found, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Início mostra "Sua comunidade" e a dica do serviço', (
    tester,
  ) async {
    await signInDemo();
    final service = NeighborhoodService.instance;
    expect(service.isLoaded, isTrue);
    expect(service.stats?.goal?.countLabel, '157 de 400 ações');

    await tester.pumpWidget(const EcoApp());
    await tester.pump();
    await _open(tester, '/inicio');

    expect(find.text('Sua comunidade', skipOffstage: false), findsOneWidget);
    expect(find.text('157 de 400 ações', skipOffstage: false), findsOneWidget);
    expect(
      find.text(
        countText(
          service.stats!.activeNeighbors,
          'vizinho ativo',
          'vizinhos ativos',
        ),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    final tip = service.tip;
    expect(tip, isNotNull);
    expect(find.text(tip!.text, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro sugere bairro, valida CEP e cria a conta', (
    tester,
  ) async {
    expect(AuthService.instance.isAuthenticated, isFalse);
    await tester.pumpWidget(const EcoApp());
    await tester.pump();
    await _open(tester, '/registro');

    expect(find.text('Endereço'), findsOneWidget);
    expect(
      find.textContaining('Seu endereço não é mostrado a ninguém'),
      findsOneWidget,
    );
    // Valores padrão.
    expect(find.text('São José do Rio Preto'), findsOneWidget);
    expect(find.text('SP'), findsOneWidget);

    await tester.enterText(_labeled('Nome completo'), 'Pessoa Visitante');
    await tester.enterText(_labeled('E-mail'), 'visitante.feira@exemplo.com');
    await tester.enterText(_labeled('Senha'), 'segredo123');
    await tester.enterText(_labeled('Confirmar senha'), 'segredo123');

    // CEP incompleto não passa.
    await tester.enterText(_field('endereco-cep'), '15015');
    await tester.enterText(_field('endereco-bairro'), 'reden');
    await _settle(tester);

    final suggestion = find.text('Vila Redentora');
    expect(suggestion, findsOneWidget);
    await tester.ensureVisible(suggestion);
    await tester.pump();
    await tester.tap(suggestion);
    await tester.pump();

    final bairro = tester.widget<EditableText>(
      find.descendant(
        of: _field('endereco-bairro'),
        matching: find.byType(EditableText),
      ),
    );
    expect(bairro.controller.text, 'Vila Redentora');
    expect(find.text('Vila Redentora'), findsOneWidget); // lista fechada

    final submit = find.text('Criar minha conta');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Informe um CEP com 8 dígitos.'), findsOneWidget);
    expect(AuthService.instance.isAuthenticated, isFalse);

    await tester.enterText(_field('endereco-cep'), '15015100');
    await tester.pump();
    expect(find.text('15015-100'), findsOneWidget);

    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await _settle(tester);

    expect(AuthService.instance.isAuthenticated, isTrue);
    expect(AuthService.instance.neighborhood, 'Vila Redentora');
    expect(AuthService.instance.location, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('as três telas cabem em 320x568 com texto 1,3x', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    // Cadastro, com a lista de sugestões aberta.
    await _open(tester, '/registro');
    await tester.enterText(_field('endereco-bairro'), 'reden');
    await _settle(tester);
    expect(find.text('Vila Redentora'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'cadastro');

    await signInDemo();
    await _open(tester, '/inicio');
    expect(tester.takeException(), isNull, reason: 'início');
    await _scrollUntilFound(tester, find.text('Sua comunidade'));
    expect(tester.takeException(), isNull, reason: 'início rolado');

    await _open(tester, '/acoes');
    expect(
      find.textContaining('Hoje na comunidade: ', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull, reason: 'ações');
  });
}

/// Mesmo formato de `countLabel` (milhar com ponto).
String countText(int count, String singular, String plural) {
  final digits = count.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer ${count == 1 ? singular : plural}';
}
