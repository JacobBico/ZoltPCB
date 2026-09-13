import 'dart:math' as math;
import 'dart:ui';

import '../models/models.dart';
import '../symbols/symbols.dart';

/// Where and how a symbol unit sits on the sheet.
///
/// Two coordinate systems meet here. Symbol libraries use millimetres with
/// Y pointing up, the way a draughtsman thinks. Schematic sheets — and
/// screens — use millimetres with Y pointing down from the top-left corner.
/// Everything that draws or exports goes through [apply] so the flip is
/// written once.
class Placement {
  const Placement({
    required this.x,
    required this.y,
    this.rotation = 0,
    this.mirrorX = false,
    this.mirrorY = false,
  });

  factory Placement.ofUnit(PartUnit unit) => Placement(
    x: unit.x,
    y: unit.y,
    rotation: unit.rotation,
    mirrorX: unit.mirrorX,
    mirrorY: unit.mirrorY,
  );

  /// Position of the symbol's origin, in sheet millimetres.
  final double x;
  final double y;

  /// Degrees counter-clockwise, as the user sees it: 0, 90, 180 or 270.
  final int rotation;

  final bool mirrorX;
  final bool mirrorY;

  /// Maps a point in symbol space to sheet space.
  Offset apply(double sx, double sy) {
    // Mirroring happens in symbol space, before rotation, which is the
    // order KiCad applies them in.
    var px = mirrorY ? -sx : sx;
    var py = mirrorX ? -sy : sy;

    // Flip to Y-down, then rotate. Rotating after the flip means a positive
    // angle still reads as counter-clockwise on screen.
    final fx = px;
    final fy = -py;

    final radians = rotation * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final rx = fx * cos + fy * sin;
    final ry = -fx * sin + fy * cos;

    return Offset(x + rx, y + ry);
  }

  Offset applyPoint(SymbolPoint point) => apply(point.x, point.y);

  /// The direction a pin stub points, in sheet space, as an angle in degrees
  /// measured clockwise from the positive X axis (screen convention).
  double pinAngle(double symbolAngle) {
    var angle = symbolAngle;
    if (mirrorY) angle = 180 - angle;
    if (mirrorX) angle = -angle;
    // Y-down flips the sense of rotation, then the placement rotation adds.
    return _normalizeDegrees(-angle - rotation);
  }

  static double _normalizeDegrees(double degrees) {
    var value = degrees % 360;
    if (value < 0) value += 360;
    return value;
  }

  @override
  String toString() => 'Placement($x, $y, $rotation°)';
}

/// The bounding box of a symbol unit in symbol space, used to frame the
/// view and to decide what is on screen.
Rect symbolBounds(
  SymbolDefinition symbol,
  int unit, {
  int bodyStyle = 1,
  bool includePins = true,
}) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  void include(double x, double y) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  for (final graphic in symbol.graphicsForUnit(unit, bodyStyle: bodyStyle)) {
    switch (graphic) {
      case SymbolPolyline(:final points):
      case SymbolBezier(:final points):
        for (final p in points) {
          include(p.x, p.y);
        }
      case SymbolRectangle(:final start, :final end):
        include(start.x, start.y);
        include(end.x, end.y);
      case SymbolCircle(:final center, :final radius):
        include(center.x - radius, center.y - radius);
        include(center.x + radius, center.y + radius);
      case SymbolArc(:final start, :final mid, :final end):
        include(start.x, start.y);
        include(mid.x, mid.y);
        include(end.x, end.y);
      case SymbolText(:final at):
        include(at.x, at.y);
      case SymbolTextBox(:final at, :final size):
        include(at.x, at.y);
        include(at.x + size.x, at.y + size.y);
    }
  }

  if (includePins) {
    for (final pin in symbol.pinsForUnit(unit, bodyStyle: bodyStyle)) {
      include(pin.at.x, pin.at.y);
      final radians = pin.angle * math.pi / 180;
      include(
        pin.at.x + pin.length * math.cos(radians),
        pin.at.y + pin.length * math.sin(radians),
      );
    }
  }

  if (minX > maxX) return Rect.zero;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// The extent of a placed unit on the sheet, in sheet millimetres.
///
/// Shared by the canvas and the exporter. Both feed it to the wire router as
/// an obstacle, and a wire that dodges a symbol on the phone has to dodge
/// the same symbol in the exported file — so there is one definition of
/// where a symbol is, not two.
Rect unitBoundsOnSheet({
  required SymbolDefinition? symbol,
  required int unitNumber,
  required int bodyStyle,
  required Placement placement,
  required List<Offset> sheetPoints,
  double minimumExtentMm = 2.54,
}) {
  var rect = Rect.zero;
  var initialised = false;

  void include(Offset point) {
    final r = Rect.fromLTWH(point.dx, point.dy, 0, 0);
    rect = initialised ? rect.expandToInclude(r) : r;
    initialised = true;
  }

  if (symbol != null) {
    final local = symbolBounds(
      symbol,
      unitNumber,
      bodyStyle: bodyStyle,
      includePins: false,
    );
    if (local != Rect.zero) {
      include(placement.apply(local.left, local.top));
      include(placement.apply(local.right, local.top));
      include(placement.apply(local.left, local.bottom));
      include(placement.apply(local.right, local.bottom));
    }
  }

  for (final point in sheetPoints) {
    include(point);
  }

  if (!initialised) {
    // A unit with neither graphics nor pins still needs somewhere to be
    // grabbed, so it gets a nominal box at its origin.
    return Rect.fromCenter(
      center: Offset(placement.x, placement.y),
      width: minimumExtentMm,
      height: minimumExtentMm,
    );
  }

  // Without a library, a two-pin part such as a resistor is a vertical line
  // of pins and its box has no width at all. Widening degenerate axes keeps
  // it visible and, more importantly, grabbable.
  if (rect.width < minimumExtentMm) {
    rect = Rect.fromCenter(
      center: rect.center,
      width: minimumExtentMm,
      height: rect.height,
    );
  }
  if (rect.height < minimumExtentMm) {
    rect = Rect.fromCenter(
      center: rect.center,
      width: rect.width,
      height: minimumExtentMm,
    );
  }
  return rect;
}
