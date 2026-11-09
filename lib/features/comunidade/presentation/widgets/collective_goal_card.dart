import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'community_section.dart';

/// Meta coletiva da semana: soma das ações registradas por toda a comunidade.
class CollectiveGoalCard extends StatelessWidget {
  const CollectiveGoalCard({super.key, required this.goal});

  final CollectiveGoal goal;

  String get _contributorsLabel {
    final count = goal.contributors;
    if (count == 0) return 'Ninguém contribuiu ainda. Comece você!';
    final number = UserProgressService.formatNumber(count);
    return count == 1
        ? '1 pessoa já contribuiu'
        : '$number pessoas já contribuíram';
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0.0, 1.0);

    return CommunityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityIconBadge(
                icon: goal.reached ? Icons.celebration : Icons.flag_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        goal.title,
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        goal.description,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (goal.reached) ...[
            const SizedBox(height: 12),
            const _ReachedBanner(),
          ],
          const SizedBox(height: 14),
          Semantics(
            label: '${goal.countLabel}, ${goal.percentLabel}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: AppColors.brandDarkAccent,
                    backgroundColor: AppColors.brandSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      goal.countLabel,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    Text(
                      goal.percentLabel,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.brandDarkAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CommunityDetailLine(
            icon: Icons.people_outline,
            label: 'Participação',
            text: _contributorsLabel,
          ),
          const SizedBox(height: 4),
          CommunityDetailLine(
            icon: Icons.schedule,
            label: 'Prazo',
            text: goal.deadlineLabel,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => context.go('/acoes'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Registrar ação'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReachedBanner extends StatelessWidget {
  const _ReachedBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brandTertiaryAccent.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.emoji_events, color: AppColors.brandDarkAccent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meta alcançada! Cada ação registrada agora é bônus para a '
                'vizinhança.',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
