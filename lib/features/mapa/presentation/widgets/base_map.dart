import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa-base offline de São José do Rio Preto.
///
/// O fundo do mapa (vias principais, rios e lagos) vem pronto, em imagens
/// embutidas no app (`assets/map/tiles/`). Elas são desenhadas pelo próprio
/// projeto, com os dados do OpenStreetMap, por
/// `test/capturas/gerar_mapa_tiles.dart`.
///
/// Antes o app desenhava milhares de linhas a cada quadro, o que travava o
/// mapa no celular. Com as imagens, arrastar e ampliar só move figuras.
abstract final class BaseMap {
  /// Pasta dos quadros; cada arquivo se chama `<zoom>_<x>_<y>.png`.
  static const String tilesDir = 'assets/map/tiles/';

  /// Quadro de uma cor só, usado onde não há nada desenhado.
  static const String blankTile = '${tilesDir}vazio.png';

  /// Níveis de zoom que existem em imagem. Acima do último, a imagem do
  /// último nível é ampliada.
  static const int minNativeZoom = 11;
  static const int maxNativeZoom = 16;

  /// Área coberta pelas imagens; a câmera fica presa dentro dela.
  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(-20.93, -49.5),
    const LatLng(-20.7, -49.28),
  );

  /// Cor do terreno: fundo do mapa e das imagens.
  static const Color land = Color(0xFFEFEADF);

  static String tileAsset(int zoom, int x, int y) =>
      '$tilesDir${zoom}_${x}_$y.png';

  /// Arquivos dos quadros em volta de [center] no nível [zoom], entre os que
  /// existem em [available]. Serve para carregar a área inicial antes de o
  /// mapa aparecer.
  static List<String> tilesAround(
    LatLng center,
    int zoom,
    Set<String> available, {
    int columns = 1,
    int rows = 2,
  }) {
    final count = 1 << zoom;
    final x = ((center.longitude + 180) / 360 * count).floor();
    final phi = center.latitude * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) /
                2 *
                count)
            .floor();
    return [
      for (var i = x - columns; i <= x + columns; i++)
        for (var j = y - rows; j <= y + rows; j++)
          if (available.contains(tileAsset(zoom, i, j))) tileAsset(zoom, i, j),
    ];
  }

  static Future<Set<String>>? _loading;
  static Set<String>? _tiles;

  /// Quadros que existem no pacote do app (lidos uma vez por execução).
  static Future<Set<String>> loadTiles() {
    final tiles = _tiles;
    if (tiles != null) return Future.value(tiles);
    final loading = _loading;
    if (loading != null) return loading;
    final future = _listTiles().then((value) => _tiles = value);
    _loading = future;
    // Se der erro, a próxima tentativa lê a lista de novo.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_loading, future)) _loading = null;
        },
      ),
    );
    return future;
  }

  static Future<Set<String>> _listTiles() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return {
      for (final asset in manifest.listAssets())
        if (asset.startsWith(tilesDir)) asset,
    };
  }
}

/// Entrega ao mapa a imagem embutida de cada quadro.
///
/// Só existem arquivos para os quadros que têm algo desenhado; os demais
/// recebem [BaseMap.blankTile].
class BaseMapTileProvider extends TileProvider {
  BaseMapTileProvider(this.available);

  /// Arquivos de quadro presentes no pacote.
  final Set<String> available;

  static const AssetImage _blank = AssetImage(BaseMap.blankTile);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final asset = BaseMap.tileAsset(
      coordinates.z,
      coordinates.x,
      coordinates.y,
    );
    return available.contains(asset) ? AssetImage(asset) : _blank;
  }
}

/// Camada de fundo do mapa.
class BaseMapLayer extends StatelessWidget {
  const BaseMapLayer({super.key, required this.provider});

  /// A mesma instância entre reconstruções, para a camada não recarregar.
  final BaseMapTileProvider provider;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      tileProvider: provider,
      tileDimension: 256,
      minNativeZoom: BaseMap.minNativeZoom,
      maxNativeZoom: BaseMap.maxNativeZoom,
      tileBounds: BaseMap.bounds,
      // Um anel de quadros além da tela, para não aparecer vazio ao arrastar.
      panBuffer: 1,
      keepBuffer: 2,
      tileDisplay: const TileDisplay.fadeIn(
        duration: Duration(milliseconds: 120),
      ),
    );
  }
}
