import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

enum _NotificationFilter { todas, naoLidas, conquistas, desafios, comunidade }

class _NotificacoesPageState extends State<NotificacoesPage> {
  final NotificationService _service = NotificationService.instance;
  _NotificationFilter _filter = _NotificationFilter.todas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/inicio');
            }
          },
        ),
        title: Text(
          'Notificações',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              if (_service.unreadCount == 0) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: _service.markAllAsRead,
                child: Text(
                  'Marcar todas',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            final items = _filteredItems();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _service.unreadCount == 0
                              ? 'Você está em dia com as novidades.'
                              : '${_service.unreadCount} notificação(ões) não lida(s).',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ),
                      if (_service.notifications.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _confirmClearAll(context),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 16,
                          ),
                          label: const Text('Limpar'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandTextSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _filterChip('Todas', _NotificationFilter.todas),
                      const SizedBox(width: 8),
                      _filterChip('Não lidas', _NotificationFilter.naoLidas),
                      const SizedBox(width: 8),
                      _filterChip('Conquistas', _NotificationFilter.conquistas),
                      const SizedBox(width: 8),
                      _filterChip('Desafios', _NotificationFilter.desafios),
                      const SizedBox(width: 8),
                      _filterChip('Comunidade', _NotificationFilter.comunidade),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child:
                      items.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: items.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final notification = items[index];
                              return Dismissible(
                                key: ValueKey(notification.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                onDismissed:
                                    (_) => _service.remove(notification.id),
                                child: _notificationCard(notification),
                              );
                            },
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, _NotificationFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = filter),
      backgroundColor: AppColors.brandSurface,
      selectedColor: AppColors.brandSecondaryContainer,
      side: BorderSide(
        color:
            selected
                ? AppColors.brandSecondaryContainer
                : AppColors.brandBorder,
      ),
      labelStyle: AppTextStyles.labelSm.copyWith(
        color:
            selected ? AppColors.brandDarkAccent : AppColors.brandTextSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _notificationCard(AppNotification notification) {
    final visual = _visualFor(notification.category);
    return Material(
      color: notification.read ? AppColors.brandSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _service.markAsRead(notification.id);
          _openDetails(notification);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  notification.read
                      ? AppColors.brandBorder
                      : AppColors.brandPrimary.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 20, color: visual.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight:
                                  notification.read
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            notification.timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            notification.read
                                ? 'Lida'
                                : 'Toque para marcar como lida',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: AppTextStyles.labelSm.copyWith(
                              color:
                                  notification.read
                                      ? AppColors.brandTextSecondary
                                      : AppColors.brandPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(AppNotification notification) {
    final visual = _visualFor(notification.category);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: visual.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        visual.icon,
                        size: 20,
                        color: visual.foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _categoryLabel(notification.category),
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notification.title,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.message,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.timeLabel,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _navigateTo(notification.category);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Ver no aplicativo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.brandBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    final isFiltered = _filter != _NotificationFilter.todas;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_outlined
                    : Icons.notifications_none,
                color: AppColors.brandPrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'Nada por aqui' : 'Tudo em dia!',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Não encontramos notificações para este filtro.'
                  : 'Você não tem novas notificações no momento.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppNotification> _filteredItems() {
    final items = _service.notifications;
    switch (_filter) {
      case _NotificationFilter.todas:
        return items;
      case _NotificationFilter.naoLidas:
        return items.where((n) => !n.read).toList();
      case _NotificationFilter.conquistas:
        return items
            .where((n) => n.category == NotificationCategory.conquista)
            .toList();
      case _NotificationFilter.desafios:
        return items
            .where((n) => n.category == NotificationCategory.desafio)
            .toList();
      case _NotificationFilter.comunidade:
        return items
            .where((n) => n.category == NotificationCategory.comunidade)
            .toList();
    }
  }

  void _navigateTo(NotificationCategory category) {
    final destination = _destinationFor(category);
    const shellDestinations = {
      '/inicio',
      '/acoes',
      '/desafios',
      '/comunidade',
      '/perfil',
    };
    // Rotas de branch do StatefulShellRoute devem ser abertas com `go`;
    // usar `push` duplicaria as chaves de página do Navigator.
    if (shellDestinations.contains(destination)) {
      context.go(destination);
    } else {
      context.push(destination);
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Limpar notificações?',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Todas as notificações serão removidas desta sessão.',
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
              onPressed: () {
                _service.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Limpar'),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual(this.icon, this.color, this.foreground);

  final IconData icon;
  final Color color;
  final Color foreground;
}

_NotificationVisual _visualFor(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.conquista:
      return const _NotificationVisual(
        Icons.military_tech,
        AppColors.brandSecondaryContainer,
        AppColors.brandDarkAccent,
      );
    case NotificationCategory.desafio:
      return _NotificationVisual(
        Icons.flag_circle,
        AppColors.brandTertiaryAccent.withOpacity(0.3),
        AppColors.brandDarkAccent,
      );
    case NotificationCategory.comunidade:
      return const _NotificationVisual(
        Icons.groups,
        AppColors.brandSecondaryContainer,
        AppColors.brandPrimary,
      );
    case NotificationCategory.sistema:
      return _NotificationVisual(
        Icons.notifications_active_outlined,
        AppColors.brandBackground,
        AppColors.brandTextSecondary,
      );
  }
}

String _categoryLabel(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.conquista:
      return 'Conquista';
    case NotificationCategory.desafio:
      return 'Desafio';
    case NotificationCategory.comunidade:
      return 'Comunidade';
    case NotificationCategory.sistema:
      return 'Lembrete';
  }
}

String _destinationFor(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.conquista:
      return '/conquistas';
    case NotificationCategory.desafio:
      return '/desafios';
    case NotificationCategory.comunidade:
      return '/comunidade';
    case NotificationCategory.sistema:
      return '/acoes';
  }
}
