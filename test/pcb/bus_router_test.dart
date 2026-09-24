import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t =
      (((p - a).dx * ab.dx + (p - a).dy * ab.dy) /
              (ab.dx * ab.dx + ab.dy * ab.dy))
          .clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

void main() {
  group('offsetting a path', () {
    test('a straight run moves sideways by exactly the distance', () {
      final out = BusRouter.offsetPolyline(const [
        Offset(0, 0),
        Offset(10, 0),
      ], 1);
      // Left of travel, as the board is seen (y down): up.
      expect(out, const [Offset(0, -1), Offset(10, -1)]);
    });

    test('through a 45° bend both runs stay the distance off', () {
      const path = [Offset(0, 0), Offset(10, 0), Offset(20, 10)];
      final out = BusRouter.offsetPolyline(path, 0.5);
      expect(out, hasLength(3));
      // The first run parallel to the first leg, the last to the last.
      expect(_distanceToSegment(out[0], path[0], path[1]), closeTo(0.5, 1e-9));
      expect(_distanceToSegment(out[2], path[1], path[2]), closeTo(0.5, 1e-9));
      // The mitred corner is the distance off both legs' lines.
      final corner = out[1];
      expect((corner.dy - 0).abs(), closeTo(0.5, 1e-9));
      final lineDistance =
          ((corner.dx - 10) - (corner.dy - 0)).abs() / math.sqrt2;
      expect(lineDistance, closeTo(0.5, 1e-9));
    });
  });

  group('a bus', () {
    List<BusLane> lanes(List<double> fromYs, List<double> toYs) => [
      for (var i = 0; i < fromYs.length; i++)
        BusLane(
          netId: 'd$i',
          netName: 'D$i',
          from: Offset(2, fromYs[i]),
          to: Offset(38, toYs[i]),
        ),
    ];

    const spine = [Offset(8, 11), Offset(20, 11), Offset(28, 19)];

    test('lanes run side by side at the pitch, pad to pad, in order', () {
      final plan = BusRouter.plan(
        lanes: lanes([10, 11, 12], [18, 19, 20]),
        spine: spine,
        pitch: 0.5,
      );
      expect(plan.warnings, isEmpty);
      expect(plan.tracks, hasLength(3));
      for (final (lane, points) in plan.tracks) {
        expect(points.first, lane.from);
        expect(points.last, lane.to);
        // Every run on 0, 45 or 90 degrees.
        for (var i = 0; i < points.length - 1; i++) {
          final dx = (points[i + 1].dx - points[i].dx).abs();
          final dy = (points[i + 1].dy - points[i].dy).abs();
          expect(
            dx < 1e-6 || dy < 1e-6 || (dx - dy).abs() < 1e-6,
            isTrue,
            reason: '${lane.netName} run $i',
          );
        }
      }
      // Along the shared straight run, neighbours are the pitch apart.
      double yAt14(List<Offset> points) {
        for (var i = 0; i < points.length - 1; i++) {
          final a = points[i];
          final b = points[i + 1];
          if ((a.dy - b.dy).abs() < 1e-9 &&
              math.min(a.dx, b.dx) <= 14 &&
              math.max(a.dx, b.dx) >= 14) {
            return a.dy;
          }
        }
        throw StateError('no straight run at x = 14');
      }

      final ys = [for (final (_, points) in plan.tracks) yAt14(points)];
      expect((ys[1] - ys[0]).abs(), closeTo(0.5, 1e-9));
      expect((ys[2] - ys[1]).abs(), closeTo(0.5, 1e-9));
      // Each lane takes the rail on its own side: the one starting lowest
      // runs lowest, so none crosses another leaving its pad.
      final byStart = [
        for (final (lane, points) in plan.tracks) (lane.from.dy, yAt14(points)),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      expect(byStart.map((e) => e.$2).toList(), [10.5, 11.0, 11.5]);
    });

    test('ends in a different order: reported as crossing', () {
      final plan = BusRouter.plan(
        lanes: lanes([10, 11, 12], [20, 19, 18]),
        spine: spine,
        pitch: 0.5,
      );
      expect(plan.warnings.single, contains('cross'));
    });

    test('the lanes are the unrouted connections starting in the box', () {
      final scene = BoardScene(
        board: Board(
          id: 'b',
          projectId: 'p',
          outlineX: 0,
          outlineY: 0,
          outlineWidth: 40,
          outlineHeight: 30,
          rules: const DesignRules(),
          gridMm: 0.5,
          modifiedAt: DateTime(2026),
        ),
        footprints: const [],
        pads: const [],
        tracks: const [],
        vias: const [],
        ratsnest: const [
          RatsnestLine(
            netId: 'a',
            netName: 'A',
            from: Offset(2, 10),
            to: Offset(38, 18),
          ),
          // Drawn the other way round: still starts in the box.
          RatsnestLine(
            netId: 'b',
            netName: 'B',
            from: Offset(38, 19),
            to: Offset(2, 11),
          ),
          // Both ends outside: not part of it.
          RatsnestLine(
            netId: 'c',
            netName: 'C',
            from: Offset(20, 25),
            to: Offset(30, 25),
          ),
        ],
        unplaced: const [],
      );
      final found = BusRouter.lanesStartingIn(
        scene,
        const Rect.fromLTRB(0, 8, 5, 14),
      );
      expect([for (final l in found) l.netId], ['a', 'b']);
      expect(found[1].from, const Offset(2, 11));
    });
  });
}
