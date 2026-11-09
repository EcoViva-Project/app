import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/local/local_seed.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'reward_ui.dart';

/// Abre o cupom em tela cheia: código, situação e conferência no balcão.
///
/// [justRedeemed] acrescenta o aviso de resgate confirmado.
Future<void> showCouponDialog(
  BuildContext context,
  RewardRedemption coupon, {
  bool justRedeemed = false,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => CouponDialog(coupon: coupon, justRedeemed: justRedeemed),
  );
}

/// Um cupom resgatado, pronto para mostrar ao parceiro.
class CouponDialog extends StatefulWidget {
  const CouponDialog({
    super.key,
    required this.coupon,
    this.justRedeemed = false,
  });

  final RewardRedemption coupon;
  final bool justRedeemed;

  @override
  State<CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<CouponDialog> {
  final RewardService _service = RewardService.instance;

  // O diálogo cobre a tela; com um mensageiro próprio os avisos aparecem por
  // cima dele, e não escondidos atrás.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late RewardRedemption _latest = widget.coupon;
  bool _checking = false;

  /// O cupom como está no serviço agora (passa a "Usado" depois de conferido).
  RewardRedemption get _coupon => _service.redemptions.firstWhere(
    (item) => item.id == _latest.id,
    orElse: () => _latest,
  );

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyCode(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      _showMessage('Código copiado.');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível copiar. Toque no código e segure para selecionar.',
      );
    }
  }

  Future<void> _checkAtCounter(RewardRedemption coupon) async {
    if (_checking) return;
    _checking = true;
    try {
      final updated = await showDialog<RewardRedemption>(
        context: context,
        builder: (_) => PartnerPinDialog(coupon: coupon),
      );
      if (!mounted || updated == null) return;
      setState(() => _latest = updated);
      _showMessage('Cupom conferido');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.brandBackground,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: AppColors.brandBackground,
          appBar: AppBar(
            backgroundColor: AppColors.brandBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'Seu cupom',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandDarkAccent,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(
                  Icons.close,
                  color: AppColors.brandTextPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: AnimatedBuilder(
              animation: _service,
              builder: (context, _) => _content(_coupon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(RewardRedemption coupon) {
    final address = coupon.partnerAddress?.trim() ?? '';
    final description = coupon.rewardDescription?.trim() ?? '';
    final terms = coupon.terms?.trim() ?? '';
    final status = coupon.status;
    final showDetail = coupon.statusDetail != status.label;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.justRedeemed) ...[
            RewardPanel(
              color: AppColors.brandSecondaryContainer,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.brandDarkAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resgate confirmado!',
                          style: AppTextStyles.labelLg.copyWith(
                            color: AppColors.brandDarkAccent,
                          ),
                        ),
                        Text(
                          'O cupom também fica guardado em "Meus cupons".',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.brandTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          RewardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RewardIconBox(icon: coupon.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        coupon.rewardTitle,
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                RewardInfoRow(
                  icon: Icons.storefront_outlined,
                  text: coupon.partnerName,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RewardInfoRow(icon: Icons.place_outlined, text: address),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          RewardPanel(
            color: AppColors.brandSecondaryContainer,
            child: Column(
              children: [
                Text(
                  'Código do cupom',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    coupon.code,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLg.copyWith(
                      color:
                          coupon.isActive
                              ? AppColors.brandDarkAccent
                              : AppColors.brandTextSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyCode(coupon.code),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar código'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RewardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(status.icon, color: status.color, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.label,
                            style: AppTextStyles.labelLg.copyWith(
                              color: status.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (showDetail)
                            Text(
                              coupon.statusDetail,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.brandTextPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (coupon.dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  RewardInfoRow(
                    icon: Icons.event_outlined,
                    text: 'Resgatado em ${coupon.dateLabel}',
                    detail: 'Custou ${pointsLabel(coupon.pointsSpent)}',
                  ),
                ],
                if (coupon.valueCents > 0) ...[
                  const SizedBox(height: 10),
                  RewardInfoRow(
                    icon: Icons.sell_outlined,
                    text:
                        'Vale '
                        '${UserProgressService.formatMoney(coupon.valueCents)}',
                  ),
                ],
              ],
            ),
          ),
          if (coupon.isActive) ...[
            const SizedBox(height: 12),
            Text(
              'Mostre este código no balcão. O atendente confere digitando '
              'o código do parceiro.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _checkAtCounter(coupon),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Conferir no balcão'),
            ),
          ],
          if (terms.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo em que quem atende no balcão digita o código do parceiro.
///
/// Fecha devolvendo o cupom já marcado como usado. Código errado aparece no
/// próprio campo, sem fechar.
class PartnerPinDialog extends StatefulWidget {
  const PartnerPinDialog({super.key, required this.coupon});

  final RewardRedemption coupon;

  @override
  State<PartnerPinDialog> createState() => _PartnerPinDialogState();
}

class _PartnerPinDialogState extends State<PartnerPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Digite o código do parceiro.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await RewardService.instance.useCoupon(
        widget.coupon,
        pin,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      _pinController.clear();
      setState(() {
        _submitting = false;
        _error =
            error is ApiException
                ? error.message
                : 'Não foi possível conferir o cupom. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Enquanto a conferência está em andamento o diálogo não fecha, para o
      // resultado não se perder.
      canPop: !_submitting,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Conferir no balcão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entregue o celular a quem atende no balcão para digitar o '
              'código do parceiro. Depois da conferência, o cupom '
              '${widget.coupon.code} fica marcado como usado.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              autofocus: true,
              // Somente leitura (e não desabilitado) durante o envio: assim o
              // teclado continua aberto se o código estiver errado.
              readOnly: _submitting,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Código do parceiro',
                errorText: _error,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (AuthService.instance.isLocalMode) ...[
              const SizedBox(height: 8),
              Text(
                'Demonstração: o código dos parceiros é '
                '${LocalSeed.demoPartnerPin}.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Conferindo…' : 'Confirmar'),
          ),
        ],
      ),
    );
  }
}
