import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/local/data/neighborhoods_data.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'point_types.dart';

/// Tamanho de toque dos marcadores.
const double kMapMarkerSize = 48;

/// Marcador de ponto de coleta: botão verde-escuro com o ícone do tipo.
class CollectionPointMarker extends StatelessWidget {
  const CollectionPointMarker({
    super.key,
    required this.point,
    required this.onPressed,
  });

  final CollectionPoint point;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ponto de coleta: ${point.name}',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: kMapMarkerSize,
        height: kMapMarkerSize,
      ),
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorForPoint(point),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(point.icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Marcador de vizinho: círculo claro com as iniciais.
class NeighborMarker extends StatelessWidget {
  const NeighborMarker({
    super.key,
    required this.neighbor,
    required this.onPressed,
  });

  final MapNeighbor neighbor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Vizinho: ${neighbor.name}',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: kMapMarkerSize,
        height: kMapMarkerSize,
      ),
      icon: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandSecondaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brandPrimary, width: 1.5),
        ),
        child: Text(
          neighbor.initials,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.brandDarkAccent,
          ),
        ),
      ),
    );
  }
}

/// Marcador "você": círculo destacado com as iniciais da pessoa.
class MeMarker extends StatelessWidget {
  const MeMarker({super.key, required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Você, na região do seu bairro',
      child: Semantics(
        label: 'Você, na região do seu bairro',
        excludeSemantics: true,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTertiaryAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandDarkAccent.withValues(alpha: 0.45),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Text(
              initials,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulos dos bairros, só a partir do zoom 13 e só os da área visível.
///
/// Para não poluir nem pesar, guarda no máximo um rótulo por célula de uma
/// grade fixa no mapa (que não "pisca" ao arrastar) e no máximo [maxLabels].
class NeighborhoodLabelsLayer extends StatefulWidget {
  const NeighborhoodLabelsLayer({
    super.key,
    this.minZoom = 13,
    this.maxLabels = 40,
  });

  final double minZoom;
  final int maxLabels;

  @override
  State<NeighborhoodLabelsLayer> createState() =>
      _NeighborhoodLabelsLayerState();
}

class _NeighborhoodLabelsLayerState extends State<NeighborhoodLabelsLayer> {
  static const double _cellWidth = 130;
  static const double _cellHeight = 40;

  /// Marcadores criados sob demanda e reaproveitados entre quadros.
  final Map<int, Marker> _markers = {};

  Marker _marker(int index) => _markers.putIfAbsent(index, () {
    final item = neighborhoodsData[index];
    return Marker(
      key: ValueKey('bairro-$index'),
      point: LatLng(item.lat, item.lon),
      width: 120,
      height: 36,
      child: _LabelText(item.name),
    );
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (camera.zoom < widget.minZoom) return const SizedBox.shrink();

    final bounds = camera.visibleBounds;
    final taken = <(int, int)>{};
    final markers = <Marker>[];
    for (var i = 0; i < neighborhoodsData.length; i++) {
      final item = neighborhoodsData[i];
      final point = LatLng(item.lat, item.lon);
      if (!bounds.contains(point)) continue;
      final pixel = camera.projectAtZoom(point);
      final cell = (
        (pixel.dx / _cellWidth).floor(),
        (pixel.dy / _cellHeight).floor(),
      );
      if (!taken.add(cell)) continue;
      markers.add(_marker(i));
      if (markers.length >= widget.maxLabels) break;
    }
    return IgnorePointer(
      child: ExcludeSemantics(child: MarkerLayer(markers: markers)),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSm.copyWith(
          fontSize: 11,
          height: 1.15,
          color: AppColors.brandTextSecondary,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Colors.white, blurRadius: 3),
            Shadow(color: Colors.white, blurRadius: 1),
          ],
        ),
      ),
    );
  }
}
