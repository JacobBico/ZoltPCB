import 'dart:math' as math;
import 'dart:ui';

import 'board.dart';
import 'board_layer.dart';
import 'footprint.dart';

/// Where and how a footprint sits on the board.
///
/// The counterpart of [Placement] for the board side, and deliberately not
/// the same class. Symbol space is Y-up and flips only for mirroring;
/// footprint space is Y-down like the board itself, and "flip" means moving
/// the part to the other side, which swaps its layers as well as its
/// geometry. Sharing one class would mean one of the two carrying a flag
/// explaining which world it was in.
class FootprintPlacement {
  const FootprintPlacement({
    required this.x,
    required this.y,
    this.rotation = 0,
    this.flipped = false,
  });

  factory FootprintPlacement.of(PlacedFootprintRef ref) => FootprintPlacement(
    x: ref.x,
    y: ref.y,
    rotation: ref.rotation,
    flipped: ref.flipped,
  );

  /// Origin of the footprint, in board millimetres.
  final double x;
  final double y;

  /// Degrees counter-clockwise, as the user sees it.
  final double rotation;

  /// True when the component is on the back of the board.
  final bool flipped;

  /// Maps a point in footprint space to board space.
  Offset apply(double fx, double fy) {
    // Flipping mirrors left to right. Looking through the board from the
    // front is what a back-side component looks like, and that is what
    // KiCad draws.
    final mx = flipped ? -fx : fx;

    final radians = rotation * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    // Board space is Y-down, so a positive angle reads counter-clockwise
    // only if the sine terms are taken this way round.
    final rx = mx * cos + fy * sin;
    final ry = -mx * sin + fy * cos;

    return Offset(x + rx, y + ry);
  }

  Offset applyPoint(FootprintPoint point) => apply(point.x, point.y);

  /// Which way text at [angle] in the footprint's own frame reads on the
  /// board, kept upright the way KiCad keeps a footprint's text.
  double textRotation(double angle) {
    var a = (rotation + angle) % 360;
    if (a < 0) a += 360;
    if (a > 90 && a <= 270) a -= 180;
    return a;
  }

  /// Maps a point on the board back into footprint space — the inverse of
  /// [apply], for storing something the user placed on the board in the
  /// frame it has to be written in.
  Offset invert(Offset board) {
    final rx = board.dx - x;
    final ry = board.dy - y;

    final radians = rotation * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    // The rotation in [apply] is orthonormal, so its inverse is its
    // transpose.
    final mx = rx * cos - ry * sin;
    final fy = rx * sin + ry * cos;

    return Offset(flipped ? -mx : mx, fy);
  }

  /// A pad's own rotation once the footprint's is taken into account.
  double padAngle(double padAngle) {
    final flippedAngle = flipped ? -padAngle : padAngle;
    return _normalize(flippedAngle + rotation);
  }

  /// The layer a footprint graphic or pad actually lands on.
  BoardLayer? layerOf(BoardLayer? layer) {
    if (layer == null) return null;
    return flipped ? layer.flipped : layer;
  }

  static double _normalize(double degrees) {
    var value = degrees % 360;
    if (value < 0) value += 360;
    return value;
  }
}

/// The extent of a footprint in its own space, in millimetres.
///
/// Courtyard first when there is one: it is the outline the footprint
/// author intended as "do not put anything else here", which is exactly
/// what a finger needs to grab and what placement needs to respect. Falls
/// back to pads and silkscreen.
Rect footprintBounds(FootprintDefinition footprint) {
  Rect? courtyard;
  Rect? everything;

  void include(Rect? Function() get, void Function(Rect) set, Offset point) {
    final existing = get();
    final r = Rect.fromLTWH(point.dx, point.dy, 0, 0);
    set(existing == null ? r : existing.expandToInclude(r));
  }

  void addToAll(Offset point) =>
      include(() => everything, (r) => everything = r, point);

  for (final graphic in footprint.graphics) {
    final onCourtyard =
        graphic.layer == BoardLayer.frontCourtyard ||
        graphic.layer == BoardLayer.backCourtyard;

    void add(Offset point) {
      addToAll(point);
      if (onCourtyard) {
        include(() => courtyard, (r) => courtyard = r, point);
      }
    }

    switch (graphic) {
      case FootprintLine(:final start, :final end):
        add(Offset(start.x, start.y));
        add(Offset(end.x, end.y));
      case FootprintRect(:final start, :final end):
        add(Offset(start.x, start.y));
        add(Offset(end.x, end.y));
      case FootprintCircle(:final center):
        final r = graphic.radius;
        add(Offset(center.x - r, center.y - r));
        add(Offset(center.x + r, center.y + r));
      case FootprintArc(:final start, :final mid, :final end):
        add(Offset(start.x, start.y));
        add(Offset(mid.x, mid.y));
        add(Offset(end.x, end.y));
      case FootprintPolygon(:final points):
        for (final point in points) {
          add(Offset(point.x, point.y));
        }
      case FootprintText(:final at):
        add(Offset(at.x, at.y));
    }
  }

  for (final pad in footprint.pads) {
    final half = Offset(pad.sizeX / 2, pad.sizeY / 2);
    addToAll(Offset(pad.at.x - half.dx, pad.at.y - half.dy));
    addToAll(Offset(pad.at.x + half.dx, pad.at.y + half.dy));
  }

  final chosen = courtyard ?? everything;
  if (chosen == null) return Rect.zero;

  // A footprint of one pad and nothing else still has to be grabbable.
  const minimum = 1.0;
  var rect = chosen;
  if (rect.width < minimum) {
    rect = Rect.fromCenter(
      center: rect.center,
      width: minimum,
      height: rect.height,
    );
  }
  if (rect.height < minimum) {
    rect = Rect.fromCenter(
      center: rect.center,
      width: rect.width,
      height: minimum,
    );
  }
  return rect;
}
