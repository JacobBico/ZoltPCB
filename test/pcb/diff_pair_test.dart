import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

void main() {
  group('which two nets make a pair', () {
    test('the suffixes KiCad reads, and nothing else', () {
      expect(DiffPairs.partnerName('USB_D+'), ('USB_D-', true));
      expect(DiffPairs.partnerName('USB_D-'), ('USB_D+', false));
      expect(DiffPairs.partnerName('CLK_P'), ('CLK_N', true));
      expect(DiffPairs.partnerName('CLK_N'), ('CLK_P', false));
      expect(DiffPairs.partnerName('lvds0_p'), ('lvds0_n', true));
      expect(DiffPairs.partnerName('GND'), isNull);
      expect(DiffPairs.partnerName('VCC'), isNull);
      // A name that is only the suffix is not half of anything.
      expect(DiffPairs.partnerName('+'), isNull);
    });
  });

  group('offsetting a run', () {
    test('a straight run moves sideways and keeps its length', () {
      final run = DiffPairs.offsetRun(const [Offset(0, 0), Offset(10, 0)], 0.5);
      expect(run.first, const Offset(0, -0.5));
      expect(run.last, const Offset(10, -0.5));
    });

    test('every run keeps its bearing, so 45s stay 45s', () {
      const drawn = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(15, 5),
        Offset(15, 12),
      ];
      for (final distance in [0.4, -0.4, 1.2]) {
        final run = DiffPairs.offsetRun(drawn, distance);
        expect(run, hasLength(drawn.length));
        for (var i = 0; i < drawn.length - 1; i++) {
          final want = drawn[i + 1] - drawn[i];
          final got = run[i + 1] - run[i];
          // Same direction, whatever the length of the mitred run.
          final cross = want.dx * got.dy - want.dy * got.dx;
          expect(
            cross.abs(),
            lessThan(1e-9),
            reason: 'run $i turned when it was offset by $distance',
          );
          expect(want.dx * got.dx + want.dy * got.dy, greaterThan(0));
        }
      }
    });

    test('the two halves stay the gap apart down the whole run', () {
      const drawn = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(16, 6),
        Offset(16, 14),
      ];
      final (positive, negative) = DiffPairs.runs(
        drawn,
        gap: 0.5,
        style: DiffPairStyle.mirrored,
        side: 1,
      );
      // Measured properly: every corner of one against every run of the
      // other, which is what a clearance check would do.
      expect(DiffPairs.gapBetween(positive, negative), closeTo(0.5, 1e-6));
      expect(DiffPairs.gapBetween(negative, positive), closeTo(0.5, 1e-6));
    });

    test('mirrored splits the gap; a copy puts it all on one side', () {
      const drawn = [Offset(0, 0), Offset(10, 0)];
      final (a, b) = DiffPairs.runs(
        drawn,
        gap: 0.6,
        style: DiffPairStyle.mirrored,
        side: 1,
      );
      expect(a.first.dy, closeTo(-0.3, 1e-9));
      expect(b.first.dy, closeTo(0.3, 1e-9));

      final (c, d) = DiffPairs.runs(
        drawn,
        gap: 0.6,
        style: DiffPairStyle.copy,
        side: 1,
      );
      expect(c.first, drawn.first, reason: 'the drawn run is one of them');
      expect(d.first.dy, closeTo(0.6, 1e-9));
    });

    test('a length matched round a corner: both halves the same', () {
      const drawn = [Offset(0, 0), Offset(10, 0), Offset(20, 10)];
      final (positive, negative) = DiffPairs.runs(
        drawn,
        gap: 0.4,
        style: DiffPairStyle.mirrored,
        side: 1,
      );
      double length(List<Offset> run) {
        var total = 0.0;
        for (var i = 0; i < run.length - 1; i++) {
          total += (run[i + 1] - run[i]).distance;
        }
        return total;
      }

      // The inside of a bend is shorter than the outside — that is
      // geometry, not a fault — but a mitred 45 keeps the difference to a
      // fraction of the gap rather than to a fraction of the run.
      expect(
        (length(positive) - length(negative)).abs(),
        lessThan(0.4),
        reason: 'the two halves came out badly unequal',
      );
    });

    test('the partner keeps the side its own pad is already on', () {
      // Otherwise the two halves cross each other on the way out of the
      // connector, which is the one thing a pair must never do.
      const drawn = [Offset(0, 0), Offset(10, 0)];
      for (final partner in const [Offset(0, 2), Offset(0, -2)]) {
        final (positive, negative) = DiffPairs.runs(
          drawn,
          gap: 0.6,
          style: DiffPairStyle.mirrored,
          side: DiffPairs.sideOf(drawn, partner),
        );
        expect(
          (negative.first - partner).distance,
          lessThan((positive.first - partner).distance),
          reason: 'the halves crossed for a partner at $partner',
        );
      }
    });

    test('a reversal does not send the run to infinity', () {
      const drawn = [Offset(0, 0), Offset(10, 0), Offset(0, 0)];
      final run = DiffPairs.offsetRun(drawn, 0.5);
      for (final p in run) {
        expect(p.dx.isFinite && p.dy.isFinite, isTrue);
        expect(p.dx.abs(), lessThan(100));
      }
    });
  });

  test('landing a run on a pad joins it on legal angles', () {
    const run = [Offset(5, 5), Offset(12, 5)];
    final landed = DiffPairs.landOn(run, const Offset(2, 3), atEnd: false);
    expect(landed.first, const Offset(2, 3));
    expect(landed.last, const Offset(12, 5));
    for (var i = 0; i < landed.length - 1; i++) {
      final d = landed[i + 1] - landed[i];
      final legal =
          d.dx.abs() < 1e-6 ||
          d.dy.abs() < 1e-6 ||
          (d.dx.abs() - d.dy.abs()).abs() < 1e-6;
      expect(legal, isTrue, reason: 'leg $i is at ${math.atan2(d.dy, d.dx)}');
    }
  });
}
