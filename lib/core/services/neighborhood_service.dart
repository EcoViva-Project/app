import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'icon_catalog.dart';

import 'package:flutter/material.dart' show IconData, Icons;

/// Meta coletiva da semana: ações registradas por toda a comunidade.
class CollectiveGoal {
  const CollectiveGoal({
    required this.title,
    required this.description,
    required this.target,
    required this.current,
    required this.progress,
    required this.reached,
    required this.contributors,
    required this.daysLeft,
  });

  final String title;
  final String description;
  final int target;
  final int current;
  final double progress;
  final bool reached;

  /// Quantas pessoas já registraram ações nesta semana.
  final int contributors;

  /// Dias até a meta fechar (domingo).
  final int daysLeft;

  /// "157 de 400 ações".
  String get countLabel => '$current de $target ações';

  /// "39% da meta".
  String get percentLabel => '${(progress * 100).round()}% da meta';

  /// "Restam 5 dias", "Resta 1 dia" ou "Termina hoje".
  String get deadlineLabel {
    if (daysLeft <= 0) return 'Termina hoje';
    if (daysLeft == 1) return 'Resta 1 dia';
    return 'Restam $daysLeft dias';
  }

  factory CollectiveGoal.fromApi(Map<String, dynamic> json) => CollectiveGoal(
    title: json['title'] as String? ?? 'Meta coletiva da semana',
    description: json['description'] as String? ?? '',
    target: (json['target'] as num?)?.toInt() ?? 0,
    current: (json['current'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    reached: json['reached'] as bool? ?? false,
    contributors: (json['contributors'] as num?)?.toInt() ?? 0,
    daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
  );
}

/// Uma linha do ranking semanal (pontos de ações na semana).
class RankingEntry {
  const RankingEntry({
    required this.position,
    required this.name,
    required this.initials,
    required this.points,
    required this.isMe,
    this.neighborhood,
  });

  final int position;

  /// Primeiro nome e inicial ("Marina L."); o nome inteiro só para o próprio.
  final String name;
  final String initials;
  final String? neighborhood;
  final int points;
  final bool isMe;

  factory RankingEntry.fromApi(Map<String, dynamic> json) => RankingEntry(
    position: (json['position'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    initials: json['initials'] as String? ?? '?',
    neighborhood: json['neighborhood'] as String?,
    points: (json['points'] as num?)?.toInt() ?? 0,
    isMe: json['isMe'] as bool? ?? false,
  );
}

/// Números da comunidade, calculados sobre os registros de todos.
class CommunityStats {
  const CommunityStats({
    required this.city,
    required this.neighborhood,
    required this.members,
    required this.activeNeighbors,
    required this.actionsToday,
    required this.actionsThisWeek,
    required this.litersThisWeek,
    required this.pointsThisWeek,
    required this.ranking,
    required this.myWeeklyPoints,
    this.goal,
    this.myPosition,
  });

  final String city;
  final String neighborhood;

  /// Pessoas cadastradas.
  final int members;

  /// Pessoas com ação registrada nos últimos 7 dias.
  final int activeNeighbors;
  final int actionsToday;
  final int actionsThisWeek;
  final int litersThisWeek;
  final int pointsThisWeek;
  final CollectiveGoal? goal;

  /// As cinco primeiras posições da semana.
  final List<RankingEntry> ranking;

  /// Posição do usuário na semana; `null` se ainda não pontuou.
  final int? myPosition;
  final int myWeeklyPoints;

  factory CommunityStats.fromApi(Map<String, dynamic> json) => CommunityStats(
    city: json['city'] as String? ?? '',
    neighborhood: json['neighborhood'] as String? ?? '',
    members: (json['members'] as num?)?.toInt() ?? 0,
    activeNeighbors: (json['activeNeighbors'] as num?)?.toInt() ?? 0,
    actionsToday: (json['actionsToday'] as num?)?.toInt() ?? 0,
    actionsThisWeek: (json['actionsThisWeek'] as num?)?.toInt() ?? 0,
    litersThisWeek: (json['litersThisWeek'] as num?)?.toInt() ?? 0,
    pointsThisWeek: (json['pointsThisWeek'] as num?)?.toInt() ?? 0,
    goal:
        json['goal'] is Map<String, dynamic>
            ? CollectiveGoal.fromApi(json['goal'] as Map<String, dynamic>)
            : null,
    ranking: [
      for (final item in (json['ranking'] as List?) ?? const [])
        RankingEntry.fromApi(item as Map<String, dynamic>),
    ],
    myPosition: (json['myPosition'] as num?)?.toInt(),
    myWeeklyPoints: (json['myWeeklyPoints'] as num?)?.toInt() ?? 0,
  );
}

/// Um ponto de coleta de materiais (ecoponto, cooperativa, entrega voluntária).
class CollectionPoint {
  const CollectionPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.materials,
    this.address,
    this.neighborhood,
    this.hours,
    this.phone,
    this.responsible,
    this.lat,
    this.lon,
    this.distanceMeters,
    this.confidence,
    this.sourceUrl,
    this.notes,
  });

  final int id;
  final String name;

  /// Tipo como veio do levantamento (por exemplo `ecoponto municipal`).
  final String type;
  final List<String> materials;
  final String? address;
  final String? neighborhood;
  final String? hours;
  final String? phone;
  final String? responsible;
  final double? lat;
  final double? lon;

  /// Distância a partir da posição aproximada do usuário.
  final int? distanceMeters;

  /// `alta`, `média` ou `baixa`, conforme o levantamento.
  final String? confidence;
  final String? sourceUrl;
  final String? notes;

  bool get hasPosition => lat != null && lon != null;

  /// "A 850 m" ou "A 2,4 km"; `null` sem coordenada.
  String? get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    if (meters < 1000) return 'A ${(meters / 10).round() * 10} m';
    final km = (meters / 100).round() / 10;
    return 'A ${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static const Map<String, String> _typeLabels = {
    'ecoponto_municipal': 'Ecoponto municipal',
    'cooperativa': 'Cooperativa de reciclagem',
    'entrega_voluntaria': 'Entrega voluntária',
    'eletronicos': 'Eletrônicos',
    'pilhas_baterias': 'Pilhas e baterias',
    'lampadas': 'Lâmpadas',
    'oleo_cozinha': 'Óleo de cozinha',
    'medicamentos': 'Medicamentos',
    'pneus': 'Pneus',
    'vidro': 'Vidro',
    'outros': 'Outros materiais',
  };

  /// Tipos conhecidos, na ordem em que aparecem nos filtros.
  static List<String> get knownTypes => _typeLabels.keys.toList();

  /// Nome de um tipo para exibir ("Óleo de cozinha").
  static String labelForType(String type) {
    final known = _typeLabels[type];
    if (known != null) return known;
    if (type.isEmpty) return 'Ponto de coleta';
    final text = type.replaceAll('_', ' ');
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Tipo do ponto para exibir.
  String get typeLabel => labelForType(type);

  /// A informação veio de fonte oficial e recente.
  bool get isConfirmed => (confidence ?? '').toLowerCase() == 'alta';

  IconData get icon {
    final key = type.toLowerCase();
    if (key.contains('cooperativa')) return Icons.groups;
    if (key.contains('eletr')) return Icons.devices_other;
    if (key.contains('pilha') || key.contains('bateria')) {
      return Icons.battery_alert;
    }
    if (key.contains('lâmpada') || key.contains('lampada')) {
      return Icons.lightbulb_outline;
    }
    if (key.contains('óleo') || key.contains('oleo')) return Icons.opacity;
    if (key.contains('medicamento')) return Icons.medication_outlined;
    if (key.contains('pneu')) return Icons.trip_origin;
    if (key.contains('vidro')) return Icons.wine_bar_outlined;
    return Icons.recycling;
  }

  factory CollectionPoint.fromApi(Map<String, dynamic> json) => CollectionPoint(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Ponto de coleta',
    type: json['type'] as String? ?? '',
    materials: [
      for (final item in (json['materials'] as List?) ?? const [])
        item.toString(),
    ],
    address: json['address'] as String?,
    neighborhood: json['neighborhood'] as String?,
    hours: json['hours'] as String?,
    phone: json['phone'] as String?,
    responsible: json['responsible'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
    confidence: json['confidence'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    notes: json['notes'] as String?,
  );
}

/// Uma pessoa no mapa da comunidade, sempre em posição aproximada.
class MapNeighbor {
  const MapNeighbor({
    required this.name,
    required this.initials,
    required this.lat,
    required this.lon,
    required this.weeklyPoints,
    this.neighborhood,
  });

  final String name;
  final String initials;
  final String? neighborhood;
  final double lat;
  final double lon;
  final int weeklyPoints;

  factory MapNeighbor.fromApi(Map<String, dynamic> json) => MapNeighbor(
    name: json['name'] as String? ?? '',
    initials: json['initials'] as String? ?? '?',
    neighborhood: json['neighborhood'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    weeklyPoints: (json['weeklyPoints'] as num?)?.toInt() ?? 0,
  );
}

/// Dados do mapa da comunidade.
class CommunityMapData {
  const CommunityMapData({
    required this.centerLat,
    required this.centerLon,
    required this.neighbors,
    required this.points,
    required this.attribution,
    this.myLat,
    this.myLon,
    this.visibleToOthers = true,
  });

  final double centerLat;
  final double centerLon;

  /// Posição aproximada do próprio usuário.
  final double? myLat;
  final double? myLon;

  /// O usuário aceitou aparecer no mapa dos outros.
  final bool visibleToOthers;
  final List<MapNeighbor> neighbors;
  final List<CollectionPoint> points;

  /// Crédito obrigatório dos dados do mapa.
  final String attribution;

  factory CommunityMapData.fromApi(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>? ?? const {};
    final me = json['me'] as Map<String, dynamic>?;
    return CommunityMapData(
      centerLat: (center['lat'] as num?)?.toDouble() ?? -20.81085,
      centerLon: (center['lon'] as num?)?.toDouble() ?? -49.37885,
      myLat: (me?['lat'] as num?)?.toDouble(),
      myLon: (me?['lon'] as num?)?.toDouble(),
      visibleToOthers: me?['visible'] as bool? ?? true,
      neighbors: [
        for (final item in (json['neighbors'] as List?) ?? const [])
          MapNeighbor.fromApi(item as Map<String, dynamic>),
      ],
      points: [
        for (final item in (json['points'] as List?) ?? const [])
          CollectionPoint.fromApi(item as Map<String, dynamic>),
      ],
      attribution:
          json['attribution'] as String? ?? '© colaboradores do OpenStreetMap',
    );
  }
}

/// Dica ecológica do dia.
class DailyTip {
  const DailyTip({
    required this.text,
    required this.categoryLabel,
    required this.icon,
  });

  final String text;
  final String categoryLabel;
  final IconData icon;

  factory DailyTip.fromApi(Map<String, dynamic> json) => DailyTip(
    text: json['text'] as String? ?? '',
    categoryLabel: json['categoryLabel'] as String? ?? '',
    icon: IconCatalog.resolve(json['icon'] as String?),
  );
}

/// Tudo o que vem do bairro e não é do próprio usuário: estatísticas, meta
/// coletiva, ranking, pontos de coleta, mapa e dica do dia.
///
/// Os números são calculados pela API sobre os registros de todos os
/// usuários; nada aqui é fixo no código.
class NeighborhoodService extends ChangeNotifier {
  NeighborhoodService._();

  static final NeighborhoodService instance = NeighborhoodService._();

  CommunityStats? _stats;
  List<CollectionPoint> _points = const [];
  DailyTip? _tip;
  CommunityMapData? _map;
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  CommunityStats? get stats => _stats;

  /// Pontos de coleta, do mais perto para o mais longe.
  List<CollectionPoint> get collectionPoints => _points;

  DailyTip? get tip => _tip;

  /// Dados do mapa (carregados por [loadMap]).
  CommunityMapData? get map => _map;

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  /// Carrega estatísticas, pontos de coleta e dica do dia.
  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/community/stats'),
        ApiClient.instance.get('/collection-points'),
        ApiClient.instance.get('/tips/today'),
      ]);
      _stats = CommunityStats.fromApi(results[0] as Map<String, dynamic>);
      _points = List.unmodifiable([
        for (final item in (results[1]['points'] as List?) ?? const [])
          CollectionPoint.fromApi(item as Map<String, dynamic>),
      ]);
      final tip = results[2]['tip'];
      _tip = tip is Map<String, dynamic> ? DailyTip.fromApi(tip) : null;
      _loaded = true;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Recarrega só as estatísticas (depois de registrar uma ação, por exemplo).
  Future<void> refreshStats() async {
    final data = await ApiClient.instance.get('/community/stats');
    _stats = CommunityStats.fromApi(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<CommunityMapData> loadMap() async {
    final data = await ApiClient.instance.get('/community/map');
    final map = CommunityMapData.fromApi(data as Map<String, dynamic>);
    _map = map;
    notifyListeners();
    return map;
  }

  void reset() {
    _stats = null;
    _points = const [];
    _tip = null;
    _map = null;
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
