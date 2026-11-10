import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// De onde vem a foto de comprovação.
enum PhotoSource { camera, gallery }

/// Escolhe uma foto com a câmera ou a galeria do aparelho.
///
/// As telas falam só com esta interface; os testes usam uma versão falsa e
/// nunca chegam ao plugin.
abstract class PhotoPicker {
  /// Caminho da foto escolhida, ou `null` se a pessoa desistiu.
  Future<String?> pick(PhotoSource source);

  /// No Android, o sistema pode fechar o app enquanto a câmera está aberta.
  /// Ao voltar, devolve a foto que ficou pendente (ou `null`).
  Future<String?> recoverLost();
}

/// Implementação com o plugin `image_picker`.
///
/// A câmera abre pelo aplicativo de câmera do próprio aparelho, então o
/// EcoViva não precisa pedir a permissão de câmera.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Reduz a foto já na origem: basta para comprovar e ocupa pouco espaço.
  static const double maxWidth = 1280;
  static const int imageQuality = 80;

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source:
          source == PhotoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    return file?.path;
  }

  @override
  Future<String?> recoverLost() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      final files = response.files;
      if (files != null && files.isNotEmpty) return files.first.path;
      return response.file?.path;
    } catch (_) {
      return null;
    }
  }
}
