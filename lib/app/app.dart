import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/auth_service.dart';
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

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
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

class AppRouter {
  static const _authRoutes = {'/login', '/registro', '/esqueci-senha'};

  static final GoRouter router = GoRouter(
    initialLocation: '/inicio',
    refreshListenable: AuthService.instance,
    redirect: (context, state) {
      final auth = AuthService.instance;
      final location = state.matchedLocation;
      final isAuthRoute = _authRoutes.contains(location);

      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute) return '/inicio';
      return null;
    },
    routes: [
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
                builder: (context, state) => const AcoesPage(),
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
      GoRoute(
        path: '/registro-acao',
        name: 'registro_acao',
        builder: (context, state) {
          final action = state.extra as Map<String, dynamic>?;
          return RegistroAcaoPage(action: action);
        },
      ),
      GoRoute(
        path: '/confirmacao-registro',
        name: 'confirmacao_registro',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ConfirmacaoRegistroPage(extra: extra);
        },
      ),
      GoRoute(
        path: '/meu-historico',
        name: 'meu_historico',
        builder: (context, state) => const MeuHistoricoPage(),
      ),
      GoRoute(
        path: '/detalhes-desafio',
        name: 'detalhes_desafio',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DetalhesDesafioPage(extra: extra);
        },
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
      routerConfig: AppRouter.router,
    );
  }
}
