// Gera as imagens do mapa-base (quadros de 512 px) que o app mostra no mapa
// da comunidade, sem internet.
//
// Não faz parte da suíte (o nome não termina em `_test.dart`). Para rodar:
//   flutter test test/capturas/gerar_mapa_tiles.dart
//
// Entrada: tool/dados/mapa_base_rio_preto.json (DADOS do OpenStreetMap, ODbL,
// baixados por tool/gerar_mapa_base.js).
// Saída:   assets/map/tiles/<zoom>_<x>_<y>.png
//
// Por que imagens: desenhar milhares de linhas a cada quadro deixava o mapa
// travado no celular. Com os quadros prontos, arrastar e ampliar só move
// imagens. O desenho é do próprio projeto (estilo e código daqui); não são as
// imagens de tile.openstreetmap.org, cujo uso sem internet a política da OSMF
// não permite. O crédito "© colaboradores do OpenStreetMap" segue na tela.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const String _source = 'tool/dados/mapa_base_rio_preto.json';
const String _outDir = 'assets/map/tiles';

/// Níveis de zoom gerados. Acima do último, o app amplia a imagem.
const int _minZoom = 11;
const int _maxZoom = 16;

/// Lado do quadro no mapa (pontos lógicos) e na imagem (pixels): 2x.
const double _tileLogical = 256;
const int _tilePixels = 512;

// Cores (as mesmas do mapa vetorial que estas imagens substituem).
const ui.Color _land = ui.Color(0xFFEFEADF);
const ui.Color _lakeFill = ui.Color(0xFFBFDCEE);
const ui.Color _lakeBorder = ui.Color(0xFF8FBEDC);
const ui.Color _river = ui.Color(0xFF7FB2D6);
const ui.Color _motorway = ui.Color(0xFF857560);
const ui.Color _primary = ui.Color(0xFFA0907A);
const ui.Color _secondary = ui.Color(0xFFBBAE99);
const ui.Color _tertiary = ui.Color(0xFFD2C8B7);

/// Ordem de desenho das vias: as mais importantes por cima.
const List<String> _roadOrder = [
  'tertiary',
  'secondary',
  'primary',
  'trunk',
  'motorway',
];

/// Espessura (pontos lógicos, no zoom exato) de cada classe em cada nível.
/// Zero esconde a classe naquele nível.
const Map<String, List<double>> _roadWidths = {
  //            z11  z12  z13  z14  z15  z16
  'motorway': [2.6, 3.2, 4.4, 5.2, 6.4, 8.0],
  'trunk': [2.6, 3.2, 4.4, 5.2, 6.4, 8.0],
  'primary': [1.8, 2.2, 3.2, 3.9, 5.0, 6.4],
  'secondary': [1.1, 1.4, 2.2, 2.8, 3.8, 5.0],
  'tertiary': [0, 0, 1.3, 1.7, 2.5, 3.6],
};
const Map<String, List<double>> _waterWidths = {
  'river': [1.8, 2.2, 2.6, 3.0, 3.6, 4.4],
  'stream': [0.8, 1.0, 1.4, 1.6, 2.0, 2.4],
};

ui.Color _roadColor(String kind) => switch (kind) {
  'motorway' || 'trunk' => _motorway,
  'primary' => _primary,
  'secondary' => _secondary,
  _ => _tertiary,
};

/// Linha ou polígono em coordenadas de Mercator normalizadas (0 a 1).
class _Feature {
  _Feature(this.kind, List<dynamic> flat)
    : xs = Float64List(flat.length ~/ 2),
      ys = Float64List(flat.length ~/ 2) {
    for (var i = 0; i < xs.length; i++) {
      final lat = (flat[2 * i] as num).toDouble();
      final lon = (flat[2 * i + 1] as num).toDouble();
      xs[i] = (lon + 180) / 360;
      final phi = lat * math.pi / 180;
      ys[i] = (1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) / 2;
    }
    minX = xs.reduce(math.min);
    maxX = xs.reduce(math.max);
    minY = ys.reduce(math.min);
    maxY = ys.reduce(math.max);
  }

  final String kind;
  final Float64List xs;
  final Float64List ys;
  late final double minX;
  late final double maxX;
  late final double minY;
  late final double maxY;

  /// Toca o retângulo (em coordenadas normalizadas)?
  bool touches(double left, double top, double right, double bottom) =>
      maxX >= left && minX <= right && maxY >= top && minY <= bottom;

  /// Acrescenta o traçado a [path], em pontos lógicos do quadro.
  void addTo(
    ui.Path path,
    double world,
    double originX,
    double originY, {
    bool close = false,
  }) {
    path.moveTo(xs[0] * world - originX, ys[0] * world - originY);
    for (var i = 1; i < xs.length; i++) {
      path.lineTo(xs[i] * world - originX, ys[i] * world - originY);
    }
    if (close) path.close();
  }
}

double _normX(double lon) => (lon + 180) / 360;
double _normY(double lat) {
  final phi = lat * math.pi / 180;
  return (1 - math.log(math.tan(phi) + 1 / math.cos(phi)) / math.pi) / 2;
}

// --- PNG indexado (paleta), bem menor que o PNG de 32 bits do motor ---------

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  final length = ByteData(4)..setUint32(0, data.length);
  final body = [...ascii.encode(type), ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(body) & 0xFFFFFFFF);
  out
    ..add(length.buffer.asUint8List())
    ..add(body)
    ..add(crc.buffer.asUint8List());
}

/// Bits descartados de cada cor antes de montar a paleta. Com 2, tons quase
/// iguais do contorno suavizado viram um só e o arquivo encolhe; as cores
/// cheias não mudam, porque cada entrada da paleta é a média das cores reais.
const int _minShift = 2;

/// Converte RGBA em PNG de paleta. `blank` diz se a imagem tem uma cor só.
({Uint8List png, bool blank}) _encodeIndexedPng(
  Uint8List rgba,
  int width,
  int height,
) {
  final pixels = width * height;
  final indices = Uint8List(pixels);
  late Map<int, int> palette;
  late List<List<int>> sums; // por cor: [r, g, b, quantidade]

  // Junta cores parecidas (descartando bits) até caber em 256.
  for (var shift = _minShift; ; shift++) {
    palette = <int, int>{};
    sums = [];
    var fits = true;
    for (var i = 0; i < pixels; i++) {
      final r = rgba[4 * i];
      final g = rgba[4 * i + 1];
      final b = rgba[4 * i + 2];
      final key = ((r >> shift) << 16) | ((g >> shift) << 8) | (b >> shift);
      var index = palette[key];
      if (index == null) {
        if (palette.length == 256) {
          fits = false;
          break;
        }
        index = palette.length;
        palette[key] = index;
        sums.add([0, 0, 0, 0]);
      }
      final sum = sums[index];
      sum[0] += r;
      sum[1] += g;
      sum[2] += b;
      sum[3]++;
      indices[i] = index;
    }
    if (fits) break;
  }
  final plte = <int>[];
  for (final sum in sums) {
    plte
      ..add((sum[0] / sum[3]).round())
      ..add((sum[1] / sum[3]).round())
      ..add((sum[2] / sum[3]).round());
  }

  final raw = Uint8List(height * (width + 1));
  for (var y = 0; y < height; y++) {
    raw[y * (width + 1)] = 0; // filtro "nenhum"
    raw.setRange(
      y * (width + 1) + 1,
      (y + 1) * (width + 1),
      indices,
      y * width,
    );
  }

  final header =
      ByteData(13)
        ..setUint32(0, width)
        ..setUint32(4, height)
        ..setUint8(8, 8) // bits por pixel
        ..setUint8(9, 3) // cor indexada
        ..setUint8(10, 0)
        ..setUint8(11, 0)
        ..setUint8(12, 0);
  final out =
      BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(out, 'IHDR', header.buffer.asUint8List());
  _chunk(out, 'PLTE', plte);
  _chunk(out, 'IDAT', ZLibCodec(level: 9).encode(raw));
  _chunk(out, 'IEND', const []);
  return (png: out.toBytes(), blank: palette.length == 1);
}

// ---------------------------------------------------------------------------

void main() {
  test('gera os quadros do mapa-base', () async {
    final json =
        jsonDecode(File(_source).readAsStringSync()) as Map<String, dynamic>;
    final bbox = json['bbox'] as Map<String, dynamic>;
    final west = _normX((bbox['west'] as num).toDouble());
    final east = _normX((bbox['east'] as num).toDouble());
    final north = _normY((bbox['north'] as num).toDouble());
    final south = _normY((bbox['south'] as num).toDouble());

    List<_Feature> read(String key, {int minPoints = 2}) => [
      for (final item in (json[key] as List? ?? const []))
        if (((item as Map<String, dynamic>)['p'] as List).length >=
            minPoints * 2)
          _Feature(item['c'] as String? ?? '', item['p'] as List),
    ];
    final roads = read('roads');
    final water = read('water');
    final lakes = read('lakes', minPoints: 3);

    final dir = Directory(_outDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final fill = ui.Paint()..isAntiAlias = true;
    final stroke =
        ui.Paint()
          ..isAntiAlias = true
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round;
    const scale = _tilePixels / _tileLogical;

    var totalFiles = 0;
    var totalBytes = 0;
    for (var z = _minZoom; z <= _maxZoom; z++) {
      final level = z - _minZoom;
      final tiles = math.pow(2, z).toDouble();
      final world = tiles * _tileLogical;
      final x0 = (west * tiles).floor();
      final x1 = (east * tiles).floor();
      final y0 = (north * tiles).floor();
      final y1 = (south * tiles).floor();
      // Folga para traços e bordas que começam no quadro vizinho.
      final margin = 12 / world;

      var files = 0;
      var bytes = 0;
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          final left = x / tiles - margin;
          final right = (x + 1) / tiles + margin;
          final top = y / tiles - margin;
          final bottom = (y + 1) / tiles + margin;
          final originX = x * _tileLogical;
          final originY = y * _tileLogical;

          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(
            recorder,
            ui.Rect.fromLTWH(
              0,
              0,
              _tilePixels.toDouble(),
              _tilePixels.toDouble(),
            ),
          );
          canvas.drawColor(_land, ui.BlendMode.src);
          canvas.scale(scale);
          var drew = false;

          // Lagos e represas.
          final lakePath = ui.Path();
          for (final lake in lakes) {
            if (!lake.touches(left, top, right, bottom)) continue;
            lake.addTo(lakePath, world, originX, originY, close: true);
            drew = true;
          }
          canvas.drawPath(lakePath, fill..color = _lakeFill);
          canvas.drawPath(
            lakePath,
            stroke
              ..color = _lakeBorder
              ..strokeWidth = 1,
          );

          // Rios e córregos.
          for (final kind in const ['stream', 'river']) {
            final width = _waterWidths[kind]![level];
            final path = ui.Path();
            for (final line in water) {
              final lineKind = line.kind == 'river' ? 'river' : 'stream';
              if (lineKind != kind) continue;
              if (!line.touches(left, top, right, bottom)) continue;
              line.addTo(path, world, originX, originY);
              drew = true;
            }
            canvas.drawPath(
              path,
              stroke
                ..color = _river
                ..strokeWidth = width,
            );
          }

          // Vias, das menos para as mais importantes.
          for (final kind in _roadOrder) {
            final width = _roadWidths[kind]![level];
            if (width <= 0) continue;
            final path = ui.Path();
            for (final road in roads) {
              if (road.kind != kind) continue;
              if (!road.touches(left, top, right, bottom)) continue;
              road.addTo(path, world, originX, originY);
              drew = true;
            }
            canvas.drawPath(
              path,
              stroke
                ..color = _roadColor(kind)
                ..strokeWidth = width,
            );
          }

          final picture = recorder.endRecording();
          if (!drew) {
            picture.dispose();
            continue;
          }
          final image = await picture.toImage(_tilePixels, _tilePixels);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          picture.dispose();
          final encoded = _encodeIndexedPng(
            data!.buffer.asUint8List(),
            _tilePixels,
            _tilePixels,
          );
          // Só a cor de fundo: o app usa o quadro vazio no lugar.
          if (encoded.blank) continue;
          File('$_outDir/${z}_${x}_$y.png').writeAsBytesSync(encoded.png);
          files++;
          bytes += encoded.png.length;
        }
      }
      final possible = (x1 - x0 + 1) * (y1 - y0 + 1);
      // ignore: avoid_print
      print(
        'zoom $z: $files de $possible quadros, '
        '${(bytes / 1024).toStringAsFixed(0)} KB',
      );
      totalFiles += files;
      totalBytes += bytes;
    }
    // Quadro vazio, de uma cor só, para onde não há nada desenhado.
    const blankSide = 16;
    final blankPixels = Uint8List(blankSide * blankSide * 4);
    for (var i = 0; i < blankSide * blankSide; i++) {
      blankPixels[4 * i] = (_land.r * 255).round();
      blankPixels[4 * i + 1] = (_land.g * 255).round();
      blankPixels[4 * i + 2] = (_land.b * 255).round();
      blankPixels[4 * i + 3] = 255;
    }
    File('$_outDir/vazio.png').writeAsBytesSync(
      _encodeIndexedPng(blankPixels, blankSide, blankSide).png,
    );

    // ignore: avoid_print
    print(
      'total: $totalFiles quadros, '
      '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB em $_outDir',
    );
    expect(totalFiles, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
