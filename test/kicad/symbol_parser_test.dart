import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/pin.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/kicad/sexpr/sexpr_parser.dart';
import 'package:hintpcb/kicad/symbol_parser.dart';

SymbolDefinition parse(String source, {String nickname = 'Test'}) =>
    SymbolParser.parseSymbol(SExprParser.parseDocument(source), nickname);

void main() {
  group('symbol basics', () {
    const resistor = '''
(symbol "R"
  (pin_numbers (hide yes))
  (pin_names (offset 0))
  (in_bom yes)
  (on_board yes)
  (property "Reference" "R" (at 2.032 0 90))
  (property "Value" "R" (at 0 0 90))
  (property "Footprint" "" (at -1.778 0 90))
  (property "Description" "Resistor" (at 0 0 0))
  (property "ki_keywords" "R res resistor" (at 0 0 0))
  (property "ki_fp_filters" "R_* Resistor_*" (at 0 0 0))
  (symbol "R_0_1"
    (rectangle (start -1.016 -2.54) (end 1.016 2.54)
      (stroke (width 0.254) (type default)) (fill (type none))))
  (symbol "R_1_1"
    (pin passive line (at 0 3.81 270) (length 1.27)
      (name "" (effects (font (size 1.27 1.27))))
      (number "1" (effects (font (size 1.27 1.27)))))
    (pin passive line (at 0 -3.81 90) (length 1.27)
      (name "" (effects (font (size 1.27 1.27))))
      (number "2" (effects (font (size 1.27 1.27)))))))
''';

    test('reads identity, properties and derived accessors', () {
      final symbol = parse(resistor, nickname: 'Device');

      expect(symbol.name, 'R');
      expect(symbol.libId, 'Device:R');
      expect(symbol.reference, 'R');
      expect(symbol.referencePrefix, 'R');
      expect(symbol.description, 'Resistor');
      expect(symbol.keywords, 'R res resistor');
      expect(symbol.footprintFilters, ['R_*', 'Resistor_*']);
      expect(symbol.isDerived, isFalse);
      expect(symbol.isPower, isFalse);
    });

    test('reads pins with position, direction and electrical type', () {
      final symbol = parse(resistor);

      expect(symbol.pinCount, 2);
      final pin = symbol.pins.first;
      expect(pin.number, '1');
      expect(pin.electricalType, PinElectricalType.passive);
      expect(pin.graphicStyle, PinGraphicStyle.line);
      expect(pin.at, const SymbolPoint(0, 3.81));
      expect(pin.angle, 270);
      expect(pin.length, 1.27);
      expect(pin.hasName, isFalse);
      expect(pin.label, '1');
    });

    test('reads graphics into the unit-0 drawing', () {
      final symbol = parse(resistor);
      final shared = symbol.unitDrawings.firstWhere((d) => d.unit == 0);

      expect(shared.isCommonToAllUnits, isTrue);
      final rect = shared.graphics.single as SymbolRectangle;
      expect(rect.start, const SymbolPoint(-1.016, -2.54));
      expect(rect.end, const SymbolPoint(1.016, 2.54));
      expect(rect.stroke.width, 0.254);
      expect(rect.fill.type, FillType.none);
    });

    test('a single-unit part reports one unit', () {
      final symbol = parse(resistor);
      expect(symbol.unitCount, 1);
      expect(symbol.isMultiUnit, isFalse);
    });

    test('hidden pin numbers and zero name offset are read', () {
      final symbol = parse(resistor);
      expect(symbol.pinNumbersHidden, isTrue);
      expect(symbol.pinNamesHidden, isFalse);
      expect(symbol.pinNamesOffset, 0);
    });
  });

  group('units and body styles', () {
    test('unit index is read from the right, so underscores in the name '
        'do not confuse it', () {
      final symbol = parse('''
(symbol "SN74_LVC_1G08"
  (symbol "SN74_LVC_1G08_2_1"
    (pin input line (at 0 0 0) (length 2.54)
      (name "A") (number "1"))))
''');
      final drawing = symbol.unitDrawings.single;
      expect(drawing.unit, 2);
      expect(drawing.bodyStyle, 1);
    });

    test('unit count is the highest unit, ignoring the shared unit 0', () {
      final symbol = parse('''
(symbol "U"
  (symbol "U_0_1" (rectangle (start 0 0) (end 1 1)))
  (symbol "U_1_1" (pin input line (at 0 0 0) (name "A") (number "1")))
  (symbol "U_2_1" (pin input line (at 0 0 0) (name "B") (number "2")))
  (symbol "U_3_1" (pin power_in line (at 0 0 0) (name "VCC") (number "14"))))
''');
      expect(symbol.unitCount, 3);
      expect(symbol.isMultiUnit, isTrue);
    });

    test('pins in unit 0 belong to every unit', () {
      // 4xxx_IEEE-style: the supply pins are shared by all the gates.
      final symbol = parse('''
(symbol "4011"
  (symbol "4011_0_1"
    (pin power_in line (at 0 10 270) (name "VDD") (number "14"))
    (pin power_in line (at 0 -10 90) (name "VSS") (number "7")))
  (symbol "4011_1_1"
    (pin input line (at -5 2 0) (name "A") (number "1"))
    (pin output line (at 5 0 180) (name "Y") (number "3")))
  (symbol "4011_2_1"
    (pin input line (at -5 2 0) (name "A") (number "5"))))
''');

      expect(symbol.unitCount, 2);
      final unit1 = symbol.pinsForUnit(1).map((p) => p.number).toSet();
      final unit2 = symbol.pinsForUnit(2).map((p) => p.number).toSet();

      expect(unit1, {'14', '7', '1', '3'});
      expect(unit2, {'14', '7', '5'});
      expect(unit1.intersection(unit2), {'14', '7'});
    });

    test('body style 0 drawings apply to every body style', () {
      final symbol = parse('''
(symbol "G"
  (symbol "G_1_0" (rectangle (start 0 0) (end 1 1)))
  (symbol "G_1_1" (polyline (pts (xy 0 0) (xy 1 1))))
  (symbol "G_1_2" (circle (center 0 0) (radius 1))))
''');

      expect(symbol.graphicsForUnit(1, bodyStyle: 1), hasLength(2));
      expect(symbol.graphicsForUnit(1, bodyStyle: 2), hasLength(2));
      expect(symbol.hasDeMorganAlternate, isTrue);
    });
  });

  group('flag forms across format versions', () {
    test('a bare hide token is honoured, as written by KiCad 8 and older', () {
      final symbol = parse('''
(symbol "P"
  (pin_names (offset 1.016) hide)
  (symbol "P_1_1"
    (pin power_in line (at 0 0 0) hide (name "VCC") (number "1"))))
''');

      expect(symbol.pinNamesHidden, isTrue);
      expect(symbol.pins.single.hidden, isTrue);
    });

    test(
      'the wrapped hide form is honoured, as written by KiCad 9 and newer',
      () {
        final symbol = parse('''
(symbol "P"
  (pin_names (offset 1.016) (hide yes))
  (symbol "P_1_1"
    (pin power_in line (at 0 0 0) (hide yes) (name "VCC") (number "1"))))
''');

        expect(symbol.pinNamesHidden, isTrue);
        expect(symbol.pins.single.hidden, isTrue);
      },
    );

    test('power symbols are recognised in both forms', () {
      expect(parse('(symbol "GND" (power))').isPower, isTrue);
      expect(parse('(symbol "GND" (power global))').isPower, isTrue);
      expect(parse('(symbol "R")').isPower, isFalse);
    });
  });

  test('pin alternates are carried through', () {
    final symbol = parse('''
(symbol "MCU"
  (symbol "MCU_1_1"
    (pin bidirectional line (at 0 0 0) (length 2.54)
      (name "PA5") (number "21")
      (alternate "SPI1_SCK" bidirectional line)
      (alternate "TIM2_CH1" output line))))
''');

    final pin = symbol.pins.single;
    expect(pin.alternates.map((a) => a.name), ['SPI1_SCK', 'TIM2_CH1']);
    expect(pin.alternates.last.electricalType, PinElectricalType.output);
  });

  test('every graphic primitive is recognised', () {
    final symbol = parse('''
(symbol "G"
  (symbol "G_1_1"
    (polyline (pts (xy 0 0) (xy 1 1) (xy 2 0)))
    (rectangle (start -1 -1) (end 1 1))
    (circle (center 0 0) (radius 2.5))
    (arc (start -1 0) (mid 0 1) (end 1 0))
    (bezier (pts (xy 0 0) (xy 1 1) (xy 2 1) (xy 3 0)))
    (text "1" (at 1.524 0 90) (effects (font (size 2.54 2.54))))
    (text_box "10V\\nREF" (at -17.78 6.35 0) (size 7.62 -7.62))))
''');

    final graphics = symbol.unitDrawings.single.graphics;
    expect(graphics.whereType<SymbolPolyline>().single.points, hasLength(3));
    expect(graphics.whereType<SymbolRectangle>(), hasLength(1));
    expect(graphics.whereType<SymbolCircle>().single.radius, 2.5);
    expect(graphics.whereType<SymbolArc>().single.mid, const SymbolPoint(0, 1));
    expect(graphics.whereType<SymbolBezier>().single.points, hasLength(4));

    final text = graphics.whereType<SymbolText>().single;
    expect(text.text, '1');
    expect(text.angle, 90);
    expect(text.effects.sizeX, 2.54);

    final box = graphics.whereType<SymbolTextBox>().single;
    expect(box.text, '10V\nREF');
    expect(box.size, const SymbolPoint(7.62, -7.62));
  });

  test('text justification is read', () {
    final symbol = parse('''
(symbol "G"
  (symbol "G_1_1"
    (text "x" (at 0 0 0)
      (effects (font (size 1 1) (italic yes)) (justify left bottom)))))
''');

    final text = symbol.unitDrawings.single.graphics.single as SymbolText;
    expect(text.effects.horizontal, TextHorizontalAlign.left);
    expect(text.effects.vertical, TextVerticalAlign.bottom);
    expect(text.effects.italic, isTrue);
  });

  test('a malformed node is rejected rather than silently mis-parsed', () {
    expect(
      () => parse('(not_a_symbol "R")'),
      throwsA(isA<SymbolParseException>()),
    );
    expect(() => parse('(symbol)'), throwsA(isA<SymbolParseException>()));
  });
}
