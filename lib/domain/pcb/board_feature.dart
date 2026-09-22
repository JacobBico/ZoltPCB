import 'dart:math' as math;
import 'dart:ui';

import '../models/models.dart';
import '../symbols/symbols.dart' show StrokeStyle;
import 'board.dart';
import 'board_layer.dart';
import 'footprint.dart';

/// The board-only things every real board has and no schematic shows.
enum BoardFeatureKind {
  /// A hole for a screw or a standoff. Unplated by default; plated, it has
  /// a copper ring that can be tied to a net, usually ground.
  mountingHole('Mounting hole', 'H'),

  /// A bare copper dot with a wide opening in the mask, for the assembly
  /// machine's camera to find the board by. Three, in the corners, is the
  /// usual number.
  fiducial('Fiducial', 'FID'),

  /// A pad on a net for a probe to touch.
  testPoint('Test point', 'TP');

  const BoardFeatureKind(this.label, this.prefix);

  final String label;

  /// The designator prefix, as KiCad's own library uses.
  final String prefix;

  static BoardFeatureKind byName(String? name) =>
      values.where((k) => k.name == name).firstOrNull ?? mountingHole;
}

/// One mounting hole, fiducial or test point.
///
/// Stored on its own rather than as a schematic part, and turned into a
/// footprint when the board is built — so pours clear round it, the drill
/// file drills it, the design rule check checks it and the editor moves it,
/// all without knowing it is anything special.
class BoardFeature {
  const BoardFeature({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.reference,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.back = false,
    this.size = 3.2,
    this.plated = false,
    this.netId,
    this.netName = '',
    this.placed = true,
  });

  /// The prefix a feature's footprint and part ids carry, so the rest of
  /// the app can tell one from a schematic part's footprint.
  static const idPrefix = 'feature:';

  static bool isFeatureId(String id) => id.startsWith(idPrefix);
  static String featureIdOf(String id) => id.substring(idPrefix.length);

  /// Common sizes: M2, M2.5, M3, M4 clearance holes, and the usual fiducial
  /// and test pad diameters.
  static const holeSizes = {'M2': 2.2, 'M2.5': 2.7, 'M3': 3.2, 'M4': 4.3};

  static double defaultSize(BoardFeatureKind kind) => switch (kind) {
    BoardFeatureKind.mountingHole => 3.2,
    BoardFeatureKind.fiducial => 1.0,
    BoardFeatureKind.testPoint => 1.5,
  };

  final String id;
  final String projectId;
  final BoardFeatureKind kind;
  final String reference;
  final double x;
  final double y;
  final double rotation;

  /// On the underside. A fiducial or test point can be on either side; a
  /// hole goes through, so for one this only moves its label.
  final bool back;

  /// Hole diameter for a mounting hole, copper diameter otherwise.
  final double size;

  /// A mounting hole with a copper ring round it.
  final bool plated;

  final String? netId;
  final String netName;

  /// False once removed from the board, kept so undo can put it back.
  final bool placed;

  Offset get position => Offset(x, y);

  bool get hasNet =>
      kind == BoardFeatureKind.testPoint ||
      (kind == BoardFeatureKind.mountingHole && plated);

  /// The copper ring of a plated hole: the proportion KiCad's own
  /// `MountingHole_3.2mm_M3_Pad` uses, 6 mm round a 3.2 mm hole.
  double get padDiameter => switch (kind) {
    BoardFeatureKind.mountingHole => plated ? size * 1.875 : size,
    _ => size,
  };

  /// The mask opening round a fiducial, twice its copper, so the camera
  /// sees bare copper on a clean ring of board.
  double get maskMargin => kind == BoardFeatureKind.fiducial ? size / 2 : 0;

  String _mm(double v) {
    final text = v.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// Named the way KiCad's own libraries name the same thing.
  String get footprintName => switch (kind) {
    BoardFeatureKind.mountingHole =>
      'MountingHole_${_mm(size)}mm${plated ? '_Pad' : ''}',
    BoardFeatureKind.fiducial =>
      'Fiducial_${_mm(size)}mm_Mask${_mm(size * 2)}mm',
    BoardFeatureKind.testPoint => 'TestPoint_Pad_D${_mm(size)}mm',
  };

  String get libId => 'HintPCB:$footprintName';

  String get value => switch (kind) {
    BoardFeatureKind.mountingHole => 'MountingHole',
    BoardFeatureKind.fiducial => 'Fiducial',
    BoardFeatureKind.testPoint => netName.isEmpty ? 'TestPoint' : netName,
  };

  /// The footprint the board is built with.
  FootprintDefinition get definition {
    final pad = switch (kind) {
      BoardFeatureKind.mountingHole => Pad(
        number: plated ? '1' : '',
        type: plated ? PadType.thruHole : PadType.npth,
        shape: PadShape.circle,
        at: const FootprintPoint(0, 0),
        sizeX: padDiameter,
        sizeY: padDiameter,
        drill: size,
        // Unplated too: KiCad lists copper for a bare hole so pours clear
        // round it, and puts no copper there.
        layers: const [
          BoardLayer.frontCopper,
          BoardLayer.backCopper,
          BoardLayer.frontMask,
          BoardLayer.backMask,
        ],
        rawLayers: const ['*.Cu', '*.Mask'],
      ),
      BoardFeatureKind.fiducial || BoardFeatureKind.testPoint => Pad(
        number: kind == BoardFeatureKind.testPoint ? '1' : '',
        type: PadType.smd,
        shape: PadShape.circle,
        at: const FootprintPoint(0, 0),
        sizeX: size,
        sizeY: size,
        maskMargin: maskMargin,
        layers: const [BoardLayer.frontCopper, BoardLayer.frontMask],
        rawLayers: const ['F.Cu', 'F.Mask'],
      ),
    };
    // A courtyard just clear of the copper, so parts cannot be placed on
    // top of it, and the screw head's room round a mounting hole.
    final keep = switch (kind) {
      BoardFeatureKind.mountingHole => math.max(padDiameter, size * 1.9) / 2,
      BoardFeatureKind.fiducial => size + 0.25,
      BoardFeatureKind.testPoint => size / 2 + 0.25,
    };
    return FootprintDefinition(
      libraryNickname: 'HintPCB',
      name: footprintName,
      description: '${kind.label}, made by HintPCB',
      pads: [pad],
      graphics: [
        FootprintCircle(
          center: const FootprintPoint(0, 0),
          end: FootprintPoint(keep, 0),
          layer: BoardLayer.frontCourtyard,
          stroke: const StrokeStyle(width: 0.05),
        ),
      ],
      attributes: [
        if (kind != BoardFeatureKind.mountingHole) 'smd',
        'exclude_from_pos_files',
        'exclude_from_bom',
      ],
    );
  }

  /// As a footprint on the board.
  PlacedFootprintRef get ref => PlacedFootprintRef(
    id: '$idPrefix$id',
    projectId: projectId,
    partId: '$idPrefix$id',
    libId: libId,
    x: x,
    y: y,
    rotation: rotation,
    flipped: back && kind != BoardFeatureKind.mountingHole,
    placed: placed,
  );

  /// The part a board footprint belongs to. Out of the BOM: nothing is
  /// bought for a hole or a bare pad.
  Part get part => Part(
    id: '$idPrefix$id',
    projectId: projectId,
    libId: libId,
    reference: reference,
    value: value,
    createdAt: DateTime(2000),
    inBom: false,
  );

  BoardFeature copyWith({
    double? x,
    double? y,
    double? rotation,
    bool? back,
    double? size,
    bool? plated,
    String? netId,
    bool clearNet = false,
    String? netName,
    String? reference,
    bool? placed,
  }) => BoardFeature(
    id: id,
    projectId: projectId,
    kind: kind,
    reference: reference ?? this.reference,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    back: back ?? this.back,
    size: size ?? this.size,
    plated: plated ?? this.plated,
    netId: clearNet ? null : (netId ?? this.netId),
    netName: clearNet ? '' : (netName ?? this.netName),
    placed: placed ?? this.placed,
  );

  @override
  String toString() => 'BoardFeature($reference, ${kind.name})';
}

/// A measurement drawn on the board: two points and the distance between
/// them, set off to one side.
class BoardDimension {
  const BoardDimension({
    required this.id,
    required this.projectId,
    required this.start,
    required this.end,
    this.offset = 3,
  });

  final String id;
  final String projectId;
  final Offset start;
  final Offset end;

  /// How far the dimension line sits from the measured points,
  /// perpendicular to them; negative puts it on the other side.
  final double offset;

  double get length => (end - start).distance;

  /// The unit normal the dimension line is offset along.
  Offset get normal {
    final d = end - start;
    final l = d.distance;
    if (l < 1e-9) return const Offset(0, -1);
    return Offset(d.dy / l, -d.dx / l);
  }

  /// The dimension line's own two ends, [offset] from the measured points.
  (Offset, Offset) get line => (start + normal * offset, end + normal * offset);

  String get text => '${length.toStringAsFixed(2)} mm';

  BoardDimension copyWith({Offset? start, Offset? end, double? offset}) =>
      BoardDimension(
        id: id,
        projectId: projectId,
        start: start ?? this.start,
        end: end ?? this.end,
        offset: offset ?? this.offset,
      );
}
