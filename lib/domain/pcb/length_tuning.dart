import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_scene.dart';
import 'impedance.dart';
import 'stackup.dart';

/// How long a net's copper is, and how long a signal takes along it.
class NetLength {
  const NetLength({
    required this.netId,
    required this.length,
    required this.delayPs,
    required this.trackCount,
    required this.viaCount,
  });

  final String netId;

  /// Total track length, in millimetres. Vias are not counted: their
  /// barrel is a fraction of a millimetre, and which part of it a signal
  /// uses depends on which layers it changes between.
  final double length;

  /// Propagation delay along every track, in picoseconds — each at the
  /// speed its own layer and width give it.
  final double delayPs;

  final int trackCount;
  final int viaCount;

  static NetLength of(BoardScene scene, String netId) {
    var length = 0.0;
    var delay = 0.0;
    var tracks = 0;
    final stackup = scene.board.stackup;
    final speeds = <(CopperLayer, double), double>{};
    for (final track in scene.tracks) {
      if (track.netId != netId) continue;
      tracks++;
      length += track.lengthMm;
      delay +=
          track.lengthMm *
          speeds.putIfAbsent((
            track.layer,
            track.width,
          ), () => delayPerMm(stackup, track.layer, track.width));
    }
    return NetLength(
      netId: netId,
      length: length,
      delayPs: delay,
      trackCount: tracks,
      viaCount: scene.vias.where((v) => v.netId == netId).length,
    );
  }

  /// Picoseconds per millimetre for a track of [width] on [layer], or a
  /// typical FR-4 figure for a layer the build does not have.
  static double delayPerMm(Stackup stackup, CopperLayer layer, double width) {
    if (!stackup.layers.contains(layer) || width <= 0) return 6.0;
    return ImpedanceCalculator.of(stackup, layer, width: width).delayPsPerMm;
  }
}

/// How the meander's corners are turned.
enum MeanderCorner {
  square('Square'),
  chamfered('45°');

  const MeanderCorner(this.label);

  final String label;
}

/// Which side of the track the loops stand on.
enum MeanderSide {
  /// Loops on both sides, alternating — the most extra length for the
  /// room, and centred on where the track ran.
  both('Both sides'),

  /// Loops on the left of the direction of travel only: a trombone, for
  /// a track with something close by on one side.
  left('Left'),
  right('Right');

  const MeanderSide(this.label);

  final String label;
}

/// A meander worked out for one straight segment.
class MeanderPlan {
  const MeanderPlan({
    required this.points,
    required this.added,
    required this.loops,
    required this.amplitude,
    this.problem,
  });

  /// The track's new path, first point on the segment's start and last on
  /// its end. Empty when it could not be made.
  final List<Offset> points;

  /// Extra length the loops add, in millimetres.
  final double added;
  final int loops;

  /// How far each loop stands off the line, in millimetres.
  final double amplitude;

  /// Why it could not be made, if it could not.
  final String? problem;

  bool get isValid => problem == null && points.length >= 2;

  static const failed = MeanderPlan(
    points: [],
    added: 0,
    loops: 0,
    amplitude: 0,
  );

  MeanderPlan withProblem(String problem) => MeanderPlan(
    points: const [],
    added: 0,
    loops: loops,
    amplitude: amplitude,
    problem: problem,
  );
}

/// Adds length to a straight track by folding it into loops — the way two
/// signals that must arrive together are made the same length.
abstract final class Meander {
  /// Folds the segment [a]–[b] so it grows by [extra] millimetres.
  ///
  /// The loops stand at most [maxAmplitude] off the line, with centres
  /// [spacing] apart, and leave [spacing] of straight track at each end
  /// so the meander does not start on the corner before it. As few loops
  /// as fit the amplitude are used, all the same height, sized to add
  /// exactly [extra] — the last millimetre is not rounded away.
  static MeanderPlan plan({
    required Offset a,
    required Offset b,
    required double extra,
    required double maxAmplitude,
    required double spacing,
    MeanderSide side = MeanderSide.both,
    MeanderCorner corner = MeanderCorner.chamfered,
  }) {
    final length = (b - a).distance;
    if (extra <= 1e-6) {
      return MeanderPlan.failed.withProblem(
        'Nothing to add — the track is already long enough',
      );
    }
    if (length < 1e-6 || spacing <= 0 || maxAmplitude <= 0) {
      return MeanderPlan.failed.withProblem('The segment has no length');
    }

    // Straight run left at each end, and what is left for loops.
    final margin = spacing;
    final room = length - 2 * margin;
    final symmetric = side == MeanderSide.both;

    // A chamfered corner is cut back by c: each loses (2 − √2)·c of length.
    const perCorner = 2 - math.sqrt2;
    double amplitudeFor(int loops, double chamfer) {
      // Every bend of the path is a right angle: two where it leaves and
      // rejoins the line, and two per loop top on a symmetric meander; four
      // per loop on a one-sided one, which comes back to the line each time.
      final corners = symmetric ? 2 * loops + 2 : 4 * loops;
      return (extra + corners * perCorner * chamfer) / (2 * loops);
    }

    double chamferFor(double squareAmplitude) => corner == MeanderCorner.square
        ? 0
        : math.min(spacing / 4, squareAmplitude / 4);

    int loops = 1;
    double amplitude = 0;
    double chamfer = 0;
    for (; loops < 1000; loops++) {
      chamfer = chamferFor(amplitudeFor(loops, 0));
      amplitude = amplitudeFor(loops, chamfer);
      if (amplitude <= maxAmplitude + 1e-9) break;
    }
    final occupied = symmetric ? loops * spacing : (2 * loops - 1) * spacing;
    if (occupied > room + 1e-9) {
      final needed = occupied + 2 * margin;
      return MeanderPlan(
        points: const [],
        added: 0,
        loops: loops,
        amplitude: amplitude,
        problem:
            'Needs ${needed.toStringAsFixed(1)} mm of straight track; this '
            'one is ${length.toStringAsFixed(1)} mm. Raise the amplitude or '
            'pick a longer run',
      );
    }

    // Built in the segment's own frame — x along it, y to its left — then
    // turned onto the board.
    final along = (b - a) / length;
    final leftward = Offset(along.dy, -along.dx);
    Offset world(double x, double y) => a + along * x + leftward * y;

    final start = (length - occupied) / 2;
    final local = <Offset>[Offset.zero, Offset(start, 0)];
    if (symmetric) {
      var y = 0.0;
      var x = start;
      for (var i = 0; i < loops; i++) {
        final top = i.isEven ? amplitude : -amplitude;
        local.add(Offset(x, top));
        x += spacing;
        local.add(Offset(x, top));
        y = top;
      }
      local.add(Offset(x, 0));
      assert(y != 0);
    } else {
      final sign = side == MeanderSide.left ? 1.0 : -1.0;
      var x = start;
      for (var i = 0; i < loops; i++) {
        local
          ..add(Offset(x, sign * amplitude))
          ..add(Offset(x + spacing, sign * amplitude))
          ..add(Offset(x + spacing, 0));
        x += 2 * spacing;
        if (i < loops - 1) local.add(Offset(x, 0));
      }
    }
    local.add(Offset(length, 0));

    final path = corner == MeanderCorner.chamfered && chamfer > 0
        ? _chamfer(local, chamfer)
        : local;
    final cleaned = _dropCollinear(path);
    final points = [for (final p in cleaned) world(p.dx, p.dy)];
    // Exact ends, not ends rebuilt through a rotation.
    points[0] = a;
    points[points.length - 1] = b;

    return MeanderPlan(
      points: points,
      added: _pathLength(points) - length,
      loops: loops,
      amplitude: amplitude,
    );
  }

  /// Cuts every right-angle corner back by [c], turning it into two 45°
  /// bends. The first and last points are the track's ends and stay.
  static List<Offset> _chamfer(List<Offset> points, double c) {
    final out = <Offset>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final here = points[i];
      final next = points[i + 1];
      final inDir = here - prev;
      final outDir = next - here;
      final cross = inDir.dx * outDir.dy - inDir.dy * outDir.dx;
      if (cross.abs() < 1e-12 ||
          inDir.distance < 1e-9 ||
          outDir.distance < 1e-9) {
        out.add(here);
        continue;
      }
      final cut = math.min(c, math.min(inDir.distance, outDir.distance) / 2);
      out
        ..add(here - inDir / inDir.distance * cut)
        ..add(here + outDir / outDir.distance * cut);
    }
    out.add(points.last);
    return out;
  }

  static List<Offset> _dropCollinear(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      if (out.isNotEmpty && (out.last - p).distance < 1e-9) continue;
      if (out.length >= 2) {
        final a = out[out.length - 2];
        final b = out.last;
        final cross =
            (b.dx - a.dx) * (p.dy - b.dy) - (b.dy - a.dy) * (p.dx - b.dx);
        final dot =
            (b.dx - a.dx) * (p.dx - b.dx) + (b.dy - a.dy) * (p.dy - b.dy);
        if (cross.abs() < 1e-9 && dot > 0) {
          out[out.length - 1] = p;
          continue;
        }
      }
      out.add(p);
    }
    return out;
  }

  static double _pathLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  /// A sensible leg spacing for a track: three widths centre to centre, or
  /// enough for the clearance between legs, whichever is more — legs of
  /// one net coupling to each other shorten the delay the loops were
  /// added for.
  static double defaultSpacing(double width, double clearance) =>
      math.max(3 * width, width + 2 * clearance);
}
