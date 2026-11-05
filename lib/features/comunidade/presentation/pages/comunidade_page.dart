import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';

class _CommunityPost {
  _CommunityPost({
    required this.id,
    required this.name,
    required this.initials,
    required this.action,
    required this.time,
    required this.likes,
    required this.liked,
    List<String>? comments,
  }) : comments = List<String>.of(comments ?? const []);

  final String id;
  final String name;
  final String initials;
  final String action;
  final String time;
  int likes;
  bool liked;
  final List<String> comments;
}

class ComunidadePage extends StatefulWidget {
  const ComunidadePage({super.key});

  @override
  State<ComunidadePage> createState() => _ComunidadePageState();
}

class _ComunidadePageState extends State<ComunidadePage> {
  late final List<_CommunityPost> _posts;
  final Set<int> _joinedInitiatives = {};

  @override
  void initState() {
    super.initState();
    _posts = [];
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      await CommunityService.instance.load();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(
            CommunityService.instance.posts.map(
              (post) => _CommunityPost(
                id: post.id,
                name: post.authorName,
                initials: post.authorInitials,
                action: post.content,
                time: post.timeLabel,
                likes: post.likes,
                liked: post.likedByMe,
                comments:
                    post.comments.map((comment) => comment.content).toList(),
              ),
            ),
          );
      });
    } catch (_) {
      // O feed permanece vazio se a API estiver indisponível.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.groups,
        title: 'Comunidade',
        onProfilePressed: () => context.go('/perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _communityHeader(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _collectiveGoal(context),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pontos ecológicos locais',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Perto de você',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _localPointTile(
                        context,
                        icon: Icons.yard,
                        title: 'Horta\nComunitária',
                        detail: 'A 180m',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _localPointTile(
                        context,
                        icon: Icons.recycling,
                        title: 'Ecoponto\ndo Bairro',
                        detail: 'A 400m',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _localPointTile(
                        context,
                        icon: Icons.compost,
                        title: 'Compostagem\nColetiva',
                        detail: 'A 650m',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Iniciativas locais',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAllInitiatives(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver todas',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _initiativeCard(
                  context,
                  id: 0,
                  icon: Icons.cleaning_services,
                  category: 'Espaços Públicos • Sábado, 09:00',
                  title: 'Mutirão de Limpeza na Praça Central',
                  description:
                      'Cuidado com canteiros, recolhimento de resíduos e pintura ecológica nos bancos públicos.',
                  footer: '26 vizinhos confirmados',
                  actionLabel: 'Participar',
                  confirmLabel: 'Confirmado',
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _initiativeCard(
                  context,
                  id: 1,
                  icon: Icons.inventory_2_outlined,
                  category: 'Coleta Seletiva • Em andamento',
                  title: 'Campanha de Arrecadação de Vidro & Papel',
                  description:
                      'Ponto voluntário de entrega temporária destinado à cooperativa local de reciclagem parceira.',
                  footer: '42 entregas registradas',
                  actionLabel: 'Como entregar',
                  isInformationOnly: true,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ações recentes dos vizinhos',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandSecondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Tempo real',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandDarkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _composer(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (int i = 0; i < _posts.length; i++) ...[
                      _postCard(_posts[i]),
                      if (i < _posts.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.brandSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '"O futuro sustentável é feito por comunidades inteiras cuidando do seu pedacinho de terra."',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _communityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Bairro ${AuthService.instance.neighborhood}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ao vivo',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Pequenos gestos somados transformam a nossa vizinhança.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _headerStat(
                  icon: Icons.spa,
                  value: '128',
                  label: 'vizinhos ativos',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _headerStat(
                  icon: Icons.eco,
                  value: '1.840',
                  label: 'ações coletivas',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectiveGoal(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandSecondaryContainer, AppColors.brandSurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_circle,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Meta Coletiva da Semana',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.brandDarkAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 12,
                        color: AppColors.brandTextSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '2 dias restantes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandTextSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nossa Comunidade Mais Verde',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Alcançar 500 registros de substituição de descartáveis e reciclagem consciente entre os vizinhos do bairro.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '380 de 500 ações',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '76% alcançado',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.brandDarkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.76,
              minHeight: 10,
              backgroundColor: AppColors.brandSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 14,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '84 vizinhos já contribuíram',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
              Text(
                'Meta de domingo',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/acoes'),
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text('Registrar contribuição'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.labelMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _localPointTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return GestureDetector(
      onTap:
          () => _showLocalPoint(
            context,
            title: title,
            detail: detail,
            icon: icon,
          ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brandBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.brandSecondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.brandPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandTextPrimary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandTextSecondary,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Explorar',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initiativeCard(
    BuildContext context, {
    required int id,
    required IconData icon,
    required String category,
    required String title,
    required String description,
    required String footer,
    required String actionLabel,
    String? confirmLabel,
    bool isInformationOnly = false,
  }) {
    final joined = _joinedInitiatives.contains(id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.brandSecondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      title,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 14,
                color: AppColors.brandTextSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  footer,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (isInformationOnly) {
                    _showDeliveryInstructions(context);
                    return;
                  }
                  setState(() {
                    if (!_joinedInitiatives.add(id)) {
                      _joinedInitiatives.remove(id);
                    }
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor:
                      joined
                          ? AppColors.brandSecondaryContainer
                          : AppColors.brandPrimary,
                  foregroundColor:
                      joined ? AppColors.brandDarkAccent : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(joined ? Icons.check : Icons.add_circle, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      joined ? (confirmLabel ?? 'Confirmado') : actionLabel,
                      style: AppTextStyles.labelSm.copyWith(
                        color:
                            joined ? AppColors.brandDarkAccent : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _createPost,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandSecondaryContainer,
                  child: Text(
                    AuthService.instance.userInitials,
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Compartilhe uma ação com a comunidade',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_outlined,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nova publicação',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Conte o que você fez pelo bairro...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Publicar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || text == null || text.isEmpty) {
      return;
    }

    try {
      final post = await CommunityService.instance.createPost(text);
      if (!mounted) return;
      setState(() {
        _posts.insert(
          0,
          _CommunityPost(
            id: post.id,
            name: post.authorName,
            initials: post.authorInitials,
            action: post.content,
            time: post.timeLabel,
            likes: post.likes,
            liked: post.likedByMe,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publicação compartilhada com a comunidade!'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _postCard(_CommunityPost post) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandSecondaryContainer,
                  child: Text(
                    post.initials,
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.brandDarkAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.name,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      Text(
                        post.time,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.liked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Apoiado',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.brandDarkAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.action,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final wasLiked = post.liked;
                    setState(() {
                      post.liked = !post.liked;
                      post.likes += post.liked ? 1 : -1;
                    });
                    try {
                      await CommunityService.instance.toggleLike(post.id);
                    } on ApiException {
                      if (!mounted) return;
                      setState(() {
                        post.liked = wasLiked;
                        post.likes += wasLiked ? 1 : -1;
                      });
                    }
                  },
                  icon: Icon(
                    post.liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color:
                        post.liked
                            ? AppColors.brandPrimary
                            : AppColors.brandTextSecondary,
                  ),
                  label: Text('Celebrar (${post.likes})'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        post.liked
                            ? AppColors.brandPrimary
                            : AppColors.brandTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openComments(post),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    post.comments.isEmpty
                        ? 'Comentar'
                        : 'Comentar (${post.comments.length})',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Compartilhar publicação',
                  onPressed: () => _sharePost(post),
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.brandTextSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePost(_CommunityPost post) async {
    await Clipboard.setData(
      ClipboardData(text: '${post.name} na EcoViva: ${post.action}'),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publicação copiada para compartilhar!')),
    );
  }

  void _showLocalPoint(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final name = title.replaceAll('\n', ' ');
    late final String address;
    late final String hours;
    late final String description;

    if (name.contains('Horta')) {
      address = 'Rua das Acácias, 120 — Jardim das Flores';
      hours = 'Aberta diariamente, das 7h às 18h';
      description =
          'Espaço coletivo de cultivo de hortaliças e ervas. Vizinhos se revezam nos cuidados e compartilham a colheita.';
    } else if (name.contains('Ecoponto')) {
      address = 'Av. das Flores, 450 — próximo à praça central';
      hours = 'Segunda a sábado, das 8h às 17h';
      description =
          'Recebe vidro, papel, plástico e metal já separados. Os materiais são encaminhados à cooperativa local.';
    } else {
      address = 'Rua do Composto, 80 — ao lado da horta';
      hours = 'Terças e quintas, das 9h às 16h';
      description =
          'Composteira comunitária que transforma resíduos orgânicos em adubo para os canteiros do bairro.';
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.brandSecondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.brandPrimary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.brandTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$detail de você',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(Icons.location_on_outlined, address),
                const SizedBox(height: 6),
                _infoRow(Icons.schedule, hours),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: address));
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Endereço copiado!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar endereço'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.brandBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.brandPrimary),
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
    );
  }

  void _showAllInitiatives(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Iniciativas do bairro',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Participe das ações coletivas organizadas pelos vizinhos do Jardim das Flores.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _initiativeSummary(
                  icon: Icons.cleaning_services,
                  title: 'Mutirão de Limpeza na Praça Central',
                  info: 'Espaços Públicos • Sábado, 09:00 • 26 confirmados',
                ),
                const SizedBox(height: 8),
                _initiativeSummary(
                  icon: Icons.inventory_2_outlined,
                  title: 'Campanha de Arrecadação de Vidro & Papel',
                  info: 'Coleta Seletiva • Em andamento • 42 entregas',
                ),
                const SizedBox(height: 8),
                _initiativeSummary(
                  icon: Icons.swap_horiz,
                  title: 'Feira de Trocas Sustentáveis',
                  info: 'Consumo Consciente • Domingo, 10:00 • 18 confirmados',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _initiativeSummary({
    required IconData icon,
    required String title,
    required String info,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.brandSecondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  info,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.brandTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Como entregar',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _instructionStep(
                '1',
                'Separe vidro e papel limpos, sem restos de comida.',
              ),
              const SizedBox(height: 8),
              _instructionStep('2', 'Embale materiais cortantes com cuidado.'),
              const SizedBox(height: 8),
              _instructionStep(
                '3',
                'Entregue no Ecoponto do Bairro (Av. das Flores, 450), de segunda a sábado, das 8h às 17h.',
              ),
              const SizedBox(height: 8),
              _instructionStep(
                '4',
                'A equipe da cooperativa registra sua entrega no app.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Widget _instructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.brandSecondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _openComments(_CommunityPost post) {
    final controller = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: AppColors.brandBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Comentários (${post.comments.length})',
                              style: AppTextStyles.headlineSm.copyWith(
                                color: AppColors.brandTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.brandTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Text(
                          'Nenhum comentário ainda. Que tal começar a conversa?',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: post.comments.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.brandBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                post.comments[index],
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.brandTextPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                _submitComment(post, controller, setSheetState);
                              },
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.brandTextPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Escreva um comentário...',
                                hintStyle: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.brandTextSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.brandBackground,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () {
                              _submitComment(post, controller, setSheetState);
                            },
                            icon: const Icon(Icons.send, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _submitComment(
    _CommunityPost post,
    TextEditingController controller,
    StateSetter setSheetState,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    controller.clear();
    try {
      await CommunityService.instance.addComment(post.id, text);
      if (!mounted) return;
      setState(() => post.comments.add(text));
      setSheetState(() {});
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
