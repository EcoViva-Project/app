import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';

/// Vitrine de recompensas criadas pelas empresas parceiras.
///
/// A pessoa troca os pontos acumulados por produtos, serviços, descontos e
/// itens de jogos. O resgate é registrado no backend e gera um código único.
class RecompensasPage extends StatefulWidget {
  const RecompensasPage({super.key});

  @override
  State<RecompensasPage> createState() => _RecompensasPageState();
}

class _RecompensasPageState extends State<RecompensasPage> {
  final RewardService _service = RewardService.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service.load().catchError((_) {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.redeem,
        title: 'Recompensas',
        profileInitials: auth.userInitials,
        onProfilePressed: () => context.go('/perfil'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_service, UserProgressService.instance]),
        builder: (context, _) {
          final progress = UserProgressService.instance;
          final rewards = _service.rewards;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _balanceCard(progress),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: _service.setSearch,
                      decoration: InputDecoration(
                        hintText: 'Buscar recompensa ou parceiro',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            _service.search.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchController.clear();
                                    _service.setSearch('');
                                  },
                                ),
                        filled: true,
                        fillColor: AppColors.brandSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.brandBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.brandBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: RewardCategoryFilter.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = RewardCategoryFilter.values[index];
                        final selected = _service.category == filter;
                        return ChoiceChip(
                          label: Text(filter.label),
                          selected: selected,
                          onSelected: (_) => _service.setCategory(filter),
                          selectedColor: AppColors.brandSecondaryContainer,
                          backgroundColor: AppColors.brandSurface,
                          side: BorderSide(
                            color:
                                selected
                                    ? AppColors.brandPrimary
                                    : AppColors.brandBorder,
                          ),
                          labelStyle: AppTextStyles.labelMd.copyWith(
                            color:
                                selected
                                    ? AppColors.brandDarkAccent
                                    : AppColors.brandTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recompensas dos parceiros',
                                style: AppTextStyles.headlineSm.copyWith(
                                  color: AppColors.brandTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${rewards.length} disponíveis para resgate',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<RewardSort>(
                          tooltip: 'Ordenar recompensas',
                          initialValue: _service.sort,
                          onSelected: _service.setSort,
                          itemBuilder:
                              (context) =>
                                  RewardSort.values
                                      .map(
                                        (sort) => PopupMenuItem<RewardSort>(
                                          value: sort,
                                          child: Text(sort.label),
                                        ),
                                      )
                                      .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.swap_vert,
                                  size: 18,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _service.sort.label,
                                  style: AppTextStyles.labelMd.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_service.busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  if (rewards.isEmpty)
                    _emptyState()
                  else
                    ...rewards.map(
                      (reward) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _rewardCard(reward, progress),
                      ),
                    ),
                  if (_service.redemptions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                      child: Text(
                        'Meus resgates',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ..._service.redemptions.map(
                      (item) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _redemptionCard(item),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _balanceCard(UserProgressService progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDarkAccent, AppColors.brandPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEUS PONTOS DISPONÍVEIS',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandSurface.withOpacity(0.85),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  progress.formattedPoints,
                  style: AppTextStyles.displayLgMobile.copyWith(
                    color: AppColors.brandSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'pts',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandSurface.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Troque por produtos, serviços, descontos e itens de jogos '
            'oferecidos pelas empresas parceiras.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _balancePill(
                icon: Icons.trending_up,
                label:
                    'Ganhos: ${UserProgressService.formatNumber(progress.pointsEarned)}',
              ),
              _balancePill(
                icon: Icons.redeem,
                label:
                    'Resgatados: ${UserProgressService.formatNumber(progress.pointsSpent)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balancePill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSurface.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.brandSurface, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard(Reward reward, UserProgressService progress) {
    final canAfford = progress.points >= reward.pointsCost;
    final enabled = reward.available && canAfford && !_service.busy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(reward.icon, color: AppColors.brandDarkAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            reward.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (reward.isFeatured)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandTertiaryAccent.withOpacity(
                                0.45,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Destaque',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.tertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reward.partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _categoryPill(reward.categoryLabel),
              Text(
                reward.available ? '${reward.stock} disponíveis' : 'Esgotado',
                style: AppTextStyles.labelSm.copyWith(
                  color:
                      reward.available
                          ? AppColors.brandTextSecondary
                          : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${UserProgressService.formatNumber(reward.pointsCost)} pts',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  reward.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: enabled ? () => _openReward(reward) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(
                  !reward.available
                      ? 'Esgotado'
                      : canAfford
                      ? 'Resgatar'
                      : 'Faltam pts',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.brandDarkAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _redemptionCard(RewardRedemption item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: AppColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.rewardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.partnerName} • ${item.dateLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  item.code,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-${UserProgressService.formatNumber(item.pointsSpent)} pts',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off,
              size: 40,
              color: AppColors.brandTextSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhuma recompensa encontrada',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReward(Reward reward) async {
    final progress = UserProgressService.instance;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.brandBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.brandBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brandSecondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        reward.icon,
                        color: AppColors.brandDarkAccent,
                        size: 26,
                      ),
                    ),
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
                          Text(
                            reward.partnerName,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  reward.description,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _categoryPill(reward.categoryLabel),
                    Text(
                      reward.available
                          ? '${reward.stock} disponíveis'
                          : 'Esgotado',
                      style: AppTextStyles.labelSm.copyWith(
                        color:
                            reward.available
                                ? AppColors.brandTextSecondary
                                : AppColors.error,
                      ),
                    ),
                    Text(
                      '${UserProgressService.formatNumber(reward.pointsCost)} pts',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (reward.terms != null && reward.terms!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brandSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Text(
                      reward.terms!,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed:
                        reward.available
                            ? () {
                              Navigator.of(sheetContext).pop();
                              _redeem(reward);
                            }
                            : null,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: Text(
                      'Resgatar por '
                      '${UserProgressService.formatNumber(reward.pointsCost)} pts',
                    ),
                  ),
                ),
                if (progress.points < reward.pointsCost)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Você ainda precisa de '
                      '${UserProgressService.formatNumber(reward.pointsCost - progress.points)} '
                      'pts para este resgate.',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _redeem(Reward reward) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final redemption = await _service.redeem(reward);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Resgate confirmado!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você resgatou "${redemption.rewardTitle}" com '
                    '${redemption.partnerName}.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEU CÓDIGO',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandDarkAccent,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          redemption.code,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.brandDarkAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apresente o código ao parceiro para usar a recompensa.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível concluir o resgate. Tente novamente.',
          ),
        ),
      );
    }
  }
}
