import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/track_router.dart';

void main() {
  group('45 degree routing', () {
    test('a diagonal run then a straight one reaches the target', () {
      final points = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(10, 4),
      );

      expect(points.first, Offset.zero);
      expect(points.last, const Offset(10, 4));
      // The diagonal covers the shorter axis in full.
      expect(points[1], const Offset(4, 4));
    });

    test('every segment is horizontal, vertical or exactly 45 degrees', () {
      for (final target in const [
        Offset(10, 4),
        Offset(-7, 3),
        Offset(2, -9),
        Offset(-5, -5),
        Offset(0, 6),
        Offset(6, 0),
      ]) {
        final points = TrackRouter.route(from: Offset.zero, to: target);
        for (var i = 0; i < points.length - 1; i++) {
          expect(
            TrackRouter.isLegal(
              points[i],
              points[i + 1],
              TrackAngleMode.diagonal,
            ),
            isTrue,
            reason: 'segment ${points[i]}->${points[i + 1]} for $target',
          );
        }
      }
    });

    test('the straight run can be put first instead', () {
      final points = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(10, 4),
        straightFirst: true,
      );

      expect(points[1], const Offset(6, 0));
      expect(points.last, const Offset(10, 4));
    });

    test('a pure diagonal needs no corner at all', () {
      final points = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(5, 5),
      );
      expect(points, [Offset.zero, const Offset(5, 5)]);
    });

    test('a straight run needs no corner either', () {
      expect(TrackRouter.route(from: Offset.zero, to: const Offset(5, 0)), [
        Offset.zero,
        const Offset(5, 0),
      ]);
    });
  });

  group('90 degree routing', () {
    test('turns exactly once', () {
      final points = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(10, 4),
        mode: TrackAngleMode.orthogonal,
      );

      expect(points, [Offset.zero, const Offset(10, 0), const Offset(10, 4)]);
      for (var i = 0; i < points.length - 1; i++) {
        expect(
          TrackRouter.isLegal(
            points[i],
            points[i + 1],
            TrackAngleMode.orthogonal,
          ),
          isTrue,
        );
      }
    });

    test('a 45 degree segment is not legal in 90 degree mode', () {
      expect(
        TrackRouter.isLegal(
          Offset.zero,
          const Offset(3, 3),
          TrackAngleMode.orthogonal,
        ),
        isFalse,
      );
    });
  });

  group('avoiding what is in the way', () {
    // Reported: routing pad to pad ran the trace straight through the part
    // sitting between them. Both corner choices are legal, so the one that
    // does not cut through anything is the one to draw.
    test('the corner that misses the part is the one taken', () {
      const part = Rect.fromLTRB(4, -1, 9, 1);

      final route = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(12, 6),
        obstacles: const [part],
      );

      for (var i = 0; i < route.length - 1; i++) {
        for (var step = 1; step < 24; step++) {
          final point = Offset.lerp(route[i], route[i + 1], step / 24)!;
          expect(
            part.deflate(1e-6).contains(point),
            isFalse,
            reason: 'the route passes through the part at $point',
          );
        }
      }
    });

    test('an obstacle nowhere near changes nothing', () {
      final clear = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(12, 6),
      );
      final withDistant = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(12, 6),
        obstacles: const [Rect.fromLTRB(80, 80, 90, 90)],
      );
      expect(withDistant, clear);
    });

    test('a route with no way past keeps its preferred shape', () {
      // Boxed in on both variants: the route still has to exist, and the
      // user can steer it themselves.
      final route = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(12, 6),
        obstacles: const [Rect.fromLTRB(-20, -20, 40, 40)],
      );
      expect(route.first, Offset.zero);
      expect(route.last, const Offset(12, 6));
    });

    test('the constrained angles survive the detour', () {
      final route = TrackRouter.route(
        from: Offset.zero,
        to: const Offset(12, 6),
        obstacles: const [Rect.fromLTRB(4, -1, 9, 1)],
      );
      for (var i = 0; i < route.length - 1; i++) {
        expect(
          TrackRouter.isLegal(route[i], route[i + 1], TrackAngleMode.diagonal),
          isTrue,
        );
      }
    });
  });

  test('there are only two angle modes to cycle through', () {
    // A free-angle mode let a finger draw a 3° trace by accident. Both
    // remaining modes have to be reachable by cycling, and neither may be
    // free.
    expect(TrackAngleMode.values, hasLength(2));
    expect(TrackAngleMode.diagonal.next, TrackAngleMode.orthogonal);
    expect(TrackAngleMode.orthogonal.next, TrackAngleMode.diagonal);
  });

  test('a route to where it started is a single point', () {
    expect(TrackRouter.route(from: Offset.zero, to: Offset.zero), [
      Offset.zero,
    ]);
  });

  group('snapping', () {
    test('rounds onto the grid', () {
      expect(
        TrackRouter.snap(const Offset(1.2, 3.4), 0.5),
        const Offset(1, 3.5),
      );
      expect(
        TrackRouter.snap(const Offset(-1.2, -3.4), 0.5),
        const Offset(-1, -3.5),
      );
    });

    test('a grid of zero leaves the point alone', () {
      expect(
        TrackRouter.snap(const Offset(1.234, 5.678), 0),
        const Offset(1.234, 5.678),
      );
    });
  });
}
