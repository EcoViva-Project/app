import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/local/places.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Texto de ajuda padrão do campo "Bairro".
const String kNeighborhoodHelper =
    'Digite 2 letras ou mais para ver sugestões.';

/// Aviso quando o bairro digitado não está na lista.
const String kUnknownNeighborhoodHint =
    'Não achamos esse bairro na lista de Rio Preto. Escolha uma sugestão para '
    'aparecer no mapa.';

/// Ajuda do campo "Bairro" para o texto digitado: o aviso de bairro fora da
/// lista, o nome reconhecido quando a pessoa abreviou ("Jd Nazareth") ou
/// `null` (texto curto ou nome exato). Não impede de salvar.
String? neighborhoodHint(String text) {
  final value = text.trim();
  if (value.length < 2) return null;
  final found = Places.findNeighborhood(value);
  if (found == null) return kUnknownNeighborhoodHint;
  if (Places.normalize(found.name) == Places.normalize(value)) return null;
  return 'Vamos usar o bairro ${found.name} no mapa.';
}

/// Controladores dos campos de endereço. Quem cria chama [dispose].
class AddressControllers {
  AddressControllers({
    String cep = '',
    String street = '',
    String number = '',
    String complement = '',
    String neighborhood = '',
    String city = defaultCity,
    String state = defaultState,
  }) : cep = TextEditingController(text: CepInputFormatter.format(cep)),
       street = TextEditingController(text: street),
       number = TextEditingController(text: number),
       complement = TextEditingController(text: complement),
       neighborhood = TextEditingController(text: neighborhood),
       city = TextEditingController(text: city),
       state = TextEditingController(text: state.toUpperCase());

  static const String defaultCity = 'São José do Rio Preto';
  static const String defaultState = 'SP';

  final TextEditingController cep;
  final TextEditingController street;
  final TextEditingController number;
  final TextEditingController complement;
  final TextEditingController neighborhood;
  final TextEditingController city;
  final TextEditingController state;

  /// CEP só com os dígitos (vazio se não foi informado).
  String get cepDigits => cep.text.replaceAll(RegExp(r'[^0-9]'), '');

  String get stateCode => state.text.trim().toUpperCase();

  void dispose() {
    for (final controller in [
      cep,
      street,
      number,
      complement,
      neighborhood,
      city,
      state,
    ]) {
      controller.dispose();
    }
  }
}

/// Bloco "Endereço": CEP, rua, número, complemento, bairro (com sugestões de
/// bairros conhecidos), cidade e UF. Deve ficar dentro de um [Form].
///
/// A única chamada de rede é a sugestão de bairros; sem conexão a lista
/// simplesmente não aparece e o bairro pode ser digitado à mão.
class AddressFields extends StatefulWidget {
  const AddressFields({
    super.key,
    required this.controllers,
    this.enabled = true,
    this.onSubmitted,
  });

  final AddressControllers controllers;
  final bool enabled;

  /// Chamado quando a pessoa aperta Enter no último campo (UF).
  final VoidCallback? onSubmitted;

  @override
  State<AddressFields> createState() => _AddressFieldsState();
}

class _AddressFieldsState extends State<AddressFields> {
  static const Duration _searchDelay = Duration(milliseconds: 300);

  Timer? _debounce;
  int _searchId = 0;
  List<String> _suggestions = const [];

  /// Aviso sobre o bairro digitado (ver [neighborhoodHint]).
  String? _hint;

  AddressControllers get _c => widget.controllers;

  @override
  void initState() {
    super.initState();
    _hint = neighborhoodHint(_c.neighborhood.text);
  }

  @override
  void didUpdateWidget(covariant AddressFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _suggestions.isNotEmpty) {
      _debounce?.cancel();
      _searchId++;
      _suggestions = const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onNeighborhoodChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      _searchId++;
      if (_suggestions.isNotEmpty || _hint != null) {
        setState(() {
          _suggestions = const [];
          _hint = null;
        });
      }
      return;
    }
    _debounce = Timer(_searchDelay, () {
      if (mounted) setState(() => _hint = neighborhoodHint(query));
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final id = ++_searchId;
    List<String> found;
    try {
      found = await AuthService.instance.searchNeighborhoods(query);
    } catch (_) {
      found = const [];
    }
    if (!mounted || id != _searchId) return;
    final lower = query.toLowerCase();
    final exact = found.any((name) => name.toLowerCase() == lower);
    setState(() => _suggestions = exact ? const [] : found.take(5).toList());
  }

  void _pick(String name) {
    _debounce?.cancel();
    _searchId++;
    _c.neighborhood.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() {
      _suggestions = const [];
      _hint = neighborhoodHint(name);
    });
  }

  static String? _maxLength(String? value, int max, String label) {
    if ((value ?? '').trim().length > max) {
      return '$label deve ter no máximo $max caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final enabled = widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Endereço',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.brandTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _PrivacyNotice(),
        gap,
        TextFormField(
          key: const ValueKey('endereco-cep'),
          controller: _c.cep,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.postalCode],
          inputFormatters: [CepInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'CEP (opcional)',
            hintText: '00000-000',
            prefixIcon: Icon(Icons.markunread_mailbox_outlined),
            errorMaxLines: 2,
          ),
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
          key: const ValueKey('endereco-rua'),
          controller: _c.street,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.streetAddressLine1],
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: const InputDecoration(
            labelText: 'Rua (opcional)',
            prefixIcon: Icon(Icons.signpost_outlined),
            errorMaxLines: 2,
          ),
          validator: (value) => _maxLength(value, 120, 'A rua'),
        ),
        gap,
        TextFormField(
          key: const ValueKey('endereco-numero'),
          controller: _c.number,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(12)],
          decoration: const InputDecoration(
            labelText: 'Número (opcional)',
            prefixIcon: Icon(Icons.pin_outlined),
            errorMaxLines: 2,
          ),
          validator: (value) => _maxLength(value, 12, 'O número'),
        ),
        gap,
        TextFormField(
          key: const ValueKey('endereco-complemento'),
          controller: _c.complement,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.streetAddressLine2],
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          decoration: const InputDecoration(
            labelText: 'Complemento (opcional)',
            prefixIcon: Icon(Icons.apartment_outlined),
            errorMaxLines: 2,
          ),
          validator: (value) => _maxLength(value, 60, 'O complemento'),
        ),
        gap,
        TextFormField(
          key: const ValueKey('endereco-bairro'),
          controller: _c.neighborhood,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.sublocality],
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: InputDecoration(
            labelText: 'Bairro',
            helperText: _hint ?? kNeighborhoodHelper,
            helperStyle:
                _hint == kUnknownNeighborhoodHint
                    ? AppTextStyles.bodySm.copyWith(
                      color: AppColors.tertiary,
                      fontWeight: FontWeight.w600,
                    )
                    : null,
            helperMaxLines: 3,
            errorMaxLines: 2,
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          onChanged: _onNeighborhoodChanged,
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return 'Informe o bairro.';
            return _maxLength(text, 80, 'O bairro');
          },
        ),
        if (_suggestions.isNotEmpty && enabled)
          _SuggestionList(suggestions: _suggestions, onPick: _pick),
        gap,
        TextFormField(
          key: const ValueKey('endereco-cidade'),
          controller: _c.city,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.addressCity],
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: const InputDecoration(
            labelText: 'Cidade',
            prefixIcon: Icon(Icons.location_city_outlined),
            errorMaxLines: 2,
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return 'Informe a cidade.';
            return _maxLength(text, 80, 'A cidade');
          },
        ),
        gap,
        TextFormField(
          key: const ValueKey('endereco-uf'),
          controller: _c.state,
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction:
              widget.onSubmitted == null
                  ? TextInputAction.next
                  : TextInputAction.done,
          autofillHints: const [AutofillHints.addressState],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
            LengthLimitingTextInputFormatter(2),
            _UpperCaseFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'UF',
            prefixIcon: Icon(Icons.map_outlined),
            errorMaxLines: 2,
          ),
          validator: (value) {
            if (!RegExp(r'^[A-Za-z]{2}$').hasMatch((value ?? '').trim())) {
              return 'Informe a UF com 2 letras.';
            }
            return null;
          },
          onFieldSubmitted:
              widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.brandDarkAccent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Seu endereço não é mostrado a ninguém. No mapa da comunidade '
              'você aparece só na região do bairro, e dá para desligar isso '
              'em Preferências.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.brandTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: AppColors.brandSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.brandBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          liveRegion: true,
          label:
              suggestions.length == 1
                  ? '1 sugestão de bairro'
                  : '${suggestions.length} sugestões de bairro',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final name in suggestions)
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () => onPick(name),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.brandDarkAccent,
                              ),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aceita só dígitos e mostra o CEP como 00000-000.
class CepInputFormatter extends TextInputFormatter {
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
