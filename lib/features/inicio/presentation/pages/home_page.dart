import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/reset_demo_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/weekly_cap_card.dart';
import '../widgets/home_sections.dart';

/// Aba "Início": resumo do usuário. Todos os números vêm dos serviços;
/// enquanto o resumo não carrega, a tela mostra carregamento ou erro.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _loadFallback =
      'Não foi possível carregar seus dados. Tente de novo.';

  final Listenable _services = Listenable.merge([
    AuthService.instance,
    UserProgressService.instance,
    ActionHistoryService.instance,
    ChallengeService.instance,
    AchievementService.instance,
    RewardService.instance,
    ActionCatalogService.instance,
    NeighborhoodService.instance,
  ]);

  bool _refreshingDemo = false;

  /// Aviso "Atualizar agora": pergunta como em Perfil → "Restaurar
  /// demonstração", recria os dados e entra de novo, ficando na Início.
  Future<void> _refreshDemo() async {
    if (_refreshingDemo) return;
    final confirmed = await confirmResetDemo(
      context,
      afterwards: 'Depois, o app entra de novo na conta de demonstração.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _refreshingDemo = true);
    try {
      await AuthService.instance.refreshDemo();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Demonstração atualizada com os números de hoje.'),
          ),
        );
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível atualizar a demonstração.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingDemo = false);
    }
  }

  Future<void> _refresh() async {
    await AuthService.instance.loadAll();
    if (!mounted) return;
    // Os dados antigos continuam na tela; avisa que não foram atualizados.
    final error = UserProgressService.instance.error;
    if (error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(pageIcon: Icons.eco, title: 'Início'),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _services,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final progress = UserProgressService.instance;
    if (_refreshingDemo) {
      return const LoadingView(message: 'Atualizando a demonstração…');
    }
    if (!progress.isLoaded) {
      if (progress.loading) {
        return const LoadingView(message: 'Carregando seus dados…');
      }
      // Sem sessão (saindo da conta) o roteador já está levando ao login:
      // não é um erro de carga.
      if (!AuthService.instance.isAuthenticated) {
        return const SizedBox.shrink();
      }
      return LoadErrorView(
        message: progress.error ?? _loadFallback,
        onRetry: AuthService.instance.loadAll,
      );
    }

    return RefreshIndicator(
      color: AppColors.brandDarkAccent,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: _buildContent(context, progress),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserProgressService progress) {
    final auth = AuthService.instance;
    final history = ActionHistoryService.instance;
    final featured = ChallengeService.instance.featured;
    final categories = ActionCatalogService.instance.categories;
    final neighborhood = NeighborhoodService.instance;
    final stats = neighborhood.isLoaded ? neighborhood.stats : null;
    final tip = neighborhood.tip;
    const gap = SizedBox(height: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (auth.showDemoStaleNotice) ...[
                HomeDemoStaleBanner(
                  seededOn: auth.demoSeededOn,
                  onRefresh: _refreshDemo,
                  onDismiss: auth.dismissDemoStaleNotice,
                ),
                const SizedBox(height: 12),
              ],
              _Greeting(
                firstName: auth.firstName,
                neighborhood: auth.neighborhood,
              ),
              const SizedBox(height: 12),
              HomeBalanceCard(progress: progress),
              const SizedBox(height: 12),
              if (progress.hasWeeklyCap) ...[
                WeeklyCapCard(onTap: () => context.push('/progresso')),
                const SizedBox(height: 12),
              ],
              HomeIndicators(progress: progress),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/acoes'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Registrar ação'),
                ),
              ),
              gap,
              HomeWeekSection(history: history, weeklyGoal: auth.weeklyGoal),
              gap,
              if (stats != null) ...[HomeCommunitySection(stats: stats), gap],
              if (featured != null) ...[
                HomeFeaturedChallenge(challenge: featured),
                gap,
              ],
              HomeRewardsShortcut(
                formattedPoints: progress.formattedPoints,
                activeCoupons: RewardService.instance.activeCoupons.length,
              ),
              gap,
            ],
          ),
        ),
        if (categories.isNotEmpty) ...[
          HomeCategories(categories: categories),
          gap,
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeRecentActivity(history: history),
              if (tip != null && tip.text.isNotEmpty) ...[
                gap,
                HomeDailyTip(tip: tip),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Saudação com o primeiro nome; acompanha a troca de nome no perfil.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName, required this.neighborhood});

  final String firstName;
  final String neighborhood;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (neighborhood.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Comunidade $neighborhood',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandDarkAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          header: true,
          child: Text(
            firstName.isEmpty ? 'Olá' : 'Olá, $firstName',
            style: AppTextStyles.headlineLg.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cada pequeno hábito transforma o nosso bairro. Que tal registrar uma ação hoje?',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
      ],
    );
  }
}
