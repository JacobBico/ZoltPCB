import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'board_layer.dart';

/// A picture printed in the silkscreen: a logo, a mascot, a QR code.
///
/// Stored as ink and no ink, one bit a pixel, because that is all a
/// silkscreen can print. It is fabricated as the rectangles the ink makes,
/// the same rectangles drawn on the screen.
class BoardImage {
  BoardImage({
    required this.id,
    required this.projectId,
    required this.name,
    required this.position,
    required this.width,
    required this.columns,
    required this.rows,
    required this.bits,
    this.rotation = 0,
    this.back = false,
  });

  final String id;
  final String projectId;

  /// What the picture was made from, to tell one from another.
  final String name;

  /// Centre of the picture, in board millimetres.
  final Offset position;

  /// Printed width in millimetres; the height follows from the pixels.
  final double width;

  /// Degrees counter-clockwise.
  final double rotation;

  /// On the underside, where it is printed mirrored so it reads right way
  /// round from below.
  final bool back;

  /// Pixels across and down.
  final int columns;
  final int rows;

  /// One bit a pixel, row by row from the top, most significant bit first.
  final Uint8List bits;

  double get height => width * rows / columns;

  BoardLayer get layer => back ? BoardLayer.backSilk : BoardLayer.frontSilk;

  /// Whether pixel ([x], [y]) is inked.
  bool ink(int x, int y) {
    final i = y * columns + x;
    return (bits[i >> 3] >> (7 - (i & 7))) & 1 == 1;
  }

  /// The ink as rectangles, in pixels: each row's runs, and a run that
  /// carries on unchanged down the next rows merged into one taller block.
  late final List<Rect> inkRects = _rects();

  List<Rect> _rects() {
    final rects = <Rect>[];
    // A run open since some row, by where it starts and ends.
    final open = <(int, int), int>{};
    for (var y = 0; y <= rows; y++) {
      final runs = <(int, int)>{};
      if (y < rows) {
        var x = 0;
        while (x < columns) {
          if (!ink(x, y)) {
            x++;
            continue;
          }
          final start = x;
          while (x < columns && ink(x, y)) {
            x++;
          }
          runs.add((start, x));
        }
      }
      for (final key in open.keys.toList()) {
        if (runs.contains(key)) continue;
        final top = open.remove(key)!;
        rects.add(
          Rect.fromLTRB(
            key.$1.toDouble(),
            top.toDouble(),
            key.$2.toDouble(),
            y.toDouble(),
          ),
        );
      }
      for (final run in runs) {
        open.putIfAbsent(run, () => y);
      }
    }
    return rects;
  }

  /// The ink as polygons in board millimetres, placed, turned, and mirrored
  /// on the back.
  late final List<List<Offset>> inkPolygons = [
    for (final r in inkRects)
      [
        toBoard(r.left, r.top),
        toBoard(r.right, r.top),
        toBoard(r.right, r.bottom),
        toBoard(r.left, r.bottom),
      ],
  ];

  /// A point given in pixels, on the board.
  Offset toBoard(double px, double py) {
    final scale = width / columns;
    var x = (px - columns / 2) * scale;
    // Pixels count down the picture; the board frame turns with y up.
    final y = -(py - rows / 2) * scale;
    if (back) x = -x;
    final radians = rotation * math.pi / 180;
    final rx = x * math.cos(radians) - y * math.sin(radians);
    final ry = x * math.sin(radians) + y * math.cos(radians);
    return position + Offset(rx, -ry);
  }

  /// The corners of the whole picture on the board, for picking it up.
  List<Offset> get frame => [
    toBoard(0, 0),
    toBoard(columns.toDouble(), 0),
    toBoard(columns.toDouble(), rows.toDouble()),
    toBoard(0, rows.toDouble()),
  ];

  /// Whether [point] is on the picture.
  bool contains(Offset point) {
    final corners = frame;
    var inside = false;
    for (var i = 0, j = corners.length - 1; i < corners.length; j = i++) {
      final a = corners[i];
      final b = corners[j];
      if ((a.dy > point.dy) == (b.dy > point.dy)) continue;
      final x = (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (point.dx < x) inside = !inside;
    }
    return inside;
  }

  String get encodedBits => base64Encode(bits);

  static Uint8List decodeBits(String encoded) => base64Decode(encoded);

  /// Packs [ink], row by row, into [bits] form.
  static Uint8List pack(List<bool> ink) {
    final bytes = Uint8List((ink.length + 7) >> 3);
    for (var i = 0; i < ink.length; i++) {
      if (ink[i]) bytes[i >> 3] |= 1 << (7 - (i & 7));
    }
    return bytes;
  }

  BoardImage copyWith({
    Offset? position,
    double? width,
    double? rotation,
    bool? back,
  }) => BoardImage(
    id: id,
    projectId: projectId,
    name: name,
    position: position ?? this.position,
    width: width ?? this.width,
    rotation: rotation ?? this.rotation,
    back: back ?? this.back,
    columns: columns,
    rows: rows,
    bits: bits,
  );
}
