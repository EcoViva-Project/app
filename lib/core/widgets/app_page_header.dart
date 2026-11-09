import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Cabeçalho padrão das telas: ícone e título, sino de notificações e avatar.
///
/// O avatar mostra as iniciais do usuário logado e leva ao Perfil. Telas fora
/// das abas principais passam `showBack: true` para ganhar a seta de voltar.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({
    super.key,
    required this.pageIcon,
    required this.title,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.notificationTooltip = 'Notificações',
    this.profileTooltip = 'Abrir perfil',
    this.backgroundColor,
    this.iconBackgroundColor,
    this.iconColor,
    this.showProfileAvatar = true,
    this.showBack = false,
    this.backFallback = '/inicio',
    this.profileInitials,
  });

  final IconData pageIcon;
  final String title;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;
  final String notificationTooltip;
  final String profileTooltip;
  final Color? backgroundColor;
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final bool showProfileAvatar;

  /// Mostra a seta de voltar no lugar do ícone da página.
  final bool showBack;

  /// Para onde a seta leva quando não há tela anterior na pilha.
  final String backFallback;

  /// Iniciais do avatar; por padrão, as do usuário logado.
  final String? profileInitials;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.brandBackground;
    final iconBgColor = iconBackgroundColor ?? AppColors.brandPrimary;
    final iconCol = iconColor ?? Colors.white;

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: showBack ? 0 : 16,
      automaticallyImplyLeading: false,
      leading:
          showBack
              ? IconButton(
                tooltip: 'Voltar',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.brandTextPrimary,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(backFallback);
                  }
                },
              )
              : null,
      title: Row(
        children: [
          if (!showBack) ...[
            ExcludeSemantics(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(pageIcon, color: iconCol, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      actions: [
        AnimatedBuilder(
          animation: NotificationService.instance,
          builder: (context, _) {
            final unread = NotificationService.instance.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed:
                      onNotificationPressed ??
                      () {
                        // Evita empilhar a mesma rota duas vezes (chaves duplicadas).
                        final currentPath =
                            GoRouter.of(
                              context,
                            ).routerDelegate.currentConfiguration.uri.path;
                        if (currentPath != '/notificacoes') {
                          context.push('/notificacoes');
                        }
                      },
                  icon: Icon(
                    unread > 0
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    color: AppColors.brandTextPrimary,
                  ),
                  tooltip:
                      unread > 0
                          ? '$notificationTooltip ($unread não lidas)'
                          : notificationTooltip,
                ),
                if (unread > 0)
                  Positioned(
                    right: 6,
                    top: 5,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: bgColor, width: 1.5),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (showProfileAvatar)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedBuilder(
              animation: AuthService.instance,
              builder: (context, _) {
                final initials =
                    profileInitials ?? AuthService.instance.userInitials;
                return IconButton(
                  tooltip: profileTooltip,
                  onPressed: onProfilePressed ?? () => context.go('/perfil'),
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brandSecondaryContainer,
                    child: Text(
                      initials,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}
