import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/day_status_circle.dart';

class DesafiosPage extends StatefulWidget {
  const DesafiosPage({super.key});

  @override
  State<DesafiosPage> createState() => _DesafiosPageState();
}

class _DesafiosPageState extends State<DesafiosPage> {
  final ChallengeService _service = ChallengeService.instance;

  @override
  void initState() {
    super.initState();
    _service.load().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final ongoing = _service.ongoing;
        final available = _service.available;
        return _buildPage(context, ongoing, available);
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    List<Challenge> ongoing,
    List<Challenge> available,
  ) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.emoji_events,
        title: 'Desafios',
        profileInitials: 'C',
        onProfilePressed: () {
          context.go('/perfil');
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSecondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.spa,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Jornada Consciente',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.brandDarkAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Conquistas',
                          child: GestureDetector(
                            onTap: () => context.push('/conquistas'),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandSurface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.brandBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.military_tech,
                                    size: 16,
                                    color: AppColors.brandTertiaryAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Conquistas',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.brandTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTertiaryAccent
                                          .withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${AchievementService.instance.unlocked.length}',
                                        style: AppTextStyles.labelSm.copyWith(
                                          color: AppColors.brandDarkAccent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Desafios Sustentáveis',
                      style: AppTextStyles.headlineLg.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pequenas metas coletivas e individuais para transformar hábitos no dia a dia com leveza e propósito.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EM ANDAMENTO (${ongoing.length})',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ritmo da Semana',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (ongoing.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Nenhum desafio em andamento. Escolha um desafio disponível para começar.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                )
              else
                for (int i = 0; i < ongoing.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildOngoingChallengeCard(
                      context,
                      title: ongoing[i].title,
                      description: ongoing[i].description,
                      category:
                          ongoing[i].isWeekly
                              ? 'Desafio semanal'
                              : 'Desafio coletivo',
                      subcategory: ongoing[i].category,
                      points: '+${ongoing[i].pointsReward} pts',
                      daysCompleted: ongoing[i].completedSteps,
                      totalDays: ongoing[i].targetSteps,
                      progressPercent: (ongoing[i].progress * 100).round(),
                    ),
                  ),
                  if (i < ongoing.length - 1) const SizedBox(height: 12),
                ],
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'DISPONÍVEIS PARA PARTICIPAR',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (int i = 0; i < available.length; i++) ...[
                      _buildAvailableChallengeCard(
                        context,
                        challengeId: available[i].id,
                        title: available[i].title,
                        description: available[i].description,
                        category: available[i].category,
                        points: '+${available[i].pointsReward} pts',
                        duration: '${available[i].daysLeft} dias',
                        participants:
                            '${available[i].participants} participantes',
                      ),
                      if (i < available.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: AppColors.brandPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cada gesto gera impacto real',
                              style: AppTextStyles.labelLg.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Suas metas ativas já pouparam o equivalente a 14kg de CO₂ nesta semana junto aos vizinhos.',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.brandTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingChallengeCard(
    BuildContext context, {
    required String title,
    required String description,
    required String category,
    required String subcategory,
    required String points,
    required int daysCompleted,
    required int totalDays,
    required int progressPercent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandSecondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              category,
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.brandDarkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.recycling,
                                size: 12,
                                color: AppColors.brandTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                subcategory,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: AppTextStyles.headlineSm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiaryAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        color: AppColors.brandDarkAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        points,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandDarkAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  color: AppColors.brandPrimary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$daysCompleted de $totalDays dias concluídos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$progressPercent%',
                  style: AppTextStyles.labelSm.copyWith(
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
                value: progressPercent / 100,
                minHeight: 8,
                backgroundColor: AppColors.brandSecondaryContainer,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.brandPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(totalDays, (index) {
                final isCompleted = index < daysCompleted;
                final isToday =
                    index == daysCompleted && daysCompleted < totalDays;
                final dayLabels = ['Seg', 'Ter', 'Qua', 'Hoje', 'Sex'];
                return Expanded(
                  child: DayStatusCircle(
                    label: index < dayLabels.length ? dayLabels[index] : '',
                    done: isCompleted,
                    isToday: isToday,
                    labelFontSize: 10,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  context.push(
                    '/registro-acao',
                    extra: {
                      'title': title,
                      'description': description,
                      'categoryLabel': category,
                      'icon': Icons.recycling,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Registrar Ação de Hoje',
                      style: AppTextStyles.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableChallengeCard(
    BuildContext context, {
    required int challengeId,
    required String title,
    required String description,
    required String category,
    required String points,
    required String duration,
    required String participants,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSecondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandDarkAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiaryAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        color: AppColors.brandDarkAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        points,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandDarkAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.brandTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.brandTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              participants,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/detalhes-desafio',
                      extra: {
                        'id': challengeId,
                        'title': title,
                        'description': description,
                        'category': category,
                        'points': points,
                        'duration': duration,
                        'participants': participants,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Participar',
                        style: AppTextStyles.labelMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
