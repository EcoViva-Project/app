import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/impact_equivalents.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/weekly_cap_card.dart';
import '../widgets/progresso_sections.dart';

/// "Meu progresso": totais, nível, sequência, semana, categorias, desafios
/// e últimas ações. Todos os números vêm dos serviços.
class ProgressoPage extends StatefulWidget {
  const ProgressoPage({super.key});

  @override
  State<ProgressoPage> createState() => _ProgressoPageState();
}

class _ProgressoPageState extends State<ProgressoPage> {
  static const String _loadFallback =
      'Não foi possível carregar seus dados. Tente de novo.';

  final Listenable _services = Listenable.merge([
    AuthService.instance,
    UserProgressService.instance,
    ActionHistoryService.instance,
    ChallengeService.instance,
    ActionCatalogService.instance,
  ]);

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
      // `showBack`: volta para a tela anterior ou, sem pilha, para o Perfil.
      appBar: const AppPageHeader(
        pageIcon: Icons.insights,
        title: 'Meu progresso',
        showBack: true,
        backFallback: '/perfil',
        showProfileAvatar: false,
      ),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: _buildContent(context, progress),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserProgressService progress) {
    final history = ActionHistoryService.instance;
    final water = WaterEquivalents.of(progress.litersSaved);
    const gap = SizedBox(height: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acompanhe seus hábitos e veja como pequenas atitudes diárias somam.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        gap,
        ProgressStatsRow(progress: progress),
        const SizedBox(height: 12),
        ProgressLevelCard(progress: progress),
        const SizedBox(height: 12),
        if (progress.hasWeeklyCap) ...[
          const WeeklyCapCard(),
          const SizedBox(height: 12),
        ],
        ProgressStreakCard(
          streakDays: progress.streakDays,
          bestStreak: progress.bestStreak,
        ),
        if (water != null) ...[
          const SizedBox(height: 12),
          ProgressWaterCard(water: water),
        ],
        gap,
        ProgressWeekChart(history: history),
        gap,
        ProgressCategories(
          history: history,
          categories: ActionCatalogService.instance.categories,
        ),
        gap,
        ProgressOngoingChallenges(challenges: ChallengeService.instance),
        gap,
        ProgressRecentRecords(history: history),
        const SizedBox(height: 20),
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
      ],
    );
  }
}
