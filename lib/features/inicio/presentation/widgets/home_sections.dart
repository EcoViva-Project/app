import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/day_status_circle.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../progresso/presentation/widgets/shared_blocks.dart';

// Blocos da aba Início. Cada um recebe os dados (ou o serviço) pelo
// construtor, para ser reconstruído sempre que a tela reagir a um serviço.

/// Cartão principal: saldo disponível, nível e pontos ganhos no total.
class HomeBalanceCard extends StatelessWidget {
  const HomeBalanceCard({super.key, required this.progress});

  final UserProgressService progress;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label:
                'Saldo disponível: '
                '${countLabel(progress.points, 'ponto', 'pontos')}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo disponível',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        progress.formattedPoints,
                        style: AppTextStyles.displayLgMobile.copyWith(
                          color: AppColors.brandDarkAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'pts',
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LevelProgressBlock(progress: progress),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 12),
          LabelValueRow(
            label: 'Pontos ganhos no total',
            value:
                '${UserProgressService.formatNumber(progress.pointsEarned)} pts',
            labelStyle: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
            valueStyle: AppTextStyles.labelMd.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicadores: sequência de dias, água poupada e meta do mês.
class HomeIndicators extends StatelessWidget {
  const HomeIndicators({super.key, required this.progress});

  final UserProgressService progress;

  @override
  Widget build(BuildContext context) {
    final liters = UserProgressService.formatNumber(progress.litersSaved);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _IndicatorTile(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Sequência',
                  value: countLabel(
                    progress.streakDays,
                    'dia seguido',
                    'dias seguidos',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IndicatorTile(
                  icon: Icons.water_drop_outlined,
                  label: 'Água poupada',
                  value: '$liters L',
                  spokenValue: countLabel(
                    progress.litersSaved,
                    'litro',
                    'litros',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MonthlyGoalCard(
          actions: progress.monthlyActions,
          goal: progress.monthlyGoal,
          progress: progress.monthlyGoalProgress,
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({
    required this.icon,
    required this.label,
    required this.value,
    this.spokenValue,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Valor por extenso para leitores de tela (por exemplo "28 litros").
  final String? spokenValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${spokenValue ?? value}',
      excludeSemantics: true,
      child: EcoCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.brandDarkAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyGoalCard extends StatelessWidget {
  const _MonthlyGoalCard({
    required this.actions,
    required this.goal,
    required this.progress,
  });

  final int actions;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal > 0;
    final value =
        hasGoal
            ? '${UserProgressService.formatNumber(actions)} de '
                '${countLabel(goal, 'ação', 'ações')}'
            : countLabel(actions, 'ação neste mês', 'ações neste mês');
    return Semantics(
      label: 'Meta do mês: $value',
      excludeSemantics: true,
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabelValueRow(
              icon: Icons.flag_outlined,
              label: 'Meta do mês',
              value: value,
            ),
            if (hasGoal) ...[
              const SizedBox(height: 8),
              EcoProgressBar(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Sua semana": os sete dias da semana atual e a meta semanal.
class HomeWeekSection extends StatelessWidget {
  const HomeWeekSection({
    super.key,
    required this.history,
    required this.weeklyGoal,
  });

  final ActionHistoryService history;
  final int weeklyGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Sua semana'),
        const SizedBox(height: 8),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child:
              history.isLoaded
                  ? _WeekSummary(
                    days: history.currentWeek(),
                    weeklyGoal: weeklyGoal,
                  )
                  : ModuleStateView(
                    loading: history.loading,
                    error: history.error,
                  ),
        ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.days, required this.weeklyGoal});

  final List<DayActivity> days;
  final int weeklyGoal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final total = days.fold<int>(0, (sum, day) => sum + day.actions);
    final hasGoal = weeklyGoal > 0;
    final goalReached = hasGoal && total >= weeklyGoal;
    final String goalText;
    if (hasGoal && total > weeklyGoal) {
      goalText =
          'Meta da semana batida: ${countLabel(total, 'ação', 'ações')} '
          '(meta de ${UserProgressService.formatNumber(weeklyGoal)})';
    } else if (hasGoal) {
      goalText =
          '${UserProgressService.formatNumber(total)} de '
          '${countLabel(weeklyGoal, 'ação', 'ações')} nesta semana';
    } else {
      goalText = countLabel(total, 'ação nesta semana', 'ações nesta semana');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(child: _WeekDay(day: days[i], index: i, today: today)),
          ],
        ),
        const SizedBox(height: 12),
        if (hasGoal) ...[
          EcoProgressBar(
            value: total / weeklyGoal,
            semanticsLabel: 'Meta da semana',
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Icon(
              goalReached ? Icons.check_circle : Icons.flag_outlined,
              size: 18,
              color: AppColors.brandDarkAccent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                goalText,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({required this.day, required this.index, required this.today});

  final DayActivity day;

  /// Posição na semana: 0 = segunda, 6 = domingo.
  final int index;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(day.date, today);
    final String status;
    if (day.date.isAfter(today)) {
      status = 'ainda não chegou';
    } else if (!day.active) {
      status = 'nenhuma ação';
    } else {
      status =
          '${countLabel(day.actions, 'ação', 'ações')}, '
          '${countLabel(day.points, 'ponto', 'pontos')}';
    }

    return Semantics(
      label: '${weekdayFullNames[index]}${isToday ? ' (hoje)' : ''}: $status',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DayStatusCircle(
          label: ActionHistoryService.weekdayLabels[index],
          done: day.active,
          isToday: isToday,
          points: day.points > 0 ? '+${day.points}' : null,
          labelFontSize: 12,
        ),
      ),
    );
  }
}

/// "Sua comunidade": números do bairro calculados pela API sobre os
/// registros de todos. O cartão inteiro abre a aba Comunidade.
class HomeCommunitySection extends StatelessWidget {
  const HomeCommunitySection({super.key, required this.stats});

  final CommunityStats stats;

  @override
  Widget build(BuildContext context) {
    final goal = stats.goal;
    final position = stats.myPosition;
    final neighbors = countLabel(
      stats.activeNeighbors,
      'vizinho ativo',
      'vizinhos ativos',
    );
    final today = countLabel(stats.actionsToday, 'ação hoje', 'ações hoje');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Sua comunidade'),
        const SizedBox(height: 8),
        EcoCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          onTap: () => context.go('/comunidade'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _CommunityStat(
                          icon: Icons.groups_outlined,
                          text: neighbors,
                        ),
                        _CommunityStat(icon: Icons.eco_outlined, text: today),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ],
              ),
              if (goal != null) ...[
                const SizedBox(height: 14),
                Text(
                  goal.title,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      goal.countLabel,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      goal.reached ? 'Meta batida' : goal.deadlineLabel,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                EcoProgressBar(
                  value: goal.progress,
                  semanticsLabel: 'Meta coletiva: ${goal.percentLabel}',
                ),
              ],
              if (position != null) ...[
                const SizedBox(height: 12),
                _CommunityStat(
                  icon: Icons.emoji_events_outlined,
                  text: 'Você está em $positionº lugar no ranking da semana',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityStat extends StatelessWidget {
  const _CommunityStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 18, color: AppColors.brandDarkAccent),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.labelLg.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Desafio em destaque: o que está em andamento ou o primeiro disponível.
class HomeFeaturedChallenge extends StatelessWidget {
  const HomeFeaturedChallenge({super.key, required this.challenge});

  final Challenge challenge;

  void _open(BuildContext context) {
    context.push('/detalhes-desafio/${challenge.id}');
  }

  @override
  Widget build(BuildContext context) {
    final bonus = UserProgressService.formatNumber(challenge.pointsReward);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Desafio em destaque',
          actionLabel: 'Ver todos',
          onAction: () => context.go('/desafios'),
        ),
        const SizedBox(height: 8),
        EcoCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          onTap: () => _open(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      challenge.icon,
                      size: 22,
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.brandTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          challenge.deadlineLabel,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (challenge.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  challenge.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
              if (challenge.joined) ...[
                const SizedBox(height: 12),
                Text(
                  challenge.stepsLabel,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                EcoProgressBar(
                  value: challenge.progress,
                  semanticsLabel: 'Progresso do desafio',
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (challenge.pointsReward > 0)
                          Text(
                            '+$bonus pts de bônus',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.brandDarkAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (challenge.participants > 0)
                          Text(
                            countLabel(
                              challenge.participants,
                              'pessoa participando',
                              'pessoas participando',
                            ),
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () => _open(context),
                      child: const Text('Ver desafio'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Atalho para as recompensas: saldo e cupons que ainda podem ser usados.
class HomeRewardsShortcut extends StatelessWidget {
  const HomeRewardsShortcut({
    super.key,
    required this.formattedPoints,
    required this.activeCoupons,
  });

  final String formattedPoints;
  final int activeCoupons;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: () => context.push('/recompensas'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.redeem, color: AppColors.brandDarkAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Troque seus pontos por recompensas',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo: $formattedPoints pts',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                if (activeCoupons > 0)
                  Text(
                    countLabel(
                      activeCoupons,
                      'cupom disponível',
                      'cupons disponíveis',
                    ),
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.brandDarkAccent),
        ],
      ),
    );
  }
}

/// Categorias do catálogo. Cada uma abre a aba Ações já filtrada.
///
/// Cuida das próprias margens laterais para a lista rolar até a borda.
class HomeCategories extends StatelessWidget {
  const HomeCategories({super.key, required this.categories});

  final List<ActionCategory> categories;

  @override
  Widget build(BuildContext context) {
    // A largura acompanha o tamanho da fonte para caber a maior palavra
    // ("Alimentação") sem quebrar no meio.
    final cardWidth = 24 + MediaQuery.textScalerOf(context).scale(12) * 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: 'Explorar por categoria',
            actionLabel: 'Ver todas',
            onAction: () => context.go('/acoes'),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: SizedBox(
                      width: cardWidth,
                      child: _CategoryButton(category: categories[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.category});

  final ActionCategory category;

  @override
  Widget build(BuildContext context) {
    final query = Uri.encodeQueryComponent(category.label);
    return EcoCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.go('/acoes?categoria=$query'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: AppColors.brandDarkAccent),
          ),
          const SizedBox(height: 6),
          Text(
            category.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Atividades recentes: os três lançamentos mais novos do histórico.
class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({super.key, required this.history});

  final ActionHistoryService history;

  @override
  Widget build(BuildContext context) {
    final records = history.records.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Atividades recentes',
          actionLabel: 'Ver tudo',
          onAction: () => context.push('/meu-historico'),
        ),
        const SizedBox(height: 8),
        if (!history.isLoaded)
          EcoCard(
            child: ModuleStateView(
              loading: history.loading,
              error: history.error,
            ),
          )
        else if (records.isEmpty)
          EcoCard(
            child: EmptyStateView(
              icon: Icons.eco,
              title: 'Nenhuma ação registrada ainda',
              message: 'Registre sua primeira ação para começar a pontuar.',
              actionLabel: 'Registrar primeira ação',
              onAction: () => context.go('/acoes'),
              padding: 8,
            ),
          )
        else
          for (var i = 0; i < records.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: EcoCard(
                padding: const EdgeInsets.all(12),
                child: RecordTile(record: records[i]),
              ),
            ),
      ],
    );
  }
}

/// "Dica do dia": vem da API (`NeighborhoodService.tip`), com categoria e
/// ícone.
class HomeDailyTip extends StatelessWidget {
  const HomeDailyTip({super.key, required this.tip});

  final DailyTip tip;

  @override
  Widget build(BuildContext context) {
    final category = tip.categoryLabel.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTertiaryAccent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(tip.icon, color: AppColors.tertiary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.isEmpty ? 'Dica do dia' : 'Dica do dia · $category',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.text,
                  style: AppTextStyles.bodySm.copyWith(
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
