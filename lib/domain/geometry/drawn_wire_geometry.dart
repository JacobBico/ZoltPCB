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
  /// How far run [index] actually moves for a drag of [delta]: a run only
  /// slides across itself, never along.
  static Offset runShift(List<Offset> points, int index, Offset delta) {
    if (index < 0 || index >= points.length - 1) return Offset.zero;
    final a = points[index];
    final b = points[index + 1];
    final horizontal = (a.dy - b.dy).abs() < _eps;
    return horizontal ? Offset(0, delta.dy) : Offset(delta.dx, 0);
  }

  /// Where two segments cross, or null if they meet only at an end, touch,
  /// or miss each other entirely.
  ///
  /// Ends are deliberately left out: wires that meet at a point are joined,
  /// and it is the ones that merely pass over each other that need saying
  /// something about.
  static Offset? crossing(Offset a1, Offset a2, Offset b1, Offset b2) {
    final r = a2 - a1;
    final s = b2 - b1;
    final denominator = r.dx * s.dy - r.dy * s.dx;
    if (denominator.abs() < 1e-12) return null;
    final d = b1 - a1;
    final t = (d.dx * s.dy - d.dy * s.dx) / denominator;
    final u = (d.dx * r.dy - d.dy * r.dx) / denominator;
    const edge = 1e-6;
    if (t <= edge || t >= 1 - edge || u <= edge || u >= 1 - edge) return null;
    return a1 + Offset(r.dx * t, r.dy * t);
  }

  /// Whether [at] lies on the segment from [a] to [b].
  static bool onSegment(Offset at, Offset a, Offset b) =>
      _distanceToSegment(at, a, b) < 0.01;

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

  /// The points where wires need a junction dot.
  ///
  /// KiCad's rule, and the one that makes a drawing readable: a dot where
  /// three or more directions of wire leave the same point. Counting ends
  /// is not enough — a wire lying along another, end inside it, has three
  /// ends meeting and yet only two directions, and dotting that says the
  /// two are joined at a place where they merely overlap.
  ///
  /// A pin counts as a connection where it sits, so two wires meeting on
  /// one are dotted while a single wire reaching a pin is not.
  ///
  /// Pass the wires of a single net: wires that merely cross on their way
  /// somewhere else are not connected and must not be dotted.
  static List<Offset> junctions(
    Iterable<List<Offset>> wires, {
    Iterable<Offset> pins = const [],
  }) {
    const tolerance = 0.01;
    final paths = [
      for (final wire in wires)
        if (wire.length >= 2) wire,
    ];

    // Corners, pins, and the places two of these wires cross: wires of one
    // net that cross are joined, and a crossing with nothing to show for it
    // reads as two wires passing by.
    final crossings = <Offset>[];
    for (var i = 0; i < paths.length; i++) {
      for (var j = i + 1; j < paths.length; j++) {
        for (var a = 0; a < paths[i].length - 1; a++) {
          for (var b = 0; b < paths[j].length - 1; b++) {
            final at = crossing(
              paths[i][a],
              paths[i][a + 1],
              paths[j][b],
              paths[j][b + 1],
            );
            if (at != null) crossings.add(at);
          }
        }
      }
    }

    final candidates = <Offset>[];
    for (final point in [
      for (final path in paths) ...path,
      ...pins,
      ...crossings,
    ]) {
      if (!candidates.any((c) => (c - point).distance < tolerance)) {
        candidates.add(point);
      }
    }

    final dots = <Offset>[];
    for (final point in candidates) {
      final directions = <Offset>[];
      void leaving(Offset towards) {
        final away = towards - point;
        if (away.distance < tolerance) return;
        final unit = away / away.distance;
        if (directions.any((d) => (d - unit).distance < 1e-3)) return;
        directions.add(unit);
      }

      for (final path in paths) {
        for (var i = 0; i < path.length; i++) {
          if ((path[i] - point).distance >= tolerance) continue;
          if (i > 0) leaving(path[i - 1]);
          if (i < path.length - 1) leaving(path[i + 1]);
        }
        // Passing through, between two corners rather than at one.
        for (var i = 0; i < path.length - 1; i++) {
          if ((path[i] - point).distance < tolerance ||
              (path[i + 1] - point).distance < tolerance) {
            continue;
          }
          if (_distanceToSegment(point, path[i], path[i + 1]) < tolerance) {
            leaving(path[i]);
            leaving(path[i + 1]);
          }
        }
      }

      final onPin = pins.any((pin) => (pin - point).distance < tolerance);
      if (directions.length >= 3 || (onPin && directions.length >= 2)) {
        dots.add(point);
      }
    }
    return dots;
  }

  /// The ends of [wires] that touch nothing: no pin in [anchors], and no
  /// other wire, whether at its end, a corner or part-way along.
  ///
  /// KiCad marks these with a small square, because a wire that stops a
  /// hair short of a pin looks exactly like one that reaches it and is the
  /// most common way a schematic ends up quietly unconnected.
  static List<Offset> looseEnds(
    List<List<Offset>> wires, {
    Iterable<Offset> anchors = const [],
  }) {
    const tolerance = 0.01;
    final pins = anchors.toList();
    final loose = <Offset>[];
    for (var w = 0; w < wires.length; w++) {
      final wire = wires[w];
      if (wire.length < 2) continue;
      for (final atStart in const [true, false]) {
        final end = atStart ? wire.first : wire.last;
        if (pins.any((pin) => (pin - end).distance < tolerance)) continue;
        // The run the end belongs to reaches it by definition.
        final ownRun = atStart ? 0 : wire.length - 2;
        var touches = false;
        for (var o = 0; o < wires.length && !touches; o++) {
          final other = wires[o];
          for (var i = 0; i < other.length - 1 && !touches; i++) {
            if (o == w && i == ownRun) continue;
            touches =
                _distanceToSegment(end, other[i], other[i + 1]) < tolerance;
          }
        }
        if (!touches) loose.add(end);
      }
    }
    return loose;
  }

  /// [points] with corner [index] moved to [to], the runs on either side of
  /// it bending to keep up — the way a corner is dragged in KiCad.
  static List<Offset> moveVertex(List<Offset> points, int index, Offset to) {
    if (index < 0 || index >= points.length) return points;
    if (index == 0) return attachEnds(points, start: to);
    if (index == points.length - 1) return attachEnds(points, end: to);

    final head = attachEnds(points.sublist(0, index + 1), end: to);
    final tail = attachEnds(points.sublist(index), start: to);
    return simplify([...head, ...tail.skip(1)]);
  }

  /// [points] with a corner put in at [at], which has to lie on it, so that
  /// the place another wire meets it can then be moved.
  static List<Offset> splitAt(List<Offset> points, Offset at) {
    const tolerance = 0.01;
    for (final point in points) {
      if ((point - at).distance < tolerance) return points;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (_distanceToSegment(at, points[i], points[i + 1]) < tolerance) {
        return [...points.sublist(0, i + 1), at, ...points.sublist(i + 1)];
      }
    }
    return points;
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
