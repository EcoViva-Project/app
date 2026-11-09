import 'package:flutter/material.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'inline_error.dart';

/// Abre a folha de comentários da publicação [postId].
Future<void> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => CommentsSheet(postId: postId),
  );
}

/// Lista os comentários de uma publicação e permite enviar um novo.
///
/// A lista vem sempre do `CommunityService`, então se atualiza sozinha quando
/// um comentário é criado.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  static const int _maxLength = 500;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreva um comentário antes de enviar.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await CommunityService.instance.addComment(widget.postId, text);
      if (!mounted) return;
      // O texto só sai do campo depois que o comentário foi salvo.
      _controller.clear();
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            error is ApiException
                ? error.message
                : 'Não foi possível enviar o comentário. Tente de novo.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sobe junto com o teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: CommunityService.instance,
          builder: (context, _) {
            final post = CommunityService.instance.byId(widget.postId);
            final comments = post?.comments ?? const <CommunityComment>[];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          comments.isEmpty
                              ? 'Comentários'
                              : 'Comentários (${comments.length})',
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.brandTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(child: _buildList(post, comments)),
                // As chaves mantêm o campo (e o teclado aberto) quando a faixa
                // de erro aparece ou some logo acima dele.
                if (_error != null)
                  Padding(
                    key: const ValueKey('comment-error'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: CommunityInlineError(message: _error!),
                  ),
                if (post != null) _buildInput(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(CommunityPost? post, List<CommunityComment> comments) {
    if (post == null) {
      return const _SheetMessage('Esta publicação não está mais disponível.');
    }
    if (comments.isEmpty) {
      return const _SheetMessage(
        'Nenhum comentário ainda. Que tal começar a conversa?',
      );
    }
    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _CommentTile(comment: comments[index]),
    );
  }

  Widget _buildInput() {
    return Padding(
      key: const ValueKey('comment-input'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              readOnly: _sending,
              maxLength: _maxLength,
              minLines: 1,
              maxLines: 4,
              // Teclado de texto comum: a tecla de ação envia o comentário e
              // o texto longo quebra de linha sozinho.
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              // Mantém o teclado aberto depois de enviar.
              onEditingComplete: _send,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Escreva um comentário',
                hintStyle: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
                filled: true,
                fillColor: AppColors.brandBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.brandBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.brandBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.brandDarkAccent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Enviar comentário',
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brandDarkAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.brandSecondaryContainer,
              minimumSize: const Size(48, 48),
            ),
            icon:
                _sending
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandDarkAccent,
                        semanticsLabel: 'Enviando comentário',
                      ),
                    )
                    : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brandSecondaryContainer,
              child: Text(
                comment.authorInitials,
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
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      comment.authorName,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                    if (comment.timeLabel.isNotEmpty)
                      Text(
                        comment.timeLabel,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
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
