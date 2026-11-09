import 'package:flutter/material.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'collection_points_section.dart';
import 'community_section.dart';

/// Abre a folha com todos os dados de um ponto de coleta.
Future<void> showCollectionPointDetails(
  BuildContext context,
  CollectionPoint point,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder:
              (context, controller) =>
                  _PointDetails(point: point, controller: controller),
        ),
  );
}

/// Abre a folha com a lista completa e a busca.
Future<void> showAllCollectionPoints(
  BuildContext context,
  List<CollectionPoint> points,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder:
              (context, controller) =>
                  _AllPoints(points: points, controller: controller),
        ),
  );
}

class _PointDetails extends StatelessWidget {
  const _PointDetails({required this.point, required this.controller});

  final CollectionPoint point;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final distance = point.distanceLabel;
    final place = collectionPointPlace(point);
    final hours = point.hours?.trim() ?? '';
    final phone = point.phone?.trim() ?? '';
    final responsible = point.responsible?.trim() ?? '';
    final notes = point.notes?.trim() ?? '';
    final confirmed = point.isConfirmed;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommunityIconBadge(icon: point.icon, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      point.name,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    point.typeLabel,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandDarkAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.brandTextPrimary),
            ),
          ],
        ),
        if (!confirmed) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandTertiaryAccent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CommunityDetailLine(
              icon: Icons.info_outline,
              label: 'Aviso',
              text: 'Informação a confirmar no local',
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (distance != null)
          _DetailBlock(
            icon: Icons.near_me_outlined,
            label: 'Distância',
            text: distance,
          ),
        if (place.isNotEmpty)
          _DetailBlock(
            icon: Icons.location_on_outlined,
            label: 'Endereço',
            text: place,
          ),
        if (hours.isNotEmpty)
          _DetailBlock(icon: Icons.schedule, label: 'Horário', text: hours),
        if (phone.isNotEmpty)
          _DetailBlock(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            text: phone,
          ),
        if (responsible.isNotEmpty)
          _DetailBlock(
            icon: Icons.badge_outlined,
            label: 'Responsável',
            text: responsible,
          ),
        if (point.materials.isNotEmpty) ...[
          const _Label('Materiais aceitos'),
          const SizedBox(height: 6),
          MaterialChips(materials: point.materials),
          const SizedBox(height: 14),
        ],
        if (notes.isNotEmpty)
          _DetailBlock(icon: Icons.notes, label: 'Observações', text: notes),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMd.copyWith(color: AppColors.brandTextSecondary),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: _Label(label)),
          const SizedBox(height: 4),
          CommunityDetailLine(icon: icon, label: label, text: text),
        ],
      ),
    );
  }
}

class _AllPoints extends StatefulWidget {
  const _AllPoints({required this.points, required this.controller});

  final List<CollectionPoint> points;
  final ScrollController controller;

  @override
  State<_AllPoints> createState() => _AllPointsState();
}

class _AllPointsState extends State<_AllPoints> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Tipo escolhido nos filtros; `null` mostra todos.
  String? _type;

  /// Contagem por tipo, na ordem de [CollectionPoint.knownTypes] e depois
  /// os tipos desconhecidos.
  late final Map<String, int> _typeCounts = _countTypes(widget.points);

  /// Texto de busca de cada ponto, já normalizado (calculado uma vez).
  late final Map<CollectionPoint, String> _haystack = {
    for (final point in widget.points)
      point: _normalize(
        [
          point.name,
          point.typeLabel,
          point.neighborhood ?? '',
          point.address ?? '',
          ...point.materials,
        ].join(' '),
      ),
  };

  static Map<String, int> _countTypes(List<CollectionPoint> points) {
    final raw = <String, int>{};
    for (final point in points) {
      raw[point.type] = (raw[point.type] ?? 0) + 1;
    }
    return {
      for (final type in CollectionPoint.knownTypes)
        if (raw.containsKey(type)) type: raw[type]!,
      for (final entry in raw.entries)
        if (!CollectionPoint.knownTypes.contains(entry.key))
          entry.key: entry.value,
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CollectionPoint> get _filtered {
    final query = _normalize(_query.trim());
    if (query.isEmpty && _type == null) return widget.points;
    return [
      for (final point in widget.points)
        if ((_type == null || point.type == _type) &&
            (query.isEmpty || _haystack[point]!.contains(query)))
          point,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: CustomScrollView(
        controller: widget.controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildHeader(results.length)),
          ),
          SliverToBoxAdapter(child: _buildTypeFilter()),
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Nenhum ponto encontrado. Tente outra busca ou outro tipo.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final point = results[index];
                  return Padding(
                    key: ValueKey(point.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CollectionPointCard(
                      point: point,
                      onTap: () => showCollectionPointDetails(context, point),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int shown) {
    final total = widget.points.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Pontos de coleta',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.brandTextPrimary),
            ),
          ],
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            shown == total
                ? '$total ${plural(total, 'ponto', 'pontos')}, do mais perto '
                    'ao mais longe'
                : '$shown de $total pontos',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar por nome, bairro ou material',
            prefixIcon: const Icon(Icons.search),
            suffixIcon:
                _query.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Filtro por tipo, em etiquetas que rolam para o lado.
  Widget _buildTypeFilter() {
    Widget chip(String label, String? type) {
      final selected = _type == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.brandSecondaryContainer,
          backgroundColor: AppColors.brandSurface,
          side: BorderSide(
            color:
                selected ? AppColors.brandDarkAccent : AppColors.brandBorder,
          ),
          labelStyle: AppTextStyles.labelLg.copyWith(
            color:
                selected
                    ? AppColors.brandDarkAccent
                    : AppColors.brandTextPrimary,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) => setState(() => _type = type),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Filtrar por tipo',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(
          children: [
            chip('Todos (${widget.points.length})', null),
            for (final entry in _typeCounts.entries)
              chip(
                '${CollectionPoint.labelForType(entry.key)} (${entry.value})',
                entry.key,
              ),
          ],
        ),
      ),
    );
  }
}

/// Minúsculas e sem acentos, para a busca achar "agua" em "Água".
String _normalize(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}
