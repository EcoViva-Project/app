import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class DetalhesDesafioPage extends StatefulWidget {
  const DetalhesDesafioPage({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  State<DetalhesDesafioPage> createState() => _DetalhesDesafioPageState();
}

class _DetalhesDesafioPageState extends State<DetalhesDesafioPage> {
  final ChallengeService _service = ChallengeService.instance;

  int? _challengeId;
  Challenge? _challenge;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _challengeId = (widget.extra?['id'] as num?)?.toInt();
    final id = _challengeId;
    if (id != null) {
      _challenge = _service.byId(id);
      if (_challenge == null) {
        _service
            .fetch(id)
            .then((challenge) {
              if (mounted) setState(() => _challenge = challenge);
            })
            .catchError((_) {});
      }
    }
  }

  Future<void> _joinChallenge() async {
    final id = _challengeId;
    if (id == null) return;
    await _run(() async {
      final challenge = await _service.join(id);
      if (challenge != null && mounted) {
        setState(() => _challenge = challenge);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você entrou no desafio "${challenge.title}"!'),
          ),
        );
      }
    });
  }

  Future<void> _registerStep() async {
    final id = _challengeId;
    if (id == null) return;
    await _run(() async {
      final challenge = await _service.addProgress(id);
      if (challenge != null && mounted) {
        setState(() => _challenge = challenge);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              challenge.completed
                  ? 'Desafio concluído! +${challenge.pointsReward} pts'
                  : 'Etapa registrada! ${challenge.completedSteps} de ${challenge.targetSteps}',
            ),
          ),
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o desafio.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.extra ?? {};
    final challenge = _challenge;
    final title =
        challenge?.title ??
        extra['title']?.toString() ??
        'Semana Sem Descarte Único';
    final description =
        challenge?.description ??
        extra['description']?.toString() ??
        'Adote o hábito de substituir copos plásticos, sacolas descartáveis e embalagens de uso único por recipientes e ecobags reutilizáveis ao longo de 5 dias.';
    final category =
        challenge?.category ??
        extra['category']?.toString() ??
        'Reciclagem e Consumo Consciente';
    final points =
        challenge != null
            ? '+${challenge.pointsReward} pts'
            : extra['points']?.toString() ?? '+120 pts';
    final participants =
        challenge != null
            ? '${challenge.participants} vizinhos participando'
            : extra['participants']?.toString() ?? '42 vizinhos participando';

    final completedSteps = challenge?.completedSteps ?? 3;
    final targetSteps = challenge?.targetSteps ?? 5;
    final progress = challenge?.progress ?? 0.6;
    final isCompleted = challenge?.completed ?? false;
    final joined = challenge?.joined ?? false;

    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Detalhes do Desafio',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartilhar desafio',
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.brandTextSecondary,
            ),
            onPressed: () => _shareChallenge(title),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.compost, category),
                        _chip(Icons.groups, 'Desafio Coletivo da Semana'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            challenge != null
                                ? 'Termina em ${challenge.daysLeft} dias'
                                : 'Termina em 2 dias',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.brandTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.diversity_1,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            participants,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.brandTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Seu progresso pessoal',
                          style: AppTextStyles.labelLg.copyWith(
                            color: AppColors.brandDarkAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSecondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '$completedSteps de $targetSteps ${targetSteps == 1 ? 'etapa' : 'etapas'} (${(progress * 100).round()}%)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.brandDarkAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppColors.brandSecondaryContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 1; i <= targetSteps; i++)
                      _timelineItem(
                        'Etapa $i${i == completedSteps + 1 && !isCompleted ? ' • Hoje: registre sua etapa' : ''}',
                        i <= completedSteps,
                        isToday: i == completedSteps + 1 && !isCompleted,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Como Funciona',
                            style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _howToItem(
                      '1',
                      'Pratique a substituição diária',
                      'Evite pelo menos 1 item descartável por dia na sua rotina.',
                    ),
                    _howToItem(
                      '2',
                      'Registre a atitude',
                      'Tire uma foto opcional ou confirme com 1 clique no app.',
                    ),
                    _howToItem(
                      '3',
                      'Impacto comunitário',
                      'Cada registro soma para a meta coletiva dos vizinhos do bairro.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brandTertiaryAccent.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.military_tech,
                        color: AppColors.brandDarkAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recompensa final',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandDarkAccent,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            points,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Selo "Guardião sem Descarte" adicionado ao seu perfil',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      _busy || isCompleted
                          ? null
                          : (joined ? _registerStep : _joinChallenge),
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Icon(
                            isCompleted
                                ? Icons.check_circle
                                : (joined ? Icons.add_task : Icons.login),
                            size: 20,
                          ),
                  label: Text(
                    isCompleted
                        ? 'Desafio concluído!'
                        : (joined
                            ? 'Registrar etapa de hoje'
                            : 'Entrar no desafio'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isCompleted
                            ? AppColors.brandSecondaryContainer
                            : AppColors.brandPrimary,
                    foregroundColor:
                        isCompleted ? AppColors.brandDarkAccent : Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.brandSecondaryContainer,
                    disabledForegroundColor: AppColors.brandDarkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _shareChallenge(title, forNeighbors: true),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Convidar vizinhos ou compartilhar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandTextPrimary,
                    side: const BorderSide(color: AppColors.brandBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareChallenge(
    String title, {
    bool forNeighbors = false,
  }) async {
    final text =
        forNeighbors
            ? 'Bora participar do desafio "$title" comigo na EcoViva?'
            : 'Desafio na EcoViva: $title';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          forNeighbors
              ? 'Convite copiado para compartilhar com vizinhos!'
              : 'Link do desafio copiado!',
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(String label, bool done, {bool isToday = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  done
                      ? AppColors.brandPrimary
                      : (isToday
                          ? AppColors.brandSecondaryContainer
                          : AppColors.brandBackground),
              border: Border.all(
                color:
                    done
                        ? AppColors.brandPrimary
                        : (isToday
                            ? AppColors.brandPrimary
                            : AppColors.brandBorder),
              ),
            ),
            child:
                done
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isToday
                    ? const Icon(
                      Icons.wb_sunny_outlined,
                      color: AppColors.brandPrimary,
                      size: 16,
                    )
                    : const Icon(
                      Icons.lock_clock,
                      color: AppColors.brandTextSecondary,
                      size: 16,
                    ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color:
                    done || isToday
                        ? AppColors.brandTextPrimary
                        : AppColors.brandTextSecondary,
                fontWeight:
                    isToday && !done ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (done)
            Text(
              'Concluído',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (isToday)
            Text(
              'Pendente',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _howToItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.bodySm.copyWith(
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
}
