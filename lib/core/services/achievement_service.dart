import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'icon_catalog.dart';

/// Um selo/conquista e o progresso do usuário nele.
class Achievement {
  const Achievement({
    required this.key,
    required this.icon,
    required this.title,
    required this.points,
    required this.description,
    required this.current,
    required this.target,
    required this.isUnlocked,
    this.unlockedOn,
    this.progressLabel,
    this.missing,
  });

  final String key;
  final IconData icon;
  final String title;

  /// Bônus creditado uma única vez, ao desbloquear.
  final int points;
  final String description;
  final int current;
  final int target;
  final bool isUnlocked;

  /// Data do desbloqueio, já formatada ("9 de novembro").
  final String? unlockedOn;
  final String? progressLabel;
  final String? missing;

  double get progress =>
      isUnlocked || target <= 0
          ? 1
          : (current / target).clamp(0.0, 1.0).toDouble();

  factory Achievement.fromApi(Map<String, dynamic> json) {
    final current = (json['current'] as num?)?.toInt() ?? 0;
    final target = (json['target'] as num?)?.toInt() ?? 1;
    return Achievement(
      key: json['key'] as String? ?? json['title'] as String? ?? '',
      icon: IconCatalog.resolve(json['icon'] as String?),
      title: json['title'] as String? ?? 'Conquista',
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      current: current,
      target: target,
      isUnlocked: json['isUnlocked'] as bool? ?? current >= target,
      unlockedOn: json['unlockedOn'] as String?,
      progressLabel: json['progressLabel'] as String?,
      missing: json['missing'] as String?,
    );
  }

  static List<Achievement> listFromApi(Object? json) => [
    for (final item in (json as List?) ?? const [])
      Achievement.fromApi(item as Map<String, dynamic>),
  ];
}

/// Conquistas carregadas da API (`/progress/achievements`).
class AchievementService extends ChangeNotifier {
  AchievementService._();

  static final AchievementService instance = AchievementService._();

  List<Achievement> _items = const [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<Achievement> get achievements => _items;

  List<Achievement> get unlocked =>
      _items.where((achievement) => achievement.isUnlocked).toList();

  List<Achievement> get inProgress =>
      _items.where((achievement) => !achievement.isUnlocked).toList();

  /// A conquista ainda bloqueada que está mais perto de sair.
  Achievement? get nextAchievement {
    final candidates =
        inProgress..sort((a, b) => b.progress.compareTo(a.progress));
    return candidates.isEmpty ? null : candidates.first;
  }

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/progress/achievements');
      _items = List.unmodifiable(Achievement.listFromApi(data['achievements']));
      _loaded = true;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyAchievements(List<Achievement> achievements) {
    _items = List.unmodifiable(achievements);
    _loaded = true;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _items = const [];
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
