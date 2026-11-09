import 'package:flutter/material.dart';

import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Família de tipos de ponto de coleta, com uma cor no mapa.
class PointFamily {
  const PointFamily(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Famílias, na ordem da legenda.
const List<PointFamily> pointFamilies = [
  PointFamily(
    'Ecopontos, entrega voluntária e cooperativas',
    AppColors.brandDarkAccent,
    Icons.recycling,
  ),
  PointFamily(
    'Eletrônicos, pilhas e lâmpadas',
    Color(0xFF2F5F95),
    Icons.devices_other,
  ),
  PointFamily('Óleo de cozinha', Color(0xFF9A6200), Icons.opacity),
  PointFamily('Medicamentos', Color(0xFFB2443F), Icons.medication_outlined),
  PointFamily('Pneus', Color(0xFF5E5245), Icons.trip_origin),
];

/// Família de um tipo (`ecoponto_municipal`, `oleo_cozinha`...).
PointFamily familyForType(String type) {
  final key = type.toLowerCase();
  if (key.contains('eletr') ||
      key.contains('pilha') ||
      key.contains('bateria') ||
      key.contains('lampada') ||
      key.contains('lâmpada')) {
    return pointFamilies[1];
  }
  if (key.contains('oleo') || key.contains('óleo')) return pointFamilies[2];
  if (key.contains('medicamento')) return pointFamilies[3];
  if (key.contains('pneu')) return pointFamilies[4];
  return pointFamilies[0];
}

/// Cor do marcador de um ponto.
Color colorForPoint(CollectionPoint point) => familyForType(point.type).color;

/// Tipos presentes em [points], na ordem de `CollectionPoint.knownTypes`
/// (tipos desconhecidos no fim, em ordem alfabética), com a contagem.
List<({String type, int count})> typeCounts(List<CollectionPoint> points) {
  final counts = <String, int>{};
  for (final point in points) {
    counts[point.type] = (counts[point.type] ?? 0) + 1;
  }
  final known = CollectionPoint.knownTypes;
  final types =
      counts.keys.toList()..sort((a, b) {
        final ia = known.indexOf(a);
        final ib = known.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
  return [for (final type in types) (type: type, count: counts[type]!)];
}

/// Ponto em escola ou creche (a observação traz "instituição de ensino").
bool isSchoolPoint(CollectionPoint point) =>
    normalizeForSearch(point.notes ?? '').contains('instituicao de ensino');

/// Texto não vazio, ou `null` (para omitir linhas sem informação).
String? nonEmpty(String? text) {
  final value = text?.trim();
  return value == null || value.isEmpty || value == 'null' ? null : value;
}

/// Texto sem acentos e em minúsculas, para a busca.
String normalizeForSearch(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}
