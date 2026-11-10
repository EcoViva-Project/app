import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Frase de privacidade da posição exata, igual em todo o app.
const String kExactPositionPrivacy =
    'Só você vê sua posição exata. Os vizinhos veem a região do seu bairro.';

/// O que a pessoa escolheu na folha "Você".
enum MyPositionChoice { useLocation, adjust, backToRegion }

/// Folha aberta ao tocar no próprio marcador: de onde vem a posição e o que
/// dá para fazer com ela.
///
/// [sourceLabel] completa "Sua posição: ..." ("pela localização do celular",
/// "ajustada por você" ou "região do bairro Boa Vista").
Future<MyPositionChoice?> showMyPositionSheet(
  BuildContext context, {
  required String sourceLabel,
  required bool hasExactPosition,
}) {
  return showModalBottomSheet<MyPositionChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (context) => _SheetBody(
          title: 'Você',
          children: [
            Text(
              'Sua posição: $sourceLabel.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              kExactPositionPrivacy,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  () => Navigator.of(context).pop(MyPositionChoice.useLocation),
              icon: const Icon(Icons.my_location),
              label: const Text('Usar minha localização'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  () => Navigator.of(context).pop(MyPositionChoice.adjust),
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('Ajustar no mapa'),
            ),
            if (hasExactPosition) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(MyPositionChoice.backToRegion),
                icon: const Icon(Icons.undo),
                label: const Text('Voltar para a região do bairro'),
              ),
            ],
          ],
        ),
  );
}

/// Explicação mostrada uma vez, antes do pedido de permissão do sistema.
/// Devolve `true` se a pessoa quer usar a localização.
Future<bool> showLocationIntroSheet(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.brandSurface,
    builder:
        (context) => _SheetBody(
          title: 'Mostrar onde você está?',
          children: [
            Text(
              'Com a localização do celular, seu marcador fica no lugar certo '
              'do mapa e as distâncias até os pontos de coleta ficam mais '
              'precisas.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kExactPositionPrivacy,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.my_location),
              label: const Text('Usar minha localização'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
          ],
        ),
  );
  return accepted == true;
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
