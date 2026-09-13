import 'dart:math' as math;
import 'dart:ui';

/// The shapes an extra edge-cut can take.
///
/// These sit alongside the board outline rather than replacing it: the
/// outline says how big the board is and what "off the board" means, and
/// these are the slots, notches, rounded corners and cutouts a design needs
/// on top of that.
enum BoardEdgeKind {
  line('Line', 2),
  arc('Arc', 3),
  rectangle('Rectangle', 2),
  circle('Circle', 2),
  polygon('Polygon', 3);

  const BoardEdgeKind(this.label, this.minimumPoints);

  final String label;

  /// How many points the shape needs before it means anything.
  final int minimumPoints;
}

/// One shape on the Edge.Cuts layer.
///
/// Every kind is stored as a list of points, because that is what they all
/// are: a line is two, an arc is a start, a point it passes through and an
/// end — the same three KiCad writes — a rectangle is two opposite corners,
/// a circle is a centre and a point on it, and a polygon is as many as it
/// takes. One column, no per-shape schema.
class BoardEdge {
  const BoardEdge({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.points,
    this.width = 0.1,
  });

  final String id;
  final String projectId;
  final BoardEdgeKind kind;

  /// Vertices in board millimetres. See the class comment for what each
  /// kind reads into them.
  final List<Offset> points;

  /// Line width in millimetres. Edge cuts are a cut line, not a feature
  /// with a width, but KiCad still carries one and 0.1 is its default.
  final double width;

  bool get isValid => points.length >= kind.minimumPoints;

  Offset get start => points.first;
  Offset get end => points.last;

  /// An arc's middle point — the one it passes through.
  Offset get mid => points.length >= 3 ? points[1] : _midpointOf(start, end);

  /// A circle's centre, and the radius taken from its second point.
  Offset get center => switch (kind) {
    BoardEdgeKind.circle => points.first,
    BoardEdgeKind.rectangle => bounds.center,
    _ => bounds.center,
  };

  double get radius => kind == BoardEdgeKind.circle && points.length >= 2
      ? (points[1] - points[0]).distance
      : math.min(bounds.width, bounds.height) / 2;

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    if (kind == BoardEdgeKind.circle && points.length >= 2) {
      final r = (points[1] - points[0]).distance;
      return Rect.fromCircle(center: points.first, radius: r);
    }
    var rect = Rect.fromPoints(points.first, points.first);
    for (final point in points.skip(1)) {
      rect = rect.expandToInclude(Rect.fromPoints(point, point));
    }
    return rect;
  }

  /// The shape as something drawable.
  Path get path {
    final path = Path();
    if (points.isEmpty) return path;

    switch (kind) {
      case BoardEdgeKind.line:
        if (points.length < 2) return path;
        path
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);
      case BoardEdgeKind.arc:
        return arcPath;
      case BoardEdgeKind.rectangle:
        if (points.length < 2) return path;
        path.addRect(Rect.fromPoints(points[0], points[1]));
      case BoardEdgeKind.circle:
        path.addOval(Rect.fromCircle(center: center, radius: radius));
      case BoardEdgeKind.polygon:
        path.moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        path.close();
    }
    return path;
  }

  /// An arc through its three points.
  ///
  /// Flutter draws arcs from a bounding box and two angles, and KiCad
  /// stores three points, so the circle through them has to be recovered
  /// first. Three points in a straight line have no circle — the
  /// circumcentre runs off to infinity — and that case degenerates to the
  /// chord, which is both correct and what the user drew.
  Path get arcPath {
    final path = Path();
    if (points.length < 3) {
      if (points.length == 2) {
        path
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);
      }
      return path;
    }

    final centre = circumcentre(start, mid, end);
    if (centre == null) {
      path
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy);
      return path;
    }

    final r = (start - centre).distance;
    final a0 = math.atan2(start.dy - centre.dy, start.dx - centre.dx);
    final a1 = math.atan2(mid.dy - centre.dy, mid.dx - centre.dx);
    final a2 = math.atan2(end.dy - centre.dy, end.dx - centre.dx);

    // Sweep from start to end the way round that actually passes through
    // the middle point. Taking the short way every time turns a
    // three-quarter arc inside out.
    var sweep = a2 - a0;
    while (sweep <= -math.pi * 2) {
      sweep += math.pi * 2;
    }
    while (sweep > math.pi * 2) {
      sweep -= math.pi * 2;
    }
    if (!_between(a0, a1, a0 + sweep)) {
      sweep += sweep > 0 ? -math.pi * 2 : math.pi * 2;
    }

    path.addArc(Rect.fromCircle(center: centre, radius: r), a0, sweep);
    return path;
  }

  /// The centre of the circle through three points, or null when they are
  /// collinear.
  static Offset? circumcentre(Offset a, Offset b, Offset c) {
    final d =
        2 *
        (a.dx * (b.dy - c.dy) + b.dx * (c.dy - a.dy) + c.dx * (a.dy - b.dy));
    if (d.abs() < 1e-9) return null;

    final a2 = a.dx * a.dx + a.dy * a.dy;
    final b2 = b.dx * b.dx + b.dy * b.dy;
    final c2 = c.dx * c.dx + c.dy * c.dy;

    return Offset(
      (a2 * (b.dy - c.dy) + b2 * (c.dy - a.dy) + c2 * (a.dy - b.dy)) / d,
      (a2 * (c.dx - b.dx) + b2 * (a.dx - c.dx) + c2 * (b.dx - a.dx)) / d,
    );
  }

  /// Whether sweeping from [from] to [to] passes [angle].
  static bool _between(double from, double angle, double to) {
    double normalise(double value) {
      var v = value;
      while (v < 0) {
        v += math.pi * 2;
      }
      while (v >= math.pi * 2) {
        v -= math.pi * 2;
      }
      return v;
    }

    final span = to - from;
    final offset = normalise(span > 0 ? angle - from : from - angle);
    return offset <= span.abs() + 1e-9;
  }

  static Offset _midpointOf(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  /// Shortest distance from [point] to the drawn shape, for hit-testing.
  double distanceTo(Offset point) {
    switch (kind) {
      case BoardEdgeKind.line:
        if (points.length < 2) return (point - start).distance;
        return _distanceToSegment(point, start, end);
      case BoardEdgeKind.circle:
        return ((point - center).distance - radius).abs();
      case BoardEdgeKind.arc:
        final centre = points.length >= 3
            ? circumcentre(start, mid, end)
            : null;
        if (centre == null) return _distanceToSegment(point, start, end);
        // Close enough: distance to the full circle. An arc's ends are the
        // only place this flatters, and by less than a fingertip.
        return ((point - centre).distance - (start - centre).distance).abs();
      case BoardEdgeKind.rectangle:
      case BoardEdgeKind.polygon:
        final corners = kind == BoardEdgeKind.rectangle
            ? [
                bounds.topLeft,
                bounds.topRight,
                bounds.bottomRight,
                bounds.bottomLeft,
              ]
            : points;
        var best = double.infinity;
        for (var i = 0; i < corners.length; i++) {
          final a = corners[i];
          final b = corners[(i + 1) % corners.length];
          final d = _distanceToSegment(point, a, b);
          if (d < best) best = d;
        }
        return best;
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-12) return (p - a).distance;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  BoardEdge copyWith({
    BoardEdgeKind? kind,
    List<Offset>? points,
    double? width,
  }) => BoardEdge(
    id: id,
    projectId: projectId,
    kind: kind ?? this.kind,
    points: points ?? this.points,
    width: width ?? this.width,
  );

  /// A human description, for the list of edge cuts.
  String get summary => switch (kind) {
    BoardEdgeKind.line =>
      '(${_mm(start.dx)}, ${_mm(start.dy)}) → '
          '(${_mm(end.dx)}, ${_mm(end.dy)})',
    BoardEdgeKind.arc =>
      '(${_mm(start.dx)}, ${_mm(start.dy)}) → '
          '(${_mm(end.dx)}, ${_mm(end.dy)})',
    BoardEdgeKind.rectangle =>
      '${_mm(bounds.width)} × ${_mm(bounds.height)} mm',
    BoardEdgeKind.circle => '⌀${_mm(radius * 2)} mm',
    BoardEdgeKind.polygon => '${points.length} points',
  };

  static String _mm(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  String toString() => 'BoardEdge(${kind.name}, ${points.length} points)';
}
