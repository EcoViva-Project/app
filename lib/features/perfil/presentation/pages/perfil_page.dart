import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/reward_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/edit_profile_dialog.dart';

/// Perfil: dados da pessoa, resumo, atalhos e conta.
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final AuthService _auth = AuthService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  final AchievementService _achievements = AchievementService.instance;
  final RewardService _rewards = RewardService.instance;

  late final Listenable _listenable = Listenable.merge([
    _auth,
    _progress,
    _achievements,
    _rewards,
  ]);

  bool _retrying = false;
  bool _editing = false;
  bool _signingOut = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    // `load()` avisa os ouvintes na hora: espera o primeiro quadro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_auth.isAuthenticated) return;
      if (!_progress.isLoaded && !_progress.loading) {
        _progress.load().catchError((_) {});
      }
      if (!_achievements.isLoaded && !_achievements.loading) {
        _achievements.load().catchError((_) {});
      }
      if (!_rewards.isLoaded && !_rewards.loading) {
        _rewards.load().catchError((_) {});
      }
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _auth.loadAll();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _editProfile() async {
    if (_editing) return;
    _editing = true;
    try {
      final saved = await showEditProfileDialog(context);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Dados atualizados.')));
    } finally {
      _editing = false;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            backgroundColor: AppColors.brandSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  Future<void> _signOut() async {
    if (_signingOut || _resetting) return;
    final confirmed = await _confirm(
      title: 'Sair da conta?',
      message: 'Para ver seus dados de novo, será preciso entrar outra vez.',
      confirmLabel: 'Sair',
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      // O roteador leva ao login quando a sessão acaba.
      await _auth.logout();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível sair agora. Tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _resetDemo() async {
    if (_resetting || _signingOut) return;
    final confirmed = await _confirm(
      title: 'Restaurar demonstração?',
      message:
          'Os dados deste aparelho serão apagados e a conta de demonstração '
          'volta ao início. Depois, o app abre a tela de entrada.',
      confirmLabel: 'Restaurar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _resetting = true);
    try {
      await _auth.resetDemo();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível restaurar a demonstração.',
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _showHelp() {
    const steps = [
      (Icons.eco_outlined, 'Em Ações, escolha o que você fez e registre para '
          'ganhar pontos.'),
      (Icons.flag_outlined, 'Em Desafios, participe de metas com prazo.'),
      (Icons.groups_outlined, 'Em Comunidade, acompanhe e publique as ações '
          'do bairro.'),
      (Icons.redeem_outlined, 'Em Recompensas, troque pontos por cupons dos '
          'parceiros.'),
      (Icons.insights_outlined, 'Em Progresso, veja seu nível e quanto falta '
          'do teto semanal de pontos.'),
    ];
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            backgroundColor: AppColors.brandSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Como usar o EcoViva',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (icon, text) in steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 20, color: AppColors.brandDarkAccent),
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
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            backgroundColor: AppColors.brandSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Sobre o EcoViva',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EcoViva • versão 1.0.0 • projeto acadêmico',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Registre hábitos sustentáveis, acompanhe seu progresso e '
                  'participe da comunidade do seu bairro.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                if (_auth.isLocalMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Modo demonstração: os dados ficam neste aparelho.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ],
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.person,
        title: 'Perfil',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _listenable,
          builder:
              (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _profileHeader(),
                  const SizedBox(height: 16),
                  _summary(),
                  const SizedBox(height: 20),
                  _sectionTitle('Atalhos'),
                  const SizedBox(height: 8),
                  _menuCard(_shortcuts()),
                  const SizedBox(height: 20),
                  _sectionTitle('Ajuda e conta'),
                  const SizedBox(height: 8),
                  _menuCard(_accountItems()),
                ],
              ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final region = _auth.regionLabel;
    final email = _auth.userEmail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.brandSecondaryContainer,
                child: Text(
                  _auth.userInitials,
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _auth.userName,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (region.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _iconLine(Icons.location_on_outlined, region),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _iconLine(Icons.mail_outline, email),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar dados'),
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: AppColors.brandTextSecondary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    if (!_progress.isLoaded) {
      final error = _progress.error;
      final busy = _retrying || _progress.loading || error == null;
      return Container(
        width: double.infinity,
        decoration: _cardDecoration,
        child:
            busy
                ? const LoadingView(message: 'Carregando seu resumo…')
                : LoadErrorView(message: error, onRetry: _retry),
      );
    }

    final weekly = _progress.weeklyPoints;
    final goal = _auth.weeklyGoal;
    final achievementsValue =
        _achievements.isLoaded
            ? '${_achievements.unlocked.length}/${_achievements.achievements.length}'
            : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_progress.level.isNotEmpty) ...[
            Text(
              _progress.level,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandDarkAccent,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _stat(
                  value: _progress.formattedPoints,
                  label: 'pontos',
                  icon: Icons.stars_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat(
                  value: UserProgressService.formatNumber(
                    _progress.actionsCount,
                  ),
                  label: _progress.actionsCount == 1 ? 'ação' : 'ações',
                  icon: Icons.eco_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat(
                  value: achievementsValue,
                  label: 'conquistas',
                  icon: Icons.military_tech_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 10),
          _iconInfo(
            Icons.bolt_outlined,
            '${UserProgressService.formatNumber(weekly)} '
            '${weekly == 1 ? 'pt' : 'pts'} nesta semana',
          ),
          const SizedBox(height: 6),
          _iconInfo(
            Icons.flag_outlined,
            'Meta semanal: $goal ${goal == 1 ? 'ação' : 'ações'}',
          ),
        ],
      ),
    );
  }

  Widget _iconInfo(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.brandDarkAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return MergeSemantics(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.brandDarkAccent),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: AppTextStyles.headlineSm.copyWith(
          color: AppColors.brandTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Widget> _shortcuts() {
    final level = _progress.isLoaded ? _progress.level : '';
    final actions = _progress.actionsCount;
    final coupons = _rewards.activeCoupons.length;

    return [
      _menuItem(
        icon: Icons.insights_outlined,
        title: 'Progresso',
        subtitle:
            level.isNotEmpty ? level : 'Nível, pontos e teto semanal',
        onTap: () => context.push('/progresso'),
      ),
      _menuItem(
        icon: Icons.military_tech_outlined,
        title: 'Conquistas',
        subtitle:
            _achievements.isLoaded
                ? '${_achievements.unlocked.length} de '
                    '${_achievements.achievements.length} desbloqueadas'
                : 'Selos e bônus',
        onTap: () => context.push('/conquistas'),
      ),
      _menuItem(
        icon: Icons.history,
        title: 'Histórico',
        subtitle:
            _progress.isLoaded
                ? (actions == 1
                    ? '1 ação registrada'
                    : '$actions ações registradas')
                : 'Suas ações registradas',
        onTap: () => context.push('/meu-historico'),
      ),
      _menuItem(
        icon: Icons.redeem_outlined,
        title: 'Recompensas',
        subtitle:
            _rewards.isLoaded
                ? (coupons == 1
                    ? '1 cupom disponível'
                    : '$coupons cupons disponíveis')
                : 'Troque pontos por cupons de parceiros',
        onTap: () => context.push('/recompensas'),
      ),
      _menuItem(
        icon: Icons.tune,
        title: 'Preferências',
        subtitle: 'Notificações, privacidade e meta semanal',
        onTap: () => context.push('/preferencias'),
      ),
    ];
  }

  List<Widget> _accountItems() {
    return [
      _menuItem(
        icon: Icons.help_outline,
        title: 'Ajuda',
        subtitle: 'Como usar o aplicativo',
        onTap: _showHelp,
      ),
      _menuItem(
        icon: Icons.info_outline,
        title: 'Sobre o EcoViva',
        subtitle: 'Versão 1.0.0',
        onTap: _showAbout,
      ),
      if (_auth.isLocalMode)
        _menuItem(
          icon: Icons.restart_alt,
          title: 'Restaurar demonstração',
          subtitle: 'Apaga os dados deste aparelho e volta ao início da '
              'apresentação',
          onTap: _resetting || _signingOut ? null : _resetDemo,
          busy: _resetting,
        ),
      _menuItem(
        icon: Icons.logout,
        title: 'Sair da conta',
        onTap: _signingOut || _resetting ? null : _signOut,
        busy: _signingOut,
        color: AppColors.error,
      ),
    ];
  }

  Widget _menuCard(List<Widget> items) {
    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.brandBorder,
                ),
              items[i],
            ],
          ],
        ),
      ),
    );
  }

  /// O único tipo de item de menu da tela.
  Widget _menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    bool busy = false,
    Color? color,
  }) {
    final foreground = color ?? AppColors.brandTextPrimary;
    return ListTile(
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: color ?? AppColors.brandDarkAccent),
      title: Text(
        title,
        style: AppTextStyles.bodyMd.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
      trailing:
          busy
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandDarkAccent,
                ),
              )
              : Icon(
                Icons.chevron_right,
                color: color ?? AppColors.brandTextSecondary,
              ),
      onTap: onTap,
    );
  }

  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: AppColors.brandSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.brandBorder),
  );
}
