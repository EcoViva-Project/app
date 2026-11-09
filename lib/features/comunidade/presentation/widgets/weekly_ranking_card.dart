import 'package:flutter/material.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'community_section.dart';

String _pointsLabel(int points) =>
    '${UserProgressService.formatNumber(points)} ${plural(points, 'pt', 'pts')}';

/// Ranking da semana: as cinco primeiras posições e a do próprio usuário.
class WeeklyRankingCard extends StatelessWidget {
  const WeeklyRankingCard({super.key, required this.stats});

  final CommunityStats stats;

  @override
  Widget build(BuildContext context) {
    final ranking = stats.ranking;
    final myPosition = stats.myPosition;
    final showMyLine = myPosition != null && myPosition > ranking.length;

    return CommunityCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ranking.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Ninguém pontuou nesta semana ainda.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
          for (final entry in ranking) _RankingRow(entry: entry),
          if (showMyLine) ...[
            const Divider(height: 12, color: AppColors.brandBorder),
            _MyPositionRow(
              position: myPosition,
              points: stats.myWeeklyPoints,
            ),
          ],
          if (myPosition == null) ...[
            const Divider(height: 12, color: AppColors.brandBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CommunityDetailLine(
                icon: Icons.emoji_events_outlined,
                label: 'Convite',
                text:
                    'Você ainda não pontuou nesta semana. Registre uma ação '
                    'para entrar no ranking.',
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              'Conta os pontos de ações desta semana. Com o teto semanal de '
              'pontos, a disputa é justa.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final neighborhood = entry.neighborhood?.trim() ?? '';
    final semantics = [
      '${entry.position}º lugar',
      entry.isMe ? '${entry.name} (você)' : entry.name,
      if (neighborhood.isNotEmpty) neighborhood,
      _pointsLabel(entry.points),
    ].join(', ');

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              entry.isMe ? AppColors.brandSecondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              entry.isMe
                  ? Border.all(color: AppColors.brandDarkAccent)
                  : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.position}º',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  entry.isMe
                      ? AppColors.brandDarkAccent
                      : AppColors.brandSecondaryContainer,
              child: Text(
                entry.initials,
                style: AppTextStyles.labelMd.copyWith(
                  color:
                      entry.isMe ? Colors.white : AppColors.brandDarkAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.name,
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      if (entry.isMe) const _YouTag(),
                    ],
                  ),
                  if (neighborhood.isNotEmpty)
                    Text(
                      neighborhood,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _pointsLabel(entry.points),
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandDarkAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Você',
        style: AppTextStyles.labelMd.copyWith(color: Colors.white),
      ),
    );
  }
}

class _MyPositionRow extends StatelessWidget {
  const _MyPositionRow({required this.position, required this.points});

  final int position;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sua posição: $positionº, ${_pointsLabel(points)}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brandSecondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined,
                color: AppColors.brandDarkAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sua posição: $positionº',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
            Text(
              _pointsLabel(points),
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
