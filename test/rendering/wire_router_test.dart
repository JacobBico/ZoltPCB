import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/geometry/wire_router.dart';

/// Every segment of a route must be horizontal or vertical.
void expectOrthogonal(List<Offset> path) {
  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final horizontal = (a.dy - b.dy).abs() < 1e-6;
    final vertical = (a.dx - b.dx).abs() < 1e-6;
    expect(
      horizontal || vertical,
      isTrue,
      reason: 'segment $a -> $b is diagonal',
    );
  }
}

void main() {
  const right = Offset(1, 0);
  const left = Offset(-1, 0);
  const up = Offset(0, -1);
  const down = Offset(0, 1);

  group('shape', () {
    test('a route starts and ends exactly on the pins', () {
      final route = WireRouter.route(
        from: const Offset(10, 10),
        fromExit: right,
        to: const Offset(40, 30),
        toExit: left,
      );

      expect(route.points.first, const Offset(10, 10));
      expect(route.points.last, const Offset(40, 30));
    });

    test('every segment is axis aligned', () {
      for (final exits in [
        (right, left),
        (up, down),
        (right, up),
        (down, left),
      ]) {
        final route = WireRouter.route(
          from: const Offset(10, 10),
          fromExit: exits.$1,
          to: const Offset(40, 30),
          toExit: exits.$2,
        );
        expectOrthogonal(route.points);
      }
    });

    test('pins that already line up get a straight run', () {
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(25.4, 0),
        toExit: left,
      );

      expect(route.points, hasLength(2), reason: 'no corner is needed');
    });

    test('the wire leaves the pin before it turns', () {
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(30, 20),
        toExit: left,
      );

      expect(
        route.points[1].dx,
        greaterThanOrEqualTo(WireRouter.stubMm - 1e-6),
      );
      expect(route.points[1].dy, route.points.first.dy);
    });

    test('an off-grid pin still gets a square route that touches it', () {
      final route = WireRouter.route(
        from: const Offset(0.4, 0.7),
        fromExit: right,
        to: const Offset(19.1, 11.3),
        toExit: left,
      );

      expect(route.points.first, const Offset(0.4, 0.7));
      expect(route.points.last, const Offset(19.1, 11.3));
      expectOrthogonal(route.points);
      expect(route.points[1].dy, 0.7, reason: 'leaves along the pin axis');
    });
  });

  group('handles', () {
    test('two pins facing each other have one movable run', () {
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 10.16),
        toExit: left,
      );

      expect(route.handles, hasLength(1));
      expect(route.handles.single.moveAxis, WireAxis.horizontal);
    });

    test('two pins both facing up share a run that moves vertically', () {
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: up,
        to: const Offset(20.32, 10.16),
        toExit: up,
      );

      expect(route.handles, hasLength(1));
      expect(route.handles.single.moveAxis, WireAxis.vertical);
    });

    test('an L has two movable runs, one per corner', () {
      // A diode's sideways pin joined to a capacitor's upward one: the case
      // that used to have no movable run at all.
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 20.32),
        toExit: up,
      );

      expect(route.handles, hasLength(2));
      expect(
        route.handles.map((h) => h.moveAxis).toSet(),
        {WireAxis.horizontal, WireAxis.vertical},
        reason: 'each corner is adjustable on its own axis',
      );
      expect(route.handles.map((h) => h.offsetIndex), [0, 1]);
    });

    test('a run always slides perpendicular to itself', () {
      final route = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 20.32),
        toExit: up,
        offsets: const [5.08, 5.08],
      );

      for (final handle in route.handles) {
        final isVerticalRun = (handle.start.dx - handle.end.dx).abs() < 1e-6;
        expect(
          handle.moveAxis,
          isVerticalRun ? WireAxis.horizontal : WireAxis.vertical,
          reason: 'a vertical run moves sideways, and vice versa',
        );
      }
    });
  });

  group('offsets', () {
    test('an offset moves the run and leaves the ends attached', () {
      const from = Offset(0, 0);
      const to = Offset(20.32, 10.16);

      final plain = WireRouter.route(
        from: from,
        fromExit: right,
        to: to,
        toExit: left,
      );
      final moved = WireRouter.route(
        from: from,
        fromExit: right,
        to: to,
        toExit: left,
        offsets: const [5.08],
      );

      expect(moved.points.first, from);
      expect(moved.points.last, to);
      expectOrthogonal(moved.points);
      expect(moved.points, isNot(equals(plain.points)));
      expect(
        moved.handles.single.start.dx - plain.handles.single.start.dx,
        closeTo(5.08, 1e-6),
      );
    });

    test('zero offsets give exactly the automatic route', () {
      final auto = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 20.32),
        toExit: up,
      );
      final zeroed = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 20.32),
        toExit: up,
        offsets: const [0, 0],
      );

      expect(zeroed.points, auto.points);
    });

    test('an L nudged back into line collapses to a straight route', () {
      // Straightening is the point of adjusting a wire: when the corners
      // meet, the redundant points have to disappear rather than leave a
      // zero-length kink behind.
      const from = Offset(0, 0);
      const to = Offset(20.32, 20.32);
      final plain = WireRouter.route(
        from: from,
        fromExit: right,
        to: to,
        toExit: up,
      );
      final corners = plain.points.length;

      final straightened = WireRouter.route(
        from: from,
        fromExit: right,
        to: to,
        toExit: up,
        offsets: const [0, 0],
      );

      expect(straightened.points.length, corners);
      expectOrthogonal(straightened.points);
    });

    test('missing offsets are treated as zero', () {
      final partial = WireRouter.route(
        from: const Offset(0, 0),
        fromExit: right,
        to: const Offset(20.32, 20.32),
        toExit: up,
        offsets: const [5.08],
      );

      expectOrthogonal(partial.points);
      expect(partial.points.last, const Offset(20.32, 20.32));
    });
  });

  test('of two equally valid crossings, the one clear of a symbol wins', () {
    // A block sitting where the halfway crossing would run, but clear of
    // the horizontal runs at either pin's height, so an alternative exists.
    final blocked = Rect.fromLTRB(8, 2, 12, 8);

    final route = WireRouter.route(
      from: const Offset(0, 0),
      fromExit: right,
      to: const Offset(20.32, 10.16),
      toExit: left,
      obstacles: [blocked],
    );

    expectOrthogonal(route.points);
    for (var i = 0; i < route.points.length - 1; i++) {
      final a = route.points[i];
      final b = route.points[i + 1];
      final crosses =
          [a.dx, b.dx].reduce((x, y) => x < y ? x : y) < blocked.right - 1e-6 &&
          [a.dx, b.dx].reduce((x, y) => x > y ? x : y) > blocked.left + 1e-6 &&
          [a.dy, b.dy].reduce((x, y) => x < y ? x : y) <
              blocked.bottom - 1e-6 &&
          [a.dy, b.dy].reduce((x, y) => x > y ? x : y) > blocked.top + 1e-6;
      expect(crosses, isFalse, reason: 'segment $a -> $b is blocked');
    }
  });

  test('a route never repeats a point', () {
    final route = WireRouter.route(
      from: const Offset(0, 0),
      fromExit: right,
      to: const Offset(40, 25),
      toExit: left,
    );

    for (var i = 0; i < route.points.length - 1; i++) {
      expect((route.points[i] - route.points[i + 1]).distance, greaterThan(0));
    }
  });

  group('routing around a symbol', () {
    /// A MOSFET-shaped part: gate out to the left, drain up, source down,
    /// with the body between them. The reported case — joining drain to
    /// gate drew the wire straight through the transistor, where it could
    /// not be grabbed again because the symbol sits on top of it.
    const body = Rect.fromLTRB(20, 20, 28, 32);
    const gate = Offset(20, 26);
    const gateExit = Offset(-1, 0);
    const drain = Offset(26, 20);
    const drainExit = Offset(0, -1);

    test('a wire between two pins of one part stays outside it', () {
      final route = WireRouter.route(
        from: gate,
        fromExit: gateExit,
        to: drain,
        toExit: drainExit,
        obstacles: const [body],
      );

      for (var i = 0; i < route.points.length - 1; i++) {
        expect(
          _crossesRect(route.points[i], route.points[i + 1], body),
          isFalse,
          reason:
              'segment ${route.points[i]} → ${route.points[i + 1]} '
              'cuts through the symbol',
        );
      }
    });

    test('it still starts and ends on its pins', () {
      final route = WireRouter.route(
        from: gate,
        fromExit: gateExit,
        to: drain,
        toExit: drainExit,
        obstacles: const [body],
      );

      expect(route.points.first, gate);
      expect(route.points.last, drain);
    });

    test('every segment stays orthogonal while dodging', () {
      final route = WireRouter.route(
        from: gate,
        fromExit: gateExit,
        to: drain,
        toExit: drainExit,
        obstacles: const [body],
      );

      for (var i = 0; i < route.points.length - 1; i++) {
        final a = route.points[i];
        final b = route.points[i + 1];
        expect(
          (a.dx - b.dx).abs() < 1e-9 || (a.dy - b.dy).abs() < 1e-9,
          isTrue,
          reason: 'diagonal segment $a → $b',
        );
      }
    });

    test('the dodged wire is still adjustable', () {
      // Without handles there is no way to tidy the detour by hand, which
      // was half of what made the original bug so awkward.
      final route = WireRouter.route(
        from: gate,
        fromExit: gateExit,
        to: drain,
        toExit: drainExit,
        obstacles: const [body],
      );

      expect(route.handles, isNotEmpty);
      for (final handle in route.handles) {
        expect(handle.distanceTo(handle.start), lessThan(1e-6));
      }
    });

    test('an unobstructed wire is routed exactly as before', () {
      // The detour must not become the normal case: two pins with nothing
      // between them get the same single-corner route they always had.
      final clear = WireRouter.route(
        from: const Offset(10, 10),
        fromExit: const Offset(-1, 0),
        to: const Offset(40, 30),
        toExit: const Offset(0, -1),
      );
      final withDistantObstacle = WireRouter.route(
        from: const Offset(10, 10),
        fromExit: const Offset(-1, 0),
        to: const Offset(40, 30),
        toExit: const Offset(0, -1),
        obstacles: const [Rect.fromLTRB(100, 100, 120, 120)],
      );

      expect(withDistantObstacle.points, clear.points);
    });

    test('a same-axis wire also dodges', () {
      // Two pins both facing left, with a symbol between them.
      final route = WireRouter.route(
        from: const Offset(10, 25),
        fromExit: const Offset(-1, 0),
        to: const Offset(40, 27),
        toExit: const Offset(-1, 0),
        obstacles: const [Rect.fromLTRB(0, 20, 8, 32)],
      );

      for (var i = 0; i < route.points.length - 1; i++) {
        expect(
          _crossesRect(
            route.points[i],
            route.points[i + 1],
            const Rect.fromLTRB(0, 20, 8, 32),
          ),
          isFalse,
        );
      }
    });
  });
}

/// Whether an axis-aligned segment passes through a rectangle's interior.
bool _crossesRect(Offset a, Offset b, Rect rect) {
  final left = math.min(a.dx, b.dx);
  final right = math.max(a.dx, b.dx);
  final top = math.min(a.dy, b.dy);
  final bottom = math.max(a.dy, b.dy);

  const epsilon = 1e-6;
  return left < rect.right - epsilon &&
      right > rect.left + epsilon &&
      top < rect.bottom - epsilon &&
      bottom > rect.top + epsilon;
}
