import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// A picture made ready for the silkscreen: its ink, and how wide to print
/// it.
class PreparedPicture {
  const PreparedPicture({
    required this.name,
    required this.columns,
    required this.rows,
    required this.bits,
    required this.width,
  });

  final String name;
  final int columns;
  final int rows;
  final Uint8List bits;

  /// Printed width in millimetres.
  final double width;
}

/// The pictures that come with the app.
enum BuiltInPicture {
  logo('Zolt logo', 20),
  mark('Zolt mark', 8);

  const BuiltInPicture(this.label, this.width);

  final String label;

  /// A sensible printed width, in millimetres.
  final double width;
}

/// The longest side a picture is read at. A silkscreen prints nothing much
/// finer than a tenth of a millimetre, so this is already more detail than
/// a board-sized picture can show.
const _maxSide = 300;

/// A built-in picture, drawn from the logo's own geometry.
Future<PreparedPicture> builtInPicture(BuiltInPicture which) async {
  const k = 2.0; // pixels per unit of the logo's drawing
  const pad = 9.5;
  const drill = 3.6;
  const stroke = 12.0;
  final wordmark = which == BuiltInPicture.logo;
  // The logo is drawn in a 310 × 82 box starting 4 units down; the mark is
  // its first letter.
  final box = wordmark
      ? const Rect.fromLTWH(0, 4, 310, 82)
      : const Rect.fromLTWH(0, 4, 86, 82);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(k)
    ..translate(-box.left, -box.top);
  final ink = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = const Color(0xFF000000);
  final pads = <Offset>[];

  Path path(String d) {
    // The handful of commands the logo uses: M, H, V, L, Q, Z.
    final p = Path();
    final tokens = RegExp(r'[MHVLQZ]|-?[\d.]+').allMatches(d).map((m) => m[0]!);
    var x = 0.0, y = 0.0;
    final it = tokens.iterator;
    double next() {
      it.moveNext();
      return double.parse(it.current);
    }

    while (it.moveNext()) {
      switch (it.current) {
        case 'M':
          x = next();
          y = next();
          p.moveTo(x, y);
        case 'H':
          x = next();
          p.lineTo(x, y);
        case 'V':
          y = next();
          p.lineTo(x, y);
        case 'L':
          x = next();
          y = next();
          p.lineTo(x, y);
        case 'Q':
          final cx = next(), cy = next();
          x = next();
          y = next();
          p.quadraticBezierTo(cx, cy, x, y);
        case 'Z':
          p.close();
      }
    }
    return p;
  }

  canvas.drawPath(path('M10 14 H58 Q76 14 63 27 L25 63 Q12 76 30 76 H76'), ink);
  pads.addAll(const [Offset(10, 14), Offset(76, 76)]);
  if (wordmark) {
    canvas
      ..drawCircle(const Offset(122, 45), 30, ink)
      ..drawPath(path('M172 14 V60 Q172 76 188 76 H214'), ink)
      ..drawPath(path('M232 14 H300'), ink)
      ..drawPath(path('M266 14 V76'), ink)
      ..drawPath(path('M248 14 Q266 14 266 32 Q266 14 284 14 Z'), fill);
    pads.addAll(const [
      Offset(122, 15),
      Offset(172, 14),
      Offset(214, 76),
      Offset(232, 14),
      Offset(300, 14),
      Offset(266, 76),
    ]);
  }
  for (final at in pads) {
    canvas.drawCircle(at, pad, fill);
  }
  // The drill holes, cut through everything drawn under them.
  final cut = Paint()..blendMode = BlendMode.clear;
  for (final at in pads) {
    canvas.drawCircle(at, drill, cut);
  }

  final width = (box.width * k).round();
  final height = (box.height * k).round();
  final image = await recorder.endRecording().toImage(width, height);
  final rgba = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  return PreparedPicture(
    name: which.label,
    columns: width,
    rows: height,
    bits: BoardImage.pack([
      for (var i = 0; i < width * height; i++) rgba[i * 4 + 3] >= 128,
    ]),
    width: which.width,
  );
}

/// Reads a picture from the phone and shows it as it will print, with the
/// cut between ink and bare board adjustable, before it goes on the board.
Future<PreparedPicture?> preparePicture(
  BuildContext context,
  Uint8List bytes,
  String name,
) async {
  final ui.ImageDescriptor descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
  } on Object {
    throw const FormatException('That picture could not be read');
  }
  final scale = math.min(
    1.0,
    _maxSide / math.max(descriptor.width, descriptor.height),
  );
  final width = math.max(1, (descriptor.width * scale).round());
  final height = math.max(1, (descriptor.height * scale).round());
  final codec = await descriptor.instantiateCodec(
    targetWidth: width,
    targetHeight: height,
  );
  final frame = await codec.getNextFrame();
  final rgba = (await frame.image.toByteData())!.buffer.asUint8List();
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  if (!context.mounted) return null;

  return showDialog<PreparedPicture>(
    context: context,
    builder: (context) =>
        _PictureDialog(name: name, columns: width, rows: height, rgba: rgba),
  );
}

class _PictureDialog extends StatefulWidget {
  const _PictureDialog({
    required this.name,
    required this.columns,
    required this.rows,
    required this.rgba,
  });

  final String name;
  final int columns;
  final int rows;
  final Uint8List rgba;

  @override
  State<_PictureDialog> createState() => _PictureDialogState();
}

class _PictureDialogState extends State<_PictureDialog> {
  late final Uint8List _luminance;
  late final Uint8List _opaque;
  late double _threshold;
  bool _invert = false;
  final _width = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    final count = widget.columns * widget.rows;
    _luminance = Uint8List(count);
    _opaque = Uint8List(count);
    final histogram = List<int>.filled(256, 0);
    for (var i = 0; i < count; i++) {
      final r = widget.rgba[i * 4];
      final g = widget.rgba[i * 4 + 1];
      final b = widget.rgba[i * 4 + 2];
      final a = widget.rgba[i * 4 + 3];
      final l = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      _luminance[i] = l;
      _opaque[i] = a >= 128 ? 1 : 0;
      if (a >= 128) histogram[l]++;
    }
    _threshold = _otsu(histogram).toDouble();
  }

  @override
  void dispose() {
    _width.dispose();
    super.dispose();
  }

  /// The level that best splits the picture's pixels into two groups, the
  /// usual way of choosing a black-and-white cut automatically.
  static int _otsu(List<int> histogram) {
    final total = histogram.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 128;
    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }
    var sumB = 0.0, weightB = 0, best = 0.0, level = 128;
    for (var i = 0; i < 256; i++) {
      weightB += histogram[i];
      if (weightB == 0) continue;
      final weightF = total - weightB;
      if (weightF == 0) break;
      sumB += i * histogram[i];
      final meanB = sumB / weightB;
      final meanF = (sum - sumB) / weightF;
      final between = weightB * weightF * (meanB - meanF) * (meanB - meanF);
      if (between > best) {
        best = between;
        level = i;
      }
    }
    // A picture of one flat colour has nothing to split: all of it is ink.
    return best == 0 ? 255 : level + 1;
  }

  /// Ink: an opaque pixel darker than the cut, or lighter with [_invert].
  /// Transparency never prints.
  List<bool> get _ink => [
    for (var i = 0; i < _luminance.length; i++)
      _opaque[i] == 1 && ((_luminance[i] < _threshold) != _invert),
  ];

  double? get _widthValue =>
      double.tryParse(_width.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final ink = _ink;
    final width = _widthValue;
    final valid = width != null && width >= 1 && width <= 300;
    return AlertDialog(
      title: const Text('Picture for the silkscreen'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // As it will print: white ink on the green of a board.
              Container(
                width: 260,
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: _MaskPainter(ink, widget.columns, widget.rows),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ink level',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Slider(
                      key: const ValueKey('picture-threshold'),
                      value: _threshold.clamp(1, 255),
                      min: 1,
                      max: 255,
                      onChanged: (v) => setState(() => _threshold = v),
                    ),
                    SwitchListTile(
                      key: const ValueKey('picture-invert'),
                      value: _invert,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Invert'),
                      subtitle: const Text('Print the light parts instead'),
                      onChanged: (v) => setState(() => _invert = v),
                    ),
                    TextField(
                      key: const ValueKey('picture-width'),
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Printed width mm',
                        isDense: true,
                        helperText: valid
                            ? '${(width * widget.rows / widget.columns).toStringAsFixed(1)} mm tall'
                            : 'Between 1 and 300 mm',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          key: const ValueKey('picture-place'),
          onPressed: !valid || !ink.contains(true)
              ? null
              : () => Navigator.of(context).pop(
                  PreparedPicture(
                    name: widget.name,
                    columns: widget.columns,
                    rows: widget.rows,
                    bits: BoardImage.pack(ink),
                    width: width,
                  ),
                ),
          child: const Text('PLACE'),
        ),
      ],
    );
  }
}

/// Ink drawn white, fitted to the box, a row's run at a time.
class _MaskPainter extends CustomPainter {
  _MaskPainter(this.ink, this.columns, this.rows, {this.framed = true});

  final List<bool> ink;
  final int columns;
  final int rows;

  /// Whether to outline the picture's extent.
  final bool framed;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / columns, size.height / rows);
    final origin = Offset(
      (size.width - columns * scale) / 2,
      (size.height - rows * scale) / 2,
    );
    final paint = Paint()..color = const Color(0xFFF4F4F0);
    for (var y = 0; y < rows; y++) {
      var x = 0;
      while (x < columns) {
        if (!ink[y * columns + x]) {
          x++;
          continue;
        }
        final start = x;
        while (x < columns && ink[y * columns + x]) {
          x++;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + start * scale,
            origin.dy + y * scale,
            (x - start) * scale,
            scale,
          ),
          paint,
        );
      }
    }
    if (!framed) return;
    canvas.drawRect(
      origin & Size(columns * scale, rows * scale),
      Paint()
        ..color = KicadPalette.border
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => !identical(old.ink, ink);
}

/// Changes how a placed picture prints: its width, its turn and its side.
Future<BoardImage?> showPicturePropertiesDialog(
  BuildContext context,
  BoardImage image,
) => showDialog<BoardImage>(
  context: context,
  builder: (context) => _PicturePropertiesDialog(image: image),
);

class _PicturePropertiesDialog extends StatefulWidget {
  const _PicturePropertiesDialog({required this.image});

  final BoardImage image;

  @override
  State<_PicturePropertiesDialog> createState() =>
      _PicturePropertiesDialogState();
}

class _PicturePropertiesDialogState extends State<_PicturePropertiesDialog> {
  late final _width = TextEditingController(
    text: widget.image.width.toStringAsFixed(1),
  );
  late double _rotation = widget.image.rotation;
  late bool _back = widget.image.back;

  @override
  void dispose() {
    _width.dispose();
    super.dispose();
  }

  double? get _widthValue =>
      double.tryParse(_width.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final width = _widthValue;
    final valid = width != null && width >= 1 && width <= 300;
    final image = widget.image;
    return AlertDialog(
      title: Text(image.name),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    key: const ValueKey('picture-edit-width'),
                    controller: _width,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Width mm',
                      isDense: true,
                      helperText: valid
                          ? '${(width * image.rows / image.columns).toStringAsFixed(1)} mm tall'
                          : 'Between 1 and 300 mm',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Front')),
                      ButtonSegment(value: true, label: Text('Back')),
                    ],
                    selected: {_back},
                    onSelectionChanged: (value) =>
                        setState(() => _back = value.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final angle in const [0, 90, 180, 270])
                  ChoiceChip(
                    label: Text('$angle°'),
                    selected: _rotation == angle,
                    onSelected: (_) =>
                        setState(() => _rotation = angle.toDouble()),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.of(context).pop(
                  image.copyWith(
                    width: width,
                    rotation: _rotation,
                    back: _back,
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

/// A picture's ink, white on board green, fitted to the space it is given.
class PictureThumbnail extends StatelessWidget {
  const PictureThumbnail({
    super.key,
    required this.columns,
    required this.rows,
    required this.bits,
  });

  final int columns;
  final int rows;
  final Uint8List bits;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF1B5E30),
      borderRadius: BorderRadius.circular(4),
    ),
    child: CustomPaint(
      painter: _MaskPainter(
        _unpacked[bits] ??= [
          for (var i = 0; i < columns * rows; i++)
            (bits[i >> 3] >> (7 - (i & 7))) & 1 == 1,
        ],
        columns,
        rows,
        framed: false,
      ),
    ),
  );

  static final _unpacked = Expando<List<bool>>();
}
