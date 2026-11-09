import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/state_views.dart';

/// Preferências salvas na conta: notificações, privacidade e meta semanal.
class PreferenciasPage extends StatefulWidget {
  const PreferenciasPage({super.key});

  @override
  State<PreferenciasPage> createState() => _PreferenciasPageState();
}

class _PreferenciasPageState extends State<PreferenciasPage> {
  static const String _weeklyGoalKey = 'weeklyGoal';
  static const List<int> _goalOptions = [3, 5, 7, 10, 14];

  final AuthService _auth = AuthService.instance;

  /// Valores mostrados enquanto a API confirma a mudança.
  final Map<String, Object> _pending = {};

  /// Chaves sendo salvas agora (o controle fica bloqueado).
  final Set<String> _saving = {};

  bool _flag(String key) =>
      _pending[key] as bool? ?? _auth.preferences[key] as bool? ?? true;

  int get _weeklyGoal => _pending[_weeklyGoalKey] as int? ?? _auth.weeklyGoal;

  /// O único caminho de gravação. Mostra o valor novo na hora e volta ao
  /// valor salvo se a API recusar.
  Future<void> _save(String key, Object value) async {
    if (_saving.contains(key)) return;
    setState(() {
      _saving.add(key);
      _pending[key] = value;
    });
    try {
      if (key == _weeklyGoalKey) {
        await _auth.updateProfile(weeklyGoal: value as int);
      } else {
        await _auth.updatePreferences({key: value});
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error,
          fallback: 'Não foi possível salvar. Tente de novo.',
        );
      }
    } finally {
      if (mounted) {
        // Sem o valor pendente, a tela volta a mostrar o que está na conta:
        // o novo, se salvou; o anterior, se falhou.
        setState(() {
          _saving.remove(key);
          _pending.remove(key);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: const AppPageHeader(
        pageIcon: Icons.tune,
        title: 'Preferências',
        showBack: true,
        backFallback: '/perfil',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _auth,
          builder:
              (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _section(
                    title: 'Notificações',
                    children: [
                      _switch(
                        key: 'notificationsEnabled',
                        icon: Icons.notifications_active_outlined,
                        title: 'Notificações no aplicativo',
                        subtitle:
                            'Avisos de conquistas, desafios, comunidade e '
                            'recompensas.',
                      ),
                      _divider,
                      _comingSoonSwitch(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Privacidade',
                    children: [
                      _switch(
                        key: 'privacyProfile',
                        icon: Icons.visibility_outlined,
                        title: 'Perfil visível para a comunidade',
                        subtitle:
                            'Seu nome e suas publicações aparecem para os '
                            'vizinhos.',
                      ),
                      _divider,
                      _switch(
                        key: 'privacyLocation',
                        icon: Icons.map_outlined,
                        title: 'Aparecer no mapa da comunidade',
                        subtitle: 'Só a região do bairro, nunca o endereço',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Meta semanal',
                    subtitle: 'Aparece na tela inicial, em Sua semana.',
                    children: [const SizedBox(height: 4), _goalChips()],
                  ),
                  const SizedBox(height: 16),
                  _section(title: 'Endereço', children: [_addressInfo()]),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        size: 18,
                        color: AppColors.brandTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'As alterações são salvas na sua conta.',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.brandTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }

  static const Widget _divider = Divider(
    height: 1,
    color: AppColors.brandBorder,
  );

  Widget _section({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandBorder),
      ),
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
              subtitle,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final saving = _saving.contains(key);
    return SwitchListTile(
      key: ValueKey('preferencia-$key'),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.brandDarkAccent),
      title: Text(
        title,
        style: AppTextStyles.bodyMd.copyWith(
          color: AppColors.brandTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        saving ? 'Salvando…' : subtitle,
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      ),
      value: _flag(key),
      onChanged: saving ? null : (value) => _save(key, value),
    );
  }

  Widget _comingSoonSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.alarm, color: AppColors.brandTextSecondary),
      title: Text(
        'Lembretes diários',
        style: AppTextStyles.bodyMd.copyWith(
          color: AppColors.brandTextSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Em breve',
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.brandTextSecondary,
        ),
      ),
      value: false,
      onChanged: null,
    );
  }

  Widget _goalChips() {
    final current = _weeklyGoal;
    final saving = _saving.contains(_weeklyGoalKey);
    final options = {..._goalOptions, current}.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              key: ValueKey('meta-$option'),
              label: Text('$option ${option == 1 ? 'ação' : 'ações'}'),
              selected: option == current,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected:
                  saving
                      ? null
                      : (_) {
                        if (option != current) _save(_weeklyGoalKey, option);
                      },
              backgroundColor: AppColors.brandBackground,
              selectedColor: AppColors.brandSecondaryContainer,
              disabledColor:
                  option == current
                      ? AppColors.brandSecondaryContainer
                      : AppColors.brandBackground,
              side: BorderSide(
                color:
                    option == current
                        ? AppColors.brandDarkAccent
                        : AppColors.brandBorder,
              ),
              labelStyle: AppTextStyles.labelMd.copyWith(
                color:
                    option == current
                        ? AppColors.brandDarkAccent
                        : AppColors.brandTextSecondary,
                fontWeight:
                    option == current ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _addressInfo() {
    final line = _auth.addressLine;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.brandDarkAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.isEmpty ? 'Não informado' : line,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.brandTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para mudar o endereço, use Editar dados no Perfil.',
                  style: AppTextStyles.bodySm.copyWith(
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
