import 'dart:math';

import 'data/neighborhoods_data.dart';

/// Funções de lugar do modo local: bairros de São José do Rio Preto, posição
/// aproximada de um morador e distância entre dois pontos.
///
/// A posição de uma pessoa nunca é o endereço dela: é o centro do bairro com
/// um deslocamento fixo de algumas centenas de metros, calculado a partir de
/// uma chave do usuário. Assim ela aparece no mapa na região certa, mas não
/// na porta de casa.
class Places {
  Places._();

  static const String defaultCity = 'São José do Rio Preto';
  static const String defaultState = 'SP';

  /// Centro da cidade (bairro Centro, segundo o OpenStreetMap).
  static const ({double lat, double lon}) cityCenter = (
    lat: -20.81085,
    lon: -49.37885,
  );

  /// Deslocamento máximo aplicado à posição de uma pessoa, em graus
  /// (cerca de 350 metros).
  static const double _jitter = 0.0032;

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };

  /// Minúsculas, sem acentos e sem espaços repetidos.
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().trim().split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Bairro com esse nome (ignorando acentos e maiúsculas), se existir.
  static ({String name, double lat, double lon})? findNeighborhood(
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) return null;
    final wanted = normalize(name);
    for (final item in neighborhoodsData) {
      if (normalize(item.name) == wanted) return item;
    }
    return null;
  }

  /// Nomes de bairros que contêm [query], para o campo de cadastro.
  static List<String> searchNeighborhoods(String query, {int limit = 12}) {
    final wanted = normalize(query);
    if (wanted.isEmpty) return const [];
    final starts = <String>[];
    final contains = <String>[];
    for (final item in neighborhoodsData) {
      final name = normalize(item.name);
      if (name.startsWith(wanted)) {
        starts.add(item.name);
      } else if (name.contains(wanted)) {
        contains.add(item.name);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  static int _hash(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Posição aproximada de um morador do [neighborhood].
  ///
  /// [key] identifica a pessoa (por exemplo o e-mail) e torna o deslocamento
  /// sempre o mesmo para ela. Bairro desconhecido cai no centro da cidade,
  /// com deslocamento maior.
  static ({double lat, double lon}) approximatePosition(
    String? neighborhood,
    String key,
  ) {
    final found = findNeighborhood(neighborhood);
    final base =
        found == null ? cityCenter : (lat: found.lat, lon: found.lon);
    final spread = found == null ? _jitter * 3 : _jitter;
    final hash = _hash(key);
    final dLat = ((hash % 2001) / 1000.0 - 1) * spread;
    final dLon = (((hash ~/ 2001) % 2001) / 1000.0 - 1) * spread;
    return (
      lat: double.parse((base.lat + dLat).toStringAsFixed(5)),
      lon: double.parse((base.lon + dLon).toStringAsFixed(5)),
    );
  }

  /// Distância em metros entre dois pontos (fórmula de haversine).
  static int distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return (earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))).round();
  }
}
