import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/editors/footprint_design.dart';
import 'package:hintpcb/domain/editors/symbol_design.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/features/components/component_browser_panel.dart';
import 'package:hintpcb/features/library_editors/footprint_match_dialog.dart';

const _threePins = [
  PinDesign(number: '1', name: 'IN+'),
  PinDesign(number: '2', name: 'IN-'),
  PinDesign(number: '3', name: 'OUT', side: PinSide.right),
];

void main() {
  // "a choice of what shape the symbol is, like triangle, square, or some
  // sort of polygon, additionally, I want to be able to drag the pins where
  // I so desire"
  group('body shapes', () {
    const pins = [
      PinDesign(number: '1', name: 'IN+'),
      PinDesign(number: '2', name: 'IN-'),
      PinDesign(number: '3', name: 'OUT', side: PinSide.right),
    ];

    test('each shape draws the body it names', () {
      SymbolGraphic body(BodyShape shape) => SymbolDesign(
        name: 'X',
        pins: pins,
        shape: shape,
      ).build().unitDrawings.single.graphics.single;

      expect(body(BodyShape.rectangle), isA<SymbolRectangle>());
      expect(body(BodyShape.circle), isA<SymbolCircle>());
      final triangle = body(BodyShape.triangle) as SymbolPolyline;
      expect(triangle.points, hasLength(4)); // three corners, closed
      final hexagon =
          SymbolDesign(
                name: 'X',
                pins: pins,
                shape: BodyShape.polygon,
                polygonSides: 6,
              ).build().unitDrawings.single.graphics.single
              as SymbolPolyline;
      expect(hexagon.points, hasLength(7));
    });

    test('a laid-out pin reaches exactly to the body, whatever its shape', () {
      for (final shape in BodyShape.values) {
        final design = SymbolDesign(name: 'X', pins: pins, shape: shape);
        for (final pin in design.build().pins) {
          final end = SymbolPoint(
            pin.at.x +
                (pin.angle == 0
                    ? pin.length
                    : pin.angle == 180
                    ? -pin.length
                    : 0),
            pin.at.y +
                (pin.angle == 90
                    ? pin.length
                    : pin.angle == 270
                    ? -pin.length
                    : 0),
          );
          // The stub's body end sits on the outline: stepping a hair further
          // along it is inside the body, a hair back is outside.
          final d = design.distanceToBody(
            end,
            SymbolPoint(
              pin.angle == 0
                  ? 1
                  : pin.angle == 180
                  ? -1
                  : 0,
              pin.angle == 90
                  ? 1
                  : pin.angle == 270
                  ? -1
                  : 0,
            ),
          );
          expect(d, closeTo(0, 1e-6), reason: '$shape pin ${pin.number}');
        }
      }
    });

    test('the triangle points at its output', () {
      final built = SymbolDesign(
        name: 'Amp',
        pins: pins,
        shape: BodyShape.triangle,
      ).build();
      final out = built.pins.firstWhere((p) => p.name == 'OUT');
      final inputs = built.pins.where((p) => p.name != 'OUT');
      expect(out.at.x, greaterThan(0));
      expect(inputs.every((p) => p.at.x < 0), isTrue);
    });
  });

  group('pins where you put them', () {
    test('a dragged pin keeps its place and faces the body', () {
      final design = SymbolDesign(
        name: 'X',
        pins: [
          const PinDesign(number: '1', name: 'A'),
          const PinDesign(number: '2', name: 'B', x: 2.54, y: -7.62),
        ],
      );
      final moved = design.build().pins.firstWhere((p) => p.number == '2');
      expect(moved.at, const SymbolPoint(2.54, -7.62));
      expect(moved.angle, 90); // below the body, pointing up into it
    });

    // "if I keep swiping left on the pin, it can almost go infinitely out
    // without it ever touching the symbol boundary"
    test('a dragged pin slides round the body and never leaves it', () {
      for (final shape in BodyShape.values) {
        final design = SymbolDesign(name: 'X', pins: _threePins, shape: shape);
        for (final finger in const [
          SymbolPoint(-500, 1.1), // far out to the left
          SymbolPoint(400, -2.3), // far right
          SymbolPoint(0.7, 90), // far above
          SymbolPoint(-1.9, -60), // far below
          SymbolPoint(-500, 500), // off past a corner
        ]) {
          for (final snap in [false, true]) {
            final moved = design.slidePin(0, finger, snap: snap);
            final after = design.copyWith(pins: [moved, ..._threePins.skip(1)]);
            final built = after.build().pins.first;
            final direction = SymbolPoint(
              (built.angle == 0 ? 1 : 0) - (built.angle == 180 ? 1 : 0),
              (built.angle == 90 ? 1 : 0) - (built.angle == 270 ? 1 : 0),
            );
            final end = SymbolPoint(
              built.at.x + direction.x * built.length,
              built.at.y + direction.y * built.length,
            );
            // Against the body as it is with the pin moved: a pin changing
            // sides can resize it.
            final gap = after.distanceToBody(end, direction);
            expect(
              gap,
              closeTo(0, 1e-6),
              reason: '$shape, finger $finger, snap $snap',
            );
            expect(built.at.x.abs(), lessThan(30), reason: '$shape $finger');
            expect(built.at.y.abs(), lessThan(30), reason: '$shape $finger');
            if (snap) {
              bool onGrid(double v) =>
                  ((v / SymbolDesign.grid) - (v / SymbolDesign.grid).round())
                      .abs() <
                  1e-6;
              expect(onGrid(built.at.x) && onGrid(built.at.y), isTrue);
            }
          }
        }
      }
    });

    test('dragging the same pin over and over does not stretch it', () {
      var design = SymbolDesign(
        name: 'X',
        pins: _threePins,
        shape: BodyShape.circle,
      );
      for (var i = 0; i < 20; i++) {
        final moved = design.slidePin(0, SymbolPoint(-40, i * 0.3 - 3));
        design = design.copyWith(pins: [moved, ...design.pins.skip(1)]);
      }
      expect(design.pins.first.length, lessThan(2.54 + SymbolDesign.grid));
    });

    test('reopening a symbol changes nothing about it', () {
      final first = SymbolDesign(
        name: 'Hex',
        shape: BodyShape.polygon,
        polygonSides: 6,
        bodyWidth: 12.7,
        showPinNumbers: false,
        pins: const [
          PinDesign(number: '1', name: 'A', x: -10.16, y: 0, angle: 0),
          PinDesign(number: '2', name: 'B', side: PinSide.right),
        ],
      ).build();
      final again = SymbolDesign.from(first).build();

      expect(again.pins.map((p) => (p.at, p.angle, p.length)).toList(), [
        for (final p in first.pins) (p.at, p.angle, p.length),
      ]);
      final reopened = SymbolDesign.from(first);
      expect(reopened.shape, BodyShape.polygon);
      expect(reopened.polygonSides, 6);
      expect(reopened.bodyWidth, closeTo(12.7, 1e-6));
      expect(reopened.showPinNumbers, isFalse);
      // The editor's own note stays out of sight in KiCad.
      expect(first.properties.keys, contains('ki_hintpcb_body'));
    });
  });

  group('matching a footprint', () {
    test('says which pins have no pad and which pads have no pin', () {
      final sot23 = FootprintDesign(
        name: 'SOT-23',
        pads: [
          const PadDesign(number: '1'),
          const PadDesign(number: '2', x: 1.9),
          const PadDesign(number: '3', y: 2),
        ],
      ).build();

      expect(PinPadMatch.of(['1', '2', '3'], sot23).isExact, isTrue);
      final short = PinPadMatch.of(['1', '2', '4'], sot23);
      expect(short.missingPads, ['4']);
      expect(short.unusedPads, ['3']);
    });
  });

  test('only MCU and CPU libraries count as microcontrollers', () {
    expect(isMcuLibrary('MCU_ST_STM32F1'), isTrue);
    expect(isMcuLibrary('CPU_NXP_6800'), isTrue);
    expect(isMcuLibrary('Device'), isFalse);
    expect(isMcuLibrary('Diode'), isFalse);
  });

  test('pin types stay what they were set to', () {
    final built = const SymbolDesign(
      name: 'X',
      pins: [
        PinDesign(number: '1', name: 'VCC', type: PinElectricalType.powerIn),
      ],
    ).build();
    expect(built.pins.single.electricalType, PinElectricalType.powerIn);
  });
}
