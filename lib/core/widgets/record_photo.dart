import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/photo_proof.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Foto de comprovação de um registro: foto de exemplo (asset) ou arquivo
/// guardado no aparelho. Se o arquivo sumiu, mostra um aviso no lugar, sem
/// quebrar a tela.
class RecordPhotoImage extends StatefulWidget {
  const RecordPhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.compact = false,
    this.dark = false,
  });

  final RecordPhoto photo;
  final BoxFit fit;

  /// Largura para decodificar a imagem (miniaturas leves na lista).
  final int? cacheWidth;

  /// Aviso de foto indisponível só com o ícone (miniaturas pequenas).
  final bool compact;

  /// Aviso em fundo escuro (visualização em tela cheia).
  final bool dark;

  @override
  State<RecordPhotoImage> createState() => _RecordPhotoImageState();
}

class _RecordPhotoImageState extends State<RecordPhotoImage> {
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant RecordPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.file != widget.photo.file) _resolve();
  }

  void _resolve() {
    final name = widget.photo.file;
    _file = name == null || kIsWeb ? null : PhotoProof.files.find(name);
  }

  Widget _unavailable(BuildContext context) =>
      PhotoUnavailable(compact: widget.compact, dark: widget.dark);

  @override
  Widget build(BuildContext context) {
    final asset = widget.photo.asset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        errorBuilder: (context, _, _) => _unavailable(context),
      );
    }
    final future = _file;
    if (future == null) return _unavailable(context);
    return FutureBuilder<File?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: AppColors.brandSecondaryContainer);
        }
        final file = snapshot.data;
        if (file == null) return _unavailable(context);
        return Image.file(
          file,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          errorBuilder: (context, _, _) => _unavailable(context),
        );
      },
    );
  }
}

/// Foto recém-escolhida, ainda no caminho entregue pela câmera ou galeria.
class PickedPhotoPreview extends StatelessWidget {
  const PickedPhotoPreview({super.key, required this.path, this.cacheWidth});

  final String path;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const PhotoUnavailable();
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (context, _, _) => const PhotoUnavailable(),
    );
  }
}

/// No lugar de uma foto que não pôde ser aberta.
class PhotoUnavailable extends StatelessWidget {
  const PhotoUnavailable({super.key, this.compact = false, this.dark = false});

  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white70 : AppColors.brandTextSecondary;
    return ColoredBox(
      color: dark ? Colors.black : AppColors.brandBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Em miniaturas, só o ícone: o texto não caberia.
          final small =
              compact ||
              constraints.maxWidth < 140 ||
              constraints.maxHeight < 100;
          final icon = Icon(
            Icons.image_not_supported_outlined,
            color: color,
            size: small ? 18 : 32,
          );
          return Center(
            child:
                small
                    ? Semantics(label: 'Foto indisponível', child: icon)
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(height: 6),
                        Text(
                          'Foto indisponível',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd.copyWith(color: color),
                        ),
                      ],
                    ),
          );
        },
      ),
    );
  }
}

/// Selo "Com comprovação". Com [onTap], abre a foto.
class ProofBadge extends StatelessWidget {
  const ProofBadge({super.key, this.photo, this.onTap});

  /// Quando informada, aparece uma miniatura dentro do selo.
  final RecordPhoto? photo;
  final VoidCallback? onTap;

  static const String label = 'Com comprovação';

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    final content = Container(
      padding: EdgeInsets.fromLTRB(photo == null ? 8 : 3, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppColors.brandSecondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (photo != null)
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: RecordPhotoImage(
                    photo: photo,
                    cacheWidth: 78,
                    compact: true,
                  ),
                ),
              ),
            )
          else
            const Icon(
              Icons.photo_camera_outlined,
              size: 14,
              color: AppColors.brandDarkAccent,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.brandDarkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      hint: 'Abre a foto',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

/// Abre a foto em tela cheia, com zoom de pinça.
Future<void> showRecordPhoto(
  BuildContext context,
  RecordPhoto photo, {
  String? title,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => RecordPhotoViewer(photo: photo, title: title),
    ),
  );
}

class RecordPhotoViewer extends StatelessWidget {
  const RecordPhotoViewer({super.key, required this.photo, this.title});

  final RecordPhoto photo;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Fechar foto',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title ?? 'Foto de comprovação',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelLg.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: RecordPhotoImage(
                    photo: photo,
                    fit: BoxFit.contain,
                    dark: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                photo.isAsset
                    ? 'Foto de exemplo da demonstração.'
                    : 'Esta foto fica só neste celular. Use dois dedos para aproximar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
