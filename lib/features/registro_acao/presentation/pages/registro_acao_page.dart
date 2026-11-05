import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/action_history_service.dart' as history;
import '../../../../core/services/api_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/user_progress_service.dart';

class RegistroAcaoPage extends StatefulWidget {
  const RegistroAcaoPage({super.key, this.action});

  final Map<String, dynamic>? action;

  @override
  State<RegistroAcaoPage> createState() => _RegistroAcaoPageState();
}

class _RegistroAcaoPageState extends State<RegistroAcaoPage> {
  int _count = 2;
  bool _submitting = false;
  final TextEditingController _notesController = TextEditingController();

  int get _actionId => (widget.action?['id'] as num?)?.toInt() ?? 1;

  int get _basePoints => (widget.action?['pointsValue'] as num?)?.toInt() ?? 15;

  int get _baseLiters => (widget.action?['liters'] as num?)?.toInt() ?? 12;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showPointsInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Como os pontos funcionam',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Cada unidade registrada vale $_basePoints pontos e representa cerca de '
            '$_baseLiters litros de água poupados. Ajuste a quantidade para refletir '
            'sua ação real — o impacto é calculado automaticamente.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final action = widget.action ?? {};
    final title = action['title']?.toString() ?? 'Ação sustentável';
    final points = _basePoints * _count;
    final liters = _baseLiters * _count;
    final notes = _notesController.text.trim();

    setState(() => _submitting = true);
    try {
      final result = await history.ActionHistoryService.instance.submitAction(
        actionId: _actionId,
        quantity: _count,
        notes: notes.isEmpty ? null : notes,
      );

      if (result['summary'] is Map<String, dynamic>) {
        UserProgressService.instance.applySummary(
          result['summary'] as Map<String, dynamic>,
        );
      }
      if (result['achievements'] is List) {
        AchievementService.instance.applyAchievements(
          (result['achievements'] as List)
              .map((item) => Achievement.fromApi(item as Map<String, dynamic>))
              .toList(),
        );
      }
      NotificationService.instance.load();

      if (!mounted) return;
      context.push(
        '/confirmacao-registro',
        extra: {'points': points, 'liters': liters, 'action': title},
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar a ação.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action ?? {};
    final title = action['title']?.toString() ?? 'Ação sustentável';
    final description =
        action['description']?.toString() ??
        'Registre sua ação para gerar impacto positivo.';
    final categoryLabel = action['categoryLabel']?.toString() ?? 'Ação';
    final icon = action['icon'] as IconData? ?? Icons.eco;
    final points = (_basePoints * _count);

    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Registro de Ação',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.brandTextSecondary,
            ),
            onPressed: () => _showPointsInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                icon,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                categoryLabel,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandDarkAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
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
                            '+$points pts',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Data da realização',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.brandPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hoje',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit_calendar,
                      color: AppColors.brandTextSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Frequência / Quantidade realizada',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                          Text(
                            _count == 1
                                ? '1 vez no dia'
                                : '$_count vezes no dia',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Manhã e noite',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Diminuir quantidade',
                          onPressed:
                              _count > 1
                                  ? () {
                                    setState(() => _count--);
                                  }
                                  : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.brandBackground,
                            foregroundColor: AppColors.brandTextPrimary,
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$_count',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar quantidade',
                          onPressed:
                              _count < 10
                                  ? () {
                                    setState(() => _count++);
                                  }
                                  : null,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.brandBackground,
                            foregroundColor: AppColors.brandTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Observações ou aprendizado',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 4,
                  maxLength: 240,
                  decoration: InputDecoration(
                    hintText:
                        'Ex: Incentivei também minha família a adotar essa prática hoje...',
                    hintStyle: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brandTextSecondary.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    counterStyle: AppTextStyles.labelSm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto do momento',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brandSecondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicionar foto comprobatória ou inspiradora',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Formatos JPG, PNG até 5MB',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: AppColors.brandPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Impacto estimado: ~${_baseLiters * _count} Litros poupados hoje',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon:
                      _submitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.check_circle, size: 20),
                  label: Text('Confirmar registro (+$points pts)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Cancelar e voltar',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
