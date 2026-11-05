import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProgressoPage extends StatelessWidget {
  const ProgressoPage({super.key});

  static const List<int> _weeklyActions = [2, 4, 3, 5, 3, 1, 0];
  static const List<String> _weekDays = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  String _monthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }

  IconData _iconFromRecord(ActionRecord r) {
    switch (r.categoryLabel) {
      case 'Água':
        return Icons.water_drop;
      case 'Reciclagem':
        return Icons.recycling;
      case 'Transporte':
        return Icons.directions_bike;
      case 'Alimentação':
        return Icons.compost;
      case 'Energia':
        return Icons.lightbulb_outline;
      case 'Espaços Públicos':
        return Icons.park;
      default:
        return Icons.eco;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProgressService.instance,
      builder: (context, _) {
        final progress = UserProgressService.instance;
        final records = ActionHistoryService.instance.records;

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
              'Meu Progresso',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seu ritmo sustentável',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.brandTextPrimary,
                            fontWeight: FontWeight.w700,
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
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Text(
                          'Demonstração',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acompanhe seus hábitos e veja como pequenas atitudes diárias fazem a diferença no bairro.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: Icons.eco,
                          value: '${progress.actionsCount}',
                          label: 'Ações feitas',
                          iconBackground: AppColors.brandSecondaryContainer,
                          iconColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          icon: Icons.stars,
                          value: progress.formattedPoints,
                          label: 'Eco-pontos',
                          iconBackground: AppColors.brandTertiaryAccent
                              .withOpacity(0.35),
                          iconColor: AppColors.brandDarkAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          icon: Icons.calendar_today,
                          value: '${progress.activeDays}',
                          label: 'Dias ativos',
                          iconBackground: AppColors.brandSecondaryContainer,
                          iconColor: AppColors.brandDarkAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brandSurface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ritmo consciente',
                                style: AppTextStyles.labelLg.copyWith(
                                  color: AppColors.brandTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Você manteve seus hábitos por 4 dias seguidos nesta semana! Cada escolha consciente preserva os recursos do seu bairro.',
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
                  const SizedBox(height: 16),
                  _section(
                    title: 'Atividade na semana',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bar_chart,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '18 ações',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Ações nos últimos 7 dias',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _weeklyChart(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Ações por categoria',
                    trailing: Text(
                      'Por área de impacto',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    child: Column(
                      children: [
                        _categoryRow(
                          icon: Icons.water_drop,
                          label: 'Água',
                          detail: '14 ações (33%)',
                          progress: 0.33,
                          color: AppColors.brandPrimary,
                        ),
                        _categoryRow(
                          icon: Icons.recycling,
                          label: 'Reciclagem & Resíduos',
                          detail: '12 ações (29%)',
                          progress: 0.29,
                          color: AppColors.brandDarkAccent,
                        ),
                        _categoryRow(
                          icon: Icons.directions_walk,
                          label: 'Mobilidade Ativa',
                          detail: '8 ações (19%)',
                          progress: 0.19,
                          color: AppColors.secondary,
                        ),
                        _categoryRow(
                          icon: Icons.bolt,
                          label: 'Energia & Consumo',
                          detail: '5 ações (12%)',
                          progress: 0.12,
                          color: AppColors.tertiaryContainer,
                        ),
                        _categoryRow(
                          icon: Icons.restaurant,
                          label: 'Alimentação Consciente',
                          detail: '3 ações (7%)',
                          progress: 0.07,
                          color: AppColors.outlineVariant,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Desafios em andamento',
                    trailing: TextButton(
                      onPressed: () => context.go('/desafios'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver todos',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _challengeProgress(
                          icon: Icons.flag,
                          title: 'Semana Sem Descarte Único',
                          detail: '3 de 5 dias concluídos',
                          progress: 0.6,
                        ),
                        const SizedBox(height: 10),
                        _challengeProgress(
                          icon: Icons.restaurant,
                          title: 'Menos Desperdício na Cozinha',
                          detail: '2 de 3 ações registradas',
                          progress: 0.66,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Últimas ações registradas',
                    trailing: TextButton(
                      onPressed: () => context.go('/meu-historico'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver histórico',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        if (records.isEmpty) ...[
                          _demoAction(
                            icon: Icons.water_drop,
                            title: 'Fechar a torneira ao escovar',
                            category: 'Água',
                            when: 'Hoje, 08:30',
                            points: 15,
                          ),
                          const SizedBox(height: 8),
                          _demoAction(
                            icon: Icons.directions_walk,
                            title: 'Deslocamento a pé ao mercado',
                            category: 'Mobilidade',
                            when: 'Ontem',
                            points: 30,
                          ),
                          const SizedBox(height: 8),
                          _demoAction(
                            icon: Icons.compost,
                            title: 'Compostagem de resíduos',
                            category: 'Alimentação',
                            when: '22 de Outubro',
                            points: 35,
                          ),
                        ] else
                          for (int i = 0; i < records.length && i < 3; i++) ...[
                            _recordAction(records[i]),
                            if (i < records.length - 1 && i < 2)
                              const SizedBox(height: 8),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/acoes'),
                      icon: const Icon(Icons.add_circle, size: 20),
                      label: const Text('Registrar nova ação'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: AppTextStyles.labelLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconBackground,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _weeklyChart(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    const maxValue = 5;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return SizedBox(
      height: 128 + (textScale - 1) * 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_weekDays.length, (index) {
          final value = _weeklyActions[index];
          final isToday = index == todayIndex;
          final heightFactor = value == 0 ? 0.04 : value / maxValue;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$value',
                    style: AppTextStyles.labelSm.copyWith(
                      color:
                          isToday
                              ? AppColors.brandDarkAccent
                              : AppColors.brandTextSecondary,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
                    ),
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
                      heightFactor: heightFactor,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              isToday
                                  ? AppColors.brandPrimary
                                  : AppColors.brandPrimary.withOpacity(0.55),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isToday ? 'Hoje' : _weekDays[index],
                    style: AppTextStyles.labelSm.copyWith(
                      color:
                          isToday
                              ? AppColors.brandDarkAccent
                              : AppColors.brandTextSecondary,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _categoryRow({
    required IconData icon,
    required String label,
    required String detail,
    required double progress,
    required Color color,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                detail,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.brandTextSecondary,
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
              backgroundColor: AppColors.brandBackground,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeProgress({
    required IconData icon,
    required String title,
    required String detail,
    required double progress,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.brandPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _demoAction({
    required IconData icon,
    required String title,
    required String category,
    required String when,
    required int points,
  }) {
    return _actionRow(
      icon: icon,
      title: title,
      subtitle: '$category • $when',
      points: points,
    );
  }

  Widget _recordAction(ActionRecord record) {
    return _actionRow(
      icon: _iconFromRecord(record),
      title: record.title,
      subtitle:
          '${record.categoryLabel} • ${record.dateTime.day} de ${_monthName(record.dateTime.month)}',
      points: record.points,
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required int points,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$points',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
