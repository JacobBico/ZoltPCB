import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

// Ported from meander_gui_implementation/test_meander_engine.py, zigzag
// ("rounded") and sine ("smooth") cases.
const _tol = 1e-3;

void main() {
  _serpentineTests();

  group('timing', () {
    test('FR-4 stripline is about 6.8 ps/mm', () {
      expect(MeanderEngine.psPerMm(4.2), closeTo(6.836, 0.01));
    });
    test('microstrip is faster', () {
      expect(MeanderEngine.psPerMm(3.6), lessThan(MeanderEngine.psPerMm(4.2)));
    });
    test('vacuum is the speed of light', () {
      expect(MeanderEngine.psPerMm(1), closeTo(1 / 0.299792458, 1e-9));
    });
  });

  group('fitting a meander into a run', () {
    const cases = [
      (80.0, 2.0, 4.0, 0.45, 0.8, MeanderStyle.zigzag),
      (80.0, 5.0, 4.0, 0.45, 0.8, MeanderStyle.zigzag),
      (80.0, 12.0, 4.0, 0.45, 0.8, MeanderStyle.zigzag),
      (80.0, 20.0, 4.0, 0.45, 0.8, MeanderStyle.zigzag),
      (80.0, 35.0, 4.0, 0.45, 0.8, MeanderStyle.zigzag),
      (40.0, 9.0, 2.0, 0.45, 0.5, MeanderStyle.zigzag),
      (120.0, 60.0, 6.0, 0.45, 1.0, MeanderStyle.zigzag),
      (80.0, 2.0, 4.0, 0.45, 0.0, MeanderStyle.sine),
      (80.0, 12.0, 4.0, 0.45, 0.0, MeanderStyle.sine),
      (80.0, 20.0, 4.0, 0.45, 0.0, MeanderStyle.sine),
      (150.0, 45.0, 5.0, 0.45, 0.0, MeanderStyle.sine),
    ];

    for (final (span, added, maxAmp, minRun, radius, style) in cases) {
      test('${style.label}: $added mm into $span mm, budget $maxAmp', () {
        final fit = MeanderEngine.buildLocal(
          span: span,
          added: added,
          maxAmplitude: maxAmp,
          minRun: minRun,
          cornerRadius: radius,
          style: style,
        );
        expect(fit.ok, isTrue, reason: fit.reason);
        // Exactly the length asked for.
        expect(fit.length, closeTo(span + added, _tol));
        // Within the amplitude budget, with runs at least the spacing.
        expect(fit.amplitude, lessThanOrEqualTo(maxAmp + 1e-6));
        expect(span / (fit.crossings + 1), greaterThanOrEqualTo(minRun - 1e-9));
        // Starts and ends on the centre line, so it splices in cleanly.
        expect(fit.points.first, Offset.zero);
        expect(fit.points.last.dy.abs(), lessThan(1e-9));
        expect(fit.points.last.dx, closeTo(span, 1e-9));
      });
    }

    test('no added length is a straight line', () {
      final fit = MeanderEngine.buildLocal(
        span: 40,
        added: 0,
        maxAmplitude: 4,
        minRun: 0.45,
      );
      expect(fit.points, const [Offset.zero, Offset(40, 0)]);
    });

    test('a bigger budget needs fewer crossings', () {
      int crossings(double budget) => MeanderEngine.buildLocal(
        span: 80,
        added: 20,
        maxAmplitude: budget,
        minRun: 0.45,
      ).crossings;
      expect(crossings(6), lessThan(crossings(2)));
    });

    test('a run too short to hold it says so', () {
      final fit = MeanderEngine.buildLocal(
        span: 0.6,
        added: 10,
        maxAmplitude: 1,
        minRun: 0.45,
      );
      expect(fit.ok, isFalse);
      expect(fit.reason, contains('too short'));
    });
  });

  group('a whole route', () {
    test('meanders, and keeps both ends where they were', () {
      const route = [Offset(0, 0), Offset(50, 0)];
      final fit = MeanderEngine.meanderPolyline(route, 60);
      expect(fit.ok, isTrue);
      expect(fit.points.first, route.first);
      expect(fit.points.last, route.last);
      expect(fit.length, closeTo(60, _tol));
    });

    test('folds the longest run of a bent route, and leaves the rest', () {
      const route = [Offset(0, 0), Offset(10, 0), Offset(10, 60)];
      final fit = MeanderEngine.meanderPolyline(route, 80);
      expect(fit.segmentIndex, 1);
      expect(fit.points.take(2), route.take(2));
    });

    test('does the same thing twice', () {
      const route = [Offset(0, 0), Offset(40, 0), Offset(40, 30)];
      final a = MeanderEngine.meanderPolyline(route, 90);
      final b = MeanderEngine.meanderPolyline(route, 90);
      expect(a.points, b.points);
    });

    test('a turned run is folded along it, not across the board', () {
      final route = [
        Offset.zero,
        Offset(30 * math.cos(0.7), 30 * math.sin(0.7)),
      ];
      final fit = MeanderEngine.meanderPolyline(route, 36);
      expect(fit.length, closeTo(36, _tol));
      expect(fit.points.last, route.last);
    });
  });

  group('the verdict', () {
    const ps = 6.836;

    test('matched when it reaches the target', () {
      final result = MeanderEngine.tune(
        route: const [Offset(0, 0), Offset(50, 0)],
        targetLength: 60,
        psPerMm: ps,
      );
      expect(result.status, TuningStatus.matched);
      expect(result.deltaPs.abs(), lessThan(1));
      expect(result.fit!.crossings, greaterThan(0));
      expect(result.fit!.amplitude, greaterThan(0));
    });

    test('already equal is matched, with nothing done', () {
      final result = MeanderEngine.tune(
        route: const [Offset(0, 0), Offset(50, 0)],
        targetLength: 50,
        psPerMm: ps,
      );
      expect(result.status, TuningStatus.matched);
      expect(result.points, const [Offset(0, 0), Offset(50, 0)]);
    });

    test('too long, because length cannot be taken away', () {
      final result = MeanderEngine.tune(
        route: const [Offset(0, 0), Offset(50, 0)],
        targetLength: 40,
        psPerMm: ps,
      );
      expect(result.status, TuningStatus.long);
      expect(result.reason, contains('only be added'));
      // A straight route is never shortened.
      expect(result.totalLength, 50);
    });

    test('no fit when there is nowhere to put it', () {
      final result = MeanderEngine.tune(
        route: const [Offset(0, 0), Offset(0.6, 0)],
        targetLength: 30,
        psPerMm: ps,
      );
      expect(result.status, TuningStatus.infeasible);
    });
  });
}

void _serpentineTests() {
  group('the shape the Route tool draws live', () {
    test('it starts and ends on the line, and adds length', () {
      const shape = MeanderShape(amplitude: 1.5, pitch: 1.2);
      final points = MeanderEngine.serpentine(20, shape);
      expect(points.first, Offset.zero);
      expect(points.last.dx, closeTo(20, 1e-6));
      expect(points.last.dy, closeTo(0, 1e-6));
      expect(MeanderEngine.polylineLength(points), greaterThan(40));
      for (final p in points) {
        expect(p.dy.abs(), lessThanOrEqualTo(1.5 + 1e-6));
      }
    });

    test('a zigzag turns through a curve, not a corner', () {
      // "the zig zag variation has 45 degree turning where as it should be
      // a smooth curve like the meander gui had setup". A curve shows up
      // as a run of small, steadily changing turns; a chamfer is one big
      // one.
      const shape = MeanderShape(amplitude: 2, pitch: 2, cornerRadius: 0.8);
      final points = MeanderEngine.serpentine(20, shape);
      var sharp = 0;
      for (var i = 1; i < points.length - 1; i++) {
        final into = points[i] - points[i - 1];
        final outOf = points[i + 1] - points[i];
        if (into.distance < 1e-9 || outOf.distance < 1e-9) continue;
        final cos =
            (into.dx * outOf.dx + into.dy * outOf.dy) /
            (into.distance * outOf.distance);
        // More than about 30° at one point is a corner, not a curve.
        if (cos < 0.86) sharp++;
      }
      expect(sharp, 0, reason: 'the loops turn in steps, not in corners');
    });

    test('too short to loop, it is simply the line', () {
      const shape = MeanderShape(pitch: 4);
      expect(MeanderEngine.serpentine(2, shape), [
        Offset.zero,
        const Offset(2, 0),
      ]);
    });

    test('laid along a run, it keeps both ends where they were', () {
      const a = Offset(10, 10);
      const b = Offset(10, 25);
      final laid = MeanderEngine.alongRun(
        a,
        b,
        MeanderEngine.serpentine((b - a).distance, const MeanderShape()),
      );
      expect(laid.first, a);
      expect((laid.last - b).distance, lessThan(1e-6));
      expect(MeanderEngine.polylineLength(laid), greaterThan(15));
    });
  });
}
