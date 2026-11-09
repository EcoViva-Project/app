import 'package:flutter/material.dart';

import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Por que uma recompensa não pode ser resgatada agora.
enum RedeemBlock { soldOut, limitReached, balanceUnknown, missingPoints }

/// Devolve o impedimento do resgate, ou `null` quando ele está liberado.
///
/// [balance] é `null` enquanto o saldo ainda não foi carregado.
RedeemBlock? redeemBlockFor(Reward reward, int? balance) {
  if (!reward.available) return RedeemBlock.soldOut;
  if (reward.limitReached) return RedeemBlock.limitReached;
  if (balance == null) return RedeemBlock.balanceUnknown;
  if (balance < reward.pointsCost) return RedeemBlock.missingPoints;
  return null;
}

/// "1.600 pts".
String pointsLabel(int points) =>
    '${UserProgressService.formatNumber(points)} pts';

/// Aparência de cada situação de cupom: texto, ícone e cor.
extension CouponStatusVisual on CouponStatus {
  String get pluralLabel {
    switch (this) {
      case CouponStatus.active:
        return 'Disponíveis';
      case CouponStatus.used:
        return 'Usados';
      case CouponStatus.expired:
        return 'Vencidos';
    }
  }

  IconData get icon {
    switch (this) {
      case CouponStatus.active:
        return Icons.confirmation_number_outlined;
      case CouponStatus.used:
        return Icons.task_alt;
      case CouponStatus.expired:
        return Icons.event_busy_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CouponStatus.active:
        return AppColors.brandDarkAccent;
      case CouponStatus.used:
        return AppColors.brandTextSecondary;
      case CouponStatus.expired:
        return AppColors.onErrorContainer;
    }
  }
}

/// Selo pequeno com ícone e texto (situação, valor, destaque).
class RewardPill extends StatelessWidget {
  const RewardPill({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.brandSecondaryContainer,
    this.foreground = AppColors.brandDarkAccent,
  });

  /// Recompensa sem estoque.
  const RewardPill.soldOut({super.key})
    : label = 'Esgotado',
      icon = Icons.remove_shopping_cart_outlined,
      background = AppColors.errorContainer,
      foreground = AppColors.onErrorContainer;

  /// A pessoa já resgatou o máximo permitido no período.
  const RewardPill.limitReached({super.key})
    : label = 'Limite atingido',
      icon = Icons.block,
      background = AppColors.surfaceContainerHigh,
      foreground = AppColors.brandTextPrimary;

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMd.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quadro com o ícone da recompensa ou do cupom.
class RewardIconBox extends StatelessWidget {
  const RewardIconBox({super.key, required this.icon, this.size = 46});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.brandDarkAccent, size: size * 0.5),
    );
  }
}

/// Linha de informação: ícone à esquerda, texto e detalhe opcional.
class RewardInfoRow extends StatelessWidget {
  const RewardInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
  });

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: AppColors.brandDarkAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
              if (detail != null && detail!.isNotEmpty)
                Text(
                  detail!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cartão branco padrão da tela (raio 16 e borda da marca).
class RewardPanel extends StatelessWidget {
  const RewardPanel({
    super.key,
    required this.child,
    this.color = AppColors.brandSurface,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: child,
    );
  }
}
