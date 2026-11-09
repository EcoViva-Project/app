import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/api_exception.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/base_map.dart';
import '../widgets/map_markers.dart';
import '../widgets/map_sheets.dart';
import '../widgets/point_types.dart';
import '../widgets/points_cluster_layer.dart';

/// Mapa da comunidade: pontos de coleta e vizinhos (em posição aproximada)
/// sobre um mapa-base desenhado pelo app, sem internet.
class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const double _initialZoom = 13;
  static const double _minZoom = 11;
  static const double _maxZoom = 17;

  final MapController _controller = MapController();

  bool _loading = true;
  String? _error;
  CommunityMapData? _data;
  BaseMapLayers? _layers;

  bool _showPoints = true;
  bool _showNeighbors = true;

  /// Tipos de ponto desligados no filtro.
  final Set<String> _hiddenTypes = {};

  /// Pontos com coordenada.
  List<CollectionPoint> _positioned = const [];

  /// Mostra os pontos em escolas e creches (desligado por padrão).
  bool _showSchools = false;
  int _schoolCount = 0;

  /// Pontos com coordenada, já sem os de escolas quando desligados.
  List<CollectionPoint> _basePoints = const [];

  /// Pontos com coordenada e dos tipos ligados; a lista só muda quando o
  /// filtro muda, para a camada de grupos manter o cache.
  List<CollectionPoint> _mapPoints = const [];

  /// Contagem por tipo, para os chips.
  List<({String type, int count})> _typeCounts = const [];

  /// Camadas de marcadores, montadas uma vez por carga.
  Widget? _neighborsLayer;
  Widget? _meLayer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        BaseMapData.load(),
        NeighborhoodService.instance.loadMap(),
      ]);
      if (!mounted) return;
      final base = results[0] as BaseMapData;
      final data = results[1] as CommunityMapData;
      final layers =
          identical(_layers?.data, base) ? _layers! : BaseMapLayers(base);
      setState(() {
        _layers = layers;
        _data = data;
        _buildMarkerLayers(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeLoadError(error);
        _loading = false;
      });
    }
  }

  void _applyTypeFilter() {
    _mapPoints = List.unmodifiable([
      for (final point in _basePoints)
        if (!_hiddenTypes.contains(point.type)) point,
    ]);
  }

  /// Recalcula os pontos visíveis e as contagens dos chips.
  void _applySchoolFilter() {
    _basePoints = List.unmodifiable([
      for (final point in _positioned)
        if (_showSchools || !isSchoolPoint(point)) point,
    ]);
    _typeCounts = typeCounts(_basePoints);
    _applyTypeFilter();
  }

  void _toggleSchools(bool value) {
    setState(() {
      _showSchools = value;
      _applySchoolFilter();
    });
  }

  /// "Pontos de coleta: fontes públicas consultadas em ... Confirme no local
  /// antes de levar o material."
  String? _sourceLabel(CommunityMapData data) =>
      NeighborhoodService.sourceLabelFor(data.points) ??
      NeighborhoodService.instance.pointsSourceLabel;

  /// Pontos para a lista, com o mesmo filtro de escolas do mapa.
  List<CollectionPoint> _listPoints(CommunityMapData data) => [
    for (final point in data.points)
      if (_showSchools || !isSchoolPoint(point)) point,
  ];

  void _toggleType(String type, bool visible) {
    setState(() {
      if (visible) {
        _hiddenTypes.remove(type);
      } else {
        _hiddenTypes.add(type);
      }
      _applyTypeFilter();
    });
  }

  void _openPointFromMap(CollectionPoint point) =>
      showCollectionPointSheet(context, point);

  /// Aproxima o grupo; se ele não se separa mais (mesmo endereço ou zoom
  /// máximo), abre a lista dos pontos daquele local.
  void _onClusterPressed(LatLng center, List<CollectionPoint> points) {
    final first = points.first;
    final samePlace = points.every(
      (p) => p.lat == first.lat && p.lon == first.lon,
    );
    final zoom = _controller.camera.zoom;
    if (samePlace || zoom >= _maxZoom - 0.01) {
      showPlacePointsSheet(context, points: points);
      return;
    }
    _controller.move(
      center,
      (zoom.floorToDouble() + 2).clamp(_minZoom, _maxZoom),
    );
  }

  void _buildMarkerLayers(CommunityMapData data) {
    _positioned = List.unmodifiable(data.points.where((p) => p.hasPosition));
    _schoolCount = _positioned.where(isSchoolPoint).length;
    _hiddenTypes.retainAll(_positioned.map((p) => p.type));
    _applySchoolFilter();
    _neighborsLayer = MarkerLayer(
      key: const ValueKey('mapa-vizinhos'),
      markers: [
        for (final (index, neighbor) in data.neighbors.indexed)
          Marker(
            key: ValueKey('mapa-vizinho-$index'),
            point: LatLng(neighbor.lat, neighbor.lon),
            width: kMapMarkerSize,
            height: kMapMarkerSize,
            child: NeighborMarker(
              neighbor: neighbor,
              onPressed: () => showNeighborSheet(context, neighbor),
            ),
          ),
      ],
    );
    final myLat = data.myLat;
    final myLon = data.myLon;
    _meLayer =
        myLat == null || myLon == null
            ? null
            : MarkerLayer(
              key: const ValueKey('mapa-voce'),
              markers: [
                Marker(
                  point: LatLng(myLat, myLon),
                  width: kMapMarkerSize,
                  height: kMapMarkerSize,
                  child: MeMarker(initials: AuthService.instance.userInitials),
                ),
              ],
            );
  }

  LatLng get _homePosition {
    final data = _data!;
    return LatLng(data.myLat ?? data.centerLat, data.myLon ?? data.centerLon);
  }

  /// Mantém um ponto dentro da área do mapa-base.
  LatLng _clamp(LatLng point, LatLngBounds bounds) => LatLng(
    point.latitude.clamp(bounds.south, bounds.north),
    point.longitude.clamp(bounds.west, bounds.east),
  );

  void _zoomBy(double delta) {
    final camera = _controller.camera;
    final zoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    _controller.move(camera.center, zoom.roundToDouble());
  }

  void _centerOnMe() {
    final zoom = math.max(_controller.camera.zoom, 14.0);
    _controller.move(_clamp(_homePosition, _layers!.data.bounds), zoom);
  }

  void _openPoint(CollectionPoint point) {
    if (point.hasPosition) {
      _controller.move(
        LatLng(point.lat!, point.lon!),
        math.max(_controller.camera.zoom, 14.0),
      );
    }
    showCollectionPointSheet(context, point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.map_outlined,
        title: 'Mapa',
        showBack: true,
        backFallback: '/comunidade',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data;
    final layers = _layers;
    if (data == null || layers == null) {
      if (_error != null && !_loading) {
        return LoadErrorView(message: _error!, onRetry: _load);
      }
      return const LoadingView(message: 'Carregando o mapa...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          pointsCount: _basePoints.length,
          neighborsCount: data.neighbors.length,
          showPoints: _showPoints,
          showNeighbors: _showNeighbors,
          onPointsChanged: (value) => setState(() => _showPoints = value),
          onNeighborsChanged: (value) => setState(() => _showNeighbors = value),
          onShowList:
              () => showCollectionPointsListSheet(
                context,
                points: _listPoints(data),
                onSelect: _openPoint,
                sourceLabel: _sourceLabel(data),
              ),
        ),
        if (_showPoints && (_typeCounts.isNotEmpty || _schoolCount > 0))
          _TypeFilterBar(
            counts: _typeCounts,
            hidden: _hiddenTypes,
            onChanged: _toggleType,
            schoolCount: _schoolCount,
            showSchools: _showSchools,
            onSchoolsChanged: _toggleSchools,
          ),
        Expanded(
          child: ClipRect(
            child: LayoutBuilder(
              builder:
                  (context, constraints) => Stack(
                    children: [
                      Positioned.fill(child: _buildMap(data, layers)),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _MapButton(
                          icon: Icons.info_outline,
                          tooltip: 'Legenda do mapa',
                          onPressed:
                              () => showMapLegendSheet(
                                context,
                                sourceLabel: _sourceLabel(data),
                              ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _MapControls(
                          // Mapa baixo (tela pequena, fonte grande): em linha.
                          horizontal: constraints.maxHeight < 220,
                          onZoomIn: () => _zoomBy(1),
                          onZoomOut: () => _zoomBy(-1),
                          onCenter: _centerOnMe,
                          hasMyPosition:
                              data.myLat != null && data.myLon != null,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: _AttributionLabel(text: data.attribution),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
        _PrivacyNotice(visibleToOthers: data.visibleToOthers),
      ],
    );
  }

  Widget _buildMap(CommunityMapData data, BaseMapLayers layers) {
    final bounds = layers.data.bounds;
    return Semantics(
      label:
          'Mapa da comunidade. Use o botão "Ver como lista" para ouvir os '
          'pontos de coleta.',
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _clamp(_homePosition, bounds),
          initialZoom: _initialZoom,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          backgroundColor: BaseMapColors.land,
          cameraConstraint: CameraConstraint.containCenter(bounds: bounds),
          interactionOptions: const InteractionOptions(
            flags:
                InteractiveFlag.drag |
                InteractiveFlag.flingAnimation |
                InteractiveFlag.pinchMove |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.scrollWheelZoom,
          ),
        ),
        children: [
          layers.lakes,
          layers.water,
          ZoomBandLayer(
            key: const ValueKey('mapa-vias'),
            bands: layers.roadBands,
          ),
          const NeighborhoodLabelsLayer(key: ValueKey('mapa-bairros')),
          if (_showPoints)
            PointsClusterLayer(
              key: const ValueKey('mapa-pontos'),
              points: _mapPoints,
              onPointPressed: _openPointFromMap,
              onClusterPressed: _onClusterPressed,
            ),
          if (_showNeighbors && _neighborsLayer != null) _neighborsLayer!,
          if (_meLayer != null) _meLayer!,
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.pointsCount,
    required this.neighborsCount,
    required this.showPoints,
    required this.showNeighbors,
    required this.onPointsChanged,
    required this.onNeighborsChanged,
    required this.onShowList,
  });

  final int pointsCount;
  final int neighborsCount;
  final bool showPoints;
  final bool showNeighbors;
  final ValueChanged<bool> onPointsChanged;
  final ValueChanged<bool> onNeighborsChanged;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.labelMd.copyWith(
      color: AppColors.brandTextPrimary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: Text('Pontos de coleta ($pointsCount)'),
            labelStyle: labelStyle,
            selected: showPoints,
            onSelected: onPointsChanged,
            selectedColor: AppColors.brandSecondaryContainer,
            checkmarkColor: AppColors.brandDarkAccent,
            backgroundColor: AppColors.brandSurface,
            side: const BorderSide(color: AppColors.brandBorder),
            tooltip: 'Mostrar ou esconder os pontos de coleta',
          ),
          FilterChip(
            label: Text('Vizinhos ($neighborsCount)'),
            labelStyle: labelStyle,
            selected: showNeighbors,
            onSelected: onNeighborsChanged,
            selectedColor: AppColors.brandSecondaryContainer,
            checkmarkColor: AppColors.brandDarkAccent,
            backgroundColor: AppColors.brandSurface,
            side: const BorderSide(color: AppColors.brandBorder),
            tooltip: 'Mostrar ou esconder os vizinhos',
          ),
          TextButton.icon(
            onPressed: onShowList,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandDarkAccent,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.format_list_bulleted, size: 18),
            label: const Text('Ver como lista'),
          ),
        ],
      ),
    );
  }
}

/// Chips por tipo de ponto, roláveis na horizontal, com a cor da legenda.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({
    required this.counts,
    required this.hidden,
    required this.onChanged,
    required this.schoolCount,
    required this.showSchools,
    required this.onSchoolsChanged,
  });

  final List<({String type, int count})> counts;
  final Set<String> hidden;
  final void Function(String type, bool visible) onChanged;

  /// Pontos em escolas e creches (interruptor no começo da fileira).
  final int schoolCount;
  final bool showSchools;
  final ValueChanged<bool> onSchoolsChanged;

  @override
  Widget build(BuildContext context) {
    // Altura acompanha o tamanho da fonte, com no mínimo 48 de toque.
    final height = math.max(
      52.0,
      MediaQuery.textScalerOf(context).scale(12) + 36,
    );
    final offset = schoolCount > 0 ? 1 : 0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: counts.length + offset,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index < offset) {
            return Center(
              child: _SchoolSwitch(
                count: schoolCount,
                value: showSchools,
                onChanged: onSchoolsChanged,
              ),
            );
          }
          final item = counts[index - offset];
          final family = familyForType(item.type);
          final selected = !hidden.contains(item.type);
          return Center(
            child: FilterChip(
              avatar: CircleAvatar(
                backgroundColor: family.color,
                child: const SizedBox.shrink(),
              ),
              showCheckmark: false,
              label: Text(
                '${CollectionPoint.labelForType(item.type)} (${item.count})',
              ),
              labelStyle: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
              selected: selected,
              onSelected: (value) => onChanged(item.type, value),
              selectedColor: AppColors.brandSecondaryContainer,
              backgroundColor: AppColors.brandSurface,
              side: BorderSide(
                color: selected ? family.color : AppColors.brandBorder,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }
}

/// Interruptor "Mostrar pontos em escolas", desligado por padrão: os pontos
/// em escolas e creches atendem sobretudo a comunidade escolar.
class _SchoolSwitch extends StatelessWidget {
  const _SchoolSwitch({
    required this.count,
    required this.value,
    required this.onChanged,
  });

  final int count;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Material(
        color: AppColors.brandSurface,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.brandBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mostrar pontos em escolas ($count)',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor: AppColors.brandPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenter,
    required this.hasMyPosition,
    this.horizontal = false,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenter;
  final bool hasMyPosition;

  /// Botões em linha, para mapas baixos.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 8, height: 8);
    final children = [
      _MapButton(icon: Icons.add, tooltip: 'Aproximar', onPressed: onZoomIn),
      gap,
      _MapButton(icon: Icons.remove, tooltip: 'Afastar', onPressed: onZoomOut),
      gap,
      _MapButton(
        icon: Icons.my_location,
        tooltip:
            hasMyPosition
                ? 'Centralizar em mim'
                : 'Centralizar no centro da cidade',
        onPressed: onCenter,
      ),
    ];
    return horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.brandSurface,
        foregroundColor: AppColors.brandDarkAccent,
        side: const BorderSide(color: AppColors.brandBorder),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      icon: Icon(icon),
    );
  }
}

/// Crédito obrigatório dos dados do mapa, sempre visível.
class _AttributionLabel extends StatelessWidget {
  const _AttributionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySm.copyWith(color: AppColors.brandTextPrimary),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.visibleToOthers});

  final bool visibleToOthers;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.bodySm.copyWith(
      color: AppColors.brandTextPrimary,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandSurface,
        border: Border(top: BorderSide(color: AppColors.brandBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.brandDarkAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'As pessoas aparecem só na região do bairro, nunca no '
                        'endereço.',
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
              if (!visibleToOthers)
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: AppColors.brandDarkAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Você escolheu não aparecer no mapa dos vizinhos.',
                        style: style,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/preferencias'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandDarkAccent,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Mudar'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
