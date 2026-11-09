import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Resumo do usuário: saldo, nível, teto semanal e totais.
///
/// Todos os números vêm da API (`/progress`). Antes da primeira carga os
/// valores são zero e [isLoaded] é falso: as telas devem mostrar carregamento
/// ou erro, nunca números de exemplo.
class UserProgressService extends ChangeNotifier {
  UserProgressService._();

  static final UserProgressService instance = UserProgressService._();

  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;

  bool get isLoaded => _summary != null;

  bool get loading => _loading;

  String? get error => _error;

  Map<String, dynamic>? get summary => _summary;

  int _int(String key) => (_summary?[key] as num?)?.toInt() ?? 0;

  /// Saldo disponível para resgates (ganhos menos gastos).
  int get points => _int('points');

  /// Total de pontos já ganhos; é ele que define o nível.
  int get pointsEarned => _int('pointsEarned');

  int get pointsSpent => _int('pointsSpent');

  int get actionsCount => _int('actionsCount');

  int get activeDays => _int('activeDays');

  int get monthlyActions => _int('monthlyActions');

  int get monthlyGoal => _int('monthlyGoal');

  double get monthlyGoalProgress =>
      (_summary?['monthlyGoalProgress'] as num?)?.toDouble() ?? 0;

  int get litersSaved => _int('litersSaved');

  String get level => _summary?['level'] as String? ?? '';

  String get levelName => _summary?['levelName'] as String? ?? '';

  int get levelNumber => _int('levelNumber');

  int get levelFloor => _int('levelFloor');

  /// Pontos ganhos necessários para o próximo nível; `null` no último nível.
  int? get nextLevelAt => (_summary?['nextLevelAt'] as num?)?.toInt();

  int get pointsToNextLevel {
    final next = nextLevelAt;
    return next == null ? 0 : (next - pointsEarned).clamp(0, next);
  }

  double get levelProgress {
    final next = nextLevelAt;
    if (next == null) return 1;
    final span = next - levelFloor;
    if (span <= 0) return 1;
    return ((pointsEarned - levelFloor) / span).clamp(0.0, 1.0);
  }

  /// Pontos de ações já creditados nesta semana.
  int get weeklyPoints => _int('weeklyPoints');

  /// Teto semanal de pontos de ações.
  int get weeklyCap => _int('weeklyCap');

  int get weeklyRemaining => _int('weeklyRemaining');

  bool get hasWeeklyCap => weeklyCap > 0;

  bool get capReached => hasWeeklyCap && weeklyRemaining <= 0;

  double get weeklyProgress =>
      hasWeeklyCap ? (weeklyPoints / weeklyCap).clamp(0.0, 1.0) : 0;

  /// Quando o teto zera (segunda-feira, 00:00 de Brasília).
  DateTime? get weekResetsAt =>
      DateTime.tryParse(_summary?['weekResetsAt'] as String? ?? '')?.toLocal();

  /// Dias seguidos com ação registrada, contando hoje ou ontem.
  int get streakDays => _int('streakDays');

  int get bestStreak => _int('bestStreak');

  String get formattedPoints => formatNumber(points);

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/progress');
      _summary = data['summary'] as Map<String, dynamic>;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applySummary(Map<String, dynamic>? summary) {
    if (summary == null) return;
    _summary = summary;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _summary = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  /// 1240 → "1.240".
  static String formatNumber(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// 3200 centavos → "R$ 32,00".
  static String formatMoney(int cents) {
    final reais = cents ~/ 100;
    final rest = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ ${formatNumber(reais)},$rest';
  }
}
