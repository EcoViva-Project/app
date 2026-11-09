import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Uma linha do mapa-base (via ou curso d'água), já convertida em [LatLng].
class BaseLine {
  const BaseLine(this.kind, this.points);

  /// Classe como veio do arquivo (`primary`, `river`...).
  final String kind;
  final List<LatLng> points;
}

/// Mapa-base offline de São José do Rio Preto, gerado dos dados do
/// OpenStreetMap (`assets/map/rio_preto.json`).
///
/// O arquivo é lido e convertido uma única vez por execução do app; a
/// conversão roda fora da linha de interface (`compute`).
class BaseMapData {
  const BaseMapData({
    required this.attribution,
    required this.bounds,
    required this.roads,
    required this.water,
    required this.lakes,
  });

  static const String assetPath = 'assets/map/rio_preto.json';

  final String attribution;

  /// Área coberta pelo arquivo; a câmera fica presa dentro dela.
  final LatLngBounds bounds;

  /// Vias, da menos para a mais importante (ordem de desenho).
  final List<BaseLine> roads;
  final List<BaseLine> water;
  final List<List<LatLng>> lakes;

  static Future<BaseMapData>? _cache;
  static BaseMapData? _loaded;

  /// Carrega o mapa-base (ou devolve o que já está em memória).
  static Future<BaseMapData> load() {
    final loaded = _loaded;
    if (loaded != null) return Future.value(loaded);
    final cached = _cache;
    if (cached != null) return cached;
    final future = rootBundle
        .loadString(assetPath)
        .then((raw) => compute(_parseBaseMap, raw))
        .then((data) => _loaded = data);
    _cache = future;
    // Se der erro, a próxima tentativa lê o arquivo de novo.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_cache, future)) _cache = null;
        },
      ),
    );
    return future;
  }
}

/// Ordem de desenho das vias: as mais importantes por cima.
const List<String> roadClassOrder = [
  'tertiary',
  'secondary',
  'primary',
  'trunk',
  'motorway',
];

BaseMapData _parseBaseMap(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;

  List<LatLng> points(Object? flat) {
    final list = flat as List? ?? const [];
    return List<LatLng>.unmodifiable([
      for (var i = 0; i + 1 < list.length; i += 2)
        LatLng((list[i] as num).toDouble(), (list[i + 1] as num).toDouble()),
    ]);
  }

  final bbox = json['bbox'] as Map<String, dynamic>? ?? const {};
  double coord(String key, double fallback) =>
      (bbox[key] as num?)?.toDouble() ?? fallback;

  final roads = <BaseLine>[];
  for (final item in (json['roads'] as List?) ?? const []) {
    final map = item as Map<String, dynamic>;
    final kind = map['c'] as String? ?? '';
    if (!roadClassOrder.contains(kind)) continue;
    final line = points(map['p']);
    if (line.length >= 2) roads.add(BaseLine(kind, line));
  }
  roads.sort(
    (a, b) => roadClassOrder
        .indexOf(a.kind)
        .compareTo(roadClassOrder.indexOf(b.kind)),
  );

  return BaseMapData(
    attribution:
        json['attribution'] as String? ?? '© colaboradores do OpenStreetMap',
    bounds: LatLngBounds(
      LatLng(coord('south', -20.93), coord('west', -49.5)),
      LatLng(coord('north', -20.7), coord('east', -49.28)),
    ),
    roads: List.unmodifiable(roads),
    water: List.unmodifiable([
      for (final item in (json['water'] as List?) ?? const [])
        if (points((item as Map<String, dynamic>)['p']) case final line
            when line.length >= 2)
          BaseLine(item['c'] as String? ?? '', line),
    ]),
    lakes: List.unmodifiable([
      for (final item in (json['lakes'] as List?) ?? const [])
        if (points((item as Map<String, dynamic>)['p']) case final ring
            when ring.length >= 3)
          ring,
    ]),
  );
}

/// Cores do mapa-base.
abstract final class BaseMapColors {
  /// Fundo: bege um pouco mais escuro que o fundo das telas.
  static const Color land = Color(0xFFEFEADF);
  static const Color lakeFill = Color(0xFFBFDCEE);
  static const Color lakeBorder = Color(0xFF8FBEDC);
  static const Color river = Color(0xFF7FB2D6);
  static const Color motorway = Color(0xFF857560);
  static const Color primary = Color(0xFFA0907A);
  static const Color secondary = Color(0xFFBBAE99);
  static const Color tertiary = Color(0xFFD2C8B7);
}

/// Espessura e cor de cada classe de via em cada faixa de zoom.
///
/// Faixas: 0 = zoom abaixo de 13 (terciárias escondidas), 1 = de 13 a 15,
/// 2 = a partir de 15.
({double width, Color color})? roadStyle(String kind, int band) {
  const widths = <String, List<double>>{
    'motorway': [3.2, 4.6, 7],
    'trunk': [3.2, 4.6, 7],
    'primary': [2.2, 3.4, 5.4],
    'secondary': [1.4, 2.4, 4],
    'tertiary': [0, 1.4, 2.8],
  };
  final width = widths[kind]?[band] ?? 0;
  if (width <= 0) return null;
  final color = switch (kind) {
    'motorway' || 'trunk' => BaseMapColors.motorway,
    'primary' => BaseMapColors.primary,
    'secondary' => BaseMapColors.secondary,
    _ => BaseMapColors.tertiary,
  };
  return (width: width, color: color);
}

/// Faixa de zoom usada por [roadStyle].
int zoomBand(double zoom) => zoom < 13 ? 0 : (zoom < 15 ? 1 : 2);

/// Camadas do mapa-base, criadas uma única vez a partir de [BaseMapData].
///
/// Os widgets são guardados e reaproveitados: como a instância não muda entre
/// reconstruções, o `PolylineLayer` mantém as projeções em cache e não refaz o
/// trabalho a cada quadro.
class BaseMapLayers {
  BaseMapLayers(this.data)
    : lakes = PolygonLayer(
        key: const ValueKey('mapa-lagos'),
        polygonLabels: false,
        polygons: [
          for (final ring in data.lakes)
            Polygon(
              points: ring,
              color: BaseMapColors.lakeFill,
              borderColor: BaseMapColors.lakeBorder,
              borderStrokeWidth: 1,
            ),
        ],
      ),
      water = PolylineLayer(
        key: const ValueKey('mapa-rios'),
        simplificationTolerance: 0.5,
        polylines: [
          for (final line in data.water)
            Polyline(
              points: line.points,
              color: BaseMapColors.river,
              strokeWidth: line.kind == 'river' ? 2.6 : 1.4,
            ),
        ],
      ),
      roadBands = List.unmodifiable([
        for (var band = 0; band < 3; band++) _roadLayer(data.roads, band),
      ]);

  final BaseMapData data;
  final Widget lakes;
  final Widget water;

  /// Uma camada de vias por faixa de zoom (ver [zoomBand]).
  final List<Widget> roadBands;

  static Widget _roadLayer(List<BaseLine> roads, int band) {
    final polylines = <Polyline>[];
    for (final road in roads) {
      final style = roadStyle(road.kind, band);
      if (style == null) continue;
      polylines.add(
        Polyline(
          points: road.points,
          color: style.color,
          strokeWidth: style.width,
        ),
      );
    }
    return PolylineLayer(
      key: ValueKey('mapa-vias-$band'),
      simplificationTolerance: 0.5,
      polylines: polylines,
    );
  }
}

/// Escolhe uma das camadas pré-montadas conforme o zoom atual.
class ZoomBandLayer extends StatelessWidget {
  const ZoomBandLayer({super.key, required this.bands});

  final List<Widget> bands;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    return bands[zoomBand(zoom).clamp(0, bands.length - 1)];
  }
}
