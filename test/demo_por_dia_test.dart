import 'dart:math';

import 'package:eco_app/core/local/economy.dart';
import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_seed.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A demonstração é criada em relação ao dia em que o app é aberto (ou em que
/// se toca em "Restaurar demonstração"). Como cada ação tem limite por dia, a
/// semana só chega perto do teto a partir da quarta-feira.
///
/// Este teste percorre a semana da feira (segunda 09/11 a domingo 15/11/2026)
/// e trava o que o roteiro de apresentação promete para a quarta, dia da
/// feira, em qualquer horário. Nos outros dias ele confere o mínimo e imprime
/// a tabela usada em `OFFLINE-NA-FEIRA.md`.
void main() {
  const names = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  const fairDay = 2; // quarta-feira, 11/11/2026

  for (var i = 0; i < 7; i++) {
    final hours = i == fairDay ? [7, 8, 9, 12, 15, 18, 21] : [9, 15, 20];
    for (final hour in hours) {
      // Horário de Brasília (UTC−3).
      final now = DateTime.utc(2026, 11, 9 + i, hour + 3);
      final label = '${names[i]} ${Economy.dateKey(now)} ${hour}h';

      test('roteiro da demonstração: $label', () async {
        final api = LocalApi(
          LocalDatabase(MemoryStore()),
          clock: () => now,
          random: Random(7),
        );
        final login = await api.handle(
          'POST',
          '/auth/login',
          body: {
            'email': LocalSeed.demoEmail,
            'password': LocalSeed.demoPassword,
          },
        );
        final token = login['token'] as String;
        Future<dynamic> call(String method, String path, {Object? body}) =>
            api.handle(method, path, body: body, token: token);

        final summary =
            (await call('GET', '/progress'))['summary'] as Map<String, dynamic>;
        final lightsBefore =
            (await call('GET', '/actions/5'))['action'] as Map<String, dynamic>;
        final compostBefore =
            (await call('GET', '/actions/4'))['action'] as Map<String, dynamic>;

        // Passo do roteiro: "Apagar luzes" destrava a conquista de Energia.
        final lights =
            await call('POST', '/actions/5/records', body: {'quantity': 1})
                as Map<String, dynamic>;
        final unlocked = (lights['newAchievements'] as List)
            .map((a) => a['key'])
            .toList();

        // Passo seguinte: a compostagem encosta no teto.
        final compost =
            await call('POST', '/actions/4/records', body: {'quantity': 1})
                as Map<String, dynamic>;

        // ignore: avoid_print
        print(
          '$label | semana ${summary['weeklyPoints']}/${summary['weeklyCap']} '
          '| luzes +${lights['record']['points']} conquistas $unlocked '
          '| compostagem +${compost['record']['points']} '
          'teto ${compost['capReached']}',
        );

        // Em qualquer dia: as duas ações do roteiro estão livres e a semana
        // nunca começa acima da folga deixada para a demonstração.
        expect(lightsBefore['remaining'], 1, reason: 'luzes disponível');
        expect(compostBefore['remaining'], 1, reason: 'compostagem disponível');
        expect(lights['record']['points'], 5);
        expect(
          summary['weeklyPoints'],
          lessThanOrEqualTo(Economy.weeklyCap - 25),
        );

        if (i != fairDay) return;

        // No dia da feira, o roteiro completo.
        expect(summary['weeklyPoints'], Economy.weeklyCap - 25);
        expect(unlocked, contains('guardiao-da-energia'));
        expect(compost['record']['basePoints'], 25);
        expect(compost['record']['points'], 20);
        expect(compost['capReached'], isTrue);
      });
    }
  }
}
