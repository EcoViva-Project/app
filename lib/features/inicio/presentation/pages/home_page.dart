import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/day_status_circle.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = AuthService.instance;
    final firstName = auth.userName.split(' ').first;
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.eco,
        title: 'Início',
        profileInitials: auth.userInitials,
        onProfilePressed: () {
          context.go('/perfil');
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandSecondaryContainer.withOpacity(
                          0.7,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Comunidade ${auth.neighborhood}',
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
                    const SizedBox(height: 8),
                    Text(
                      'Olá, $firstName 🌿',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cada pequeno hábito transforma o nosso bairro. Que tal registrar sua pegada positiva hoje?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: UserProgressService.instance,
                builder: (context, _) {
                  final progress = UserProgressService.instance;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'IMPACTO ACUMULADO',
                                        style: AppTextStyles.labelSm.copyWith(
                                          color: AppColors.brandTextSecondary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              progress.formattedPoints,
                                              style: AppTextStyles
                                                  .displayLgMobile
                                                  .copyWith(
                                                    color:
                                                        AppColors.brandPrimary,
                                                  ),
                                            ),
                                            const SizedBox(width: 6),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                'pts',
                                                style: AppTextStyles.labelLg
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .brandTextSecondary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTertiaryAccent
                                          .withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.eco,
                                          color: AppColors.brandDarkAccent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            progress.level,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.labelSm
                                                .copyWith(
                                                  color:
                                                      AppColors.brandDarkAccent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Meta de hábitos do mês',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.brandTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress.monthlyGoalProgress,
                                minHeight: 10,
                                backgroundColor:
                                    AppColors.brandSecondaryContainer,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.brandPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${(progress.monthlyGoalProgress * 100).round()}% concluída',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors
                                                    .brandSecondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.grass,
                                            color: AppColors.brandDarkAccent,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Ações no mês',
                                                style: AppTextStyles.labelSm
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .brandTextSecondary,
                                                    ),
                                              ),
                                              Text(
                                                '${progress.monthlyActions} concluídas',
                                                style: AppTextStyles.labelMd
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .brandTextPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors
                                                    .brandSecondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.water_drop_outlined,
                                            color: AppColors.brandDarkAccent,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Água poupada',
                                                style: AppTextStyles.labelSm
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .brandTextSecondary,
                                                    ),
                                              ),
                                              Text(
                                                '-${progress.litersSaved} Litros',
                                                style: AppTextStyles.labelMd
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .brandTextPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/acoes'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Registrar nova ação ecológica'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: AppColors.brandSecondaryContainer.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandSurface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.military_tech,
                                      color: AppColors.tertiary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Desafio Coletivo da Semana',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.labelSm.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Restam 2 dias',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.brandTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Semana Sem Descarte Único',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Substitua copos descartáveis e sacolas plásticas por alternativas reutilizáveis durante 5 dias consecutivos.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.brandSurface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '3 de 5 dias concluídos',
                                      style: AppTextStyles.labelSm.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '+120 pts ao fim',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.brandDarkAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _dayCircle('Seg', true),
                                  const Spacer(),
                                  _dayCircle('Ter', true),
                                  const Spacer(),
                                  _dayCircle('Qua', true),
                                  const Spacer(),
                                  _dayCircle('Hoje', false, isToday: true),
                                  const Spacer(),
                                  _dayCircle('Sex', false),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 24,
                              child: Stack(
                                children: [
                                  const CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        AppColors.brandSecondaryContainer,
                                    child: Text(
                                      'MG',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          AppColors.brandTertiaryAccent,
                                      child: Text(
                                        'LF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 24,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          AppColors.brandSecondaryContainer,
                                      child: Text(
                                        '+42',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandDarkAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'vizinhos participando',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandTextSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  () => context.push('/detalhes-desafio'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Detalhes',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.brandPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.brandPrimary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explorar por categoria',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Atitudes que fazem a diferença',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/acoes'),
                      child: Text(
                        'Ver todas',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _categoryCard(Icons.water_drop_outlined, 'Água'),
                    _categoryCard(Icons.lightbulb_outline, 'Energia'),
                    _categoryCard(Icons.recycling_outlined, 'Reciclagem'),
                    _categoryCard(Icons.compost, 'Alimentos'),
                    _categoryCard(Icons.directions_bike_outlined, 'Mobilidade'),
                    _categoryCard(Icons.forest_outlined, 'Natureza'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua semana sustentável',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '4 dias ativos de cuidado coletivo',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: AppColors.brandDarkAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '4 dias seguidos',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandDarkAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _weekDay('Seg', '+45', true)),
                        Expanded(child: _weekDay('Ter', '+30', true)),
                        Expanded(child: _weekDay('Qua', '+60', true)),
                        Expanded(
                          child: _weekDay('Hoje', '+30', true, isToday: true),
                        ),
                        Expanded(child: _weekDay('Sex', null, false)),
                        Expanded(child: _weekDay('Sáb', null, false)),
                        Expanded(child: _weekDay('Dom', null, false)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _activityItem(
                      Icons.directions_walk,
                      'Deslocamento a pé até o mercado',
                      'Hoje, 08:30',
                      'Mobilidade',
                      '+30 pts',
                    ),
                    const SizedBox(height: 10),
                    _activityItem(
                      Icons.compost,
                      'Compostagem de resíduos orgânicos',
                      'Ontem',
                      'Alimentação',
                      '+50 pts',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandTertiaryAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.tertiary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dica ecológica de hoje',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.brandDarkAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aproveite a água do enxágue de vegetais para regar suas plantas medicinais ou flores na janela.',
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

  Widget _dayCircle(String label, bool done, {bool isToday = false}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.brandPrimary : AppColors.brandBackground,
            border:
                isToday
                    ? Border.all(color: AppColors.brandPrimary, width: 2)
                    : null,
          ),
          child:
              done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Center(
                    child: Text(
                      label == 'Hoje' ? '4' : (label == 'Sex' ? '5' : label),
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color:
                done || isToday
                    ? AppColors.brandTextPrimary
                    : AppColors.brandTextSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _categoryCard(IconData icon, String label) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.labelSm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekDay(
    String label,
    String? points,
    bool done, {
    bool isToday = false,
  }) {
    return DayStatusCircle(
      label: label,
      points: points,
      done: done,
      isToday: isToday,
    );
  }

  Widget _activityItem(
    IconData icon,
    String title,
    String time,
    String tag,
    String points,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandDarkAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              points,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
