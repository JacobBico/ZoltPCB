import 'dart:ui';

import 'board_layer.dart';

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
          point.dx <
              (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
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
  }) => BoardZone(
    id: id,
    projectId: projectId,
    layer: layer ?? this.layer,
    points: points ?? this.points,
    netId: clearNet ? null : (netId ?? this.netId),
    netName: clearNet ? '' : (netName ?? this.netName),
    clearance: clearance ?? this.clearance,
    minThickness: minThickness ?? this.minThickness,
  );

  @override
  String toString() =>
      'BoardZone($label on ${layer.name}, ${points.length} points)';
}
