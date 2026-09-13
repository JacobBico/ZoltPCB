import 'dart:math' as math;
import 'dart:ui';

/// The direction a wire run can slide.
enum WireAxis { horizontal, vertical }

/// A run of a route the user can take hold of and move.
///
/// The runs that touch the pins are not handles: they have to meet the pin,
/// so they cannot move. Everything between them can.
class WireHandle {
  const WireHandle({
    required this.offsetIndex,
    required this.moveAxis,
    required this.start,
    required this.end,
  });

  /// Which entry of the route's offset list this run is controlled by.
  final int offsetIndex;

  /// The direction the run slides when dragged — always perpendicular to
  /// the run itself.
  final WireAxis moveAxis;

  final Offset start;
  final Offset end;

  /// Distance from [point] to this run.
  ///
  /// A run collapses to a point when the wire has been straightened out.
  /// It still has to be reachable — otherwise straightening a wire would
  /// make it impossible to bend again — so a degenerate run measures from
  /// its position rather than reporting that it cannot be hit.
  double distanceTo(Offset point) => _distanceToSegment(point, start, end);

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-12) return (p - a).distance;

    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}

/// A routed connection: the points to draw, and the runs that can be moved.
class WireRoute {
  const WireRoute({required this.points, required this.handles});

  final List<Offset> points;
  final List<WireHandle> handles;

  /// How many offsets this shape takes.
  static int offsetCountFor({
    required bool fromHorizontal,
    required bool toHorizontal,
  }) => fromHorizontal == toHorizontal ? 1 : 2;
}

/// Routes a connection between two pins as axis-aligned segments.
///
/// KiCad schematics are drawn with orthogonal wires that leave a pin along
/// its axis and turn at right angles. A straight diagonal says the same
/// thing electrically but reads as a rat's-nest preview rather than a
/// drawing, so connections are routed here before they are painted.
///
/// The shape is described by a small list of offsets, one per movable run.
/// Offsets are stored as displacements from the automatic route rather than
/// as absolute coordinates, so a wire keeps the adjustment the user gave it
/// when the parts at either end are moved.
abstract final class WireRouter {
  /// KiCad's schematic grid. Corners land on it so the drawing stays tidy
  /// and matches what the desktop would produce.
  static const double gridMm = 1.27;

  /// How far a wire runs straight out of a pin before it may turn, so a
  /// corner never sits on top of the pin itself.
  static const double stubMm = 2.54;

  static WireRoute route({
    required Offset from,
    required Offset fromExit,
    required Offset to,
    required Offset toExit,
    List<Rect> obstacles = const [],
    List<double> offsets = const [],
  }) {
    final stubA = _stubEnd(from, fromExit);
    final stubB = _stubEnd(to, toExit);
    final fromHorizontal = fromExit.dx.abs() > fromExit.dy.abs();
    final toHorizontal = toExit.dx.abs() > toExit.dy.abs();

    double offset(int index) =>
        index < offsets.length ? offsets[index] : 0.0;

    final handles = <WireHandle>[];

    if (fromHorizontal == toHorizontal) {
      // Both ends leave the same way, so one crossing run joins them and
      // that run is the only thing free to move.
      final horizontal = fromHorizontal;

      List<Offset> shape(double value) => horizontal
          ? [
              from,
              stubA,
              Offset(value, stubA.dy),
              Offset(value, stubB.dy),
              stubB,
              to,
            ]
          : [
              from,
              stubA,
              Offset(stubA.dx, value),
              Offset(stubB.dx, value),
              stubB,
              to,
            ];

      final base = horizontal
          ? (stubA.dx + stubB.dx) / 2
          : (stubA.dy + stubB.dy) / 2;

      final chosen = _clearest(
        candidates: () => [
          base,
          horizontal ? stubA.dx : stubA.dy,
          horizontal ? stubB.dx : stubB.dy,
          ..._sidesOf(
            _blockers(shape(base), obstacles),
            horizontal: horizontal,
          ),
        ],
        shape: shape,
        obstacles: obstacles,
        fallback: base,
      );

      // When both pins lie on one line facing away from each other — the two
      // ends of a resistor, joined to each other — every route of the shape
      // above runs down that line, through the part, wherever its crossing
      // is put. The way round is the other shape: out of one pin, along the
      // side of the part, and back in to the other.
      List<Offset> detour(double value) => horizontal
          ? [
              from,
              stubA,
              Offset(stubA.dx, value),
              Offset(stubB.dx, value),
              stubB,
              to,
            ]
          : [
              from,
              stubA,
              Offset(value, stubA.dy),
              Offset(value, stubB.dy),
              stubB,
              to,
            ];

      final crossings = _crossings(shape(chosen), obstacles);
      if (crossings > 0) {
        final blockers = _blockers(shape(chosen), obstacles);
        double? bestDetour;
        var bestDetourCrossings = crossings;
        for (final candidate in _sidesOf(blockers, horizontal: !horizontal)) {
          final count = _crossings(detour(candidate), obstacles);
          if (count < bestDetourCrossings) {
            bestDetourCrossings = count;
            bestDetour = candidate;
            if (count == 0) break;
          }
        }

        if (bestDetour != null) {
          final value = _snapValue(bestDetour + offset(0));
          final points = detour(value);
          handles.add(
            WireHandle(
              offsetIndex: 0,
              // The free run of a detour lies along the pins' line, so it
              // slides across it — the opposite axis to a crossing.
              moveAxis: horizontal ? WireAxis.vertical : WireAxis.horizontal,
              start: points[2],
              end: points[3],
            ),
          );
          return WireRoute(points: _simplify(points), handles: handles);
        }
      }

      final value = _snapValue(chosen + offset(0));
      final points = shape(value);
      handles.add(
        WireHandle(
          offsetIndex: 0,
          moveAxis: horizontal ? WireAxis.horizontal : WireAxis.vertical,
          start: points[2],
          end: points[3],
        ),
      );
      return WireRoute(points: _simplify(points), handles: handles);
    }

    // Mixed: one end leaves sideways and the other up or down. Two runs in
    // the middle, each free on its own axis — dragging either is how a
    // staircase gets straightened out.
    //
    // Both runs also have to be *placed*, and placing them naively is what
    // used to send a wire straight through the symbol it came from: joining
    // two pins of the same part, the default corner sits inside the body,
    // and a wire drawn inside a symbol cannot be grabbed afterwards because
    // the symbol is on top of it. So the corner is chosen, not assumed.
    final firstIsHorizontal = fromHorizontal;

    List<Offset> shapeOf(double x, double y) => firstIsHorizontal
        ? [
            from,
            stubA,
            Offset(x, stubA.dy),
            Offset(x, y),
            Offset(stubB.dx, y),
            stubB,
            to,
          ]
        : [
            from,
            stubA,
            Offset(stubA.dx, y),
            Offset(x, y),
            Offset(x, stubB.dy),
            stubB,
            to,
          ];

    // The route the old code always took. Still the first thing tried, so
    // an unobstructed wire looks exactly as it did.
    final defaultX = firstIsHorizontal ? stubB.dx : stubA.dx;
    final defaultY = firstIsHorizontal ? stubA.dy : stubB.dy;

    final blockers = _blockers(shapeOf(defaultX, defaultY), obstacles);

    var bestX = defaultX;
    var bestY = defaultY;

    if (blockers.isNotEmpty) {
      final xs = <double>[
        defaultX,
        firstIsHorizontal ? stubA.dx : stubB.dx,
        ..._sidesOf(blockers, horizontal: true),
      ];
      final ys = <double>[
        defaultY,
        firstIsHorizontal ? stubB.dy : stubA.dy,
        ..._sidesOf(blockers, horizontal: false),
      ];

      var bestScore = -1;
      for (var i = 0; i < xs.length; i++) {
        for (var j = 0; j < ys.length; j++) {
          final crossings = _crossings(shapeOf(xs[i], ys[j]), obstacles);
          if (bestScore < 0 || crossings < bestScore) {
            bestScore = crossings;
            bestX = xs[i];
            bestY = ys[j];
            if (crossings == 0) break;
          }
        }
        if (bestScore == 0) break;
      }
    }

    final x = _snapValue(bestX + offset(firstIsHorizontal ? 0 : 1));
    final y = _snapValue(bestY + offset(firstIsHorizontal ? 1 : 0));
    final points = shapeOf(x, y);

    handles
      ..add(
        WireHandle(
          offsetIndex: firstIsHorizontal ? 0 : 1,
          moveAxis: WireAxis.horizontal,
          start: points[firstIsHorizontal ? 2 : 3],
          end: points[firstIsHorizontal ? 3 : 4],
        ),
      )
      ..add(
        WireHandle(
          offsetIndex: firstIsHorizontal ? 1 : 0,
          moveAxis: WireAxis.vertical,
          start: points[firstIsHorizontal ? 3 : 2],
          end: points[firstIsHorizontal ? 4 : 3],
        ),
      );

    return WireRoute(points: _simplify(points), handles: handles);
  }

  /// Picks the value that puts a route through fewest symbols.
  ///
  /// Ties go to the earliest candidate, and the caller puts the route it
  /// would have drawn anyway first — so avoiding an obstacle never changes
  /// a wire that was not hitting one.
  static double _clearest({
    required List<double> Function() candidates,
    required List<Offset> Function(double) shape,
    required List<Rect> obstacles,
    required double fallback,
  }) {
    if (obstacles.isEmpty) return fallback;

    var best = fallback;
    var bestScore = -1;
    for (final candidate in candidates()) {
      final crossings = _crossings(shape(candidate), obstacles);
      if (bestScore < 0 || crossings < bestScore) {
        bestScore = crossings;
        best = candidate;
        if (crossings == 0) break;
      }
    }
    return best;
  }

  /// The obstacles a given route actually runs through.
  ///
  /// Candidate positions are derived from these alone. A sheet with fifty
  /// symbols on it would otherwise generate a hundred candidates per axis
  /// and ten thousand routes to score, for a wire that is nowhere near any
  /// of them.
  static List<Rect> _blockers(List<Offset> points, List<Rect> obstacles) => [
    for (final obstacle in obstacles)
      if (_crossings(points, [obstacle]) > 0) obstacle,
  ];

  /// Just outside each obstacle, on the given axis — where a wire has to be
  /// to clear it.
  static List<double> _sidesOf(
    List<Rect> obstacles, {
    required bool horizontal,
  }) => [
    for (final obstacle in obstacles) ...[
      if (horizontal) obstacle.left - gridMm else obstacle.top - gridMm,
      if (horizontal) obstacle.right + gridMm else obstacle.bottom + gridMm,
    ],
  ];

  /// How many obstacle interiors a route passes through.
  static int _crossings(List<Offset> points, List<Rect> obstacles) {
    var count = 0;
    for (var i = 0; i < points.length - 1; i++) {
      for (final obstacle in obstacles) {
        if (_segmentCrossesRect(points[i], points[i + 1], obstacle)) count++;
      }
    }
    return count;
  }

  /// Whether an axis-aligned segment passes through [rect].
  ///
  /// Only the interior counts: a wire running along an edge, which is what
  /// happens where it meets the symbol it belongs to, is not a crossing.
  static bool _segmentCrossesRect(Offset a, Offset b, Rect rect) {
    final left = math.min(a.dx, b.dx);
    final right = math.max(a.dx, b.dx);
    final top = math.min(a.dy, b.dy);
    final bottom = math.max(a.dy, b.dy);

    const epsilon = 1e-6;
    return left < rect.right - epsilon &&
        right > rect.left + epsilon &&
        top < rect.bottom - epsilon &&
        bottom > rect.top + epsilon;
  }

  /// Drops points that repeat or sit in the middle of a straight run, which
  /// is what makes a wire the user has straightened actually look straight.
  static List<Offset> _simplify(List<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isNotEmpty && (result.last - point).distance < 1e-6) {
        continue;
      }
      result.add(point);
    }
    if (result.length < 3) return result;

    final simplified = <Offset>[result.first];
    for (var i = 1; i < result.length - 1; i++) {
      final previous = simplified.last;
      final next = result[i + 1];
      final collinearX =
          (previous.dx - result[i].dx).abs() < 1e-6 &&
          (result[i].dx - next.dx).abs() < 1e-6;
      final collinearY =
          (previous.dy - result[i].dy).abs() < 1e-6 &&
          (result[i].dy - next.dy).abs() < 1e-6;
      if (collinearX || collinearY) continue;
      simplified.add(result[i]);
    }
    simplified.add(result.last);
    return simplified;
  }

  /// Where the wire stops running straight out of a pin and may turn.
  ///
  /// Only the direction of travel is snapped to the grid. Snapping both
  /// coordinates would shift the stub off the pin's own axis whenever the
  /// pin does not sit on a grid line, which turns the very first segment
  /// into a diagonal — the thing this router exists to avoid.
  static Offset _stubEnd(Offset pin, Offset exit) {
    final horizontal = exit.dx.abs() > exit.dy.abs();
    if (horizontal) {
      final direction = exit.dx.isNegative ? -1 : 1;
      var x = _snapValue(pin.dx + direction * stubMm);
      if ((x - pin.dx) * direction <= 0) x += direction * gridMm;
      return Offset(x, pin.dy);
    }
    final direction = exit.dy.isNegative ? -1 : 1;
    var y = _snapValue(pin.dy + direction * stubMm);
    if ((y - pin.dy) * direction <= 0) y += direction * gridMm;
    return Offset(pin.dx, y);
  }

  static double _snapValue(double value) => (value / gridMm).round() * gridMm;
}
