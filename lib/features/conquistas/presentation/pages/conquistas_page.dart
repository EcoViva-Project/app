import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';

enum _AchievementFilter { all, unlocked, progress }

/// Conquistas (selos) do usuário e o progresso de cada uma.
class ConquistasPage extends StatefulWidget {
  const ConquistasPage({super.key});

  @override
  State<ConquistasPage> createState() => _ConquistasPageState();
}

class _ConquistasPageState extends State<ConquistasPage> {
  final AchievementService _service = AchievementService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  late final Listenable _listenable = Listenable.merge([_service, _progress]);

  _AchievementFilter _filter = _AchievementFilter.all;
  bool _reloading = false;

  /// Falha de carga que o serviço não registrou em `error`.
  String? _loadFailure;

  @override
  void initState() {
    super.initState();
    if (_service.isLoaded) return;
    // `load()` avisa os ouvintes na hora. Chamá-lo depois do primeiro quadro
    // evita avisar as outras telas no meio da montagem desta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_service.isLoaded) _reload();
    });
  }

  Future<void> _reload() async {
    if (_reloading) return;
    _reloading = true;
    if (_loadFailure != null) setState(() => _loadFailure = null);
    try {
      await Future.wait([
        _service.load(),
        // O nível é complementar: se falhar, a etiqueta só não aparece.
        _progress.load().catchError((_) {}),
      ]);
    } catch (error) {
      if (!mounted) return;
      if (_service.isLoaded) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível atualizar as conquistas.',
        );
      } else if (_service.error == null) {
        setState(
          () =>
              _loadFailure =
                  'Não foi possível carregar as conquistas. Tente de novo.',
        );
      }
    } finally {
      _reloading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/perfil'),
        ),
        title: Text(
          'Minhas Conquistas',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _listenable,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_service.isLoaded) {
      final error = _service.error ?? _loadFailure;
      if (error == null || _service.loading) {
        return const LoadingView(message: 'Carregando conquistas…');
      }
      return LoadErrorView(message: error, onRetry: _reload);
    }

    final total = _service.achievements.length;
    final unlocked = _service.unlocked;
    final inProgress = _service.inProgress;
    final showUnlocked =
        _filter != _AchievementFilter.progress && unlocked.isNotEmpty;
    final showProgress =
        _filter != _AchievementFilter.unlocked && inProgress.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _reload,
      color: AppColors.brandDarkAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _journeyCard(unlocked: unlocked.length, total: total),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _filterChip('Todas ($total)', _AchievementFilter.all),
                _filterChip(
                  'Desbloqueadas (${unlocked.length})',
                  _AchievementFilter.unlocked,
                ),
                _filterChip(
                  'Em progresso (${inProgress.length})',
                  _AchievementFilter.progress,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!showUnlocked && !showProgress)
              _emptyState(noneAtAll: total == 0),
            if (showUnlocked) ...[
              _sectionTitle(
                'Desbloqueadas',
                unlocked.length == 1 ? '1 selo' : '${unlocked.length} selos',
              ),
              const SizedBox(height: 10),
              for (final achievement in unlocked) ...[
                _unlockedCard(achievement),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
            if (showProgress) ...[
              _sectionTitle(
                'Próximos passos',
                '${inProgress.length} em andamento',
              ),
              const SizedBox(height: 10),
              for (final achievement in inProgress) ...[
                _inProgressCard(achievement),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _journeyCard({required int unlocked, required int total}) {
    // Sem conquistas na lista não há o que dividir.
    final percent = total == 0 ? 0.0 : unlocked / total;
    final level = _progress.isLoaded ? _progress.level : '';
    final percentLabel = '${(percent * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandSurface,
            AppColors.brandSecondaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'SUA JORNADA SUSTENTÁVEL',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              if (level.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: Text(
                    level,
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'Nenhuma conquista'
                      : '$unlocked de $total ${total == 1 ? 'conquista' : 'conquistas'}',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentLabel,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.brandSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brandPrimary,
              ),
              semanticsLabel: 'Conquistas desbloqueadas',
              semanticsValue: percentLabel,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.brandDarkAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'O bônus de cada conquista é creditado uma única vez, ao '
                    'desbloquear, e não entra no teto semanal de pontos.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _AchievementFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      // Garante 48 px de área de toque em qualquer plataforma.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      onSelected: (_) => setState(() => _filter = filter),
      backgroundColor: AppColors.brandSurface,
      selectedColor: AppColors.brandSecondaryContainer,
      side: BorderSide(
        color: selected ? AppColors.brandDarkAccent : AppColors.brandBorder,
      ),
      labelStyle: AppTextStyles.labelMd.copyWith(
        color:
            selected ? AppColors.brandDarkAccent : AppColors.brandTextSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }

  Widget _emptyState({required bool noneAtAll}) {
    if (noneAtAll) {
      return const EmptyStateView(
        icon: Icons.military_tech_outlined,
        title: 'Nenhuma conquista por aqui',
        message: 'Puxe a tela para baixo para atualizar.',
      );
    }
    if (_filter == _AchievementFilter.unlocked) {
      return EmptyStateView(
        icon: Icons.lock_outline,
        title: 'Nenhuma conquista desbloqueada ainda',
        message: 'Registre ações para desbloquear a primeira.',
        actionLabel: 'Ver em progresso',
        onAction: () => setState(() => _filter = _AchievementFilter.progress),
      );
    }
    return const EmptyStateView(
      icon: Icons.verified_outlined,
      title: 'Nada em progresso',
      message: 'Você já desbloqueou todas as conquistas.',
    );
  }

  Widget _sectionTitle(String title, String trailing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return MergeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brandBorder),
        ),
        child: child,
      ),
    );
  }

  Widget _header(Achievement achievement, {required List<Widget> details}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _badgeIcon(achievement.icon, unlocked: achievement.isUnlocked),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (achievement.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: details,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _unlockedCard(Achievement achievement) {
    final unlockedOn = achievement.unlockedOn;
    return _card(
      child: _header(
        achievement,
        details: [
          if (achievement.points > 0) _pointsChip(achievement.points),
          // Só mostra a data quando a API informou uma.
          if (unlockedOn != null && unlockedOn.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.brandTextSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Concluído em $unlockedOn',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _inProgressCard(Achievement achievement) {
    final progress = achievement.progress;
    final percentLabel = '${(progress * 100).round()}%';
    final missing = achievement.missing;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            achievement,
            details: [
              if (achievement.points > 0)
                _pointsChip(achievement.points, muted: true),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.progressLabel ??
                            '${achievement.current} de ${achievement.target}',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentLabel,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.brandBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                    semanticsLabel: 'Progresso de ${achievement.title}',
                    semanticsValue: percentLabel,
                  ),
                ),
                if (missing != null && missing.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    missing,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeIcon(IconData icon, {required bool unlocked}) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    unlocked
                        ? AppColors.brandSecondaryContainer
                        : AppColors.brandBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      unlocked
                          ? AppColors.brandPrimary.withValues(alpha: 0.2)
                          : AppColors.brandBorder,
                ),
              ),
              child: Icon(
                icon,
                size: 24,
                color:
                    unlocked
                        ? AppColors.brandDarkAccent
                        : AppColors.brandTextSecondary,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color:
                      unlocked
                          ? AppColors.brandTertiaryAccent
                          : AppColors.brandBorder,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandSurface, width: 2),
                ),
                child: Icon(
                  unlocked ? Icons.check : Icons.hourglass_top,
                  size: 12,
                  color:
                      unlocked
                          ? AppColors.brandDarkAccent
                          : AppColors.brandTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointsChip(int points, {bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            muted
                ? AppColors.brandBackground
                : AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$points pts de bônus',
        style: AppTextStyles.labelMd.copyWith(
          color:
              muted ? AppColors.brandTextSecondary : AppColors.brandDarkAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
