import 'package:flutter/material.dart';

import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/state_views.dart';

// Blocos usados pelas telas Início e Meu progresso. Nenhum deles guarda
// números próprios: tudo chega pelos parâmetros, vindo dos serviços.

/// "1 dia", "2 dias", "1.240 pontos".
String countLabel(int count, String singular, String plural) {
  final number = UserProgressService.formatNumber(count);
  return '$number ${count == 1 ? singular : plural}';
}

/// Dias da semana por extenso, de segunda a domingo (para leitores de tela).
const List<String> weekdayFullNames = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

const List<String> _monthNames = [
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

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hoje, 08:30", "Ontem" ou "9 de novembro" (com o ano, se for outro).
String formatWhen(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (isSameDay(when, today)) {
    final hour = when.hour.toString().padLeft(2, '0');
    final minute = when.minute.toString().padLeft(2, '0');
    return 'Hoje, $hour:$minute';
  }
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (isSameDay(when, yesterday)) return 'Ontem';
  final date = '${when.day} de ${_monthNames[when.month - 1]}';
  return when.year == today.year ? date : '$date de ${when.year}';
}

/// Cartão padrão do app: fundo branco, raio 16 e borda `brandBorder`.
///
/// Com [onTap] o cartão inteiro vira um botão.
class EcoCard extends StatelessWidget {
  const EcoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.brandSurface,
    this.radius = 16,
    this.bordered = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side:
            bordered
                ? const BorderSide(color: AppColors.brandBorder)
                : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          onTap == null
              ? content
              : Semantics(
                button: true,
                child: InkWell(onTap: onTap, child: content),
              ),
    );
  }
}

/// Título de seção com subtítulo e, à direita, um botão de texto ou um
/// widget qualquer.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget? side;
    if (actionLabel != null && onAction != null) {
      side = TextButton(onPressed: onAction, child: Text(actionLabel!));
    } else if (trailing != null) {
      side = Padding(padding: const EdgeInsets.only(left: 8), child: trailing);
    } else {
      side = null;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
            ],
          ),
        ),
        // O lado direito ocupa no máximo metade da tela: com fonte grande o
        // texto dele quebra a linha em vez de empurrar o título para fora.
        if (side != null)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.5,
            ),
            child: side,
          ),
      ],
    );
  }
}

/// Barra de progresso arredondada. Aceita qualquer valor e limita a 0–1.
class EcoProgressBar extends StatelessWidget {
  const EcoProgressBar({
    super.key,
    required this.value,
    this.minHeight = 8,
    this.color = AppColors.brandDarkAccent,
    this.backgroundColor = AppColors.brandSecondaryContainer,
    this.semanticsLabel,
  });

  final double value;
  final double minHeight;
  final Color color;
  final Color backgroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: safeValue,
        minHeight: minHeight,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// Rótulo à esquerda e valor à direita. Em tela estreita ou com fonte
/// grande, o valor desce para a linha de baixo em vez de estourar.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor = AppColors.brandDarkAccent,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color iconColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style:
          labelStyle ??
          AppTextStyles.labelMd.copyWith(color: AppColors.brandTextPrimary),
    );
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 2,
        children: [
          if (icon == null)
            labelText
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Flexible(child: labelText),
              ],
            ),
          Text(
            value,
            style:
                valueStyle ??
                AppTextStyles.labelMd.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Nível atual, barra até o próximo nível e quanto falta.
class LevelProgressBlock extends StatelessWidget {
  const LevelProgressBlock({super.key, required this.progress});

  final UserProgressService progress;

  /// "Faltam 260 pts para o próximo nível" ou "Nível máximo".
  static String remainingLabel(UserProgressService progress) {
    if (progress.nextLevelAt == null) return 'Nível máximo';
    final missing = progress.pointsToNextLevel;
    if (missing == 1) return 'Falta 1 pt para o próximo nível';
    final number = UserProgressService.formatNumber(missing);
    return 'Faltam $number pts para o próximo nível';
  }

  @override
  Widget build(BuildContext context) {
    final level =
        progress.level.isNotEmpty
            ? progress.level
            : 'Nível ${progress.levelNumber}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.eco, size: 18, color: AppColors.brandDarkAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                level,
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        EcoProgressBar(
          value: progress.levelProgress,
          minHeight: 10,
          semanticsLabel: 'Progresso até o próximo nível',
        ),
        const SizedBox(height: 6),
        Text(
          remainingLabel(progress),
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Linha de um lançamento do histórico: ícone do próprio registro, título,
/// quando aconteceu e os pontos creditados.
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});

  final ActionRecord record;

  @override
  Widget build(BuildContext context) {
    final details = [
      formatWhen(record.dateTime),
      record.categoryLabel,
      if (record.capped) 'teto semanal atingido',
    ].join(' • ');
    final number = UserProgressService.formatNumber(record.points);
    final points = record.points >= 0 ? '+$number pts' : '$number pts';

    return Semantics(
      label:
          '${record.title}. $details. '
          '${countLabel(record.points, 'ponto', 'pontos')}.',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              record.icon,
              size: 20,
              color: AppColors.brandDarkAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
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
              points,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carregando ou erro de um módulo (histórico, desafios), para usar dentro
/// de um cartão no lugar de números zerados.
class ModuleStateView extends StatelessWidget {
  const ModuleStateView({super.key, required this.loading, this.error});

  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingView(padding: 16);
    return LoadErrorView(
      message: error ?? 'Não foi possível carregar esta parte.',
      padding: 8,
      onRetry: AuthService.instance.loadAll,
    );
  }
}
