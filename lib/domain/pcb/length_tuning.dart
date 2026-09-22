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
