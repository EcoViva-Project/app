import '../services/user_progress_service.dart';

/// Água poupada traduzida em coisas do dia a dia: garrafões de 20 litros e
/// dias de água para uma pessoa.
///
/// Só contas, sem tela: as frases saem prontas para a Início e o Progresso.
class WaterEquivalents {
  const WaterEquivalents._({
    required this.liters,
    required this.jugs,
    required this.personDays,
  });

  /// Litros de um garrafão de água.
  static const int litersPerJug = 20;

  /// Litros por dia que a ONU considera suficientes para uma pessoa.
  static const int litersPerPersonPerDay = 110;

  /// Litros poupados no total.
  final int liters;

  /// Garrafões de 20 litros cheios (arredondado para baixo).
  final int jugs;

  /// Dias de água para uma pessoa (arredondado para baixo).
  final int personDays;

  /// Equivalências de [liters], ou `null` abaixo de um garrafão (nunca
  /// "0 garrafões").
  static WaterEquivalents? of(int liters) {
    if (liters < litersPerJug) return null;
    return WaterEquivalents._(
      liters: liters,
      jugs: liters ~/ litersPerJug,
      personDays: liters ~/ litersPerPersonPerDay,
    );
  }

  static String _count(int count, String singular, String plural) =>
      '${UserProgressService.formatNumber(count)} '
      '${count == 1 ? singular : plural}';

  /// "76 garrafões de 20 litros".
  String get jugsText =>
      '${_count(jugs, 'garrafão', 'garrafões')} de $litersPerJug litros';

  /// "13 dias de água para uma pessoa".
  String get personDaysText =>
      '${_count(personDays, 'dia', 'dias')} de água para uma pessoa';

  /// Linha curta para a Início: "≈ 76 garrafões de 20 L".
  String get shortLine =>
      '≈ ${_count(jugs, 'garrafão', 'garrafões')} de $litersPerJug L';

  /// A mesma linha para leitores de tela: "cerca de 76 garrafões de 20 litros".
  String get spokenShortLine => 'cerca de $jugsText';

  /// Frase completa para o Progresso, com a referência de 110 litros.
  String get sentence {
    final total = _count(liters, 'litro poupado', 'litros poupados');
    final reference =
        'A ONU considera $litersPerPersonPerDay litros por dia o suficiente '
        'para uma pessoa.';
    if (personDays == 0) {
      return 'Seus $total equivalem a cerca de $jugsText. $reference';
    }
    return 'Seus $total equivalem a cerca de $jugsText, ou '
        '$personDaysText. $reference';
  }
}
