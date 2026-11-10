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

  // dart format off
  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };
  // dart format on

  /// Minúsculas, sem acentos e sem espaços repetidos.
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().trim().split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Área coberta pelo mapa-base (São José do Rio Preto). Uma posição fora
  /// dela não aparece no mapa.
  static const ({double south, double west, double north, double east})
  mapArea = (south: -20.93, west: -49.5, north: -20.7, east: -49.28);

  /// A posição fica dentro de [mapArea].
  static bool insideMapArea(double lat, double lon) =>
      lat >= mapArea.south &&
      lat <= mapArea.north &&
      lon >= mapArea.west &&
      lon <= mapArea.east;

  /// Abreviações comuns em nomes de bairro ("Jd." é Jardim, "Vl" é Vila...).
  static const Map<String, String> _abbreviations = {
    'jd': 'jardim',
    'jdm': 'jardim',
    'vl': 'vila',
    'pq': 'parque',
    'pqe': 'parque',
    'res': 'residencial',
    'resid': 'residencial',
    'cj': 'conjunto',
    'conj': 'conjunto',
    'hab': 'habitacional',
    'lot': 'loteamento',
    'cond': 'condominio',
    'sta': 'santa',
    'sto': 'santo',
    'nsa': 'nossa',
    'sra': 'senhora',
    'dr': 'doutor',
    'prof': 'professor',
  };

  /// Palavras de ligação, ignoradas na comparação ("Bosque da Saúde").
  static const Set<String> _connectives = {'de', 'da', 'do', 'dos', 'das'};

  /// Números romanos que aparecem nos nomes ("Vista Alegre II").
  static const Map<String, String> _romans = {
    'i': '1',
    'ii': '2',
    'iii': '3',
    'iv': '4',
  };

  /// Palavras de um nome para comparação: sem acentos nem pontuação, com as
  /// abreviações por extenso, romanos como números e sem "de/da/do/dos/das".
  static List<String> _words(String value) {
    final text = normalize(value).replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return [
      for (final raw in text.split(' '))
        if (raw.isNotEmpty && !_connectives.contains(raw))
          _romans[raw] ?? _abbreviations[raw] ?? raw,
    ];
  }

  /// Bairros com o nome normalizado e as palavras de comparação, montados
  /// uma vez (o campo "Bairro" consulta a cada letra digitada).
  static final List<
    ({
      ({String name, double lat, double lon}) item,
      String normalized,
      String key,
      List<String> words,
    })
  >
  _index = List.unmodifiable([
    for (final item in neighborhoodsData)
      (
        item: item,
        normalized: normalize(item.name),
        key: _words(item.name).join(' '),
        words: _words(item.name),
      ),
  ]);

  /// Bairro com esse nome, se existir.
  ///
  /// Na ordem: nome igual (ignorando acentos e maiúsculas); igual depois de
  /// trocar abreviações e ignorar pontuação e "de/da/do"; o único bairro que
  /// tem todas as palavras digitadas; o único que bate com até uma letra
  /// trocada, faltando ou sobrando. Se mais de um bairro serve, nenhum é
  /// escolhido: melhor pedir para a pessoa escolher do que pôr no lugar
  /// errado.
  static ({String name, double lat, double lon})? findNeighborhood(
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) return null;
    final wanted = normalize(name);
    for (final entry in _index) {
      if (entry.normalized == wanted) return entry.item;
    }

    final words = _words(name);
    if (words.isEmpty) return null;
    final key = words.join(' ');
    ({String name, double lat, double lon})? only(
      bool Function(List<String> words, String key) test,
    ) {
      ({String name, double lat, double lon})? found;
      for (final entry in _index) {
        if (!test(entry.words, entry.key)) continue;
        if (found != null) return null; // mais de um: ambíguo
        found = entry.item;
      }
      return found;
    }

    final same = only((_, other) => other == key);
    if (same != null) return same;
    // Texto curto demais ("2", "Sul") casaria com qualquer coisa.
    if (key.replaceAll(' ', '').length < 4) return null;
    final contained = only(
      (other, _) => words.every((word) => other.contains(word)),
    );
    if (contained != null) return contained;
    return only((other, _) => _closeWords(words, other));
  }

  /// Cada palavra digitada está em [other], com no máximo uma delas com uma
  /// letra de diferença. Números precisam ser iguais.
  static bool _closeWords(List<String> words, List<String> other) {
    var typos = 0;
    for (final word in words) {
      if (other.contains(word)) continue;
      if (word.length < 4 || RegExp(r'[0-9]').hasMatch(word)) return false;
      final near = other.any(
        (candidate) => candidate.length >= 4 && _withinOneEdit(word, candidate),
      );
      if (!near || ++typos > 1) return false;
    }
    return typos == 1;
  }

  /// [a] e [b] diferem por no máximo uma letra (trocada, faltando ou sobrando).
  static bool _withinOneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length > b.length) return _withinOneEdit(b, a);
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length == b.length) i++;
      j++;
    }
    return edits + (b.length - j) + (a.length - i) <= 1;
  }

  /// Nomes de bairros que contêm [query], para o campo de cadastro.
  ///
  /// Também acha pelo nome abreviado ("Jd Nazar" sugere Jardim Nazareth).
  static List<String> searchNeighborhoods(String query, {int limit = 12}) {
    final wanted = normalize(query);
    if (wanted.isEmpty) return const [];
    final key = _words(query).join(' ');
    final starts = <String>[];
    final contains = <String>[];
    final byKey = <String>[];
    for (final entry in _index) {
      final name = entry.normalized;
      if (name.startsWith(wanted)) {
        starts.add(entry.item.name);
      } else if (name.contains(wanted)) {
        contains.add(entry.item.name);
      } else if (key.isNotEmpty && entry.key.contains(key)) {
        byKey.add(entry.item.name);
      }
    }
    return [...starts, ...contains, ...byKey].take(limit).toList();
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
  /// sempre o mesmo para ela.
  ///
  /// Bairro que não está na lista dá `null`: a pessoa fica sem posição (não
  /// aparece para os vizinhos) em vez de cair, sem aviso, no centro da
  /// cidade.
  static ({double lat, double lon})? approximatePosition(
    String? neighborhood,
    String key,
  ) {
    final found = findNeighborhood(neighborhood);
    if (found == null) return null;
    final hash = _hash(key);
    final dLat = ((hash % 2001) / 1000.0 - 1) * _jitter;
    final dLon = (((hash ~/ 2001) % 2001) / 1000.0 - 1) * _jitter;
    return (
      lat: double.parse((found.lat + dLat).toStringAsFixed(5)),
      lon: double.parse((found.lon + dLon).toStringAsFixed(5)),
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
