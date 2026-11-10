import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';
import 'collection_point_sheets.dart';
import 'community_section.dart';

/// Quantos pontos aparecem direto na tela; o resto fica em "Ver todos".
const int collectionPointsPreview = 3;

/// Pontos de coleta mais próximos, vindos do levantamento da API.
class CollectionPointsSection extends StatelessWidget {
  const CollectionPointsSection({super.key, required this.points});

  /// Já vêm do mais perto ao mais longe.
  final List<CollectionPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return CommunityCard(
        child: EmptyStateView(
          icon: Icons.recycling,
          title: 'Pontos de coleta em levantamento',
          message:
              'Estamos reunindo os ecopontos e cooperativas da cidade. '
              'Enquanto isso, veja quem participa perto de você.',
          actionLabel: 'Ver mapa da comunidade',
          onAction: () => context.push('/mapa'),
          padding: 8,
        ),
      );
    }

    final nearest = pickNearestVaried(points, collectionPointsPreview);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final point in nearest)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CollectionPointCard(
              point: point,
              onTap: () => showCollectionPointDetails(context, point),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => showAllCollectionPoints(context, points),
              icon: const Icon(Icons.list_alt),
              label: Text('Ver todos (${points.length})'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/mapa'),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver no mapa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          NeighborhoodService.instance.distancesFromMyPosition
              ? 'As distâncias são medidas a partir da sua localização.'
              : 'As distâncias são medidas a partir da região do seu bairro.',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        if (NeighborhoodService.sourceLabelFor(points) case final source?) ...[
          const SizedBox(height: 4),
          Text(
            source,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Cartão resumido de um ponto de coleta; tocar abre os detalhes.
class CollectionPointCard extends StatelessWidget {
  const CollectionPointCard({
    super.key,
    required this.point,
    required this.onTap,
  });

  final CollectionPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = point.distanceLabel;
    final place = collectionPointPlace(point);

    return Material(
      color: AppColors.brandSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          hint: 'Abre os detalhes do ponto de coleta',
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunityIconBadge(icon: point.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      Text(
                        distance == null
                            ? point.typeLabel
                            : '${point.typeLabel} · $distance',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandDarkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (point.materials.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        MaterialChips(materials: point.materials, max: 3),
                      ],
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        CommunityDetailLine(
                          icon: Icons.location_on_outlined,
                          label: 'Endereço',
                          text: place,
                        ),
                      ],
                      if ((point.hours ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        CommunityDetailLine(
                          icon: Icons.schedule,
                          label: 'Horário',
                          text: point.hours!.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Materiais aceitos, em etiquetas que quebram linha.
class MaterialChips extends StatelessWidget {
  const MaterialChips({super.key, required this.materials, this.max});

  final List<String> materials;

  /// Mostra no máximo [max] e um "+N" com o resto.
  final int? max;

  @override
  Widget build(BuildContext context) {
    final limit = max ?? materials.length;
    final shown = materials.take(limit).toList();
    final hidden = materials.length - shown.length;

    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMd.copyWith(color: AppColors.brandDarkAccent),
      ),
    );

    return Semantics(
      label: 'Materiais: ${materials.join(', ')}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final material in shown) chip(material),
          if (hidden > 0) chip('+$hidden'),
        ],
      ),
    );
  }
}

/// Tipos que abrem a lista da tela principal: recebem vários materiais.
const _generalTypes = {'ecoponto_municipal', 'entrega_voluntaria'};

/// Escolhe até [count] pontos próximos de tipos diferentes, começando pelo
/// ecoponto ou ponto de entrega voluntária mais perto, para a lista não virar
/// três farmácias. Devolve do mais perto ao mais longe.
///
/// [points] já vem do mais perto ao mais longe.
List<CollectionPoint> pickNearestVaried(
  List<CollectionPoint> points,
  int count,
) {
  final chosen = <CollectionPoint>[];
  final types = <String>{};
  void take(CollectionPoint point) {
    chosen.add(point);
    types.add(point.type);
  }

  final general = points.where((p) => _generalTypes.contains(p.type));
  if (general.isNotEmpty) take(general.first);
  for (final point in points) {
    if (chosen.length >= count) break;
    if (!types.contains(point.type)) take(point);
  }
  // Poucos tipos: completa com os mais próximos que sobraram.
  for (final point in points) {
    if (chosen.length >= count) break;
    if (!chosen.contains(point)) take(point);
  }
  final order = {for (var i = 0; i < points.length; i++) points[i]: i};
  chosen.sort((a, b) => order[a]!.compareTo(order[b]!));
  return chosen;
}

/// "Endereço - Bairro", com o que houver.
String collectionPointPlace(CollectionPoint point) => [
  point.address?.trim() ?? '',
  point.neighborhood?.trim() ?? '',
].where((value) => value.isNotEmpty).join(' - ');
