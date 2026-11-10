import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../core/services/photo_proof.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/record_photo.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/weekly_cap_card.dart';

/// Formulário para registrar uma ação do catálogo.
class RegistroAcaoPage extends StatefulWidget {
  const RegistroAcaoPage({super.key, required this.actionId});

  /// Identificador da ação no catálogo (vem de `/registro-acao/:id`).
  final int actionId;

  @override
  State<RegistroAcaoPage> createState() => _RegistroAcaoPageState();
}

class _RegistroAcaoPageState extends State<RegistroAcaoPage> {
  static const int _notesMaxLength = 500;

  final ActionCatalogService _catalog = ActionCatalogService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  late final Listenable _services = Listenable.merge([_catalog, _progress]);
  final TextEditingController _notesController = TextEditingController();

  int _quantity = 1;
  bool _submitting = false;

  /// Foto de comprovação escolhida (caminho entregue pela câmera ou galeria).
  /// Só é copiada para a pasta do app na hora de registrar.
  String? _photoPath;

  /// A foto veio da recuperação do Android (o app foi fechado com a câmera
  /// aberta).
  bool _photoRecovered = false;
  bool _picking = false;

  /// Carga do catálogo pedida por esta tela.
  bool _loadingNow = false;

  /// Erro de carga que o serviço não guardou em `error`.
  String? _loadError;

  /// A ação e a folga do teto no momento do envio. O registro muda os limites
  /// e o teto; sem este retrato, a tela piscaria com os valores novos enquanto
  /// é trocada pela confirmação.
  ({EcoAction action, int? weeklyRoom})? _sent;

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: `load()` avisa os ouvintes na hora, e isso
    // não pode acontecer no meio da montagem da tela.
    if (!_catalog.isLoaded && !_catalog.loading) {
      _loadingNow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLoad());
    }
    if (!_progress.isLoaded && !_progress.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Sem o resumo, a tela só não mostra o aviso do teto semanal.
        if (mounted) _progress.load().catchError((_) {});
      });
    }
    if (PhotoProof.available) _recoverLostPhoto();
  }

  /// No Android, o sistema pode fechar o app enquanto a câmera está aberta;
  /// a foto tirada fica guardada e volta aqui.
  Future<void> _recoverLostPhoto() async {
    try {
      final path = await PhotoProof.picker.recoverLost();
      if (path == null || !mounted || _photoPath != null) return;
      setState(() {
        _photoPath = path;
        _photoRecovered = true;
      });
    } catch (_) {
      // Sem foto recuperada: a tela segue normal.
    }
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final path = await PhotoProof.picker.pick(source);
      if (!mounted || path == null) return;
      setState(() {
        _photoPath = path;
        _photoRecovered = false;
      });
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback:
            source == PhotoSource.camera
                ? 'Não foi possível abrir a câmera. Tente de novo.'
                : 'Não foi possível abrir a galeria. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoRecovered = false;
    });
  }

  @override
  void didUpdateWidget(covariant RegistroAcaoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actionId != oldWidget.actionId && !_submitting) {
      _quantity = 1;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Pontos que ainda cabem no teto desta semana; `null` se não há teto ou se
  /// o resumo ainda não foi carregado.
  int? get _weeklyRoom =>
      _progress.isLoaded && _progress.hasWeeklyCap
          ? _progress.weeklyRemaining
          : null;

  Future<void> _load() async {
    if (_loadingNow) return;
    setState(() {
      _loadingNow = true;
      _loadError = null;
    });
    await _runLoad();
  }

  Future<void> _runLoad() async {
    if (!mounted) {
      _loadingNow = false;
      return;
    }
    try {
      await _catalog.load();
    } catch (error) {
      if (!mounted) return;
      if (!_catalog.isLoaded) {
        _loadError =
            error is ApiException
                ? error.message
                : 'Não foi possível carregar a ação. Tente de novo.';
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNow = false);
      } else {
        _loadingNow = false;
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/acoes');
    }
  }

  Future<void> _submit(EcoAction action, int quantity, int? weeklyRoom) async {
    if (_submitting) return;
    if (!action.canRegister) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _quantity = quantity;
      _sent = (action: action, weeklyRoom: weeklyRoom);
    });
    final notes = _notesController.text.trim();

    // A foto é copiada para a pasta do app só agora, para não sobrar arquivo
    // de um registro que não aconteceu.
    String? photo;
    final photoPath = PhotoProof.available ? _photoPath : null;
    if (photoPath != null) {
      try {
        photo = await PhotoProof.files.save(photoPath);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _sent = null;
        });
        showErrorSnackBar(
          context,
          error,
          fallback:
              'Não foi possível guardar a foto. Tente de novo ou remova a foto para registrar sem ela.',
        );
        return;
      }
    }

    try {
      await ActionHistoryService.instance.submitAction(
        actionId: action.id,
        quantity: quantity,
        notes: notes.isEmpty ? null : notes,
        photo: photo,
      );
      if (!mounted) return;
      // `_submitting` continua ligado: esta tela está saindo, e um segundo
      // toque durante a troca não pode registrar de novo.
      context.pushReplacement('/confirmacao-registro');
    } catch (error) {
      // O registro não aconteceu: a cópia da foto não serve para nada.
      if (photo != null) PhotoProof.files.delete(photo).ignore();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = null;
      });
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível registrar a ação. Tente de novo.',
      );
      // O erro pode ser um limite já atingido: atualiza os limites da ação.
      _catalog.load().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Registrar ação',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _services,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final sent = _sent;
    final action = sent?.action ?? _catalog.byId(widget.actionId);
    if (action == null) {
      if (!_catalog.isLoaded) return _buildUnloaded();
      return EmptyStateView(
        icon: Icons.search_off,
        title: 'Ação não encontrada',
        message: 'Ela pode ter saído do catálogo. Escolha outra na lista.',
        actionLabel: 'Ver ações',
        onAction: () => context.go('/acoes'),
      );
    }
    return _buildForm(action, sent != null ? sent.weeklyRoom : _weeklyRoom);
  }

  Widget _buildUnloaded() {
    final message = _catalog.error ?? _loadError;
    if (message == null && (_catalog.loading || _loadingNow)) {
      return const LoadingView(message: 'Carregando a ação…');
    }
    return LoadErrorView(
      message: message ?? 'Não foi possível carregar a ação.',
      onRetry: _load,
    );
  }

  /// "1 de 2 hoje" ou "0 de 1 nesta semana"; `null` se a ação não tem limite.
  String? _usageLabel(EcoAction action) {
    final daily = action.dailyLimit;
    final weekly = action.weeklyLimit;
    if (weekly != null && (daily == null || action.usedThisWeek >= weekly)) {
      return '${action.usedThisWeek} de $weekly nesta semana';
    }
    if (daily != null) return '${action.usedToday} de $daily hoje';
    return null;
  }

  String _blockedMessage(EcoAction action) {
    final daily = action.dailyLimit;
    final weekly = action.weeklyLimit;
    final String reason;
    if (weekly != null && action.usedThisWeek >= weekly) {
      reason =
          'Limite desta semana atingido (${action.usedThisWeek} de $weekly).';
    } else if (daily != null) {
      reason = 'Limite de hoje atingido (${action.usedToday} de $daily).';
    } else {
      reason = 'Esta ação já atingiu o limite de registros.';
    }
    // "Volta amanhã" ou "Volta na segunda-feira".
    final comesBack = action.blockedLabel;
    return comesBack == null ? reason : '$reason $comesBack.';
  }

  Widget _buildForm(EcoAction action, int? weeklyRoom) {
    final canRegister = action.canRegister;
    final maxQuantity = math.max(1, action.maxQuantity);
    final quantity = math.min(math.max(_quantity, 1), maxQuantity);
    final basePoints = action.points * quantity;
    final credited =
        weeklyRoom == null
            ? basePoints
            : math.min(basePoints, math.max(weeklyRoom, 0));
    final capped = credited < basePoints;
    final limit = action.limitLabel;
    final usage = _usageLabel(action);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionCard(action, limit: limit, usage: usage),
          const SizedBox(height: 12),
          const WeeklyCapCard(compact: true),
          if (!canRegister) ...[
            const SizedBox(height: 12),
            _Notice(icon: Icons.schedule, text: _blockedMessage(action)),
          ] else ...[
            if (maxQuantity > 1) ...[
              const SizedBox(height: 16),
              _fieldLabel('Quantidade'),
              const SizedBox(height: 6),
              _buildQuantitySelector(quantity, maxQuantity),
            ],
            const SizedBox(height: 16),
            _buildSummary(action, quantity, basePoints),
            if (capped) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.speed_outlined,
                text:
                    credited > 0
                        ? 'Por causa do teto semanal, só $credited de $basePoints pts entram agora. '
                            'A ação continua valendo para desafios e conquistas.'
                        : 'Teto semanal atingido: este registro não soma pontos agora, '
                            'mas a ação continua valendo para desafios e conquistas.',
              ),
            ],
            const SizedBox(height: 16),
            _fieldLabel('Observações (opcional)'),
            const SizedBox(height: 6),
            _buildNotesField(),
            if (PhotoProof.available) ...[
              const SizedBox(height: 8),
              _fieldLabel('Foto de comprovação (opcional)'),
              const SizedBox(height: 6),
              _buildPhotoField(),
            ],
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                canRegister && !_submitting
                    ? () => _submit(action, quantity, weeklyRoom)
                    : null,
            icon:
                _submitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandDarkAccent,
                      ),
                    )
                    : const Icon(Icons.check_circle, size: 20),
            label: Text(_submitting ? 'Registrando…' : 'Confirmar registro'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              textStyle: AppTextStyles.labelLg,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting ? null : _goBack,
            child: Text(canRegister ? 'Cancelar e voltar' : 'Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelLg.copyWith(color: AppColors.brandTextPrimary),
    );
  }

  Widget _buildActionCard(
    EcoAction action, {
    required String? limit,
    required String? usage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action.icon,
                        size: 16,
                        color: AppColors.brandDarkAccent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          action.categoryLabel,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.brandDarkAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${action.points} pts por registro',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            action.title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              action.description,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
          if (limit != null || usage != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (limit != null)
                  _MetaChip(icon: Icons.event_repeat, label: limit),
                if (usage != null) _MetaChip(icon: Icons.task_alt, label: usage),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(int quantity, int maxQuantity) {
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: AppColors.brandBackground,
      foregroundColor: AppColors.brandTextPrimary,
      minimumSize: const Size(48, 48),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    quantity == 1 ? '1 vez' : '$quantity vezes',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Até $maxQuantity neste registro',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed:
                quantity > 1 && !_submitting
                    ? () => setState(() => _quantity = quantity - 1)
                    : null,
            icon: const Icon(Icons.remove),
            style: buttonStyle,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: ExcludeSemantics(
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed:
                quantity < maxQuantity && !_submitting
                    ? () => setState(() => _quantity = quantity + 1)
                    : null,
            icon: const Icon(Icons.add),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(EcoAction action, int quantity, int basePoints) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.eco,
            label:
                quantity > 1
                    ? 'Este registro vale (${action.points} × $quantity)'
                    : 'Este registro vale',
            value: '+$basePoints pts',
          ),
          if (action.liters > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.water_drop_outlined,
              label: 'Água poupada (estimativa)',
              value: '${action.liters * quantity} L',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoField() {
    final path = _photoPath;
    final enabled = !_submitting && !_picking;
    final note = Text(
      'A foto fica só neste celular e ainda não é conferida por ninguém. '
      'Ela é um selo: não muda os pontos.',
      style: AppTextStyles.bodySm.copyWith(color: AppColors.brandTextSecondary),
    );

    if (path == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PhotoButton(
                icon: Icons.photo_camera_outlined,
                label: 'Tirar foto',
                onPressed:
                    enabled ? () => _pickPhoto(PhotoSource.camera) : null,
              ),
              _PhotoButton(
                icon: Icons.photo_library_outlined,
                label: 'Escolher da galeria',
                onPressed:
                    enabled ? () => _pickPhoto(PhotoSource.gallery) : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          note,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                image: true,
                label: 'Prévia da foto de comprovação',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    key: const ValueKey<String>('registro-foto-previa'),
                    width: 88,
                    height: 88,
                    child: PickedPhotoPreview(path: path, cacheWidth: 264),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _photoRecovered
                          ? 'Recuperamos a foto que você tinha tirado.'
                          : 'Foto pronta para o registro.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _submitting ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Remover foto'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          note,
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: _notesController,
      enabled: !_submitting,
      minLines: 3,
      maxLines: 5,
      maxLength: _notesMaxLength,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.bodyMd.copyWith(color: AppColors.brandTextPrimary),
      decoration: InputDecoration(
        hintText: 'Conte como foi, se quiser.',
        hintStyle: AppTextStyles.bodyMd.copyWith(
          color: AppColors.brandTextSecondary,
        ),
        filled: true,
        fillColor: AppColors.brandSurface,
        contentPadding: const EdgeInsets.all(12),
        counterStyle: AppTextStyles.bodySm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
        border: border(AppColors.brandBorder),
        enabledBorder: border(AppColors.brandBorder),
        disabledBorder: border(AppColors.brandBorder),
        focusedBorder: border(AppColors.brandDarkAccent, 1.5),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: AppColors.brandSurface,
        textStyle: AppTextStyles.labelLg,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandDarkAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTextStyles.labelLg.copyWith(
            color: AppColors.brandDarkAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Aviso em destaque (limite da ação ou teto semanal).
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brandTertiaryAccent.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandTertiaryAccent.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
