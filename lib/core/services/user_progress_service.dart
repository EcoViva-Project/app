import 'package:flutter/foundation.dart';

import 'action_history_service.dart';
import 'api_client.dart';

/// Estado agregado do usuário.
///
/// Os números vêm da API (`/progress`). Enquanto a primeira carga não acontece
/// — por exemplo em testes unitários —, o serviço mantém a base demonstrativa
/// compatível com o seed do backend.
class UserProgressService extends ChangeNotifier {
  UserProgressService._() {
    ActionHistoryService.instance.addListener(_handleHistoryChanged);
  }

  static final UserProgressService instance = UserProgressService._();

  static const int basePoints = 1240;
  static const int baseActions = 42;
  static const int baseActiveDays = 12;
  static const int baseMonthlyActions = 14;
  static const int baseLitersSaved = 28;
  static const int defaultMonthlyGoal = 17;

  Map<String, dynamic>? _summary;
  bool _loaded = false;

  void _handleHistoryChanged() {
    if (_summary == null) notifyListeners();
  }

  List<ActionRecord> get _records => ActionHistoryService.instance.records;

  bool get isLoaded => _loaded;

  Map<String, dynamic>? get summary => _summary;

  int get points =>
      (_summary?['points'] as num?)?.toInt() ??
      basePoints + _records.fold<int>(0, (sum, record) => sum + record.points);

  int get actionsCount =>
      (_summary?['actionsCount'] as num?)?.toInt() ??
      baseActions + _records.length;

  int get activeDays =>
      (_summary?['activeDays'] as num?)?.toInt() ?? baseActiveDays;

  int get monthlyActions {
    final fromServer = (_summary?['monthlyActions'] as num?)?.toInt();
    if (fromServer != null) return fromServer;
    final now = DateTime.now();
    final recordedThisMonth =
        _records.where((record) {
          return record.dateTime.year == now.year &&
              record.dateTime.month == now.month;
        }).length;
    return baseMonthlyActions + recordedThisMonth;
  }

  int get monthlyGoal =>
      (_summary?['monthlyGoal'] as num?)?.toInt() ?? defaultMonthlyGoal;

  double get monthlyGoalProgress =>
      (_summary?['monthlyGoalProgress'] as num?)?.toDouble() ??
      (monthlyActions / monthlyGoal).clamp(0.0, 1.0).toDouble();

  int get litersSaved =>
      (_summary?['litersSaved'] as num?)?.toInt() ??
      baseLitersSaved +
          _records.fold<int>(0, (sum, record) => sum + record.liters);

  String get level => _summary?['level'] as String? ?? _levelFromPoints(points);

  String get formattedPoints => formatNumber(points);

  Future<void> load() async {
    final data = await ApiClient.instance.get('/progress');
    applySummary(data['summary'] as Map<String, dynamic>);
  }

  void applySummary(Map<String, dynamic>? summary) {
    _summary = summary;
    _loaded = true;
    notifyListeners();
  }

  void reset() {
    _summary = null;
    _loaded = false;
    notifyListeners();
  }

  static String _levelFromPoints(int points) {
    if (points < 500) return 'Semente • Nível 1';
    if (points < 1000) return 'Broto • Nível 2';
    if (points < 1500) return 'Guardiã Verde • Nível 3';
    if (points < 2500) return 'Guardiã do Bairro • Nível 4';
    return 'Guardiã do Planeta • Nível 5';
  }

  static String formatNumber(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
