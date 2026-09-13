import 'dart:math' as math;
import 'dart:ui';

/// How a drawn track is allowed to turn.
///
/// Two options, not three. A free-angle mode was offered at first and was a
/// mistake: it let a finger draw a 3° trace, which no fabricator's design
/// rules like and no one meant to draw. KiCad constrains to 45° and 90° for
/// the same reason, and a phone needs the constraint more, not less.
enum TrackAngleMode {
  /// 45° and 90° — KiCad's default, and the reason boards look the way they
  /// do. Any point is reached by one diagonal run and one straight one.
  diagonal('45°'),

  /// 90° only. Two runs, one horizontal and one vertical.
  orthogonal('90°');

  const TrackAngleMode(this.label);

  final String label;

  TrackAngleMode get next =>
      TrackAngleMode.values[(index + 1) % TrackAngleMode.values.length];
}

/// Turns a start point and a finger position into the corners of a track.
///
/// Drawing copper freehand on a phone produces angles nobody wants and a
/// board nobody can fabricate cleanly. Constraining every run to 45° or 90°
/// is what makes a finger-drawn track look like a routed one — and it is
/// what KiCad does on the desktop, so a board finished there does not have
/// to be redrawn.
abstract final class TrackRouter {
  /// The corners from [from] to [to], inclusive of both.
  ///
  /// Returns a single point when the two coincide, so a caller can always
  /// take the last element as "where the route currently ends".
  /// [obstacles] are the footprints in the way, in board millimetres.
  ///
  /// Both corner choices are legal; when one of them cuts through a part and
  /// the other does not, the clear one is taken. That is what stops a route
  /// drawn pad-to-pad from running straight through the component between
  /// them, which is the first thing anyone tries and the first thing that
  /// used to go wrong.
  static List<Offset> route({
    required Offset from,
    required Offset to,
    TrackAngleMode mode = TrackAngleMode.diagonal,
    bool straightFirst = false,
    List<Rect> obstacles = const [],
  }) {
    if ((to - from).distance < 1e-9) return [from];

    final preferred = _shape(from, to, mode, straightFirst);
    if (obstacles.isEmpty) return preferred;

    final alternative = _shape(from, to, mode, !straightFirst);
    return _crossings(alternative, obstacles) < _crossings(preferred, obstacles)
        ? alternative
        : preferred;
  }

  static List<Offset> _shape(
    Offset from,
    Offset to,
    TrackAngleMode mode,
    bool straightFirst,
  ) {
    switch (mode) {
      case TrackAngleMode.orthogonal:
        final corner = straightFirst
            ? Offset(from.dx, to.dy)
            : Offset(to.dx, from.dy);
        return _simplify([from, corner, to]);

      case TrackAngleMode.diagonal:
        final dx = to.dx - from.dx;
        final dy = to.dy - from.dy;
        final run = math.min(dx.abs(), dy.abs());
        final signX = dx.isNegative ? -1 : 1;
        final signY = dy.isNegative ? -1 : 1;

        // The diagonal covers the shorter axis completely; the straight run
        // covers what is left of the longer one. Which comes first is the
        // user's choice, because both are legal and only one looks right in
        // any given corner of a board.
        final Offset corner;
        if (straightFirst) {
          corner = dx.abs() > dy.abs()
              ? Offset(to.dx - run * signX, from.dy)
              : Offset(from.dx, to.dy - run * signY);
        } else {
          corner = Offset(from.dx + run * signX, from.dy + run * signY);
        }
        return _simplify([from, corner, to]);
    }
  }

  /// How many obstacles a route passes through.
  ///
  /// A segment that merely touches an edge does not count: a trace leaving a
  /// pad starts on its own footprint's courtyard every time.
  static int _crossings(List<Offset> points, List<Rect> obstacles) {
    var count = 0;
    for (var i = 0; i < points.length - 1; i++) {
      for (final obstacle in obstacles) {
        if (_segmentCrossesRect(points[i], points[i + 1], obstacle)) count++;
      }
    }
    return count;
  }

  static bool _segmentCrossesRect(Offset a, Offset b, Rect rect) {
    // Sampled rather than solved: a diagonal against an axis-aligned box is
    // a handful of cases to get wrong, and a route is a few millimetres of
    // board checked a few dozen times per gesture.
    const steps = 24;
    for (var i = 1; i < steps; i++) {
      final point = Offset.lerp(a, b, i / steps)!;
      if (rect.deflate(1e-6).contains(point)) return true;
    }
    return false;
  }

  /// Rounds a point onto the board grid.
  static Offset snap(Offset point, double gridMm) {
    if (gridMm <= 0) return point;
    return Offset(
      (point.dx / gridMm).round() * gridMm,
      (point.dy / gridMm).round() * gridMm,
    );
  }

  /// Whether a segment obeys [mode].
  static bool isLegal(Offset a, Offset b, TrackAngleMode mode) {
    final dx = (b.dx - a.dx).abs();
    final dy = (b.dy - a.dy).abs();
    const epsilon = 1e-6;
    if (dx < epsilon || dy < epsilon) return true;
    if (mode == TrackAngleMode.orthogonal) return false;
    return (dx - dy).abs() < epsilon;
  }

  static List<Offset> _simplify(List<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isNotEmpty && (result.last - point).distance < 1e-9) continue;
      result.add(point);
    }
    return result;
  }
}
