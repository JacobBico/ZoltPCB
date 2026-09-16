import 'dart:math' as math;
import 'dart:ui';

import '../pcb/pcb.dart';
import '../symbols/symbols.dart' show StrokeStyle, StrokeType, FillType;

/// One pad, stated exactly: every number in millimetres or degrees.
class PadDesign {
  const PadDesign({
    required this.number,
    this.type = PadType.smd,
    this.shape = PadShape.roundrect,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
    this.drill = 0,
    this.angle = 0,
    this.roundness = 0.25,
  });

  final String number;
  final PadType type;
  final PadShape shape;
  final double x;
  final double y;
  final double width;
  final double height;

  /// Hole diameter; ignored for a surface-mount pad.
  final double drill;
  final double angle;

  /// Corner radius as a share of the short side, for a rounded rectangle.
  final double roundness;

  PadDesign copyWith({
    String? number,
    PadType? type,
    PadShape? shape,
    double? x,
    double? y,
    double? width,
    double? height,
    double? drill,
    double? angle,
    double? roundness,
  }) => PadDesign(
    number: number ?? this.number,
    type: type ?? this.type,
    shape: shape ?? this.shape,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    drill: drill ?? this.drill,
    angle: angle ?? this.angle,
    roundness: roundness ?? this.roundness,
  );

  /// The pad's extent, ignoring rotation other than quarter turns.
  Rect get bounds {
    final quarter = ((angle % 180) - 90).abs() < 45;
    final w = quarter ? height : width;
    final h = quarter ? width : height;
    return Rect.fromCenter(center: Offset(x, y), width: w, height: h);
  }
}

/// A footprint described exactly, pad by pad.
class FootprintDesign {
  const FootprintDesign({
    required this.name,
    this.description = '',
    this.keywords = '',
    this.pads = const [],
    this.bodyWidth = 0,
    this.bodyHeight = 0,
    this.courtyardMargin = 0.25,
    this.silkscreen = true,
    this.pinOneMarker = true,
  });

  final String name;
  final String description;
  final String keywords;
  final List<PadDesign> pads;

  /// The part's body, centred on the origin. Zero sizes it to the pads.
  final double bodyWidth;
  final double bodyHeight;

  /// How far the courtyard stands off everything else.
  final double courtyardMargin;

  final bool silkscreen;
  final bool pinOneMarker;

  FootprintDesign copyWith({
    String? name,
    String? description,
    String? keywords,
    List<PadDesign>? pads,
    double? bodyWidth,
    double? bodyHeight,
    double? courtyardMargin,
    bool? silkscreen,
    bool? pinOneMarker,
  }) => FootprintDesign(
    name: name ?? this.name,
    description: description ?? this.description,
    keywords: keywords ?? this.keywords,
    pads: pads ?? this.pads,
    bodyWidth: bodyWidth ?? this.bodyWidth,
    bodyHeight: bodyHeight ?? this.bodyHeight,
    courtyardMargin: courtyardMargin ?? this.courtyardMargin,
    silkscreen: silkscreen ?? this.silkscreen,
    pinOneMarker: pinOneMarker ?? this.pinOneMarker,
  );

  Rect? get padBounds {
    Rect? all;
    for (final pad in pads) {
      all = all == null ? pad.bounds : all.expandToInclude(pad.bounds);
    }
    return all;
  }

  Rect get body {
    final pads = padBounds ?? Rect.zero;
    return Rect.fromCenter(
      center: Offset.zero,
      width: bodyWidth > 0 ? bodyWidth : pads.width,
      height: bodyHeight > 0 ? bodyHeight : pads.height,
    );
  }

  /// The courtyard: body and pads together, stood off by the margin, and
  /// rounded out to 0.01 mm the way KiCad's checker expects.
  Rect get courtyard {
    final pads = padBounds;
    final all = pads == null ? body : body.expandToInclude(pads);
    final grown = all.inflate(courtyardMargin);
    double out(double v) => (v * 100).roundToDouble() / 100;
    return Rect.fromLTRB(
      out(grown.left),
      out(grown.top),
      out(grown.right),
      out(grown.bottom),
    );
  }

  static const _fabWidth = 0.1;
  static const _silkWidth = 0.12;
  static const _courtyardWidth = 0.05;

  /// The footprint KiCad reads, in [library].
  FootprintDefinition build({String library = 'My_Footprints'}) {
    final graphics = <FootprintGraphic>[];
    StrokeStyle stroke(double width) =>
        StrokeStyle(width: width, type: StrokeType.solid);
    FootprintPoint p(double x, double y) => FootprintPoint(x, y);

    final body = this.body;
    if (!body.isEmpty) {
      graphics.add(
        FootprintRect(
          start: p(body.left, body.top),
          end: p(body.right, body.bottom),
          layer: BoardLayer.frontFab,
          stroke: stroke(_fabWidth),
        ),
      );
    }

    final court = courtyard;
    graphics.add(
      FootprintRect(
        start: p(court.left, court.top),
        end: p(court.right, court.bottom),
        layer: BoardLayer.frontCourtyard,
        stroke: stroke(_courtyardWidth),
      ),
    );

    // Silkscreen follows the body but never crosses copper: each edge is
    // drawn only where it clears every pad by a little more than a line.
    if (silkscreen && !body.isEmpty) {
      final outline = body.inflate(_silkWidth);
      final keepOut = [for (final pad in pads) pad.bounds.inflate(0.2)];
      for (final (a, b) in [
        (outline.topLeft, outline.topRight),
        (outline.topRight, outline.bottomRight),
        (outline.bottomRight, outline.bottomLeft),
        (outline.bottomLeft, outline.topLeft),
      ]) {
        for (final (s, e) in _clear(a, b, keepOut)) {
          graphics.add(
            FootprintLine(
              start: p(s.dx, s.dy),
              end: p(e.dx, e.dy),
              layer: BoardLayer.frontSilk,
              stroke: stroke(_silkWidth),
            ),
          );
        }
      }
    }

    if (pinOneMarker && pads.isNotEmpty) {
      final first = pads.firstWhere(
        (pad) => pad.number == '1',
        orElse: () => pads.first,
      );
      final bounds = first.bounds;
      final towards = Offset(first.x, first.y);
      final corner = Offset(
        towards.dx <= 0 ? bounds.left - 0.5 : bounds.right + 0.5,
        towards.dy <= 0 ? bounds.top - 0.5 : bounds.bottom + 0.5,
      );
      graphics.add(
        FootprintCircle(
          center: p(corner.dx, corner.dy),
          end: p(corner.dx + 0.15, corner.dy),
          layer: BoardLayer.frontSilk,
          stroke: stroke(0.3),
          fill: FillType.outline,
        ),
      );
    }

    final smd = pads.isNotEmpty && pads.every((p) => p.type == PadType.smd);
    return FootprintDefinition(
      libraryNickname: library,
      name: name,
      description: description,
      keywords: keywords,
      attributes: [smd ? 'smd' : 'through_hole'],
      pads: [for (final pad in pads) _pad(pad)],
      graphics: graphics,
    );
  }

  static Pad _pad(PadDesign pad) {
    final raw = switch (pad.type) {
      PadType.smd => ['F.Cu', 'F.Paste', 'F.Mask'],
      PadType.npth => ['*.Cu', '*.Mask'],
      _ => ['*.Cu', '*.Mask'],
    };
    return Pad(
      number: pad.type == PadType.npth ? '' : pad.number,
      type: pad.type,
      shape: pad.shape,
      at: FootprintPoint(pad.x, pad.y),
      sizeX: pad.width,
      sizeY: pad.height,
      angle: pad.angle,
      drill: pad.type == PadType.smd ? 0 : pad.drill,
      roundrectRatio: pad.shape == PadShape.roundrect ? pad.roundness : 0,
      rawLayers: raw,
      layers: [
        if (pad.type == PadType.smd) ...[
          BoardLayer.frontCopper,
          BoardLayer.frontPaste,
          BoardLayer.frontMask,
        ] else ...[
          BoardLayer.frontCopper,
          BoardLayer.backCopper,
          BoardLayer.frontMask,
          BoardLayer.backMask,
        ],
      ],
    );
  }

  /// The parts of segment a→b clear of every rectangle in [keepOut].
  static List<(Offset, Offset)> _clear(Offset a, Offset b, List<Rect> keepOut) {
    const steps = 400;
    final pieces = <(Offset, Offset)>[];
    Offset? start;
    Offset? last;
    for (var i = 0; i <= steps; i++) {
      final point = Offset.lerp(a, b, i / steps)!;
      final blocked = keepOut.any((r) => r.contains(point));
      if (!blocked) {
        start ??= point;
        last = point;
      } else if (start != null) {
        if ((last! - start).distance > 0.1) pieces.add((start, last));
        start = null;
      }
    }
    if (start != null && (last! - start).distance > 0.1) {
      pieces.add((start, last));
    }
    return pieces;
  }

  /// A design read back from a footprint made before.
  static FootprintDesign from(FootprintDefinition footprint) {
    final fab = footprint.graphics
        .whereType<FootprintRect>()
        .where((r) => r.layer == BoardLayer.frontFab)
        .firstOrNull;
    return FootprintDesign(
      name: footprint.name,
      description: footprint.description,
      keywords: footprint.keywords,
      bodyWidth: fab == null ? 0 : (fab.end.x - fab.start.x).abs(),
      bodyHeight: fab == null ? 0 : (fab.end.y - fab.start.y).abs(),
      pads: [
        for (final pad in footprint.pads)
          PadDesign(
            number: pad.number,
            type: pad.type,
            shape: pad.shape,
            x: pad.at.x,
            y: pad.at.y,
            width: pad.sizeX,
            height: pad.sizeY,
            drill: pad.drill,
            angle: pad.angle,
            roundness: pad.roundrectRatio == 0 ? 0.25 : pad.roundrectRatio,
          ),
      ],
    );
  }
}

/// Pads laid out from a few exact numbers, the way a datasheet states them.
abstract final class PadPatterns {
  /// Two pads either side of the origin: a resistor, a capacitor, a diode.
  static List<PadDesign> twoPad({
    required double centreDistance,
    required double padWidth,
    required double padHeight,
  }) => [
    PadDesign(
      number: '1',
      x: -centreDistance / 2,
      width: padWidth,
      height: padHeight,
    ),
    PadDesign(
      number: '2',
      x: centreDistance / 2,
      width: padWidth,
      height: padHeight,
    ),
  ];

  /// A row, or a double row, of through-hole pins: a pin header.
  ///
  /// Pin 1 is square. A double row numbers across and down — 1 and 2 side by
  /// side — which is how a header is numbered.
  static List<PadDesign> header({
    required int pins,
    required double pitch,
    int rows = 1,
    double rowSpacing = 2.54,
    double padSize = 1.7,
    double drill = 1.0,
  }) {
    final perRow = (pins / rows).ceil();
    final result = <PadDesign>[];
    for (var i = 0; i < pins; i++) {
      final column = i % rows;
      final row = i ~/ rows;
      result.add(
        PadDesign(
          number: '${i + 1}',
          type: PadType.thruHole,
          shape: i == 0 ? PadShape.rect : PadShape.oval,
          x: column * rowSpacing - (rows - 1) * rowSpacing / 2,
          y: row * pitch - (perRow - 1) * pitch / 2,
          width: padSize,
          height: padSize,
          drill: drill,
        ),
      );
    }
    return result;
  }

  /// Two rows facing each other, numbered down one side and up the other:
  /// DIP, SOIC, SOP, TSSOP.
  static List<PadDesign> dualRow({
    required int pins,
    required double pitch,
    required double rowSpacing,
    required double padWidth,
    required double padHeight,
    bool throughHole = false,
    double drill = 0.8,
  }) {
    final perSide = pins ~/ 2;
    final result = <PadDesign>[];
    for (var i = 0; i < perSide * 2; i++) {
      final leftSide = i < perSide;
      final index = leftSide ? i : perSide * 2 - 1 - i;
      result.add(
        PadDesign(
          number: '${i + 1}',
          type: throughHole ? PadType.thruHole : PadType.smd,
          shape: throughHole
              ? (i == 0 ? PadShape.rect : PadShape.oval)
              : PadShape.roundrect,
          x: leftSide ? -rowSpacing / 2 : rowSpacing / 2,
          y: index * pitch - (perSide - 1) * pitch / 2,
          width: padWidth,
          height: padHeight,
          drill: throughHole ? drill : 0,
        ),
      );
    }
    return result;
  }

  /// Pads on all four sides, numbered counter-clockwise from the top of the
  /// left side: QFN, QFP. An exposed pad, if given, takes the next number.
  static List<PadDesign> quad({
    required int pinsPerSide,
    required double pitch,
    required double span,
    required double padLength,
    required double padWidth,
    double exposedPad = 0,
  }) {
    final result = <PadDesign>[];
    final offset = (pinsPerSide - 1) * pitch / 2;
    var number = 1;
    for (var side = 0; side < 4; side++) {
      for (var i = 0; i < pinsPerSide; i++) {
        final along = -offset + i * pitch;
        final (x, y, vertical) = switch (side) {
          0 => (-span / 2, along, false),
          1 => (along, span / 2, true),
          2 => (span / 2, -along, false),
          _ => (-along, -span / 2, true),
        };
        result.add(
          PadDesign(
            number: '${number++}',
            x: x,
            y: y,
            width: vertical ? padWidth : padLength,
            height: vertical ? padLength : padWidth,
          ),
        );
      }
    }
    if (exposedPad > 0) {
      result.add(
        PadDesign(
          number: '$number',
          width: exposedPad,
          height: exposedPad,
          roundness: 0.05,
        ),
      );
    }
    return result;
  }

  /// The centre-to-centre distance from [pad] to its nearest neighbour.
  static double? pitchOf(PadDesign pad, List<PadDesign> all) {
    double? best;
    for (final other in all) {
      if (identical(other, pad)) continue;
      final d = math.sqrt(
        math.pow(other.x - pad.x, 2) + math.pow(other.y - pad.y, 2),
      );
      if (d > 1e-9 && (best == null || d < best)) best = d;
    }
    return best;
  }
}
