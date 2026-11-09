import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/inicio/presentation/pages/home_page.dart';
import '../features/acoes/presentation/pages/acoes_page.dart';
import '../features/desafios/presentation/pages/desafios_page.dart';
import '../features/comunidade/presentation/pages/comunidade_page.dart';
import '../features/perfil/presentation/pages/perfil_page.dart';
import '../features/registro_acao/presentation/pages/registro_acao_page.dart';
import '../features/confirmacao_registro/presentation/pages/confirmacao_registro_page.dart';
import '../features/meu_historico/presentation/pages/meu_historico_page.dart';
import '../features/detalhes_desafio/presentation/pages/detalhes_desafio_page.dart';
import '../features/progresso/presentation/pages/progresso_page.dart';
import '../features/conquistas/presentation/pages/conquistas_page.dart';
import '../features/preferencias/presentation/pages/preferencias_page.dart';
import '../features/notificacoes/presentation/pages/notificacoes_page.dart';
import '../features/recompensas/presentation/pages/recompensas_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        // Mesmo tamanho nos dois estados: o rótulo mais longo ("Comunidade")
        // cabe inteiro em telas estreitas e a barra não "pula" ao trocar de aba.
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap:
            (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/images/eco_leaf_icon.png')),
            activeIcon: ImageIcon(
              AssetImage('assets/images/eco_leaf_icon_filled.png'),
            ),
            label: 'Ações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Desafios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Comunidade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Tela mostrada enquanto a sessão salva é conferida.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/eco_leaf_logo.png',
              width: 96,
              height: 96,
              semanticLabel: 'EcoViva',
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppColors.brandDarkAccent),
            const SizedBox(height: 12),
            Text(
              'Abrindo o EcoViva…',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Endereço que não existe no app.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_off_outlined,
                  size: 48,
                  color: AppColors.brandTextSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não encontramos esta tela',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/inicio'),
                  child: const Text('Ir para o início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppRouter {
  static const _authRoutes = {'/login', '/registro', '/esqueci-senha'};
  static const _splash = '/abrindo';

  static final GoRouter router = GoRouter(
    initialLocation: '/inicio',
    refreshListenable: AuthService.instance,
    redirect: (context, state) {
      final auth = AuthService.instance;
      final location = state.matchedLocation;

      if (!auth.initialized) return location == _splash ? null : _splash;

      final isAuthRoute = _authRoutes.contains(location);
      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute || location == _splash) return '/inicio';
      return null;
    },
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: _splash,
        name: 'abrindo',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/registro',
        name: 'registro',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/esqueci-senha',
        name: 'esqueci_senha',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inicio',
                name: 'inicio',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/acoes',
                name: 'acoes',
                // `/acoes?categoria=Água` abre a lista já filtrada.
                builder:
                    (context, state) => AcoesPage(
                      initialCategory: state.uri.queryParameters['categoria'],
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/desafios',
                name: 'desafios',
                builder: (context, state) => const DesafiosPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/comunidade',
                name: 'comunidade',
                builder: (context, state) => const ComunidadePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/perfil',
                name: 'perfil',
                builder: (context, state) => const PerfilPage(),
              ),
            ],
          ),
        ],
      ),
      // As telas abaixo recebem o identificador pelo endereço, e não por
      // `extra`, para continuarem funcionando ao recarregar a página na web
      // ou ao abrir o endereço direto.
      GoRoute(
        path: '/registro-acao/:id',
        name: 'registro_acao',
        builder:
            (context, state) => RegistroAcaoPage(
              actionId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
      ),
      GoRoute(
        path: '/confirmacao-registro',
        name: 'confirmacao_registro',
        builder: (context, state) => const ConfirmacaoRegistroPage(),
      ),
      GoRoute(
        path: '/meu-historico',
        name: 'meu_historico',
        builder: (context, state) => const MeuHistoricoPage(),
      ),
      GoRoute(
        path: '/detalhes-desafio/:id',
        name: 'detalhes_desafio',
        builder:
            (context, state) => DetalhesDesafioPage(
              challengeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
      ),
      GoRoute(
        path: '/progresso',
        name: 'progresso',
        builder: (context, state) => const ProgressoPage(),
      ),
      GoRoute(
        path: '/conquistas',
        name: 'conquistas',
        builder: (context, state) => const ConquistasPage(),
      ),
      GoRoute(
        path: '/preferencias',
        name: 'preferencias',
        builder: (context, state) => const PreferenciasPage(),
      ),
      GoRoute(
        path: '/notificacoes',
        name: 'notificacoes',
        builder: (context, state) => const NotificacoesPage(),
      ),
      GoRoute(
        path: '/recompensas',
        name: 'recompensas',
        builder: (context, state) => const RecompensasPage(),
      ),
    ],
  );
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoViva',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: AppRouter.router,
    );
  }
}
