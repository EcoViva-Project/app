import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _errorKey = GlobalKey();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _neighborhoodController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final length = (value ?? '').trim().length;
    if (length == 0) return 'Informe seu nome.';
    if (length < 2 || length > 80) return 'Use de 2 a 80 caracteres.';
    return null;
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '').isEmpty) return 'Repita a senha.';
    if (value != _passwordController.text) return 'As senhas não conferem.';
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        neighborhood: _neighborhoodController.text,
      );
      // Com a sessão aberta, o roteador leva ao início sozinho.
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível criar a conta. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Mostra o erro na faixa do topo e rola a tela até ela.
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
            'Criar conta',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Junte-se à comunidade',
                        style: AppTextStyles.headlineLg.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Registre suas ações, acompanhe conquistas e inspire a vizinhança.',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        AuthErrorBanner(key: _errorKey, message: _error!),
                        const SizedBox(height: 12),
                      ],
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              readOnly: _loading,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(80),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Nome completo',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: _validateName,
                            ),
                            const SizedBox(height: 12),
                            AuthEmailField(
                              controller: _emailController,
                              readOnly: _loading,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _neighborhoodController,
                              readOnly: _loading,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.sublocality],
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(80),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Bairro (opcional)',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AuthPasswordField(
                              controller: _passwordController,
                              readOnly: _loading,
                              helperText: 'Mínimo de 6 caracteres',
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            AuthPasswordField(
                              controller: _confirmController,
                              readOnly: _loading,
                              labelText: 'Confirmar senha',
                              prefixIcon: Icons.lock_reset,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: _validateConfirmation,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AuthPrimaryButton(
                        label: 'Criar minha conta',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text('Já tenho conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
