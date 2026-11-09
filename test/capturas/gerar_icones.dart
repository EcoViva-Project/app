// Gera o ícone do app para Android a partir de web/icons/Icon-512.png.
//
// Não faz parte da suíte. Para rodar:
//   flutter test test/capturas/gerar_icones.dart
// Regrava android/app/src/main/res/mipmap-*/ic_launcher.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const Map<String, int> _sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

void main() {
  testWidgets('gera os ícones do Android', (tester) async {
    final source = File('web/icons/Icon-512.png').readAsBytesSync();
    await tester.runAsync(() async {
      for (final entry in _sizes.entries) {
        final codec = await ui.instantiateImageCodec(
          source,
          targetWidth: entry.value,
          targetHeight: entry.value,
        );
        final frame = await codec.getNextFrame();
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        File('android/app/src/main/res/${entry.key}/ic_launcher.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
    expect(
      File(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ).lengthSync(),
      greaterThan(1500),
    );
  });
}
