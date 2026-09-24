import 'dart:math' as math;

import '../models/pin.dart';
import '../symbols/symbols.dart';

/// Which side of the body a pin comes out of, when it is laid out for you.
enum PinSide {
  left('Left'),
  right('Right'),
  top('Top'),
  bottom('Bottom');

  const PinSide(this.label);
  final String label;
}

/// The outline of a symbol's body.
enum BodyShape {
  rectangle('Box'),
  triangle('Triangle'),
  circle('Circle'),
  polygon('Polygon');

  const BodyShape(this.label);
  final String label;
}

/// One pin: what it is, and — once it has been dragged — exactly where.
class PinDesign {
  const PinDesign({
    required this.number,
    required this.name,
    this.type = PinElectricalType.passive,
    this.side = PinSide.left,
    this.x,
    this.y,
    this.angle,
    this.length = SymbolDesign.pitch,
    this.style = PinGraphicStyle.line,
  });

  final String number;
  final String name;
  final PinElectricalType type;
  final PinSide side;

  /// Where the pin's connection point is, in symbol millimetres (Y up).
  /// Null lets the layout put it on [side].
  final double? x;
  final double? y;

  /// Which way the pin stub points from its connection point, in degrees:
  /// 0 right, 90 up, 180 left, 270 down. Null faces it at the body.
  final double? angle;

  final double length;
  final PinGraphicStyle style;

  bool get isPlaced => x != null && y != null;

  PinDesign copyWith({
    String? number,
    String? name,
    PinElectricalType? type,
    PinSide? side,
    double? x,
    double? y,
    double? angle,
    double? length,
    PinGraphicStyle? style,
    bool unplace = false,
  }) => PinDesign(
    number: number ?? this.number,
    name: name ?? this.name,
    type: type ?? this.type,
    side: side ?? this.side,
    x: unplace ? null : (x ?? this.x),
    y: unplace ? null : (y ?? this.y),
    angle: unplace ? null : (angle ?? this.angle),
    length: length ?? this.length,
    style: style ?? this.style,
  );
}

/// A component symbol described as fields, a body and a pin list.
///
/// Pins nobody has placed are laid out on their sides the way KiCad's own
/// generators do it, 2.54 mm apart on the grid, with each stub reaching
/// exactly to the body whatever its shape. A dragged pin keeps the place it
/// was dragged to.
class SymbolDesign {
  const SymbolDesign({
    required this.name,
    this.reference = 'U',
    this.value = '',
    this.footprint = '',
    this.description = '',
    this.keywords = '',
    this.pins = const [],
    this.shape = BodyShape.rectangle,
    this.polygonSides = 6,
    this.bodyWidth = 0,
    this.bodyHeight = 0,
    this.showPinNames = true,
    this.showPinNumbers = true,
  });

  final String name;
  final String reference;
  final String value;
  final String footprint;
  final String description;
  final String keywords;
  final List<PinDesign> pins;

  final BodyShape shape;
  final int polygonSides;

  /// The body's size in millimetres; zero sizes it to fit the pins.
  final double bodyWidth;
  final double bodyHeight;

  final bool showPinNames;
  final bool showPinNumbers;

  static const pitch = 2.54;
  static const grid = 1.27;

  SymbolDesign copyWith({
    String? name,
    String? reference,
    String? value,
    String? footprint,
    String? description,
    String? keywords,
    List<PinDesign>? pins,
    BodyShape? shape,
    int? polygonSides,
    double? bodyWidth,
    double? bodyHeight,
    bool? showPinNames,
    bool? showPinNumbers,
  }) => SymbolDesign(
    name: name ?? this.name,
    reference: reference ?? this.reference,
    value: value ?? this.value,
    footprint: footprint ?? this.footprint,
    description: description ?? this.description,
    keywords: keywords ?? this.keywords,
    pins: pins ?? this.pins,
    shape: shape ?? this.shape,
    polygonSides: polygonSides ?? this.polygonSides,
    bodyWidth: bodyWidth ?? this.bodyWidth,
    bodyHeight: bodyHeight ?? this.bodyHeight,
    showPinNames: showPinNames ?? this.showPinNames,
    showPinNumbers: showPinNumbers ?? this.showPinNumbers,
  );

  /// Half the body's width and height, on the grid.
  ///
  /// Sized by every pin on each side, placed or not, so dragging a pin
  /// along its side leaves the body alone — and a reopened symbol, whose
  /// pins all come back placed, keeps the body it was saved with.
  (double, double) get halfSize {
    List<PinDesign> on(PinSide side) => [
      for (final pin in pins)
        if (pin.side == side) pin,
    ];
    final left = on(PinSide.left);
    final right = on(PinSide.right);
    final top = on(PinSide.top);
    final bottom = on(PinSide.bottom);

    double nameWidth(List<PinDesign> side) => side.isEmpty || !showPinNames
        ? 0
        : side.map((p) => p.name.length).reduce(math.max) * 0.8 + 1.27;
    double upToGrid(double v) => (v / pitch).ceil() * pitch;

    var halfHeight = upToGrid(
      math.max(
        math.max(left.length, right.length) * pitch / 2 + pitch / 2,
        math.max(nameWidth(top), nameWidth(bottom)) / 2 + pitch,
      ),
    );
    var halfWidth = upToGrid(
      math.max(
        math.max(top.length, bottom.length) * pitch / 2 + pitch / 2,
        (nameWidth(left) + nameWidth(right)) / 2 + pitch,
      ),
    );
    // A triangle narrows to a point, so the same pins need a longer body;
    // a circle needs its square.
    if (shape == BodyShape.triangle) halfWidth = upToGrid(halfWidth * 1.5);
    if (shape != BodyShape.rectangle && shape != BodyShape.triangle) {
      halfWidth = halfHeight = math.max(halfWidth, halfHeight);
    }
    if (bodyWidth > 0) halfWidth = bodyWidth / 2;
    if (bodyHeight > 0) halfHeight = bodyHeight / 2;
    return (halfWidth, halfHeight);
  }

  /// The body outline, as points in symbol space.
  List<SymbolPoint> outline() {
    final (hw, hh) = halfSize;
    switch (shape) {
      case BodyShape.rectangle:
        return [
          SymbolPoint(-hw, hh),
          SymbolPoint(hw, hh),
          SymbolPoint(hw, -hh),
          SymbolPoint(-hw, -hh),
        ];
      case BodyShape.triangle:
        return [
          SymbolPoint(-hw, hh),
          SymbolPoint(hw, 0),
          SymbolPoint(-hw, -hh),
        ];
      case BodyShape.circle:
        final r = math.min(hw, hh);
        return [
          for (var i = 0; i < 48; i++)
            SymbolPoint(
              r * math.cos(i * math.pi / 24),
              r * math.sin(i * math.pi / 24),
            ),
        ];
      case BodyShape.polygon:
        final sides = polygonSides.clamp(3, 12);
        return [
          for (var i = 0; i < sides; i++)
            SymbolPoint(
              hw * math.cos(math.pi / 2 + i * 2 * math.pi / sides),
              hh * math.sin(math.pi / 2 + i * 2 * math.pi / sides),
            ),
        ];
    }
  }

  /// How far from [from] along [direction] the body's edge is, or null if
  /// that line misses the body.
  double? distanceToBody(SymbolPoint from, SymbolPoint direction) {
    final points = outline();
    double? best;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ex = b.x - a.x;
      final ey = b.y - a.y;
      final denominator = direction.x * ey - direction.y * ex;
      if (denominator.abs() < 1e-12) continue;
      final t = ((a.x - from.x) * ey - (a.y - from.y) * ex) / denominator;
      final u =
          ((a.x - from.x) * direction.y - (a.y - from.y) * direction.x) /
          denominator;
      if (t >= -1e-9 && u >= -1e-9 && u <= 1 + 1e-9) {
        if (best == null || t < best) best = t;
      }
    }
    return best;
  }

  /// Every pin where it goes: dragged pins where they were put, the rest on
  /// their sides, each stub pointing at the body.
  List<SymbolPin> placedPins() {
    final (hw, hh) = halfSize;
    List<PinDesign> on(PinSide side) => [
      for (final pin in pins)
        if (pin.side == side && !pin.isPlaced) pin,
    ];
    List<double> spread(int count) {
      final start = ((count - 1) / 2).floor() * pitch;
      return [for (var i = 0; i < count; i++) start - i * pitch];
    }

    double outToGrid(double v) => (v / grid).ceil() * grid;
    final positions = <PinDesign, SymbolPoint>{};
    void lay(PinSide side) {
      final list = on(side);
      final along = spread(list.length);
      for (var i = 0; i < list.length; i++) {
        final length = list[i].length;
        positions[list[i]] = switch (side) {
          PinSide.left => SymbolPoint(-outToGrid(hw) - length, along[i]),
          PinSide.right => SymbolPoint(outToGrid(hw) + length, along[i]),
          PinSide.top => SymbolPoint(-along[i], outToGrid(hh) + length),
          PinSide.bottom => SymbolPoint(-along[i], -outToGrid(hh) - length),
        };
      }
    }

    PinSide.values.forEach(lay);

    return [
      for (final pin in pins)
        () {
          final at = pin.isPlaced
              ? SymbolPoint(pin.x!, pin.y!)
              : positions[pin] ?? const SymbolPoint(0, 0);
          final angle = pin.angle ?? facingBody(at);
          final radians = angle * math.pi / 180;
          final direction = SymbolPoint(math.cos(radians), math.sin(radians));
          // Laid-out pins reach exactly to the body, whatever its shape; a
          // placed pin keeps the length it was given.
          final reach = pin.isPlaced ? null : distanceToBody(at, direction);
          return SymbolPin(
            number: pin.number,
            name: pin.name.isEmpty ? '~' : pin.name,
            electricalType: pin.type,
            graphicStyle: pin.style,
            at: at,
            angle: angle,
            length: reach == null || reach <= 0 ? pin.length : reach,
          );
        }(),
    ];
  }

  /// Pin [index] moved towards [finger], sliding round the body.
  ///
  /// The pin goes to whichever side of the body the finger is nearest and
  /// runs along it, its stub always reaching the outline — however far the
  /// finger strays, the pin cannot leave the body behind. With [snap] the
  /// place along the side and the connection point settle on the 1.27 mm
  /// grid, the stub stretching the little it takes to still touch the body.
  PinDesign slidePin(int index, SymbolPoint finger, {bool snap = true}) {
    final (hw, hh) = halfSize;
    final side = finger.x.abs() / hw >= finger.y.abs() / hh
        ? (finger.x < 0 ? PinSide.left : PinSide.right)
        : (finger.y < 0 ? PinSide.bottom : PinSide.top);
    // A pin changing sides can change the body's size, so it is measured
    // against the body as it will be with the pin on its new side.
    final onSide = [...pins]..[index] = pins[index].copyWith(side: side);
    return copyWith(pins: onSide)._slideOnSide(index, side, finger, snap);
  }

  PinDesign _slideOnSide(
    int index,
    PinSide side,
    SymbolPoint finger,
    bool snap,
  ) {
    final pin = pins[index];
    final (hw, hh) = halfSize;
    final horizontal = side == PinSide.left || side == PinSide.right;

    // Along the side, kept a hair inside the corners so the stub still has
    // an edge to land on.
    final limit = (horizontal ? hh : hw) * 0.98;
    var along = (horizontal ? finger.y : finger.x).clamp(-limit, limit);
    if (snap) {
      along = (along / grid).round() * grid;
      if (along.abs() > limit) along -= along.sign * grid;
    }

    const far = 1000.0;
    final (from, direction) = switch (side) {
      PinSide.left => (SymbolPoint(-far, along), const SymbolPoint(1, 0)),
      PinSide.right => (SymbolPoint(far, along), const SymbolPoint(-1, 0)),
      PinSide.top => (SymbolPoint(along, far), const SymbolPoint(0, -1)),
      PinSide.bottom => (SymbolPoint(along, -far), const SymbolPoint(0, 1)),
    };
    final t = distanceToBody(from, direction);
    final fallback = horizontal ? hw : hh;
    // How far out from the centre the body's edge is, on this side.
    final edge = t == null ? fallback : far - t;

    var out = edge + pin.length;
    if (snap) {
      // From the stub's length on the grid, not the length a previous snap
      // stretched it to, so dragging a pin again and again cannot grow it.
      final nominal = math.max(grid, (pin.length / grid + 1e-9).floor() * grid);
      out = ((edge + nominal) / grid - 1e-9).ceil() * grid;
    }
    final length = out - edge;

    final (x, y, angle) = switch (side) {
      PinSide.left => (-out, along, 0.0),
      PinSide.right => (out, along, 180.0),
      PinSide.top => (along, out, 270.0),
      PinSide.bottom => (along, -out, 90.0),
    };
    return pin.copyWith(side: side, x: x, y: y, angle: angle, length: length);
  }

  /// The quarter turn that points from [at] towards the body's centre.
  static double facingBody(SymbolPoint at) {
    if (at.x.abs() >= at.y.abs()) return at.x <= 0 ? 0 : 180;
    return at.y <= 0 ? 90 : 270;
  }

  /// The symbol as KiCad reads it, in [library].
  SymbolDefinition build({String library = 'My_Symbols'}) {
    final outline = this.outline();
    const stroke = StrokeStyle(width: 0.254);
    const fill = FillStyle(type: FillType.background);
    final (hw, hh) = halfSize;

    final SymbolGraphic body = switch (shape) {
      BodyShape.rectangle => SymbolRectangle(
        start: SymbolPoint(-hw, hh),
        end: SymbolPoint(hw, -hh),
        stroke: stroke,
        fill: fill,
      ),
      BodyShape.circle => SymbolCircle(
        center: const SymbolPoint(0, 0),
        radius: math.min(hw, hh),
        stroke: stroke,
        fill: fill,
      ),
      _ => SymbolPolyline(
        points: [...outline, outline.first],
        stroke: stroke,
        fill: fill,
      ),
    };

    return SymbolDefinition(
      libraryNickname: library,
      name: name,
      pinNamesHidden: !showPinNames,
      pinNumbersHidden: !showPinNumbers,
      properties: {
        'Reference': reference.isEmpty ? 'U' : reference,
        'Value': value.isEmpty ? name : value,
        'Footprint': footprint,
        'Datasheet': '',
        if (description.isNotEmpty) 'Description': description,
        if (keywords.isNotEmpty) 'ki_keywords': keywords,
        // Remembered so the editor reopens the body it was saved with.
        'ki_zolt_body':
            '${shape.name},$polygonSides,${_n(bodyWidth)},${_n(bodyHeight)}',
      },
      unitDrawings: [
        SymbolUnitDrawing(
          unit: 1,
          bodyStyle: 1,
          graphics: [body],
          pins: placedPins(),
        ),
      ],
    );
  }

  static String _n(double v) => v.toStringAsFixed(3);

  /// A design read back out of a symbol, for editing one made before.
  ///
  /// Every pin comes back placed exactly where it was, so reopening a symbol
  /// never rearranges it.
  static SymbolDesign from(SymbolDefinition symbol) {
    // Symbols saved before the app was called Zolt keep their body under
    // the old name.
    final body =
        (symbol.properties['ki_zolt_body'] ??
                symbol.properties['ki_hintpcb_body'] ??
                '')
            .split(',');
    final shape =
        BodyShape.values
            .where((s) => s.name == (body.isEmpty ? '' : body[0]))
            .firstOrNull ??
        BodyShape.rectangle;
    double at(int i) => body.length > i ? double.tryParse(body[i]) ?? 0 : 0;

    return SymbolDesign(
      name: symbol.name,
      reference: symbol.reference,
      value: symbol.value,
      footprint: symbol.footprint,
      description: symbol.description,
      keywords: symbol.keywords,
      shape: shape,
      polygonSides: body.length > 1 ? int.tryParse(body[1]) ?? 6 : 6,
      bodyWidth: at(2),
      bodyHeight: at(3),
      showPinNames: !symbol.pinNamesHidden,
      showPinNumbers: !symbol.pinNumbersHidden,
      pins: [
        for (final pin in symbol.pins)
          PinDesign(
            number: pin.number,
            name: pin.name == '~' ? '' : pin.name,
            type: pin.electricalType,
            style: pin.graphicStyle,
            side: switch ((pin.angle % 360).round()) {
              0 => PinSide.left,
              180 => PinSide.right,
              270 => PinSide.top,
              _ => PinSide.bottom,
            },
            x: pin.at.x,
            y: pin.at.y,
            angle: pin.angle,
            length: pin.length,
          ),
      ],
    );
  }
}
