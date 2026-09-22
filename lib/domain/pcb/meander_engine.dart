import 'dart:math' as math;
import 'dart:ui';

import 'track_angles.dart';

/// The two meander shapes the tuner draws.
///
/// Ported from the standalone meander tuner (`meander_gui_implementation/
/// meander_engine.py`), keeping its zigzag and sine styles.
enum MeanderStyle {
  /// A rounded square wave: straight runs joined by 90° bends, each bend
  /// rounded by the corner radius. Compact, and reads as routed copper.
  zigzag('Zigzag'),

  /// A sine wave along the run: tangent-continuous, the gentlest return
  /// path, and the least length for its height.
  sine('Sine');

  const MeanderStyle(this.label);

  final String label;
}

/// What the tuner decided.
enum TuningStatus {
  /// Within tolerance of the target.
  matched('Matched'),

  /// A meander went in but could not reach the target.
  short('Too short'),

  /// The route is already longer than the target; length cannot be taken
  /// away, only added.
  long('Too long'),

  /// The length needed does not fit in the run at all.
  infeasible('No fit');

  const TuningStatus(this.label);

  final String label;
}

/// The loops a meander draws, set by hand rather than solved for a length.
///
/// This is what the Route tool carries while it is set to Meander: you
/// choose the shape, and the length it adds is what you watch grow as the
/// run gets longer. The dialog that solves the other way round — give me
/// this much length, find me a shape — is still there for tuning a track
/// that is already laid.
class MeanderShape {
  const MeanderShape({
    this.style = MeanderStyle.zigzag,
    this.amplitude = 1.5,
    this.pitch = 1.2,
    this.cornerRadius = 0.6,
  });

  final MeanderStyle style;

  /// How far the copper bulges either side of the line, in millimetres.
  final double amplitude;

  /// How far apart the runs are along the line, in millimetres.
  final double pitch;

  /// How far back from each corner the curve starts. Capped by the runs it
  /// joins, so turning it up past what the loops can hold simply rounds
  /// them as far as they go.
  final double cornerRadius;

  MeanderShape copyWith({
    MeanderStyle? style,
    double? amplitude,
    double? pitch,
    double? cornerRadius,
  }) => MeanderShape(
    style: style ?? this.style,
    amplitude: amplitude ?? this.amplitude,
    pitch: pitch ?? this.pitch,
    cornerRadius: cornerRadius ?? this.cornerRadius,
  );

  @override
  bool operator ==(Object other) =>
      other is MeanderShape &&
      other.style == style &&
      other.amplitude == amplitude &&
      other.pitch == pitch &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(style, amplitude, pitch, cornerRadius);
}

/// A meander folded into a run: the route's new points, and its shape.
class MeanderFit {
  const MeanderFit({
    this.points = const [],
    this.ok = false,
    this.reason = '',
    this.amplitude = 0,
    this.crossings = 0,
    this.span = 0,
    this.segmentIndex = -1,
    this.added = 0,
  });

  final List<Offset> points;
  final bool ok;
  final String reason;

  /// How far the copper bulges from the centre line, in millimetres.
  final double amplitude;

  /// How many times the copper crosses the centre line.
  final int crossings;
  final double span;

  /// Which run of the route was folded.
  final int segmentIndex;
  final double added;

  double get length => MeanderEngine.polylineLength(points);

  MeanderFit copyWith({
    List<Offset>? points,
    int? segmentIndex,
    double? added,
  }) => MeanderFit(
    points: points ?? this.points,
    ok: ok,
    reason: reason,
    amplitude: amplitude,
    crossings: crossings,
    span: span,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    added: added ?? this.added,
  );
}

/// The whole tuning decision, with everything a readout needs.
class TuningResult {
  const TuningResult({
    required this.psPerMm,
    required this.baseLength,
    required this.targetLength,
    required this.totalLength,
    required this.status,
    required this.points,
    this.reason = '',
    this.fit,
  });

  final double psPerMm;

  /// The route before tuning, and after.
  final double baseLength;
  final double totalLength;
  final double targetLength;
  final TuningStatus status;
  final String reason;

  /// The tuned route, or the original when nothing could be done.
  final List<Offset> points;
  final MeanderFit? fit;

  double get delayPs => totalLength * psPerMm;
  double get targetDelayPs => targetLength * psPerMm;
  double get deltaPs => (targetLength - totalLength) * psPerMm;
  double get deltaMm => targetLength - totalLength;
  double get addedMm => math.max(totalLength - baseLength, 0);
}

/// Folds extra length into a route so it arrives when another does.
///
/// Pure geometry, millimetres and picoseconds throughout.
abstract final class MeanderEngine {
  /// The speed of light, in millimetres per picosecond.
  static const cMmPerPs = 0.299792458;

  static const _eps = 1e-9;

  /// Chords per rounded corner.
  static const roundSegments = 8;

  /// Delay of a trace in ps/mm for an effective permittivity: about 6.8
  /// for FR-4 stripline (εeff ≈ 4.2).
  static double psPerMm(double epsEff) =>
      math.sqrt(math.max(epsEff, 1.0)) / cMmPerPs;

  static double polylineLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  static List<Offset> _dedupe(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      if (out.isNotEmpty && (out.last - p).distance < _eps) continue;
      out.add(p);
    }
    return out;
  }

  /// A square-wave serpentine along a run of [span], in the run's own
  /// frame: u along it, v to its left. With n crossings there are n + 1
  /// runs; it starts and ends on the centre line so it splices in cleanly.
  static List<Offset> _square(
    double span,
    int crossings,
    double amplitude,
    double cornerRadius, {
    int segments = roundSegments,
  }) {
    final run = span / (crossings + 1);
    final points = <Offset>[Offset.zero];
    var v = 0.0;
    var u = 0.0;
    for (var i = 0; i < crossings; i++) {
      u += run;
      points.add(Offset(u, v));
      v = v <= 0 ? amplitude : -amplitude;
      points.add(Offset(u, v));
    }
    u += run;
    points
      ..add(Offset(u, v))
      ..add(Offset(u, 0));
    return _dedupe(
      roundCorners(points, radius: cornerRadius, segments: segments),
    );
  }

  /// A sine wave along the run.
  static List<Offset> _sine(
    double span,
    int crossings,
    double amplitude, {
    int samplesPerHalf = 24,
  }) {
    final samples = math.max(48, crossings * samplesPerHalf);
    return _dedupe([
      for (var i = 0; i <= samples; i++)
        Offset(
          span * i / samples,
          amplitude *
              math.sin(math.pi * crossings * (span * i / samples) / span),
        ),
    ]);
  }

  static List<Offset> _build(
    double span,
    int crossings,
    double amplitude,
    MeanderStyle style,
    double cornerRadius, {
    int segments = roundSegments,
  }) => switch (style) {
    MeanderStyle.sine => _sine(span, crossings, amplitude),
    MeanderStyle.zigzag => _square(
      span,
      crossings,
      amplitude,
      cornerRadius,
      segments: segments,
    ),
  };

  /// The bulge that makes this serpentine exactly [target] long. Length
  /// grows with amplitude, so a bisection is exact. Null when even
  /// [maxAmplitude] is not enough.
  static double? _solveAmplitude(
    double span,
    int crossings,
    double target,
    double maxAmplitude,
    MeanderStyle style,
    double cornerRadius,
  ) {
    double lengthAt(double amplitude) =>
        polylineLength(_build(span, crossings, amplitude, style, cornerRadius));
    if (lengthAt(maxAmplitude) < target - 1e-7) return null;
    if (lengthAt(0) >= target) return 0;
    var lo = 0.0;
    var hi = maxAmplitude;
    for (var i = 0; i < 48; i++) {
      final mid = (lo + hi) / 2;
      if (lengthAt(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Folds [added] mm into a run of [span], at most [maxAmplitude] off the
  /// centre line, with runs at least [minRun] apart. Takes the fewest
  /// crossings that fit — the biggest, laziest meander, the one that looks
  /// most like routed copper.
  static MeanderFit buildLocal({
    required double span,
    required double added,
    required double maxAmplitude,
    required double minRun,
    double cornerRadius = 0.8,
    MeanderStyle style = MeanderStyle.zigzag,
  }) {
    if (span <= _eps) {
      return MeanderFit(span: span, reason: 'the run has no length');
    }
    if (added <= 1e-7) {
      return MeanderFit(
        points: [Offset.zero, Offset(span, 0)],
        ok: true,
        span: span,
      );
    }
    if (maxAmplitude <= 1e-6) {
      return MeanderFit(span: span, reason: 'the amplitude budget is zero');
    }
    final run = minRun <= 0 ? 0.2 : minRun;

    // n crossings travel about 2·amplitude·n sideways, so start there.
    final nStart = math.max(1, (added / (2 * maxAmplitude)).ceil());
    final nMax = (span / run).floor() - 1;
    if (nMax < 1) {
      return MeanderFit(
        span: span,
        reason:
            'the run is ${span.toStringAsFixed(2)} mm — too short to fold '
            '${added.toStringAsFixed(2)} mm into',
      );
    }
    if (nStart > nMax) {
      return MeanderFit(
        span: span,
        reason:
            'needs at least $nStart crossings but only $nMax fit in '
            '${span.toStringAsFixed(2)} mm',
      );
    }

    final target = span + added;
    for (var crossings = nStart; crossings <= nMax; crossings++) {
      final amplitude = _solveAmplitude(
        span,
        crossings,
        target,
        maxAmplitude,
        style,
        cornerRadius,
      );
      if (amplitude == null) continue;
      final points = _build(span, crossings, amplitude, style, cornerRadius);
      final length = polylineLength(points);
      // Rounding ate more than the model allowed for: denser does better.
      if (length < target - 1e-3) continue;
      return MeanderFit(
        points: points,
        ok: true,
        amplitude: amplitude,
        crossings: crossings,
        span: span,
        added: length - span,
      );
    }
    return MeanderFit(
      span: span,
      reason:
          'cannot fold ${added.toStringAsFixed(2)} mm into '
          '${span.toStringAsFixed(2)} mm within a '
          '${maxAmplitude.toStringAsFixed(2)} mm amplitude budget',
    );
  }

  /// A serpentine of a set shape along a run of [span], in the run's own
  /// frame — u along it, v to its left.
  ///
  /// It starts and ends on the centre line, so it splices into a route
  /// without moving either end.
  static List<Offset> serpentine(double span, MeanderShape shape) {
    if (span <= _eps || shape.amplitude <= _eps || shape.pitch <= _eps) {
      return [Offset.zero, Offset(span, 0)];
    }
    // Each crossing is half a wave, so a wave of the asked-for pitch is two
    // of them. Fewer than one crossing is not a meander, just a line.
    final crossings = (2 * span / shape.pitch).floor() - 1;
    if (crossings < 1) return [Offset.zero, Offset(span, 0)];
    // Curved corners, the way the meander tuner draws them, not cut off at
    // 45°. A meander is the one place on the board where the 45° habit is
    // wrong: the whole point of the shape is that it turns the signal round
    // without a discontinuity, and a chamfer is two discontinuities where a
    // curve is none.
    return _build(
      span,
      crossings,
      shape.amplitude,
      shape.style,
      shape.cornerRadius,
    );
  }

  /// [local] (u along, v to the left) laid along the run from [a] to [b].
  static List<Offset> alongRun(Offset a, Offset b, List<Offset> local) {
    final length = (b - a).distance;
    if (length < _eps) return [a, b];
    final u = (b - a) / length;
    final n = Offset(u.dy, -u.dx);
    return [for (final p in local) a + u * p.dx + n * p.dy];
  }

  /// [local] (u along, v to the left) put in place of run [index].
  static List<Offset> _splice(
    List<Offset> points,
    int index,
    List<Offset> local,
  ) {
    final a = points[index];
    final b = points[index + 1];
    final length = (b - a).distance;
    if (length < _eps) return [...points];
    final u = (b - a) / length;
    // Left of travel as the board is seen, y down.
    final n = Offset(u.dy, -u.dx);
    final mapped = [for (final p in local) a + u * p.dx + n * p.dy];
    return [
      ...points.take(index + 1),
      ...mapped.skip(1),
      ...points.skip(index + 2),
    ];
  }

  /// [points] with a meander in its longest run that can hold one, making
  /// the whole route [targetLength] long. The rest of the route stays as
  /// drawn.
  static MeanderFit meanderPolyline(
    List<Offset> points,
    double targetLength, {
    double maxAmplitude = 4,
    double cornerRadius = 0.8,
    MeanderStyle style = MeanderStyle.zigzag,
    double trackWidth = 0.25,
    double clearance = 0.2,
  }) {
    if (points.length < 2) {
      return MeanderFit(points: points, reason: 'a route needs two points');
    }
    final base = polylineLength(points);
    if (targetLength <= base + _eps) {
      return MeanderFit(points: points, ok: true, reason: 'no length to add');
    }
    final added = targetLength - base;
    final minRun = math.max(trackWidth + clearance, 0.05);
    final order = [for (var i = 0; i < points.length - 1; i++) i]
      ..sort(
        (a, b) => (points[b + 1] - points[b]).distance.compareTo(
          (points[a + 1] - points[a]).distance,
        ),
      );
    var lastReason = '';
    for (final index in order) {
      final fit = buildLocal(
        span: (points[index + 1] - points[index]).distance,
        added: added,
        maxAmplitude: maxAmplitude,
        minRun: minRun,
        cornerRadius: cornerRadius,
        style: style,
      );
      if (!fit.ok) {
        lastReason = fit.reason;
        continue;
      }
      final spliced = _splice(points, index, fit.points);
      return fit.copyWith(
        points: spliced,
        segmentIndex: index,
        added: polylineLength(spliced) - base,
      );
    }
    return MeanderFit(
      points: points,
      reason: lastReason.isEmpty
          ? 'no run can hold that much extra length'
          : lastReason,
    );
  }

  /// Turns a route and a target into a tuned route and a verdict.
  static TuningResult tune({
    required List<Offset> route,
    required double targetLength,
    required double psPerMm,
    double maxAmplitude = 4,
    double cornerRadius = 0.8,
    MeanderStyle style = MeanderStyle.zigzag,
    double trackWidth = 0.25,
    double clearance = 0.2,
    double tolerancePs = 1,
  }) {
    final base = polylineLength(route);
    TuningResult result(
      List<Offset> tuned,
      TuningStatus status, [
      String reason = '',
      MeanderFit? fit,
    ]) => TuningResult(
      psPerMm: psPerMm,
      baseLength: base,
      targetLength: targetLength,
      totalLength: polylineLength(tuned),
      status: status,
      points: tuned,
      reason: reason,
      fit: fit,
    );

    if (targetLength <= base + _eps) {
      if ((targetLength - base).abs() * psPerMm <= tolerancePs) {
        return result(route, TuningStatus.matched, 'already the right length');
      }
      return result(
        route,
        TuningStatus.long,
        'the shortest path is already '
        '${(base - targetLength).toStringAsFixed(2)} mm longer than the '
        'target — length can only be added, so tune the other trace',
      );
    }
    final fit = meanderPolyline(
      route,
      targetLength,
      maxAmplitude: maxAmplitude,
      cornerRadius: cornerRadius,
      style: style,
      trackWidth: trackWidth,
      clearance: clearance,
    );
    if (!fit.ok) {
      return result(route, TuningStatus.infeasible, fit.reason, fit);
    }
    final reached = (targetLength - fit.length).abs() * psPerMm;
    if (reached <= tolerancePs) {
      return result(fit.points, TuningStatus.matched, '', fit);
    }
    return result(
      fit.points,
      TuningStatus.short,
      'the meander could not quite reach the target length',
      fit,
    );
  }
}
