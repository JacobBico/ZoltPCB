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
  static WiringDrag drag(
    List<PolylineWire> net,
    String id,
    int run,
    Offset delta, {
    double grid = 1.27,
  }) {
    var tried = delta;
    for (var attempt = 0; attempt < 40; attempt++) {
      final result = _dragOnce(net, id, run, tried);
      final shapes = [
        for (final wire in net)
          if (wire.id == id)
            result.dragged
          else
            result.followers[wire.id] ?? wire.points,
      ];
      if (allJoined(shapes)) return result;

      final length = tried.distance;
      if (length <= grid) break;
      tried = tried * ((length - grid) / length);
    }
    return const WiringDrag(dragged: [], followers: {});
  }

  static WiringDrag _dragOnce(
    List<PolylineWire> net,
    String id,
    int run,
    Offset delta,
  ) {
    final wire = net.where((w) => w.id == id).firstOrNull;
    if (wire == null || run < 0 || run + 1 >= wire.points.length) {
      return const WiringDrag(dragged: [], followers: {});
    }

    // An end not held by a pin travels with the run it belongs to, so a
    // wire can be dragged somewhere else; one on a pin stays on its pin.
    final moved = DrawnWireGeometry.slideRun(
      wire.points,
      run,
      delta,
      carryStart: run == 0 && !wire.startPinned,
      carryEnd: run == wire.points.length - 2 && !wire.endPinned,
    );
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
      // Against its middle, though, is a junction: the meeting point slides
      // along the dragged wire and this one stays exactly where it was put.
      // That is the difference between shortening a wire and shoving
      // everything hanging off it.
      final moving = <(Offset, Offset)>[];
      for (var i = 0; i < shape.length; i++) {
        if (i == 0 && other.startPinned) continue;
        if (i == shape.length - 1 && other.endPinned) continue;
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
