import 'dart:math' as math;
import 'dart:ui';

import 'board_scene.dart';
import 'track_angles.dart';

/// One connection a bus carries: a net, and the two pads it joins.
class BusLane {
  const BusLane({
    required this.netId,
    required this.netName,
    required this.from,
    required this.to,
  });

  final String netId;
  final String netName;
  final Offset from;
  final Offset to;
}

/// The tracks a bus comes to, and anything worth saying about them.
class BusPlan {
  const BusPlan(this.tracks, this.warnings);

  /// One run of corners per lane, pad to pad, in lane order.
  final List<(BusLane, List<Offset>)> tracks;
  final List<String> warnings;
}

/// Routes several connections side by side along one drawn path.
///
/// Eight data lines from a connector to a chip are eight routes that all
/// want to go the same way. Drawing one path and having the rest follow it
/// at the spacing is how a person would route them, and it keeps them
/// together, in order and evenly spaced — which a bus should be.
abstract final class BusRouter {
  /// The unrouted connections that start inside [area]: one per net, from
  /// its end inside the area to its other end.
  static List<BusLane> lanesStartingIn(BoardScene scene, Rect area) {
    final lanes = <String, BusLane>{};
    for (final line in scene.ratsnest) {
      if (lanes.containsKey(line.netId)) continue;
      final fromInside = area.contains(line.from);
      final toInside = area.contains(line.to);
      if (fromInside == toInside) continue;
      lanes[line.netId] = BusLane(
        netId: line.netId,
        netName: line.netName,
        from: fromInside ? line.from : line.to,
        to: fromInside ? line.to : line.from,
      );
    }
    return lanes.values.toList();
  }

  /// Lays [lanes] along [spine], [pitch] apart centre to centre.
  ///
  /// Lanes are ordered by where they start across the first run of the
  /// path, so they leave their pads without crossing. If their other ends
  /// come in a different order they have to cross somewhere, and the plan
  /// says so rather than hiding it.
  static BusPlan plan({
    required List<BusLane> lanes,
    required List<Offset> spine,
    required double pitch,
  }) {
    if (lanes.isEmpty || spine.isEmpty) return const BusPlan([], []);
    final path = spine.length == 1
        ? [spine.first, spine.first + const Offset(1e-3, 0)]
        : spine;

    final startNormal = _normal(path[0], path[1]);
    final endNormal = _normal(path[path.length - 2], path.last);
    double across(Offset p, Offset origin, Offset normal) =>
        (p - origin).dx * normal.dx + (p - origin).dy * normal.dy;

    final ordered = [...lanes]
      ..sort(
        (a, b) => across(
          a.from,
          path.first,
          startNormal,
        ).compareTo(across(b.from, path.first, startNormal)),
      );

    final warnings = <String>[];
    final atEnd = [...ordered]
      ..sort(
        (a, b) => across(
          a.to,
          path.last,
          endNormal,
        ).compareTo(across(b.to, path.last, endNormal)),
      );
    if (!_sameOrder(ordered, atEnd)) {
      warnings.add(
        'The connections arrive in a different order from the one they '
        'leave in, so some cross — check the red where they do',
      );
    }

    final n = ordered.length;
    final tracks = <(BusLane, List<Offset>)>[];
    for (var k = 0; k < n; k++) {
      final lane = ordered[k];
      final offset = (k - (n - 1) / 2) * pitch;
      final rail = offsetPolyline(path, offset);
      final points = <Offset>[
        lane.from,
        ...legalCorners(lane.from, rail.first, TrackAngleLock.deg45),
        ...rail.skip(1),
        ...legalCorners(rail.last, lane.to, TrackAngleLock.deg45),
      ];
      tracks.add((lane, _dedupe(points)));
    }
    return BusPlan(tracks, warnings);
  }

  /// [points] moved sideways by [distance], corners mitred so each run
  /// stays parallel to the one it follows. Positive is to the left of the
  /// direction of travel, as the board is seen.
  static List<Offset> offsetPolyline(List<Offset> points, double distance) {
    if (points.length < 2 || distance == 0) return [...points];
    final normals = [
      for (var i = 0; i < points.length - 1; i++)
        _normal(points[i], points[i + 1]),
    ];
    final out = <Offset>[points.first + normals.first * distance];
    for (var i = 1; i < points.length - 1; i++) {
      final a = normals[i - 1];
      final b = normals[i];
      // The mitre: along the bisector, far enough that both runs stay
      // [distance] off their own centre lines.
      final bisector = a + b;
      final length = bisector.distance;
      if (length < 1e-9) {
        out.add(points[i] + a * distance);
        continue;
      }
      final unit = bisector / length;
      final cos = unit.dx * a.dx + unit.dy * a.dy;
      out.add(points[i] + unit * (distance / math.max(cos, 1e-6)));
    }
    out.add(points.last + normals.last * distance);
    return out;
  }

  static Offset _normal(Offset a, Offset b) {
    final d = b - a;
    final l = d.distance;
    if (l < 1e-12) return const Offset(0, -1);
    return Offset(d.dy / l, -d.dx / l);
  }

  static bool _sameOrder(List<BusLane> a, List<BusLane> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].netId != b[i].netId) return false;
    }
    return true;
  }

  static List<Offset> _dedupe(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      if (out.isEmpty || (out.last - p).distance > 1e-9) out.add(p);
    }
    return out;
  }
}
