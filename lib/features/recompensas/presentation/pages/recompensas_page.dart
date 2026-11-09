import 'package:flutter/material.dart';

import '../../../../core/local/economy.dart';
import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/coupon_dialog.dart';
import '../widgets/coupon_tile.dart';
import '../widgets/reward_card.dart';
import '../widgets/reward_details_sheet.dart';
import '../widgets/reward_ui.dart';

/// Vitrine de recompensas das empresas parceiras e cupons da pessoa.
///
/// Os pontos são trocados por cupons. Cada cupom tem um código, uma validade
/// e é conferido no balcão com o código do parceiro.
class RecompensasPage extends StatefulWidget {
  const RecompensasPage({super.key});

  @override
  State<RecompensasPage> createState() => _RecompensasPageState();
}

class _RecompensasPageState extends State<RecompensasPage> {
  static const String _loadFallback =
      'Não foi possível carregar as recompensas.';

  final RewardService _service = RewardService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  late final Listenable _changes = Listenable.merge([_service, _progress]);
  late final TextEditingController _searchController = TextEditingController(
    text: _service.search,
  );
  final GlobalKey _couponsKey = GlobalKey();

  CouponStatus _couponTab = CouponStatus.active;
  bool _loadFailed = false;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_syncSearchField);
    // O serviço avisa quem escuta na mesma hora. Esperar o fim deste quadro
    // evita "setState durante o build" nas telas que continuam montadas por
    // baixo desta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _service.clearFilters();
      _reload();
    });
  }

  @override
  void dispose() {
    _service.removeListener(_syncSearchField);
    _searchController.dispose();
    super.dispose();
  }

  /// Mantém o campo de busca igual à busca guardada no serviço.
  void _syncSearchField() {
    final search = _service.search;
    if (_searchController.text.trim() == search) return;
    _searchController.value = TextEditingValue(
      text: search,
      selection: TextSelection.collapsed(offset: search.length),
    );
  }

  Future<void> _reload() async {
    try {
      await _service.load();
      if (mounted && _loadFailed) setState(() => _loadFailed = false);
    } catch (_) {
      // O serviço guarda a mensagem em `error`; `_loadFailed` cobre as
      // falhas que chegam sem mensagem.
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _openReward(Reward reward) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showRewardDetailsSheet(context, reward);
    if (!mounted || confirmed != true) return;
    await _redeem(reward);
  }

  /// Faz o resgate já confirmado na folha de detalhes e mostra o cupom.
  Future<void> _redeem(Reward reward) async {
    if (_redeeming) return;
    _redeeming = true;
    try {
      final coupon = await _service.redeem(reward);
      if (!mounted) return;
      setState(() => _couponTab = CouponStatus.active);
      await showCouponDialog(context, coupon, justRedeemed: true);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível concluir o resgate. Tente de novo.',
      );
    } finally {
      _redeeming = false;
    }
  }

  void _openCoupon(RewardRedemption coupon) {
    FocusManager.instance.primaryFocus?.unfocus();
    showCouponDialog(context, coupon);
  }

  void _scrollToCoupons() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _couponTab = CouponStatus.active);
    final target = _couponsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.redeem,
        title: 'Recompensas',
        showBack: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _changes,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    final failure =
        _service.loading
            ? null
            : _service.error ?? (_loadFailed ? _loadFallback : null);

    if (!_service.isLoaded) {
      if (failure != null) {
        return LoadErrorView(message: failure, onRetry: _reload);
      }
      return const LoadingView(message: 'Carregando recompensas…');
    }

    final balance = _progress.isLoaded ? _progress.points : null;
    final rewards = _service.rewards;
    final working = _service.loading || _service.busy;

    return Column(
      children: [
        SizedBox(
          height: 3,
          child:
              working
                  ? const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: AppColors.brandSecondaryContainer,
                    semanticsLabel: 'Atualizando recompensas',
                  )
                  : null,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brandDarkAccent,
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 9, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _refreshError(failure),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _balanceCard(),
                  ),
                  if (_service.activeCoupons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _couponsShortcut(_service.activeCoupons.length),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _searchField(),
                  ),
                  const SizedBox(height: 8),
                  _chipRow([
                    for (final filter in RewardCategoryFilter.values)
                      _choiceChip(
                        label: filter.label,
                        selected: _service.category == filter,
                        onSelected: () => _service.setCategory(filter),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _sectionTitle(
                      'Recompensas dos parceiros',
                      _availableLabel(_service.availableCount),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _chipRow([
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Ordenar por',
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ),
                    for (final sort in RewardSort.values)
                      _choiceChip(
                        label: sort.label,
                        selected: _service.sort == sort,
                        onSelected: () => _service.setSort(sort),
                      ),
                  ]),
                  if (rewards.isEmpty)
                    _rewardsEmpty()
                  else
                    for (final reward in rewards)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: RewardCard(
                          reward: reward,
                          balance: balance,
                          onTap: () => _openReward(reward),
                        ),
                      ),
                  _couponsSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _availableLabel(int count) =>
      count == 1 ? '1 disponível' : '$count disponíveis';

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _refreshError(String message) {
    return RewardPanel(
      color: AppColors.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar de novo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    final loaded = _progress.isLoaded;
    const onCard = AppColors.onPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Os dois verdes escuros da marca: o texto branco pequeno continua
        // legível em todo o cartão.
        gradient: const LinearGradient(
          colors: [AppColors.brandDarkAccent, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo disponível',
                  style: AppTextStyles.labelLg.copyWith(color: onCard),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        loaded ? _progress.formattedPoints : '—',
                        style: AppTextStyles.displayLgMobile.copyWith(
                          color: onCard,
                        ),
                      ),
                    ),
                    if (loaded) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'pts',
                          style: AppTextStyles.labelLg.copyWith(color: onCard),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loaded
                ? 'Ganhos: '
                    '${UserProgressService.formatNumber(_progress.pointsEarned)}'
                    ' • Usados em cupons: '
                    '${UserProgressService.formatNumber(_progress.pointsSpent)}'
                : 'Não foi possível carregar seu saldo. Puxe a tela para '
                    'baixo para atualizar.',
            style: AppTextStyles.labelMd.copyWith(color: onCard),
          ),
          const SizedBox(height: 10),
          Text(
            'Cada ${Economy.pointsPerReal} pontos valem cerca de R\$ 1 em '
            'benefícios.',
            style: AppTextStyles.bodySm.copyWith(color: onCard),
          ),
        ],
      ),
    );
  }

  /// Atalho para os cupons que ainda podem ser usados.
  Widget _couponsShortcut(int count) {
    return Material(
      color: AppColors.brandSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _scrollToCoupons,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.brandDarkAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? 'Você tem 1 cupom para usar'
                        : 'Você tem $count cupons para usar',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ver',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  color: AppColors.brandDarkAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) => _service.setSearch(value.trim()),
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
        border: border(AppColors.brandBorder),
        enabledBorder: border(AppColors.brandBorder),
        focusedBorder: border(AppColors.brandDarkAccent, 2),
      ),
    );
  }

  /// Linha de chips que rola para os lados quando não cabe na tela.
  Widget _chipRow(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        // Área de toque de 48 px também no navegador e no computador.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        selectedColor: AppColors.brandSecondaryContainer,
        backgroundColor: AppColors.brandSurface,
        checkmarkColor: AppColors.brandDarkAccent,
        side: BorderSide(
          color: selected ? AppColors.brandDarkAccent : AppColors.brandBorder,
        ),
        labelStyle: AppTextStyles.labelLg.copyWith(
          color:
              selected ? AppColors.brandDarkAccent : AppColors.brandTextPrimary,
        ),
      ),
    );
  }

  Widget _rewardsEmpty() {
    final filtered =
        _service.search.isNotEmpty ||
        _service.category != RewardCategoryFilter.todas;
    if (filtered) {
      return EmptyStateView(
        icon: Icons.search_off,
        title: 'Nenhuma recompensa encontrada',
        message: 'Tente outra busca ou outra categoria.',
        actionLabel: 'Limpar filtros',
        onAction: _service.clearFilters,
      );
    }
    return const EmptyStateView(
      icon: Icons.redeem,
      title: 'Nenhuma recompensa por enquanto',
      message: 'Quando houver recompensas dos parceiros, elas aparecem aqui.',
    );
  }

  Widget _couponsSection() {
    final coupons = _service.redemptions;
    int count(CouponStatus status) =>
        coupons.where((coupon) => coupon.status == status).length;
    final visible =
        coupons.where((coupon) => coupon.status == _couponTab).toList();

    return Column(
      key: _couponsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: _sectionTitle(
            'Meus cupons',
            'Toque em um cupom para ver o código e conferir no balcão.',
          ),
        ),
        const SizedBox(height: 4),
        _chipRow([
          for (final status in CouponStatus.values)
            _choiceChip(
              label: '${status.pluralLabel} (${count(status)})',
              selected: _couponTab == status,
              onSelected: () => setState(() => _couponTab = status),
            ),
        ]),
        if (visible.isEmpty)
          _couponsEmpty()
        else
          for (final coupon in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CouponTile(
                coupon: coupon,
                onTap: () => _openCoupon(coupon),
              ),
            ),
      ],
    );
  }

  Widget _couponsEmpty() {
    switch (_couponTab) {
      case CouponStatus.active:
        return const EmptyStateView(
          icon: Icons.confirmation_number_outlined,
          title: 'Nenhum cupom disponível',
          message: 'Resgate uma recompensa e o cupom aparece aqui.',
        );
      case CouponStatus.used:
        return const EmptyStateView(
          icon: Icons.task_alt,
          title: 'Nenhum cupom usado',
          message: 'Os cupons conferidos no balcão aparecem aqui.',
        );
      case CouponStatus.expired:
        return const EmptyStateView(
          icon: Icons.event_busy_outlined,
          title: 'Nenhum cupom vencido',
          message: 'Os cupons que passarem da validade aparecem aqui.',
        );
    }
  }
}
