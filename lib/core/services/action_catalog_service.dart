import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'icon_catalog.dart';

/// Uma ação sustentável do catálogo, com os limites e o uso do usuário.
class EcoAction {
  const EcoAction({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryLabel,
    required this.icon,
    required this.points,
    required this.liters,
    required this.usedToday,
    required this.usedThisWeek,
    required this.tags,
    this.neighborsToday = 0,
    this.dailyLimit,
    this.weeklyLimit,
    this.remaining,
    this.info,
    this.infoIcon,
    this.footerInfo,
    this.footerIcon,
  });

  final int id;
  final String title;
  final String description;

  /// Identificador da categoria (por exemplo `agua`).
  final String category;

  /// Nome da categoria para exibir (por exemplo "Água").
  final String categoryLabel;
  final IconData icon;

  /// Pontos por registro.
  final int points;
  final int liters;

  /// Quantas vezes a ação pode ser registrada por dia; `null` = sem limite diário.
  final int? dailyLimit;

  /// Quantas vezes por semana; `null` = sem limite semanal.
  final int? weeklyLimit;
  final int usedToday;
  final int usedThisWeek;

  /// Quantas outras pessoas registraram esta ação hoje.
  final int neighborsToday;

  /// Quantos registros ainda cabem agora; `null` = sem limite.
  final int? remaining;
  final String? info;
  final IconData? infoIcon;
  final List<String> tags;
  final String? footerInfo;
  final IconData? footerIcon;

  bool get canRegister => remaining == null || remaining! > 0;

  /// "1 de 2 hoje" ou "1 de 1 nesta semana"; `null` sem limite.
  String? get usageLabel {
    if (dailyLimit != null) return '$usedToday de $dailyLimit hoje';
    if (weeklyLimit != null) return '$usedThisWeek de $weeklyLimit nesta semana';
    return null;
  }

  /// "7 vizinhos registraram hoje"; `null` quando ninguém registrou.
  String? get neighborsTodayLabel {
    if (neighborsToday <= 0) return null;
    return neighborsToday == 1
        ? '1 vizinho registrou hoje'
        : '$neighborsToday vizinhos registraram hoje';
  }

  /// Maior quantidade aceita em um único registro.
  int get maxQuantity => remaining == null ? 10 : remaining!.clamp(0, 10);

  /// "Até 2 por dia" ou "1 por semana".
  String? get limitLabel {
    if (dailyLimit != null) return 'Até $dailyLimit por dia';
    if (weeklyLimit != null) {
      return weeklyLimit == 1 ? '1 por semana' : 'Até $weeklyLimit por semana';
    }
    return null;
  }

  /// "Já registrada hoje", "Já registrada nesta semana" ou `null`.
  String? get blockedLabel {
    if (canRegister) return null;
    if (weeklyLimit != null && usedThisWeek >= weeklyLimit!) {
      return 'Volta na segunda-feira';
    }
    return 'Volta amanhã';
  }

  factory EcoAction.fromApi(Map<String, dynamic> json) {
    final infoIconName = json['infoIcon'] as String?;
    final footerIconName = json['footerIcon'] as String?;
    return EcoAction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Ação sustentável',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryLabel: json['categoryLabel'] as String? ?? 'Ação',
      icon: IconCatalog.resolve(json['icon'] as String?),
      points: (json['points'] as num?)?.toInt() ?? 0,
      liters: (json['liters'] as num?)?.toInt() ?? 0,
      dailyLimit: (json['dailyLimit'] as num?)?.toInt(),
      weeklyLimit: (json['weeklyLimit'] as num?)?.toInt(),
      usedToday: (json['usedToday'] as num?)?.toInt() ?? 0,
      usedThisWeek: (json['usedThisWeek'] as num?)?.toInt() ?? 0,
      neighborsToday: (json['neighborsToday'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt(),
      info: json['info'] as String?,
      infoIcon: infoIconName == null ? null : IconCatalog.resolve(infoIconName),
      tags: [
        for (final tag in (json['tags'] as List?) ?? const []) tag.toString(),
      ],
      footerInfo: json['footerInfo'] as String?,
      footerIcon:
          footerIconName == null ? null : IconCatalog.resolve(footerIconName),
    );
  }
}

/// Uma categoria de ação presente no catálogo.
class ActionCategory {
  const ActionCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Catálogo de ações sustentáveis, carregado de `GET /actions`.
class ActionCatalogService extends ChangeNotifier {
  ActionCatalogService._();

  static final ActionCatalogService instance = ActionCatalogService._();

  final List<EcoAction> _actions = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<EcoAction> get actions => List.unmodifiable(_actions);

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  /// Categorias na ordem em que aparecem no catálogo.
  List<ActionCategory> get categories {
    final seen = <String>{};
    return [
      for (final action in _actions)
        if (seen.add(action.category))
          ActionCategory(
            id: action.category,
            label: action.categoryLabel,
            icon: action.icon,
          ),
    ];
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/actions');
      _actions
        ..clear()
        ..addAll(
          ((data['actions'] as List?) ?? const []).map(
            (item) => EcoAction.fromApi(item as Map<String, dynamic>),
          ),
        );
      _loaded = true;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  EcoAction? byId(int id) {
    for (final action in _actions) {
      if (action.id == id) return action;
    }
    return null;
  }

  /// Ações de uma categoria, pelo nome exibido (por exemplo "Água").
  List<EcoAction> byCategoryLabel(String label) =>
      _actions.where((action) => action.categoryLabel == label).toList();

  void reset() {
    _actions.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
