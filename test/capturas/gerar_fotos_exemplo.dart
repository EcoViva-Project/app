// Desenha as três fotos de exemplo da demonstração (ilustrações simples,
// feitas aqui mesmo; nada baixado da internet).
//
// Não faz parte da suíte. Para rodar:
//   flutter test test/capturas/gerar_fotos_exemplo.dart
// Regrava assets/fotos_exemplo/*.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 800;
const double _height = 600;

const Color _sky = Color(0xFFDDF1E4);
const Color _ground = Color(0xFFB7D9A8);
const Color _dark = Color(0xFF1F3A2B);
const Color _white = Color(0xFFFFFFFF);

Future<void> _loadFont() async {
  ByteData read(String path) =>
      ByteData.view(File(path).readAsBytesSync().buffer);
  final loader = FontLoader('PlusJakartaSans');
  for (final weight in ['Regular', 'Bold']) {
    loader.addFont(
      Future.value(
        read('assets/fonts/PlusJakartaSans/static/PlusJakartaSans-$weight.ttf'),
      ),
    );
  }
  await loader.load();
}

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) =>
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  double size = 28,
  Color color = _white,
  bool bold = true,
  double width = _width,
  ui.TextAlign align = ui.TextAlign.left,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            textAlign: align,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(text);
  final paragraph =
      builder.build()..layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(paragraph, at);
}

/// Fundo, chão e a faixa "Foto de exemplo" com a legenda.
void _scene(Canvas canvas, String caption, void Function() draw) {
  canvas.drawRect(const Rect.fromLTWH(0, 0, _width, _height), _fill(_sky));
  canvas.drawCircle(const Offset(680, 110), 52, _fill(const Color(0xFFFFD45C)));
  canvas.drawRect(const Rect.fromLTWH(0, 400, _width, 200), _fill(_ground));
  draw();
  canvas.drawRect(
    const Rect.fromLTWH(0, 500, _width, 100),
    _fill(_dark.withValues(alpha: 0.88)),
  );
  _text(canvas, 'Foto de exemplo', const Offset(32, 512), size: 34);
  _text(
    canvas,
    caption,
    const Offset(32, 556),
    size: 22,
    bold: false,
    color: const Color(0xFFCDE8D6),
  );
}

void _drawBins(Canvas canvas) {
  const bins = [
    ('PAPEL', Color(0xFF2F6FD6)),
    ('PLÁSTICO', Color(0xFFD9443A)),
    ('METAL', Color(0xFFE8B21E)),
    ('ORGÂNICO', Color(0xFF8A5A2B)),
  ];
  const binWidth = 150.0;
  const gap = 30.0;
  const left = (_width - (binWidth * 4 + gap * 3)) / 2;
  for (var i = 0; i < bins.length; i++) {
    final (label, color) = bins[i];
    final x = left + i * (binWidth + gap);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 8, 230, binWidth - 16, 210),
      const Radius.circular(14),
    );
    canvas.drawRRect(body, _fill(color));
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, 205, binWidth, 34),
      const Radius.circular(10),
    );
    canvas.drawRRect(lid, _fill(Color.lerp(color, _dark, 0.25)!));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + binWidth / 2 - 22, 192, 44, 16),
        const Radius.circular(6),
      ),
      _fill(Color.lerp(color, _dark, 0.35)!),
    );
    // Setas da reciclagem, simplificadas em um anel.
    final center = Offset(x + binWidth / 2, 310);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 30),
      -math.pi / 2,
      math.pi * 1.6,
      false,
      _stroke(_white, 9),
    );
    canvas.drawCircle(center + const Offset(-18, -24), 7, _fill(_white));
    _text(
      canvas,
      label,
      Offset(x, 372),
      size: 20,
      width: binWidth,
      align: ui.TextAlign.center,
    );
  }
}

void _drawCompost(Canvas canvas) {
  const wood = Color(0xFFA9773F);
  const woodDark = Color(0xFF7D5426);
  // Caixa de madeira com ripas.
  for (var i = 0; i < 4; i++) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(210, 260 + i * 44.0, 380, 36),
        const Radius.circular(6),
      ),
      _fill(i.isEven ? wood : const Color(0xFFB98549)),
    );
  }
  canvas.drawRect(const Rect.fromLTWH(200, 240, 22, 210), _fill(woodDark));
  canvas.drawRect(const Rect.fromLTWH(578, 240, 22, 210), _fill(woodDark));
  // Terra por cima.
  final soil =
      Path()
        ..moveTo(222, 262)
        ..quadraticBezierTo(300, 205, 400, 228)
        ..quadraticBezierTo(500, 200, 578, 262)
        ..close();
  canvas.drawPath(soil, _fill(const Color(0xFF5B3A1E)));
  // Cascas e restos de comida.
  canvas.drawOval(
    const Rect.fromLTWH(300, 222, 46, 22),
    _fill(const Color(0xFFF2A93B)),
  );
  canvas.drawOval(
    const Rect.fromLTWH(430, 214, 40, 20),
    _fill(const Color(0xFFE35D3A)),
  );
  canvas.drawOval(
    const Rect.fromLTWH(372, 232, 30, 16),
    _fill(const Color(0xFFF7E07A)),
  );
  // Brotos.
  void sprout(double x, double baseY, double height) {
    canvas.drawLine(
      Offset(x, baseY),
      Offset(x, baseY - height),
      _stroke(const Color(0xFF2E8B57), 6),
    );
    final leaf = _fill(const Color(0xFF3FA66B));
    canvas.save();
    canvas.translate(x, baseY - height);
    canvas.rotate(-0.6);
    canvas.drawOval(const Rect.fromLTWH(-34, -12, 34, 20), leaf);
    canvas.restore();
    canvas.save();
    canvas.translate(x, baseY - height);
    canvas.rotate(0.6);
    canvas.drawOval(const Rect.fromLTWH(0, -12, 34, 20), leaf);
    canvas.restore();
  }

  sprout(270, 246, 60);
  sprout(400, 228, 90);
  sprout(520, 238, 55);
  _text(
    canvas,
    'COMPOSTEIRA',
    const Offset(210, 400),
    size: 24,
    width: 380,
    align: ui.TextAlign.center,
  );
}

void _drawBicycle(Canvas canvas) {
  // Estrada.
  canvas.drawRect(
    const Rect.fromLTWH(0, 430, _width, 70),
    _fill(const Color(0xFF8C9A92)),
  );
  for (var x = 20.0; x < _width; x += 120) {
    canvas.drawRect(Rect.fromLTWH(x, 462, 60, 8), _fill(_white));
  }
  // Árvores ao fundo.
  for (final x in [90.0, 700.0]) {
    canvas.drawRect(
      Rect.fromLTWH(x - 10, 300, 20, 110),
      _fill(const Color(0xFF7D5426)),
    );
    canvas.drawCircle(Offset(x, 280), 62, _fill(const Color(0xFF3FA66B)));
  }

  const frame = Color(0xFF1E8A6E);
  const rear = Offset(270, 360);
  const front = Offset(530, 360);
  const pedal = Offset(390, 360);
  const seatTop = Offset(350, 245);
  const handle = Offset(495, 235);
  for (final wheel in [rear, front]) {
    canvas.drawCircle(wheel, 78, _stroke(_dark, 12));
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        wheel,
        wheel + Offset(math.cos(angle) * 70, math.sin(angle) * 70),
        _stroke(const Color(0xFF6B7B72), 2.5),
      );
    }
    canvas.drawCircle(wheel, 8, _fill(_dark));
  }
  final frameStroke = _stroke(frame, 12);
  canvas.drawLine(rear, pedal, frameStroke);
  canvas.drawLine(rear, seatTop + const Offset(0, 20), frameStroke);
  canvas.drawLine(seatTop + const Offset(0, 20), pedal, frameStroke);
  canvas.drawLine(
    seatTop + const Offset(0, 20),
    handle + const Offset(0, 25),
    frameStroke,
  );
  canvas.drawLine(pedal, handle + const Offset(0, 25), frameStroke);
  canvas.drawLine(handle + const Offset(0, 25), front, frameStroke);
  canvas.drawLine(handle + const Offset(0, 25), handle, _stroke(_dark, 10));
  canvas.drawLine(handle, handle + const Offset(34, -6), _stroke(_dark, 10));
  // Selim e pedal.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: seatTop, width: 66, height: 18),
      const Radius.circular(9),
    ),
    _fill(_dark),
  );
  canvas.drawLine(seatTop, seatTop + const Offset(0, 20), _stroke(_dark, 8));
  canvas.drawCircle(pedal, 16, _fill(_dark));
  canvas.drawLine(
    pedal + const Offset(-14, 22),
    pedal + const Offset(14, -22),
    _stroke(_dark, 6),
  );
}

Future<void> _render(
  WidgetTester tester,
  String name,
  String caption,
  void Function(Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _scene(canvas, caption, () => draw(canvas));
  final picture = recorder.endRecording();
  await tester.runAsync(() async {
    final image = await picture.toImage(_width.toInt(), _height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/fotos_exemplo/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('gera as fotos de exemplo', (tester) async {
    await tester.runAsync(_loadFont);
    await _render(
      tester,
      'separacao',
      'Resíduos separados por tipo',
      _drawBins,
    );
    await _render(
      tester,
      'composteira',
      'Composteira com restos de comida',
      _drawCompost,
    );
    await _render(
      tester,
      'bicicleta',
      'Ida ao trabalho de bicicleta',
      _drawBicycle,
    );

    for (final name in ['separacao', 'composteira', 'bicicleta']) {
      final size = File('assets/fotos_exemplo/$name.png').lengthSync();
      expect(size, greaterThan(5000), reason: name);
      expect(size, lessThan(80 * 1024), reason: name);
    }
  });
}
