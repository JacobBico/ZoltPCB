import 'dart:math' as math;

import '../symbols/symbols.dart' show StrokeStyle, FillType;
import 'board_layer.dart';

/// A point in footprint space, in millimetres.
///
/// Unlike symbol space, footprint coordinates are Y-down — the same way up
/// as the board and the screen. KiCad made that choice, not us, and the
/// difference is worth stating because the two formats sit side by side in
/// this app.
class FootprintPoint {
  const FootprintPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is FootprintPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// How a pad is attached to the board.
enum PadType {
  /// Surface mount: copper on one side only.
  smd('smd'),

  /// A plated hole through every copper layer.
  thruHole('thru_hole'),

  /// An unplated hole — a mounting hole, not a connection.
  npth('np_thru_hole'),

  /// An edge connector finger.
  connect('connect');

  const PadType(this.token);

  final String token;

  static PadType fromToken(String token) => PadType.values.firstWhere(
    (t) => t.token == token,
    orElse: () => PadType.smd,
  );

  bool get isPlated => this != PadType.npth;

  /// Whether this pad reaches both sides of a two-layer board.
  bool get spansLayers =>
      this == PadType.thruHole || this == PadType.npth;
}

/// The outline a pad is drawn with.
enum PadShape {
  circle('circle'),
  rect('rect'),
  oval('oval'),
  roundrect('roundrect'),
  trapezoid('trapezoid'),

  /// An arbitrary polygon. Drawn as its bounding rectangle: fewer than one
  /// pad in two hundred is custom, and a rectangle of the right size in the
  /// right place is a better answer than refusing the footprint.
  custom('custom');

  const PadShape(this.token);

  final String token;

  static PadShape fromToken(String token) => PadShape.values.firstWhere(
    (t) => t.token == token,
    orElse: () => PadShape.rect,
  );
}

/// One pad of a footprint, in footprint space.
class Pad {
  const Pad({
    required this.number,
    required this.type,
    required this.shape,
    required this.at,
    required this.sizeX,
    required this.sizeY,
    this.angle = 0,
    this.drill = 0,
    this.drillY = 0,
    this.roundrectRatio = 0,
    this.layers = const [],
    this.rawLayers = const [],
  });

  /// The pad identifier, matching a schematic pin number. Not necessarily
  /// numeric, and not necessarily unique: ground pads on a connector often
  /// share one.
  final String number;

  final PadType type;
  final PadShape shape;
  final FootprintPoint at;
  final double sizeX;
  final double sizeY;

  /// Degrees counter-clockwise, relative to the footprint.
  final double angle;

  /// Hole diameter, or 0 for a surface-mount pad. An oval hole also sets
  /// [drillY].
  final double drill;
  final double drillY;

  final double roundrectRatio;

  /// The layers this pad occupies, resolved to the ones we draw.
  final List<BoardLayer> layers;

  /// The layer names exactly as the file gave them, wildcards included.
  /// Kept so an export can put back what it read.
  final List<String> rawLayers;

  bool get isPlated => type.isPlated;

  /// A pad with no number connects to nothing — a mechanical hole or a
  /// thermal tab that the footprint author left unnamed.
  bool get isConnectable => number.isNotEmpty && number != '""' && isPlated;

  @override
  String toString() => 'Pad($number, ${type.token} ${shape.token})';
}

/// A graphic drawn as part of a footprint: silkscreen, courtyard, fab.
sealed class FootprintGraphic {
  const FootprintGraphic({required this.layer, required this.stroke});

  final BoardLayer? layer;
  final StrokeStyle stroke;
}

class FootprintLine extends FootprintGraphic {
  const FootprintLine({
    required this.start,
    required this.end,
    required super.layer,
    required super.stroke,
  });

  final FootprintPoint start;
  final FootprintPoint end;
}

class FootprintRect extends FootprintGraphic {
  const FootprintRect({
    required this.start,
    required this.end,
    required super.layer,
    required super.stroke,
    this.fill = FillType.none,
  });

  final FootprintPoint start;
  final FootprintPoint end;
  final FillType fill;
}

class FootprintCircle extends FootprintGraphic {
  const FootprintCircle({
    required this.center,
    required this.end,
    required super.layer,
    required super.stroke,
    this.fill = FillType.none,
  });

  final FootprintPoint center;

  /// A point on the circumference — KiCad states the radius that way.
  final FootprintPoint end;
  final FillType fill;

  double get radius {
    final dx = end.x - center.x;
    final dy = end.y - center.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class FootprintArc extends FootprintGraphic {
  const FootprintArc({
    required this.start,
    required this.mid,
    required this.end,
    required super.layer,
    required super.stroke,
  });

  final FootprintPoint start;
  final FootprintPoint mid;
  final FootprintPoint end;
}

class FootprintPolygon extends FootprintGraphic {
  const FootprintPolygon({
    required this.points,
    required super.layer,
    required super.stroke,
    this.fill = FillType.none,
  });

  final List<FootprintPoint> points;
  final FillType fill;
}

/// A complete footprint, as read from one `.kicad_mod` file.
class FootprintDefinition {
  const FootprintDefinition({
    required this.libraryNickname,
    required this.name,
    this.description = '',
    this.keywords = '',
    this.pads = const [],
    this.graphics = const [],
    this.attributes = const [],
    this.formatVersion = 0,
    this.generator = '',
  });

  final String libraryNickname;
  final String name;
  final String description;
  final String keywords;
  final List<Pad> pads;
  final List<FootprintGraphic> graphics;

  /// `smd`, `through_hole`, `exclude_from_bom` and friends.
  final List<String> attributes;

  final int formatVersion;
  final String generator;

  /// `Resistor_SMD:R_0805_2012Metric` — how a board file names it, and what
  /// a part's footprint field holds.
  String get libId => '$libraryNickname:$name';

  bool get isSurfaceMount => attributes.contains('smd');
  bool get isThroughHole =>
      attributes.contains('through_hole') ||
      pads.any((p) => p.type == PadType.thruHole);

  /// Pads that can carry a net, in file order.
  Iterable<Pad> get connectablePads => pads.where((p) => p.isConnectable);

  /// Distinct pad numbers — the count a schematic symbol has to match.
  int get padCount => connectablePads.map((p) => p.number).toSet().length;

  @override
  String toString() => 'FootprintDefinition($libId, ${pads.length} pads)';
}
