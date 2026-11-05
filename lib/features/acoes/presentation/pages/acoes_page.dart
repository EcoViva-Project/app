import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';

class AcoesPage extends StatefulWidget {
  const AcoesPage({super.key});

  @override
  State<AcoesPage> createState() => _AcoesPageState();
}

class _AcoesPageState extends State<AcoesPage> {
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortMode = 'relevance';

  final List<Map<String, dynamic>> _actions = [
    {
      'id': 1,
      'title': 'Fechar a torneira ao escovar os dentes',
      'description': 'Economia estimada de ~12L de água por ciclo',
      'category': 'agua',
      'categoryLabel': 'Água',
      'icon': Icons.water_drop,
      'points': '+15 pts',
      'pointsValue': 15,
      'liters': 12,
      'info': 'Hábito diário',
      'infoIcon': Icons.schedule,
      'tags': ['agua', 'torneira', 'dentes', 'banho'],
      'footerInfo': '432 vizinhos registraram hoje',
      'footerIcon': Icons.groups,
    },
    {
      'id': 2,
      'title': 'Separar resíduos secos e orgânicos',
      'description': 'Destino correto de plástico, papel, vidro e metal',
      'category': 'reciclagem',
      'categoryLabel': 'Reciclagem',
      'icon': Icons.recycling,
      'points': '+30 pts',
      'pointsValue': 30,
      'liters': 0,
      'info': 'Coleta seletiva',
      'infoIcon': Icons.recycling,
      'tags': ['reciclagem', 'lixo', 'residuos', 'secos', 'organicos'],
      'footerInfo': 'Evita 0.8kg de CO₂ equivalente',
      'footerIcon': Icons.eco,
    },
    {
      'id': 3,
      'title': 'Deslocamento a pé ou de bicicleta',
      'description': 'Mobilidade ativa sem emissões diretas de carbono',
      'category': 'transporte',
      'categoryLabel': 'Transporte',
      'icon': Icons.directions_bike,
      'points': '+40 pts',
      'pointsValue': 40,
      'liters': 0,
      'info': 'Saúde & Ar Limpo',
      'infoIcon': Icons.favorite,
      'tags': [
        'transporte',
        'bicicleta',
        'bike',
        'caminha',
        'pe',
        'mobilidade',
      ],
      'footerInfo': 'Distâncias de até 5 km',
      'footerIcon': Icons.route,
    },
    {
      'id': 4,
      'title': 'Compostagem de resíduos orgânicos',
      'description':
          'Cascas, borra de café e restos vegetais transformados em adubo',
      'category': 'alimentacao',
      'categoryLabel': 'Alimentação',
      'icon': Icons.compost,
      'points': '+35 pts',
      'pointsValue': 35,
      'liters': 0,
      'info': 'Nutrientes de volta ao solo',
      'infoIcon': Icons.yard,
      'tags': ['alimentacao', 'compostagem', 'comida', 'horta', 'adubo'],
      'footerInfo': 'Reduz 45% do lixo doméstico',
      'footerIcon': Icons.check_circle,
    },
    {
      'id': 5,
      'title': 'Apagar luzes em cômodos vazios',
      'description': 'Eficiência energética e redução no consumo mensal',
      'category': 'energia',
      'categoryLabel': 'Energia',
      'icon': Icons.lightbulb_outline,
      'points': '+20 pts',
      'pointsValue': 20,
      'liters': 0,
      'info': 'Consumo Consciente',
      'infoIcon': Icons.bolt,
      'tags': ['energia', 'luz', 'comodo', 'eletricidade', 'lampada'],
      'footerInfo': 'Até 10% de alívio na fatura',
      'footerIcon': Icons.savings,
    },
    {
      'id': 6,
      'title': 'Mutirão de limpeza de praça pública',
      'description':
          'Cuidado com os canteiros, descarte e conservação de áreas comuns',
      'category': 'publico',
      'categoryLabel': 'Espaços Públicos',
      'icon': Icons.park,
      'points': '+60 pts',
      'pointsValue': 60,
      'liters': 0,
      'info': 'Coletivo',
      'infoIcon': Icons.diversity_1,
      'tags': [
        'publico',
        'praca',
        'parque',
        'mutirao',
        'comunidade',
        'limpeza',
      ],
      'footerInfo': 'Insígnia de Zelador Cívico',
      'footerIcon': Icons.military_tech,
    },
  ];

  List<Map<String, dynamic>> get _filteredActions {
    final items =
        _actions.where((action) {
          final matchesCategory =
              _selectedCategory == 'all' ||
              action['category'] == _selectedCategory;
          final matchesSearch =
              _searchQuery.isEmpty ||
              action['title'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              action['description'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (action['tags'] as List).any(
                (tag) => tag.toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              );
          return matchesCategory && matchesSearch;
        }).toList();

    if (_sortMode == 'points') {
      items.sort((a, b) => _pointsOf(b).compareTo(_pointsOf(a)));
    } else if (_sortMode == 'alphabetical') {
      items.sort(
        (a, b) => a['title'].toString().toLowerCase().compareTo(
          b['title'].toString().toLowerCase(),
        ),
      );
    }

    return items;
  }

  int _pointsOf(Map<String, dynamic> action) {
    final digits = action['points'].toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return int.tryParse(digits) ?? 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppPageHeader(
        pageIcon: Icons.eco,
        title: 'Ações',
        profileInitials: 'C',
        onProfilePressed: () {
          context.go('/perfil');
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSecondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_ios_new,
                                size: 12,
                                color: AppColors.brandDarkAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Impacto Coletivo',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.brandDarkAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '• Hoje: +1.420 ações',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ações Sustentáveis',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.brandTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pequenos hábitos diários que geram grande impacto positivo na nossa comunidade.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Buscar ação (ex: torneira, reciclagem...)',
                            hintStyle: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.brandTextSecondary.withOpacity(
                                0.7,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.brandTextSecondary,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => _showFilters(context),
                        tooltip: 'Ordenar ações',
                        icon: Icon(
                          Icons.tune,
                          color:
                              _sortMode == 'relevance'
                                  ? AppColors.brandPrimary
                                  : AppColors.brandDarkAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryChip('all', 'Todas', Icons.done),
                    const SizedBox(width: 8),
                    _buildCategoryChip('agua', 'Água', Icons.water_drop),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      'energia',
                      'Energia',
                      Icons.lightbulb_outline,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      'reciclagem',
                      'Reciclagem',
                      Icons.recycling,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      'alimentacao',
                      'Alimentação',
                      Icons.compost,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      'transporte',
                      'Transporte',
                      Icons.directions_bike,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      'publico',
                      'Espaços Públicos',
                      Icons.park,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Atividades Sugeridas (${_filteredActions.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppColors.brandPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Meta Diária: 1/3',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.brandDarkAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children:
                      _filteredActions.isEmpty
                          ? [
                            const SizedBox(height: 40),
                            Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSecondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.search_off,
                                    color: AppColors.brandPrimary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma ação encontrada',
                                  style: AppTextStyles.headlineSm.copyWith(
                                    color: AppColors.brandTextPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tente outros termos ou sugira uma prática comunitária inédita para a sua vizinhança.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.brandTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ]
                          : _filteredActions.map((action) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildActionCard(action),
                            );
                          }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
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
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_circle,
                          color: AppColors.brandPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sentiu falta de algum hábito?',
                              style: AppTextStyles.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandTextPrimary,
                              ),
                            ),
                            Text(
                              'Sugira uma prática para toda a cidade',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.brandTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showSuggestionDialog(context),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Sugerir'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandPrimary,
                          backgroundColor: AppColors.brandSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.brandSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ordenar ações',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.brandTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.brandTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _sortOption(
                sheetContext,
                'relevance',
                'Relevância',
                'Ordem original da lista',
              ),
              _sortOption(
                sheetContext,
                'points',
                'Mais pontos',
                'Maior impacto por ação primeiro',
              ),
              _sortOption(
                sheetContext,
                'alphabetical',
                'Ordem alfabética',
                'De A a Z',
              ),
              if (_selectedCategory != 'all' || _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'all';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: const Text('Limpar filtros de busca'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandTextSecondary,
                        side: const BorderSide(color: AppColors.brandBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sortOption(
    BuildContext sheetContext,
    String value,
    String title,
    String subtitle,
  ) {
    final selected = _sortMode == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: AppColors.brandPrimary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMd.copyWith(
          color: AppColors.brandTextPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      ),
      onTap: () {
        setState(() => _sortMode = value);
        Navigator.of(sheetContext).pop();
      },
    );
  }

  Future<void> _showSuggestionDialog(BuildContext context) async {
    final controller = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.brandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sugerir uma prática',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.brandTextPrimary,
            ),
            decoration: const InputDecoration(
              hintText:
                  'Ex.: Separar o óleo de cozinha usado para reciclagem...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      controller.dispose();
      return;
    }

    if (submitted == true && controller.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sugestão enviada para a equipe. Obrigado!'),
        ),
      );
    }
    controller.dispose();
  }

  Widget _buildCategoryChip(String value, String label, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = value;
          });
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : AppColors.brandSurface,
            borderRadius: BorderRadius.circular(999),
            boxShadow:
                isSelected
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.brandPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMd.copyWith(
                  color:
                      isSelected ? Colors.white : AppColors.brandTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    action['icon'],
                    color: AppColors.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandSecondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              action['categoryLabel'],
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.brandDarkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                action['infoIcon'],
                                size: 12,
                                color: AppColors.brandTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  action['info'],
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.brandTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action['title'],
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action['description'],
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    action['points'],
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.brandDarkAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  action['footerIcon'],
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    action['footerInfo'],
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.brandTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/registro-acao', extra: action);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Registrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandSecondaryContainer,
                    foregroundColor: AppColors.brandDarkAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
