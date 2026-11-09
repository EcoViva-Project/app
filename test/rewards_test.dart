import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/reward_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(RewardService.instance.reset);
  tearDown(RewardService.instance.reset);

  test('catálogo local filtra por categoria, busca e ordena', () {
    final service = RewardService.instance;

    expect(service.rewards.length, 4);
    // Destaques primeiro e, dentro de cada grupo, menor custo.
    expect(service.rewards.first.title, 'Kit de sacolas reutilizáveis');

    service.setCategory(RewardCategoryFilter.desconto);
    expect(service.rewards.length, 1);
    expect(service.rewards.single.title, 'Café especial grátis');

    service.setCategory(RewardCategoryFilter.jogo);
    expect(service.rewards.single.title, 'Skin Guardião da Floresta');

    service.setCategory(RewardCategoryFilter.todas);
    service.setSearch('mercado');
    expect(service.rewards.single.partnerName, 'Mercado Verde');

    service.setSearch('cafe');
    expect(service.rewards.single.title, 'Café especial grátis');

    service.setSearch('');
    service.setSort(RewardSort.menorCusto);
    expect(service.rewards.map((reward) => reward.pointsCost).toList(), [
      150,
      400,
      500,
      700,
    ]);

    service.setSort(RewardSort.alfabetica);
    expect(service.rewards.map((reward) => reward.title).toList(), [
      'Café especial grátis',
      'Kit de sacolas reutilizáveis',
      'Revisão básica de bicicleta',
      'Skin Guardião da Floresta',
    ]);
  });

  testWidgets('tela de recompensas mostra saldo e catálogo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSignIn();
    addTearDown(AuthService.instance.logout);

    await tester.pumpWidget(const EcoApp());
    await tester.pump();

    AppRouter.router.go('/recompensas');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('SEUS PONTOS DISPONÍVEIS'), findsOneWidget);
    expect(find.text('Café especial grátis'), findsOneWidget);
    expect(find.text('Resgatar'), findsWidgets);
  });
}
