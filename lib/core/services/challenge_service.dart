import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'icon_catalog.dart';

class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.targetSteps,
    required this.stepMode,
    required this.pointsReward,
    required this.participants,
    required this.durationDays,
    required this.daysLeft,
    required this.isWeekly,
    required this.joined,
    required this.completedSteps,
    required this.completed,
    required this.expired,
    required this.stepDoneToday,
  });

  final int id;
  final String title;
  final String description;

  /// Categoria das ações que fazem o desafio avançar (por exemplo "Água").
  final String category;
  final IconData icon;
  final int targetSteps;

  /// `days`: uma etapa por dia com ação da categoria.
  /// `actions`: uma etapa por ação da categoria.
  final String stepMode;

  /// Bônus creditado ao concluir (não entra no teto semanal).
  final int pointsReward;
  final int participants;
  final int durationDays;

  /// Dias que restam no prazo pessoal (ou a duração, antes de entrar).
  final int daysLeft;
  final bool isWeekly;
  final bool joined;
  final int completedSteps;
  final bool completed;

  /// Entrou, não concluiu e o prazo acabou. Pode recomeçar.
  final bool expired;

  /// No modo por dias: a etapa de hoje já foi contada.
  final bool stepDoneToday;

  bool get countsByDay => stepMode != 'actions';

  bool get inProgress => joined && !completed && !expired;

  double get progress =>
      targetSteps == 0 ? 0 : (completedSteps / targetSteps).clamp(0.0, 1.0);

  /// "3 de 7 dias" ou "2 de 5 ações".
  String get stepsLabel =>
      '$completedSteps de $targetSteps ${countsByDay ? 'dias' : 'ações'}';

  /// "Restam 4 dias", "Resta 1 dia" ou "Último dia".
  String get deadlineLabel {
    if (daysLeft <= 0) return 'Prazo encerrado';
    if (daysLeft == 1) return joined ? 'Último dia' : '1 dia de prazo';
    return joined ? 'Restam $daysLeft dias' : '$daysLeft dias de prazo';
  }

  /// Explica como o desafio avança.
  String get howItWorks =>
      countsByDay
          ? 'Cada dia com uma ação de $category registrada conta uma etapa.'
          : 'Cada ação de $category registrada conta uma etapa.';

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
      stepMode: json['stepMode'] as String? ?? 'days',
      pointsReward: (json['pointsReward'] as num?)?.toInt() ?? 0,
      participants: (json['participants'] as num?)?.toInt() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
      daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
      isWeekly: json['isWeekly'] as bool? ?? false,
      joined: json['joined'] as bool? ?? false,
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      expired: json['expired'] as bool? ?? false,
      stepDoneToday: json['stepDoneToday'] as bool? ?? false,
    );
  }
}

/// Desafios coletivos.
///
/// O progresso não é declarado à mão: ele avança quando o usuário registra
/// ações da categoria do desafio (ver `ActionHistoryService.submitAction`).
class ChallengeService extends ChangeNotifier {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  final List<Challenge> _challenges = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<Challenge> get challenges => List.unmodifiable(_challenges);

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  /// Em andamento: entrou, não concluiu e ainda está no prazo.
  List<Challenge> get ongoing =>
      _challenges.where((challenge) => challenge.inProgress).toList();

  /// Disponíveis: ainda não entrou, ou o prazo venceu e pode recomeçar.
  List<Challenge> get available =>
      _challenges
          .where(
            (challenge) =>
                !challenge.completed &&
                (!challenge.joined || challenge.expired),
          )
          .toList();

  List<Challenge> get completedChallenges =>
      _challenges.where((challenge) => challenge.completed).toList();

  /// Desafio para destacar na tela inicial: um em andamento ou o primeiro
  /// disponível.
  Challenge? get featured {
    final current = ongoing;
    if (current.isNotEmpty) return current.first;
    final open = available;
    return open.isEmpty ? null : open.first;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/challenges');
      _challenges
        ..clear()
        ..addAll(
          ((data['challenges'] as List?) ?? const []).map(
            (item) => Challenge.fromApi(item as Map<String, dynamic>),
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

  Challenge? byId(int id) {
    for (final challenge in _challenges) {
      if (challenge.id == id) return challenge;
    }
    return null;
  }

  Future<Challenge> fetch(int id) async {
    final data = await ApiClient.instance.get('/challenges/$id');
    return _replace(data['challenge'] as Map<String, dynamic>);
  }

  /// Entra no desafio (ou recomeça um desafio vencido).
  Future<Challenge> join(int id) async {
    final data = await ApiClient.instance.post('/challenges/$id/join');
    return _replace(data['challenge'] as Map<String, dynamic>);
  }

  /// Aplica os desafios devolvidos ao registrar uma ação.
  List<Challenge> applyUpdates(Object? json) {
    final updated = <Challenge>[];
    for (final item in (json as List?) ?? const []) {
      updated.add(_replace(item as Map<String, dynamic>, notify: false));
    }
    if (updated.isNotEmpty) notifyListeners();
    return updated;
  }

  Challenge _replace(Map<String, dynamic> json, {bool notify = true}) {
    final challenge = Challenge.fromApi(json);
    final index = _challenges.indexWhere((item) => item.id == challenge.id);
    if (index >= 0) {
      _challenges[index] = challenge;
    } else {
      _challenges.add(challenge);
    }
    if (notify) notifyListeners();
    return challenge;
  }

  void reset() {
    _challenges.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
