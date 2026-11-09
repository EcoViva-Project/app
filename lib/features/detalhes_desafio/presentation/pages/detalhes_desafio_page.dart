import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../desafios/presentation/widgets/challenge_widgets.dart';

/// Detalhes de um desafio: regras, bônus, prazo e o progresso da pessoa.
///
/// O desafio é sempre lido do [ChallengeService] pelo identificador; a tela
/// nunca mostra dados de exemplo.
class DetalhesDesafioPage extends StatefulWidget {
  const DetalhesDesafioPage({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<DetalhesDesafioPage> createState() => _DetalhesDesafioPageState();
}

class _DetalhesDesafioPageState extends State<DetalhesDesafioPage> {
  static const String _fetchFallback =
      'Não foi possível carregar o desafio. Tente de novo.';

  final ChallengeService _service = ChallengeService.instance;

  bool _fetching = false;
  bool _notFound = false;
  String? _fetchError;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _fetchIfMissing();
  }

  @override
  void didUpdateWidget(covariant DetalhesDesafioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId != widget.challengeId) {
      _notFound = false;
      _fetchError = null;
      _fetching = false;
      _fetchIfMissing();
    }
  }

  /// Busca o desafio uma vez, se ele ainda não estiver na lista carregada.
  void _fetchIfMissing() {
    if (_service.byId(widget.challengeId) != null) return;
    _fetching = true;
    _fetch();
  }

  Future<void> _fetch() async {
    final id = widget.challengeId;
    try {
      await _service.fetch(id);
      if (!mounted || id != widget.challengeId) return;
      setState(() => _fetching = false);
    } on ApiException catch (error) {
      if (!mounted || id != widget.challengeId) return;
      setState(() {
        _fetching = false;
        if (error.statusCode == 404) {
          _notFound = true;
        } else {
          _fetchError = error.message;
        }
      });
    } catch (_) {
      if (!mounted || id != widget.challengeId) return;
      setState(() {
        _fetching = false;
        _fetchError = _fetchFallback;
      });
    }
  }

  void _retryFetch() {
    if (_fetching) return;
    setState(() {
      _fetching = true;
      _fetchError = null;
      _notFound = false;
    });
    _fetch();
  }

  /// Entra no desafio, ou recomeça um desafio vencido.
  Future<void> _join(Challenge challenge) async {
    if (_joining) return;
    final restarting = challenge.expired;
    setState(() => _joining = true);
    try {
      final updated = await _service.join(challenge.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${restarting ? 'Desafio recomeçado' : 'Você entrou no desafio'}. ${updated.deadlineLabel}.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback:
            restarting
                ? 'Não foi possível recomeçar o desafio. Tente de novo.'
                : 'Não foi possível entrar no desafio. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _copyInvite(Challenge challenge) async {
    final invite = StringBuffer(
      'Vamos participar do desafio "${challenge.title}" no EcoViva?',
    );
    if (challenge.description.isNotEmpty) {
      invite.write(' ${challenge.description}');
    }
    try {
      await Clipboard.setData(ClipboardData(text: invite.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Convite copiado. Agora é só colar na conversa.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível copiar o convite.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final challenge = _service.byId(widget.challengeId);
        return Scaffold(
          backgroundColor: AppColors.brandBackground,
          // A seta volta para a tela anterior ou, sem histórico, para a aba
          // Desafios.
          appBar: const AppPageHeader(
            pageIcon: Icons.emoji_events,
            title: 'Desafio',
            showBack: true,
            backFallback: '/desafios',
          ),
          body: SafeArea(
            child:
                challenge == null
                    ? _buildMissing(context)
                    : _buildContent(challenge),
          ),
          bottomNavigationBar:
              challenge == null ? null : _buildActionBar(context, challenge),
        );
      },
    );
  }

  /// Sem desafio para mostrar: carregando, erro ou inexistente.
  Widget _buildMissing(BuildContext context) {
    if (_fetching) return const LoadingView(message: 'Carregando desafio…');
    final error = _fetchError;
    if (error != null && !_notFound) {
      return LoadErrorView(message: error, onRetry: _retryFetch);
    }
    return EmptyStateView(
      icon: Icons.search_off,
      title: 'Desafio não encontrado',
      message: 'Ele pode ter saído do ar. Veja os desafios disponíveis.',
      actionLabel: 'Ver desafios',
      onAction: () => context.go('/desafios'),
    );
  }

  Widget _buildContent(Challenge challenge) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(challenge),
          const SizedBox(height: 16),
          if (challenge.completed) ...[
            _buildCompletedCard(challenge),
            const SizedBox(height: 16),
          ] else if (challenge.expired) ...[
            _buildExpiredCard(challenge),
            const SizedBox(height: 16),
          ] else if (challenge.inProgress) ...[
            _buildProgressCard(challenge),
            const SizedBox(height: 16),
          ],
          _buildHowItWorksCard(challenge),
          if (!challenge.completed) ...[
            const SizedBox(height: 16),
            _buildBonusCard(challenge),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _copyInvite(challenge),
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copiar convite'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Challenge challenge) {
    return ChallengeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChallengeIcon(icon: challenge.icon, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  challenge.category,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              challenge.title,
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              challenge.description,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              // Depois de concluído, o prazo deixa de valer.
              if (!challenge.completed)
                ChallengeMeta(
                  icon: Icons.schedule,
                  label: challenge.deadlineLabel,
                  color: AppColors.brandTextPrimary,
                ),
              ChallengeMeta(
                icon: Icons.groups_outlined,
                label: challengeParticipantsLabel(challenge),
                color: AppColors.brandTextPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Em andamento: quanto já foi feito e as etapas numeradas.
  Widget _buildProgressCard(Challenge challenge) {
    final stepCountedToday = challenge.countsByDay && challenge.stepDoneToday;

    return ChallengeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Seu progresso',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
                Text(
                  challengeStepsLabel(challenge),
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ChallengeProgressBar(challenge: challenge, height: 10),
          if (ChallengeStepsRow.fits(challenge)) ...[
            const SizedBox(height: 6),
            ChallengeStepsRow(challenge: challenge),
          ],
          if (stepCountedToday) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A etapa de hoje já foi contada. Volte amanhã.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Prazo vencido sem concluir: pode recomeçar do zero.
  Widget _buildExpiredCard(Challenge challenge) {
    return ChallengeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChallengeIcon(
            icon: Icons.event_busy,
            background: AppColors.brandTertiaryAccent.withValues(alpha: 0.35),
            foreground: AppColors.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O prazo terminou',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Você fez ${challengeStepsLabel(challenge)}. Ao recomeçar, '
                  'a contagem volta a zero e você ganha um novo prazo de '
                  '${daysLabel(challenge.durationDays)}.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Concluído: comemoração com o bônus recebido.
  Widget _buildCompletedCard(Challenge challenge) {
    return ChallengeCard(
      color: AppColors.brandSecondaryContainer,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ChallengeIcon(
            icon: Icons.emoji_events,
            size: 64,
            background: AppColors.brandTertiaryAccent.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Desafio concluído!',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Você completou ${challengeStepsLabel(challenge)}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ChallengeBadge(
            icon: Icons.stars,
            label: challengeBonusReceivedLabel(challenge),
            background: AppColors.brandSurface,
          ),
          const SizedBox(height: 8),
          Text(
            'O bônus de desafio não entra no teto semanal de pontos.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard(Challenge challenge) {
    return ChallengeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.help_outline,
                  color: AppColors.brandDarkAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Como funciona',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _howToItem(Icons.task_alt, challenge.howItWorks),
          const SizedBox(height: 10),
          _howToItem(
            Icons.auto_awesome,
            'O progresso avança sozinho quando você registra a ação: não é '
            'preciso marcar nada nesta tela.',
          ),
          const SizedBox(height: 10),
          _howToItem(
            Icons.schedule,
            'O prazo é pessoal: ${daysLabel(challenge.durationDays)}, '
            'contando o dia em que você entra no desafio.',
          ),
        ],
      ),
    );
  }

  Widget _howToItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChallengeIcon(icon: icon, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBonusCard(Challenge challenge) {
    return ChallengeCard(
      color: AppColors.brandSecondaryContainer,
      child: Row(
        children: [
          ChallengeIcon(
            icon: Icons.stars,
            size: 48,
            background: AppColors.brandTertiaryAccent.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ao concluir',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challengeBonusLabel(challenge),
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Esse bônus não entra no teto semanal de pontos.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Botão principal, fixo no rodapé. Desafio concluído não tem ação.
  Widget? _buildActionBar(BuildContext context, Challenge challenge) {
    if (challenge.completed) return null;

    final Widget button;
    if (challenge.inProgress) {
      button = FilledButton.icon(
        onPressed: () => openChallengeAction(context, challenge),
        style: _primaryButtonStyle,
        icon: const Icon(Icons.add_task, size: 20),
        label: Text(
          registerActionLabel(challenge),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      final restart = challenge.expired;
      button = FilledButton.icon(
        onPressed: _joining ? null : () => _join(challenge),
        style: _primaryButtonStyle,
        icon:
            _joining
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(restart ? Icons.restart_alt : Icons.flag, size: 20),
        label: Text(
          restart ? 'Recomeçar desafio' : 'Entrar no desafio',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Material(
      color: AppColors.brandSurface,
      shape: const Border(top: BorderSide(color: AppColors.brandBorder)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(width: double.infinity, child: button),
        ),
      ),
    );
  }

  static final ButtonStyle _primaryButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size(48, 52),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle: AppTextStyles.labelLg,
  );
}
