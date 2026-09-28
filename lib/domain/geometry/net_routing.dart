import 'dart:ui';

import '../models/schematic_wire.dart';
import 'drawn_wire_geometry.dart';
import 'wire_router.dart';

/// A pin as the router needs it: a point, and the way a wire leaves it.
///
/// Deliberately smaller than either the canvas's or the exporter's idea of a
/// pin. Both build these from their own data and get identical geometry
/// back, which is what lets the exported file show the same wires the user
/// arranged on screen.
class RoutablePin {
  const RoutablePin({
    required this.id,
    required this.position,
    required this.exitDirection,
  });

  /// Builds one from a pin position and the point where its stub meets the
  /// symbol body — the wire leaves along that line, pointing away.
  factory RoutablePin.fromBodyEnd({
    required String id,
    required Offset position,
    required Offset bodyEnd,
  }) {
    final away = position - bodyEnd;
    final length = away.distance;
    return RoutablePin(
      id: id,
      position: position,
      exitDirection: length < 1e-6
          ? const Offset(1, 0)
          : Offset(away.dx / length, away.dy / length),
    );
  }

  final String id;
  final Offset position;

  /// Unit vector pointing away from the symbol body.
  final Offset exitDirection;
}

/// One connection of a net, routed as an orthogonal path in sheet space.
class RoutedWire {
  const RoutedWire({
    required this.netId,
    required this.pinAId,
    required this.pinBId,
    required this.points,
    this.handles = const [],
    this.drawnId,
  });

  /// The stored wire this is, when the user drew or shaped it; null for a
  /// connection the app routed itself.
  final String? drawnId;

  bool get isDrawn => drawnId != null;

  final String netId;
  final String pinAId;
  final String pinBId;

  /// Corner points in sheet millimetres, starting and ending on the pins.
  final List<Offset> points;

  /// The runs of this wire that can be moved, each on its own axis.
  final List<WireHandle> handles;

  bool get isAdjustable => handles.isNotEmpty;

  /// Stable key: the stored wire's id when drawn, otherwise the pin pair,
  /// matching the stored route hint.
  String get key => drawnId ?? NetRouting.routeKey(pinAId, pinBId);

  /// Shortest distance from [point] to the drawn path.
  double distanceTo(Offset point) {
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final distance = distanceToSegment(point, points[i], points[i + 1]);
      if (distance < best) best = distance;
    }
    return best;
  }

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-12) return (p - a).distance;

    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}

/// Turns a net's pins into the wires that join them.
///
/// This lives in the domain rather than in the renderer because the canvas
/// is no longer the only consumer: the exported `.kicad_sch` carries the
/// same wires, and they have to be the same wires. A second implementation
/// would drift, and the first sign of the drift would be a schematic that
/// opens on the desktop looking nothing like the phone.
abstract final class NetRouting {
  /// Stable key for a pin pair, independent of which end came first.
  static String routeKey(String pinAId, String pinBId) =>
      pinAId.compareTo(pinBId) <= 0 ? '$pinAId|$pinBId' : '$pinBId|$pinAId';

  /// Routes every net in [pinsByNet].
  static List<RoutedWire> routeAll({
    required Map<String, List<RoutablePin>> pinsByNet,
    List<Rect> obstacles = const [],
    Map<String, List<double>> hints = const {},
  }) {
    final wires = <RoutedWire>[];
    for (final entry in pinsByNet.entries) {
      wires.addAll(
        routeNet(entry.key, entry.value, obstacles: obstacles, hints: hints),
      );
    }
    return wires;
  }

  /// Routes a net whose drawing is partly the user's own.
  ///
  /// The drawn wires come first, exactly as laid, with their ends pulled
  /// onto wherever their pins now are. Only what they leave unjoined is
  /// routed automatically — one connection between each pair of pieces —
  /// so a net drawn by hand shows no extra wires, and one joined in a hurry
  /// still shows how it is joined.
  ///
  /// A piece holding one of [labelledPins] or [powerPins] is joined by its
  /// name, the way a KiCad label joins it, and is never bridged to another
  /// such piece by a wire routed across the sheet. Two `+5V` symbols are
  /// connected because they are both called `+5V`, not because a wire runs
  /// between them — drawing that wire across the whole sheet is what the
  /// symbol exists to avoid. With neither set the routing is exactly what
  /// it always was.
  ///
  /// [labelAnchors] are where labels drawn on the sheet sit, as a KiCad
  /// file brings them: a piece with one on its wires or pins is joined by
  /// that label's name just the same.
  static List<RoutedWire> routeNetWithDrawn(
    String netId,
    List<RoutablePin> pins, {
    List<SchematicWire> drawn = const [],
    List<Rect> obstacles = const [],
    Map<String, List<double>> hints = const {},
    Set<String> labelledPins = const {},
    Set<String> powerPins = const {},
    List<Offset> labelAnchors = const [],
  }) {
    final byId = {for (final pin in pins) pin.id: pin};
    final wires = <RoutedWire>[];

    // Pieces of the net already joined, as sets of pin ids.
    final parent = {for (final pin in pins) pin.id: pin.id};
    String find(String id) {
      var root = id;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      return root;
    }

    void union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    final placed = <List<Offset>>[];
    for (final wire in drawn) {
      final a = byId[wire.pinAId];
      final b = byId[wire.pinBId];
      final points = DrawnWireGeometry.attachEnds(
        wire.points,
        start: a?.position,
        end: b?.position,
      );
      if (points.length < 2) continue;
      placed.add(points);
      wires.add(
        RoutedWire(
          netId: netId,
          pinAId: wire.pinAId ?? '',
          pinBId: wire.pinBId ?? '',
          points: points,
          drawnId: wire.id,
        ),
      );
    }

    // Drawn wires that touch — end to end, or an end on another's run —
    // are one piece, and a piece joins every pin at any of its ends. That
    // is how a wire drawn as several segments, the way a KiCad file stores
    // one, still counts as a single connection.
    final groupOf = List<int>.generate(placed.length, (i) => i);
    int findWire(int i) {
      while (groupOf[i] != i) {
        i = groupOf[i];
      }
      return i;
    }

    bool touches(List<Offset> end, List<Offset> other) {
      for (final point in [end.first, end.last]) {
        final (_, distance) = DrawnWireGeometry.nearestRun(other, point);
        if (distance < 0.01) return true;
      }
      return false;
    }

    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        if (touches(placed[i], placed[j]) || touches(placed[j], placed[i])) {
          final ri = findWire(i);
          final rj = findWire(j);
          if (ri != rj) groupOf[ri] = rj;
        }
      }
    }
    final pinsOfGroup = <int, Set<String>>{};
    for (var i = 0; i < placed.length; i++) {
      final group = pinsOfGroup[findWire(i)] ??= {};
      final wire = drawn[i];
      if (byId.containsKey(wire.pinAId)) group.add(wire.pinAId!);
      if (byId.containsKey(wire.pinBId)) group.add(wire.pinBId!);
      for (final pin in pins) {
        if ((pin.position - placed[i].first).distance < 0.01 ||
            (pin.position - placed[i].last).distance < 0.01) {
          group.add(pin.id);
        }
      }
    }
    for (final group in pinsOfGroup.values) {
      final members = group.toList();
      for (final other in members.skip(1)) {
        union(members.first, other);
      }
    }
    final labelledHere = <String>{
      for (final at in labelAnchors) ...[
        for (final pin in pins)
          if ((pin.position - at).distance < 0.01) pin.id,
        for (var i = 0; i < placed.length; i++)
          if (DrawnWireGeometry.nearestRun(placed[i], at).$2 < 0.01)
            ...?pinsOfGroup[findWire(i)],
      ],
    };

    // One representative pin list per piece, then a spanning tree between
    // pieces using the closest pair of pins each time.
    final groups = <String, List<RoutablePin>>{};
    for (final pin in pins) {
      (groups[find(pin.id)] ??= []).add(pin);
    }
    final pieces = groups.values.toList();
    if (pieces.length < 2) return wires;

    RoutedWire bridge(RoutablePin a, RoutablePin b) {
      final route = WireRouter.route(
        from: a.position,
        fromExit: a.exitDirection,
        to: b.position,
        toExit: b.exitDirection,
        obstacles: obstacles,
        offsets: hints[routeKey(a.id, b.id)] ?? const [],
      );
      return RoutedWire(
        netId: netId,
        pinAId: a.id,
        pinBId: b.id,
        points: route.points,
        handles: route.handles,
      );
    }

    // Only pieces anchored by their own name — a pin labelled by the
    // Labels action, or a power symbol, which is a label with a shape — are
    // joined by name. Without one, this is the routing the drag rules were
    // built and tested against, unchanged.
    final anchored = <int>{
      for (var i = 0; i < pieces.length; i++)
        if (pieces[i].any(
          (pin) =>
              labelledPins.contains(pin.id) ||
              powerPins.contains(pin.id) ||
              labelledHere.contains(pin.id),
        ))
          i,
    };
    if (anchored.isNotEmpty) {
      (RoutablePin, RoutablePin, double)? closest(
        List<RoutablePin> from,
        List<RoutablePin> to,
      ) {
        (RoutablePin, RoutablePin, double)? best;
        for (final a in from) {
          for (final b in to) {
            final d = (a.position - b.position).distance;
            if (best == null || d < best.$3) best = (a, b, d);
          }
        }
        return best;
      }

      // Everything else joins the nearest piece already placed, never
      // making a bridge between two labelled pieces.
      final done = {...anchored};
      final waiting = [
        for (var i = 0; i < pieces.length; i++)
          if (!done.contains(i)) i,
      ];
      while (waiting.isNotEmpty) {
        (RoutablePin, RoutablePin, double)? best;
        int? next;
        for (final i in waiting) {
          for (final j in done) {
            final pair = closest(pieces[i], pieces[j]);
            if (pair != null && (best == null || pair.$3 < best.$3)) {
              best = pair;
              next = i;
            }
          }
        }
        if (best == null || next == null) break;
        wires.add(bridge(best.$1, best.$2));
        done.add(next);
        waiting.remove(next);
      }
      return wires;
    }

    final inTree = <int>{0};
    while (inTree.length < pieces.length) {
      (RoutablePin, RoutablePin)? bestPair;
      int? bestPiece;
      var bestDistance = double.infinity;
      for (final i in inTree) {
        for (var j = 0; j < pieces.length; j++) {
          if (inTree.contains(j)) continue;
          for (final a in pieces[i]) {
            for (final b in pieces[j]) {
              final d = (a.position - b.position).distance;
              if (d < bestDistance) {
                bestDistance = d;
                bestPair = (a, b);
                bestPiece = j;
              }
            }
          }
        }
      }
      if (bestPair == null || bestPiece == null) break;
      inTree.add(bestPiece);
      final (a, b) = bestPair;
      wires.add(bridge(a, b));
    }
    return wires;
  }

  /// Chooses which pins to join and routes each connection.
  static List<RoutedWire> routeNet(
    String netId,
    List<RoutablePin> pins, {
    List<Rect> obstacles = const [],
    Map<String, List<double>> hints = const {},
  }) {
    if (pins.length < 2) return const [];

    final wires = <RoutedWire>[];
    for (final edge in spanningTree(pins)) {
      final a = pins[edge.$1];
      final b = pins[edge.$2];
      final route = WireRouter.route(
        from: a.position,
        fromExit: a.exitDirection,
        to: b.position,
        toExit: b.exitDirection,
        obstacles: obstacles,
        offsets: hints[routeKey(a.id, b.id)] ?? const [],
      );
      wires.add(
        RoutedWire(
          netId: netId,
          pinAId: a.id,
          pinBId: b.id,
          points: route.points,
          handles: route.handles,
        ),
      );
    }
    return wires;
  }

  /// Pairs of indices into [pins] forming a minimum spanning tree by
  /// straight-line distance.
  ///
  /// A star from the first pin would draw a fan that reads as "everything
  /// connects to this one pin", a claim the net does not make. A spanning
  /// tree uses the same number of wires, keeps each short, and gives no pin
  /// a special role.
  static List<(int, int)> spanningTree(List<RoutablePin> pins) {
    final edges = <(int, int)>[];
    final inTree = List<bool>.filled(pins.length, false);
    final nearest = List<double>.filled(pins.length, double.infinity);
    final parent = List<int>.filled(pins.length, -1);
    nearest[0] = 0;

    for (var step = 0; step < pins.length; step++) {
      var next = -1;
      var nextDistance = double.infinity;
      for (var i = 0; i < pins.length; i++) {
        if (!inTree[i] && nearest[i] < nextDistance) {
          nextDistance = nearest[i];
          next = i;
        }
      }
      if (next < 0) break;

      inTree[next] = true;
      if (parent[next] >= 0) edges.add((parent[next], next));

      for (var i = 0; i < pins.length; i++) {
        if (inTree[i]) continue;
        final distance = (pins[i].position - pins[next].position).distance;
        if (distance < nearest[i]) {
          nearest[i] = distance;
          parent[i] = next;
        }
      }
    }
    return edges;
  }
}
