import 'package:flutter/material.dart';

/// Converte nomes de ícones usados pela API em `IconData`.
///
/// Mantém o backend independente do Flutter e evita armazenar code points
/// frágeis no banco.
class IconCatalog {
  IconCatalog._();

  static const Map<String, IconData> _icons = {
    'eco': Icons.eco,
    'water_drop': Icons.water_drop,
    'water_drop_outlined': Icons.water_drop_outlined,
    'calendar_month': Icons.calendar_month,
    'diversity_1': Icons.diversity_1,
    'category': Icons.category,
    'compost': Icons.compost,
    'handshake': Icons.handshake,
    'directions_bike': Icons.directions_bike,
    'bolt': Icons.bolt,
    'recycling': Icons.recycling,
    'lightbulb_outline': Icons.lightbulb_outline,
    'park': Icons.park,
    'groups': Icons.groups,
    'favorite': Icons.favorite,
    'route': Icons.route,
    'yard': Icons.yard,
    'check_circle': Icons.check_circle,
    'savings': Icons.savings,
    'military_tech': Icons.military_tech,
    'schedule': Icons.schedule,
    'spa': Icons.spa,
    'emoji_events': Icons.emoji_events,
    'storefront': Icons.storefront,
    'cleaning_services': Icons.cleaning_services,
    'local_cafe': Icons.local_cafe,
    'sports_esports': Icons.sports_esports,
    'shopping_bag': Icons.shopping_bag,
    'percent': Icons.percent,
    'checkroom': Icons.checkroom,
    'redeem': Icons.redeem,
    'inventory_2': Icons.inventory_2,
    'confirmation_number': Icons.confirmation_number,
  };

  static IconData resolve(String? name, {IconData fallback = Icons.eco}) {
    if (name == null) return fallback;
    return _icons[name] ?? fallback;
  }
}
