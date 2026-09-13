import 'dart:ui';

/// The ANSI resistor: a zigzag between two points.
///
/// Six peaks, as drawn in every American textbook and in KiCad's own
/// `R_US`. The zigzag's amplitude is a fraction of its length so it keeps
/// its proportions at any size, and it starts and ends on the axis so it
/// joins the pin stubs without a kink.
Path resistorZigzag(Offset from, Offset to, {double widthFraction = 0.18}) {
  const peaks = 6;
  final along = to - from;
  final length = along.distance;
  if (length < 1e-9) return Path();

  final unit = along / length;
  final normal = Offset(-unit.dy, unit.dx);
  final amplitude = length * widthFraction;

  final path = Path()..moveTo(from.dx, from.dy);
  // Each peak takes a whole step; the zigzag swings out on the half steps.
  for (var i = 0; i < peaks; i++) {
    final side = i.isEven ? 1.0 : -1.0;
    final t = (i + 0.5) / peaks;
    final point = from + along * t + normal * (amplitude * side);
    path.lineTo(point.dx, point.dy);
  }
  path.lineTo(to.dx, to.dy);
  return path;
}
