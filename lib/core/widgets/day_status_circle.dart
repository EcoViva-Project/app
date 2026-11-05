import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Círculo de status de um dia/etapa.
///
/// Padrão único usado no Início e em Desafios:
/// - concluído: fundo verde com check branco;
/// - hoje: fundo claro com borda verde e ponto central;
/// - pendente: fundo neutro com cadeado.
class DayStatusCircle extends StatelessWidget {
  const DayStatusCircle({
    super.key,
    required this.label,
    required this.done,
    this.isToday = false,
    this.points,
    this.size = 32,
    this.labelFontSize,
  });

  final String label;
  final bool done;
  final bool isToday;
  final String? points;
  final double size;
  final double? labelFontSize;

  @override
  Widget build(BuildContext context) {
    final highlighted = done || isToday;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reserva sempre o espaço dos pontos para manter todos os
        // círculos alinhados na mesma linha, mesmo os que têm cadeado.
        Visibility(
          visible: points != null,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text(
            points ?? '',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandDarkAccent,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                done
                    ? AppColors.brandPrimary
                    : isToday
                    ? AppColors.brandSecondaryContainer
                    : AppColors.brandBackground,
            border:
                done
                    ? null
                    : isToday
                    ? Border.all(color: AppColors.brandPrimary, width: 2)
                    : Border.all(color: AppColors.brandBorder),
          ),
          child:
              done
                  ? Icon(Icons.check, color: Colors.white, size: size * 0.5)
                  : isToday
                  ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  : Icon(
                    Icons.lock,
                    color: AppColors.brandTextSecondary,
                    size: size * 0.5,
                  ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color:
                highlighted
                    ? AppColors.brandTextPrimary
                    : AppColors.brandTextSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
  }
}
