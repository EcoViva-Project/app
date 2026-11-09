import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'icon_catalog.dart';
import 'notification_service.dart';
import 'user_progress_service.dart';

/// Categoria de recompensa oferecida pelas empresas parceiras.
enum RewardCategoryFilter {
  todas,
  gastronomia,
  desconto,
  produto,
  servico,
  jogo,
}

extension RewardCategoryFilterLabel on RewardCategoryFilter {
  String get label {
    switch (this) {
      case RewardCategoryFilter.todas:
        return 'Todas';
      case RewardCategoryFilter.gastronomia:
        return 'Gastronomia';
      case RewardCategoryFilter.desconto:
        return 'Descontos';
      case RewardCategoryFilter.produto:
        return 'Produtos';
      case RewardCategoryFilter.servico:
        return 'Serviços';
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

String _formatDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

/// Uma recompensa (cupom) que pode ser resgatada com pontos.
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
    this.valueCents = 0,
    this.validityDays = 30,
    this.perUserLimit,
    this.redeemedByMe = 0,
    this.limitReached = false,
    this.partnerAddress,
    this.partnerDescription,
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
  final String? partnerAddress;
  final String? partnerDescription;
  final int pointsCost;

  /// Valor do benefício em centavos de real (0 = não informado).
  final int valueCents;
  final int stock;

  /// Por quantos dias o cupom vale depois do resgate.
  final int validityDays;

  /// Máximo de resgates por pessoa a cada 30 dias; `null` = sem limite.
  final int? perUserLimit;

  /// Quantas vezes o usuário resgatou nos últimos 30 dias.
  final int redeemedByMe;
  final bool limitReached;
  final String? terms;
  final bool isFeatured;

  bool get available => stock > 0;

  bool get hasValue => valueCents > 0;

  /// "Vale R$ 32,00".
  String get valueLabel => 'Vale ${UserProgressService.formatMoney(valueCents)}';

  /// "Válido por 30 dias após o resgate".
  String get validityLabel => 'Válido por $validityDays dias após o resgate';

  /// "Até 2 resgates a cada 30 dias".
  String? get limitLabel {
    final limit = perUserLimit;
    if (limit == null) return null;
    return limit == 1
        ? '1 resgate por pessoa a cada 30 dias'
        : 'Até $limit resgates por pessoa a cada 30 dias';
  }

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
      partnerAddress: json['partnerAddress'] as String?,
      partnerDescription: json['partnerDescription'] as String?,
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      valueCents: (json['valueCents'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      validityDays: (json['validityDays'] as num?)?.toInt() ?? 30,
      perUserLimit: (json['perUserLimit'] as num?)?.toInt(),
      redeemedByMe: (json['redeemedByMe'] as num?)?.toInt() ?? 0,
      limitReached: json['limitReached'] as bool? ?? false,
      terms: json['terms'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }
}

/// Situação de um cupom resgatado.
enum CouponStatus { active, used, expired }

extension CouponStatusLabel on CouponStatus {
  String get label {
    switch (this) {
      case CouponStatus.active:
        return 'Disponível';
      case CouponStatus.used:
        return 'Usado';
      case CouponStatus.expired:
        return 'Vencido';
    }
  }
}

/// Um cupom: o resultado de resgatar uma recompensa.
class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.rewardTitle,
    required this.partnerName,
    required this.icon,
    required this.code,
    required this.pointsSpent,
    required this.dateLabel,
    this.status = CouponStatus.active,
    this.expiresLabel = '',
    this.usedLabel = '',
    this.valueCents = 0,
    this.rewardDescription,
    this.partnerAddress,
    this.terms,
  });

  final int id;
  final String rewardTitle;
  final String? rewardDescription;
  final String partnerName;
  final String? partnerAddress;
  final IconData icon;

  /// Código que o parceiro confere, no formato `ECO-XXXXXXXX`.
  final String code;
  final int pointsSpent;
  final int valueCents;
  final String? terms;
  final CouponStatus status;

  /// Data do resgate ("09/11/2026").
  final String dateLabel;

  /// Data de validade.
  final String expiresLabel;

  /// Data em que foi usado (vazio se ainda não foi).
  final String usedLabel;

  bool get isActive => status == CouponStatus.active;

  /// "Válido até 09/12/2026", "Usado em 11/11/2026" ou "Venceu em 09/10/2026".
  String get statusDetail {
    switch (status) {
      case CouponStatus.active:
        return expiresLabel.isEmpty ? 'Disponível' : 'Válido até $expiresLabel';
      case CouponStatus.used:
        return usedLabel.isEmpty ? 'Usado' : 'Usado em $usedLabel';
      case CouponStatus.expired:
        return expiresLabel.isEmpty ? 'Vencido' : 'Venceu em $expiresLabel';
    }
  }

  factory RewardRedemption.fromApi(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        DateTime.tryParse(json[key] as String? ?? '');
    final rawStatus = json['status'] as String? ?? 'active';
    return RewardRedemption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rewardTitle: json['rewardTitle'] as String? ?? 'Recompensa',
      rewardDescription: json['rewardDescription'] as String?,
      partnerName: json['partnerName'] as String? ?? 'Parceiro EcoViva',
      partnerAddress: json['partnerAddress'] as String?,
      icon: IconCatalog.resolve(
        json['icon'] as String?,
        fallback: Icons.redeem,
      ),
      code: json['code'] as String? ?? '',
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      valueCents: (json['valueCents'] as num?)?.toInt() ?? 0,
      terms: json['terms'] as String?,
      status: CouponStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => CouponStatus.active,
      ),
      dateLabel: _formatDate(date('dateTime')),
      expiresLabel: _formatDate(date('expiresAt')),
      usedLabel: _formatDate(date('usedAt')),
    );
  }
}

/// Recompensas de parceiros e cupons do usuário (`/rewards`).
class RewardService extends ChangeNotifier {
  RewardService._();

  static final RewardService instance = RewardService._();

  final List<Reward> _rewards = [];
  final List<RewardRedemption> _redemptions = [];

  bool _loaded = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  String _search = '';
  RewardCategoryFilter _category = RewardCategoryFilter.todas;
  RewardSort _sort = RewardSort.destaque;

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  /// Um resgate ou uma conferência de cupom está em andamento.
  bool get busy => _busy;

  String? get error => _error;

  String get search => _search;

  RewardCategoryFilter get category => _category;

  RewardSort get sort => _sort;

  /// Todos os cupons do usuário, do mais recente para o mais antigo.
  List<RewardRedemption> get redemptions => List.unmodifiable(_redemptions);

  /// Cupons que ainda podem ser usados.
  List<RewardRedemption> get activeCoupons =>
      _redemptions.where((coupon) => coupon.isActive).toList();

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
          (a, b) => _normalize(a.title).compareTo(_normalize(b.title)),
        );
    }
    return list;
  }

  /// Recompensas disponíveis (com estoque) entre as filtradas.
  int get availableCount => rewards.where((reward) => reward.available).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/rewards');
      _rewards
        ..clear()
        ..addAll(
          ((data['rewards'] as List?) ?? const []).map(
            (item) => Reward.fromApi(item as Map<String, dynamic>),
          ),
        );
      await _loadRedemptions();
      _loaded = true;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRedemptions() async {
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

  /// Volta busca, categoria e ordenação ao padrão.
  void clearFilters() {
    _search = '';
    _category = RewardCategoryFilter.todas;
    _sort = RewardSort.destaque;
    notifyListeners();
  }

  /// Resgata uma recompensa e devolve o cupom gerado.
  ///
  /// Um segundo pedido enquanto o primeiro está em andamento é recusado.
  Future<RewardRedemption> redeem(Reward reward) async {
    if (_busy) {
      throw ApiException('Aguarde: um resgate já está em andamento.');
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
        if (index >= 0) _rewards[index] = replacement;
      }
      final summary = data['summary'];
      if (summary is Map<String, dynamic>) {
        UserProgressService.instance.applySummary(summary);
      }
      NotificationService.instance.load().catchError((_) {});
      return redemption;
    } on ApiException {
      // Saldo, estoque ou limite podem ter mudado: recarrega a vitrine.
      load().catchError((_) {});
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Marca o cupom como usado. [pin] é o código do parceiro, digitado pelo
  /// atendente no balcão.
  Future<RewardRedemption> useCoupon(
    RewardRedemption coupon,
    String pin,
  ) async {
    if (_busy) {
      throw ApiException('Aguarde: uma conferência já está em andamento.');
    }
    _setBusy(true);
    try {
      final data = await ApiClient.instance.post(
        '/rewards/redemptions/${coupon.id}/use',
        {'pin': pin.trim()},
      );
      final updated = RewardRedemption.fromApi(
        data['redemption'] as Map<String, dynamic>,
      );
      final index = _redemptions.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _redemptions[index] = updated;
      NotificationService.instance.load().catchError((_) {});
      return updated;
    } finally {
      _setBusy(false);
    }
  }

  void reset() {
    _rewards.clear();
    _redemptions.clear();
    _loaded = false;
    _loading = false;
    _busy = false;
    _error = null;
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
