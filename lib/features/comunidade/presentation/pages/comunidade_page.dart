import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/services/neighborhood_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/collection_points_section.dart';
import '../widgets/collective_goal_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/community_numbers.dart';
import '../widgets/community_section.dart';
import '../widgets/new_post_dialog.dart';
import '../widgets/post_card.dart';
import '../widgets/weekly_ranking_card.dart';

class ComunidadePage extends StatefulWidget {
  const ComunidadePage({super.key});

  @override
  State<ComunidadePage> createState() => _ComunidadePageState();
}

class _ComunidadePageState extends State<ComunidadePage> {
  final CommunityService _service = CommunityService.instance;
  final NeighborhoodService _neighborhood = NeighborhoodService.instance;
  final Listenable _listenable = Listenable.merge([
    CommunityService.instance,
    NeighborhoodService.instance,
    AuthService.instance,
  ]);
  final Set<String> _deleting = {};

  /// Verdadeiros entre a criação da tela e o início da primeira carga, para
  /// os blocos abrirem em "carregando" e não piscarem um erro antigo.
  bool _starting = false;
  bool _startingNeighborhood = false;
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
    if (_neighborhood.stats == null && !_neighborhood.loading) {
      _startingNeighborhood = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadNeighborhood().catchError((Object _) {});
      });
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

  /// Números, meta, ranking e pontos de coleta. O erro aparece no bloco.
  Future<void> _loadNeighborhood() async {
    _startingNeighborhood = false;
    if (_neighborhood.loading) return;
    try {
      await _neighborhood.load();
    } catch (_) {
      // O bloco mostra o erro e o botão "Tentar de novo".
    }
  }

  /// Puxar para atualizar: recarrega os dois serviços, cada um por si.
  Future<void> _refresh() async {
    Future<Object?> attempt(Future<void> Function() load) =>
        load().then<Object?>((_) => null).catchError((Object error) => error);

    final errors = await Future.wait([
      if (!_neighborhood.loading) attempt(_neighborhood.load),
      if (!_service.loading) attempt(_service.load),
    ]);
    if (!mounted) return;
    // Sem dados na tela, o erro já aparece no lugar do bloco.
    final error = errors.whereType<Object>().firstOrNull;
    if (error == null) return;
    if (_neighborhood.stats == null && !_service.isLoaded) return;
    showErrorSnackBar(
      context,
      error,
      fallback: 'Não foi possível atualizar a comunidade.',
    );
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
                  _RegionLine(region: AuthService.instance.regionLabel),
                  const SizedBox(height: 16),
                  ..._buildNeighborhood(),
                  const CommunitySectionTitle(
                    title: 'Publicações da comunidade',
                  ),
                  _Composer(
                    initials: AuthService.instance.userInitials,
                    onTap: _openNewPost,
                  ),
                  const SizedBox(height: 10),
                  ..._buildFeed(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Números, meta, ranking e pontos de coleta: tudo do `NeighborhoodService`.
  /// Se a carga falhar, só estes blocos mostram o erro; o feed continua.
  List<Widget> _buildNeighborhood() {
    const gap = SizedBox(height: 24);
    final stats = _neighborhood.stats;
    if (stats == null) {
      return [
        const CommunitySectionTitle(title: 'Números da comunidade'),
        if (_neighborhood.loading || _startingNeighborhood)
          const LoadingView(message: 'Carregando os números da comunidade…')
        else
          CommunityCard(
            child: LoadErrorView(
              message:
                  _neighborhood.error ??
                  'Não foi possível carregar os números da comunidade.',
              onRetry: _loadNeighborhood,
              padding: 8,
            ),
          ),
        gap,
      ];
    }

    final goal = stats.goal;
    return [
      const CommunitySectionTitle(title: 'Números da comunidade'),
      CommunityNumbers(stats: stats),
      gap,
      if (goal != null) ...[CollectiveGoalCard(goal: goal), gap],
      const CommunitySectionTitle(title: 'Ranking da semana'),
      WeeklyRankingCard(stats: stats),
      gap,
      const CommunitySectionTitle(title: 'Pontos de coleta perto de você'),
      CollectionPointsSection(points: _neighborhood.collectionPoints),
      gap,
    ];
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

/// Lugar de quem está usando o app ("Boa Vista, São José do Rio Preto").
class _RegionLine extends StatelessWidget {
  const _RegionLine({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: region.isEmpty ? 'Sua vizinhança' : 'Sua região: $region',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.location_on,
              size: 18,
              color: AppColors.brandDarkAccent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              region.isEmpty ? 'Sua vizinhança' : region,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.brandTextPrimary,
              ),
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
