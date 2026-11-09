import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';
import 'shared_blocks.dart';

// Blocos da tela Meu progresso. Cada um recebe os dados (ou o serviço) pelo
// construtor, para ser reconstruído sempre que a tela reagir a um serviço.

/// Três números do topo: pontos ganhos no total, ações e dias ativos.
class ProgressStatsRow extends StatelessWidget {
  const ProgressStatsRow({super.key, required this.progress});

  final UserProgressService progress;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.stars_outlined,
              value: UserProgressService.formatNumber(progress.pointsEarned),
              label: 'Pontos ganhos no total',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.eco_outlined,
              value: UserProgressService.formatNumber(progress.actionsCount),
              label: progress.actionsCount == 1 ? 'Ação' : 'Ações',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.calendar_today_outlined,
              value: UserProgressService.formatNumber(progress.activeDays),
              label: progress.activeDays == 1 ? 'Dia ativo' : 'Dias ativos',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: EcoCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.brandDarkAccent),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
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

/// Nível atual e quanto falta para o próximo.
class ProgressLevelCard extends StatelessWidget {
  const ProgressLevelCard({super.key, required this.progress});

  final UserProgressService progress;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu nível',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          LevelProgressBlock(progress: progress),
        ],
      ),
    );
  }
}

/// Sequência de dias: a atual e a melhor, ou um convite quando está zerada.
class ProgressStreakCard extends StatelessWidget {
  const ProgressStreakCard({
    super.key,
    required this.streakDays,
    required this.bestStreak,
  });

  final int streakDays;
  final int bestStreak;

  /// "3 dias seguidos. Sua melhor sequência: 12 dias."
  static String message(int streakDays, int bestStreak) {
    final best = countLabel(bestStreak, 'dia', 'dias');
    if (streakDays > 0) {
      final current =
          '${countLabel(streakDays, 'dia seguido', 'dias seguidos')}.';
      return bestStreak > 0 ? '$current Sua melhor sequência: $best.' : current;
    }
    if (bestStreak > 0) {
      return 'Sua melhor sequência: $best. '
          'Registre uma ação hoje para começar outra.';
    }
    return 'Registre uma ação hoje para começar uma sequência.';
  }

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      color: AppColors.brandSecondaryContainer,
      bordered: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_fire_department_outlined,
              color: AppColors.brandDarkAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sequência',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message(streakDays, bestStreak),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Atividade da semana": ações por dia, de segunda a domingo.
class ProgressWeekChart extends StatelessWidget {
  const ProgressWeekChart({super.key, required this.history});

  final ActionHistoryService history;

  @override
  Widget build(BuildContext context) {
    if (!history.isLoaded) {
      return EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Atividade da semana'),
            ModuleStateView(loading: history.loading, error: history.error),
          ],
        ),
      );
    }

    final days = history.currentWeek();
    final total = days.fold<int>(0, (sum, day) => sum + day.actions);
    final highest = days.fold<int>(1, (top, day) => math.max(top, day.actions));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final totalLabel = countLabel(total, 'ação', 'ações');

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Atividade da semana',
            subtitle: 'Ações por dia, de segunda a domingo',
            trailing: Text(
              totalLabel,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: 'Gráfico de ações desta semana. Total: $totalLabel.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _WeekBar(
                      day: days[i],
                      index: i,
                      today: today,
                      highest: highest,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.day,
    required this.index,
    required this.today,
    required this.highest,
  });

  final DayActivity day;

  /// Posição na semana: 0 = segunda, 6 = domingo.
  final int index;
  final DateTime today;

  /// Maior número de ações em um dia desta semana (no mínimo 1).
  final int highest;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(day.date, today);
    final isFuture = day.date.isAfter(today);
    final name = weekdayFullNames[index];
    final String spoken;
    if (isFuture) {
      spoken = '$name: ainda não chegou';
    } else {
      final count =
          day.actions == 0
              ? 'nenhuma ação'
              : countLabel(day.actions, 'ação', 'ações');
      spoken = '$name${isToday ? ' (hoje)' : ''}: $count';
    }
    final textStyle = AppTextStyles.labelMd.copyWith(
      color: isToday ? AppColors.brandDarkAccent : AppColors.brandTextSecondary,
      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(isFuture ? '–' : '${day.actions}', style: textStyle),
            ),
            const SizedBox(height: 4),
            Container(
              height: 88,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color:
                    isToday
                        ? AppColors.brandSecondaryContainer
                        : AppColors.brandBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: day.actions / highest,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        isToday
                            ? AppColors.brandDarkAccent
                            : AppColors.brandPrimary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ActionHistoryService.weekdayLabels[index],
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ações por categoria": contagem e percentual de cada categoria.
class ProgressCategories extends StatelessWidget {
  const ProgressCategories({
    super.key,
    required this.history,
    required this.categories,
  });

  final ActionHistoryService history;

  /// Categorias do catálogo, de onde vem o ícone de cada uma.
  final List<ActionCategory> categories;

  static const List<Color> _barColors = [
    AppColors.brandDarkAccent,
    AppColors.brandPrimary,
    AppColors.tertiary,
    AppColors.secondary,
    AppColors.tertiaryContainer,
    AppColors.outline,
  ];

  IconData _iconFor(String label) {
    for (final category in categories) {
      if (category.label == label) return category.icon;
    }
    return Icons.eco;
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        history.isLoaded
            ? history.actionsByCategory()
            : const <MapEntry<String, int>>[];
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Ações por categoria'),
          const SizedBox(height: 10),
          if (!history.isLoaded)
            ModuleStateView(loading: history.loading, error: history.error)
          else if (entries.isEmpty)
            Text(
              'Quando você registrar ações, elas aparecem aqui separadas por categoria.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            )
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: _CategoryRow(
                  icon: _iconFor(entries[i].key),
                  label: entries[i].key,
                  count: entries[i].value,
                  share: entries[i].value / total,
                  color: _barColors[i % _barColors.length],
                ),
              ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.share,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;

  /// Parte do total de ações, de 0 a 1.
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final detail =
        '${countLabel(count, 'ação', 'ações')} (${(share * 100).round()}%)';
    return Semantics(
      label: '$label: $detail',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabelValueRow(
            icon: icon,
            iconColor: color,
            label: label,
            value: detail,
            labelStyle: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w600,
            ),
            valueStyle: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          EcoProgressBar(
            value: share,
            minHeight: 6,
            color: color,
            backgroundColor: AppColors.brandBackground,
          ),
        ],
      ),
    );
  }
}

/// "Desafios em andamento": os desafios em que o usuário entrou.
class ProgressOngoingChallenges extends StatelessWidget {
  const ProgressOngoingChallenges({super.key, required this.challenges});

  final ChallengeService challenges;

  @override
  Widget build(BuildContext context) {
    final ongoing = challenges.ongoing;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Desafios em andamento',
            actionLabel: 'Ver todos',
            onAction: () => context.go('/desafios'),
          ),
          const SizedBox(height: 6),
          if (!challenges.isLoaded)
            ModuleStateView(
              loading: challenges.loading,
              error: challenges.error,
            )
          else if (ongoing.isEmpty)
            EmptyStateView(
              icon: Icons.emoji_events_outlined,
              title: 'Nenhum desafio em andamento',
              message:
                  'Entre em um desafio: ele avança sozinho quando você registra ações da categoria.',
              actionLabel: 'Ver desafios',
              onAction: () => context.go('/desafios'),
              padding: 8,
            )
          else
            for (var i = 0; i < ongoing.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: _ChallengeTile(challenge: ongoing[i]),
              ),
        ],
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      radius: 12,
      bordered: false,
      color: AppColors.brandBackground,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/detalhes-desafio/${challenge.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(challenge.icon, size: 18, color: AppColors.brandDarkAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.brandDarkAccent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${challenge.stepsLabel} • ${challenge.deadlineLabel}',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          EcoProgressBar(
            value: challenge.progress,
            minHeight: 6,
            backgroundColor: AppColors.brandBorder,
            semanticsLabel: 'Progresso do desafio',
          ),
        ],
      ),
    );
  }
}

/// "Últimas ações": os cinco lançamentos mais novos do histórico.
class ProgressRecentRecords extends StatelessWidget {
  const ProgressRecentRecords({super.key, required this.history});

  final ActionHistoryService history;

  @override
  Widget build(BuildContext context) {
    final records = history.records.take(5).toList();
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Últimas ações',
            actionLabel: 'Ver histórico',
            onAction: () => context.push('/meu-historico'),
          ),
          const SizedBox(height: 6),
          if (!history.isLoaded)
            ModuleStateView(loading: history.loading, error: history.error)
          else if (records.isEmpty)
            const EmptyStateView(
              icon: Icons.eco,
              title: 'Nenhuma ação registrada ainda',
              message: 'Registre sua primeira ação para vê-la aqui.',
              padding: 8,
            )
          else
            for (var i = 0; i < records.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RecordTile(record: records[i]),
                ),
              ),
        ],
      ),
    );
  }
}
