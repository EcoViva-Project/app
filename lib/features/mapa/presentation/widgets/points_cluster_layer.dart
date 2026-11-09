import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'map_markers.dart';
import 'point_types.dart';

/// Pontos de coleta no mapa, agrupados por proximidade.
///
/// Os pontos que caem na mesma célula de uma grade fixa no mapa viram um
/// círculo com a contagem. Abaixo de [clusterUntilZoom] a célula tem
/// [cellSize]; a partir dele, [closeCellSize], que ainda junta pontos no
/// mesmo endereço (coordenadas idênticas, como lojas de um shopping). Só
/// entram na tela os marcadores da área visível, e os grupos são calculados
/// uma vez por nível de zoom inteiro, não a cada quadro.
class PointsClusterLayer extends StatefulWidget {
  const PointsClusterLayer({
    super.key,
    required this.points,
    required this.onPointPressed,
    required this.onClusterPressed,
    this.clusterUntilZoom = 16,
    this.cellSize = 64,
    this.closeCellSize = 28,
  });

  /// Pontos já filtrados e com coordenada.
  final List<CollectionPoint> points;
  final ValueChanged<CollectionPoint> onPointPressed;

  /// Recebe o centro e os pontos do grupo, para aproximar o mapa ou, se o
  /// grupo não se separa mais, listar os pontos do local.
  final void Function(LatLng center, List<CollectionPoint> points)
  onClusterPressed;
  final double clusterUntilZoom;
  final double cellSize;
  final double closeCellSize;

  @override
  State<PointsClusterLayer> createState() => _PointsClusterLayerState();
}

class _Cluster {
  _Cluster(this.key);

  final String key;
  final List<CollectionPoint> points = [];
  late final LatLng center;
}

class _PointsClusterLayerState extends State<PointsClusterLayer> {
  /// Grupos por nível de zoom inteiro.
  final Map<int, List<_Cluster>> _clustersByZoom = {};

  /// Marcadores reaproveitados entre quadros.
  final Map<int, Marker> _pointMarkers = {};
  final Map<String, Marker> _clusterMarkers = {};

  @override
  void didUpdateWidget(PointsClusterLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) {
      _clustersByZoom.clear();
      _clusterMarkers.clear();
    }
    if (oldWidget.onPointPressed != widget.onPointPressed) {
      _pointMarkers.clear();
    }
  }

  List<_Cluster> _clustersFor(MapCamera camera, int zoom) =>
      _clustersByZoom.putIfAbsent(zoom, () {
        final cells = <(int, int), _Cluster>{};
        final size =
            zoom >= widget.clusterUntilZoom
                ? widget.closeCellSize
                : widget.cellSize;
        for (final point in widget.points) {
          final position = LatLng(point.lat!, point.lon!);
          final pixel = camera.projectAtZoom(position, zoom.toDouble());
          final cell = ((pixel.dx / size).floor(), (pixel.dy / size).floor());
          cells
              .putIfAbsent(cell, () => _Cluster('$zoom-${cell.$1}-${cell.$2}'))
              .points
              .add(point);
        }
        for (final cluster in cells.values) {
          var lat = 0.0;
          var lon = 0.0;
          for (final point in cluster.points) {
            lat += point.lat!;
            lon += point.lon!;
          }
          cluster.center = LatLng(
            lat / cluster.points.length,
            lon / cluster.points.length,
          );
        }
        return cells.values.toList(growable: false);
      });

  Marker _pointMarker(CollectionPoint point) => _pointMarkers.putIfAbsent(
    point.id,
    () => Marker(
      key: ValueKey('mapa-ponto-${point.id}'),
      point: LatLng(point.lat!, point.lon!),
      width: kMapMarkerSize,
      height: kMapMarkerSize,
      child: CollectionPointMarker(
        point: point,
        onPressed: () => widget.onPointPressed(point),
      ),
    ),
  );

  Marker _clusterMarker(_Cluster cluster) =>
      _clusterMarkers.putIfAbsent(cluster.key, () {
        final families = {
          for (final point in cluster.points) familyForType(point.type),
        };
        final color =
            families.length == 1
                ? families.first.color
                : AppColors.brandDarkAccent;
        return Marker(
          key: ValueKey('mapa-grupo-${cluster.key}'),
          point: cluster.center,
          width: 56,
          height: 56,
          child: ClusterMarker(
            count: cluster.points.length,
            color: color,
            samePlace: cluster.points.every(
              (p) =>
                  p.lat == cluster.points.first.lat &&
                  p.lon == cluster.points.first.lon,
            ),
            onPressed:
                () => widget.onClusterPressed(
                  cluster.center,
                  List.unmodifiable(cluster.points),
                ),
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    // Margem para os marcadores não "nascerem" na borda ao arrastar.
    final latPad = (bounds.north - bounds.south) * 0.15;
    final lonPad = (bounds.east - bounds.west) * 0.15;
    bool visible(LatLng p) =>
        p.latitude >= bounds.south - latPad &&
        p.latitude <= bounds.north + latPad &&
        p.longitude >= bounds.west - lonPad &&
        p.longitude <= bounds.east + lonPad;

    final markers = <Marker>[];
    for (final cluster in _clustersFor(camera, camera.zoom.floor())) {
      if (!visible(cluster.center)) continue;
      markers.add(
        cluster.points.length == 1
            ? _pointMarker(cluster.points.first)
            : _clusterMarker(cluster),
      );
    }
    return MarkerLayer(markers: markers);
  }
}

/// Círculo com a quantidade de pontos agrupados.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    super.key,
    required this.count,
    required this.color,
    required this.onPressed,
    this.samePlace = false,
  });

  final int count;
  final Color color;
  final VoidCallback onPressed;

  /// Todos no mesmo endereço: tocar lista os pontos em vez de aproximar.
  final bool samePlace;

  @override
  Widget build(BuildContext context) {
    final size = count >= 50 ? 50.0 : (count >= 10 ? 44.0 : 38.0);
    return IconButton(
      tooltip:
          samePlace
              ? '$count pontos de coleta neste local. Toque para ver a lista.'
              : '$count pontos de coleta aqui. Toque para aproximar.',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 56, height: 56),
      icon: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 4),
          ],
        ),
        child: Text(
          '$count',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.labelLg.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
