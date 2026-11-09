import 'package:flutter/material.dart';

import '../../../../core/services/reward_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'reward_ui.dart';

/// Linha de um cupom em "Meus cupons". O cartão inteiro abre o cupom.
class CouponTile extends StatelessWidget {
  const CouponTile({super.key, required this.coupon, required this.onTap});

  final RewardRedemption coupon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = coupon.status;
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RewardIconBox(icon: coupon.icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.rewardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coupon.partnerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        coupon.code,
                        style: AppTextStyles.labelLg.copyWith(
                          color:
                              coupon.isActive
                                  ? AppColors.brandDarkAccent
                                  : AppColors.brandTextSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(status.icon, size: 16, color: status.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              coupon.statusDetail,
                              style: AppTextStyles.labelMd.copyWith(
                                color: status.textColor,
                              ),
                            ),
                          ),
                        ],
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
          ),
        ),
      ),
    );
  }
}
