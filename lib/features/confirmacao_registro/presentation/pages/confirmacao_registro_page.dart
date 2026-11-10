import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/achievement_service.dart';
import '../../../../core/services/action_history_service.dart';
import '../../../../core/services/challenge_service.dart';
import '../../../../core/services/photo_proof.dart';
import '../../../../core/services/user_progress_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/record_photo.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/weekly_cap_card.dart';

/// Resumo do último registro feito nesta sessão.
///
/// Tudo o que aparece aqui vem da resposta da API guardada em
/// `ActionHistoryService.lastSubmission`. Sem registro, a tela diz isso em vez
/// de mostrar um sucesso.
class ConfirmacaoRegistroPage extends StatelessWidget {
  const ConfirmacaoRegistroPage({super.key});

  static final Listenable _services = Listenable.merge([
    ActionHistoryService.instance,
    UserProgressService.instance,
  ]);

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
          tooltip: 'Fechar',
          icon: const Icon(Icons.close, color: AppColors.brandTextPrimary),
          onPressed: () => context.go('/acoes'),
        ),
        title: Text(
          'Confirmação',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _services,
          builder: (context, _) {
            final result = ActionHistoryService.instance.lastSubmission;
            if (result == null) {
              return EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: 'Nenhum registro para mostrar',
                message: 'Registre uma ação para ver o resumo aqui.',
                actionLabel: 'Ver ações',
                onAction: () => context.go('/acoes'),
              );
            }
            return _ConfirmationContent(result: result);
          },
        ),
      ),
    );
  }
}

class _ConfirmationContent extends StatelessWidget {
  const _ConfirmationContent({required this.result});

  final RegisteredAction result;

  @override
  Widget build(BuildContext context) {
    final record = result.record;
    final progress = UserProgressService.instance;
    final basePoints = record.basePoints ?? record.points;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: ExcludeSemantics(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.brandSecondaryContainer,
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.brandDarkAccent,
                  size: 52,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'Ação registrada!',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            record.quantity > 1
                ? '${record.title} (${record.quantity} vezes)'
                : record.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
          if (record.photo != null) ...[
            const SizedBox(height: 16),
            _PhotoCard(photo: record.photo!, title: record.title),
          ],
          const SizedBox(height: 20),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ValueRow(
                  icon: Icons.eco,
                  label: 'Pontos creditados',
                  value: '+${record.points} pts',
                  emphasized: true,
                ),
                if (record.capped) ...[
                  const SizedBox(height: 10),
                  _CapNotice(
                    text:
                        record.points > 0
                            ? 'Esta ação vale $basePoints pts; entraram ${record.points} por causa do teto semanal.'
                            : 'Teto semanal atingido: a ação foi registrada sem pontos e continua valendo para desafios e conquistas.',
                  ),
                ],
                if (record.liters > 0) ...[
                  const SizedBox(height: 12),
                  _ValueRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Água poupada (estimativa)',
                    value: '${record.liters} L',
                  ),
                ],
                if (progress.isLoaded) ...[
                  const Divider(height: 24, color: AppColors.brandBorder),
                  _ValueRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo disponível',
                    value: '${progress.formattedPoints} pts',
                  ),
                ],
              ],
            ),
          ),
          if (result.newAchievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle('Novas conquistas'),
            for (final achievement in result.newAchievements) ...[
              const SizedBox(height: 8),
              _AchievementTile(achievement: achievement),
            ],
          ],
          if (result.challengeUpdates.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle('Desafios que avançaram'),
            for (final challenge in result.challengeUpdates) ...[
              const SizedBox(height: 8),
              _ChallengeTile(challenge: challenge),
            ],
          ],
          const SizedBox(height: 16),
          const WeeklyCapCard(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/acoes'),
            icon: const Icon(Icons.add_task, size: 20),
            label: const Text('Registrar outra ação'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              textStyle: AppTextStyles.labelLg,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/meu-historico'),
            icon: const Icon(Icons.history, size: 20),
            label: const Text('Ver meu histórico'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              textStyle: AppTextStyles.labelLg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: child,
    );
  }
}

/// Miniatura da foto de comprovação com o selo. Tocar abre a foto inteira.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.title});

  final RecordPhoto photo;
  final String title;

  @override
  Widget build(BuildContext context) {
    void open() => showRecordPhoto(context, photo, title: title);
    return _Card(
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Ver a foto de comprovação',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: open,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  key: const ValueKey<String>('confirmacao-foto'),
                  width: 72,
                  height: 72,
                  child: RecordPhotoImage(photo: photo, cacheWidth: 216),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProofBadge(onTap: open),
                const SizedBox(height: 6),
                Text(
                  'A foto fica só neste celular e não muda os pontos.',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: AppTextStyles.labelLg.copyWith(
          color: AppColors.brandTextPrimary,
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brandDarkAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: (emphasized ? AppTextStyles.headlineSm : AppTextStyles.labelLg)
              .copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTertiaryAccent.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandTertiaryAccent.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.speed_outlined, size: 20, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.brandSecondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.brandDarkAccent, size: 22),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          _TileIcon(achievement.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${achievement.points} pts de bônus',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
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

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileIcon(challenge.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.stepsLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: challenge.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.brandSecondaryContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.brandDarkAccent,
                      ),
                    ),
                  ),
                ),
                if (challenge.completed) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Desafio concluído! +${challenge.pointsReward} pts de bônus',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
