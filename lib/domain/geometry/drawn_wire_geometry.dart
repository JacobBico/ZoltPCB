import 'dart:ui';

/// Geometry for wires drawn at right angles, the schematic's answer to the
/// board's 45° tracks.
///
/// Everything works on plain corner lists so the canvas, the exporter and
/// the tests all see the same shapes.
abstract final class DrawnWireGeometry {
  static const double _eps = 1e-6;

  /// A path through [taps] made only of horizontal and vertical runs.
  ///
  /// Each step goes along first, then up or down — the corner a person
  /// makes when they draw one — so a tap that is off-axis gains a single
  /// bend rather than a diagonal.
  static List<Offset> orthogonalPath(List<Offset> taps) {
    if (taps.isEmpty) return const [];
    final points = <Offset>[taps.first];
    for (final tap in taps.skip(1)) {
      final last = points.last;
      if ((tap.dx - last.dx).abs() > _eps && (tap.dy - last.dy).abs() > _eps) {
        // Continue the way the previous run was going, so a chain of taps
        // does not zig-zag — unless that would double back over the run
        // just drawn, which folds the wire onto itself and loses the corner.
        final previous = points.length >= 2 ? points[points.length - 2] : null;
        final wasVertical =
            previous != null && (previous.dx - last.dx).abs() < _eps;
        final verticalFirst = Offset(last.dx, tap.dy);
        final horizontalFirst = Offset(tap.dx, last.dy);
        bool reverses(Offset bend) {
          if (previous == null) return false;
          final came = last - previous;
          final going = bend - last;
          return came.dx * going.dx + came.dy * going.dy < -_eps;
        }

        final preferred = wasVertical ? verticalFirst : horizontalFirst;
        final other = wasVertical ? horizontalFirst : verticalFirst;
        points.add(reverses(preferred) ? other : preferred);
      }
      points.add(tap);
    }
    return simplify(points);
  }

  /// [points] with its first and last corners moved to [start] and [end],
  /// still at right angles.
  ///
  /// This is what makes a drawn wire follow a part. The run next to the
  /// moved end keeps its direction: its far corner shifts with it, so the
  /// wire bends where it already bent instead of going diagonal.
  static List<Offset> attachEnds(
    List<Offset> points, {
    Offset? start,
    Offset? end,
  }) {
    if (points.length < 2) return points;
    var result = List<Offset>.from(points);
    if (start != null) result = _moveEnd(result, start);
    if (end != null) {
      result = _moveEnd(result.reversed.toList(), end).reversed.toList();
    }
    return simplify(result);
  }

  static List<Offset> _moveEnd(List<Offset> points, Offset to) {
    final first = points[0];
    if ((first - to).distance < _eps) return points;
    final second = points[1];
    final horizontal = (first.dy - second.dy).abs() < _eps;
    final vertical = (first.dx - second.dx).abs() < _eps;

    if (points.length == 2) {
      // A single straight run can only stay straight if the ends line up;
      // otherwise it gains a corner.
      final other = points[1];
      if ((to.dx - other.dx).abs() < _eps || (to.dy - other.dy).abs() < _eps) {
        return [to, other];
      }
      return horizontal
          ? [to, Offset(other.dx, to.dy), other]
          : [to, Offset(to.dx, other.dy), other];
    }

    final moved = List<Offset>.from(points);
    moved[0] = to;
    if (horizontal) {
      moved[1] = Offset(second.dx, to.dy);
    } else if (vertical) {
      moved[1] = Offset(to.dx, second.dy);
    } else {
      moved.insert(1, Offset(second.dx, to.dy));
    }
    return moved;
  }

  /// Slides run [index] (between corners index and index + 1) sideways by
  /// [delta], keeping every angle square.
  ///
  /// A run touching an end cannot take that end with it — the end is on a
  /// pin — so a short stub is added to hold the end where it is. That is
  /// what KiCad does when a wire's last run is dragged.
  /// An end of the wire that is anchored stays where it is and the wire
  /// bends to reach it; one that is carried travels with the run. A wire
  /// end sitting on a pin is anchored — dragging the wire must not quietly
  /// pull it off the pin — while a loose end is carried, so a wire left
  /// hanging can be dragged onto a pin.
  static List<Offset> slideRun(
    List<Offset> points,
    int index,
    Offset delta, {
    bool carryStart = false,
    bool carryEnd = false,
  }) {
    if (index < 0 || index >= points.length - 1) return points;
    final a = points[index];
    final b = points[index + 1];
    final horizontal = (a.dy - b.dy).abs() < _eps;
    final shift = horizontal ? Offset(0, delta.dy) : Offset(delta.dx, 0);
    if (shift.distance < _eps) return points;

    final result = List<Offset>.from(points);
    result[index] = a + shift;
    result[index + 1] = b + shift;
    if (index + 1 == points.length - 1 && !carryEnd) result.add(b);
    if (index == 0 && !carryStart) result.insert(0, a);
    return simplify(result);
  }

  /// Drops repeated corners and corners in the middle of a straight run.
  static List<Offset> simplify(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      if (out.isNotEmpty && (out.last - p).distance < _eps) continue;
      if (out.length >= 2) {
        final a = out[out.length - 2];
        final b = out.last;
        final collinear =
            ((a.dx - b.dx).abs() < _eps && (b.dx - p.dx).abs() < _eps) ||
            ((a.dy - b.dy).abs() < _eps && (b.dy - p.dy).abs() < _eps);
        if (collinear) {
          out[out.length - 1] = p;
          continue;
        }
      }
      out.add(p);
    }
    return out;
  }

  /// The run of [points] nearest [at], and how far away it is.
  static (int, double) nearestRun(List<Offset> points, Offset at) {
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegment(at, points[i], points[i + 1]);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return (best, bestDistance);
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
}
