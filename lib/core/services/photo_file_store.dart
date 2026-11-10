import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda as fotos de comprovação em uma pasta do aplicativo.
///
/// O banco grava só o nome do arquivo; a pasta é descoberta na hora, porque o
/// caminho completo pode mudar entre versões do sistema.
abstract class PhotoFileStore {
  /// Copia a foto de [sourcePath] para a pasta do app e devolve o nome do
  /// arquivo novo.
  Future<String> save(String sourcePath);

  /// O arquivo de [fileName], ou `null` se ele não existe mais.
  Future<File?> find(String fileName);

  /// Apaga uma foto (por exemplo, quando o registro não chegou a ser feito).
  Future<void> delete(String fileName);

  /// Apaga todas as fotos (usado ao restaurar a demonstração).
  Future<void> deleteAll();
}

/// Fotos em `<documentos do app>/fotos/`.
class DocumentsPhotoFileStore implements PhotoFileStore {
  DocumentsPhotoFileStore({
    Future<Directory> Function()? baseDirectory,
    Random? random,
  }) : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory,
       _random = random ?? Random.secure();

  static const String folderName = 'fotos';

  /// Só nomes simples, sem pastas: o banco nunca aponta para fora da pasta.
  static final RegExp validName = RegExp(r'^[A-Za-z0-9_-]{1,64}\.(jpg|png)$');

  final Future<Directory> Function() _baseDirectory;
  final Random _random;

  Future<Directory> _folder() async {
    final base = await _baseDirectory();
    return Directory(p.join(base.path, folderName));
  }

  String _newName(String sourcePath) {
    final extension =
        p.extension(sourcePath).toLowerCase() == '.png' ? 'png' : 'jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'foto_${stamp}_$suffix.$extension';
  }

  @override
  Future<String> save(String sourcePath) async {
    final folder = await _folder();
    await folder.create(recursive: true);
    final name = _newName(sourcePath);
    await File(sourcePath).copy(p.join(folder.path, name));
    return name;
  }

  @override
  Future<File?> find(String fileName) async {
    if (!validName.hasMatch(fileName)) return null;
    try {
      final file = File(p.join((await _folder()).path, fileName));
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String fileName) async {
    if (!validName.hasMatch(fileName)) return;
    try {
      final file = File(p.join((await _folder()).path, fileName));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Se não deu para apagar, a foto só ocupa espaço; nada quebra.
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final folder = await _folder();
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (_) {
      // Mesmo caso: falhar aqui não pode impedir a restauração dos dados.
    }
  }
}
