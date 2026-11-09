import 'package:flutter/material.dart';

import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'reward_ui.dart';

/// Abre os detalhes de uma recompensa.
///
/// Devolve `true` quando a pessoa confirmou que quer resgatar; quem chamou
/// faz o resgate.
Future<bool?> showRewardDetailsSheet(BuildContext context, Reward reward) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.brandBackground,
    builder: (_) => RewardDetailsSheet(reward: reward),
  );
}

/// Folha com tudo sobre a recompensa e o botão de resgate.
class RewardDetailsSheet extends StatefulWidget {
  const RewardDetailsSheet({super.key, required this.reward});

  final Reward reward;

  @override
  State<RewardDetailsSheet> createState() => _RewardDetailsSheetState();
}

class _RewardDetailsSheetState extends State<RewardDetailsSheet> {
  final RewardService _service = RewardService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  late final Listenable _changes = Listenable.merge([_service, _progress]);

  bool _confirming = false;

  /// Versão mais recente da recompensa (estoque e limite mudam com o uso).
  Reward get _reward => _service.rewards.firstWhere(
    (item) => item.id == widget.reward.id,
    orElse: () => widget.reward,
  );

  Future<void> _confirm(Reward reward, int balance) async {
    if (_confirming) return;
    _confirming = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              scrollable: true,
              title: const Text('Confirmar resgate'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resgatar "${reward.title}" por '
                    '${UserProgressService.formatNumber(reward.pointsCost)} '
                    'pontos?',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seu saldo fica em '
                    '${pointsLabel(balance - reward.pointsCost)}. '
                    '${reward.validityLabel}.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Resgatar'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      if (confirmed == true) Navigator.of(context).pop(true);
    } finally {
      _confirming = false;
    }
  }

  /// Texto que explica por que o botão está desligado.
  String? _blockReason(Reward reward, RedeemBlock? block, int? balance) {
    switch (block) {
      case RedeemBlock.soldOut:
        return 'Esgotado: não há mais cupons desta recompensa.';
      case RedeemBlock.limitReached:
        final limit = reward.limitLabel;
        return limit == null
            ? 'Você atingiu o limite de resgates desta recompensa.'
            : 'Você atingiu o limite de resgates: $limit.';
      case RedeemBlock.balanceUnknown:
        return 'Não foi possível conferir seu saldo. Feche e atualize a tela.';
      case RedeemBlock.missingPoints:
        return 'Faltam ${pointsLabel(reward.pointsCost - balance!)} '
            'para este resgate.';
      case null:
        return _service.busy ? 'Aguarde: há um resgate em andamento.' : null;
    }
  }

  String _redeemedByMeLabel(int count) {
    if (count <= 0) return 'Você ainda não resgatou neste período.';
    if (count == 1) return 'Você já resgatou 1 vez neste período.';
    return 'Você já resgatou $count vezes neste período.';
  }

  String _stockLabel(Reward reward) {
    if (!reward.available) return 'Esgotado';
    return reward.stock == 1
        ? '1 cupom em estoque'
        : '${UserProgressService.formatNumber(reward.stock)} cupons em estoque';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _changes,
      builder: (context, _) {
        final reward = _reward;
        final balance = _progress.isLoaded ? _progress.points : null;
        final block = redeemBlockFor(reward, balance);
        final canRedeem = block == null && balance != null && !_service.busy;
        final reason = _blockReason(reward, block, balance);
        final limitLabel = reward.limitLabel;
        final address = reward.partnerAddress?.trim() ?? '';
        final partnerDescription = reward.partnerDescription?.trim() ?? '';
        final terms = reward.terms?.trim() ?? '';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RewardIconBox(icon: reward.icon, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.title,
                                style: AppTextStyles.headlineSm.copyWith(
                                  color: AppColors.brandTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reward.categoryLabel,
                                style: AppTextStyles.labelMd.copyWith(
                                  color: AppColors.brandTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (reward.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        reward.description,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    RewardPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RewardInfoRow(
                            icon: Icons.storefront_outlined,
                            text: reward.partnerName,
                            detail: partnerDescription,
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            RewardInfoRow(
                              icon: Icons.place_outlined,
                              text: address,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    RewardPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reward.hasValue) ...[
                            RewardInfoRow(
                              icon: Icons.sell_outlined,
                              text: reward.valueLabel,
                            ),
                            const SizedBox(height: 10),
                          ],
                          RewardInfoRow(
                            icon: Icons.toll_outlined,
                            text: 'Custa ${pointsLabel(reward.pointsCost)}',
                            detail:
                                balance == null
                                    ? null
                                    : 'Seu saldo: ${pointsLabel(balance)}',
                          ),
                          const SizedBox(height: 10),
                          RewardInfoRow(
                            icon: Icons.event_available_outlined,
                            text: reward.validityLabel,
                          ),
                          if (limitLabel != null) ...[
                            const SizedBox(height: 10),
                            RewardInfoRow(
                              icon: Icons.repeat,
                              text: limitLabel,
                              detail: _redeemedByMeLabel(reward.redeemedByMe),
                            ),
                          ],
                          const SizedBox(height: 10),
                          RewardInfoRow(
                            icon: Icons.inventory_2_outlined,
                            text: _stockLabel(reward),
                          ),
                        ],
                      ),
                    ),
                    if (terms.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      RewardPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regras',
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.brandTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              terms,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.brandTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.brandBorder),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed:
                        canRedeem ? () => _confirm(reward, balance) : null,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: Text(
                      'Resgatar por ${pointsLabel(reward.pointsCost)}',
                    ),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
