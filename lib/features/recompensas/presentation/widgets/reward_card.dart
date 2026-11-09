import 'package:flutter/material.dart';

import '../../../../core/services/reward_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'reward_ui.dart';

/// Cartão de uma recompensa na vitrine. O cartão inteiro abre os detalhes.
class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.reward,
    required this.balance,
    required this.onTap,
  });

  final Reward reward;

  /// Saldo atual em pontos; `null` enquanto não foi carregado.
  final int? balance;
  final VoidCallback onTap;

  /// Selo de situação, ou `null` quando o resgate está liberado.
  Widget? _statusPill() {
    switch (redeemBlockFor(reward, balance)) {
      case RedeemBlock.soldOut:
        return const RewardPill.soldOut();
      case RedeemBlock.limitReached:
        return const RewardPill.limitReached();
      case RedeemBlock.missingPoints:
        return RewardPill(
          label: 'Faltam ${pointsLabel(reward.pointsCost - balance!)}',
          icon: Icons.lock_outline,
          background: AppColors.surfaceContainer,
          foreground: AppColors.brandTextPrimary,
        );
      case RedeemBlock.balanceUnknown:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusPill();
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.brandSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.brandBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RewardIconBox(icon: reward.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reward.partnerName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reward.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.brandTextSecondary,
                    ),
                  ],
                ),
                if (reward.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reward.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      pointsLabel(reward.pointsCost),
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.brandDarkAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reward.hasValue)
                      RewardPill(
                        label: reward.valueLabel,
                        icon: Icons.sell_outlined,
                      ),
                    if (reward.isFeatured)
                      RewardPill(
                        label: 'Destaque',
                        icon: Icons.star_outline,
                        background: AppColors.brandTertiaryAccent.withValues(
                          alpha: 0.45,
                        ),
                        foreground: AppColors.onTertiaryContainer,
                      ),
                    if (status != null) status,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
