import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_scene.dart';
import 'track_angles.dart';

/// How the second track of a pair follows the first.
enum DiffPairStyle {
  /// The path drawn is the centre line, and the two tracks sit half the gap
  /// either side of it. Both turn at the same place, so the pair stays
  /// symmetrical about what was aimed at — which is what keeps the two
  /// lengths equal round a corner.
  mirrored('Mirrored', 'Both sides of the line you draw'),

  /// The path drawn is one track and the other is a copy of it, the gap
  /// away. What you aim at is copper rather than a line between copper,
  /// which is easier to place against a pad.
  copy('Copy', 'One track drawn, the other alongside');

  const DiffPairStyle(this.label, this.note);

  final String label;
  final String note;
}

/// Two nets routed as one.
class DiffPair {
  const DiffPair({
    required this.positiveId,
    required this.negativeId,
    required this.positiveName,
    required this.negativeName,
  });

  final String positiveId;
  final String negativeId;
  final String positiveName;
  final String negativeName;

  String get label => '$positiveName / $negativeName';

  /// The other half of the pair, given one of them.
  String? partnerOf(String netId) => netId == positiveId
      ? negativeId
      : (netId == negativeId ? positiveId : null);
}

/// Routing two nets side by side.
///
/// A differential pair is two tracks that have to stay the same distance
/// apart and the same length, because everything useful about the signal is
/// in the difference between them. Drawing them one at a time and hoping is
/// how they come out unequal, so they are drawn together.
///
/// Which two nets make a pair is read off their names, exactly as KiCad
/// does it: `USB_D+` and `USB_D-`, `CLK_P` and `CLK_N`, `LVDS0_p` and
/// `LVDS0_n`. Nothing else has to be set up, and a board whose nets are
/// named by any of those conventions simply works.
abstract final class DiffPairs {
  /// The suffix pairs that name a differential pair, in the order they are
  /// tried. Each is (positive, negative).
  static const _suffixes = [
    ('+', '-'),
    ('_P', '_N'),
    ('_p', '_n'),
    ('P', 'N'),
  ];

  /// The name of [name]'s partner, and whether [name] is the positive half.
  static (String, bool)? partnerName(String name) {
    for (final (plus, minus) in _suffixes) {
      if (name.endsWith(plus) && name.length > plus.length) {
        return ('${name.substring(0, name.length - plus.length)}$minus', true);
      }
      if (name.endsWith(minus) && name.length > minus.length) {
        return ('${name.substring(0, name.length - minus.length)}$plus', false);
      }
    }
    return null;
  }

  /// The pair [netId] belongs to on [scene], or null if its name does not
  /// name one or the partner is not on this board.
  static DiffPair? of(BoardScene scene, String? netId) {
    if (netId == null) return null;
    final names = <String, String>{};
    for (final pad in scene.pads) {
      final id = pad.netId;
      final netName = pad.netName;
      if (id != null && netName != null && netName.isNotEmpty) {
        names[id] = netName;
      }
    }
    final name = names[netId];
    if (name == null) return null;
    final partner = partnerName(name);
    if (partner == null) return null;
    final (otherName, isPositive) = partner;
    String? otherId;
    for (final entry in names.entries) {
      if (entry.value == otherName) otherId = entry.key;
    }
    if (otherId == null) return null;
    return DiffPair(
      positiveId: isPositive ? netId : otherId,
      negativeId: isPositive ? otherId : netId,
      positiveName: isPositive ? name : otherName,
      negativeName: isPositive ? otherName : name,
    );
  }

  /// The pad of [netId] nearest [near], on [layer].
  static PlacedPad? padNear(
    BoardScene scene,
    String netId,
    Offset near, {
    CopperLayer? layer,
  }) {
    PlacedPad? best;
    var bestDistance = double.infinity;
    for (final pad in scene.pads) {
      if (pad.netId != netId) continue;
      if (layer != null && !pad.reaches(layer)) continue;
      final distance = (pad.position - near).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = pad;
      }
    }
    return best;
  }

  /// [points] moved [distance] to its left, keeping every run's bearing.
  ///
  /// Mitred, not rounded: each run is shifted sideways and consecutive runs
  /// are extended until they meet. Because no run changes direction, a path
  /// drawn on 45s offsets to a path on 45s — which is the whole reason a
  /// pair can be drawn this way at all.
  static List<Offset> offsetRun(List<Offset> points, double distance) {
    if (points.length < 2 || distance == 0) return [...points];

    // Each run as a point on its offset line, and the direction it runs in.
    final lines = <(Offset, Offset)>[];
    for (var i = 0; i < points.length - 1; i++) {
      final along = points[i + 1] - points[i];
      final length = along.distance;
      if (length < 1e-9) continue;
      final u = along / length;
      final n = Offset(u.dy, -u.dx);
      lines.add((points[i] + n * distance, u));
    }
    if (lines.isEmpty) return [...points];

    final out = <Offset>[lines.first.$1];
    for (var i = 0; i + 1 < lines.length; i++) {
      final meeting = _meet(lines[i], lines[i + 1]);
      // A reversal has no meeting point; keep the corner where it was so
      // the run stays continuous rather than shooting off to infinity.
      out.add(meeting ?? lines[i + 1].$1);
    }
    final (last, direction) = lines.last;
    final end = points.last - points[points.length - 2];
    out.add(last + direction * end.distance);
    return out;
  }

  /// Where two offset lines cross.
  static Offset? _meet((Offset, Offset) a, (Offset, Offset) b) {
    final cross = a.$2.dx * b.$2.dy - a.$2.dy * b.$2.dx;
    if (cross.abs() < 1e-9) return null;
    final delta = b.$1 - a.$1;
    final t = (delta.dx * b.$2.dy - delta.dy * b.$2.dx) / cross;
    return a.$1 + a.$2 * t;
  }

  /// The two runs a pair lays for a path drawn down the middle of it, or
  /// along one of them.
  ///
  /// [side] says which way round the two are: +1 puts the positive track on
  /// the left of the direction of travel.
  static (List<Offset>, List<Offset>) runs(
    List<Offset> path, {
    required double gap,
    required DiffPairStyle style,
    required double side,
  }) => switch (style) {
    DiffPairStyle.mirrored => (
      offsetRun(path, gap / 2 * side),
      offsetRun(path, -gap / 2 * side),
    ),
    DiffPairStyle.copy => ([...path], offsetRun(path, -gap * side)),
  };

  /// Which side of [path] the partner's pad sits on: +1 for its left.
  static double sideOf(List<Offset> path, Offset partner) {
    if (path.length < 2) return 1;
    final along = path[1] - path[0];
    final length = along.distance;
    if (length < 1e-9) return 1;
    final u = along / length;
    final n = Offset(u.dy, -u.dx);
    final delta = partner - path[0];
    final on = delta.dx * n.dx + delta.dy * n.dy;
    // The positive track goes on the far side from the partner, so the
    // partner keeps the side its own pad is already on.
    return on >= 0 ? -1 : 1;
  }

  /// [run] joined to [pad] at whichever end is nearer, on legal angles.
  static List<Offset> landOn(List<Offset> run, Offset pad, {bool atEnd = true}) {
    if (run.isEmpty) return [pad];
    if (atEnd) {
      if ((run.last - pad).distance < 1e-6) return run;
      return [...run, ...legalCorners(run.last, pad, TrackAngleLock.deg45)];
    }
    if ((run.first - pad).distance < 1e-6) return run;
    return [pad, ...legalCorners(pad, run.first, TrackAngleLock.deg45), ...run];
  }

  /// How far apart two runs of the same shape actually are.
  static double gapBetween(List<Offset> a, List<Offset> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var worst = double.infinity;
    for (final p in a) {
      for (var i = 0; i < b.length - 1; i++) {
        worst = math.min(worst, distanceToSegment(p, b[i], b[i + 1]));
      }
    }
    return worst.isFinite ? worst : 0;
  }
}
