import 'package:flutter/material.dart';

import 'achievement_service.dart';
import 'api_client.dart';
import 'icon_catalog.dart';
import 'user_progress_service.dart';

class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.targetSteps,
    required this.pointsReward,
    required this.participants,
    required this.daysLeft,
    required this.isWeekly,
    required this.joined,
    required this.completedSteps,
    required this.completed,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final int targetSteps;
  final int pointsReward;
  final int participants;
  final int daysLeft;
  final bool isWeekly;
  final bool joined;
  final int completedSteps;
  final bool completed;

  double get progress =>
      targetSteps == 0 ? 0 : (completedSteps / targetSteps).clamp(0.0, 1.0);

  factory Challenge.fromApi(Map<String, dynamic> json) {
    return Challenge(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Desafio',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Comunidade',
      icon: IconCatalog.resolve(
        json['icon'] as String?,
        fallback: Icons.emoji_events,
      ),
      targetSteps: (json['targetSteps'] as num?)?.toInt() ?? 1,
      pointsReward: (json['pointsReward'] as num?)?.toInt() ?? 0,
      participants: (json['participants'] as num?)?.toInt() ?? 0,
      daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
      isWeekly: json['isWeekly'] as bool? ?? false,
      joined: json['joined'] as bool? ?? false,
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class ChallengeService extends ChangeNotifier {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  final List<Challenge> _challenges = [];

  List<Challenge> get challenges => List.unmodifiable(_challenges);

  List<Challenge> get ongoing =>
      _challenges
          .where((challenge) => challenge.joined && !challenge.completed)
          .toList();

  List<Challenge> get available =>
      _challenges.where((challenge) => !challenge.joined).toList();

  Future<void> load() async {
    final data = await ApiClient.instance.get('/challenges');
    _challenges
      ..clear()
      ..addAll(
        ((data['challenges'] as List?) ?? const []).map(
          (item) => Challenge.fromApi(item as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  Challenge? byId(int id) {
    for (final challenge in _challenges) {
      if (challenge.id == id) return challenge;
    }
    return null;
  }

  Future<Challenge?> fetch(int id) async {
    final data = await ApiClient.instance.get('/challenges/$id');
    return _replace(data['challenge'] as Map<String, dynamic>);
  }

  Future<Challenge?> join(int id) async {
    final data = await ApiClient.instance.post('/challenges/$id/join');
    return _replace(data['challenge'] as Map<String, dynamic>);
  }

  Future<Challenge?> addProgress(int id, {int steps = 1}) async {
    final data = await ApiClient.instance.post('/challenges/$id/progress', {
      'steps': steps,
    });
    if (data['summary'] is Map<String, dynamic>) {
      UserProgressService.instance.applySummary(
        data['summary'] as Map<String, dynamic>,
      );
    }
    if (data['achievements'] is List) {
      AchievementService.instance.applyAchievements(
        (data['achievements'] as List)
            .map((item) => Achievement.fromApi(item as Map<String, dynamic>))
            .toList(),
      );
    }
    return _replace(data['challenge'] as Map<String, dynamic>);
  }

  Challenge? _replace(Map<String, dynamic> json) {
    final challenge = Challenge.fromApi(json);
    final index = _challenges.indexWhere((item) => item.id == challenge.id);
    if (index >= 0) {
      _challenges[index] = challenge;
    } else {
      _challenges.add(challenge);
    }
    notifyListeners();
    return challenge;
  }

  void reset() {
    _challenges.clear();
    notifyListeners();
  }
}
