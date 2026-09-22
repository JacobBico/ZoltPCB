import 'dart:ui';

import 'board_layer.dart';

/// How pads on a pour's own net join it.
enum PadConnection {
  /// A gap round the pad bridged by four spokes: joined, but the pad can
  /// still be soldered without the plane soaking up the iron's heat.
  thermal('Thermal'),

  /// Poured right up to the pad: the best joint, the hardest to solder.
  solid('Solid'),

  /// Not joined at all: kept clear like any other net's pad.
  none('None');

  const PadConnection(this.label);

  final String label;

  static PadConnection byName(String? name) =>
      values.where((c) => c.name == name).firstOrNull ?? thermal;
}

/// A copper pour tied to a net.
///
/// The ground plane, and everything shaped like one: a region of a copper
/// layer that is filled with whatever net it belongs to, so every pad on
/// that net inside it is connected without a track. It is the single
/// biggest reason a two-layer board works at all.
///
/// Stored as an outline, not as filled copper. KiCad recomputes the fill
/// from the outline, the clearance and everything else on the layer, every
/// time it opens the board or is asked to refill — so the outline is the
/// design, and the fill is a consequence of it.
class BoardZone {
  const BoardZone({
    required this.id,
    required this.projectId,
    required this.layer,
    required this.points,
    this.netId,
    this.netName = '',
    this.clearance = 0.5,
    this.minThickness = 0.25,
    this.priority = 0,
    this.padConnection = PadConnection.thermal,
    this.viaConnection = PadConnection.solid,
    this.thermalGap = 0.5,
    this.thermalSpoke = 0.5,
  });

  final String id;
  final String projectId;

  /// Which copper layer the pour is on. A zone is one layer at a time, the
  /// way KiCad's is.
  final BoardLayer layer;

  /// The outline, in board millimetres.
  final List<Offset> points;

  /// The net filled into it, or null for an unconnected pour — which is
  /// legal, occasionally wanted, and almost always a mistake.
  final String? netId;

  /// The net's name at the time of drawing, for display and for export
  /// when the net has no label of its own.
  final String netName;

  /// Gap kept between the pour and everything not on its net.
  final double clearance;

  /// Thinnest sliver of copper the pour may leave. Below this KiCad simply
  /// does not fill, which is what keeps a pour from growing hairs.
  final double minThickness;

  /// Where two pours overlap, the higher priority one is filled and the
  /// lower one is cut back round it, as KiCad does.
  final int priority;

  final PadConnection padConnection;

  /// The same, for vias and plated holes on the pour's own net. Solid by
  /// default: nothing is soldered to a via, so there is nothing for a
  /// thermal relief to protect, and a stitching via wants all the copper
  /// it can get.
  final PadConnection viaConnection;

  /// The gap round a thermal pad, and the width of the spokes across it.
  final double thermalGap;
  final double thermalSpoke;

  bool get isValid => points.length >= 3;

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var rect = Rect.fromPoints(points.first, points.first);
    for (final point in points.skip(1)) {
      rect = rect.expandToInclude(Rect.fromPoints(point, point));
    }
    return rect;
  }

  Path get path {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  /// Whether [point] is inside the pour, by the even-odd rule.
  bool contains(Offset point) {
    if (points.length < 3) return false;
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i];
      final b = points[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  String get label => netName.isEmpty ? 'No net' : netName;

  BoardZone copyWith({
    BoardLayer? layer,
    List<Offset>? points,
    String? netId,
    bool clearNet = false,
    String? netName,
    double? clearance,
    double? minThickness,
    int? priority,
    PadConnection? padConnection,
    PadConnection? viaConnection,
    double? thermalGap,
    double? thermalSpoke,
  }) => BoardZone(
    id: id,
    projectId: projectId,
    layer: layer ?? this.layer,
    points: points ?? this.points,
    netId: clearNet ? null : (netId ?? this.netId),
    netName: clearNet ? '' : (netName ?? this.netName),
    clearance: clearance ?? this.clearance,
    minThickness: minThickness ?? this.minThickness,
    priority: priority ?? this.priority,
    padConnection: padConnection ?? this.padConnection,
    viaConnection: viaConnection ?? this.viaConnection,
    thermalGap: thermalGap ?? this.thermalGap,
    thermalSpoke: thermalSpoke ?? this.thermalSpoke,
  );

  @override
  String toString() =>
      'BoardZone($label on ${layer.name}, ${points.length} points)';
}
