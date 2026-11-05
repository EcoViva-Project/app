import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;

import 'api_client.dart';
import 'icon_catalog.dart';

class ActionRecord {
  ActionRecord({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.icon,
    required this.points,
    required this.liters,
    required this.dateTime,
    this.notes,
    this.quantity = 1,
  });

  final String id;
  final String title;
  final String categoryLabel;
  final IconData icon;
  final int points;
  final int liters;
  final DateTime dateTime;
  final String? notes;
  final int quantity;

  factory ActionRecord.fromApi(Map<String, dynamic> json) {
    return ActionRecord(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Ação sustentável',
      categoryLabel: json['categoryLabel'] as String? ?? 'Ação',
      icon: IconCatalog.resolve(json['icon'] as String?),
      points: (json['points'] as num?)?.toInt() ?? 0,
      liters: (json['liters'] as num?)?.toInt() ?? 0,
      dateTime:
          DateTime.tryParse(json['dateTime'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      notes: json['notes'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Histórico de ações carregado da API.
///
/// Mantém um cache local para a interface e um modo de fallback para testes
/// unitários que não acessam a rede.
class ActionHistoryService extends ChangeNotifier {
  ActionHistoryService._();

  static final ActionHistoryService instance = ActionHistoryService._();

  final List<ActionRecord> _records = [];
  bool _loaded = false;

  List<ActionRecord> get records => List.unmodifiable(_records);

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final data = await ApiClient.instance.get('/records');
    final list = (data['records'] as List?) ?? const [];
    _records
      ..clear()
      ..addAll(
        list.map((item) => ActionRecord.fromApi(item as Map<String, dynamic>)),
      );
    _loaded = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> submitAction({
    required int actionId,
    required int quantity,
    String? notes,
  }) async {
    final data = await ApiClient.instance.post('/actions/$actionId/records', {
      'quantity': quantity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final record = ActionRecord.fromApi(data['record'] as Map<String, dynamic>);
    _records.insert(0, record);
    notifyListeners();
    return data as Map<String, dynamic>;
  }

  void addRecord(ActionRecord record) {
    _records.insert(0, record);
    notifyListeners();
  }

  void clear() {
    _records.clear();
    _loaded = false;
    notifyListeners();
  }
}
