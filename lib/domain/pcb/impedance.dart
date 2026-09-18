import 'dart:math' as math;

import 'board_layer.dart';
import 'stackup.dart';

/// The speed of light, in millimetres per nanosecond.
const _c = 299.792458;

/// The impedance of free space, in ohms.
const _eta0 = 376.730313;

/// What sort of transmission line a track on a given layer makes.
enum LineKind {
  /// On an outer layer, over one plane, with air above.
  microstrip('Microstrip'),

  /// Buried, between two planes the same distance away.
  stripline('Stripline'),

  /// Buried, nearer one plane than the other.
  asymmetricStripline('Offset stripline');

  const LineKind(this.label);

  final String label;
}

/// A track's electrical character, worked out from its geometry.
class LineImpedance {
  const LineImpedance({
    required this.kind,
    required this.z0,
    required this.epsilonEffective,
    this.zDiff,
  });

  final LineKind kind;

  /// Characteristic impedance of the single track, in ohms.
  final double z0;

  /// Impedance of the pair, when worked out for one.
  final double? zDiff;

  /// The permittivity a signal on this track actually sees — part air,
  /// part board, for a microstrip.
  final double epsilonEffective;

  /// How long a signal takes to travel a millimetre, in picoseconds.
  double get delayPsPerMm => 1000 * math.sqrt(epsilonEffective) / _c;

  /// Signal speed as a fraction of the speed of light.
  double get velocityFactor => 1 / math.sqrt(epsilonEffective);
}

/// Closed-form impedance of a PCB track, from the board's stackup.
///
/// Microstrip uses Hammerstad and Jensen's equations with Wheeler's
/// correction for copper thickness — the model behind KiCad's own
/// calculator and most others, within about 1% of a field solver over the
/// widths a board actually uses. Stripline uses Wheeler's 1978 formula,
/// and an offset stripline is taken as its two halves in parallel. Pairs
/// use the IPC-2141 coupling factor, which is rougher: good to within
/// perhaps 5–10%, fine for choosing a gap, not for signing one off.
///
/// None of it accounts for solder mask, which pulls a microstrip down by
/// two or three ohms, or for the glass weave. A fab offering controlled
/// impedance recalculates with its own laminate data; these numbers are
/// for getting the width right to begin with.
abstract final class ImpedanceCalculator {
  /// The impedance of a [width]-wide track on [layer], and of a pair
  /// [gap] apart if one is given.
  static LineImpedance of(
    Stackup stackup,
    CopperLayer layer, {
    required double width,
    double? gap,
  }) {
    final geometry = stackup.geometryOf(layer);
    return forGeometry(geometry, width: width, gap: gap);
  }

  static LineImpedance forGeometry(
    LayerGeometry geometry, {
    required double width,
    double? gap,
  }) {
    final t = geometry.copperThickness;
    final above = geometry.heightAbove;
    final below = geometry.heightBelow;

    if (above == null || below == null) {
      // Microstrip, over whichever side has a reference.
      final h = (above ?? below)!;
      final er = above == null ? geometry.epsilonBelow : geometry.epsilonAbove;
      final (z0, eeff) = microstrip(
        width: width,
        height: h,
        thickness: t,
        er: er,
      );
      return LineImpedance(
        kind: LineKind.microstrip,
        z0: z0,
        epsilonEffective: eeff,
        zDiff: gap == null
            ? null
            : 2 * z0 * (1 - 0.48 * math.exp(-0.96 * gap / h)),
      );
    }

    // Stripline. The dielectric is taken as the thickness-weighted mean of
    // what lies above and below — they are usually one core and one prepreg
    // of slightly different permittivity.
    final er =
        (geometry.epsilonAbove * above + geometry.epsilonBelow * below) /
        (above + below);
    final symmetric = (above - below).abs() < 1e-6;
    final double z0;
    if (symmetric) {
      z0 = stripline(
        width: width,
        planeSpacing: above + below + t,
        thickness: t,
        er: er,
      );
    } else {
      // Each half as a symmetric stripline twice its height, in parallel.
      final z1 = stripline(
        width: width,
        planeSpacing: 2 * above + t,
        thickness: t,
        er: er,
      );
      final z2 = stripline(
        width: width,
        planeSpacing: 2 * below + t,
        thickness: t,
        er: er,
      );
      z0 = 2 * z1 * z2 / (z1 + z2);
    }
    final b = above + below + t;
    return LineImpedance(
      kind: symmetric ? LineKind.stripline : LineKind.asymmetricStripline,
      z0: z0,
      epsilonEffective: er,
      zDiff: gap == null
          ? null
          : 2 * z0 * (1 - 0.347 * math.exp(-2.9 * gap / b)),
    );
  }

  /// Hammerstad–Jensen microstrip: impedance and effective permittivity.
  static (double, double) microstrip({
    required double width,
    required double height,
    required double thickness,
    required double er,
  }) {
    final u = width / height;
    final t = thickness / height;

    // Wheeler's thickness correction: a thick strip behaves like a wider
    // thin one, by rather less in the dielectric than in the air.
    var du1 = 0.0;
    var dur = 0.0;
    if (t > 0) {
      final coth = 1 / _tanh(math.sqrt(6.517 * u));
      du1 = t / math.pi * math.log(1 + 4 * math.e / (t * coth * coth));
      dur = 0.5 * (1 + 1 / _cosh(math.sqrt(er - 1))) * du1;
    }
    final u1 = u + du1;
    final ur = u + dur;

    double z01(double u) {
      final f = 6 + (2 * math.pi - 6) * math.exp(-math.pow(30.666 / u, 0.7528));
      return _eta0 /
          (2 * math.pi) *
          math.log(f / u + math.sqrt(1 + 4 / (u * u)));
    }

    double effective(double u) {
      final a =
          1 +
          math.log(
                (math.pow(u, 4) + math.pow(u / 52, 2)) /
                    (math.pow(u, 4) + 0.432),
              ) /
              49 +
          math.log(1 + math.pow(u / 18.1, 3)) / 18.7;
      final b = 0.564 * math.pow((er - 0.9) / (er + 3), 0.053);
      return (er + 1) / 2 + (er - 1) / 2 * math.pow(1 + 10 / u, -a * b);
    }

    final eeffR = effective(ur);
    final z0 = z01(ur) / math.sqrt(eeffR);
    final ratio = z01(u1) / z01(ur);
    final eeff = eeffR * ratio * ratio;
    return (z0, eeff);
  }

  /// Wheeler's stripline, for a strip centred between planes
  /// [planeSpacing] apart (the full distance, strip included).
  static double stripline({
    required double width,
    required double planeSpacing,
    required double thickness,
    required double er,
  }) {
    final b = planeSpacing;
    final t = thickness;
    final x = t / b;
    var wEff = width;
    if (x > 0) {
      final m = 2 / (1 + 2 / 3 * x / (1 - x));
      final dw =
          (x / (math.pi * (1 - x))) *
          (1 -
              0.5 *
                  math.log(
                    math.pow(x / (2 - x), 2) +
                        math.pow(0.0796 * x / (width / b + 1.1 * x), m),
                  ));
      wEff = width + dw * (b - t);
    }
    final k = (b - t) / wEff;
    final inner = 8 / math.pi * k;
    return _eta0 /
        (4 * math.pi * math.sqrt(er)) *
        math.log(
          1 + 4 / math.pi * k * (inner + math.sqrt(inner * inner + 6.27)),
        );
  }

  /// The width a track on [layer] needs to be [target] ohms, or the width
  /// of each half of a pair [gap] apart to be [target] ohms between them.
  ///
  /// Null when no sensible width gets there — 200 Ω on a thin prepreg
  /// would need a track narrower than any fab can etch.
  static double? widthFor(
    Stackup stackup,
    CopperLayer layer, {
    required double target,
    double? gap,
    double minWidth = 0.02,
    double maxWidth = 20,
  }) {
    double impedance(double width) {
      final line = of(stackup, layer, width: width, gap: gap);
      return gap == null ? line.z0 : line.zDiff!;
    }

    // Impedance falls as a track widens, so the target is bracketed.
    var lo = minWidth;
    var hi = maxWidth;
    if (impedance(lo) < target || impedance(hi) > target) return null;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (impedance(mid) > target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
}
