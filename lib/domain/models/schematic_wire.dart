import 'dart:ui' show Offset;

/// A schematic wire as the user drew it: corners at right angles.
///
/// Connectivity is still the net's business. This is only the drawing of
/// part of it, kept so that the wire looks — on the phone and in the file —
/// exactly the way it was laid, instead of being re-routed every time.
class SchematicWire {
  const SchematicWire({
    required this.id,
    required this.projectId,
    required this.netId,
    required this.points,
    this.pinAId,
    this.pinBId,
  });

  final String id;
  final String projectId;
  final String netId;

  /// The pin at the first point, which the wire follows when the part moves.
  /// Null when that end was left on another wire rather than on a pin.
  final String? pinAId;

  /// The pin at the last point.
  final String? pinBId;

  /// Corners in sheet millimetres, first to last.
  final List<Offset> points;

  SchematicWire copyWith({String? netId, List<Offset>? points}) =>
      SchematicWire(
        id: id,
        projectId: projectId,
        netId: netId ?? this.netId,
        pinAId: pinAId,
        pinBId: pinBId,
        points: points ?? this.points,
      );

  /// `x,y;x,y`, the way the points are stored.
  static String encode(List<Offset> points) =>
      [for (final p in points) '${_n(p.dx)},${_n(p.dy)}'].join(';');

  static List<Offset> decode(String text) => [
    for (final pair in text.split(';'))
      if (pair.contains(','))
        Offset(
          double.parse(pair.split(',')[0]),
          double.parse(pair.split(',')[1]),
        ),
  ];

  static String _n(double v) {
    final rounded = (v * 10000).round() / 10000;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : '$rounded';
  }

  @override
  String toString() => 'SchematicWire($id, ${points.length} points)';
}
