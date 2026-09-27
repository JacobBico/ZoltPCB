import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_scene.dart';
import 'footprint.dart';

/// The ground a footprint claims on one side of the board.
///
/// A courtyard is the outline its author drew to say "nothing else goes
/// here" — room for the body, the solder fillet and the nozzle that places
/// it. Two that overlap are two parts that cannot both be fitted, however
/// clear their copper is of one another.
class Courtyard {
  const Courtyard({
    required this.footprint,
    required this.back,
    required this.outlines,
    this.drawn = true,
  });

  final PlacedFootprint footprint;

  /// On the underside: only courtyards on the same side can collide.
  final bool back;

  /// Closed outlines, in board millimetres. Usually one rectangle; an
  /// L-shaped connector may draw its courtyard as two.
  final List<List<Offset>> outlines;

  /// Whether the footprint's author actually drew this, or it is the body
  /// of the part standing in for a courtyard nobody drew.
  final bool drawn;

  String get reference => footprint.part.reference;

  Rect get bounds {
    var rect = Rect.fromPoints(outlines.first.first, outlines.first.first);
    for (final outline in outlines) {
      for (final p in outline) {
        rect = rect.expandToInclude(Rect.fromPoints(p, p));
      }
    }
    return rect;
  }

  /// Whether this and [other] claim some of the same ground.
  ///
  /// Touching is allowed — two parts butted edge to edge is how a tight
  /// board is laid out, and exactly what the courtyards were drawn for.
  bool overlaps(Courtyard other) {
    if (other.back != back) return false;
    if (!bounds.overlaps(other.bounds)) return false;
    for (final a in outlines) {
      for (final b in other.outlines) {
        if (polygonsOverlap(a, b)) return true;
      }
    }
    return false;
  }

  /// The courtyards of every placed footprint that has one.
  static List<Courtyard> of(BoardScene scene) => [
    for (final footprint in scene.footprints) ...forFootprint(footprint),
  ];

  /// The ground every placed part claims, whether or not its author drew a
  /// courtyard.
  ///
  /// A footprint with no courtyard on it falls back to the box round its
  /// body. That is not what a fabricator means by a courtyard and it is not
  /// what the rule check treats as one — but a part with no courtyard drawn
  /// is otherwise a part that can be dropped straight on top of another
  /// with nothing said, and plenty of hand-made footprints have no
  /// courtyard on them.
  static List<Courtyard> claims(BoardScene scene) => [
    for (final footprint in scene.footprints)
      if (forFootprint(footprint) case final drawn when drawn.isNotEmpty)
        ...drawn
      else
        Courtyard(
          footprint: footprint,
          back: footprint.ref.flipped,
          drawn: false,
          outlines: [
            [
              footprint.bounds.topLeft,
              footprint.bounds.topRight,
              footprint.bounds.bottomRight,
              footprint.bounds.bottomLeft,
            ],
          ],
        ),
  ];

  /// Which of those claims are on ground another part has already claimed.
  ///
  /// What the board draws in red while a part is being moved: the answer
  /// has to be there before the part is put down, not afterwards in a
  /// rule check.
  static List<Courtyard> collisions(BoardScene scene) {
    final claimed = claims(scene);
    final hit = <int>{};
    for (var i = 0; i < claimed.length; i++) {
      for (var j = i + 1; j < claimed.length; j++) {
        if (claimed[i].footprint.ref.id == claimed[j].footprint.ref.id) {
          continue;
        }
        if (!claimed[i].overlaps(claimed[j])) continue;
        hit
          ..add(i)
          ..add(j);
      }
    }
    return [for (final i in hit.toList()..sort()) claimed[i]];
  }

  static List<Courtyard> forFootprint(PlacedFootprint footprint) {
    final definition = footprint.definition;
    if (definition == null) return const [];
    final placement = footprint.placement;

    final front = <List<Offset>>[];
    final back = <List<Offset>>[];
    final frontLines = <(Offset, Offset)>[];
    final backLines = <(Offset, Offset)>[];

    Offset at(FootprintPoint p) => placement.applyPoint(p);

    for (final graphic in definition.graphics) {
      final layer = placement.layerOf(graphic.layer);
      final bool isBack;
      if (layer == BoardLayer.frontCourtyard) {
        isBack = false;
      } else if (layer == BoardLayer.backCourtyard) {
        isBack = true;
      } else {
        continue;
      }
      final shapes = isBack ? back : front;
      final lines = isBack ? backLines : frontLines;

      switch (graphic) {
        case FootprintRect(:final start, :final end):
          shapes.add([
            at(start),
            at(FootprintPoint(end.x, start.y)),
            at(end),
            at(FootprintPoint(start.x, end.y)),
          ]);
        case FootprintPolygon(:final points):
          if (points.length >= 3) shapes.add([for (final p in points) at(p)]);
        case FootprintCircle(:final center):
          final r = graphic.radius;
          shapes.add([
            for (var i = 0; i < 24; i++)
              at(
                FootprintPoint(
                  center.x + r * math.cos(i * math.pi / 12),
                  center.y + r * math.sin(i * math.pi / 12),
                ),
              ),
          ]);
        case FootprintLine(:final start, :final end):
          lines.add((at(start), at(end)));
        case FootprintText():
          break;
        case FootprintArc(:final start, :final mid, :final end):
          lines
            ..add((at(start), at(mid)))
            ..add((at(mid), at(end)));
      }
    }

    front.addAll(_loops(frontLines));
    back.addAll(_loops(backLines));
    return [
      if (front.isNotEmpty)
        Courtyard(footprint: footprint, back: false, outlines: front),
      if (back.isNotEmpty)
        Courtyard(footprint: footprint, back: true, outlines: back),
    ];
  }

  /// Chains loose line segments into closed outlines. A chain that never
  /// closes — a courtyard drawn with a gap in it — is closed by its convex
  /// hull, which claims a little more ground than was drawn rather than
  /// losing the courtyard altogether.
  static List<List<Offset>> _loops(List<(Offset, Offset)> lines) {
    const touch = 0.001;
    final remaining = [...lines];
    final loops = <List<Offset>>[];
    while (remaining.isNotEmpty) {
      final first = remaining.removeAt(0);
      final chain = [first.$1, first.$2];
      var extended = true;
      while (extended && (chain.first - chain.last).distance > touch) {
        extended = false;
        for (var i = 0; i < remaining.length; i++) {
          final (a, b) = remaining[i];
          if ((a - chain.last).distance <= touch) {
            chain.add(b);
          } else if ((b - chain.last).distance <= touch) {
            chain.add(a);
          } else if ((b - chain.first).distance <= touch) {
            chain.insert(0, a);
          } else if ((a - chain.first).distance <= touch) {
            chain.insert(0, b);
          } else {
            continue;
          }
          remaining.removeAt(i);
          extended = true;
          break;
        }
      }
      final closed = (chain.first - chain.last).distance <= touch;
      if (closed) {
        chain.removeLast();
        if (chain.length >= 3) loops.add(chain);
      } else if (chain.length >= 3) {
        loops.add(convexHull(chain));
      }
    }
    return loops;
  }
}

/// Whether two simple polygons share any area.
///
/// Measured, not guessed from edges: both are cut into triangles and every
/// pair clipped against one another, and any clipped area beyond a speck
/// is an overlap. Edges that touch or run along one another — two parts
/// butted together — enclose no area and so do not count, and two parts
/// the same height overlapping by a hair, whose edges are collinear and
/// never cross, still do.
bool polygonsOverlap(List<Offset> a, List<Offset> b) {
  final ta = _triangulate(a);
  final tb = _triangulate(b);
  for (final x in ta) {
    final bx = _box(x);
    for (final y in tb) {
      if (!bx.overlaps(_box(y))) continue;
      if (_area(_clip(x, y)) > 1e-6) return true;
    }
  }
  return false;
}

Rect _box(List<Offset> points) {
  var rect = Rect.fromPoints(points.first, points.first);
  for (final p in points) {
    rect = rect.expandToInclude(Rect.fromPoints(p, p));
  }
  return rect;
}

double _signedArea(List<Offset> polygon) {
  var twice = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    twice += a.dx * b.dy - b.dx * a.dy;
  }
  return twice / 2;
}

double _area(List<Offset> polygon) =>
    polygon.length < 3 ? 0 : _signedArea(polygon).abs();

double _cross(Offset o, Offset a, Offset b) =>
    (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

/// Ear-clipping triangulation of a simple polygon. Falls back to the
/// convex hull if the outline is not simple, which claims a little more
/// ground rather than none.
List<List<Offset>> _triangulate(List<Offset> polygon) {
  var points = [...polygon];
  if (_signedArea(points) < 0) points = points.reversed.toList();
  // Collinear corners are not corners, and they stall the ear search.
  points = [
    for (var i = 0; i < points.length; i++)
      if (_cross(
            points[(i - 1 + points.length) % points.length],
            points[i],
            points[(i + 1) % points.length],
          ).abs() >
          1e-12)
        points[i],
  ];
  if (points.length < 3) return const [];

  final triangles = <List<Offset>>[];
  var guard = 0;
  while (points.length > 3 && guard++ < 10000) {
    var clipped = false;
    for (var i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final here = points[i];
      final next = points[(i + 1) % points.length];
      if (_cross(prev, here, next) <= 0) continue;
      final ear = [prev, here, next];
      var empty = true;
      for (final p in points) {
        if (p == prev || p == here || p == next) continue;
        if (_inTriangle(p, ear)) {
          empty = false;
          break;
        }
      }
      if (!empty) continue;
      triangles.add(ear);
      points.removeAt(i);
      clipped = true;
      break;
    }
    if (!clipped) return _triangulate(convexHull(polygon));
  }
  triangles.add(points);
  return triangles;
}

bool _inTriangle(Offset p, List<Offset> t) =>
    _cross(t[0], t[1], p) >= 0 &&
    _cross(t[1], t[2], p) >= 0 &&
    _cross(t[2], t[0], p) >= 0;

/// Sutherland–Hodgman: [subject] clipped to the convex, anticlockwise
/// [clip].
List<Offset> _clip(List<Offset> subject, List<Offset> clip) {
  var output = subject;
  for (var i = 0; i < clip.length && output.isNotEmpty; i++) {
    final a = clip[i];
    final b = clip[(i + 1) % clip.length];
    final input = output;
    output = [];
    for (var j = 0; j < input.length; j++) {
      final p = input[j];
      final q = input[(j + 1) % input.length];
      final pIn = _cross(a, b, p) >= 0;
      final qIn = _cross(a, b, q) >= 0;
      if (pIn) output.add(p);
      if (pIn != qIn) {
        final d1 = _cross(a, b, p);
        final d2 = _cross(a, b, q);
        output.add(p + (q - p) * (d1 / (d1 - d2)));
      }
    }
  }
  return output;
}

/// The convex hull of [points], anticlockwise. Andrew's monotone chain.
List<Offset> convexHull(List<Offset> points) {
  final sorted = [
    ...points,
  ]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  if (sorted.length < 3) return sorted;
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final lower = <Offset>[];
  for (final p in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <Offset>[];
  for (final p in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  return [...lower..removeLast(), ...upper..removeLast()];
}
