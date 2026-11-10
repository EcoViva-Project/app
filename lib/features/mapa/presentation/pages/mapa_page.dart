import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/api_exception.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/device_locator.dart';
import '../../../../core/services/my_location_service.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../perfil/presentation/widgets/edit_profile_dialog.dart';
import '../widgets/base_map.dart';
import '../widgets/map_markers.dart';
import '../widgets/map_sheets.dart';
import '../widgets/my_position_sheets.dart';
import '../widgets/point_types.dart';
import '../widgets/points_cluster_layer.dart';

/// Mapa da comunidade: pontos de coleta e vizinhos (em posição aproximada)
/// sobre um mapa-base em imagens embutidas no app, sem internet.
///
/// A própria pessoa aparece na posição exata quando o celular a informa (ou
/// quando ela marca no mapa); essa posição fica só no aparelho, ver
/// [MyLocationService]. Sem ela, aparece na região do bairro, como os
/// vizinhos a veem.
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
  BaseMapTileProvider? _tiles;

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

  final MyLocationService _myLocation = MyLocationService.instance;

  /// Posição e tipo com que [_meLayer] foi montada: a camada só é refeita
  /// quando a posição muda de fato.
  LatLng? _mePoint;
  bool _meExact = false;

  /// A pessoa já arrastou ou ampliou o mapa com o dedo: a posição que chega
  /// do celular não move mais a câmera sozinha.
  bool _userMovedMap = false;

  /// Modo "Ajustar no mapa": o próximo toque no mapa marca a posição.
  bool _adjusting = false;

  /// A localização automática da abertura já foi disparada.
  bool _autoLocateStarted = false;

  /// O mapa já foi desenhado e a câmera pode ser movida.
  bool _mapReady = false;

  /// Animação de entrada desta tela (ver [_routeTransitionDone]).
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeAnimation = ModalRoute.of(context)?.animation;
  }

  @override
  void initState() {
    super.initState();
    _myLocation.addListener(_onMyLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _myLocation.removeListener(_onMyLocationChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Espera a animação de entrada da tela terminar.
  ///
  /// O primeiro quadro do mapa é o mais caro (monta marcadores e rótulos).
  /// Com a tela já parada ele passa despercebido; no meio da animação,
  /// aparecia como um engasgo ao abrir.
  Future<void> _routeTransitionDone() {
    final animation = _routeAnimation;
    if (animation == null || animation.status != AnimationStatus.forward) {
      return Future.value();
    }
    final completer = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.forward) return;
      animation.removeStatusListener(listener);
      if (!completer.isCompleted) completer.complete();
    }

    animation.addStatusListener(listener);
    return completer.future;
  }

  /// Começa a carregar as imagens da área inicial, para o mapa já aparecer
  /// completo.
  void _precacheInitialTiles(Set<String> available, CommunityMapData data) {
    final center = _clamp(_homeFor(data), BaseMap.bounds);
    final assets = BaseMap.tilesAround(center, _initialZoom.round(), available);
    for (final asset in assets) {
      unawaited(precacheImage(AssetImage(asset), context, onError: (_, _) {}));
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final myPosition = _myLocation.load();
      final results = await Future.wait<Object>([
        BaseMap.loadTiles(),
        NeighborhoodService.instance.loadMap(),
      ]);
      await myPosition;
      if (!mounted) return;
      final available = results[0] as Set<String>;
      final data = results[1] as CommunityMapData;
      // A mesma instância enquanto a lista de quadros não mudar, para a
      // camada de fundo não recarregar as imagens.
      final tiles =
          identical(_tiles?.available, available)
              ? _tiles!
              : BaseMapTileProvider(available);
      _precacheInitialTiles(available, data);
      await _routeTransitionDone();
      if (!mounted) return;
      setState(() {
        _tiles = tiles;
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

  /// Pontos para a lista, com o mesmo filtro de escolas do mapa e a
  /// distância a partir da posição exata, quando houver.
  List<CollectionPoint> _listPoints(CommunityMapData data) =>
      NeighborhoodService.withMyDistances([
        for (final point in data.points)
          if (_showSchools || !isSchoolPoint(point)) point,
      ]);

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
    _mePoint = null;
    _meLayer = null;
    _rebuildMeLayer(data);
  }

  /// Posição do próprio marcador: a exata, se houver; senão a região do
  /// bairro; `null` se o bairro não foi reconhecido.
  LatLng? _ownPosition(CommunityMapData data) {
    final exact = _myLocation.position;
    if (exact != null) return LatLng(exact.lat, exact.lon);
    final lat = data.myLat;
    final lon = data.myLon;
    return lat == null || lon == null ? null : LatLng(lat, lon);
  }

  /// Refaz a camada "você" só se a posição (ou o tipo dela) mudou.
  void _rebuildMeLayer(CommunityMapData data) {
    final point = _ownPosition(data);
    final exact = _myLocation.hasExactPosition;
    if (point == _mePoint && exact == _meExact && _meLayer != null) return;
    _mePoint = point;
    _meExact = exact;
    _meLayer =
        point == null
            ? null
            : MarkerLayer(
              key: const ValueKey('mapa-voce'),
              markers: [
                Marker(
                  key: const ValueKey('mapa-voce-marcador'),
                  point: point,
                  width: kMeMarkerWidth,
                  height: kMeMarkerHeight,
                  child: MeMarker(
                    initials: AuthService.instance.userInitials,
                    exact: exact,
                    onPressed: _openMeSheet,
                  ),
                ),
              ],
            );
  }

  void _onMyLocationChanged() {
    if (!mounted) return;
    setState(() {
      final data = _data;
      if (data != null) _rebuildMeLayer(data);
    });
  }

  LatLng _homeFor(CommunityMapData data) =>
      _ownPosition(data) ?? LatLng(data.centerLat, data.centerLon);

  LatLng get _homePosition => _homeFor(_data!);

  void _showMessage(String text, {bool offerAdjust = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action:
              offerAdjust
                  ? SnackBarAction(
                    label: 'Ajustar no mapa',
                    onPressed: _startAdjusting,
                  )
                  : null,
        ),
      );
  }

  /// Ao abrir: se a permissão já foi dada, procura a localização sem
  /// perguntar nada. Se nunca foi pedida, explica uma vez para que serve
  /// antes do pedido do sistema. "Agora não" fica guardado e não volta.
  Future<void> _startAutoLocate() async {
    if (_autoLocateStarted) return;
    _autoLocateStarted = true;
    final current = _myLocation.position;
    if (current != null && current.isManual) return;
    final permission = await _myLocation.permission();
    if (!mounted) return;
    if (permission == LocatorPermission.granted) {
      await _locate(automatic: true);
      return;
    }
    if (permission != LocatorPermission.denied || _myLocation.introSeen) return;
    await _myLocation.markIntroSeen();
    if (!mounted) return;
    final accepted = await showLocationIntroSheet(context);
    if (accepted && mounted) await _locate();
  }

  /// Procura a localização do celular e conta à pessoa se não deu certo.
  ///
  /// [automatic]: a atualização da abertura, que não pergunta permissão e
  /// mantém uma posição marcada à mão. [center]: centraliza no fim mesmo que
  /// a pessoa já tenha mexido no mapa.
  Future<void> _locate({bool automatic = false, bool center = false}) async {
    final hadExact = _myLocation.hasExactPosition;
    final result = await _myLocation.locate(
      automatic: automatic,
      askPermission: !automatic,
    );
    if (!mounted || _data == null) return;
    if (_mapReady &&
        (center || (!_userMovedMap && _myLocation.hasExactPosition))) {
      _controller.move(
        _clamp(_homePosition, BaseMap.bounds),
        center
            ? math.max(_controller.camera.zoom, 14.0)
            : _controller.camera.zoom,
      );
    }
    // Atualização automática que falha sem mudar nada: fica quieta.
    if (automatic && hadExact) return;
    final fallback =
        _myLocation.hasExactPosition
            ? 'mantivemos sua posição anterior'
            : _data!.myLat != null
            ? 'seguimos com a região do seu bairro'
            : 'você pode marcar onde está em "Ajustar no mapa"';
    final message = result.message(fallback: fallback);
    if (message != null) _showMessage(message, offerAdjust: true);
  }

  /// "Ajustar no mapa": o próximo toque no mapa marca a posição.
  void _startAdjusting() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() => _adjusting = true);
  }

  void _cancelAdjusting() => setState(() => _adjusting = false);

  void _onMapTap(TapPosition _, LatLng point) {
    if (!_adjusting) return;
    if (!_myLocation.setManual(point.latitude, point.longitude)) {
      _showMessage('Esse ponto fica fora do mapa de Rio Preto.');
      return;
    }
    setState(() => _adjusting = false);
    _showMessage('Posição ajustada. $kExactPositionPrivacy');
  }

  /// Com o mapa na tela, procura a localização (ver [_startAutoLocate]).
  void _onMapReady() {
    _mapReady = true;
    unawaited(_startAutoLocate());
  }

  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) _userMovedMap = true;
  }

  /// Folha "Você": de onde vem a posição e o que dá para fazer.
  Future<void> _openMeSheet() async {
    final position = _myLocation.position;
    final neighborhood = AuthService.instance.neighborhood.trim();
    final source =
        position == null
            ? (neighborhood.isEmpty
                ? 'região do seu bairro'
                : 'região do bairro $neighborhood')
            : position.isManual
            ? 'ajustada por você'
            : 'pela localização do celular';
    final choice = await showMyPositionSheet(
      context,
      sourceLabel: source,
      hasExactPosition: position != null,
    );
    if (!mounted) return;
    switch (choice) {
      case MyPositionChoice.useLocation:
        await _locate(center: true);
      case MyPositionChoice.adjust:
        _startAdjusting();
      case MyPositionChoice.backToRegion:
        _myLocation.clear();
      case null:
        break;
    }
  }

  /// Bairro fora da lista: abre a edição do perfil e recarrega o mapa.
  Future<void> _editProfile() async {
    final saved = await showEditProfileDialog(context);
    if (!saved || !mounted) return;
    await _load();
    if (mounted && _mapReady && _mePoint != null) _centerOnMe();
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
    _controller.move(_clamp(_homePosition, BaseMap.bounds), zoom);
  }

  /// Botão "centralizar em mim": procura a localização e depois centraliza.
  /// Uma posição marcada à mão é mantida.
  void _onCenterPressed() {
    final current = _myLocation.position;
    if (current != null && current.isManual) {
      _centerOnMe();
      return;
    }
    unawaited(_locate(center: true));
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
    final tiles = _tiles;
    if (data == null || tiles == null) {
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
        if (_adjusting)
          _MapBanner(
            key: const ValueKey('mapa-ajustar'),
            icon: Icons.touch_app_outlined,
            text: 'Toque no mapa onde você está',
            actions: [
              _BannerAction(label: 'Cancelar', onPressed: _cancelAdjusting),
            ],
          )
        else if (data.myLat == null &&
            !_myLocation.hasExactPosition &&
            AuthService.instance.neighborhood.trim().isNotEmpty)
          _MapBanner(
            key: const ValueKey('mapa-bairro-desconhecido'),
            icon: Icons.wrong_location_outlined,
            text:
                'Não achamos o bairro "${AuthService.instance.neighborhood.trim()}" '
                'na lista de Rio Preto, por isso você não aparece no mapa.',
            actions: [
              _BannerAction(label: 'Editar perfil', onPressed: _editProfile),
              _BannerAction(
                label: 'Usar minha localização',
                onPressed: () => _locate(center: true),
              ),
            ],
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
                      // Camada própria: ao arrastar, só o mapa é
                      // redesenhado, não os botões por cima dele.
                      Positioned.fill(
                        child: RepaintBoundary(child: _buildMap(data, tiles)),
                      ),
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
                          onCenter: _onCenterPressed,
                          hasMyPosition: _mePoint != null,
                        ),
                      ),
                      if (_myLocation.locating)
                        const Positioned(
                          right: 8,
                          bottom: 8,
                          child: _LocatingLabel(),
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
        _PrivacyNotice(
          visibleToOthers: data.visibleToOthers,
          exactPosition: _myLocation.hasExactPosition,
        ),
      ],
    );
  }

  Widget _buildMap(CommunityMapData data, BaseMapTileProvider tiles) {
    final bounds = BaseMap.bounds;
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
          backgroundColor: BaseMap.land,
          cameraConstraint: CameraConstraint.containCenter(bounds: bounds),
          onTap: _onMapTap,
          onPositionChanged: _onCameraChanged,
          onMapReady: _onMapReady,
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
          BaseMapLayer(key: const ValueKey('mapa-fundo'), provider: tiles),
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
  const _PrivacyNotice({
    required this.visibleToOthers,
    required this.exactPosition,
  });

  final bool visibleToOthers;

  /// A posição exata (só deste aparelho) está em uso.
  final bool exactPosition;

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
                        exactPosition
                            ? kExactPositionPrivacy
                            : 'As pessoas aparecem só na região do bairro, '
                                'nunca no endereço.',
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

/// Faixa de aviso acima do mapa, com botões.
class _MapBanner extends StatelessWidget {
  const _MapBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.actions,
  });

  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: 20, color: AppColors.brandDarkAccent),
                ),
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
          Wrap(alignment: WrapAlignment.end, children: actions),
        ],
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandDarkAccent,
        minimumSize: const Size(48, 48),
      ),
      child: Text(label),
    );
  }
}

/// "Localizando…", discreto, enquanto o celular procura a posição.
class _LocatingLabel extends StatelessWidget {
  const _LocatingLabel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Localizando',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.brandBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Camada própria: o giro não redesenha o resto da tela.
            const RepaintBoundary(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Localizando…',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
