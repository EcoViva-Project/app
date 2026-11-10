import 'dart:io';

import 'package:eco_app/core/services/photo_file_store.dart';
import 'package:eco_app/core/services/photo_picker.dart';
import 'package:eco_app/core/services/photo_proof.dart';

/// Câmera e galeria de mentira: devolve [next] (ou `null`, como se a pessoa
/// tivesse desistido) sem chegar ao plugin.
class FakePhotoPicker implements PhotoPicker {
  String? next = 'C:/fotos-de-teste/tirada.jpg';
  String? lost;
  final List<PhotoSource> calls = [];

  @override
  Future<String?> pick(PhotoSource source) async {
    calls.add(source);
    return next;
  }

  @override
  Future<String?> recoverLost() async {
    final value = lost;
    lost = null;
    return value;
  }
}

/// Pasta de fotos de mentira. [find] devolve `null` (arquivo sumido), o que
/// também testa o aviso "Foto indisponível".
class FakePhotoFileStore implements PhotoFileStore {
  final List<String> saved = [];
  final List<String> deleted = [];
  int deleteAllCalls = 0;

  @override
  Future<String> save(String sourcePath) async {
    final name = 'foto_teste_${saved.length + 1}.jpg';
    saved.add(name);
    return name;
  }

  @override
  Future<File?> find(String fileName) async => null;

  @override
  Future<void> delete(String fileName) async => deleted.add(fileName);

  @override
  Future<void> deleteAll() async => deleteAllCalls++;
}

/// Volta às peças de verdade (chamar no `tearDown`).
void restorePhotoProof() {
  PhotoProof.picker = ImagePickerPhotoPicker();
  PhotoProof.files = DocumentsPhotoFileStore();
  PhotoProof.availableOverride = null;
}
