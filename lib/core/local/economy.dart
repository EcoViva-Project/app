/// Regras da economia de pontos do EcoViva.
///
/// Este arquivo é a fonte única das regras no aplicativo e espelha
/// `eco-backend/src/services/economy.js`. O raciocínio por trás de cada número
/// está em `ECONOMIA-DE-PONTOS.md`.
library;

class LevelInfo {
  const LevelInfo({
    required this.number,
    required this.name,
    required this.floor,
    required this.next,
  });

  /// 1 a 5.
  final int number;
  final String name;

  /// Pontos ganhos a partir dos quais o nível começa.
  final int floor;

  /// Pontos ganhos necessários para o próximo nível; `null` no último.
  final int? next;

  String get label => '$name • Nível $number';
}

class Economy {
  Economy._();

  /// Teto semanal de pontos ganhos com ações do dia a dia.
  ///
  /// Bônus de desafio concluído e de conquista são prêmios únicos e não
  /// entram no teto.
  static const int weeklyCap = 400;

  /// Referência de preço dos cupons: quantos pontos valem R$ 1 de benefício.
  static const int pointsPerReal = 50;

  /// Horário de Brasília (sem horário de verão desde 2019).
  static const Duration utcOffset = Duration(hours: -3);

  static const List<({int floor, String name})> _levels = [
    (floor: 0, name: 'Semente'),
    (floor: 300, name: 'Broto'),
    (floor: 1000, name: 'Muda'),
    (floor: 2500, name: 'Árvore'),
    (floor: 6000, name: 'Floresta'),
  ];

  static LevelInfo levelFor(int pointsEarned) {
    var index = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (pointsEarned >= _levels[i].floor) index = i;
    }
    return LevelInfo(
      number: index + 1,
      name: _levels[index].name,
      floor: _levels[index].floor,
      next: index + 1 < _levels.length ? _levels[index + 1].floor : null,
    );
  }

  /// Relógio de parede de Brasília, representado como `DateTime` em UTC.
  static DateTime wallClock(DateTime instant) =>
      instant.toUtc().add(utcOffset);

  /// Converte um relógio de parede de Brasília de volta para o instante real.
  static DateTime instantFromWall(DateTime wall) => wall.subtract(utcOffset);

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _key(DateTime wall) =>
      '${wall.year.toString().padLeft(4, '0')}-${_two(wall.month)}-${_two(wall.day)}';

  /// Dia local (Brasília) no formato `AAAA-MM-DD`.
  static String dateKey(DateTime instant) => _key(wallClock(instant));

  /// Mês local no formato `AAAA-MM`.
  static String monthKey(DateTime instant) => dateKey(instant).substring(0, 7);

  static DateTime _weekStartWall(DateTime instant) {
    final wall = wallClock(instant);
    final midnight = DateTime.utc(wall.year, wall.month, wall.day);
    return midnight.subtract(Duration(days: wall.weekday - DateTime.monday));
  }

  /// Segunda-feira da semana local, no formato `AAAA-MM-DD`.
  static String weekStartKey(DateTime instant) => _key(_weekStartWall(instant));

  /// Domingo da semana local, no formato `AAAA-MM-DD`.
  static String weekEndKey(DateTime instant) =>
      _key(_weekStartWall(instant).add(const Duration(days: 6)));

  /// Instante em que o teto semanal zera: próxima segunda, 00:00 de Brasília.
  static DateTime nextWeekReset(DateTime instant) => instantFromWall(
    _weekStartWall(instant).add(const Duration(days: 7)),
  );

  /// Início (00:00 de Brasília) do dia local que contém [instant].
  static DateTime startOfLocalDay(DateTime instant) {
    final wall = wallClock(instant);
    return instantFromWall(DateTime.utc(wall.year, wall.month, wall.day));
  }

  /// Dia local deslocado em [days] dias, no formato `AAAA-MM-DD`.
  static String shiftDateKey(String dateKey, int days) {
    final parts = dateKey.split('-').map(int.parse).toList();
    return _key(
      DateTime.utc(parts[0], parts[1], parts[2]).add(Duration(days: days)),
    );
  }

  static const List<String> monthNames = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// "9 de novembro".
  static String longDate(DateTime instant) {
    final wall = wallClock(instant);
    return '${wall.day} de ${monthNames[wall.month - 1]}';
  }

  /// "09/11/2026".
  static String shortDate(DateTime instant) {
    final wall = wallClock(instant);
    return '${_two(wall.day)}/${_two(wall.month)}/${wall.year}';
  }
}
