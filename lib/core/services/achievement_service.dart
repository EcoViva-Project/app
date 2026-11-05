import 'package:flutter/material.dart';

import 'action_history_service.dart';
import 'api_client.dart';
import 'icon_catalog.dart';
import 'user_progress_service.dart';

/// Definição de um selo/conquista e seu progresso atual.
class Achievement {
  const Achievement({
    required this.icon,
    required this.title,
    required this.points,
    required this.description,
    required this.current,
    required this.target,
    this.unlockedOn,
    this.progressLabel,
    this.missing,
  });

  final IconData icon;
  final String title;
  final int points;
  final String description;
  final int current;
  final int target;
  final String? unlockedOn;
  final String? progressLabel;
  final String? missing;

  bool get isUnlocked => current >= target;

  double get progress => (current / target).clamp(0.0, 1.0).toDouble();

  factory Achievement.fromApi(Map<String, dynamic> json) {
    return Achievement(
      icon: IconCatalog.resolve(json['icon'] as String?),
      title: json['title'] as String? ?? 'Conquista',
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      current: (json['current'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 1,
      unlockedOn: json['unlockedOn'] as String?,
      progressLabel: json['progressLabel'] as String?,
      missing: json['missing'] as String?,
    );
  }
}

/// Conquistas carregadas da API, com cálculo local de fallback.
class AchievementService {
  AchievementService._();

  static final AchievementService instance = AchievementService._();

  List<Achievement>? _cache;

  static const Set<String> _baseCategories = {
    'Água',
    'Reciclagem',
    'Alimentação',
  };

  static const Map<String, String> _categoryNames = {
    'Água': 'Água',
    'Reciclagem': 'Reciclagem',
    'Alimentação': 'Alimentação',
    'Transporte': 'Mobilidade Urbana / Transporte sustentável',
    'Energia': 'Energia',
    'Espaços Públicos': 'Espaços Públicos',
  };

  List<ActionRecord> get _records => ActionHistoryService.instance.records;

  Set<String> get _categories {
    return {
      ..._baseCategories,
      ..._records.map((record) => record.categoryLabel),
    };
  }

  int get _organicActions =>
      2 +
      _records.where((record) => record.categoryLabel == 'Alimentação').length;

  int get _activeTrips =>
      2 +
      _records.where((record) => record.categoryLabel == 'Transporte').length;

  int get _energyActions =>
      1 + _records.where((record) => record.categoryLabel == 'Energia').length;

  List<Achievement> get achievements => _cache ?? _localAchievements;

  List<Achievement> get unlocked =>
      achievements.where((achievement) => achievement.isUnlocked).toList();

  List<Achievement> get inProgress =>
      achievements.where((achievement) => !achievement.isUnlocked).toList();

  Achievement? get nextAchievement {
    final candidates =
        inProgress.toList()..sort((a, b) => b.progress.compareTo(a.progress));
    return candidates.isEmpty ? null : candidates.first;
  }

  bool get isLoaded => _cache != null;

  Future<void> load() async {
    final data = await ApiClient.instance.get('/progress/achievements');
    applyAchievements(
      ((data['achievements'] as List?) ?? const [])
          .map((item) => Achievement.fromApi(item as Map<String, dynamic>))
          .toList(),
    );
  }

  void applyAchievements(List<Achievement> achievements) {
    _cache = List.unmodifiable(achievements);
  }

  void reset() {
    _cache = null;
  }

  List<Achievement> get _localAchievements {
    final progress = UserProgressService.instance;
    final categories = _categories;
    final missingCategories =
        _categoryNames.keys
            .where((category) => !categories.contains(category))
            .map((category) => _categoryNames[category]!)
            .toList();

    return [
      Achievement(
        icon: Icons.eco,
        title: 'Primeiros Passos',
        points: 30,
        description: 'Registrou sua primeira ação sustentável no aplicativo.',
        current: progress.actionsCount,
        target: 1,
        unlockedOn: '14 de Outubro',
      ),
      Achievement(
        icon: Icons.water_drop,
        title: 'Guardião da Água',
        points: 50,
        description: 'Poupou mais de 20 litros de água em hábitos diários.',
        current: progress.litersSaved,
        target: 20,
        unlockedOn: '18 de Outubro',
      ),
      Achievement(
        icon: Icons.calendar_month,
        title: 'Consistência Verde',
        points: 60,
        description: 'Realizou ações ecológicas por 4 dias seguidos na semana.',
        current: progress.activeDays,
        target: 4,
        unlockedOn: '22 de Outubro',
      ),
      Achievement(
        icon: Icons.diversity_1,
        title: 'Força Coletiva',
        points: 80,
        description: 'Participou de 1 desafio coletivo do seu bairro.',
        current: 1,
        target: 1,
        unlockedOn: '23 de Outubro',
      ),
      Achievement(
        icon: Icons.category,
        title: 'Consciência Plena',
        points: 100,
        description: 'Experimente hábitos em 4 categorias diferentes.',
        current: categories.length,
        target: 4,
        progressLabel: '${categories.length} de 4 categorias experimentadas',
        missing:
            missingCategories.isEmpty
                ? null
                : 'Falta apenas: ${missingCategories.first}.',
      ),
      Achievement(
        icon: Icons.compost,
        title: 'Mestre da Compostagem',
        points: 70,
        description: 'Registre 5 ações de compostagem ou separação orgânica.',
        current: _organicActions,
        target: 5,
        progressLabel: '$_organicActions de 5 concluídas',
      ),
      Achievement(
        icon: Icons.handshake,
        title: 'Vizinho Exemplar',
        points: 150,
        description: 'Complete 3 desafios coletivos com a comunidade.',
        current: 1,
        target: 3,
        progressLabel: '1 de 3 concluídos',
      ),
      Achievement(
        icon: Icons.water_drop_outlined,
        title: 'Economizador de Água',
        points: 90,
        description: 'Reduza 30% do consumo de água por 7 dias.',
        current: 4,
        target: 7,
        progressLabel: '4 de 7 dias concluídos',
      ),
      Achievement(
        icon: Icons.directions_bike,
        title: 'Mobilidade Ativa',
        points: 60,
        description: 'Faça 5 trajetos curtos a pé ou de bicicleta.',
        current: _activeTrips,
        target: 5,
        progressLabel: '$_activeTrips de 5 trajetos concluídos',
      ),
      Achievement(
        icon: Icons.bolt,
        title: 'Guardião da Energia',
        points: 80,
        description: 'Registre 6 ações de economia de energia.',
        current: _energyActions,
        target: 6,
        progressLabel: '$_energyActions de 6 concluídas',
      ),
    ];
  }
}
