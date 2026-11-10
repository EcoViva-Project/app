import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/user_progress_service.dart';
import 'package:eco_app/core/utils/impact_equivalents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
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

void main() {
  group('equivalências da água poupada', () {
    test('abaixo de um garrafão não mostra nada', () {
      expect(WaterEquivalents.of(0), isNull);
      expect(WaterEquivalents.of(12), isNull);
      expect(WaterEquivalents.of(19), isNull);
    });

    test('um garrafão, no singular, ainda sem um dia de água', () {
      final water = WaterEquivalents.of(20)!;
      expect(water.jugs, 1);
      expect(water.personDays, 0);
      expect(water.shortLine, '≈ 1 garrafão de 20 L');
      expect(water.spokenShortLine, 'cerca de 1 garrafão de 20 litros');
      expect(
        water.sentence,
        'Seus 20 litros poupados equivalem a cerca de 1 garrafão de 20 '
        'litros. A ONU considera 110 litros por dia o suficiente para uma '
        'pessoa.',
      );
    });

    test('arredonda para baixo', () {
      final water = WaterEquivalents.of(39)!;
      expect(water.jugs, 1);
      expect(WaterEquivalents.of(40)!.jugs, 2);
      expect(WaterEquivalents.of(109)!.personDays, 0);
      expect(WaterEquivalents.of(110)!.personDays, 1);
      expect(WaterEquivalents.of(219)!.personDays, 1);
      expect(WaterEquivalents.of(220)!.personDays, 2);
    });

    test('plural e números com ponto de milhar', () {
      final one = WaterEquivalents.of(110)!;
      expect(one.personDaysText, '1 dia de água para uma pessoa');
      expect(one.shortLine, '≈ 5 garrafões de 20 L');

      final many = WaterEquivalents.of(25000)!;
      expect(many.jugs, 1250);
      expect(many.personDays, 227);
      expect(many.shortLine, '≈ 1.250 garrafões de 20 L');
      expect(
        many.sentence,
        'Seus 25.000 litros poupados equivalem a cerca de 1.250 garrafões '
        'de 20 litros, ou 227 dias de água para uma pessoa. A ONU considera '
        '110 litros por dia o suficiente para uma pessoa.',
      );
    });
  });

  group('telas', () {
    setUp(() async {
      await useLocalBackend();
    });

    testWidgets('conta de demonstração vê os garrafões na Início e a frase '
        'completa no Progresso', (tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await signInDemo();
      final liters = UserProgressService.instance.litersSaved;
      final water = WaterEquivalents.of(liters);
      expect(water, isNotNull, reason: 'a demonstração tem água poupada');

      await tester.pumpWidget(const EcoApp());
      await tester.pump();

      await _open(tester, '/inicio');
      expect(find.text(water!.shortLine), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Água poupada: '
          '${UserProgressService.formatNumber(liters)} litros, '
          '${water.spokenShortLine}',
        ),
        findsOneWidget,
      );

      await _open(tester, '/progresso');
      final sentence = find.text(water.sentence);
      await _reveal(tester, sentence);
      expect(sentence, findsOneWidget);
      expect(water.sentence, contains('110 litros por dia'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('conta com poucos litros não vê nada a mais', (tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.register(
        name: 'Bruno Lima',
        email: 'bruno@eco.app',
        password: 'segredo123',
        neighborhood: 'Vila Toninho',
      );
      // Fechar a torneira: 12 litros, menos de um garrafão.
      await ActionHistoryService.instance.submitAction(
        actionId: 1,
        quantity: 1,
      );
      await UserProgressService.instance.load();
      expect(UserProgressService.instance.litersSaved, 12);

      await tester.pumpWidget(const EcoApp());
      await tester.pump();

      await _open(tester, '/inicio');
      expect(find.text('12 L'), findsOneWidget);
      expect(find.textContaining('garrafõ'), findsNothing);
      expect(find.textContaining('garrafão'), findsNothing);

      await _open(tester, '/progresso');
      expect(find.textContaining('litros poupados'), findsNothing);
      expect(find.text('Água poupada'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
