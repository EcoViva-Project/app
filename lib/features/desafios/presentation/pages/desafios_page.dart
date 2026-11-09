import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/challenge_widgets.dart';

/// Aba "Desafios": em andamento, disponíveis e concluídos.
class DesafiosPage extends StatefulWidget {
  const DesafiosPage({super.key});

  @override
  State<DesafiosPage> createState() => _DesafiosPageState();
}

class _DesafiosPageState extends State<DesafiosPage> {
  static const String _loadFallback =
      'Não foi possível carregar os desafios. Tente de novo.';

  final ChallengeService _service = ChallengeService.instance;
  final Listenable _listenable = Listenable.merge([
    ChallengeService.instance,
    AchievementService.instance,
  ]);

  /// Desafios vencidos com "Recomeçar" em andamento (evita toque duplo).
  final Set<int> _restarting = <int>{};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // `load()` avisa os ouvintes na mesma hora. Esperar o fim do quadro evita
    // reconstruir, no meio da montagem, outras telas que já escutam o serviço.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_loadError != null) setState(() => _loadError = null);
    try {
      await _service.load();
    } catch (error) {
      if (!mounted) return;
      if (_service.isLoaded) {
        // Já há uma lista na tela: mantém o que estava e só avisa.
        showErrorSnackBar(context, error, fallback: _loadFallback);
      } else {
        setState(() {
          _loadError = error is ApiException ? error.message : _loadFallback;
        });
      }
    }
  }

  Future<void> _restart(Challenge challenge) async {
    if (_restarting.contains(challenge.id)) return;
    setState(() => _restarting.add(challenge.id));
    try {
      final updated = await _service.join(challenge.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Você recomeçou "${updated.title}". ${updated.deadlineLabel}.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível recomeçar o desafio. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _restarting.remove(challenge.id));
    }
  }

  void _openDetails(Challenge challenge) {
    context.push('/detalhes-desafio/${challenge.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.emoji_events,
        title: 'Desafios',
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _listenable,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_service.isLoaded) {
      final error = _loadError;
      if (error != null && !_service.loading) {
        return LoadErrorView(message: error, onRetry: _load);
      }
      return const LoadingView(message: 'Carregando desafios…');
    }

    final ongoing = _service.ongoing;
    final available = _service.available;
    final completed = _service.completedChallenges;
    final nothingAtAll =
        ongoing.isEmpty && available.isEmpty && completed.isEmpty;

    return RefreshIndicator(
      color: AppColors.brandDarkAccent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildIntro(context),
          const SizedBox(height: 20),
          if (nothingAtAll)
            const EmptyStateView(
              icon: Icons.emoji_events_outlined,
              title: 'Nenhum desafio por enquanto',
              message:
                  'Quando houver desafios, eles aparecem aqui. Puxe a tela para baixo para atualizar.',
            )
          else ...[
            _SectionHeader(title: 'Em andamento', count: ongoing.length),
            const SizedBox(height: 12),
            if (ongoing.isEmpty)
              _SectionNote(
                available.isEmpty
                    ? 'Nenhum desafio em andamento.'
                    : 'Nenhum desafio em andamento. Escolha um dos disponíveis abaixo para começar.',
              )
            else
              for (final challenge in ongoing) ...[
                _OngoingCard(
                  challenge: challenge,
                  onOpen: () => _openDetails(challenge),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            _SectionHeader(title: 'Disponíveis', count: available.length),
            const SizedBox(height: 12),
            if (available.isEmpty)
              const _SectionNote(
                'Você já entrou em todos os desafios disponíveis.',
              )
            else
              for (final challenge in available) ...[
                _AvailableCard(
                  challenge: challenge,
                  restarting: _restarting.contains(challenge.id),
                  onOpen: () => _openDetails(challenge),
                  onRestart: () => _restart(challenge),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            _SectionHeader(title: 'Concluídos', count: completed.length),
            const SizedBox(height: 12),
            if (completed.isEmpty)
              const _SectionNote(
                'Os desafios que você concluir aparecem aqui, com o bônus recebido.',
              )
            else
              for (final challenge in completed) ...[
                _CompletedCard(
                  challenge: challenge,
                  onOpen: () => _openDetails(challenge),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final achievements = AchievementService.instance;
    final total = achievements.achievements.length;
    final achievementsLabel =
        achievements.isLoaded && total > 0
            ? 'Conquistas: ${achievements.unlocked.length} de $total'
            : 'Conquistas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desafios Sustentáveis',
          style: AppTextStyles.headlineLg.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Entre em um desafio e ele avança sozinho a cada ação da categoria que você registrar.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/conquistas'),
          icon: const Icon(Icons.military_tech, size: 18),
          label: Text(achievementsLabel),
        ),
      ],
    );
  }
}

/// Título de seção com a quantidade de desafios.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${title.toUpperCase()} ($count)',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandTextPrimary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de seção vazia.
class _SectionNote extends StatelessWidget {
  const _SectionNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.brandTextPrimary),
      ),
    );
  }
}

/// Ícone, título e categoria do desafio, com a seta de "abrir detalhes".
class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChallengeIcon(icon: challenge.icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.title,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                challenge.category,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandDarkAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const ExcludeSemantics(
          child: Icon(Icons.chevron_right, color: AppColors.brandTextSecondary),
        ),
      ],
    );
  }
}

/// Desafio em andamento: progresso, prazo e atalho para registrar a ação.
class _OngoingCard extends StatelessWidget {
  const _OngoingCard({required this.challenge, required this.onOpen});

  final Challenge challenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final stepCountedToday = challenge.countsByDay && challenge.stepDoneToday;

    return ChallengeCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(challenge: challenge),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  challengeStepsLabel(challenge),
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                ChallengeMeta(
                  icon: Icons.schedule,
                  label: challenge.deadlineLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ChallengeProgressBar(challenge: challenge),
          if (ChallengeStepsRow.fits(challenge)) ...[
            const SizedBox(height: 4),
            ChallengeStepsRow(challenge: challenge, size: 28),
          ],
          const SizedBox(height: 12),
          Text(
            challenge.howItWorks,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ChallengeMeta(
            icon: Icons.stars,
            label: '${challengeBonusLabel(challenge)} ao concluir',
            color: AppColors.brandDarkAccent,
            strong: true,
          ),
          if (stepCountedToday) ...[
            const SizedBox(height: 10),
            const ChallengeBadge(
              icon: Icons.check_circle,
              label: 'Etapa de hoje registrada',
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openChallengeAction(context, challenge),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_task, size: 18),
              label: Text(
                registerActionLabel(challenge),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (stepCountedToday) ...[
            const SizedBox(height: 8),
            Text(
              'A próxima etapa deste desafio só conta amanhã, mesmo que você registre outra ação hoje.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Desafio em que a pessoa ainda não entrou, ou cujo prazo venceu.
class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.challenge,
    required this.restarting,
    required this.onOpen,
    required this.onRestart,
  });

  final Challenge challenge;
  final bool restarting;
  final VoidCallback onOpen;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final expired = challenge.expired;

    return ChallengeCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(challenge: challenge),
          if (expired) ...[
            const SizedBox(height: 10),
            ChallengeBadge(
              icon: Icons.event_busy,
              label: 'Prazo encerrado',
              background: AppColors.brandTertiaryAccent.withValues(alpha: 0.35),
              foreground: AppColors.onTertiaryContainer,
            ),
            const SizedBox(height: 6),
            Text(
              'Você fez ${challengeStepsLabel(challenge)}. Ao recomeçar, a contagem volta a zero.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ],
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              challenge.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              ChallengeMeta(
                icon: Icons.stars,
                label: challengeBonusLabel(challenge),
                color: AppColors.brandDarkAccent,
                strong: true,
              ),
              ChallengeMeta(
                icon: Icons.people_outline,
                label: challengeParticipantsLabel(challenge),
              ),
              ChallengeMeta(
                icon: Icons.schedule,
                label:
                    expired
                        ? 'Novo prazo de ${daysLabel(challenge.durationDays)}'
                        : challenge.deadlineLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expired)
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Ver desafio'),
                  ),
                  FilledButton.icon(
                    onPressed: restarting ? null : onRestart,
                    icon:
                        restarting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Recomeçar'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                child: const Text('Ver desafio'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Desafio concluído, com o bônus recebido.
class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.challenge, required this.onOpen});

  final Challenge challenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ChallengeCard(
      onTap: onOpen,
      child: Row(
        children: [
          ChallengeIcon(icon: challenge.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    const ChallengeMeta(
                      icon: Icons.check_circle,
                      label: 'Concluído',
                      color: AppColors.brandDarkAccent,
                      strong: true,
                    ),
                    ChallengeMeta(
                      icon: Icons.stars,
                      label: challengeBonusReceivedLabel(challenge),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const ExcludeSemantics(
            child: Icon(
              Icons.chevron_right,
              color: AppColors.brandTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
