import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/polyline_wiring.dart';

PolylineWire _w(String id, List<Offset> points, {String? pinA, String? pinB}) =>
    PolylineWire(id: id, points: points, pinA: pinA, pinB: pinB);

List<PolylineWire> _start() => [
  _w('main', const [
    Offset(40, 40),
    Offset(40, 60),
    Offset(70, 60),
  ], pinA: 'p1'),
  _w('branch', const [Offset(70, 60), Offset(70, 80)]),
  _w('stub', const [Offset(55, 60), Offset(55, 45)]),
];

/// Whether a wire doubles back over itself — a run reversing straight into
/// the one before it, which reads as a crease rather than a wire.
bool _doublesBack(List<Offset> points) {
  for (var i = 0; i + 2 < points.length; i++) {
    final a = points[i + 1] - points[i];
    final b = points[i + 2] - points[i + 1];
    if (a.dx * b.dx + a.dy * b.dy < -1e-9) return true;
  }
  return false;
}

/// Whether a corner is doing nothing: three points in a straight line.
bool _hasRedundantCorner(List<Offset> points) {
  for (var i = 0; i + 2 < points.length; i++) {
    final a = points[i + 1] - points[i];
    final b = points[i + 2] - points[i + 1];
    if ((a.dx * b.dy - a.dy * b.dx).abs() < 1e-9 &&
        a.dx * b.dx + a.dy * b.dy > 0) {
      return true;
    }
  }
  return false;
}

void main() {
  // Dragging a net about for a while must leave it a drawing, not a mess:
  // still joined, still square, no wire creased back on itself, and no pile
  // of corners that do nothing.
  test('a net dragged about at random stays a tidy drawing', () {
    final random = Random(20260917);
    final deltas = [
      const Offset(0, 2.54),
      const Offset(0, -2.54),
      const Offset(2.54, 0),
      const Offset(-2.54, 0),
      const Offset(0, 6.35),
      const Offset(-5.08, 0),
      const Offset(3.81, -2.54),
    ];

    for (var round = 0; round < 200; round++) {
      var net = _start();
      final history = <String>[];

      for (var step = 0; step < 10; step++) {
        final wire = net[random.nextInt(net.length)];
        if (wire.points.length < 2) continue;
        final run = random.nextInt(wire.points.length - 1);
        final delta = deltas[random.nextInt(deltas.length)];
        history.add('${wire.id} run $run by $delta');

        final result = PolylineWiring.drag(net, wire.id, run, delta);
        if (result.dragged.isEmpty) continue; // held: would have torn

        net = [
          for (final w in net)
            PolylineWire(
              id: w.id,
              points: w.id == wire.id
                  ? result.dragged
                  : result.followers[w.id] ?? w.points,
              pinA: w.pinA,
              pinB: w.pinB,
            ),
        ];

        final shapes = [for (final w in net) w.points];
        final trail = history.join('\n  ');
        expect(
          PolylineWiring.allJoined(shapes),
          isTrue,
          reason: 'came apart after:\n  $trail\n$shapes',
        );
        for (final w in net) {
          expect(
            PolylineWiring.square(w.points),
            isTrue,
            reason: 'went diagonal after:\n  $trail\n${w.points}',
          );
          expect(
            _doublesBack(w.points),
            isFalse,
            reason: 'creased back on itself after:\n  $trail\n${w.points}',
          );
          expect(
            _hasRedundantCorner(w.points),
            isFalse,
            reason: 'grew a corner doing nothing after:\n  $trail\n${w.points}',
          );
          expect(
            w.points.length,
            lessThan(12),
            reason: 'corners piled up after:\n  $trail\n${w.points}',
          );
        }
      }
    }
  });
}
