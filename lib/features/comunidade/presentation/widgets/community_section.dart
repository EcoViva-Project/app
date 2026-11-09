import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Escolhe entre singular e plural: `plural(1, 'ação', 'ações')`.
String plural(int count, String one, String many) => count == 1 ? one : many;

/// Título de um bloco da tela, com subtítulo opcional.
class CommunitySectionTitle extends StatelessWidget {
  const CommunitySectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cartão branco padrão da tela (raio 16, borda clara).
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.brandSurface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: child,
    );
  }
}

/// Ícone dentro de um círculo verde-claro, decorativo.
class CommunityIconBadge extends StatelessWidget {
  const CommunityIconBadge({super.key, required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.brandSecondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size / 2, color: AppColors.brandDarkAccent),
      ),
    );
  }
}

/// Linha "ícone + texto" usada em detalhes (endereço, horário, telefone).
class CommunityDetailLine extends StatelessWidget {
  const CommunityDetailLine({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    this.style,
  });

  final IconData icon;

  /// Nome do dado para leitores de tela ("Endereço", "Horário").
  final String label;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.brandDarkAccent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style:
                  style ??
                  AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
