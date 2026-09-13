import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/pin.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/rendering/schematic_geometry.dart';

void expectOffset(Offset actual, Offset expected, {double tolerance = 1e-6}) {
  expect(actual.dx, closeTo(expected.dx, tolerance));
  expect(actual.dy, closeTo(expected.dy, tolerance));
}

void main() {
  group('placement', () {
    test('flips Y, because symbols are drawn Y-up and sheets are Y-down', () {
      const placement = Placement(x: 100, y: 50);

      expectOffset(placement.apply(0, 0), const Offset(100, 50));
      // A point above the origin in symbol space is above it on the sheet,
      // which means a smaller Y.
      expectOffset(placement.apply(0, 10), const Offset(100, 40));
      expectOffset(placement.apply(5, -5), const Offset(105, 55));
    });

    test('rotates counter-clockwise as seen on screen', () {
      const placement = Placement(x: 0, y: 0, rotation: 90);

      // Symbol +X (right) becomes screen up under a 90° turn.
      expectOffset(placement.apply(10, 0), const Offset(0, -10));
      expectOffset(placement.apply(0, 10), const Offset(-10, 0));
    });

    test('180° turns a symbol end for end', () {
      const placement = Placement(x: 0, y: 0, rotation: 180);
      expectOffset(placement.apply(10, 0), const Offset(-10, 0));
      expectOffset(placement.apply(0, 10), const Offset(0, 10));
    });

    test('mirroring flips about the symbol axis, before rotation', () {
      const mirrored = Placement(x: 0, y: 0, mirrorY: true);
      expectOffset(mirrored.apply(10, 0), const Offset(-10, 0));
      expectOffset(mirrored.apply(0, 10), const Offset(0, -10));

      const mirroredX = Placement(x: 0, y: 0, mirrorX: true);
      expectOffset(mirroredX.apply(10, 0), const Offset(10, 0));
      expectOffset(mirroredX.apply(0, 10), const Offset(0, 10));
    });

    test('translation is applied after rotation', () {
      const placement = Placement(x: 100, y: 100, rotation: 90);
      expectOffset(placement.apply(10, 0), const Offset(100, 90));
    });

    test('pin direction follows the placement', () {
      // A pin pointing right in symbol space points right on the sheet.
      expect(const Placement(x: 0, y: 0).pinAngle(0), 0);
      // Symbol "up" (90°) is screen up, which is 270° clockwise-from-East.
      expect(const Placement(x: 0, y: 0).pinAngle(90), 270);
      expect(const Placement(x: 0, y: 0, rotation: 90).pinAngle(0), 270);
      expect(const Placement(x: 0, y: 0, rotation: 180).pinAngle(0), 180);
    });
  });

  group('arcs', () {
    test('recovers the circle through three points', () {
      final arc = arcThroughPoints(
        const Offset(-1, 0),
        const Offset(0, 1),
        const Offset(1, 0),
      )!;

      expectOffset(arc.center, Offset.zero, tolerance: 1e-9);
      expect(arc.radius, closeTo(1, 1e-9));
    });

    test('sweeps the way round that passes through the middle point', () {
      // Upper half: start left, through the top, to the right.
      final upper = arcThroughPoints(
        const Offset(-1, 0),
        const Offset(0, -1),
        const Offset(1, 0),
      )!;
      // Lower half: same ends, middle point on the other side.
      final lower = arcThroughPoints(
        const Offset(-1, 0),
        const Offset(0, 1),
        const Offset(1, 0),
      )!;

      expect(upper.sweepAngle.sign, isNot(lower.sweepAngle.sign));
      expect(upper.sweepAngle.abs(), closeTo(math.pi, 1e-9));
      expect(lower.sweepAngle.abs(), closeTo(math.pi, 1e-9));
    });

    test('the midpoint really lies on the recovered arc', () {
      final arc = arcThroughPoints(
        const Offset(2, 0),
        const Offset(1.4142135, 1.4142135),
        const Offset(0, 2),
      )!;

      final midAngle = arc.startAngle + arc.sweepAngle / 2;
      final point = Offset(
        arc.center.dx + arc.radius * math.cos(midAngle),
        arc.center.dy + arc.radius * math.sin(midAngle),
      );
      expectOffset(point, const Offset(1.4142135, 1.4142135), tolerance: 1e-4);
    });

    test('collinear points are not an arc', () {
      expect(
        arcThroughPoints(
          const Offset(0, 0),
          const Offset(1, 1),
          const Offset(2, 2),
        ),
        isNull,
      );
    });
  });

  group('bounds', () {
    SymbolDefinition symbolWith(List<SymbolGraphic> graphics, List<SymbolPin> pins) =>
        SymbolDefinition(
          libraryNickname: 'Test',
          name: 'S',
          unitDrawings: [
            SymbolUnitDrawing(
              unit: 1,
              bodyStyle: 1,
              graphics: graphics,
              pins: pins,
            ),
          ],
        );

    test('covers graphics and pin stubs', () {
      final symbol = symbolWith(
        const [
          SymbolRectangle(
            start: SymbolPoint(-1, -2.54),
            end: SymbolPoint(1, 2.54),
          ),
        ],
        const [
          SymbolPin(
            number: '1',
            name: '~',
            electricalType: PinElectricalType.passive,
            at: SymbolPoint(0, 3.81),
            angle: 270,
            length: 1.27,
          ),
        ],
      );

      final bounds = symbolBounds(symbol, 1);
      expect(bounds.left, -1);
      expect(bounds.right, 1);
      expect(bounds.bottom, closeTo(3.81, 1e-9));
    });

    test('a symbol with nothing in it has empty bounds', () {
      expect(symbolBounds(symbolWith(const [], const []), 1), Rect.zero);
    });

    test('a circle contributes its full extent', () {
      final symbol = symbolWith(
        const [SymbolCircle(center: SymbolPoint(0, 0), radius: 2.5)],
        const [],
      );
      final bounds = symbolBounds(symbol, 1);
      expect(bounds.left, -2.5);
      expect(bounds.right, 2.5);
    });
  });
}
