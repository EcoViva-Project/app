import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/widgets/address_fields.dart'
    show kNeighborhoodHelper, kUnknownNeighborhoodHint, neighborhoodHint;

/// Abre o diálogo de edição. Devolve `true` se os dados foram salvos.
Future<bool> showEditProfileDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const EditProfileDialog(),
  );
  return saved == true;
}

/// Nome e endereço da pessoa, com sugestão de bairros.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  static const String defaultCity = 'São José do Rio Preto';
  static const String defaultState = 'SP';

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cep;
  late final TextEditingController _street;
  late final TextEditingController _number;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _city;
  late final TextEditingController _state;

  bool _saving = false;
  String? _error;
  List<String> _suggestions = const [];
  int _searchId = 0;

  /// Aviso sobre o bairro digitado (ver [neighborhoodHint]).
  String? _hint;

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    String field(String key) => (auth.address[key] as String? ?? '').trim();

    _name = TextEditingController(text: auth.userName);
    _cep = TextEditingController(text: _CepFormatter.format(field('cep')));
    _street = TextEditingController(text: field('street'));
    _number = TextEditingController(text: field('number'));
    _complement = TextEditingController(text: field('complement'));
    _neighborhood = TextEditingController(text: auth.neighborhood);
    _hint = neighborhoodHint(auth.neighborhood);
    final city = auth.city.isNotEmpty ? auth.city : field('city');
    _city = TextEditingController(
      text: city.isEmpty ? EditProfileDialog.defaultCity : city,
    );
    final state = field('state');
    _state = TextEditingController(
      text: state.isEmpty ? EditProfileDialog.defaultState : state,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _cep,
      _street,
      _number,
      _complement,
      _neighborhood,
      _city,
      _state,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _searchNeighborhoods(String text) async {
    final query = text.trim();
    final id = ++_searchId;
    final hint = neighborhoodHint(query);
    if (hint != _hint) setState(() => _hint = hint);
    if (query.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    List<String> found;
    try {
      found = await AuthService.instance.searchNeighborhoods(query);
    } catch (_) {
      found = const [];
    }
    if (!mounted || id != _searchId) return;
    final exact = found.any(
      (name) => name.toLowerCase() == query.toLowerCase(),
    );
    setState(() => _suggestions = exact ? const [] : found.take(5).toList());
  }

  void _pickNeighborhood(String name) {
    _searchId++;
    _neighborhood.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() {
      _suggestions = const [];
      _hint = neighborhoodHint(name);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _suggestions = const [];
    });
    try {
      await AuthService.instance.updateProfile(
        name: _name.text.trim(),
        neighborhood: _neighborhood.text.trim(),
        cep: _cep.text.replaceAll(RegExp(r'[^0-9]'), ''),
        street: _street.text,
        number: _number.text,
        complement: _complement.text,
        city: _city.text,
        state: _state.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            error is ApiException
                ? error.message
                : 'Não foi possível salvar. Confira a conexão e tente de novo.';
      });
    }
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? helper,
    TextStyle? helperStyle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: helperStyle,
      helperMaxLines: 3,
      errorMaxLines: 2,
      border: const OutlineInputBorder(),
    );
  }

  String? _maxLength(String? value, int max, String label) {
    if ((value ?? '').trim().length > max) {
      return '$label deve ter no máximo $max caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.brandSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Editar dados',
        style: AppTextStyles.headlineSm.copyWith(
          color: AppColors.brandTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('perfil-nome'),
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Nome'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.length < 2 || text.length > 80) {
                  return 'Informe um nome com 2 a 80 caracteres.';
                }
                return null;
              },
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-cep'),
              controller: _cep,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [_CepFormatter()],
              decoration: _decoration('CEP (opcional)', hint: '00000-000'),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isNotEmpty && digits.length != 8) {
                  return 'Informe um CEP com 8 dígitos.';
                }
                return null;
              },
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-rua'),
              controller: _street,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Rua'),
              validator: (value) => _maxLength(value, 120, 'A rua'),
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-numero'),
              controller: _number,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Número'),
              validator: (value) => _maxLength(value, 12, 'O número'),
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-complemento'),
              controller: _complement,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Complemento'),
              validator: (value) => _maxLength(value, 60, 'O complemento'),
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-bairro'),
              controller: _neighborhood,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                'Bairro',
                helper: _hint ?? kNeighborhoodHelper,
                helperStyle:
                    _hint == kUnknownNeighborhoodHint
                        ? AppTextStyles.bodySm.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w600,
                        )
                        : null,
              ),
              onChanged: _searchNeighborhoods,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Informe o bairro.';
                return _maxLength(text, 80, 'O bairro');
              },
            ),
            if (_suggestions.isNotEmpty) _suggestionList(),
            gap,
            TextFormField(
              key: const ValueKey('perfil-cidade'),
              controller: _city,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Cidade'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Informe a cidade.';
                return _maxLength(text, 80, 'A cidade');
              },
            ),
            gap,
            TextFormField(
              key: const ValueKey('perfil-uf'),
              controller: _state,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                LengthLimitingTextInputFormatter(2),
                _UpperCaseFormatter(),
              ],
              decoration: _decoration('UF'),
              validator: (value) {
                if (!RegExp(r'^[A-Za-z]{2}$').hasMatch((value ?? '').trim())) {
                  return 'Informe a UF com 2 letras.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandSecondaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.brandDarkAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Seu endereço não é mostrado a ninguém. No mapa da '
                      'comunidade você aparece só na região do bairro.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.brandTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _suggestionList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in _suggestions)
            InkWell(
              onTap: () => _pickNeighborhood(name),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.brandDarkAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.brandTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aceita só dígitos e mostra o CEP como 00000-000.
class _CepFormatter extends TextInputFormatter {
  static String format(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    if (limited.length <= 5) return limited;
    return '${limited.substring(0, 5)}-${limited.substring(5)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
