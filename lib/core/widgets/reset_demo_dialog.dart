import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Pergunta antes de restaurar a demonstração (Perfil e aviso da Início).
///
/// [afterwards] diz o que o app faz depois (por exemplo "Depois, o app abre
/// a tela de entrada."). Devolve `true` se a pessoa confirmou.
Future<bool> confirmResetDemo(
  BuildContext context, {
  required String afterwards,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Restaurar demonstração?',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Os dados deste aparelho serão apagados e a conta de demonstração '
            'volta ao início. Sua posição no mapa continua guardada. '
            '$afterwards',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restaurar'),
            ),
          ],
        ),
  );
  return confirmed == true;
}
