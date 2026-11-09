import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/action_catalog_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/day_status_circle.dart';

// Peças usadas pela aba Desafios e pela tela de detalhes do desafio.

/// "1 dia" ou "7 dias".
String daysLabel(int days) => days == 1 ? '1 dia' : '$days dias';

String _pointsLabel(int points) =>
    '+${UserProgressService.formatNumber(points)} ${points == 1 ? 'pt' : 'pts'}';

/// "+100 pts de bônus".
String challengeBonusLabel(Challenge challenge) =>
    '${_pointsLabel(challenge.pointsReward)} de bônus';

/// "Bônus recebido: +100 pts".
String challengeBonusReceivedLabel(Challenge challenge) =>
    'Bônus recebido: ${_pointsLabel(challenge.pointsReward)}';

/// "1 participante" ou "184 participantes".
String challengeParticipantsLabel(Challenge challenge) {
  final count = challenge.participants;
  return count == 1
      ? '1 participante'
      : '${UserProgressService.formatNumber(count)} participantes';
}

/// Igual a [Challenge.stepsLabel], com singular quando a meta é uma etapa só
/// ("0 de 1 ação" em vez de "0 de 1 ações").
String challengeStepsLabel(Challenge challenge) {
  if (challenge.targetSteps != 1) return challenge.stepsLabel;
  return '${challenge.completedSteps} de 1 ${challenge.countsByDay ? 'dia' : 'ação'}';
}

/// Texto do botão principal de um desafio em andamento.
String registerActionLabel(Challenge challenge) =>
    'Registrar ação de ${challenge.category}';

/// Leva ao registro de uma ação da categoria do desafio.
///
/// Com uma única ação na categoria, abre direto o registro dela; se essa ação
/// já atingiu o limite de hoje ou da semana, avisa em vez de navegar. Com
/// várias ações (ou catálogo ainda não carregado), abre a aba Ações filtrada.
void openChallengeAction(BuildContext context, Challenge challenge) {
  final actions = ActionCatalogService.instance.byCategoryLabel(
    challenge.category,
  );
  if (actions.length == 1) {
    final action = actions.first;
    if (action.canRegister) {
      context.push('/registro-acao/${action.id}');
      return;
    }
    final blocked = action.blockedLabel;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '"${action.title}" já atingiu o limite de registros.'
            '${blocked == null ? '' : ' $blocked.'}',
          ),
        ),
      );
    return;
  }
  context.go(
    '/acoes?categoria=${Uri.encodeQueryComponent(challenge.category)}',
  );
}

/// Cartão branco padrão (raio 16 e borda), clicável quando recebe [onTap].
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.brandSurface,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Ícone do desafio dentro de um círculo.
class ChallengeIcon extends StatelessWidget {
  const ChallengeIcon({
    super.key,
    required this.icon,
    this.size = 44,
    this.background = AppColors.brandSecondaryContainer,
    this.foreground = AppColors.brandDarkAccent,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: foreground, size: size * 0.5),
      ),
    );
  }
}

/// Ícone pequeno seguido de um texto que quebra de linha se precisar.
class ChallengeMeta extends StatelessWidget {
  const ChallengeMeta({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.brandTextSecondary,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? AppTextStyles.labelMd : AppTextStyles.bodySm;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: style.copyWith(color: color))),
      ],
    );
  }
}

/// Selo arredondado com ícone e texto.
class ChallengeBadge extends StatelessWidget {
  const ChallengeBadge({
    super.key,
    required this.icon,
    required this.label,
    this.background = AppColors.brandSecondaryContainer,
    this.foreground = AppColors.brandDarkAccent,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: foreground)),
          const SizedBox(width: 6),
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

/// Barra de progresso do desafio.
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({
    super.key,
    required this.challenge,
    this.height = 8,
  });

  final Challenge challenge;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: challenge.progress,
        minHeight: height,
        backgroundColor: AppColors.brandSecondaryContainer,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        semanticsLabel: 'Progresso do desafio',
        semanticsValue: '${(challenge.progress * 100).round()}%',
      ),
    );
  }
}

/// Etapas numeradas de 1 a N.
///
/// Só faz sentido para desafios curtos: confira [fits] antes de usar.
class ChallengeStepsRow extends StatelessWidget {
  const ChallengeStepsRow({super.key, required this.challenge, this.size = 32});

  static const int maxSteps = 10;

  static bool fits(Challenge challenge) => challenge.targetSteps <= maxSteps;

  final Challenge challenge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final done = challenge.completedSteps;
    // A próxima etapa só fica em destaque se ainda puder ser contada agora.
    final nextIsOpen =
        challenge.inProgress &&
        !(challenge.countsByDay && challenge.stepDoneToday);
    // O texto "3 de 7 dias" já diz o mesmo para leitores de tela.
    return ExcludeSemantics(
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var i = 0; i < challenge.targetSteps; i++)
            DayStatusCircle(
              label: '${i + 1}',
              done: i < done,
              isToday: nextIsOpen && i == done,
              size: size,
              labelFontSize: 12,
            ),
        ],
      ),
    );
  }
}
