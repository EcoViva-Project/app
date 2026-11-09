import 'package:flutter/material.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'community_section.dart';

/// Chaves dos três cartões, usadas pelos testes.
const activeNeighborsStatKey = ValueKey('community-stat-active');
const actionsTodayStatKey = ValueKey('community-stat-today');
const actionsWeekStatKey = ValueKey('community-stat-week');

/// Três números da comunidade, calculados pela API sobre os registros de
/// todos: vizinhos ativos, ações hoje e ações nesta semana.
class CommunityNumbers extends StatelessWidget {
  const CommunityNumbers({super.key, required this.stats});

  final CommunityStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        key: activeNeighborsStatKey,
        icon: Icons.people_outline,
        value: stats.activeNeighbors,
        label: plural(
          stats.activeNeighbors,
          'vizinho ativo',
          'vizinhos ativos',
        ),
        detail: 'nos últimos 7 dias',
      ),
      _StatCard(
        key: actionsTodayStatKey,
        icon: Icons.today_outlined,
        value: stats.actionsToday,
        label: plural(stats.actionsToday, 'ação hoje', 'ações hoje'),
      ),
      _StatCard(
        key: actionsWeekStatKey,
        icon: Icons.date_range_outlined,
        value: stats.actionsThisWeek,
        label: plural(
          stats.actionsThisWeek,
          'ação nesta semana',
          'ações nesta semana',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Lado a lado só quando cabe; em tela estreita ou com fonte ampliada,
        // um embaixo do outro, sem cortar palavras.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final sideBySide = constraints.maxWidth >= 300 * scale;
        if (!sideBySide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                cards[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.detail,
  });

  final IconData icon;
  final int value;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final number = UserProgressService.formatNumber(value);
    return Semantics(
      container: true,
      label: [
        '$number $label',
        if (detail != null) detail!,
      ].join(', '),
      excludeSemantics: true,
      child: CommunityCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.brandDarkAccent),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                number,
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            if (detail != null)
              Text(
                detail!,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
