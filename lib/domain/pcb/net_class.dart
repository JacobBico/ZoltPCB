/// A named set of routing rules nets can be put in.
///
/// "Power traces, 0.5 mm" rather than a bare 0.5 in a list: the name is
/// what says why a track is that wide, and it is what KiCad calls the same
/// thing, so it survives the export.
class NetClass {
  const NetClass({
    required this.id,
    required this.projectId,
    required this.name,
    required this.trackWidth,
    this.clearance,
  });

  final String id;
  final String projectId;
  final String name;

  /// Width new track on a net in this class is drawn at, in millimetres.
  final double trackWidth;

  /// Gap this class's copper needs from other nets. Null keeps the board's
  /// own design rule.
  final double? clearance;

  /// `Power traces – 0.50 mm`.
  String get label => '$name – ${_mm(trackWidth)} mm';

  NetClass copyWith({
    String? name,
    double? trackWidth,
    double? clearance,
    bool clearClearance = false,
  }) => NetClass(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearClearance ? null : (clearance ?? this.clearance),
  );

  static String _mm(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed;
  }

  @override
  bool operator ==(Object other) =>
      other is NetClass &&
      other.id == id &&
      other.name == name &&
      other.trackWidth == trackWidth &&
      other.clearance == clearance;

  @override
  int get hashCode => Object.hash(id, name, trackWidth, clearance);

  @override
  String toString() => 'NetClass($name, $trackWidth)';
}
