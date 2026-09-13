import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/kicad/symbol_library_reader.dart';

Uint8List bytes(String source) =>
    Uint8List.fromList(utf8.encode(source));

void main() {
  group('scanning spans', () {
    test('finds top-level symbols and ignores their child symbols', () {
      final source = bytes('''
(kicad_symbol_lib (version 20251024) (generator "kicad_symbol_editor")
  (symbol "R"
    (symbol "R_0_1" (rectangle (start 0 0) (end 1 1)))
    (symbol "R_1_1" (pin passive line (at 0 0 0))))
  (symbol "C"
    (symbol "C_1_1" (pin passive line (at 0 0 0)))))
''');

      final spans = SymbolLibraryReader.scanSpans(source);
      expect(spans.map((s) => s.name), ['R', 'C']);
    });

    test('is not fooled by parentheses inside property strings', () {
      final source = bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "A"
    (property "Description" "Dual opamp (SOIC-8) (wide)"))
  (symbol "B"
    (property "Description" "has a ) in it")))
''');

      final spans = SymbolLibraryReader.scanSpans(source);
      expect(spans.map((s) => s.name), ['A', 'B']);
    });

    test('is not fooled by escaped quotes inside strings', () {
      final source = bytes(r'''
(kicad_symbol_lib (version 20251024)
  (symbol "GND"
    (property "Description" "creates a label named \"GND\" (global)"))
  (symbol "VCC"))
''');

      final spans = SymbolLibraryReader.scanSpans(source);
      expect(spans.map((s) => s.name), ['GND', 'VCC']);
    });

    test('a span covers exactly its own symbol', () {
      final text = '''
(kicad_symbol_lib (version 20251024)
  (symbol "A" (property "Value" "A"))
  (symbol "B" (property "Value" "B")))
''';
      final source = bytes(text);
      final spans = SymbolLibraryReader.scanSpans(source);

      final first = utf8.decode(
        source.sublist(spans[0].start, spans[0].end),
      );
      expect(first, '(symbol "A" (property "Value" "A"))');

      final parsed = SymbolLibraryReader.parseSpan(
        source,
        spans[1],
        nickname: 'Lib',
      );
      expect(parsed.name, 'B');
    });

    test('handles a library with no symbols', () {
      final spans = SymbolLibraryReader.scanSpans(
        bytes('(kicad_symbol_lib (version 20251024))'),
      );
      expect(spans, isEmpty);
    });

    test('handles non-ASCII names and values', () {
      final source = bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "R_Ω"
    (property "Description" "résistance — 5 Ω")))
''');

      final spans = SymbolLibraryReader.scanSpans(source);
      expect(spans.single.name, 'R_Ω');

      final parsed = SymbolLibraryReader.parseSpan(
        source,
        spans.single,
        nickname: 'Lib',
      );
      expect(parsed.description, 'résistance — 5 Ω');
    });
  });

  test('reads the file header', () {
    final header = SymbolLibraryReader.readHeader(
      bytes('''
(kicad_symbol_lib
  (version 20251024)
  (generator "kicad_symbol_editor")
  (generator_version "10.0"))
'''),
    );

    expect(header.version, 20251024);
    expect(header.generator, 'kicad_symbol_editor');
    expect(header.generatorVersion, '10.0');
  });

  group('inheritance', () {
    final library = bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "LM2904"
    (pin_names (offset 0.254))
    (property "Reference" "U")
    (property "Value" "LM2904")
    (property "Datasheet" "http://parent.example/ds.pdf")
    (property "ki_keywords" "dual opamp")
    (symbol "LM2904_1_1"
      (pin output line (at 7.62 0 180) (name "") (number "1"))
      (pin input line (at -7.62 -2.54 0) (name "-") (number "2")))
    (symbol "LM2904_3_1"
      (pin power_in line (at -2.54 -7.62 90) (name "V-") (number "4"))))
  (symbol "NE5532"
    (extends "LM2904")
    (property "Value" "NE5532")
    (property "Datasheet" "http://child.example/ne5532.pdf")
    (property "Description" "Dual Low-Noise Op Amp"))
  (symbol "NE5532A"
    (extends "NE5532")
    (property "Value" "NE5532A")))
''');

    test('a derived symbol inherits drawings and pins', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        library,
        nickname: 'Amplifier_Operational',
      );
      final child = parsed.symbols.firstWhere((s) => s.name == 'NE5532');

      expect(child.pinCount, 3);
      expect(child.unitCount, 3);
      expect(child.pinsForUnit(1).map((p) => p.number), ['1', '2']);
      expect(child.pinNamesOffset, 0.254);
    });

    test('a derived symbol keeps its own properties', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        library,
        nickname: 'Amplifier_Operational',
      );
      final child = parsed.symbols.firstWhere((s) => s.name == 'NE5532');

      expect(child.value, 'NE5532');
      expect(child.datasheet, 'http://child.example/ne5532.pdf');
      expect(child.description, 'Dual Low-Noise Op Amp');
      // Inherited, because the child does not set it.
      expect(child.keywords, 'dual opamp');
      expect(child.reference, 'U');
      expect(child.libId, 'Amplifier_Operational:NE5532');
    });

    test('inheritance chains resolve through every level', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        library,
        nickname: 'Amplifier_Operational',
      );
      final grandchild = parsed.symbols.firstWhere((s) => s.name == 'NE5532A');

      expect(grandchild.pinCount, 3);
      expect(grandchild.value, 'NE5532A');
      expect(grandchild.description, 'Dual Low-Noise Op Amp');
      expect(parsed.warnings, isEmpty);
    });

    test('a missing parent is a warning, not a failure', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "Orphan" (extends "NotHere") (property "Value" "Orphan")))
'''),
        nickname: 'Lib',
      );

      expect(parsed.symbols, hasLength(1));
      expect(parsed.symbols.single.pinCount, 0);
      expect(parsed.warnings.single, contains('NotHere'));
    });

    test('an inheritance cycle is reported instead of hanging', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "A" (extends "B"))
  (symbol "B" (extends "A")))
'''),
        nickname: 'Lib',
      );

      expect(parsed.symbols, hasLength(2));
      expect(parsed.warnings, isNotEmpty);
    });

    test('Value falls back to the symbol name when nothing sets it', () {
      final parsed = SymbolLibraryReader.parseLibrary(
        bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "Base" (property "Value" "Base"))
  (symbol "Derived" (extends "Base")))
'''),
        nickname: 'Lib',
      );

      expect(
        parsed.symbols.firstWhere((s) => s.name == 'Derived').value,
        'Derived',
      );
    });
  });
}
