import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum _AchievementFilter { all, unlocked, progress }

class ConquistasPage extends StatefulWidget {
  const ConquistasPage({super.key});

  @override
  State<ConquistasPage> createState() => _ConquistasPageState();
}

class _ConquistasPageState extends State<ConquistasPage> {
  List<Achievement> get _achievements =>
      AchievementService.instance.achievements;

  _AchievementFilter _filter = _AchievementFilter.all;

  List<Achievement> get _unlocked =>
      _achievements.where((achievement) => achievement.isUnlocked).toList();

  List<Achievement> get _inProgress =>
      _achievements.where((achievement) => !achievement.isUnlocked).toList();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProgressService.instance,
      builder: (context, _) {
        final unlocked = _unlocked;
        final inProgress = _inProgress;
        final showUnlocked =
            _filter == _AchievementFilter.all ||
            _filter == _AchievementFilter.unlocked;
        final showProgress =
            _filter == _AchievementFilter.all ||
            _filter == _AchievementFilter.progress;

        return Scaffold(
          backgroundColor: AppColors.brandBackground,
          appBar: AppBar(
            backgroundColor: AppColors.brandBackground,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.brandTextPrimary,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/desafios');
                }
              },
            ),
            title: Text(
              'Minhas Conquistas',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJourneyCard(unlocked.length),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          label: 'Todas (${_achievements.length})',
                          selected: _filter == _AchievementFilter.all,
                          onTap:
                              () => setState(
                                () => _filter = _AchievementFilter.all,
                              ),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Desbloqueadas (${unlocked.length})',
                          selected: _filter == _AchievementFilter.unlocked,
                          onTap:
                              () => setState(
                                () => _filter = _AchievementFilter.unlocked,
                              ),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Em progresso (${inProgress.length})',
                          selected: _filter == _AchievementFilter.progress,
                          onTap:
                              () => setState(
                                () => _filter = _AchievementFilter.progress,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (showUnlocked) ...[
                    _sectionTitle(
                      title: 'Desbloqueadas',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${unlocked.length} selos ativos',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < unlocked.length; i++) ...[
                      _unlockedCard(unlocked[i]),
                      if (i < unlocked.length - 1) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 18),
                  ],
                  if (showProgress) ...[
                    _sectionTitle(
                      title: 'Próximos Passos',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.hourglass_top,
                            size: 16,
                            color: AppColors.brandTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${inProgress.length} em andamento',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < inProgress.length; i++) ...[
                      _inProgressCard(inProgress[i]),
                      if (i < inProgress.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJourneyCard(int unlockedCount) {
    final percent = unlockedCount / _achievements.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandSurface,
            AppColors.brandSecondaryContainer.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SUA JORNADA SUSTENTÁVEL',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Nível Semente',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w600,
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
                  '$unlockedCount de ${_achievements.length} conquistas',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
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
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandSurface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cada pequeno hábito fortalece sua comunidade e inspira quem está ao redor.',
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

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.brandSecondaryContainer
                    : AppColors.brandSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? AppColors.brandSecondaryContainer
                      : AppColors.brandBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMd.copyWith(
              color:
                  selected
                      ? AppColors.brandDarkAccent
                      : AppColors.brandTextSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle({required String title, required Widget trailing}) {
    return Row(
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
        trailing,
      ],
    );
  }

  Widget _unlockedCard(Achievement achievement) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badgeIcon(achievement.icon, unlocked: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _pointsChip(achievement.points),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppColors.brandTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Concluído em ${achievement.unlockedOn ?? 'Hoje'}',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inProgressCard(Achievement achievement) {
    final progress = achievement.progress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _badgeIcon(achievement.icon, unlocked: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _pointsChip(achievement.points, muted: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.description,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
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
                        achievement.progressLabel ?? '',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandPrimary,
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
                    minHeight: 6,
                    backgroundColor: AppColors.brandBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                  ),
                ),
                if (achievement.missing != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    achievement.missing!,
                    style: AppTextStyles.labelSm.copyWith(
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
    return SizedBox(
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
                        ? AppColors.brandPrimary.withOpacity(0.2)
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
                size: 11,
                color:
                    unlocked
                        ? AppColors.brandDarkAccent
                        : AppColors.brandTextSecondary,
              ),
            ),
          ),
        ],
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
        '+$points pts',
        style: AppTextStyles.labelSm.copyWith(
          color: muted ? AppColors.brandTextSecondary : AppColors.brandPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
