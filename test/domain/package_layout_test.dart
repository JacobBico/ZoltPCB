import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/pin.dart';
import 'package:zolt/domain/symbols/symbols.dart';

/// A four-sided package, one pin per side, drawn the way KiCad draws one.
///
/// The stub angle points from the connection point towards the body, so a
/// pin at angle 0 — body to its right — is on the package's left edge.
SymbolDefinition _quad() => SymbolDefinition(
  libraryNickname: 'Test',
  name: 'QUAD',
  unitDrawings: [
    SymbolUnitDrawing(
      unit: 1,
      bodyStyle: 1,
      pins: [
        SymbolPin(
          number: '1',
          name: 'WEST',
          electricalType: PinElectricalType.bidirectional,
          at: const SymbolPoint(-10, 0),
          angle: 0,
        ),
        SymbolPin(
          number: '2',
          name: 'EAST',
          electricalType: PinElectricalType.bidirectional,
          at: const SymbolPoint(10, 0),
          angle: 180,
        ),
        SymbolPin(
          number: '3',
          name: 'NORTH',
          electricalType: PinElectricalType.bidirectional,
          at: const SymbolPoint(0, 10),
          angle: 270,
        ),
        SymbolPin(
          number: '4',
          name: 'SOUTH',
          electricalType: PinElectricalType.bidirectional,
          at: const SymbolPoint(0, -10),
          angle: 90,
        ),
      ],
    ),
  ],
);

void main() {
  test('each pin lands on the edge its stub points away from', () {
    final layout = PackageLayout.of(_quad());

    String numberOn(PackageSide side) => layout.onSide(side).single.pin.number;

    expect(numberOn(PackageSide.left), '1');
    expect(numberOn(PackageSide.right), '2');
    expect(numberOn(PackageSide.top), '3');
    expect(numberOn(PackageSide.bottom), '4');
  });

  test('side pins read down the page, not up it', () {
    // KiCad symbol space has +y upwards, the drawing does not. A pin higher
    // up the symbol has to come out higher up the package, or the diagram is
    // a mirror of the datasheet and worse than useless.
    final symbol = SymbolDefinition(
      libraryNickname: 'Test',
      name: 'LEFT',
      unitDrawings: [
        SymbolUnitDrawing(
          unit: 1,
          bodyStyle: 1,
          pins: [
            for (final (number, y) in [('1', 5.0), ('2', 0.0), ('3', -5.0)])
              SymbolPin(
                number: number,
                name: 'P$number',
                electricalType: PinElectricalType.input,
                at: SymbolPoint(-10, y),
                angle: 0,
              ),
          ],
        ),
      ],
    );

    final left = PackageLayout.of(symbol).onSide(PackageSide.left);
    expect([for (final pin in left) pin.number], ['1', '2', '3']);
  });

  test('hidden pins are left off the drawing', () {
    final symbol = SymbolDefinition(
      libraryNickname: 'Test',
      name: 'H',
      unitDrawings: [
        SymbolUnitDrawing(
          unit: 1,
          bodyStyle: 1,
          pins: [
            SymbolPin(
              number: '1',
              name: 'VCC',
              electricalType: PinElectricalType.powerIn,
              at: const SymbolPoint(-10, 0),
              angle: 0,
              hidden: true,
            ),
            SymbolPin(
              number: '2',
              name: 'IO',
              electricalType: PinElectricalType.bidirectional,
              at: const SymbolPoint(-10, -5),
              angle: 0,
            ),
          ],
        ),
      ],
    );

    expect(PackageLayout.of(symbol).pins.single.number, '2');
  });

  test('a unit takes its own pins and the ones shared by every unit', () {
    final symbol = SymbolDefinition(
      libraryNickname: 'Test',
      name: 'DUAL',
      unitDrawings: [
        SymbolUnitDrawing(
          unit: 0,
          bodyStyle: 1,
          pins: [
            SymbolPin(
              number: '8',
              name: 'V+',
              electricalType: PinElectricalType.powerIn,
              at: const SymbolPoint(0, 10),
              angle: 270,
            ),
          ],
        ),
        for (final unit in [1, 2])
          SymbolUnitDrawing(
            unit: unit,
            bodyStyle: 1,
            pins: [
              SymbolPin(
                number: '$unit',
                name: 'IN$unit',
                electricalType: PinElectricalType.input,
                at: const SymbolPoint(-10, 0),
                angle: 0,
              ),
            ],
          ),
      ],
    );

    final first = PackageLayout.of(symbol, unit: 1);
    expect({for (final pin in first.pins) pin.number}, {'1', '8'});

    final second = PackageLayout.of(symbol, unit: 2);
    expect({for (final pin in second.pins) pin.number}, {'2', '8'});
  });
}
