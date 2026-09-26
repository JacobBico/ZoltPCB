import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_outline.dart';
import 'board_zone.dart';
import 'teardrop.dart';
import 'stackup.dart';

/// The manufacturing constraints a board is drawn against.
///
/// Deliberately the same four numbers KiCad puts in front of you first.
/// Everything else in its dialog — differential pairs, teardrops, per-net
/// classes — is desktop work on a design that has already been laid out.
class DesignRules {
  const DesignRules({
    this.trackWidth = 0.25,
    this.clearance = 0.2,
    this.viaDiameter = 0.8,
    this.viaDrill = 0.4,
    this.padConnection = PadConnection.thermal,
    this.viaConnection = PadConnection.solid,
    this.thermalGap = 0.5,
    this.thermalSpoke = 0.5,
  });

  /// Width of a newly drawn track, in millimetres.
  final double trackWidth;

  /// Minimum copper-to-copper gap, in millimetres.
  final double clearance;

  final double viaDiameter;
  final double viaDrill;

  /// How a new pour joins the pads, and the vias and plated holes, of its
  /// own net.
  ///
  /// A pad is soldered by hand, so it gets a thermal relief by default: a
  /// plane behind it drinks the iron's heat and the joint never wets. A
  /// via is not soldered by anything, so it is poured solid — which is
  /// also what makes a stitching via worth placing.
  final PadConnection padConnection;
  final PadConnection viaConnection;

  /// The gap a thermal relief leaves, and the width of each of the four
  /// spokes that bridge it.
  final double thermalGap;
  final double thermalSpoke;

  /// The default rules: 0.25 mm track and 0.2 mm space, which every board
  /// house on earth will make, and an 0.8/0.4 via to match.
  static const conservative = DesignRules();

  /// Whether the numbers make a board that can physically exist.
  ///
  /// A via whose hole is wider than its pad is not a tight tolerance, it is
  /// a hole with no copper round it.
  String? get problem {
    if (trackWidth <= 0) return 'Track width must be greater than zero';
    if (clearance < 0) return 'Clearance cannot be negative';
    if (viaDrill <= 0) return 'Via drill must be greater than zero';
    if (viaDiameter <= viaDrill) {
      return 'Via diameter must be larger than its drill';
    }
    if (thermalGap <= 0) return 'The thermal gap must be greater than zero';
    if (thermalSpoke <= 0) {
      return 'The thermal spoke must be greater than zero';
    }
    return null;
  }

  DesignRules copyWith({
    double? trackWidth,
    double? clearance,
    double? viaDiameter,
    double? viaDrill,
    PadConnection? padConnection,
    PadConnection? viaConnection,
    double? thermalGap,
    double? thermalSpoke,
  }) => DesignRules(
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearance ?? this.clearance,
    viaDiameter: viaDiameter ?? this.viaDiameter,
    viaDrill: viaDrill ?? this.viaDrill,
    padConnection: padConnection ?? this.padConnection,
    viaConnection: viaConnection ?? this.viaConnection,
    thermalGap: thermalGap ?? this.thermalGap,
    thermalSpoke: thermalSpoke ?? this.thermalSpoke,
  );

  @override
  bool operator ==(Object other) =>
      other is DesignRules &&
      other.trackWidth == trackWidth &&
      other.clearance == clearance &&
      other.viaDiameter == viaDiameter &&
      other.viaDrill == viaDrill &&
      other.padConnection == padConnection &&
      other.viaConnection == viaConnection &&
      other.thermalGap == thermalGap &&
      other.thermalSpoke == thermalSpoke;

  @override
  int get hashCode => Object.hash(
    trackWidth,
    clearance,
    viaDiameter,
    viaDrill,
    padConnection,
    viaConnection,
    thermalGap,
    thermalSpoke,
  );
}

/// A project's board: where its edges are and what rules it is drawn to.
class Board {
  const Board({
    required this.id,
    required this.projectId,
    required this.outlineX,
    required this.outlineY,
    required this.outlineWidth,
    required this.outlineHeight,
    required this.rules,
    required this.gridMm,
    required this.modifiedAt,
    this.outlineKind = BoardOutlineKind.rectangle,
    this.outlinePoints = const [],
    this.trackWidths = const [],
    this.viaSizes = const [],
    this.copperLayerCount = 2,
    this.thickness = 1.6,
    this.teardrops = const TeardropRules(),
    Stackup? customStackup,
  }) : _stackup = customStackup;

  final String id;
  final String projectId;

  /// How many copper layers the board is built with: 2, 4, 6 or 8.
  final int copperLayerCount;

  /// Finished thickness, in millimetres.
  final double thickness;

  /// The fillets drawn where a track meets a pad or a via.
  final TeardropRules teardrops;

  final Stackup? _stackup;

  /// Whether the build has been set up by hand rather than worked out.
  bool get hasCustomStackup => _stackup != null;

  /// The layer build-up: what was set up, or the standard build for this
  /// many layers at this thickness.
  Stackup get stackup =>
      _stackup ??
      Stackup.standard(layerCount: copperLayerCount, thickness: thickness);

  /// The copper layers, top to bottom.
  List<CopperLayer> get copperLayers => CopperLayer.stack(copperLayerCount);

  /// The layer after [layer] going down the board, wrapping back to the
  /// top — what the routing layer button steps through.
  CopperLayer nextLayer(CopperLayer layer) {
    final layers = copperLayers;
    final index = layers.indexOf(layer);
    return layers[(index + 1) % layers.length];
  }

  /// Whether [layer] exists on this board.
  bool hasLayer(CopperLayer layer) => copperLayers.contains(layer);

  /// The outline's bounding box, in board millimetres.
  final double outlineX;
  final double outlineY;
  final double outlineWidth;
  final double outlineHeight;

  final BoardOutlineKind outlineKind;

  /// Polygon vertices. Empty for the other shapes.
  final List<Offset> outlinePoints;

  /// The board edge as a shape, which is what everything but storage wants.
  BoardOutline get outline => switch (outlineKind) {
    BoardOutlineKind.rectangle => BoardOutline.rectangle(_boundsRect),
    BoardOutlineKind.circle => BoardOutline.circle(_boundsRect),
    BoardOutlineKind.none => BoardOutline.none(_boundsRect),
    BoardOutlineKind.polygon =>
      outlinePoints.length >= 3
          ? BoardOutline.polygon(outlinePoints)
          // A polygon that lost its points is not a shape at all; falling back
          // to the box keeps the board drawable rather than blank.
          : BoardOutline.rectangle(_boundsRect),
  };

  Rect get _boundsRect =>
      Rect.fromLTWH(outlineX, outlineY, outlineWidth, outlineHeight);

  /// The same board carrying [outline] instead.
  Board withOutline(BoardOutline outline) => Board(
    id: id,
    projectId: projectId,
    outlineX: outline.rect.left,
    outlineY: outline.rect.top,
    outlineWidth: outline.rect.width,
    outlineHeight: outline.rect.height,
    outlineKind: outline.kind,
    outlinePoints: outline.kind == BoardOutlineKind.polygon
        ? outline.points
        : const [],
    rules: rules,
    trackWidths: trackWidths,
    viaSizes: viaSizes,
    gridMm: gridMm,
    modifiedAt: modifiedAt,
    copperLayerCount: copperLayerCount,
    thickness: thickness,
    customStackup: _stackup,
  );

  final DesignRules rules;

  /// Track widths set up in advance, to be picked from while routing.
  ///
  /// KiCad keeps the same list in Board Setup, and for the same reason: a
  /// board has a handful of widths on it — signal, power, and whatever the
  /// one high-current track needs — and choosing between them should be a
  /// tap, not a number typed afresh each time.
  final List<double> trackWidths;

  /// Via sizes set up in advance, as (diameter, drill) pairs.
  final List<ViaSize> viaSizes;

  /// The widths offered while routing: the ones set up, plus the design
  /// rule, which is always available whether or not it was listed.
  List<double> get availableTrackWidths {
    final all = {rules.trackWidth, ...trackWidths}.toList()..sort();
    return all;
  }

  List<ViaSize> get availableViaSizes {
    final all = <ViaSize>{
      ViaSize(rules.viaDiameter, rules.viaDrill),
      ...viaSizes,
    }.toList()..sort((a, b) => a.diameter.compareTo(b.diameter));
    return all;
  }

  /// The grid placement and routing snap to.
  final double gridMm;

  final DateTime modifiedAt;

  double get right => outlineX + outlineWidth;
  double get bottom => outlineY + outlineHeight;

  Board copyWith({
    double? outlineX,
    double? outlineY,
    double? outlineWidth,
    double? outlineHeight,
    BoardOutlineKind? outlineKind,
    List<Offset>? outlinePoints,
    DesignRules? rules,
    List<double>? trackWidths,
    List<ViaSize>? viaSizes,
    double? gridMm,
    int? copperLayerCount,
    double? thickness,
    TeardropRules? teardrops,
    Stackup? stackup,
    bool clearStackup = false,
  }) => Board(
    id: id,
    projectId: projectId,
    outlineX: outlineX ?? this.outlineX,
    outlineY: outlineY ?? this.outlineY,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    outlineHeight: outlineHeight ?? this.outlineHeight,
    outlineKind: outlineKind ?? this.outlineKind,
    outlinePoints: outlinePoints ?? this.outlinePoints,
    rules: rules ?? this.rules,
    trackWidths: trackWidths ?? this.trackWidths,
    viaSizes: viaSizes ?? this.viaSizes,
    gridMm: gridMm ?? this.gridMm,
    modifiedAt: modifiedAt,
    copperLayerCount: copperLayerCount ?? this.copperLayerCount,
    thickness: thickness ?? this.thickness,
    teardrops: teardrops ?? this.teardrops,
    customStackup: clearStackup ? null : (stackup ?? _stackup),
  );
}

/// One entry in the board's list of via sizes.
class ViaSize {
  const ViaSize(this.diameter, this.drill);

  final double diameter;
  final double drill;

  /// Whether it is a hole with copper round it rather than just a hole.
  bool get isValid => drill > 0 && diameter > drill;

  @override
  bool operator ==(Object other) =>
      other is ViaSize && other.diameter == diameter && other.drill == drill;

  @override
  int get hashCode => Object.hash(diameter, drill);

  @override
  String toString() => '$diameter/$drill';
}

/// One part's footprint, positioned on the board.
class PlacedFootprintRef {
  const PlacedFootprintRef({
    required this.id,
    required this.projectId,
    required this.partId,
    required this.libId,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.flipped = false,
    this.placed = false,
    this.labelOffset,
    this.labelSize = 1.0,
    this.labelHidden = false,
    this.locked = false,
  });

  final String id;
  final String projectId;
  final String partId;

  /// Held where it is. A connector that has to line up with a hole in a
  /// case gets locked once, and then stays put through every later pass of
  /// nudging everything else around it.
  final bool locked;

  /// Where the reference designator sits once moved, in the footprint's own
  /// frame. Null leaves it where the library put it.
  final Offset? labelOffset;

  /// Designator character height, in millimetres.
  final double labelSize;

  /// Left off the silkscreen.
  final bool labelHidden;

  /// `Resistor_SMD:R_0805_2012Metric`.
  final String libId;

  final double x;
  final double y;

  /// Degrees counter-clockwise.
  final double rotation;

  /// Mounted on the back of the board.
  final bool flipped;

  /// False until the user has put it somewhere; unplaced footprints wait
  /// off the board rather than piling up on the origin.
  final bool placed;

  CopperLayer get side => flipped ? CopperLayer.back : CopperLayer.front;

  PlacedFootprintRef copyWith({
    String? libId,
    double? x,
    double? y,
    double? rotation,
    bool? flipped,
    bool? placed,
    Offset? labelOffset,
    bool clearLabelOffset = false,
    double? labelSize,
    bool? labelHidden,
    bool? locked,
  }) => PlacedFootprintRef(
    id: id,
    projectId: projectId,
    partId: partId,
    libId: libId ?? this.libId,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    flipped: flipped ?? this.flipped,
    placed: placed ?? this.placed,
    labelOffset: clearLabelOffset ? null : (labelOffset ?? this.labelOffset),
    labelSize: labelSize ?? this.labelSize,
    labelHidden: labelHidden ?? this.labelHidden,
    locked: locked ?? this.locked,
  );
}

/// One straight run of copper.
class Track {
  const Track({
    required this.id,
    required this.projectId,
    required this.layer,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.width,
    this.netId,
    this.locked = false,
  });

  final String id;
  final String projectId;

  /// The net this copper belongs to. Null only for a segment drawn where no
  /// net could be worked out — which the board reports rather than hides.
  final String? netId;

  final CopperLayer layer;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double width;

  /// Held where it is. A locked track is not picked up, not slid, and not
  /// swept into a move or a delete — which is what makes a carefully
  /// tuned run survive the next hour of layout.
  final bool locked;

  /// The same segment with some of its numbers changed.
  ///
  /// Every one of them is editable on purpose: a board where one track can
  /// be a little wider, or a corner nudged a tenth of a millimetre, is the
  /// difference between laying out a board and accepting one.
  Track copyWith({
    String? id,
    CopperLayer? layer,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    double? width,
    String? netId,
    bool clearNet = false,
    bool? locked,
  }) => Track(
    id: id ?? this.id,
    projectId: projectId,
    layer: layer ?? this.layer,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    endX: endX ?? this.endX,
    endY: endY ?? this.endY,
    width: width ?? this.width,
    netId: clearNet ? null : (netId ?? this.netId),
    locked: locked ?? this.locked,
  );

  Track withNet(String? netId) => Track(
    id: id,
    projectId: projectId,
    netId: netId,
    layer: layer,
    startX: startX,
    startY: startY,
    endX: endX,
    endY: endY,
    width: width,
    locked: locked,
  );

  double get lengthMm {
    final dx = endX - startX;
    final dy = endY - startY;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// How far through the board a via is drilled.
enum ViaKind {
  /// Top to bottom. The only kind that costs nothing extra, and the only
  /// kind most boards should have.
  through('Through', 'Top to bottom — no extra cost'),

  /// From an outside layer to an inner one. Drilled before the board is
  /// pressed together, so the fab charges for the extra lamination.
  blind('Blind', 'Outside layer to an inner one'),

  /// Between two inner layers, invisible from either face.
  buried('Buried', 'Between two inner layers');

  const ViaKind(this.label, this.note);

  final String label;
  final String note;

  static ViaKind byName(String? name) =>
      values.where((k) => k.name == name).firstOrNull ?? through;
}

/// A plated hole joining one copper layer to another.
class Via {
  const Via({
    required this.id,
    required this.projectId,
    required this.x,
    required this.y,
    required this.diameter,
    required this.drill,
    this.netId,
    this.kind = ViaKind.through,
    this.fromLayer,
    this.toLayer,
    this.locked = false,
  });

  final String id;
  final String projectId;
  final String? netId;
  final double x;
  final double y;
  final double diameter;
  final double drill;

  final ViaKind kind;

  /// The two layers a blind or buried via joins. Null on a through via,
  /// which always runs the whole way.
  final CopperLayer? fromLayer;
  final CopperLayer? toLayer;

  final bool locked;

  /// The copper layers this via actually reaches on [board].
  ///
  /// A through via reaches every layer the board has. A blind or buried
  /// one reaches the span it was drilled for — and a span that no longer
  /// makes sense, because the board lost layers under it, falls back to
  /// the whole way rather than to nothing.
  List<CopperLayer> layersOn(Board board) {
    final all = board.copperLayers;
    if (kind == ViaKind.through) return all;
    final a = all.indexOf(fromLayer ?? CopperLayer.front);
    final b = all.indexOf(toLayer ?? CopperLayer.back);
    if (a < 0 || b < 0) return all;
    final low = math.min(a, b);
    final high = math.max(a, b);
    return all.sublist(low, high + 1);
  }

  /// Whether the span asked for can be drilled at all.
  String? problemOn(Board board) {
    if (kind == ViaKind.through) return null;
    final all = board.copperLayers;
    final from = fromLayer;
    final to = toLayer;
    if (from == null || to == null) return 'A span needs two layers';
    if (from == to) return 'A via has to join two different layers';
    if (!all.contains(from) || !all.contains(to)) {
      return 'This board does not have those layers';
    }
    final outer = {CopperLayer.front, CopperLayer.back};
    final touchesOutside = outer.contains(from) || outer.contains(to);
    if (kind == ViaKind.blind && !touchesOutside) {
      return 'A blind via has to start on the top or the bottom';
    }
    if (kind == ViaKind.buried && touchesOutside) {
      return 'A buried via cannot reach the top or the bottom';
    }
    return null;
  }

  Via copyWith({
    String? id,
    double? x,
    double? y,
    double? diameter,
    double? drill,
    String? netId,
    bool clearNet = false,
    ViaKind? kind,
    CopperLayer? fromLayer,
    CopperLayer? toLayer,
    bool? locked,
  }) => Via(
    id: id ?? this.id,
    projectId: projectId,
    x: x ?? this.x,
    y: y ?? this.y,
    diameter: diameter ?? this.diameter,
    drill: drill ?? this.drill,
    netId: clearNet ? null : (netId ?? this.netId),
    kind: kind ?? this.kind,
    fromLayer: fromLayer ?? this.fromLayer,
    toLayer: toLayer ?? this.toLayer,
    locked: locked ?? this.locked,
  );

  Via withNet(String? netId) => Via(
    id: id,
    projectId: projectId,
    netId: netId,
    x: x,
    y: y,
    diameter: diameter,
    drill: drill,
    kind: kind,
    fromLayer: fromLayer,
    toLayer: toLayer,
    locked: locked,
  );
}
