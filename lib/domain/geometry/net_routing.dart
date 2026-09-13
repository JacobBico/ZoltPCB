import 'dart:ui';

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
  });

  final String netId;
  final String pinAId;
  final String pinBId;

  /// Corner points in sheet millimetres, starting and ending on the pins.
  final List<Offset> points;

  /// The runs of this wire that can be moved, each on its own axis.
  final List<WireHandle> handles;

  bool get isAdjustable => handles.isNotEmpty;

  /// Stable key for the pin pair, matching the stored route hint.
  String get key => NetRouting.routeKey(pinAId, pinBId);

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
      pinAId.compareTo(pinBId) <= 0
      ? '$pinAId|$pinBId'
      : '$pinBId|$pinAId';

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
