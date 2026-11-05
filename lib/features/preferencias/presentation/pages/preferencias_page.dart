import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PreferenciasPage extends StatefulWidget {
  const PreferenciasPage({super.key});

  @override
  State<PreferenciasPage> createState() => _PreferenciasPageState();
}

class _PreferenciasPageState extends State<PreferenciasPage> {
  bool _pushNotifications = true;
  bool _dailyReminders = true;
  bool _weeklySummary = false;
  bool _shareProgress = true;
  bool _appearInRanking = true;
  int _weeklyGoal = 5;
  String _neighborhood = 'Jardim das Flores';

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    final prefs = auth.preferences;
    _pushNotifications = prefs['notificationsEnabled'] as bool? ?? true;
    _dailyReminders = prefs['remindersEnabled'] as bool? ?? true;
    _shareProgress = prefs['privacyProfile'] as bool? ?? true;
    _appearInRanking = prefs['privacyLocation'] as bool? ?? true;
    _weeklyGoal = (auth.user?['weeklyGoal'] as num?)?.toInt() ?? 5;
    _neighborhood = auth.neighborhood;
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      await AuthService.instance.updatePreferences({key: value});
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _saveWeeklyGoal(int goal) async {
    try {
      await AuthService.instance.updateProfile(weeklyGoal: goal);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _saveNeighborhood(String neighborhood) async {
    try {
      await AuthService.instance.updateProfile(neighborhood: neighborhood);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  static const List<int> _goalOptions = [3, 5, 7, 10];
  static const List<String> _neighborhoods = [
    'Jardim das Flores',
    'Vila Verde',
    'Parque das Águas',
    'Centro',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        backgroundColor: AppColors.brandBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, color: AppColors.brandTextPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/perfil');
            }
          },
        ),
        title: Text(
          'Preferências',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.brandTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajuste sua experiência',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.brandTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha como quer ser lembrada e o que compartilhar com a comunidade.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.brandTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Notificações',
                subtitle: 'Lembretes para manter seus hábitos em dia.',
                children: [
                  _switchTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificações push',
                    subtitle: 'Novidades, conquistas e desafios do bairro.',
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() => _pushNotifications = value);
                      _savePreference('notificationsEnabled', value);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.brandBorder),
                  _switchTile(
                    icon: Icons.alarm,
                    title: 'Lembretes diários',
                    subtitle:
                        'Um lembrete gentil às 08:00 para registrar ações.',
                    value: _dailyReminders,
                    onChanged: (value) {
                      setState(() => _dailyReminders = value);
                      _savePreference('remindersEnabled', value);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.brandBorder),
                  _switchTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Resumo semanal',
                    subtitle:
                        'Seu impacto e o da comunidade toda segunda-feira.',
                    value: _weeklySummary,
                    onChanged:
                        (value) => setState(() => _weeklySummary = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Metas pessoais',
                subtitle:
                    'Quantas ações sustentáveis você quer registrar por semana?',
                children: [
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _goalOptions)
                        ChoiceChip(
                          label: Text('$option ações'),
                          selected: _weeklyGoal == option,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _weeklyGoal = option);
                            _saveWeeklyGoal(option);
                          },
                          backgroundColor: AppColors.brandBackground,
                          selectedColor: AppColors.brandSecondaryContainer,
                          side: BorderSide(
                            color:
                                _weeklyGoal == option
                                    ? AppColors.brandSecondaryContainer
                                    : AppColors.brandBorder,
                          ),
                          labelStyle: AppTextStyles.labelMd.copyWith(
                            color:
                                _weeklyGoal == option
                                    ? AppColors.brandDarkAccent
                                    : AppColors.brandTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Meta atual: $_weeklyGoal ações por semana',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Comunidade',
                subtitle: 'Defina seu bairro e como participar do feed.',
                children: [
                  _neighborhoodTile(),
                  const Divider(height: 1, color: AppColors.brandBorder),
                  _switchTile(
                    icon: Icons.visibility_outlined,
                    title: 'Compartilhar progresso',
                    subtitle: 'Suas ações podem aparecer no feed dos vizinhos.',
                    value: _shareProgress,
                    onChanged: (value) {
                      setState(() => _shareProgress = value);
                      _savePreference('privacyProfile', value);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.brandBorder),
                  _switchTile(
                    icon: Icons.leaderboard_outlined,
                    title: 'Aparecer no ranking',
                    subtitle: 'Mostrar seu nome no ranking semanal do bairro.',
                    value: _appearInRanking,
                    onChanged: (value) {
                      setState(() => _appearInRanking = value);
                      _savePreference('privacyLocation', value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandSecondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Notificações, privacidade, meta semanal e bairro são salvos na sua conta.',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.brandTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
          Text(
            title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.brandTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        secondary: Icon(icon, size: 20, color: AppColors.brandPrimary),
        title: Text(
          title,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _neighborhoodTile() {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        leading: const Icon(
          Icons.location_on_outlined,
          size: 20,
          color: AppColors.brandPrimary,
        ),
        title: Text(
          'Meu bairro',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.brandTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _neighborhood,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.brandTextSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.brandTextSecondary,
        ),
        onTap: _selectNeighborhood,
      ),
    );
  }

  void _selectNeighborhood() {
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Escolha seu bairro',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.brandTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final neighborhood in _neighborhoods)
                ListTile(
                  leading: Icon(
                    neighborhood == _neighborhood
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.brandPrimary,
                  ),
                  title: Text(
                    neighborhood,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.brandTextPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _neighborhood = neighborhood);
                    _saveNeighborhood(neighborhood);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
