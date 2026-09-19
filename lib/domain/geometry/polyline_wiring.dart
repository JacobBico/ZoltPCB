import 'dart:ui';

import 'drawn_wire_geometry.dart';

/// A wire as the classic model holds it: a chain of corners, with the pins
/// its two ends sit on, when they sit on any.
class PolylineWire {
  const PolylineWire({
    required this.id,
    required this.points,
    this.pinA,
    this.pinB,
  });

  final String id;
  final List<Offset> points;
  final String? pinA;
  final String? pinB;

  bool get startPinned => (pinA ?? '').isNotEmpty;
  bool get endPinned => (pinB ?? '').isNotEmpty;

  @override
  String toString() => 'PolylineWire($id, $points)';
}

/// What a drag comes to: where the wire being dragged goes, and where the
/// wires joined to it have to go to stay joined.
class WiringDrag {
  const WiringDrag({required this.dragged, required this.followers});

  final List<Offset> dragged;

  /// The other wires that have to move, by id.
  final Map<String, List<Offset>> followers;
}

/// Dragging in the classic model, where a wire is a chain of corners and
/// what it touches has to be worked out as it moves.
///
/// Everything a drag has to know is here rather than in the canvas, so the
/// cases can be run through in bulk: a wire meeting the one being dragged
/// end-on, at a corner, part-way along it, or carried off the end of it.
class PolylineWiring {
  const PolylineWiring._();

  static const double tolerance = 0.01;

  /// The net after the run [run] of wire [id] is dragged by [delta].
  ///
  /// A drag that would tear the drawing apart — pulling a wire off the end
  /// of one that cannot stretch after it, because a pin holds it — is held
  /// at the last place where everything is still joined. The wire stops
  /// rather than the net quietly coming apart.
  ///
  /// "Joined" is judged against how the net stood before the drag: a net
  /// already in more than one piece — a wire cut loose, pieces joined only
  /// by a label — can still be dragged, as long as the drag does not break
  /// it into more.
  static WiringDrag drag(
    List<PolylineWire> net,
    String id,
    int run,
    Offset delta, {
    double grid = 1.27,
  }) {
    final before = pieceCount([for (final wire in net) wire.points]);
    final fixed = junctionsOf(net);
    var tried = delta;
    for (var attempt = 0; attempt < 40; attempt++) {
      final result = _dragOnce(net, id, run, tried, fixed);
      final shapes = [
        for (final wire in net)
          if (wire.id == id)
            result.dragged
          else
            result.followers[wire.id] ?? wire.points,
      ];
      if (pieceCount(shapes) <= before) return result;

      final length = tried.distance;
      if (length <= grid) break;
      tried = tried * ((length - grid) / length);
    }
    return const WiringDrag(dragged: [], followers: {});
  }

  /// The junctions of [net]: every point where three or more directions of
  /// wire meet, or two meet on a pin. These never move in a drag.
  static List<Offset> junctionsOf(List<PolylineWire> net) =>
      DrawnWireGeometry.junctions(
        [for (final wire in net) wire.points],
        pins: [
          for (final wire in net) ...[
            if (wire.startPinned) wire.points.first,
            if (wire.endPinned) wire.points.last,
          ],
        ],
      );

  static WiringDrag _dragOnce(
    List<PolylineWire> net,
    String id,
    int run,
    Offset delta,
    List<Offset> fixed,
  ) {
    final wire = net.where((w) => w.id == id).firstOrNull;
    if (wire == null || run < 0 || run + 1 >= wire.points.length) {
      return const WiringDrag(dragged: [], followers: {});
    }

    bool isJunction(Offset at) =>
        fixed.any((j) => (j - at).distance < tolerance);

    // An end not held by a pin or a junction travels with the run it
    // belongs to, so a wire can be dragged somewhere else. One on a pin
    // stays on its pin, and one at a junction stays at the junction: the
    // wire turns a corner there rather than taking the junction, and every
    // other wire meeting at it, along.
    final slid = DrawnWireGeometry.slideRun(
      wire.points,
      run,
      delta,
      carryStart:
          run == 0 && !wire.startPinned && !isJunction(wire.points.first),
      carryEnd:
          run == wire.points.length - 2 &&
          !wire.endPinned &&
          !isJunction(wire.points.last),
    );
    final moved = _slideAlongInsteadOfLeg(slid, wire, net);
    final shift = DrawnWireGeometry.runShift(wire.points, run, delta);
    final from = wire.points[run];
    final to = wire.points[run + 1];

    /// Where a point that was touching this wire has been taken to, or null
    /// if that part of the wire has not moved.
    Offset? taken(Offset at) {
      // Anywhere along the run being dragged — a wire meeting it end-on or
      // part-way along it alike — travels with it.
      if (DrawnWireGeometry.onSegment(at, from, to)) return at + shift;
      // An end of the wire that was carried rather than left anchored.
      if ((at - wire.points.first).distance < tolerance &&
          (moved.first - wire.points.first).distance > 1e-6) {
        return moved.first;
      }
      if ((at - wire.points.last).distance < tolerance &&
          (moved.last - wire.points.last).distance > 1e-6) {
        return moved.last;
      }
      return null;
    }

    final followers = <String, List<Offset>>{};
    for (final other in net) {
      if (other.id == id) continue;
      var shape = other.points;

      // What follows the drag, and what stays put, turns on where the two
      // meet.
      //
      // End to end — this wire finishes where the dragged one finishes —
      // and they are one run of wire between them: dragging one takes the
      // other's end with it, so the pair lengthens and shortens together.
      //
      // At a junction nothing moves: three or more wires meet there, each
      // is a wire of its own, and dragging one leaves the junction and the
      // others where they are.
      final moving = <(Offset, Offset)>[];
      for (var i = 0; i < shape.length; i++) {
        if (i == 0 && other.startPinned) continue;
        if (i == shape.length - 1 && other.endPinned) continue;
        // A junction stays where it is, whatever is dragged beside it.
        if (isJunction(shape[i])) continue;
        if (taken(shape[i]) case final at?) {
          final endToEnd =
              (shape[i] - wire.points.first).distance < tolerance ||
              (shape[i] - wire.points.last).distance < tolerance;
          if (!endToEnd && covers(shape, at)) continue;
          moving.add((shape[i], at));
        }
      }
      for (final (was, at) in moving) {
        final index = shape.indexWhere((p) => (p - was).distance < tolerance);
        if (index >= 0) shape = DrawnWireGeometry.moveVertex(shape, index, at);
      }

      // The other way round: an end of the wire being dragged that was
      // resting on this one and has now been carried off it. The nearest
      // corner of this wire that is free to move stretches after it — an
      // end, or a corner in the middle — so the two stay joined rather
      // than the drawing quietly coming apart.
      for (final (was, now) in [
        (wire.points.first, moved.first),
        (wire.points.last, moved.last),
      ]) {
        if ((was - now).distance < 1e-6) continue;
        // An end that was at a junction was never carried: it slid along a
        // wire already leaving that point, and every other wire there
        // stays where it is.
        if (isJunction(was)) continue;
        if (!covers(shape, was) || covers(shape, now)) continue;

        var nearest = -1;
        var distance = double.infinity;
        for (var i = 0; i < shape.length; i++) {
          if (i == 0 && other.startPinned) continue;
          if (i == shape.length - 1 && other.endPinned) continue;
          final away = (shape[i] - was).distance;
          if (away < distance) {
            distance = away;
            nearest = i;
          }
        }
        if (nearest >= 0) {
          shape = DrawnWireGeometry.moveVertex(shape, nearest, now);
        }
      }

      if (!samePoints(shape, other.points)) followers[other.id] = shape;
    }

    return WiringDrag(dragged: moved, followers: followers);
  }

  /// [moved] without a corner leg that would only retrace another wire.
  ///
  /// A wire whose end is held — on a pin, or at a junction — turns a
  /// corner there when dragged, and that leg is new wire. But if another
  /// wire already leaves the same point in the same direction, the leg
  /// would lie on top of it: dragging a wire up from a capacitor pin along
  /// the wire that also leaves that pin drew a second wire over the first.
  /// There the end slides along the wire that is already there instead,
  /// and nothing new is drawn.
  static List<Offset> _slideAlongInsteadOfLeg(
    List<Offset> moved,
    PolylineWire wire,
    List<PolylineWire> net,
  ) {
    var result = moved;

    /// Whether another wire leaves [held] along [held]–[corner]. On a pin,
    /// only a wire on that same pin counts — the one that goes on holding
    /// it once this wire's end has slid away.
    bool retraces(Offset held, Offset corner, String? pin) => net.any((other) {
      if (other.id == wire.id) return false;
      final String? otherPin;
      if ((other.points.first - held).distance < tolerance) {
        otherPin = other.pinA;
      } else if ((other.points.last - held).distance < tolerance) {
        otherPin = other.pinB;
      } else {
        return false;
      }
      if (pin != null && pin.isNotEmpty && otherPin != pin) return false;
      return _runCovered(held, corner, other.points);
    });

    if (result.length >= 3 &&
        (result.first - wire.points.first).distance < tolerance &&
        retraces(result[0], result[1], wire.pinA)) {
      result = result.sublist(1);
    }
    if (result.length >= 3 &&
        (result.last - wire.points.last).distance < tolerance &&
        retraces(result.last, result[result.length - 2], wire.pinB)) {
      result = result.sublist(0, result.length - 1);
    }
    return result;
  }

  /// [net] with every end run that only retraces another wire trimmed off.
  ///
  /// Where a wire leaves a point — a pin, a junction — along exactly the
  /// path another wire leaving the same point already takes, the two lie
  /// on top of each other: one wire drawn twice. The retracing run is cut
  /// back to where they part, and a wire that is nothing but retracing is
  /// dropped. The pin at the point is still held by the other wire.
  ///
  /// Returns the ids of the wires changed, and the new net; a changed wire
  /// that is gone altogether is missing from the net.
  static (Set<String>, List<PolylineWire>) trimRetracedEnds(
    List<PolylineWire> net,
  ) {
    var wires = [...net];
    final changed = <String>{};
    var trimmed = true;
    while (trimmed) {
      trimmed = false;
      for (var i = 0; i < wires.length && !trimmed; i++) {
        final wire = wires[i];
        final others = [
          for (final other in wires)
            if (other.id != wire.id) other.points,
        ];
        bool retraces(Offset held, Offset corner) => others.any(
          (other) =>
              ((other.first - held).distance < tolerance ||
                  (other.last - held).distance < tolerance) &&
              _runCovered(held, corner, other),
        );
        final points = wire.points;
        if (points.length < 2) continue;
        if (retraces(points[0], points[1])) {
          changed.add(wire.id);
          wires = [
            ...wires.sublist(0, i),
            if (points.length > 2)
              PolylineWire(
                id: wire.id,
                points: points.sublist(1),
                pinB: wire.pinB,
              ),
            ...wires.sublist(i + 1),
          ];
          trimmed = true;
        } else if (retraces(points.last, points[points.length - 2])) {
          changed.add(wire.id);
          wires = [
            ...wires.sublist(0, i),
            if (points.length > 2)
              PolylineWire(
                id: wire.id,
                points: points.sublist(0, points.length - 1),
                pinA: wire.pinA,
              ),
            ...wires.sublist(i + 1),
          ];
          trimmed = true;
        }
      }
    }
    return (changed, wires);
  }

  /// Whether the straight run [a]–[b] lies entirely along [shape].
  static bool _runCovered(Offset a, Offset b, List<Offset> shape) {
    final length = (b - a).distance;
    if (length < tolerance) return false;
    final steps = (length / 0.25).ceil().clamp(2, 4000);
    for (var k = 0; k <= steps; k++) {
      if (!covers(shape, Offset.lerp(a, b, k / steps)!)) return false;
    }
    return true;
  }

  /// [net] with every wire that runs through a junction split there.
  ///
  /// Where another wire ends on the middle of this one, that point is a
  /// junction, and a junction is where wires end: this one becomes two. The
  /// piece before keeps the wire's id and its first pin; the piece after is
  /// `id~1` (then `~2`, …) and keeps the last. The drawing is unchanged.
  static List<PolylineWire> splitAtJunctions(List<PolylineWire> net) {
    var wires = [...net];
    var counter = 0;
    var cut = true;
    while (cut) {
      cut = false;
      // Only a real junction splits — three or more directions of wire
      // meeting, the points that get a dot. A wire lying along another, or
      // ending where it bends, is not one.
      final junctions = junctionsOf(wires);
      bool isJunction(Offset at) =>
          junctions.any((j) => (j - at).distance < tolerance);
      outer:
      for (var i = 0; i < wires.length; i++) {
        final wire = wires[i];
        for (final other in wires) {
          if (identical(other, wire)) continue;
          for (final end in [other.points.first, other.points.last]) {
            // At one of its own ends is where wires meet anyway; anywhere
            // else — a straight stretch or a corner — is its middle.
            if ((wire.points.first - end).distance < tolerance ||
                (wire.points.last - end).distance < tolerance) {
              continue;
            }
            if (!covers(wire.points, end) || !isJunction(end)) continue;
            final split = DrawnWireGeometry.splitAt(wire.points, end);
            final at = split.indexWhere((p) => (p - end).distance < tolerance);
            if (at <= 0 || at >= split.length - 1) continue;
            wires = [
              ...wires.sublist(0, i),
              PolylineWire(
                id: wire.id,
                points: split.sublist(0, at + 1),
                pinA: wire.pinA,
              ),
              PolylineWire(
                id: '${wire.id.split('~').first}~${++counter}',
                points: split.sublist(at),
                pinB: wire.pinB,
              ),
              ...wires.sublist(i + 1),
            ];
            cut = true;
            break outer;
          }
        }
      }
    }
    return wires;
  }

  /// Whether [at] lies anywhere on the chain [points].
  static bool covers(List<Offset> points, Offset at) {
    for (var i = 0; i < points.length - 1; i++) {
      if (DrawnWireGeometry.onSegment(at, points[i], points[i + 1])) {
        return true;
      }
    }
    return false;
  }

  static bool samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distance >= 1e-6) return false;
    }
    return true;
  }

  /// How many separate pieces [wires] make: 1 for a net drawn in one
  /// piece. Wires meet by ending on one another and by crossing.
  static int pieceCount(List<List<Offset>> wires) {
    if (wires.isEmpty) return 0;
    final seen = <int>{};
    var pieces = 0;
    for (var start = 0; start < wires.length; start++) {
      if (seen.contains(start)) continue;
      pieces++;
      final stack = [start];
      seen.add(start);
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        for (var j = 0; j < wires.length; j++) {
          if (seen.contains(j) || !_meet(wires[i], wires[j])) continue;
          seen.add(j);
          stack.add(j);
        }
      }
    }
    return pieces;
  }

  static bool _meet(List<Offset> a, List<Offset> b) {
    for (final point in [a.first, a.last]) {
      if (covers(b, point)) return true;
    }
    for (final point in [b.first, b.last]) {
      if (covers(a, point)) return true;
    }
    for (var i = 0; i < a.length - 1; i++) {
      for (var j = 0; j < b.length - 1; j++) {
        if (DrawnWireGeometry.crossing(a[i], a[i + 1], b[j], b[j + 1]) !=
            null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether every wire is reachable from every other: the net drawn in one
  /// piece, which is what a drag must never break.
  ///
  /// Wires meet by ending on one another and by crossing: a wire dragged
  /// across the one it hangs off turns a tee into a cross, which is still
  /// the same connection.
  static bool allJoined(List<List<Offset>> wires) {
    if (wires.length < 2) return true;
    bool meet(List<Offset> a, List<Offset> b) {
      for (final point in [a.first, a.last]) {
        if (covers(b, point)) return true;
      }
      for (final point in [b.first, b.last]) {
        if (covers(a, point)) return true;
      }
      for (var i = 0; i < a.length - 1; i++) {
        for (var j = 0; j < b.length - 1; j++) {
          if (DrawnWireGeometry.crossing(a[i], a[i + 1], b[j], b[j + 1]) !=
              null) {
            return true;
          }
        }
      }
      return false;
    }

    final reached = <int>{0};
    var grew = true;
    while (grew) {
      grew = false;
      for (var i = 0; i < wires.length; i++) {
        if (reached.contains(i)) continue;
        if (reached.any((j) => meet(wires[j], wires[i]))) {
          reached.add(i);
          grew = true;
        }
      }
    }
    return reached.length == wires.length;
  }

  /// Whether every run of [points] is horizontal or vertical.
  static bool square(List<Offset> points) {
    for (var i = 0; i < points.length - 1; i++) {
      final run = points[i + 1] - points[i];
      if (run.dx.abs() > tolerance && run.dy.abs() > tolerance) return false;
    }
    return true;
  }
}
