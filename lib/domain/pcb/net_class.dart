import 'board_layer.dart';
import 'impedance.dart';
import 'stackup.dart';

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
    this.impedance,
  });

  final String id;
  final String projectId;
  final String name;

  /// Width new track on a net in this class is drawn at, in millimetres.
  final double trackWidth;

  /// Gap this class's copper needs from other nets. Null keeps the board's
  /// own design rule.
  final double? clearance;

  /// The impedance this class is routed to, in ohms, or null for a class
  /// that is just a width. With one set, each layer gets the width that
  /// makes it — a 50 Ω track is 0.35 mm on the outside of a four-layer
  /// board and 0.22 mm buried in a six.
  final double? impedance;

  /// The width a track on [layer] of a board built as [stackup] is drawn
  /// at: [trackWidth], or the width that gives [impedance] there.
  double widthOn(Stackup stackup, CopperLayer layer) {
    final target = impedance;
    if (target == null || !stackup.layers.contains(layer)) return trackWidth;
    final width = ImpedanceCalculator.widthFor(stackup, layer, target: target);
    if (width == null) return trackWidth;
    // To the micron: finer than any fab etches, coarse enough to read.
    return (width * 1000).roundToDouble() / 1000;
  }

  /// `Power traces – 0.50 mm`, or `USB – 90 Ω`.
  String get label => impedance == null
      ? '$name – ${_mm(trackWidth)} mm'
      : '$name – ${impedance!.toStringAsFixed(0)} Ω';

  NetClass copyWith({
    String? name,
    double? trackWidth,
    double? clearance,
    bool clearClearance = false,
    double? impedance,
    bool clearImpedance = false,
  }) => NetClass(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearClearance ? null : (clearance ?? this.clearance),
    impedance: clearImpedance ? null : (impedance ?? this.impedance),
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
      other.clearance == clearance &&
      other.impedance == impedance;

  @override
  int get hashCode => Object.hash(id, name, trackWidth, clearance, impedance);

  @override
  String toString() => 'NetClass($name, $trackWidth)';
}
