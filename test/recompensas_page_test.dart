import 'package:eco_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

/// Espera as respostas da API local sem `pumpAndSettle` (há indicadores de
/// carregamento animados).
Future<void> _wait(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _openPage(WidgetTester tester) async {
  await tester.pumpWidget(const EcoApp());
  await tester.pump();
  AppRouter.router.go('/recompensas');
  await _wait(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _wait(tester);
}

Finder _pinField() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  testWidgets('resgata um cupom e confere no balcão', (tester) async {
    await signInDemo();
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openPage(tester);

    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.text('3.115'), findsOneWidget);
    expect(
      find.text('Cada 50 pontos valem cerca de R\$ 1 em benefícios.'),
      findsOneWidget,
    );
    expect(find.text('Gastronomia'), findsOneWidget);
    expect(find.textContaining('disponíveis'), findsWidgets);

    // Filtra pela busca e abre os detalhes.
    await tester.enterText(find.byType(TextField).first, 'Sobremesa');
    await _wait(tester, 2);
    final title = find.text('Sobremesa da casa grátis');
    expect(title, findsOneWidget);
    await _tap(tester, title);

    final redeemButton = find.text('Resgatar por 600 pts');
    expect(redeemButton, findsOneWidget);
    expect(find.text('Vale R\$ 12,00'), findsWidgets);
    expect(find.text('Válido por 30 dias após o resgate'), findsOneWidget);
    await _tap(tester, redeemButton);

    // Diálogo de confirmação.
    expect(find.text('Confirmar resgate'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Resgatar'));
    await _wait(tester);

    // Cupom aberto logo depois do resgate.
    expect(find.text('Seu cupom'), findsOneWidget);
    expect(find.text('Resgate confirmado!'), findsOneWidget);
    expect(find.textContaining('ECO-'), findsWidgets);
    expect(find.text('Copiar código'), findsOneWidget);

    // Código errado: o erro aparece dentro do diálogo, que continua aberto.
    await _tap(tester, find.text('Conferir no balcão').last);
    expect(
      find.text('Demonstração: o código dos parceiros é 1234.'),
      findsOneWidget,
    );
    await tester.enterText(_pinField(), '9999');
    await _tap(tester, find.widgetWithText(FilledButton, 'Confirmar'));
    expect(_pinField(), findsOneWidget);
    final field = tester.widget<TextField>(_pinField());
    expect(field.decoration?.errorText, isNotNull);
    expect(field.decoration!.errorText, isNotEmpty);

    // Código certo: fecha, avisa e o cupom passa a "Usado".
    await tester.enterText(_pinField(), '1234');
    await _tap(tester, find.widgetWithText(FilledButton, 'Confirmar'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Cupom conferido'), findsOneWidget);
    expect(find.text('Usado'), findsOneWidget);
    expect(find.text('Conferir no balcão'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Meus cupons separa disponíveis, usados e vencidos', (
    tester,
  ) async {
    await signInDemo();
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openPage(tester);

    expect(find.text('Meus cupons'), findsOneWidget);
    expect(find.text('Disponíveis (1)'), findsOneWidget);
    expect(find.text('Usados (1)'), findsOneWidget);
    expect(find.text('Vencidos (1)'), findsOneWidget);

    await _tap(tester, find.text('Vencidos (1)'));
    expect(find.textContaining('Venceu em'), findsOneWidget);

    await _tap(tester, find.textContaining('Venceu em'));
    expect(find.text('Seu cupom'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Conferir no balcão'), findsNothing);
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
    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Folha de detalhes.
    await tester.enterText(find.byType(TextField).first, 'Sobremesa');
    await _wait(tester, 2);
    await _tap(tester, find.text('Sobremesa da casa grátis'));
    expect(find.text('Resgatar por 600 pts'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Resgate e cupom.
    await _tap(tester, find.text('Resgatar por 600 pts'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Resgatar'));
    await _wait(tester);
    expect(find.text('Seu cupom'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Diálogo do balcão.
    await _tap(tester, find.text('Conferir no balcão').last);
    expect(_pinField(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
