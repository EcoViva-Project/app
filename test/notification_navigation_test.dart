import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'notificações navegam para branches do shell sem duplicar chaves',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.debugSignIn();

      await tester.pumpWidget(const EcoApp());
      await tester.pumpAndSettle();

      final router = AppRouter.router;

      Future<void> abrirNotificacoes() async {
        router.push('/notificacoes');
        await tester.pumpAndSettle();
      }

      Future<void> abrirDetalheENavegar(
        String titulo,
        String marcadorDestino,
      ) async {
        await tester.tap(find.text(titulo));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver no aplicativo'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Falhou em: $titulo');
        expect(
          find.text(marcadorDestino),
          findsOneWidget,
          reason: 'Destino incorreto para: $titulo',
        );
      }

      // Conquista: rota fora do shell (push).
      await abrirNotificacoes();
      await abrirDetalheENavegar(
        'Novo selo desbloqueado!',
        'Minhas Conquistas',
      );

      // Desafio: branch do shell (deve usar go).
      router.go('/inicio');
      await tester.pumpAndSettle();
      await abrirNotificacoes();
      await abrirDetalheENavegar(
        'Meta coletiva quase lá',
        'Desafios Sustentáveis',
      );

      // Comunidade: branch do shell.
      router.go('/inicio');
      await tester.pumpAndSettle();
      await abrirNotificacoes();
      await abrirDetalheENavegar(
        'Mariana comentou na sua ação',
        'Meta Coletiva da Semana',
      );

      // Sistema: branch do shell (/acoes).
      router.go('/inicio');
      await tester.pumpAndSettle();
      await abrirNotificacoes();
      await abrirDetalheENavegar('Lembrete gentil', 'Ações Sustentáveis');
    },
  );
}
