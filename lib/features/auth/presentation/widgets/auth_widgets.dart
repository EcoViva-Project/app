import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Peças comuns das telas de entrar, criar conta e recuperar senha.

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// E-mail obrigatório, no formato `algo@algo.dominio`.
String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (email.length > 120 || !_emailPattern.hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

/// Senha com pelo menos 6 caracteres.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Informe a senha.';
  if (password.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
  return null;
}

/// Rola a tela até o widget da [key] depois do próximo quadro. Usado para
/// trazer a faixa de erro para a área visível quando ela aparece.
void revealAfterFrame(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}

/// Campo de e-mail com teclado, preenchimento automático e validação.
class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    super.key,
    required this.controller,
    this.autofillHints = const [AutofillHints.email],
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: const InputDecoration(
        labelText: 'E-mail',
        prefixIcon: Icon(Icons.mail_outline),
      ),
      validator: validateEmail,
    );
  }
}

/// Campo de senha com o botão de mostrar e ocultar.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.labelText = 'Senha',
    this.helperText,
    this.prefixIcon = Icons.lock_outline,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.validator = validatePassword,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final IconData prefixIcon;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool readOnly;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Rótulo de botão que ganha um indicador enquanto a ação está em andamento.
///
/// O botão fica desabilitado nesse momento (fundo claro do tema), por isso o
/// indicador usa o verde escuro da marca.
class AuthButtonLabel extends StatelessWidget {
  const AuthButtonLabel({super.key, required this.label, this.loading = false});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    if (!loading) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.brandDarkAccent,
            semanticsLabel: 'Aguarde',
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: text),
      ],
    );
  }
}

/// Botão principal das telas de autenticação, de largura total.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;

  /// `null` desabilita o botão (por exemplo, enquanto outra ação da tela roda).
  final VoidCallback? onPressed;

  /// Mostra o indicador e bloqueia novos toques.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: AuthButtonLabel(label: label, loading: loading),
      ),
    );
  }
}

/// Faixa de erro, anunciada pelos leitores de tela assim que aparece.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                color: AppColors.onErrorContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa de aviso (não é erro), também anunciada pelos leitores de tela.
class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({super.key, required this.message, this.detail});

  final String message;

  /// Linha complementar, em texto menor.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brandSecondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandDarkAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
