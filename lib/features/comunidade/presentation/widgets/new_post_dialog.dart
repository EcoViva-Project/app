import 'package:flutter/material.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'inline_error.dart';

/// Abre o diálogo de nova publicação. Devolve `true` quando ela foi criada.
Future<bool?> showNewPostDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const NewPostDialog(),
  );
}

/// Escreve e envia uma publicação sem sair do diálogo: se o envio falhar, o
/// texto continua no campo e o erro aparece aqui mesmo.
class NewPostDialog extends StatefulWidget {
  const NewPostDialog({super.key});

  @override
  State<NewPostDialog> createState() => _NewPostDialogState();
}

class _NewPostDialogState extends State<NewPostDialog> {
  static const int _minLength = 3;
  static const int _maxLength = 1000;

  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final length = (value ?? '').trim().length;
    if (length < _minLength) {
      return 'Escreva pelo menos $_minLength caracteres.';
    }
    if (length > _maxLength) {
      return 'Use no máximo $_maxLength caracteres.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await CommunityService.instance.createPost(_controller.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error =
            error is ApiException
                ? error.message
                : 'Não foi possível publicar. Tente de novo.';
      });
      return;
    }
    if (!mounted) return;
    // O botão continua bloqueado enquanto o diálogo fecha, para não publicar
    // duas vezes.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          'Nova publicação',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  CommunityInlineError(message: _error!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  readOnly: _sending,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: _maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Conte o que você fez pelo bairro',
                    helperText: 'De $_minLength a $_maxLength caracteres',
                    errorMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validate,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child:
                _sending
                    ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandDarkAccent,
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(child: Text('Publicando…')),
                      ],
                    )
                    : const Text('Publicar'),
          ),
        ],
      ),
    );
  }
}
