import 'dart:math' as math;
import 'dart:ui';

/// What angles a track is allowed to leave a corner at.
///
/// A board routed at arbitrary angles is legal and looks wrong, and more to
/// the point it is hard to read: the eye follows 45s and right angles and
/// stumbles over 3°. KiCad defaults to 45 for the same reason, and so does
/// this.
enum TrackAngleLock {
  any('Any', 0),
  deg45('45°', 45),
  deg90('90°', 90);

  const TrackAngleLock(this.label, this.step);

  final String label;

  /// The angular step allowed, in degrees. Zero means no constraint.
  final int step;

  TrackAngleLock get next =>
      values[(index + 1) % values.length];

  /// [to], moved onto the nearest allowed direction from [from].
  ///
  /// The length is kept: the point slides round the circle rather than
  /// being projected onto the ray, so aiming past a corner does not
  /// shorten the segment to nothing.
  Offset constrain(Offset from, Offset to) {
    if (step == 0) return to;
    final delta = to - from;
    final length = delta.distance;
    if (length < 1e-9) return to;

    final stepRadians = step * math.pi / 180;
    final angle = math.atan2(delta.dy, delta.dx);
    final snapped = (angle / stepRadians).round() * stepRadians;
    return from + Offset(math.cos(snapped), math.sin(snapped)) * length;
  }
}

/// The corners that take a track from [from] to [to] using only the angles
/// [lock] allows.
///
/// This is how KiCad routes, and the reason a board drawn in it never has a
/// 17° segment in it: any two points can be joined by at most two segments —
/// a straight run along an axis and a 45° diagonal — so the cursor can go
/// anywhere while the copper stays on legal angles. Constraining the target
/// point instead, which is the obvious thing to try, means the track simply
/// cannot reach a pad that is not already on a legal bearing.
///
/// Returns the points to append, ending at [to]; [from] is not included.
/// With [diagonalFirst] the bend comes first and the straight run goes into
/// the target, which is KiCad's `/` toggle.
List<Offset> legalCorners(
  Offset from,
  Offset to,
  TrackAngleLock lock, {
  bool diagonalFirst = false,
}) {
  if (lock == TrackAngleLock.any) return [to];

  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  if (dx.abs() < _epsilon && dy.abs() < _epsilon) return const [];

  // Already on a legal bearing: one segment does it.
  if (isLegalBearing(dx, dy, lock)) return [to];

  if (lock == TrackAngleLock.deg90) {
    // A single right-angled dogleg, one way round or the other.
    return diagonalFirst
        ? [Offset(from.dx, to.dy), to]
        : [Offset(to.dx, from.dy), to];
  }

  final adx = dx.abs();
  final ady = dy.abs();
  final sx = dx.isNegative ? -1.0 : 1.0;
  final sy = dy.isNegative ? -1.0 : 1.0;

  if (diagonalFirst) {
    // The diagonal uses up the shorter axis, then a straight run finishes.
    final run = math.min(adx, ady);
    return [Offset(from.dx + sx * run, from.dy + sy * run), to];
  }

  // A straight run along the longer axis, then 45° into the target — which
  // is what "a straight line and then a 45 into the pad" describes.
  return adx > ady
      ? [Offset(from.dx + sx * (adx - ady), from.dy), to]
      : [Offset(from.dx, from.dy + sy * (ady - adx)), to];
}

/// Whether a step of [dx], [dy] is one [lock] permits.
bool isLegalBearing(double dx, double dy, TrackAngleLock lock) {
  if (lock == TrackAngleLock.any) return true;
  final horizontal = dy.abs() < _epsilon;
  final vertical = dx.abs() < _epsilon;
  if (horizontal || vertical) return true;
  if (lock == TrackAngleLock.deg90) return false;
  return (dx.abs() - dy.abs()).abs() < _epsilon;
}

/// A micron. Board geometry is in millimetres, and nothing on a board is
/// meaningfully smaller than this.
const _epsilon = 1e-3;

/// Rounds the corners of a path, so a track can bend rather than turn.
///
/// Real curved copper is an arc, and KiCad can carry one; what comes out of
/// here is a short chain of straight segments approximating it. That is
/// what a fabricator receives in the end anyway — Gerber has no arcs on
/// copper layers beyond G02/G03 arcs that most tools flatten — and it means
/// a curved track is still made of ordinary segments that can be selected,
/// nudged and ripped up one at a time.
///
/// [radius] is clamped per corner to half the shorter of the two legs, so a
/// generous radius on a short jog rounds it as far as it will go rather
/// than overshooting into the segment beyond.
List<Offset> roundCorners(
  List<Offset> points, {
  required double radius,
  int segments = 6,
}) {
  if (points.length < 3 || radius <= 0) return points;

  final result = <Offset>[points.first];

  for (var i = 1; i < points.length - 1; i++) {
    final previous = points[i - 1];
    final corner = points[i];
    final next = points[i + 1];

    final inLength = (corner - previous).distance;
    final outLength = (next - corner).distance;
    if (inLength < 1e-9 || outLength < 1e-9) continue;

    final inDirection = (previous - corner) / inLength;
    final outDirection = (next - corner) / outLength;

    // A corner that does not turn has nothing to round.
    final cross =
        inDirection.dx * outDirection.dy - inDirection.dy * outDirection.dx;
    final dot = inDirection.dx * outDirection.dx + inDirection.dy * outDirection.dy;
    if (cross.abs() < 1e-9 && dot < 0) {
      result.add(corner);
      continue;
    }

    final cut = math.min(radius, math.min(inLength, outLength) / 2);
    final start = corner + inDirection * cut;
    final end = corner + outDirection * cut;

    result.add(start);
    // A quadratic bend through the corner: close enough to an arc at the
    // radii a track is ever rounded by, and it needs no circle solving.
    for (var s = 1; s < segments; s++) {
      final t = s / segments;
      final a = Offset.lerp(start, corner, t)!;
      final b = Offset.lerp(corner, end, t)!;
      result.add(Offset.lerp(a, b, t)!);
    }
    result.add(end);
  }

  result.add(points.last);
  return result;
}
