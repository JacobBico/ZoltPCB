import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_scene.dart';

/// How big the fillets are where a track meets a pad or a via.
///
/// The two ratios are KiCad's, and mean the same things: how far back along
/// the track the fillet reaches, and how wide it is where it meets the
/// round thing, both as a fraction of that thing's radius.
class TeardropRules {
  const TeardropRules({
    this.enabled = false,
    this.lengthRatio = 0.5,
    this.widthRatio = 0.9,
    this.onPads = true,
    this.onVias = true,
  });

  final bool enabled;

  /// How far back the fillet reaches, as a fraction of the pad's diameter.
  final double lengthRatio;

  /// How wide it is at the pad, as a fraction of the pad's diameter.
  final double widthRatio;

  final bool onPads;
  final bool onVias;

  TeardropRules copyWith({
    bool? enabled,
    double? lengthRatio,
    double? widthRatio,
    bool? onPads,
    bool? onVias,
  }) => TeardropRules(
    enabled: enabled ?? this.enabled,
    lengthRatio: lengthRatio ?? this.lengthRatio,
    widthRatio: widthRatio ?? this.widthRatio,
    onPads: onPads ?? this.onPads,
    onVias: onVias ?? this.onVias,
  );

  String encode() =>
      '${enabled ? 1 : 0} $lengthRatio $widthRatio '
      '${onPads ? 1 : 0} ${onVias ? 1 : 0}';

  static TeardropRules decode(String? text) {
    final parts = (text ?? '').split(' ');
    if (parts.length < 5) return const TeardropRules();
    return TeardropRules(
      enabled: parts[0] == '1',
      lengthRatio: double.tryParse(parts[1]) ?? 0.5,
      widthRatio: double.tryParse(parts[2]) ?? 0.9,
      onPads: parts[3] == '1',
      onVias: parts[4] == '1',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TeardropRules &&
      other.enabled == enabled &&
      other.lengthRatio == lengthRatio &&
      other.widthRatio == widthRatio &&
      other.onPads == onPads &&
      other.onVias == onVias;

  @override
  int get hashCode =>
      Object.hash(enabled, lengthRatio, widthRatio, onPads, onVias);
}

/// One fillet, as a filled polygon on one copper layer.
class Teardrop {
  const Teardrop(this.layer, this.points, {this.netId});

  final CopperLayer layer;
  final List<Offset> points;
  final String? netId;
}

/// Copper fillets where a track meets a pad or a via.
///
/// A track that meets a round pad at a right angle meets it at a point, and
/// that point is where the copper cracks when the board flexes, where the
/// etchant undercuts, and where a drill that wandered half its tolerance
/// breaks out of the annular ring. A teardrop fills the corner in. KiCad
/// grew them in version 7 and every fab has wanted them for decades.
///
/// Computed rather than stored, exactly as a pour's fill is: it follows
/// from the track, the pad and two ratios, and would go stale the moment
/// any of the three moved.
abstract final class Teardrops {
  /// How many points make one side of the fillet's curve.
  static const _steps = 8;

  /// Every fillet on [layer].
  static List<Teardrop> of(BoardScene scene, CopperLayer layer) {
    final rules = scene.board.teardrops;
    if (!rules.enabled) return const [];

    final drops = <Teardrop>[];
    for (final track in scene.tracks) {
      if (track.layer != layer) continue;
      final a = Offset(track.startX, track.startY);
      final b = Offset(track.endX, track.endY);
      if ((b - a).distance < 1e-6) continue;

      for (final (end, away) in [(a, b), (b, a)]) {
        final target = _targetAt(scene, layer, end, track.netId, rules);
        if (target == null) continue;
        final (centre, radius) = target;
        final shape = _shape(
          centre: centre,
          radius: radius,
          towards: away,
          halfWidth: track.width / 2,
          rules: rules,
          room: (away - end).distance,
        );
        if (shape != null) {
          drops.add(Teardrop(layer, shape, netId: track.netId));
        }
      }
    }
    return drops;
  }

  /// The pad or via a track end lands on, as a circle.
  ///
  /// A rectangular pad is taken at its short side, which is the dimension a
  /// fillet has to stay inside however the pad is turned.
  static (Offset, double)? _targetAt(
    BoardScene scene,
    CopperLayer layer,
    Offset end,
    String? netId,
    TeardropRules rules,
  ) {
    if (rules.onVias) {
      for (final via in scene.vias) {
        if (via.netId != netId) continue;
        final centre = Offset(via.x, via.y);
        if ((centre - end).distance > via.diameter / 2) continue;
        return (centre, via.diameter / 2);
      }
    }
    if (rules.onPads) {
      for (final pad in scene.pads) {
        if (pad.netId != netId) continue;
        if (!pad.reaches(layer)) continue;
        final radius = math.min(pad.pad.sizeX, pad.pad.sizeY) / 2;
        if ((pad.position - end).distance > radius) continue;
        return (pad.position, radius);
      }
    }
    return null;
  }

  /// The fillet itself: a wedge from inside the pad out to the track, with
  /// concave sides, which is what makes it read as a fillet rather than as
  /// a triangle someone left there.
  static List<Offset>? _shape({
    required Offset centre,
    required double radius,
    required Offset towards,
    required double halfWidth,
    required TeardropRules rules,
    required double room,
  }) {
    final along = towards - centre;
    final distance = along.distance;
    if (distance < 1e-6) return null;
    final u = along / distance;
    final n = Offset(-u.dy, u.dx);

    // Meaningfully wider than the track at the pad, or there is nothing to
    // fill in: a fillet a fifth wider than the track it joins is a bump,
    // not a fillet, and it costs a polygon on every layer to draw.
    final mouth = math.min(radius * rules.widthRatio, radius * 0.98);
    if (mouth <= halfWidth * 1.2) return null;

    // Long enough to be a fillet, short enough to stay on the track it
    // grew from — and never past the far end of that track.
    final reach = math.min(radius * 2 * rules.lengthRatio, room - radius);
    if (reach <= radius * 0.1) return null;

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= _steps; i++) {
      final t = i / _steps;
      // Hugs the pad at the start and meets the track tangentially at the
      // end: a square law, not a straight taper.
      final half = halfWidth + (mouth - halfWidth) * (1 - t) * (1 - t);
      final at = centre + u * (reach * t);
      left.add(at + n * half);
      right.add(at - n * half);
    }
    // Closed back through the middle of the pad, which the pad's own
    // copper covers.
    return [
      centre - u * (radius * 0.9),
      ...left,
      for (final p in right.reversed) p,
    ];
  }
}
