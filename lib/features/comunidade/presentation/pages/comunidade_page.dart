import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/local_guide_section.dart';
import '../widgets/new_post_dialog.dart';
import '../widgets/post_card.dart';

class ComunidadePage extends StatefulWidget {
  const ComunidadePage({super.key});

  @override
  State<ComunidadePage> createState() => _ComunidadePageState();
}

class _ComunidadePageState extends State<ComunidadePage> {
  final CommunityService _service = CommunityService.instance;
  final Listenable _listenable = Listenable.merge([
    CommunityService.instance,
    AuthService.instance,
  ]);
  final Set<String> _deleting = {};

  /// Verdadeiro entre a criação da tela e o início da primeira carga, para a
  /// lista abrir em "carregando" e não piscar um erro antigo.
  bool _starting = false;
  bool _composing = false;
  bool _commentsOpen = false;

  @override
  void initState() {
    super.initState();
    if (!_service.isLoaded) {
      _starting = true;
      // Fora do `build`: o serviço avisa os ouvintes assim que começa.
      Future.microtask(_load);
    }
  }

  /// Primeira carga e "Tentar de novo". O resultado chega pelo serviço.
  Future<void> _load() async {
    _starting = false;
    if (_service.loading) return;
    try {
      await _service.load();
    } catch (_) {
      // A lista mostra o erro e o botão "Tentar de novo".
    }
  }

  Future<void> _refresh() async {
    if (_service.loading) return;
    try {
      await _service.load();
    } catch (error) {
      if (!mounted) return;
      // Sem publicações carregadas, o erro já aparece no lugar da lista.
      if (!_service.isLoaded) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível atualizar as publicações.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNewPost() async {
    if (_composing) return;
    _composing = true;
    try {
      final created = await showNewPostDialog(context);
      if (!mounted) return;
      if (created == true) {
        _showMessage('Publicação compartilhada com a comunidade.');
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      _composing = false;
    }
  }

  /// O serviço ignora toques repetidos e aplica a resposta da API; a tela
  /// não adianta o resultado.
  Future<void> _toggleLike(CommunityPost post) async {
    try {
      await _service.toggleLike(post.id);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível registrar a curtida. Tente de novo.',
      );
    }
  }

  Future<void> _openComments(CommunityPost post) async {
    if (_commentsOpen) return;
    _commentsOpen = true;
    try {
      await showCommentsSheet(context, post.id);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      _commentsOpen = false;
    }
  }

  Future<void> _copyText(CommunityPost post) async {
    try {
      await Clipboard.setData(ClipboardData(text: post.content));
      if (!mounted) return;
      _showMessage('Texto copiado.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível copiar o texto.');
    }
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    if (!_deleting.add(post.id)) return;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              scrollable: true,
              title: Text(
                'Excluir publicação?',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'A publicação e os comentários dela serão apagados. '
                'Esta ação não pode ser desfeita.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextPrimary,
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
                    foregroundColor: AppColors.onError,
                  ),
                  child: const Text('Excluir'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
      await _service.deletePost(post.id);
      if (!mounted) return;
      _showMessage('Publicação excluída.');
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Não foi possível excluir a publicação. Tente de novo.',
      );
    } finally {
      _deleting.remove(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(pageIcon: Icons.groups, title: 'Comunidade'),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandDarkAccent,
          onRefresh: _refresh,
          child: ListenableBuilder(
            listenable: _listenable,
            builder: (context, _) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _NeighborhoodCard(
                    neighborhood: AuthService.instance.neighborhood.trim(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Publicações da comunidade',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.brandTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Composer(
                    initials: AuthService.instance.userInitials,
                    onTap: _openNewPost,
                  ),
                  const SizedBox(height: 10),
                  ..._buildFeed(),
                  const SizedBox(height: 14),
                  const LocalGuideSection(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeed() {
    if (!_service.isLoaded) {
      if (_service.loading || _starting) {
        return const [LoadingView(message: 'Carregando publicações…')];
      }
      return [
        LoadErrorView(
          message:
              _service.error ?? 'Não foi possível carregar as publicações.',
          onRetry: _load,
        ),
      ];
    }

    final posts = _service.posts;
    if (posts.isEmpty) {
      return [
        EmptyStateView(
          icon: Icons.forum_outlined,
          title: 'Seja a primeira pessoa a publicar',
          message:
              'Conte uma ação sustentável que você fez e inspire a vizinhança.',
          actionLabel: 'Nova publicação',
          onAction: _openNewPost,
        ),
      ];
    }

    return [
      for (final post in posts)
        Padding(
          key: ValueKey(post.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: CommunityPostCard(
            post: post,
            onToggleLike: () => _toggleLike(post),
            onOpenComments: () => _openComments(post),
            onCopyText: () => _copyText(post),
            onDelete: post.isMine ? () => _confirmDelete(post) : null,
          ),
        ),
    ];
  }
}

/// Bairro de quem está usando o app, vindo do cadastro.
class _NeighborhoodCard extends StatelessWidget {
  const _NeighborhoodCard({required this.neighborhood});

  final String neighborhood;

  @override
  Widget build(BuildContext context) {
    final hasNeighborhood = neighborhood.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
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
              child: const Icon(
                Icons.location_on,
                color: AppColors.brandDarkAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNeighborhood)
                  Text(
                    'Seu bairro',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                  ),
                Text(
                  hasNeighborhood ? neighborhood : 'Sua vizinhança',
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pequenos gestos somados transformam a nossa vizinhança.',
                  style: AppTextStyles.bodyMd.copyWith(
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

/// Atalho para escrever uma publicação.
class _Composer extends StatelessWidget {
  const _Composer({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.brandSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.brandBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.brandSecondaryContainer,
                      child: Text(
                        initials,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.brandDarkAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compartilhe uma ação com a comunidade',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.brandDarkAccent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
