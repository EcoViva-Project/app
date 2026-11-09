import 'package:flutter/material.dart';

import '../services/user_progress_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Mostra quanto do teto semanal de pontos já foi usado.
///
/// Escuta o [UserProgressService] e se atualiza sozinho. Não aparece enquanto
/// o resumo não foi carregado ou se a API não informar teto.
class WeeklyCapCard extends StatelessWidget {
  const WeeklyCapCard({super.key, this.compact = false, this.onTap});

  /// Versão de uma linha, para usar dentro de outros cartões.
  final bool compact;
  final VoidCallback? onTap;

  static const List<String> _weekdays = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  /// "Zera na segunda-feira" ou "Zera amanhã".
  static String resetLabel(DateTime? resetsAt, {DateTime? now}) {
    if (resetsAt == null) return 'Zera na segunda-feira';
    final today = now ?? DateTime.now();
    final days =
        DateTime(resetsAt.year, resetsAt.month, resetsAt.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
    if (days <= 0) return 'Zera hoje à meia-noite';
    if (days == 1) return 'Zera amanhã';
    final weekday = _weekdays[resetsAt.weekday - 1];
    return 'Zera na $weekday${resetsAt.weekday <= 5 ? '-feira' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProgressService.instance,
      builder: (context, _) {
        final progress = UserProgressService.instance;
        if (!progress.isLoaded || !progress.hasWeeklyCap) {
          return const SizedBox.shrink();
        }
        final reached = progress.capReached;
        final title =
            reached
                ? 'Teto da semana atingido'
                : 'Pontos de ações nesta semana';
        final detail =
            reached
                ? 'Suas ações continuam valendo para desafios e conquistas. ${resetLabel(progress.weekResetsAt)}.'
                : 'Faltam ${progress.weeklyRemaining} pts para o teto. ${resetLabel(progress.weekResetsAt)}.';
        final value = '${progress.weeklyPoints} de ${progress.weeklyCap} pts';
        final color =
            reached ? AppColors.tertiary : AppColors.brandDarkAccent;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  reached ? Icons.verified_outlined : Icons.speed_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: AppTextStyles.labelMd.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.weeklyProgress,
                minHeight: 8,
                backgroundColor: AppColors.brandSecondaryContainer,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
            ],
          ],
        );

        return Semantics(
          container: true,
          label: '$title: $value. $detail',
          excludeSemantics: true,
          child: Material(
            color: AppColors.brandSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.brandBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(14), child: content),
            ),
          ),
        );
      },
    );
  }
}
