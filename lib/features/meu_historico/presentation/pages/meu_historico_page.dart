import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';

/// Histórico de ações registradas e de bônus recebidos.
class MeuHistoricoPage extends StatefulWidget {
  const MeuHistoricoPage({super.key});

  @override
  State<MeuHistoricoPage> createState() => _MeuHistoricoPageState();
}

class _MeuHistoricoPageState extends State<MeuHistoricoPage> {
  final ActionHistoryService _history = ActionHistoryService.instance;
  final UserProgressService _progress = UserProgressService.instance;
  late final Listenable _services = Listenable.merge([_history, _progress]);

  /// Carga pedida por esta tela (primeira carga, "Tentar de novo" ou puxar
  /// para atualizar).
  bool _loadingNow = false;

  /// Erro de carga que o serviço não guardou em `error`.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: `load()` avisa os ouvintes na hora, e isso
    // não pode acontecer no meio da montagem da tela.
    if (!_history.isLoaded && !_history.loading) {
      _loadingNow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLoad());
    } else if (!_progress.isLoaded && !_progress.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Sem o resumo, a tela só não mostra os totais do cabeçalho.
        if (mounted) _progress.load().catchError((_) {});
      });
    }
  }

  Future<void> _load() async {
    if (_loadingNow) return;
    setState(() {
      _loadingNow = true;
      _loadError = null;
    });
    await _runLoad();
  }

  /// Recarrega o histórico e o resumo (de onde vêm os totais).
  Future<void> _runLoad() async {
    if (!mounted) {
      _loadingNow = false;
      return;
    }
    try {
      await Future.wait([_history.load(), _progress.load()]);
    } catch (error) {
      if (!mounted) return;
      if (_history.isLoaded) {
        // A lista continua na tela; só avisa.
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível atualizar o histórico. Tente de novo.',
        );
      } else {
        _loadError =
            error is ApiException
                ? error.message
                : 'Não foi possível carregar o histórico. Tente de novo.';
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNow = false);
      } else {
        _loadingNow = false;
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Meu histórico',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandDarkAccent,
          onRefresh: _load,
          child: ListenableBuilder(
            listenable: _services,
            builder: (context, _) => _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final slivers = <Widget>[];

    if (!_history.isLoaded) {
      slivers.add(
        SliverFillRemaining(hasScrollBody: false, child: _buildUnloaded()),
      );
    } else {
      final records = _history.records;
      if (records.isEmpty) {
        slivers.add(
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(
              icon: Icons.yard_outlined,
              title: 'Nenhuma ação registrada ainda',
              message: 'Que tal começar com um pequeno gesto hoje?',
              actionLabel: 'Registrar primeira ação',
              onAction: () => context.go('/acoes'),
            ),
          ),
        );
      } else {
        final now = DateTime.now();
        if (_progress.isLoaded) {
          slivers.add(SliverToBoxAdapter(child: _buildTotals()));
        }
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.separated(
              itemCount: records.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final record = records[index];
                return _HistoryItem(
                  key: ValueKey<String>(record.id),
                  record: record,
                  now: now,
                );
              },
            ),
          ),
        );
      }
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }

  Widget _buildUnloaded() {
    final message = _history.error ?? _loadError;
    if (message == null && (_history.loading || _loadingNow)) {
      return const LoadingView(message: 'Carregando seu histórico…');
    }
    return LoadErrorView(
      message: message ?? 'Não foi possível carregar o histórico.',
      onRetry: _load,
    );
  }

  /// Totais vindos do resumo do usuário, e não da soma da lista (a lista pode
  /// estar limitada aos lançamentos mais recentes).
  Widget _buildTotals() {
    final count = _progress.actionsCount;
    final earned = UserProgressService.formatNumber(_progress.pointsEarned);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 ação registrada'
                      : '${UserProgressService.formatNumber(count)} ações registradas',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Os pontos incluem bônus de desafios e conquistas.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.eco,
                    color: AppColors.brandDarkAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$earned pts ganhos',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _months = [
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

/// "Hoje", "Ontem", "9 de novembro" ou "9 de novembro de 2025".
String _formatDate(DateTime when, DateTime now) {
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  if (sameDay(when, now)) return 'Hoje';
  if (sameDay(when, DateTime(now.year, now.month, now.day - 1))) return 'Ontem';
  final date = '${when.day} de ${_months[when.month - 1]}';
  return when.year == now.year ? date : '$date de ${when.year}';
}

String _formatTime(DateTime when) {
  final hour = when.hour.toString().padLeft(2, '0');
  final minute = when.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

enum _TagTone { neutral, bonus, cap }

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({super.key, required this.record, required this.now});

  final ActionRecord record;
  final DateTime now;

  String? get _bonusLabel => switch (record.kind) {
    'challenge' => 'Bônus de desafio',
    'achievement' => 'Bônus de conquista',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final bonusLabel = _bonusLabel;
    var notes = record.notes?.trim() ?? '';
    // Nos bônus, a observação gravada pela API só repete o rótulo acima
    // ("Bônus de conquista", "Bônus de desafio coletivo").
    if (record.isBonus && notes.toLowerCase().startsWith('bônus')) notes = '';
    final tags = <Widget>[
      if (bonusLabel != null)
        _Tag(
          icon: Icons.card_giftcard,
          label: bonusLabel,
          tone: _TagTone.bonus,
        ),
      if (record.capped)
        Tooltip(
          message:
              'Valia ${record.basePoints} pts; entraram ${record.points} por causa do teto semanal.',
          child: const _Tag(
            icon: Icons.speed_outlined,
            label: 'teto semanal',
            tone: _TagTone.cap,
          ),
        ),
      if (record.liters > 0)
        _Tag(
          icon: Icons.water_drop_outlined,
          label: '~${record.liters} L poupados',
        ),
      if (record.isAction && record.quantity > 1)
        _Tag(icon: Icons.repeat, label: '${record.quantity} vezes'),
    ];
    final detailStyle = AppTextStyles.bodySm.copyWith(
      color: AppColors.brandTextSecondary,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(record.icon, color: AppColors.brandDarkAccent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          record.categoryLabel,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.brandDarkAccent,
                          ),
                        ),
                        Text(
                          '• ${_formatDate(record.dateTime, now)}',
                          style: detailStyle,
                        ),
                        Text(
                          '• ${_formatTime(record.dateTime)}',
                          style: detailStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${record.points} pts',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: tags),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(notes, style: detailStyle),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    this.tone = _TagTone.neutral,
  });

  final IconData icon;
  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      _TagTone.neutral => (
        AppColors.brandBackground,
        AppColors.brandTextSecondary,
      ),
      _TagTone.bonus => (
        AppColors.brandSecondaryContainer,
        AppColors.brandDarkAccent,
      ),
      _TagTone.cap => (
        AppColors.brandTertiaryAccent.withValues(alpha: 0.35),
        AppColors.brandTextPrimary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMd.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
