import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

void main() {
  group('the standard build', () {
    for (final count in CopperLayer.layerCounts) {
      test('$count layers comes out at the thickness asked for', () {
        final stackup = Stackup.standard(layerCount: count, thickness: 1.6);
        expect(stackup.layerCount, count);
        expect(stackup.dielectrics.length, count - 1);
        expect(stackup.thickness, closeTo(1.6, 0.001));
        expect(stackup.problem, isNull);
        expect(stackup.layers, CopperLayer.stack(count));
      });
    }

    test('six layers: every signal layer sits beside a plane', () {
      final stackup = Stackup.standard(layerCount: 6);
      final roles = [for (final c in stackup.copper) c.role];
      expect(roles, [
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.plane,
        LayerRole.signal,
      ]);
      for (var i = 0; i < roles.length; i++) {
        if (roles[i] != LayerRole.signal) continue;
        final neighbours = [
          if (i > 0) roles[i - 1],
          if (i < roles.length - 1) roles[i + 1],
        ];
        expect(neighbours, contains(LayerRole.plane), reason: 'layer $i');
      }
    });

    test('prepreg on the outside, cores alternating inward', () {
      final kinds = [
        for (final d in Stackup.standard(layerCount: 6).dielectrics) d.kind,
      ];
      expect(kinds, [
        DielectricKind.prepreg,
        DielectricKind.core,
        DielectricKind.prepreg,
        DielectricKind.core,
        DielectricKind.prepreg,
      ]);
    });

    test('outer copper heavier than inner, as quoted', () {
      final stackup = Stackup.standard(
        layerCount: 4,
        outer: CopperWeight.two,
        inner: CopperWeight.one,
      );
      expect(stackup.copperOf(CopperLayer.front).weight, CopperWeight.two);
      expect(stackup.copperOf(CopperLayer.inner1).weight, CopperWeight.one);
      expect(stackup.thickness, closeTo(1.6, 0.001));
    });

    test('a thinner board takes the difference out of the cores', () {
      final thick = Stackup.standard(layerCount: 4, thickness: 1.6);
      final thin = thick.withThickness(0.8);
      expect(thin.thickness, closeTo(0.8, 0.001));
      expect(
        thin.dielectrics.first.thickness,
        thick.dielectrics.first.thickness,
      );
      expect(
        thin.dielectrics[1].thickness,
        lessThan(thick.dielectrics[1].thickness),
      );
    });
  });

  group('storage', () {
    test('a build survives being written and read back', () {
      final original = Stackup.standard(layerCount: 6).copyWith(
        dielectrics: [
          for (final d in Stackup.standard(layerCount: 6).dielectrics)
            d.copyWith(epsilonR: 3.66, material: 'RO4350B'),
        ],
      );
      expect(Stackup.decode(original.encode(), layerCount: 6), original);
    });

    test('a build for another layer count is not used', () {
      final four = Stackup.standard(layerCount: 4).encode();
      expect(Stackup.decode(four, layerCount: 6), isNull);
      expect(Stackup.decode('', layerCount: 2), isNull);
      expect(Stackup.decode('not json', layerCount: 2), isNull);
    });

    test('a board with no build of its own gets the standard one', () {
      final board = Board(
        id: 'b',
        projectId: 'p',
        outlineX: 0,
        outlineY: 0,
        outlineWidth: 10,
        outlineHeight: 10,
        rules: const DesignRules(),
        gridMm: 0.5,
        modifiedAt: DateTime(2026),
        copperLayerCount: 6,
        thickness: 1.2,
      );
      expect(board.hasCustomStackup, isFalse);
      expect(board.stackup.layerCount, 6);
      expect(board.stackup.thickness, closeTo(1.2, 0.001));
      expect(board.copperLayers.length, 6);
      expect(board.nextLayer(CopperLayer.back), CopperLayer.front);
      expect(board.nextLayer(CopperLayer.front), CopperLayer.inner1);
    });
  });

  group('layers', () {
    test('KiCad numbers inner copper after the two outer layers', () {
      expect(CopperLayer.front.kicadIndex, 0);
      expect(CopperLayer.back.kicadIndex, 2);
      expect(CopperLayer.inner1.kicadIndex, 4);
      expect(CopperLayer.inner4.kicadIndex, 10);
    });

    test('Gerber file functions count from the top', () {
      expect(CopperLayer.front.fileFunction(6), 'Copper,L1,Top');
      expect(CopperLayer.inner2.fileFunction(6), 'Copper,L3,Inr');
      expect(CopperLayer.back.fileFunction(6), 'Copper,L6,Bot');
    });

    test('an inner layer stays put when a part is flipped', () {
      expect(BoardLayer.inner3Copper.flipped, BoardLayer.inner3Copper);
      expect(BoardLayer.frontCopper.flipped, BoardLayer.backCopper);
    });
  });

  group('where the return current flows', () {
    test('an outer layer is microstrip over the next layer in', () {
      final geometry = Stackup.standard(
        layerCount: 4,
      ).geometryOf(CopperLayer.front);
      expect(geometry.isStripline, isFalse);
      expect(geometry.heightAbove, isNull);
      expect(geometry.heightBelow, closeTo(0.2, 1e-9));
    });

    test('a buried signal layer is stripline between its planes', () {
      final stackup = Stackup.standard(layerCount: 6);
      final geometry = stackup.geometryOf(CopperLayer.inner2);
      expect(geometry.isStripline, isTrue);
      expect(geometry.heightAbove, stackup.dielectrics[1].thickness);
      expect(geometry.heightBelow, stackup.dielectrics[2].thickness);
    });

    test('a signal layer between it and the plane counts as dielectric', () {
      // SIG-GND-SIG-SIG-PWR-SIG: In2's plane below is In4, past In3.
      final base = Stackup.standard(layerCount: 6);
      final stackup = base.copyWith(
        copper: [
          for (final c in base.copper)
            c.layer == CopperLayer.inner3
                ? c.copyWith(role: LayerRole.signal)
                : c,
        ],
      );
      final geometry = stackup.geometryOf(CopperLayer.inner2);
      expect(
        geometry.heightBelow,
        closeTo(
          stackup.dielectrics[2].thickness +
              stackup.copperOf(CopperLayer.inner3).thickness +
              stackup.dielectrics[3].thickness,
          1e-9,
        ),
      );
    });
  });
}
