import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

void main() {
  group('angle lock', () {
    test('45° snaps a near-diagonal onto the diagonal', () {
      // "my tracing should lock in 45/90 degree angles rather than like 3
      // degrees" — a board routed at arbitrary angles is legal and unreadable.
      const from = Offset(10, 10);
      final to = TrackAngleLock.deg45.constrain(from, const Offset(20, 19));

      expect((to.dx - from.dx).abs(), closeTo((to.dy - from.dy).abs(), 1e-9));
      expect(to.dx, greaterThan(from.dx));
      expect(to.dy, greaterThan(from.dy));
    });

    test('45° still allows the four square directions', () {
      const from = Offset.zero;
      final right = TrackAngleLock.deg45.constrain(from, const Offset(10, 0.4));
      expect(right.dy, closeTo(0, 1e-9));

      final down = TrackAngleLock.deg45.constrain(from, const Offset(0.4, 10));
      expect(down.dx, closeTo(0, 1e-9));
    });

    test('90° refuses a diagonal outright', () {
      final to = TrackAngleLock.deg90.constrain(
        Offset.zero,
        const Offset(10, 9),
      );
      // Onto one axis or the other, never between them.
      expect(to.dx.abs() < 1e-9 || to.dy.abs() < 1e-9, isTrue);
    });

    test('the segment keeps its length rather than being projected', () {
      // Projecting onto the ray shortens a segment towards nothing as the
      // aim swings away from it; sliding round the circle does not.
      const from = Offset.zero;
      const to = Offset(10, 3);
      final locked = TrackAngleLock.deg45.constrain(from, to);
      expect((locked - from).distance, closeTo((to - from).distance, 1e-9));
    });

    test('any leaves the point exactly where it was aimed', () {
      const to = Offset(3.17, 9.02);
      expect(TrackAngleLock.any.constrain(Offset.zero, to), to);
    });

    test('the lock cycles through its three settings', () {
      expect(TrackAngleLock.any.next, TrackAngleLock.deg45);
      expect(TrackAngleLock.deg45.next, TrackAngleLock.deg90);
      expect(TrackAngleLock.deg90.next, TrackAngleLock.any);
    });
  });

  group('rounded corners', () {
    test('a right angle becomes a bend that misses the corner', () {
      const corner = Offset(10, 10);
      final rounded = roundCorners(const [
        Offset(0, 10),
        corner,
        Offset(10, 0),
      ], radius: 2);

      expect(rounded.length, greaterThan(3));
      // The sharp point is gone: nothing on the path reaches the corner.
      for (final point in rounded) {
        expect((point - corner).distance, greaterThan(0.3));
      }
      // And the ends are untouched — a track still starts and finishes on
      // its pads.
      expect(rounded.first, const Offset(0, 10));
      expect(rounded.last, const Offset(10, 0));
    });

    test('the bend stays within the radius asked for', () {
      const corner = Offset(10, 10);
      final rounded = roundCorners(const [
        Offset(0, 10),
        corner,
        Offset(10, 0),
      ], radius: 2);

      // The bend itself, not the endpoints, which are where the track's
      // pads are and are never moved.
      for (final point in rounded.sublist(1, rounded.length - 1)) {
        expect((point - corner).distance, lessThan(3.0));
      }
    });

    test('a radius bigger than the leg is cut down to fit', () {
      // A generous radius on a short jog rounds it as far as it will go
      // rather than overshooting into the segment beyond.
      final rounded = roundCorners(const [
        Offset(0, 0),
        Offset(2, 0),
        Offset(2, 2),
      ], radius: 50);

      for (final point in rounded) {
        expect(point.dx, inInclusiveRange(-0.001, 2.001));
        expect(point.dy, inInclusiveRange(-0.001, 2.001));
      }
    });

    test('a straight run is left alone', () {
      const points = [Offset(0, 0), Offset(5, 0), Offset(10, 0)];
      final rounded = roundCorners(points, radius: 1);
      // Collinear points have no corner to round, so the path keeps its
      // length rather than gaining a pointless flock of vertices.
      expect(rounded.first, points.first);
      expect(rounded.last, points.last);
      for (final point in rounded) {
        expect(point.dy, closeTo(0, 1e-9));
      }
    });

    test('no rounding at all when the radius is zero', () {
      const points = [Offset(0, 10), Offset(10, 10), Offset(10, 0)];
      expect(roundCorners(points, radius: 0), points);
    });

    test('a rounded 45° bend is smooth, not a second sharp corner', () {
      final rounded = roundCorners(const [
        Offset(0, 0),
        Offset(10, 0),
        Offset(20, 10),
      ], radius: 3);

      // Every turn along the path is gentler than the one it replaced.
      var sharpest = 0.0;
      for (var i = 1; i < rounded.length - 1; i++) {
        final a = rounded[i] - rounded[i - 1];
        final b = rounded[i + 1] - rounded[i];
        final angle = (math.atan2(b.dy, b.dx) - math.atan2(a.dy, a.dx)).abs();
        if (angle > sharpest) sharpest = angle;
      }
      expect(sharpest, lessThan(45 * math.pi / 180));
    });
  });

  group('reaching a point on legal angles', () {
    // "when I try to connect to another pad, it just connects straight from
    // pad a to pad b, where it should be like 90 degree straight line and
    // then 45 degree angle into the next pad."
    test('a straight run then a 45 into the target', () {
      const from = Offset(0, 0);
      const to = Offset(10, 3);
      final corners = legalCorners(from, to, TrackAngleLock.deg45);

      expect(corners, hasLength(2));
      // The long axis first, square.
      expect(corners.first, const Offset(7, 0));
      expect(corners.last, to);

      // Every segment on a legal bearing, which is the whole claim.
      final path = [from, ...corners];
      for (var i = 0; i < path.length - 1; i++) {
        final d = path[i + 1] - path[i];
        expect(
          isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45),
          isTrue,
          reason: 'segment $i runs at an illegal angle',
        );
      }
    });

    test('the vertical case picks the other axis', () {
      final corners = legalCorners(
        Offset.zero,
        const Offset(3, 10),
        TrackAngleLock.deg45,
      );
      expect(corners.first, const Offset(0, 7));
      expect(corners.last, const Offset(3, 10));
    });

    test('a pad already on a 45 needs only one segment', () {
      final corners = legalCorners(
        Offset.zero,
        const Offset(5, 5),
        TrackAngleLock.deg45,
      );
      expect(corners, [const Offset(5, 5)]);
    });

    test('a pad square on needs only one segment', () {
      expect(
        legalCorners(Offset.zero, const Offset(8, 0), TrackAngleLock.deg45),
        [const Offset(8, 0)],
      );
    });

    test('90° gives a right-angled dogleg, never a diagonal', () {
      const to = Offset(10, 4);
      final corners = legalCorners(Offset.zero, to, TrackAngleLock.deg90);
      expect(corners, hasLength(2));
      expect(corners.first, const Offset(10, 0));

      final path = [Offset.zero, ...corners];
      for (var i = 0; i < path.length - 1; i++) {
        final d = path[i + 1] - path[i];
        expect(isLegalBearing(d.dx, d.dy, TrackAngleLock.deg90), isTrue);
      }
    });

    test('the diagonal can be put first instead', () {
      final corners = legalCorners(
        Offset.zero,
        const Offset(10, 3),
        TrackAngleLock.deg45,
        diagonalFirst: true,
      );
      expect(corners.first, const Offset(3, 3));
      expect(corners.last, const Offset(10, 3));
    });

    test('any angle takes the direct line', () {
      const to = Offset(10, 3);
      expect(legalCorners(Offset.zero, to, TrackAngleLock.any), [to]);
    });

    test('a pad off the grid still gets a clean 45', () {
      // The real case: an 0805 pad sits at 30.9125 mm and never on a grid.
      // Rounding the corner to the grid afterwards is what turned a 45 into
      // something in the twenties.
      const from = Offset(30.9125, 35);
      const to = Offset(44.0875, 41.5);
      final corners = legalCorners(from, to, TrackAngleLock.deg45);

      final path = [from, ...corners];
      for (var i = 0; i < path.length - 1; i++) {
        final d = path[i + 1] - path[i];
        expect(
          isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45),
          isTrue,
          reason: 'segment $i is at a stray angle',
        );
      }
      expect(path.last, to);
    });

    test('a target on top of the start adds nothing', () {
      expect(
        legalCorners(Offset.zero, Offset.zero, TrackAngleLock.deg45),
        isEmpty,
      );
    });
  });

  group('legal bearings', () {
    test('45 allows the eight compass points and nothing else', () {
      for (final d in const [
        Offset(1, 0),
        Offset(0, 1),
        Offset(1, 1),
        Offset(-1, 1),
        Offset(-3, -3),
      ]) {
        expect(isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45), isTrue);
      }
      for (final d in const [Offset(10, 3), Offset(1, 5), Offset(7, -2)]) {
        expect(isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45), isFalse);
      }
    });

    test('90 allows only the four', () {
      expect(isLegalBearing(1, 1, TrackAngleLock.deg90), isFalse);
      expect(isLegalBearing(1, 0, TrackAngleLock.deg90), isTrue);
      expect(isLegalBearing(0, -4, TrackAngleLock.deg90), isTrue);
    });
  });
}
