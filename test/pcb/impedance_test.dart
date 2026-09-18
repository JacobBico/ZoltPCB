import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

void main() {
  group('microstrip', () {
    // The textbook case: 50 Ω on 1.6 mm FR-4 wants a track just under 3 mm
    // wide. Every published calculator puts it between 2.9 and 3.0 mm.
    test('50 Ω on 1.6 mm FR-4 is about 3 mm wide', () {
      final (z0, eeff) = ImpedanceCalculator.microstrip(
        width: 2.95,
        height: 1.6,
        thickness: 0.035,
        er: 4.5,
      );
      expect(z0, closeTo(50, 1.5));
      // Part air, part board: between the two.
      expect(eeff, inInclusiveRange(1, 4.5));
      expect(eeff, closeTo(3.36, 0.1));
    });

    test('a wider track is a lower impedance', () {
      double z(double w) => ImpedanceCalculator.microstrip(
        width: w,
        height: 0.2,
        thickness: 0.035,
        er: 4.4,
      ).$1;
      expect(z(0.2), greaterThan(z(0.3)));
      expect(z(0.3), greaterThan(z(0.5)));
    });

    test('thicker copper lowers it a little', () {
      double z(double t) => ImpedanceCalculator.microstrip(
        width: 0.35,
        height: 0.2,
        thickness: t,
        er: 4.4,
      ).$1;
      expect(z(0.035), lessThan(z(0.0175)));
      expect(z(0.0175) - z(0.035), lessThan(3));
    });
  });

  group('stripline', () {
    test('agrees with the IPC-2141 approximation near 50 Ω', () {
      // IPC-2141: Z = 60/√εr · ln(4b / (0.67π(0.8w + t))) → 48.4 Ω here.
      final z = ImpedanceCalculator.stripline(
        width: 0.15,
        planeSpacing: 0.435,
        thickness: 0.035,
        er: 4.3,
      );
      expect(z, closeTo(48.4, 1.5));
    });

    test('in air a thin strip is the textbook value', () {
      // Cohn's exact result for w/b = 0.4 in air is about 112 Ω.
      final z = ImpedanceCalculator.stripline(
        width: 0.2,
        planeSpacing: 0.5,
        thickness: 0,
        er: 1,
      );
      expect(z, closeTo(112, 3));
    });
  });

  group('from a stackup', () {
    test('a two-layer board needs a wide track for 50 Ω', () {
      final width = ImpedanceCalculator.widthFor(
        Stackup.standard(layerCount: 2),
        CopperLayer.front,
        target: 50,
      );
      expect(width, closeTo(2.8, 0.15));
    });

    test('a four-layer board makes 50 Ω a sane width', () {
      final stackup = Stackup.standard(layerCount: 4);
      final width = ImpedanceCalculator.widthFor(
        stackup,
        CopperLayer.front,
        target: 50,
      )!;
      expect(width, inInclusiveRange(0.3, 0.4));
      final line = ImpedanceCalculator.of(
        stackup,
        CopperLayer.front,
        width: width,
      );
      expect(line.z0, closeTo(50, 0.01));
      expect(line.kind, LineKind.microstrip);
    });

    test('a buried layer is stripline and slower than the outer layer', () {
      final stackup = Stackup.standard(layerCount: 6);
      final outer = ImpedanceCalculator.of(
        stackup,
        CopperLayer.front,
        width: 0.2,
      );
      final inner = ImpedanceCalculator.of(
        stackup,
        CopperLayer.inner2,
        width: 0.2,
      );
      expect(inner.kind, isNot(LineKind.microstrip));
      // Wholly inside the board, a signal sees all of its permittivity.
      expect(inner.delayPsPerMm, greaterThan(outer.delayPsPerMm));
      expect(inner.delayPsPerMm, closeTo(7.1, 0.3));
      expect(outer.delayPsPerMm, closeTo(5.9, 0.4));
    });

    test('a 90 Ω pair: the gap brings the pair below twice one track', () {
      final stackup = Stackup.standard(layerCount: 4);
      final single = ImpedanceCalculator.of(
        stackup,
        CopperLayer.front,
        width: 0.15,
      );
      final pair = ImpedanceCalculator.of(
        stackup,
        CopperLayer.front,
        width: 0.15,
        gap: 0.15,
      );
      expect(pair.zDiff, lessThan(2 * single.z0));
      final wider = ImpedanceCalculator.of(
        stackup,
        CopperLayer.front,
        width: 0.15,
        gap: 0.5,
      );
      expect(wider.zDiff, greaterThan(pair.zDiff!));

      final width = ImpedanceCalculator.widthFor(
        stackup,
        CopperLayer.front,
        target: 90,
        gap: 0.15,
      );
      expect(width, isNotNull);
      expect(
        ImpedanceCalculator.of(
          stackup,
          CopperLayer.front,
          width: width!,
          gap: 0.15,
        ).zDiff,
        closeTo(90, 0.01),
      );
    });

    test('a target no width can reach says so', () {
      expect(
        ImpedanceCalculator.widthFor(
          Stackup.standard(layerCount: 4),
          CopperLayer.front,
          target: 400,
        ),
        isNull,
      );
    });
  });
}
