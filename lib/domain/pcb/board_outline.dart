import 'dart:math' as math;
import 'dart:ui';

/// The shapes a board edge can take.
enum BoardOutlineKind {
  rectangle('Rectangle'),
  circle('Circle'),
  polygon('Polygon');

  const BoardOutlineKind(this.label);

  final String label;
}

/// The board's edge — what gets milled, and what everything has to fit
/// inside.
///
/// A rectangle covers most boards and is the only shape worth editing by
/// dragging two numbers, so it stays its own case rather than a four-point
/// polygon. Circles are common enough (anything that mounts on a round
/// standoff) to deserve their own handles. Everything else is a polygon,
/// which is the general answer: a triangle, an L, a cut corner.
class BoardOutline {
  const BoardOutline({
    required this.kind,
    required this.rect,
    this.points = const [],
  });

  /// The default: a plain rectangle.
  factory BoardOutline.rectangle(Rect rect) =>
      BoardOutline(kind: BoardOutlineKind.rectangle, rect: rect);

  /// A circle inscribed in [rect], which is how one is stored: the centre
  /// and radius come from the same four numbers a rectangle uses, so an
  /// outline never needs a second set of columns.
  factory BoardOutline.circle(Rect rect) =>
      BoardOutline(kind: BoardOutlineKind.circle, rect: rect);

  factory BoardOutline.polygon(List<Offset> points) => BoardOutline(
    kind: BoardOutlineKind.polygon,
    rect: _boundsOf(points),
    points: points,
  );

  final BoardOutlineKind kind;

  /// The bounding box. Authoritative for a rectangle, and for a circle it
  /// is the square the circle is drawn inside; for a polygon it is derived
  /// from the points and kept only so the view can be framed.
  final Rect rect;

  /// Polygon vertices, in order. Empty for the other kinds.
  final List<Offset> points;

  Offset get center => rect.center;

  /// A circle's radius: half of the shorter side, so it always fits.
  double get radius => math.min(rect.width, rect.height) / 2;

  /// The bounding box of whatever shape this is.
  Rect get bounds => kind == BoardOutlineKind.circle
      ? Rect.fromCircle(center: center, radius: radius)
      : rect;

  /// The outline as a closed run of points.
  ///
  /// A circle is approximated, because a board edge made of line segments
  /// is what a fabricator's milling path is anyway — but the export writes
  /// a real arc rather than this, so the approximation never leaves the
  /// screen.
  List<Offset> get path => switch (kind) {
    BoardOutlineKind.rectangle => [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ],
    BoardOutlineKind.polygon => points,
    BoardOutlineKind.circle => [
      for (var i = 0; i < 64; i++)
        Offset(
          center.dx + radius * math.cos(i * 2 * math.pi / 64),
          center.dy + radius * math.sin(i * 2 * math.pi / 64),
        ),
    ],
  };

  /// The points a finger can take hold of.
  ///
  /// A circle gets two: the centre moves it, the edge resizes it. Anything
  /// else is its own corners.
  List<Offset> get handles => switch (kind) {
    BoardOutlineKind.circle => [center, center + Offset(radius, 0)],
    _ => path,
  };

  /// Whether [point] is on the board.
  bool contains(Offset point) => switch (kind) {
    BoardOutlineKind.rectangle => rect.contains(point),
    BoardOutlineKind.circle => (point - center).distance <= radius,
    BoardOutlineKind.polygon => _polygonContains(points, point),
  };

  /// The same shape with one handle moved.
  BoardOutline withHandleAt(int index, Offset to, {double minimum = 1.0}) {
    switch (kind) {
      case BoardOutlineKind.circle:
        if (index == 0) {
          return BoardOutline.circle(
            Rect.fromCircle(center: to, radius: radius),
          );
        }
        return BoardOutline.circle(
          Rect.fromCircle(
            center: center,
            radius: math.max(minimum, (to - center).distance),
          ),
        );

      case BoardOutlineKind.rectangle:
        // The opposite corner stays put, so a drag resizes rather than
        // moves — which is what a corner grip means everywhere else.
        final fixed = switch (index) {
          0 => rect.bottomRight,
          1 => rect.bottomLeft,
          2 => rect.topLeft,
          _ => rect.topRight,
        };
        final width = math.max(minimum, (to.dx - fixed.dx).abs());
        final height = math.max(minimum, (to.dy - fixed.dy).abs());
        return BoardOutline.rectangle(
          Rect.fromLTWH(
            to.dx < fixed.dx ? fixed.dx - width : fixed.dx,
            to.dy < fixed.dy ? fixed.dy - height : fixed.dy,
            width,
            height,
          ),
        );

      case BoardOutlineKind.polygon:
        if (index < 0 || index >= points.length) return this;
        return BoardOutline.polygon([
          for (var i = 0; i < points.length; i++)
            if (i == index) to else points[i],
        ]);
    }
  }

  /// A polygon with a vertex added on the edge after [index].
  BoardOutline withPointAfter(int index) {
    final source = kind == BoardOutlineKind.polygon ? points : path;
    if (source.length < 3) return this;
    final next = (index + 1) % source.length;
    return BoardOutline.polygon([
      for (var i = 0; i < source.length; i++) ...[
        source[i],
        if (i == index) Offset.lerp(source[index], source[next], 0.5)!,
      ],
    ]);
  }

  /// A polygon with one vertex removed. A triangle is the floor: below three
  /// points there is no shape left.
  BoardOutline withoutPoint(int index) {
    if (kind != BoardOutlineKind.polygon || points.length <= 3) return this;
    return BoardOutline.polygon([
      for (var i = 0; i < points.length; i++)
        if (i != index) points[i],
    ]);
  }

  /// This shape converted to [next], keeping roughly the same area so the
  /// board does not jump when the kind changes.
  BoardOutline as(BoardOutlineKind next) {
    if (next == kind) return this;
    return switch (next) {
      BoardOutlineKind.rectangle => BoardOutline.rectangle(bounds),
      BoardOutlineKind.circle => BoardOutline.circle(bounds),
      BoardOutlineKind.polygon => BoardOutline.polygon(
        kind == BoardOutlineKind.circle
            // Six points rather than sixty-four: a polygon is meant to be
            // dragged, and a circle's worth of handles cannot be.
            ? [
                for (var i = 0; i < 6; i++)
                  Offset(
                    center.dx + radius * math.cos(i * math.pi / 3),
                    center.dy + radius * math.sin(i * math.pi / 3),
                  ),
              ]
            : path,
      ),
    };
  }

  static Rect _boundsOf(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    var rect = Rect.fromLTWH(points.first.dx, points.first.dy, 0, 0);
    for (final point in points.skip(1)) {
      rect = rect.expandToInclude(Rect.fromLTWH(point.dx, point.dy, 0, 0));
    }
    return rect;
  }

  /// Ray casting, which handles the concave shapes a hand-drawn board edge
  /// tends to have.
  static bool _polygonContains(List<Offset> points, Offset point) {
    if (points.length < 3) return false;
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i];
      final b = points[j];
      final straddles = (a.dy > point.dy) != (b.dy > point.dy);
      if (!straddles) continue;
      final x = (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (point.dx < x) inside = !inside;
    }
    return inside;
  }

  @override
  bool operator ==(Object other) =>
      other is BoardOutline &&
      other.kind == kind &&
      other.rect == rect &&
      other.points.length == points.length &&
      Iterable<int>.generate(
        points.length,
      ).every((i) => other.points[i] == points[i]);

  @override
  int get hashCode => Object.hash(kind, rect, Object.hashAll(points));
}
