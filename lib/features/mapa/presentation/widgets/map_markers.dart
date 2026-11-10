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

/// Alvo de toque dos marcadores do mapa.
///
/// Faz o papel de um `IconButton` (área de toque de 48 e rótulo para leitor
/// de tela), sem o efeito de tinta nem a dica flutuante. Dezenas de marcadores
/// entram e saem da tela enquanto o mapa é arrastado, e montar um botão
/// completo para cada um custava quadros.
class MapMarkerButton extends StatelessWidget {
  const MapMarkerButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.size = kMapMarkerSize,
  });

  /// Texto lido pelo leitor de tela.
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// Lado da área de toque.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );
  }
}

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
    return MapMarkerButton(
      label: 'Ponto de coleta: ${point.name}',
      onPressed: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorForPoint(point),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          // Anel sólido em vez de sombra desfocada: o desfoque é refeito a
          // cada quadro enquanto o mapa se move, e são dezenas de marcadores.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              spreadRadius: 1.5,
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
    return MapMarkerButton(
      label: 'Vizinho: ${neighbor.name}',
      onPressed: onPressed,
      child: Container(
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
    return Semantics(
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
    );
  }
}

/// Rótulos dos bairros, só a partir do zoom 13.
///
/// Para não poluir, fica no máximo um rótulo por célula de uma grade fixa no
/// mapa. A escolha é feita uma vez por nível de zoom inteiro e vale para a
/// cidade toda, então os rótulos não "piscam" nem são recalculados enquanto o
/// mapa é arrastado; a camada de marcadores só desenha os da área visível.
class NeighborhoodLabelsLayer extends StatefulWidget {
  const NeighborhoodLabelsLayer({super.key, this.minZoom = 13});

  final double minZoom;

  @override
  State<NeighborhoodLabelsLayer> createState() =>
      _NeighborhoodLabelsLayerState();
}

class _NeighborhoodLabelsLayerState extends State<NeighborhoodLabelsLayer> {
  static const double _cellWidth = 130;
  static const double _cellHeight = 40;

  /// Posição de cada bairro, calculada uma vez (e não a cada quadro).
  static final List<LatLng> _positions = List.unmodifiable([
    for (final item in neighborhoodsData) LatLng(item.lat, item.lon),
  ]);

  /// Marcadores criados sob demanda e reaproveitados entre quadros.
  final Map<int, Marker> _markers = {};

  Marker _marker(int index) => _markers.putIfAbsent(index, () {
    return Marker(
      key: ValueKey('bairro-$index'),
      point: _positions[index],
      width: 120,
      height: 36,
      child: _LabelText(neighborhoodsData[index].name),
    );
  });

  /// Camada pronta de cada nível de zoom inteiro. Como a instância não muda
  /// entre quadros, a camada de marcadores mantém as projeções em cache.
  final Map<int, Widget> _layers = {};

  Widget _layerFor(MapCamera camera, int zoom) => _layers.putIfAbsent(zoom, () {
    final taken = <(int, int)>{};
    final markers = <Marker>[];
    for (var i = 0; i < _positions.length; i++) {
      final pixel = camera.projectAtZoom(_positions[i], zoom.toDouble());
      final cell = (
        (pixel.dx / _cellWidth).floor(),
        (pixel.dy / _cellHeight).floor(),
      );
      if (!taken.add(cell)) continue;
      markers.add(_marker(i));
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: MarkerLayer(markers: List.unmodifiable(markers)),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (camera.zoom < widget.minZoom) return const SizedBox.shrink();
    return _layerFor(camera, camera.zoom.floor());
  }
}

/// Nome de bairro com contorno claro, para ler por cima das vias.
///
/// O contorno é o próprio texto traçado por baixo (sem desfoque). A sombra
/// desfocada que havia aqui era refeita a cada quadro em até 40 rótulos e
/// pesava ao arrastar o mapa.
class _LabelText extends StatelessWidget {
  const _LabelText(this.text);

  final String text;

  static final TextStyle _fill = AppTextStyles.labelSm.copyWith(
    fontSize: 11,
    height: 1.15,
    color: AppColors.brandTextSecondary,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle _halo = AppTextStyles.labelSm.copyWith(
    fontSize: 11,
    height: 1.15,
    fontWeight: FontWeight.w600,
    foreground:
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xE6FFFFFF),
  );

  @override
  Widget build(BuildContext context) {
    Widget line(TextStyle style) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [line(_halo), line(_fill)],
      ),
    );
  }
}
