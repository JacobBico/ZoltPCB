import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_outline.dart';

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
  });

  /// Width of a newly drawn track, in millimetres.
  final double trackWidth;

  /// Minimum copper-to-copper gap, in millimetres.
  final double clearance;

  final double viaDiameter;
  final double viaDrill;

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
    return null;
  }

  DesignRules copyWith({
    double? trackWidth,
    double? clearance,
    double? viaDiameter,
    double? viaDrill,
  }) => DesignRules(
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearance ?? this.clearance,
    viaDiameter: viaDiameter ?? this.viaDiameter,
    viaDrill: viaDrill ?? this.viaDrill,
  );

  @override
  bool operator ==(Object other) =>
      other is DesignRules &&
      other.trackWidth == trackWidth &&
      other.clearance == clearance &&
      other.viaDiameter == viaDiameter &&
      other.viaDrill == viaDrill;

  @override
  int get hashCode =>
      Object.hash(trackWidth, clearance, viaDiameter, viaDrill);
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
  });

  final String id;
  final String projectId;

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
    BoardOutlineKind.polygon => outlinePoints.length >= 3
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
  });

  final String id;
  final String projectId;
  final String partId;

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

  /// The same segment with some of its numbers changed.
  ///
  /// Every one of them is editable on purpose: a board where one track can
  /// be a little wider, or a corner nudged a tenth of a millimetre, is the
  /// difference between laying out a board and accepting one.
  Track copyWith({
    CopperLayer? layer,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    double? width,
    String? netId,
    bool clearNet = false,
  }) => Track(
    id: id,
    projectId: projectId,
    layer: layer ?? this.layer,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    endX: endX ?? this.endX,
    endY: endY ?? this.endY,
    width: width ?? this.width,
    netId: clearNet ? null : (netId ?? this.netId),
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
  );

  double get lengthMm {
    final dx = endX - startX;
    final dy = endY - startY;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// A plated hole joining front copper to back.
class Via {
  const Via({
    required this.id,
    required this.projectId,
    required this.x,
    required this.y,
    required this.diameter,
    required this.drill,
    this.netId,
  });

  final String id;
  final String projectId;
  final String? netId;
  final double x;
  final double y;
  final double diameter;
  final double drill;

  Via copyWith({
    double? x,
    double? y,
    double? diameter,
    double? drill,
    String? netId,
    bool clearNet = false,
  }) => Via(
    id: id,
    projectId: projectId,
    x: x ?? this.x,
    y: y ?? this.y,
    diameter: diameter ?? this.diameter,
    drill: drill ?? this.drill,
    netId: clearNet ? null : (netId ?? this.netId),
  );

  Via withNet(String? netId) => Via(
    id: id,
    projectId: projectId,
    netId: netId,
    x: x,
    y: y,
    diameter: diameter,
    drill: drill,
  );
}
