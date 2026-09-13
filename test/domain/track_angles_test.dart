import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

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
}
