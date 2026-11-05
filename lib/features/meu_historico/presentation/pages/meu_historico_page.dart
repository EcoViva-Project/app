import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/action_history_service.dart';

class MeuHistoricoPage extends StatelessWidget {
  const MeuHistoricoPage({super.key});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) {
      return 'Hoje, ${dt.day} de ${_monthName(dt.month)}';
    } else if (date == yesterday) {
      return 'Ontem, ${dt.day} de ${_monthName(dt.month)}';
    }
    return '${dt.day} de ${_monthName(dt.month)}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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

  IconData _iconFromRecord(ActionRecord r) => r.icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActionHistoryService.instance,
      builder: (context, _) {
        final records = ActionHistoryService.instance.records;
        final totalPoints = records.fold<int>(0, (sum, r) => sum + r.points);

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
              onPressed: () => context.go('/acoes'),
            ),
            title: Text(
              'Meu Histórico',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${records.length} ação${records.length == 1 ? '' : 'es'} registrada${records.length == 1 ? '' : 's'}',
                              style: AppTextStyles.headlineSm.copyWith(
                                color: AppColors.brandTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Desde suas primeiras ações',
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSecondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco,
                              color: AppColors.brandPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+$totalPoints pts',
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
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.brandSecondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.yard,
                              color: AppColors.brandPrimary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma ação registrada ainda',
                            style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Que tal começar com um pequeno gesto hoje?',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => context.go('/acoes'),
                              icon: const Icon(Icons.add_task, size: 18),
                              label: const Text('Registrar primeira ação'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: AppTextStyles.labelMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (int i = 0; i < records.length; i++) ...[
                          _buildHistoryItem(context, records[i]),
                          if (i < records.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandSecondaryContainer,
                          AppColors.brandBackground,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brandSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Você está fazendo a diferença!',
                                style: AppTextStyles.bodyMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandTextPrimary,
                                ),
                              ),
                              Text(
                                'Suas atitudes inspiram os vizinhos do seu bairro.',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, ActionRecord record) {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFromRecord(record),
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            record.categoryLabel,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandDarkAccent,
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
                          Text(
                            _formatDate(record.dateTime),
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
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
                          Text(
                            _formatTime(record.dateTime),
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
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
                    color: AppColors.brandSecondaryContainer,
                    borderRadius: BorderRadius.circular(8),
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
                        '+${record.points}',
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
            const SizedBox(height: 10),
            Row(
              children: [
                _infoChip(
                  Icons.water_drop_outlined,
                  '~${record.liters} L poupados',
                ),
                const SizedBox(width: 8),
                _infoChip(Icons.repeat, '${record.quantity}x'),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record.notes!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
