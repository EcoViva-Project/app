import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/weekly_cap_card.dart';

enum _SortMode {
  relevance('Relevância', 'Ordem do catálogo'),
  points('Mais pontos', 'Ações que valem mais primeiro'),
  alphabetical('Ordem alfabética', 'De A a Z');

  const _SortMode(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

const Map<String, String> _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
};

/// Minúsculas e sem acento, para a busca achar "Água" ao digitar "agua".
String _normalize(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Catálogo de ações sustentáveis, com busca, categoria e ordenação.
class AcoesPage extends StatefulWidget {
  const AcoesPage({super.key, this.initialCategory});

  /// Nome exibido da categoria (por exemplo "Água"), vindo de
  /// `/acoes?categoria=Água`.
  final String? initialCategory;

  @override
  State<AcoesPage> createState() => _AcoesPageState();
}

class _AcoesPageState extends State<AcoesPage> {
  final ActionCatalogService _catalog = ActionCatalogService.instance;
  final TextEditingController _searchController = TextEditingController();

  /// Nome exibido da categoria escolhida; `null` = todas.
  String? _selectedCategory;
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.relevance;

  /// Carga pedida por esta tela (primeira carga, "Tentar de novo" ou puxar
  /// para atualizar).
  bool _loadingNow = false;

  /// Erro de carga que o serviço não guardou em `error`.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _cleanCategory(widget.initialCategory);
    if (!_catalog.isLoaded && !_catalog.loading) {
      // Depois do primeiro quadro: `load()` avisa os ouvintes na hora, e isso
      // não pode acontecer no meio da montagem da tela.
      _loadingNow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLoad());
    }
  }

  @override
  void didUpdateWidget(covariant AcoesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory == oldWidget.initialCategory) return;
    final incoming = _cleanCategory(widget.initialCategory);
    // Igual ao filtro atual: foi esta tela que mudou o endereço.
    if (incoming == _selectedCategory) return;
    _selectedCategory = incoming;
    if (incoming != null && _searchQuery.isNotEmpty) {
      // Outra tela pediu uma categoria: a busca antiga esconderia o resultado.
      _searchQuery = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchController.clear();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String? _cleanCategory(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _load() async {
    if (_loadingNow) return;
    setState(() {
      _loadingNow = true;
      _loadError = null;
    });
    await _runLoad();
  }

  Future<void> _runLoad() async {
    if (!mounted) {
      _loadingNow = false;
      return;
    }
    // O cartão do teto semanal depende do resumo; se ele não veio na abertura
    // do app, tenta de novo junto (sem travar nem acusar erro nesta tela).
    final progress = UserProgressService.instance;
    if (!progress.isLoaded && !progress.loading) {
      progress.load().catchError((_) {});
    }
    try {
      await _catalog.load();
    } catch (error) {
      if (!mounted) return;
      if (_catalog.isLoaded) {
        // A lista anterior continua na tela; só avisa.
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível atualizar as ações. Tente de novo.',
        );
      } else {
        _loadError =
            error is ApiException
                ? error.message
                : 'Não foi possível carregar as ações. Tente de novo.';
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNow = false);
      } else {
        _loadingNow = false;
      }
    }
  }

  void _selectCategory(String? label) {
    setState(() => _selectedCategory = label);
    if (label == _cleanCategory(widget.initialCategory)) return;
    // O endereço acompanha o filtro. Sem isso, abrir de novo o mesmo
    // `/acoes?categoria=…` a partir de outra tela não reaplicaria a categoria.
    GoRouter.maybeOf(context)?.go(
      Uri(
        path: '/acoes',
        queryParameters: label == null ? null : {'categoria': label},
      ).toString(),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearFilters() {
    _clearSearch();
    _selectCategory(null);
  }

  /// A categoria escolhida, se ela existir no catálogo.
  ActionCategory? _resolveCategory(List<ActionCategory> categories) {
    final wanted = _selectedCategory;
    if (wanted == null) return null;
    final key = _normalize(wanted);
    for (final category in categories) {
      if (_normalize(category.label) == key || _normalize(category.id) == key) {
        return category;
      }
    }
    return null;
  }

  List<EcoAction> _visibleActions(ActionCategory? category) {
    final query = _normalize(_searchQuery.trim());
    final all = _catalog.actions;
    final order = {for (var i = 0; i < all.length; i++) all[i].id: i};
    final items =
        all.where((action) {
          if (category != null && action.category != category.id) return false;
          if (query.isEmpty) return true;
          return _normalize(action.title).contains(query) ||
              _normalize(action.description).contains(query) ||
              action.tags.any((tag) => _normalize(tag).contains(query));
        }).toList();

    int byCatalogOrder(EcoAction a, EcoAction b) =>
        (order[a.id] ?? 0).compareTo(order[b.id] ?? 0);

    switch (_sortMode) {
      case _SortMode.relevance:
        break;
      case _SortMode.points:
        items.sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          return byPoints != 0 ? byPoints : byCatalogOrder(a, b);
        });
      case _SortMode.alphabetical:
        items.sort((a, b) {
          final byTitle = _normalize(a.title).compareTo(_normalize(b.title));
          return byTitle != 0 ? byTitle : byCatalogOrder(a, b);
        });
    }
    return items;
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      // Por cima da barra de abas, e não só da área desta aba.
      useRootNavigator: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Ordenar ações',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
                for (final mode in _SortMode.values)
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: mode == _sortMode,
                    child: ListTile(
                      leading: Icon(
                        mode == _sortMode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.brandDarkAccent,
                      ),
                      title: Text(
                        mode.title,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight:
                              mode == _sortMode
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        mode.subtitle,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        setState(() => _sortMode = mode);
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.eco,
        title: 'Ações Sustentáveis',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandDarkAccent,
          onRefresh: _load,
          child: ListenableBuilder(
            listenable: _catalog,
            builder: (context, _) => _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final slivers = <Widget>[
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: WeeklyCapCard(compact: true),
        ),
      ),
    ];

    if (!_catalog.isLoaded) {
      slivers.add(
        SliverFillRemaining(hasScrollBody: false, child: _buildUnloaded()),
      );
    } else if (_catalog.actions.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.eco_outlined,
            title: 'Nenhuma ação disponível',
            message: 'O catálogo de ações está vazio no momento.',
            actionLabel: 'Atualizar',
            onAction: _load,
          ),
        ),
      );
    } else {
      final categories = _catalog.categories;
      final selected = _resolveCategory(categories);
      final visible = _visibleActions(selected);

      slivers
        ..add(SliverToBoxAdapter(child: _buildSearchRow()))
        ..add(SliverToBoxAdapter(child: _buildCategoryChips(categories, selected)))
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _countLabel(visible.length, selected),
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        );

      if (visible.isEmpty) {
        slivers.add(
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(
              icon: Icons.search_off,
              title: 'Nenhuma ação encontrada',
              message: 'Tente outros termos ou outra categoria.',
              actionLabel: 'Limpar filtros',
              onAction: _clearFilters,
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final action = visible[index];
                return _ActionCard(
                  key: ValueKey<int>(action.id),
                  action: action,
                  onRegister: () => context.push('/registro-acao/${action.id}'),
                );
              },
            ),
          ),
        );
      }
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );
  }

  Widget _buildUnloaded() {
    final message = _catalog.error ?? _loadError;
    if (message == null && (_catalog.loading || _loadingNow)) {
      return const LoadingView(message: 'Carregando ações…');
    }
    return LoadErrorView(
      message: message ?? 'Não foi possível carregar as ações.',
      onRetry: _load,
    );
  }

  String _countLabel(int count, ActionCategory? category) {
    final buffer = StringBuffer(count == 1 ? '1 ação' : '$count ações');
    if (category != null) buffer.write(' em ${category.label}');
    if (_sortMode != _SortMode.relevance) {
      buffer.write(' · ${_sortMode.title.toLowerCase()}');
    }
    return buffer.toString();
  }

  Widget _buildSearchRow() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar ação',
                hintStyle: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.brandTextSecondary,
                ),
                suffixIcon:
                    _searchQuery.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.brandTextSecondary,
                          ),
                          onPressed: _clearSearch,
                        ),
                filled: true,
                fillColor: AppColors.brandSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: border(AppColors.brandBorder),
                enabledBorder: border(AppColors.brandBorder),
                focusedBorder: border(AppColors.brandDarkAccent, 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ordenar ações',
            onPressed: _showSortSheet,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brandSurface,
              foregroundColor: AppColors.brandDarkAccent,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.brandBorder),
              ),
            ),
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(
    List<ActionCategory> categories,
    ActionCategory? selected,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _CategoryChip(
            label: 'Todas',
            icon: Icons.apps,
            selected: selected == null,
            onTap: () => _selectCategory(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.label,
              icon: category.icon,
              selected: selected?.id == category.id,
              onTap: () => _selectCategory(category.label),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background =
        selected ? AppColors.brandDarkAccent : AppColors.brandSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.brandDarkAccent : AppColors.brandBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.brandDarkAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.labelLg.copyWith(
                      color:
                          selected ? Colors.white : AppColors.brandTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.action,
    required this.onRegister,
  });

  final EcoAction action;
  final VoidCallback onRegister;

  /// "1 de 2 hoje" ou "0 de 1 nesta semana"; `null` se a ação não tem limite.
  String? get _usageLabel {
    final daily = action.dailyLimit;
    final weekly = action.weeklyLimit;
    if (weekly != null && (daily == null || action.usedThisWeek >= weekly)) {
      return '${action.usedThisWeek} de $weekly nesta semana';
    }
    if (daily != null) return '${action.usedToday} de $daily hoje';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final info = action.info ?? '';
    final footer = action.footerInfo ?? '';
    final limit = action.limitLabel;
    final usage = _usageLabel;
    final meta = <Widget>[
      if (action.liters > 0)
        _MetaChip(
          icon: Icons.water_drop_outlined,
          label: '${action.liters} L por registro',
        ),
      if (limit != null) _MetaChip(icon: Icons.event_repeat, label: limit),
      if (usage != null) _MetaChip(icon: Icons.task_alt, label: usage),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    action.icon,
                    color: AppColors.brandDarkAccent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSecondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            action.categoryLabel,
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.brandDarkAccent,
                            ),
                          ),
                        ),
                        if (info.isNotEmpty)
                          _IconText(
                            icon: action.infoIcon ?? Icons.info_outline,
                            text: info,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.title,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    if (action.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.description,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${action.points} pts',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: meta),
          ],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 10),
            _IconText(
              icon: action.footerIcon ?? Icons.eco,
              text: footer,
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child:
                action.canRegister
                    ? FilledButton.icon(
                      onPressed: onRegister,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Registrar'),
                    )
                    : FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(action.blockedLabel ?? 'Indisponível agora'),
                    ),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.maxLines = 2});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.brandTextSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandTextSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
