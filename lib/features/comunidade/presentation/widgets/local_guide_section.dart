import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class _GuideItem {
  const _GuideItem({
    required this.icon,
    required this.name,
    required this.description,
    this.address,
    this.schedule,
  });

  final IconData icon;
  final String name;
  final String description;
  final String? address;
  final String? schedule;
}

/// Conteúdo editorial fixo. Não vem da API nem muda sozinho, por isso não
/// tem contadores, distâncias nem botões de participação.
const List<_GuideItem> _guideItems = [
  _GuideItem(
    icon: Icons.yard,
    name: 'Horta comunitária',
    description:
        'Espaço coletivo de cultivo de hortaliças e ervas. A vizinhança se '
        'reveza nos cuidados e compartilha a colheita.',
    address: 'Rua das Acácias, 120',
    schedule: 'Aberta diariamente, das 7h às 18h',
  ),
  _GuideItem(
    icon: Icons.recycling,
    name: 'Ponto de coleta',
    description:
        'Recebe vidro, papel, plástico e metal já separados. Os materiais '
        'são encaminhados à cooperativa local.',
    address: 'Av. das Flores, 450, perto da praça central',
    schedule: 'Segunda a sábado, das 8h às 17h',
  ),
  _GuideItem(
    icon: Icons.swap_horiz,
    name: 'Feira de trocas',
    description:
        'Encontro para trocar roupas, livros e objetos em bom estado em vez '
        'de comprar novos.',
    schedule: 'Domingo, às 10h',
  ),
];

/// Seção informativa "Pontos e iniciativas do bairro".
class LocalGuideSection extends StatelessWidget {
  const LocalGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pontos e iniciativas do bairro',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Conteúdo fixo de demonstração: os endereços e horários são ilustrativos.',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.brandSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < _guideItems.length; i++) ...[
                if (i > 0)
                  const Divider(height: 24, color: AppColors.brandBorder),
                _GuideTile(item: _guideItems[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.item});

  final _GuideItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 20, color: AppColors.brandDarkAccent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.brandTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.description,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
              if (item.address != null) ...[
                const SizedBox(height: 6),
                _GuideDetail(
                  icon: Icons.location_on_outlined,
                  label: 'Endereço',
                  text: item.address!,
                ),
              ],
              if (item.schedule != null) ...[
                const SizedBox(height: 4),
                _GuideDetail(
                  icon: Icons.schedule,
                  label: 'Horário',
                  text: item.schedule!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideDetail extends StatelessWidget {
  const _GuideDetail({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brandDarkAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
