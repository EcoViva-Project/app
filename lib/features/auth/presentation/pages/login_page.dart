import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _errorKey = GlobalKey();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _demoSignIn = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _signInDemo() {
    return _signIn(
      email: AuthService.demoEmail,
      password: AuthService.demoPassword,
      demo: true,
    );
  }

  Future<void> _signIn({
    required String email,
    required String password,
    bool demo = false,
  }) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _demoSignIn = demo;
      _error = null;
    });
    try {
      await AuthService.instance.login(email: email, password: password);
      // Com a sessão aberta, o roteador leva ao início sozinho.
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível entrar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    revealAfterFrame(_errorKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthBrand(),
                    const SizedBox(height: 28),
                    Text(
                      'Que bom ter você de volta',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLg.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entre para continuar cuidando do seu bairro.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      AuthErrorBanner(key: _errorKey, message: _error!),
                      const SizedBox(height: 12),
                    ],
                    AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthEmailField(
                            controller: _emailController,
                            readOnly: _loading,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                          ),
                          const SizedBox(height: 12),
                          AuthPasswordField(
                            controller: _passwordController,
                            readOnly: _loading,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            _loading
                                ? null
                                : () => context.push('/esqueci-senha'),
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AuthPrimaryButton(
                      label: 'Entrar',
                      loading: _loading && !_demoSignIn,
                      onPressed: _loading ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _loading ? null : () => context.push('/registro'),
                      child: const Text(
                        'Ainda não tem conta? Criar conta',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (AuthService.instance.isLocalMode) ...[
                      const SizedBox(height: 12),
                      _DemoModeCard(
                        loading: _loading && _demoSignIn,
                        onSignIn: _loading ? null : _signInDemo,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/eco_leaf_logo.png',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'EcoViva',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandDarkAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Aparece só no modo local: explica onde ficam os dados e oferece a conta
/// de demonstração criada no próprio aparelho.
class _DemoModeCard extends StatelessWidget {
  const _DemoModeCard({required this.loading, required this.onSignIn});

  final bool loading;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smartphone,
                size: 20,
                color: AppColors.brandDarkAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo demonstração',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'O aplicativo está funcionando sem servidor: tudo o que você '
            'fizer fica guardado só neste aparelho.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: loading ? null : onSignIn,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: AuthButtonLabel(
              label: 'Entrar com a conta de demonstração',
              loading: loading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'E-mail: ${AuthService.demoEmail}\n'
            'Senha: ${AuthService.demoPassword}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
