import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const String _genericInfo =
      'Se existir uma conta com este e-mail, enviaremos as instruções de recuperação.';
  static final RegExp _codePattern = RegExp(r'^\d{6}$');

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _errorKey = GlobalKey();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _info;
  int? _expiresInMinutes;

  /// O código só chega à tela quando não existe e-mail para entregá-lo:
  /// no modo local ou em uma versão de desenvolvimento.
  bool get _canShowCode => AuthService.instance.isLocalMode || kDebugMode;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    if (!_codePattern.hasMatch((value ?? '').trim())) {
      return 'Informe os 6 dígitos do código.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '').isEmpty) return 'Repita a nova senha.';
    if (value != _passwordController.text) return 'As senhas não conferem.';
    return null;
  }

  String? get _validityText {
    final minutes = _expiresInMinutes;
    if (minutes == null || minutes <= 0) return null;
    return minutes == 1
        ? 'O código vale por 1 minuto.'
        : 'O código vale por $minutes minutos.';
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_loading) return;
    if (!resend && !(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _resending = resend;
      _error = null;
    });
    try {
      final data = await AuthService.instance.forgotPassword(
        _emailController.text,
      );
      if (!mounted) return;

      final rawCode = _canShowCode ? data['devCode']?.toString() : null;
      final devCode = (rawCode == null || rawCode.isEmpty) ? null : rawCode;

      if (devCode == null && AuthService.instance.isLocalMode) {
        // Este aparelho não envia e-mail: sem código, não há como continuar.
        _showError(
          'Não há conta com este e-mail neste aparelho. Confira o e-mail ou crie uma conta.',
        );
        return;
      }

      final apiMessage = data['message'];
      setState(() {
        _codeSent = true;
        _expiresInMinutes = (data['expiresInMinutes'] as num?)?.toInt();
        _passwordController.clear();
        _confirmController.clear();
        if (devCode != null) {
          _codeController.text = devCode;
          _info =
              'Modo demonstração: como este aparelho não envia e-mail, '
              'o código aparece aqui: $devCode';
        } else {
          _codeController.clear();
          _info =
              apiMessage is String && apiMessage.isNotEmpty
                  ? apiMessage
                  : _genericInfo;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível solicitar o código. Tente de novo.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_loading) return;
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _resending = false;
      _error = null;
    });
    try {
      await AuthService.instance.resetPassword(
        email: _emailController.text,
        code: _codeController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida. Entre com a nova senha.'),
          ),
        );
      context.go('/login');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível redefinir a senha. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useAnotherEmail() {
    setState(() {
      _codeSent = false;
      _info = null;
      _error = null;
      _expiresInMinutes = null;
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  void _showError(String message) {
    setState(() => _error = message);
    revealAfterFrame(_errorKey);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        appBar: AppBar(
          backgroundColor: AppColors.brandBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            color: AppColors.brandTextPrimary,
            onPressed: _loading ? null : _goBack,
          ),
          title: Text(
            'Recuperar senha',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _codeSent
                          ? 'Defina uma nova senha'
                          : 'Esqueceu sua senha?',
                      style: AppTextStyles.headlineLg.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _codeSent
                          ? 'Digite o código de 6 dígitos e escolha uma nova senha para ${_emailController.text.trim()}.'
                          : 'Digite o e-mail da sua conta para receber um código de recuperação.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      AuthErrorBanner(key: _errorKey, message: _error!),
                      const SizedBox(height: 12),
                    ],
                    if (_codeSent && _info != null) ...[
                      AuthInfoBanner(message: _info!, detail: _validityText),
                      const SizedBox(height: 12),
                    ],
                    if (!_codeSent) _buildEmailStep() else _buildResetStep(),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('Voltar para o login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthEmailField(
              controller: _emailController,
              readOnly: _loading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _requestCode(),
            ),
            const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'Enviar código',
              loading: _loading,
              onPressed: _requestCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeController,
              readOnly: _loading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: _validateCode,
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _passwordController,
              readOnly: _loading,
              labelText: 'Nova senha',
              helperText: 'Mínimo de 6 caracteres',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
              controller: _confirmController,
              readOnly: _loading,
              labelText: 'Confirmar nova senha',
              prefixIcon: Icons.lock_reset,
              autofillHints: const [AutofillHints.newPassword],
              validator: _validateConfirmation,
              onFieldSubmitted: (_) => _resetPassword(),
            ),
            const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'Redefinir senha',
              loading: _loading && !_resending,
              onPressed: _loading ? null : _resetPassword,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading ? null : () => _requestCode(resend: true),
              child: AuthButtonLabel(
                label: 'Reenviar código',
                loading: _resending,
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _useAnotherEmail,
              child: const Text('Usar outro e-mail'),
            ),
          ],
        ),
      ),
    );
  }
}
