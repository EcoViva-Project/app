import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';

/// Rotas das abas principais: abertas com `go`, as demais com `push`.
const Set<String> _tabRoutes = {
  '/inicio',
  '/acoes',
  '/desafios',
  '/comunidade',
  '/perfil',
};

enum _NotificationFilter {
  todas('Todas'),
  naoLidas('Não lidas'),
  conquista('Conquistas'),
  desafio('Desafios'),
  comunidade('Comunidade'),
  recompensa('Recompensas'),
  sistema('Avisos');

  const _NotificationFilter(this.label);

  final String label;

  NotificationCategory? get category => switch (this) {
    _NotificationFilter.conquista => NotificationCategory.conquista,
    _NotificationFilter.desafio => NotificationCategory.desafio,
    _NotificationFilter.comunidade => NotificationCategory.comunidade,
    _NotificationFilter.recompensa => NotificationCategory.recompensa,
    _NotificationFilter.sistema => NotificationCategory.sistema,
    _ => null,
  };

  bool matches(AppNotification notification) => switch (this) {
    _NotificationFilter.todas => true,
    _NotificationFilter.naoLidas => !notification.read,
    _ => notification.category == category,
  };
}

/// Notificações da conta: lista, filtros, detalhes e limpeza.
class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final NotificationService _service = NotificationService.instance;
  _NotificationFilter _filter = _NotificationFilter.todas;

  bool _reloading = false;
  bool _markingAll = false;
  bool _clearing = false;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    // A lista é recarregada sempre que a tela abre. `load()` avisa os
    // ouvintes na hora, por isso espera o primeiro quadro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    if (_reloading) return;
    _reloading = true;
    try {
      await _service.load();
    } catch (error) {
      // Sem lista carregada, a própria tela mostra o erro.
      if (mounted && _service.isLoaded) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível atualizar as notificações.',
        );
      } else if (mounted) {
        setState(() {});
      }
    } finally {
      _reloading = false;
    }
  }

  /// Mostra o erro deixado pela última alteração, se houver.
  void _reportChangeError() {
    final message = _service.takeLastError();
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
      return;
    }
    if (!mounted) return;
    _reportChangeError();
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    await _run(_service.markAllAsRead);
    if (!mounted) return;
    setState(() => _markingAll = false);
  }

  Future<void> _remove(AppNotification notification) async {
    if (!_removing.add(notification.id)) return;
    await _run(() => _service.remove(notification.id));
    if (!mounted) return;
    setState(() => _removing.remove(notification.id));
  }

  Future<void> _confirmClearAll() async {
    if (_clearing) return;
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
              'Limpar todas as notificações?',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Todas as notificações serão apagadas da sua conta. '
              'Não dá para desfazer.',
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
                child: const Text('Limpar tudo'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    await _run(_service.clear);
    if (!mounted) return;
    setState(() => _clearing = false);
  }

  void _open(AppNotification notification) {
    if (!notification.read) {
      _run(() => _service.markAsRead(notification.id));
    }
    _openDetails(notification);
  }

  void _goTo(String destination) {
    if (!mounted) return;
    // Abas do shell abrem com `go`; empilhar uma aba duplicaria as páginas.
    if (_tabRoutes.contains(destination)) {
      context.go(destination);
    } else {
      context.push(destination);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inicio');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: _back,
        ),
        title: Text(
          'Notificações',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.brandDarkAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_service.isLoaded) {
      final error = _service.error;
      if (error == null || _service.loading) {
        return const LoadingView(message: 'Carregando notificações…');
      }
      return LoadErrorView(message: error, onRetry: _reload);
    }

    final all = _service.notifications;
    final items = all.where(_filter.matches).toList();

    return RefreshIndicator(
      onRefresh: _reload,
      color: AppColors.brandDarkAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _summary(all),
          const SizedBox(height: 8),
          _filters(),
          const SizedBox(height: 8),
          if (items.isEmpty)
            _emptyState(hasAny: all.isNotEmpty)
          else
            for (final notification in items) ...[
              _dismissible(notification),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _summary(List<AppNotification> all) {
    final unread = _service.unreadCount;
    final text =
        all.isEmpty
            ? 'Nenhuma notificação no momento.'
            : unread == 0
            ? 'Você está em dia com as novidades.'
            : unread == 1
            ? '1 notificação não lida'
            : '$unread notificações não lidas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
        if (all.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              if (unread > 0)
                TextButton.icon(
                  onPressed: _markingAll ? null : _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Marcar todas como lidas'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandDarkAccent,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              TextButton.icon(
                onPressed: _clearing ? null : _confirmClearAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Limpar tudo'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandTextSecondary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _NotificationFilter.values) ...[
            _filterChip(filter),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(_NotificationFilter filter) {
    final selected = _filter == filter;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        widthFactor: 1,
        child: ChoiceChip(
          label: Text(filter.label),
          selected: selected,
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) => setState(() => _filter = filter),
          backgroundColor: AppColors.brandSurface,
          selectedColor: AppColors.brandSecondaryContainer,
          side: BorderSide(
            color: selected ? AppColors.brandDarkAccent : AppColors.brandBorder,
          ),
          labelStyle: AppTextStyles.labelMd.copyWith(
            color:
                selected
                    ? AppColors.brandDarkAccent
                    : AppColors.brandTextSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required bool hasAny}) {
    if (!hasAny) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: EmptyStateView(
          icon: Icons.notifications_none,
          title: 'Nenhuma notificação',
          message:
              'Novidades sobre suas ações, desafios, comunidade e '
              'recompensas aparecem aqui.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyStateView(
        icon: Icons.filter_alt_off_outlined,
        title:
            _filter == _NotificationFilter.naoLidas
                ? 'Nenhuma notificação não lida'
                : 'Nada neste filtro',
        message: 'Não há notificações em "${_filter.label}".',
        actionLabel: 'Ver todas',
        onAction: () => setState(() => _filter = _NotificationFilter.todas),
      ),
    );
  }

  Widget _dismissible(AppNotification notification) {
    return Dismissible(
      key: ValueKey('notificacao-${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _remove(notification),
      child: _notificationCard(notification),
    );
  }

  Widget _notificationCard(AppNotification notification) {
    final visual = _visualFor(notification.category);
    final removing = _removing.contains(notification.id);

    return Material(
      color: AppColors.brandSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              notification.read
                  ? AppColors.brandBorder
                  : AppColors.brandPrimary.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(notification),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _categoryIcon(visual),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (!notification.read) ...[
                          const SizedBox(width: 6),
                          Semantics(
                            label: 'Não lida',
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.brandDarkAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _categoryLabel(notification.category),
                        if (notification.timeLabel.isNotEmpty)
                          notification.timeLabel,
                      ].join(' • '),
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toque para ver os detalhes',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir notificação',
                onPressed: removing ? null : () => _remove(notification),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.brandTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(_NotificationVisual visual) {
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: visual.color, shape: BoxShape.circle),
        child: Icon(visual.icon, size: 20, color: visual.foreground),
      ),
    );
  }

  void _openDetails(AppNotification notification) {
    final visual = _visualFor(notification.category);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _categoryIcon(visual),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [
                            _categoryLabel(notification.category),
                            if (notification.timeLabel.isNotEmpty)
                              notification.timeLabel,
                          ].join(' • '),
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.brandDarkAccent,
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
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _goTo(notification.destination);
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Ver no aplicativo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _run(() => _service.toggleRead(notification.id));
                        },
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('Marcar como não lida'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandDarkAccent,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _remove(notification);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        AppColors.brandTertiaryAccent.withValues(alpha: 0.3),
        AppColors.brandDarkAccent,
      );
    case NotificationCategory.comunidade:
      return const _NotificationVisual(
        Icons.groups,
        AppColors.brandSecondaryContainer,
        AppColors.brandDarkAccent,
      );
    case NotificationCategory.recompensa:
      return _NotificationVisual(
        Icons.redeem,
        AppColors.brandTertiaryAccent.withValues(alpha: 0.3),
        AppColors.brandDarkAccent,
      );
    case NotificationCategory.sistema:
      return const _NotificationVisual(
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
    case NotificationCategory.recompensa:
      return 'Recompensa';
    case NotificationCategory.sistema:
      return 'Aviso';
  }
}
