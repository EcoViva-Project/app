import 'package:flutter/material.dart';

import 'api_client.dart';
import 'icon_catalog.dart';
import 'user_progress_service.dart';

/// Categoria de recompensa oferecida pelas empresas parceiras.
enum RewardCategoryFilter { todas, produto, servico, desconto, jogo }

extension RewardCategoryFilterLabel on RewardCategoryFilter {
  String get label {
    switch (this) {
      case RewardCategoryFilter.todas:
        return 'Todas';
      case RewardCategoryFilter.produto:
        return 'Produtos';
      case RewardCategoryFilter.servico:
        return 'Serviços';
      case RewardCategoryFilter.desconto:
        return 'Descontos';
      case RewardCategoryFilter.jogo:
        return 'Jogos';
    }
  }
}

/// Ordenação aplicada à lista de recompensas.
enum RewardSort { destaque, menorCusto, maiorCusto, alfabetica }

extension RewardSortLabel on RewardSort {
  String get label {
    switch (this) {
      case RewardSort.destaque:
        return 'Destaques';
      case RewardSort.menorCusto:
        return 'Menor custo';
      case RewardSort.maiorCusto:
        return 'Maior custo';
      case RewardSort.alfabetica:
        return 'A-Z';
    }
  }
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryLabel,
    required this.icon,
    required this.partnerName,
    required this.pointsCost,
    required this.stock,
    this.terms,
    this.isFeatured = false,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String categoryLabel;
  final IconData icon;
  final String partnerName;
  final int pointsCost;
  final int stock;
  final String? terms;
  final bool isFeatured;

  bool get available => stock > 0;

  factory Reward.fromApi(Map<String, dynamic> json) {
    return Reward(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Recompensa',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'produto',
      categoryLabel: json['categoryLabel'] as String? ?? 'Produto',
      icon: IconCatalog.resolve(
        json['icon'] as String?,
        fallback: Icons.redeem,
      ),
      partnerName: json['partnerName'] as String? ?? 'Parceiro EcoViva',
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      terms: json['terms'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }
}

class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.rewardTitle,
    required this.partnerName,
    required this.icon,
    required this.code,
    required this.pointsSpent,
    required this.dateLabel,
  });

  final int id;
  final String rewardTitle;
  final String partnerName;
  final IconData icon;
  final String code;
  final int pointsSpent;
  final String dateLabel;

  factory RewardRedemption.fromApi(Map<String, dynamic> json) {
    final rawDate = json['dateTime'] as String?;
    final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);
    return RewardRedemption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rewardTitle: json['rewardTitle'] as String? ?? 'Recompensa',
      partnerName: json['partnerName'] as String? ?? 'Parceiro EcoViva',
      icon: IconCatalog.resolve(
        json['icon'] as String?,
        fallback: Icons.redeem,
      ),
      code: json['code'] as String? ?? '',
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      dateLabel:
          parsed == null
              ? ''
              : '${parsed.day.toString().padLeft(2, '0')}/'
                  '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}',
    );
  }
}

/// Catálogo de recompensas de parceiros e histórico de resgates.
///
/// Os dados vêm da API (`/rewards`). Enquanto a primeira carga não acontece —
/// por exemplo em testes de widget sem rede — o serviço mantém uma vitrine
/// demonstrativa compatível com o seed do backend.
class RewardService extends ChangeNotifier {
  RewardService._();

  static final RewardService instance = RewardService._();

  static final List<Reward> _fallback = const [
    Reward(
      id: -1,
      title: 'Café especial grátis',
      description: 'Um café coado especial de 200 ml na unidade do bairro.',
      category: 'desconto',
      categoryLabel: 'Desconto',
      icon: Icons.local_cafe,
      partnerName: 'Café Raízes',
      pointsCost: 150,
      stock: 60,
      terms: 'Válido de segunda a sexta, das 8h às 17h.',
    ),
    Reward(
      id: -2,
      title: 'Kit de sacolas reutilizáveis',
      description:
          'Conjunto com três sacolas de algodão orgânico para as compras.',
      category: 'produto',
      categoryLabel: 'Produto',
      icon: Icons.shopping_bag,
      partnerName: 'Mercado Verde',
      pointsCost: 400,
      stock: 25,
      terms: 'Retire na loja em até 30 dias após o resgate.',
      isFeatured: true,
    ),
    Reward(
      id: -3,
      title: 'Skin Guardião da Floresta',
      description: 'Pacote de cosméticos digitais do jogo Floresta Viva.',
      category: 'jogo',
      categoryLabel: 'Jogo',
      icon: Icons.sports_esports,
      partnerName: 'Floresta Games',
      pointsCost: 500,
      stock: 40,
      terms: 'Código enviado por e-mail após o resgate.',
      isFeatured: true,
    ),
    Reward(
      id: -4,
      title: 'Revisão básica de bicicleta',
      description: 'Ajuste de freios, transmissão e calibragem dos pneus.',
      category: 'servico',
      categoryLabel: 'Serviço',
      icon: Icons.directions_bike,
      partnerName: 'Bike Urbana',
      pointsCost: 700,
      stock: 12,
      terms: 'Peças não inclusas. Agende pelo telefone da oficina.',
    ),
  ];

  final List<Reward> _rewards = List.of(_fallback);
  final List<RewardRedemption> _redemptions = [];

  bool _loaded = false;
  bool _busy = false;
  String _search = '';
  RewardCategoryFilter _category = RewardCategoryFilter.todas;
  RewardSort _sort = RewardSort.destaque;

  bool get isLoaded => _loaded;
  bool get busy => _busy;
  String get search => _search;
  RewardCategoryFilter get category => _category;
  RewardSort get sort => _sort;

  List<RewardRedemption> get redemptions => List.unmodifiable(_redemptions);

  /// Recompensas que combinam com os filtros atuais.
  List<Reward> get rewards {
    final term = _normalize(_search);
    final list =
        _rewards.where((reward) {
          final matchesCategory =
              _category == RewardCategoryFilter.todas ||
              reward.category == _category.name;
          final matchesSearch =
              term.isEmpty ||
              _normalize(reward.title).contains(term) ||
              _normalize(reward.description).contains(term) ||
              _normalize(reward.partnerName).contains(term);
          return matchesCategory && matchesSearch;
        }).toList();

    switch (_sort) {
      case RewardSort.destaque:
        list.sort((a, b) {
          final featured = (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0);
          return featured != 0
              ? featured
              : a.pointsCost.compareTo(b.pointsCost);
        });
      case RewardSort.menorCusto:
        list.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
      case RewardSort.maiorCusto:
        list.sort((a, b) => b.pointsCost.compareTo(a.pointsCost));
      case RewardSort.alfabetica:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return list;
  }

  List<Reward> get featured =>
      rewards.where((reward) => reward.isFeatured).toList();

  Future<void> load() async {
    final data = await ApiClient.instance.get('/rewards');
    final items =
        ((data['rewards'] as List?) ?? const [])
            .map((item) => Reward.fromApi(item as Map<String, dynamic>))
            .toList();
    _rewards
      ..clear()
      ..addAll(items);
    _loaded = true;
    notifyListeners();

    try {
      await loadRedemptions();
    } catch (_) {
      // O histórico é complementar; a vitrine já pode ser exibida.
    }
  }

  Future<void> loadRedemptions() async {
    final data = await ApiClient.instance.get('/rewards/redemptions');
    _redemptions
      ..clear()
      ..addAll(
        ((data['redemptions'] as List?) ?? const []).map(
          (item) => RewardRedemption.fromApi(item as Map<String, dynamic>),
        ),
      );
    final summary = data['summary'];
    if (summary is Map<String, dynamic>) {
      UserProgressService.instance.applySummary(summary);
    }
    notifyListeners();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  void setCategory(RewardCategoryFilter value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  void setSort(RewardSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  /// Resgata uma recompensa e devolve o código gerado pelo backend.
  Future<RewardRedemption> redeem(Reward reward) async {
    if (reward.id <= 0) {
      throw ApiException(
        'Conecte-se à internet para concluir o resgate.',
        statusCode: 503,
      );
    }

    _setBusy(true);
    try {
      final data = await ApiClient.instance.post(
        '/rewards/${reward.id}/redeem',
      );

      final redemption = RewardRedemption.fromApi(
        data['redemption'] as Map<String, dynamic>,
      );
      _redemptions.insert(0, redemption);

      final updated = data['reward'];
      if (updated is Map<String, dynamic>) {
        final replacement = Reward.fromApi(updated);
        final index = _rewards.indexWhere((item) => item.id == replacement.id);
        if (index >= 0) {
          _rewards[index] = replacement;
        }
      }

      final summary = data['summary'];
      if (summary is Map<String, dynamic>) {
        UserProgressService.instance.applySummary(summary);
      }

      notifyListeners();
      return redemption;
    } finally {
      _setBusy(false);
    }
  }

  void reset() {
    _rewards
      ..clear()
      ..addAll(_fallback);
    _redemptions.clear();
    _loaded = false;
    _busy = false;
    _search = '';
    _category = RewardCategoryFilter.todas;
    _sort = RewardSort.destaque;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  static String _normalize(String value) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString();
  }
}
