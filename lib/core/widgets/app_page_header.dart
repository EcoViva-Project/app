import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({
    super.key,
    required this.pageIcon,
    required this.title,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.notificationTooltip = 'Notificações',
    this.profileTooltip = 'Perfil',
    this.backgroundColor,
    this.iconBackgroundColor,
    this.iconColor,
    this.showProfileAvatar = true,
    this.profileInitials = 'C',
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
  final String profileInitials;

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
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(pageIcon, color: iconCol, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.brandPrimary,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: profileTooltip,
            child: Semantics(
              button: true,
              label: profileTooltip,
              child: InkResponse(
                onTap: onProfilePressed ?? () {},
                radius: 24,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.brandSecondaryContainer,
                      child: Text(
                        profileInitials,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandDarkAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
