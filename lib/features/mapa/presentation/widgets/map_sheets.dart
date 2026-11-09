import 'package:flutter/material.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';
import 'point_types.dart';

/// Legenda das cores e dos marcadores do mapa.
Future<void> showMapLegendSheet(BuildContext context, {String? sourceLabel}) {
  Widget row(Widget symbol, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 40, child: Center(child: symbol)),
        const SizedBox(width: 10),
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
  );

  Widget dot(Color color, {Widget? child, Color? border}) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: border ?? Colors.white, width: 2),
    ),
    child: child,
  );

  return _showScrollableSheet(
    context,
    initialSize: 0.6,
    builder:
        (context) => [
          Semantics(
            header: true,
            child: Text(
              'Legenda',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final family in pointFamilies)
            row(
              ExcludeSemantics(
                child: dot(
                  family.color,
                  child: Icon(family.icon, size: 16, color: Colors.white),
                ),
              ),
              family.label,
            ),
          row(
            ExcludeSemantics(
              child: dot(
                AppColors.brandDarkAccent,
                child: Text(
                  '12',
                  textScaler: TextScaler.noScaling,
                  style: AppTextStyles.labelMd.copyWith(color: Colors.white),
                ),
              ),
            ),
            'Vários pontos juntos: toque para aproximar',
          ),
          row(
            ExcludeSemantics(
              child: dot(
                AppColors.brandSecondaryContainer,
                border: AppColors.brandPrimary,
              ),
            ),
            'Vizinhos, na região do bairro',
          ),
          row(
            ExcludeSemantics(
              child: dot(
                AppColors.brandTertiaryAccent,
                border: AppColors.brandDarkAccent,
              ),
            ),
            'Você, na região do seu bairro',
          ),
          if (sourceLabel != null) ...[
            const SizedBox(height: 8),
            SourceNote(text: sourceLabel),
          ],
        ],
  );
}

/// Aviso discreto sobre a origem dos pontos de coleta.
class SourceNote extends StatelessWidget {
  const SourceNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.fact_check_outlined,
            size: 16,
            color: AppColors.brandTextSecondary,
          ),
        ),
        const SizedBox(width: 6),
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
}

/// Pontos de coleta no mesmo local (por exemplo, lojas de um shopping), que
/// não se separam no mapa nem no zoom máximo.
Future<void> showPlacePointsSheet(
  BuildContext context, {
  required List<CollectionPoint> points,
}) {
  final sorted = [...points]..sort((a, b) => a.name.compareTo(b.name));
  final address = nonEmpty(sorted.first.address);
  return _showScrollableSheet(
    context,
    initialSize: 0.6,
    builder:
        (sheetContext) => [
          Semantics(
            header: true,
            child: Text(
              '${sorted.length} pontos de coleta neste local',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
          if (address != null && sorted.every((p) => p.address == address))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                address,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final point in sorted)
            _PointTile(
              point: point,
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCollectionPointSheet(context, point);
              },
            ),
        ],
  );
}

/// Abre uma folha inferior rolável com o conteúdo de [builder].
Future<void> _showScrollableSheet(
  BuildContext context, {
  required List<Widget> Function(BuildContext context) builder,
  double initialSize = 0.55,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder:
              (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: builder(context),
              ),
        ),
  );
}

/// Detalhes de um ponto de coleta.
Future<void> showCollectionPointSheet(
  BuildContext context,
  CollectionPoint point,
) {
  return _showScrollableSheet(
    context,
    builder:
        (context) => [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorForPoint(point),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(point.icon, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point.typeLabel,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    if (point.distanceLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        point.distanceLabel!,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandDarkAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (point.materials.any((m) => nonEmpty(m) != null)) ...[
            const SizedBox(height: 16),
            Text(
              'Materiais aceitos',
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final material in point.materials)
                  if (nonEmpty(material) != null)
                    Chip(
                      label: Text(material),
                      labelStyle: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
                      ),
                      backgroundColor: AppColors.brandSecondaryContainer,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Campos sem informação (nulos ou vazios) não aparecem.
          for (final (icon, label, value) in [
            (Icons.location_on_outlined, 'Endereço', point.address),
            (Icons.holiday_village_outlined, 'Bairro', point.neighborhood),
            (Icons.schedule, 'Horário', point.hours),
            (Icons.phone_outlined, 'Telefone', point.phone),
            (Icons.notes, 'Observações', point.notes),
          ])
            if (nonEmpty(value) case final text?)
              SheetDetail(icon: icon, label: label, text: text),
          if (!point.isConfirmed)
            const SheetDetail(
              icon: Icons.info_outline,
              label: 'Aviso',
              text: 'Informação a confirmar no local',
            ),
        ],
  );
}

/// Detalhes de um vizinho (sempre em posição aproximada).
Future<void> showNeighborSheet(BuildContext context, MapNeighbor neighbor) {
  return _showScrollableSheet(
    context,
    initialSize: 0.4,
    builder:
        (context) => [
          Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.brandSecondaryContainer,
                  child: Text(
                    neighbor.initials,
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      neighbor.name,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    if (nonEmpty(neighbor.neighborhood) case final place?)
                      Text(
                        place,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SheetDetail(
            icon: Icons.eco_outlined,
            label: 'Pontos',
            text:
                neighbor.weeklyPoints == 1
                    ? '1 pt nesta semana'
                    : '${neighbor.weeklyPoints} pts nesta semana',
          ),
          const SheetDetail(
            icon: Icons.blur_circular,
            label: 'Aviso',
            text: 'Posição aproximada: a região do bairro, nunca o endereço.',
          ),
        ],
  );
}

/// Pontos de coleta em lista, do mais perto ao mais longe (alternativa ao
/// mapa para quem usa leitor de tela).
Future<void> showCollectionPointsListSheet(
  BuildContext context, {
  required List<CollectionPoint> points,
  required void Function(CollectionPoint point) onSelect,
  String? sourceLabel,
}) {
  final sorted = sortByDistance(points);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder:
              (context, controller) => _PointsListSheet(
                controller: controller,
                points: sorted,
                sourceLabel: sourceLabel,
                onSelect: (point) {
                  Navigator.of(sheetContext).pop();
                  onSelect(point);
                },
              ),
        ),
  );
}

class _PointsListSheet extends StatefulWidget {
  const _PointsListSheet({
    required this.controller,
    required this.points,
    required this.onSelect,
    this.sourceLabel,
  });

  final ScrollController controller;
  final String? sourceLabel;

  /// Já ordenados do mais perto ao mais longe.
  final List<CollectionPoint> points;
  final ValueChanged<CollectionPoint> onSelect;

  @override
  State<_PointsListSheet> createState() => _PointsListSheetState();
}

class _PointsListSheetState extends State<_PointsListSheet> {
  late final List<String> _searchText = [
    for (final point in widget.points)
      normalizeForSearch(
        [
          point.name,
          point.typeLabel,
          point.address ?? '',
          point.neighborhood ?? '',
          ...point.materials,
        ].join(' '),
      ),
  ];
  late List<CollectionPoint> _filtered = widget.points;
  String _query = '';

  void _search(String value) {
    final query = normalizeForSearch(value.trim());
    if (query == _query) return;
    setState(() {
      _query = query;
      _filtered =
          query.isEmpty
              ? widget.points
              : [
                for (var i = 0; i < widget.points.length; i++)
                  if (_searchText[i].contains(query)) widget.points[i],
              ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Pontos de coleta (${widget.points.length})',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Do mais perto ao mais longe da região do seu bairro.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                if (widget.sourceLabel != null) ...[
                  const SizedBox(height: 6),
                  SourceNote(text: widget.sourceLabel!),
                ],
                const SizedBox(height: 10),
                TextField(
                  onChanged: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, bairro ou material',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.brandBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.brandBorder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.points.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyStateView(
              icon: Icons.recycling,
              title: 'Ainda não há pontos de coleta cadastrados.',
            ),
          )
        else if (_filtered.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyStateView(
              icon: Icons.search_off,
              title: 'Nenhum ponto encontrado.',
              message: 'Tente outro nome, bairro ou material.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.builder(
              itemCount: _filtered.length,
              itemBuilder:
                  (context, index) => _PointTile(
                    point: _filtered[index],
                    onTap: () => widget.onSelect(_filtered[index]),
                  ),
            ),
          ),
      ],
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.point, required this.onTap});

  final CollectionPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('lista-ponto-${point.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: ExcludeSemantics(
        child: CircleAvatar(
          backgroundColor: colorForPoint(point),
          child: Icon(point.icon, color: Colors.white, size: 20),
        ),
      ),
      title: Text(
        point.name,
        style: AppTextStyles.labelLg.copyWith(
          color: AppColors.brandTextPrimary,
        ),
      ),
      subtitle: Text(
        [
          point.typeLabel,
          if (nonEmpty(point.distanceLabel) case final distance?) distance,
          if (nonEmpty(point.neighborhood) case final place?) place,
        ].join(' · '),
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.brandTextSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// Pontos ordenados pela distância (sem coordenada vão para o fim).
List<CollectionPoint> sortByDistance(List<CollectionPoint> points) {
  final sorted = [...points];
  sorted.sort((a, b) {
    final first = a.distanceMeters;
    final second = b.distanceMeters;
    if (first == null && second == null) return a.name.compareTo(b.name);
    if (first == null) return 1;
    if (second == null) return -1;
    return first.compareTo(second);
  });
  return sorted;
}

/// Linha de detalhe com ícone, lida inteira pelo leitor de tela.
class SheetDetail extends StatelessWidget {
  const SheetDetail({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.brandDarkAccent),
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
    );
  }
}
