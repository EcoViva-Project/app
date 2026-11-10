import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'photo_file_store.dart';
import 'photo_picker.dart';

/// Foto de comprovação ligada a um registro.
///
/// Vem da API como `{ "file": "<nome>" }` (foto tirada neste aparelho) ou
/// `{ "asset": "<caminho>" }` (foto de exemplo da demonstração).
class RecordPhoto {
  const RecordPhoto({this.file, this.asset});

  final String? file;
  final String? asset;

  bool get isAsset => asset != null;

  static RecordPhoto? fromApi(Object? json) {
    if (json is! Map) return null;
    final file = json['file'];
    final asset = json['asset'];
    if (asset is String && asset.isNotEmpty) return RecordPhoto(asset: asset);
    if (file is String && file.isNotEmpty) return RecordPhoto(file: file);
    return null;
  }
}

/// Peças da foto de comprovação, trocáveis nos testes.
///
/// A foto é só um selo: não muda pontos, limites nem desafios. Por enquanto
/// ela fica apenas no aparelho, por isso só aparece no modo local e fora do
/// navegador. Enviar a foto a um servidor fica para depois.
class PhotoProof {
  PhotoProof._();

  static PhotoPicker picker = ImagePickerPhotoPicker();
  static PhotoFileStore files = DocumentsPhotoFileStore();

  /// Nos testes, força mostrar ou esconder os botões de foto.
  @visibleForTesting
  static bool? availableOverride;

  /// Os botões de foto aparecem na tela de registro.
  static bool get available =>
      availableOverride ?? (!kIsWeb && ApiClient.isLocalMode);
}
