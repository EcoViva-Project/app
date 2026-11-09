import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  String _name = AuthService.instance.userName;
  String _neighborhood = AuthService.instance.neighborhood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.person,
        title: 'Perfil',
        onProfilePressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Você já está no seu perfil')),
          );
        },
      ),
      body: AnimatedBuilder(
        animation: UserProgressService.instance,
        builder: (context, _) {
          final progress = UserProgressService.instance;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileHeader(context),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          label: 'Pontos',
                          value: progress.formattedPoints,
                          detail: '+140 na semana',
                          icon: Icons.stars,
                          onTap: () => context.push('/progresso'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Ações',
                          value: '${progress.actionsCount}',
                          detail: '${progress.activeDays} dias ativos',
                          icon: Icons.eco,
                          onTap: () => context.push('/progresso'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          label: 'Conquistas',
                          value:
                              '${AchievementService.instance.unlocked.length}/${AchievementService.instance.achievements.length}',
                          detail: 'selos ativos',
                          icon: Icons.military_tech,
                          onTap: () => context.push('/conquistas'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _achievementsSummary(context),
                  const SizedBox(height: 16),
                  Text(
                    'Selos recentes',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _recentBadges(),
                  const SizedBox(height: 16),
                  _historyTile(context),
                  const SizedBox(height: 10),
                  _menuTile(
                    context,
                    icon: Icons.redeem,
                    title: 'Recompensas dos parceiros',
                    subtitle: 'Use seus pontos em produtos, serviços e jogos',
                    onTap: () => context.push('/recompensas'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Preferências',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuTile(
                    context,
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificações & Lembretes',
                    subtitle: 'Escolha como quer ser lembrada',
                    onTap: () => context.push('/preferencias'),
                  ),
                  _menuTile(
                    context,
                    icon: Icons.location_city_outlined,
                    title: 'Meu Bairro & Comunidade',
                    subtitle: _neighborhood,
                    onTap: () => context.push('/preferencias'),
                  ),
                  _menuTile(
                    context,
                    icon: Icons.flag_outlined,
                    title: 'Metas Pessoais Semanais',
                    subtitle: '5 ações por semana',
                    onTap: () => context.push('/preferencias'),
                  ),
                  _menuTile(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Privacidade & Dados',
                    subtitle: 'Controle o que você compartilha',
                    onTap: () => context.push('/preferencias'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Suporte',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuTile(
                    context,
                    icon: Icons.info_outline,
                    title: 'Sobre o EcoViva',
                    subtitle: 'Versão 1.0 • Feira de Tecnologia',
                    onTap: () => _showAbout(context),
                  ),
                  _menuTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Ajuda & Sugestões',
                    subtitle: 'Fale com a equipe do projeto',
                    onTap: () => _showHelp(context),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmSignOut(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sair da conta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandTextSecondary,
                        side: const BorderSide(color: AppColors.brandBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'EcoViva • Cuidando do amanhã juntos',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileHeader(BuildContext context) {
    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.brandSecondaryContainer,
            child: Text(
              _name.isEmpty ? 'C' : _name[0].toUpperCase(),
              style: AppTextStyles.headlineLg.copyWith(
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.brandTextSecondary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '$_neighborhood • Membro da comunidade',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  button: true,
                  label: 'Editar dados pessoais',
                  child: GestureDetector(
                    onTap: () => _editProfile(context),
                    child: Container(
                      height: 48,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Editar dados pessoais',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.brandDarkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String detail,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.brandPrimary, size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementsSummary(BuildContext context) {
    final service = AchievementService.instance;
    final unlocked = service.unlocked.length;
    final total = service.achievements.length;
    final percent = total == 0 ? 0.0 : unlocked / total;
    final next = service.nextAchievement;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandSurface,
            AppColors.brandSecondaryContainer.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Minhas Conquistas',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/conquistas'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todas',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandDarkAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$unlocked de $total conquistas',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.brandSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Todos os selos desbloqueados!'
                : 'Próximo selo: ${next.title} (${(next.progress * 100).round()}%)',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentBadges() {
    final unlocked = AchievementService.instance.unlocked.take(3).toList();
    if (unlocked.isEmpty) {
      return Text(
        'Registre uma ação para desbloquear seu primeiro selo.',
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < unlocked.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _badgeTile(
              icon: unlocked[i].icon,
              title: unlocked[i].title.replaceFirst(' ', '\n'),
              color:
                  i.isEven
                      ? AppColors.brandSecondaryContainer
                      : AppColors.brandTertiaryAccent.withOpacity(0.35),
            ),
          ),
        ],
      ],
    );
  }

  Widget _badgeTile({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppColors.brandDarkAccent),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/meu-historico'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brandBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history,
                color: AppColors.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico de Atividades',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Revise suas ${UserProgressService.instance.actionsCount} ações registradas',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.brandTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.brandSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.brandBorder),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: Icon(icon, color: AppColors.brandPrimary, size: 20),
          title: Text(
            title,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.brandTextSecondary,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final nameController = TextEditingController(text: _name);
    final neighborhoodController = TextEditingController(text: _neighborhood);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Editar dados pessoais',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: neighborhoodController,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Bairro',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (mounted && saved == true) {
      final newName = nameController.text.trim();
      final newNeighborhood = neighborhoodController.text.trim();
      try {
        await AuthService.instance.updateProfile(
          name: newName.isEmpty ? null : newName,
          neighborhood: newNeighborhood.isEmpty ? null : newNeighborhood,
        );
        if (!mounted) return;
        setState(() {
          _name = AuthService.instance.userName;
          _neighborhood = AuthService.instance.neighborhood;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados com sucesso.')),
        );
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    nameController.dispose();
    neighborhoodController.dispose();
  }

  Future<void> _showHelp(BuildContext context) async {
    const email = 'contato@cidadesustentavel.app';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Ajuda & Sugestões',
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
                'Encontrou um problema ou tem uma ideia para o bairro? Fale com a equipe do projeto.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      email,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Resposta em até 2 dias úteis.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: email));
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-mail copiado!')),
                );
              },
              child: const Text('Copiar e-mail'),
            ),
          ],
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'EcoViva',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Aplicativo demonstrativo de hábitos sustentáveis e impacto comunitário.\n\nVersão 1.0 • Feira de Tecnologia',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sair da conta?',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Você precisará entrar novamente para acessar seus dados.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await AuthService.instance.logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
  }
}
