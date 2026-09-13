import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';
import 'package:hintpcb/rendering/schematic_viewport.dart';

void main() {
  // "the power label kinda jumps/glitches/moves weirdly around the power
  // symbol when I zoom in and out or move side to side."
  //
  // It was laid out in screen pixels — a fixed six-pixel gap from a box
  // that grows with the zoom — so the text crept towards the symbol as the
  // drawing was magnified. On a power symbol, a few millimetres across,
  // that crawl was most of the symbol's width.
  group('reported: the label moves about when the sheet is zoomed', () {
    const body = Rect.fromLTWH(40, 50, 2.54, 5.08);

    test('the label sits the same distance from the symbol at any zoom', () {
      final places = SchematicPainter.fieldPlacement(
        bounds: body,
        reference: '#PWR02',
      );

      // Measured on the sheet, the gap is a constant — so converting it at
      // two magnifications gives two screen gaps in the same ratio as the
      // zoom, which is what "not moving" means.
      for (final pixelsPerMm in [3.0, 8.0, 20.0]) {
        final viewport = SchematicViewport(
          pixelsPerMm: pixelsPerMm,
          origin: const Offset(11, 13),
        );
        final gap =
            viewport.toScreen(places.value).dy -
            viewport.toScreen(body.topLeft).dy;
        expect(
          gap / pixelsPerMm,
          closeTo(places.value.dy - body.top, 1e-9),
          reason: 'the gap must scale with the drawing, not fight it',
        );
      }
    });

    test('panning moves the label exactly as far as the symbol', () {
      final places = SchematicPainter.fieldPlacement(
        bounds: body,
        reference: '#PWR02',
      );
      const a = SchematicViewport(pixelsPerMm: 6, origin: Offset(0, 0));
      const b = SchematicViewport(pixelsPerMm: 6, origin: Offset(37, -12));

      expect(
        b.toScreen(places.value) - a.toScreen(places.value),
        b.toScreen(body.topLeft) - a.toScreen(body.topLeft),
      );
    });
  });

  test('a power symbol shows its value but not its #PWR designator', () {
    final power = SchematicPainter.fieldPlacement(
      bounds: const Rect.fromLTWH(0, 0, 2.54, 5.08),
      reference: '#PWR01',
    );
    expect(power.reference, isNull);

    final resistor = SchematicPainter.fieldPlacement(
      bounds: const Rect.fromLTWH(0, 0, 2.54, 5.08),
      reference: 'R1',
    );
    expect(resistor.reference, isNotNull);
  });

  test('fields go beside a tall symbol and above and below a wide one', () {
    final tall = SchematicPainter.fieldPlacement(
      bounds: const Rect.fromLTWH(0, 0, 2.54, 7.62),
      reference: 'R1',
    );
    // Beside: both fields to the right of the body, stacked.
    expect(tall.align, TextAlign.left);
    expect(tall.reference!.dx, greaterThan(2.54));
    expect(tall.value.dx, greaterThan(2.54));

    final wide = SchematicPainter.fieldPlacement(
      bounds: const Rect.fromLTWH(0, 0, 7.62, 2.54),
      reference: 'U1',
    );
    expect(wide.align, TextAlign.center);
    expect(wide.reference!.dy, lessThan(0));
    expect(wide.value.dy, greaterThan(2.54));
  });
}
