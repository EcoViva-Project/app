import 'package:flutter/material.dart';

import '../../../../core/services/community_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum _PostMenuAction { copy, delete }

/// Cartão de uma publicação do feed da comunidade.
///
/// Não guarda estado: mostra o que o `CommunityService` informa e devolve os
/// toques para a tela.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onCopyText,
    this.onDelete,
  });

  final CommunityPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback onCopyText;

  /// Informado só quando a publicação é de quem está usando o app.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final commentCount = post.comments.length;
    final likeColor =
        post.likedByMe
            ? AppColors.brandDarkAccent
            : AppColors.brandTextSecondary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 2, 0),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brandSecondaryContainer,
                    child: Text(
                      post.authorInitials,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.brandDarkAccent,
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
                        post.authorName,
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      if (post.timeLabel.isNotEmpty)
                        Text(
                          post.timeLabel,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<_PostMenuAction>(
                  tooltip: 'Mais opções',
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.brandTextSecondary,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _PostMenuAction.copy:
                        onCopyText();
                      case _PostMenuAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: _PostMenuAction.copy,
                          child: Text('Copiar texto'),
                        ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: _PostMenuAction.delete,
                            child: Text('Excluir publicação'),
                          ),
                      ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              post.content,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
          // `Wrap` leva o segundo botão para a linha de baixo em telas
          // estreitas ou com texto ampliado, em vez de estourar.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            child: Wrap(
              spacing: 4,
              children: [
                Tooltip(
                  message:
                      post.likedByMe ? 'Remover curtida' : 'Curtir publicação',
                  child: TextButton.icon(
                    onPressed: onToggleLike,
                    icon: Icon(
                      post.likedByMe ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                    ),
                    label: Text('Curtir (${post.likes})'),
                    style: TextButton.styleFrom(
                      foregroundColor: likeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenComments,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    commentCount == 0 ? 'Comentar' : 'Comentar ($commentCount)',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
