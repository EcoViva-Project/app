import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:eco_app/core/services/achievement_service.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/user_progress_service.dart';

ActionRecord _record({
  required String category,
  int points = 30,
  int liters = 10,
}) {
  return ActionRecord(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: 'Ação de $category',
    categoryLabel: category,
    icon: Icons.eco,
    points: points,
    liters: liters,
    dateTime: DateTime.now(),
  );
}

void main() {
  setUp(() {
    ActionHistoryService.instance.clear();
  });

  test('progresso derivado mantém a base e soma registros', () {
    final progress = UserProgressService.instance;

    expect(progress.points, 1240);
    expect(progress.actionsCount, 42);
    expect(progress.activeDays, 12);
    expect(progress.litersSaved, 28);
    expect(progress.monthlyActions, 14);
    expect(progress.monthlyGoalProgress, closeTo(14 / 17, 0.0001));

    ActionHistoryService.instance.addRecord(_record(category: 'Água'));

    expect(progress.points, 1270);
    expect(progress.actionsCount, 43);
    expect(progress.litersSaved, 38);
    expect(progress.monthlyActions, 15);
    expect(progress.formattedPoints, '1.270');
  });

  test('conquistas refletem categorias e metas registradas', () {
    final achievements = AchievementService.instance;

    expect(achievements.achievements.length, 10);
    expect(achievements.unlocked.length, 4);
    expect(achievements.nextAchievement?.title, 'Consciência Plena');

    ActionHistoryService.instance.addRecord(_record(category: 'Transporte'));

    expect(achievements.unlocked.length, 5);
    final consciencia = achievements.achievements.firstWhere(
      (achievement) => achievement.title == 'Consciência Plena',
    );
    expect(consciencia.isUnlocked, isTrue);
    expect(achievements.nextAchievement?.title, 'Mobilidade Ativa');

    for (var i = 0; i < 3; i++) {
      ActionHistoryService.instance.addRecord(_record(category: 'Alimentação'));
    }

    final compostagem = achievements.achievements.firstWhere(
      (achievement) => achievement.title == 'Mestre da Compostagem',
    );
    expect(compostagem.isUnlocked, isTrue);
    expect(compostagem.current, 5);
  });
}
