import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;

import 'achievement_service.dart';
import 'action_catalog_service.dart';
import 'api_client.dart';
import 'challenge_service.dart';
import 'icon_catalog.dart';
import 'neighborhood_service.dart';
import 'notification_service.dart';
import 'photo_proof.dart';
import 'user_progress_service.dart';

/// Um lançamento do histórico: ação registrada ou bônus.
class ActionRecord {
  ActionRecord({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.icon,
    required this.points,
    required this.liters,
    required this.dateTime,
    this.basePoints,
    this.kind = 'action',
    this.notes,
    this.quantity = 1,
    this.photo,
  });

  final String id;
  final String title;
  final String categoryLabel;
  final IconData icon;

  /// Pontos creditados de fato (pode ser menos que [basePoints] por causa do
  /// teto semanal).
  final int points;

  /// Pontos que a ação vale sem considerar o teto.
  final int? basePoints;
  final int liters;
  final DateTime dateTime;

  /// `action`, `challenge` (bônus de desafio) ou `achievement` (bônus de selo).
  final String kind;
  final String? notes;
  final int quantity;

  /// Foto de comprovação (opcional; não muda os pontos).
  final RecordPhoto? photo;

  bool get isAction => kind == 'action';

  bool get isBonus => !isAction;

  /// Parte dos pontos ficou de fora por causa do teto semanal.
  bool get capped => (basePoints ?? points) > points;

  factory ActionRecord.fromApi(Map<String, dynamic> json) {
    return ActionRecord(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Ação sustentável',
      categoryLabel: json['categoryLabel'] as String? ?? 'Ação',
      icon: IconCatalog.resolve(json['icon'] as String?),
      points: (json['points'] as num?)?.toInt() ?? 0,
      basePoints: (json['basePoints'] as num?)?.toInt(),
      liters: (json['liters'] as num?)?.toInt() ?? 0,
      dateTime:
          DateTime.tryParse(json['dateTime'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      kind: json['kind'] as String? ?? 'action',
      notes: json['notes'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      photo: RecordPhoto.fromApi(json['photo']),
    );
  }
}

/// Resultado de registrar uma ação, pronto para a tela de confirmação.
class RegisteredAction {
  const RegisteredAction({
    required this.record,
    required this.capReached,
    required this.newAchievements,
    required this.challengeUpdates,
  });

  final ActionRecord record;

  /// O teto semanal foi atingido exatamente neste registro.
  final bool capReached;
  final List<Achievement> newAchievements;
  final List<Challenge> challengeUpdates;

  int get bonusPoints =>
      newAchievements.fold<int>(0, (sum, item) => sum + item.points) +
      challengeUpdates
          .where((challenge) => challenge.completed)
          .fold<int>(0, (sum, challenge) => sum + challenge.pointsReward);
}

/// Atividade de um dia, para os gráficos da semana.
class DayActivity {
  const DayActivity({
    required this.date,
    required this.points,
    required this.actions,
  });

  final DateTime date;
  final int points;
  final int actions;

  bool get active => actions > 0;
}

/// Histórico de ações carregado da API e registro de novas ações.
class ActionHistoryService extends ChangeNotifier {
  ActionHistoryService._();

  static final ActionHistoryService instance = ActionHistoryService._();

  static const List<String> weekdayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  final List<ActionRecord> _records = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  RegisteredAction? _lastSubmission;

  /// Todos os lançamentos, do mais recente para o mais antigo.
  List<ActionRecord> get records => List.unmodifiable(_records);

  /// Só as ações (sem os bônus de desafio e de conquista).
  List<ActionRecord> get actions =>
      _records.where((record) => record.isAction).toList();

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  /// Último registro feito nesta sessão (usado pela tela de confirmação).
  RegisteredAction? get lastSubmission => _lastSubmission;

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get(
        '/records',
        query: const {'limit': '500'},
      );
      final list = (data['records'] as List?) ?? const [];
      _records
        ..clear()
        ..addAll(
          list.map(
            (item) => ActionRecord.fromApi(item as Map<String, dynamic>),
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

  /// Registra uma ação e atualiza saldo, conquistas, desafios e notificações.
  Future<RegisteredAction> submitAction({
    required int actionId,
    required int quantity,
    String? notes,
    String? photo,
  }) async {
    final data =
        await ApiClient.instance.post('/actions/$actionId/records', {
              'quantity': quantity,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
              if (photo != null) 'photo': photo,
            })
            as Map<String, dynamic>;

    final record = ActionRecord.fromApi(data['record'] as Map<String, dynamic>);
    _records.insert(0, record);

    if (data['summary'] is Map<String, dynamic>) {
      UserProgressService.instance.applySummary(
        data['summary'] as Map<String, dynamic>,
      );
    }
    if (data['achievements'] is List) {
      AchievementService.instance.applyAchievements(
        Achievement.listFromApi(data['achievements']),
      );
    }
    final challengeUpdates = ChallengeService.instance.applyUpdates(
      data['challengeUpdates'],
    );
    final newAchievements = Achievement.listFromApi(data['newAchievements']);

    final result = RegisteredAction(
      record: record,
      capReached: data['capReached'] as bool? ?? false,
      newAchievements: newAchievements,
      challengeUpdates: challengeUpdates,
    );
    _lastSubmission = result;
    notifyListeners();

    // Bônus entram no histórico como lançamentos próprios; os limites da ação
    // e as notificações também mudaram. Erros aqui não desfazem o registro.
    if (newAchievements.isNotEmpty ||
        challengeUpdates.any((challenge) => challenge.completed)) {
      load().catchError((_) {});
    }
    ActionCatalogService.instance.load().catchError((_) {});
    NotificationService.instance.load().catchError((_) {});
    NeighborhoodService.instance.refreshStats().catchError((_) {});

    return result;
  }

  /// Os sete dias (segunda a domingo) da semana atual.
  List<DayActivity> currentWeek({DateTime? now}) {
    final today = now ?? DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - DateTime.monday));
    return [
      for (var i = 0; i < 7; i++) _dayActivity(monday.add(Duration(days: i))),
    ];
  }

  DayActivity _dayActivity(DateTime day) {
    var points = 0;
    var count = 0;
    for (final record in _records) {
      final when = record.dateTime;
      if (when.year != day.year ||
          when.month != day.month ||
          when.day != day.day) {
        continue;
      }
      points += record.points;
      if (record.isAction) count++;
    }
    return DayActivity(date: day, points: points, actions: count);
  }

  /// Quantidade de ações por categoria, da mais frequente para a menos.
  List<MapEntry<String, int>> actionsByCategory() {
    final counts = <String, int>{};
    for (final record in _records) {
      if (!record.isAction) continue;
      counts[record.categoryLabel] = (counts[record.categoryLabel] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  void clear() {
    _records.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    _lastSubmission = null;
    notifyListeners();
  }
}
