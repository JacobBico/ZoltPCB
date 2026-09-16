import 'dart:math' as math;
import 'dart:ui';

/// Geometry that only the renderer needs. Placement and symbol bounds live
/// in the domain layer, because the exporter needs them too.
export '../domain/geometry/placement.dart';

/// A circular arc recovered from the three points KiCad stores.
class ArcGeometry {
  const ArcGeometry({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
  });

  final Offset center;
  final double radius;

  /// Radians, in the same convention as [Canvas.drawArc].
  final double startAngle;
  final double sweepAngle;

  Rect get bounds => Rect.fromCircle(center: center, radius: radius);
}

/// Recovers the circle through three points.
///
/// KiCad stores an arc as start, a point on it, and end — never as a centre
/// and two angles — so every renderer of this format has to solve for the
/// centre. Returns null when the points are collinear, in which case there
/// is no arc and the caller should draw a straight line instead.
ArcGeometry? arcThroughPoints(Offset start, Offset mid, Offset end) {
  final ax = start.dx, ay = start.dy;
  final bx = mid.dx, by = mid.dy;
  final cx = end.dx, cy = end.dy;

  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (d.abs() < 1e-9) return null;

  final aSq = ax * ax + ay * ay;
  final bSq = bx * bx + by * by;
  final cSq = cx * cx + cy * cy;

  final ux = (aSq * (by - cy) + bSq * (cy - ay) + cSq * (ay - by)) / d;
  final uy = (aSq * (cx - bx) + bSq * (ax - cx) + cSq * (bx - ax)) / d;
  final center = Offset(ux, uy);
  final radius = (start - center).distance;

  final startAngle = math.atan2(ay - uy, ax - ux);
  final midAngle = math.atan2(by - uy, bx - ux);
  final endAngle = math.atan2(cy - uy, cx - ux);

  // Sweep from start to end the way round that passes through mid.
  var sweep = endAngle - startAngle;
  var toMid = midAngle - startAngle;
  sweep = _wrapAngle(sweep);
  toMid = _wrapAngle(toMid);
  if ((sweep >= 0) != (toMid >= 0) || toMid.abs() > sweep.abs()) {
    sweep = sweep >= 0 ? sweep - 2 * math.pi : sweep + 2 * math.pi;
  }

  return ArcGeometry(
    center: center,
    radius: radius,
    startAngle: startAngle,
    sweepAngle: sweep,
  );
}

double _wrapAngle(double radians) {
  var value = radians;
  while (value > math.pi) {
    value -= 2 * math.pi;
  }
  while (value < -math.pi) {
    value += 2 * math.pi;
  }
  return value;
}
