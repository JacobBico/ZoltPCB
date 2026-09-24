import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/kicad/sexpr/sexpr.dart';
import 'package:zolt/kicad/sexpr/sexpr_parser.dart';

void main() {
  group('parsing', () {
    test('reads a flat list of atoms', () {
      final node = SExprParser.parseDocument('(at 1.27 -3.81 90)');

      expect(node.head, 'at');
      expect(node.number(1), 1.27);
      expect(node.number(2), -3.81);
      expect(node.number(3), 90);
    });

    test('reads nested lists', () {
      final node = SExprParser.parseDocument(
        '(effects (font (size 1.27 1.27)) (justify left bottom))',
      );

      expect(node.child('font')?.childNumber('size'), 1.27);
      expect(node.child('justify')?.atom(1), 'left');
      expect(node.child('justify')?.atom(2), 'bottom');
    });

    test('distinguishes quoted strings from bare tokens', () {
      final node = SExprParser.parseDocument('(property "Value" yes)');
      final quoted = node.items[1] as SAtom;
      final bare = node.items[2] as SAtom;

      expect(quoted.value, 'Value');
      expect(quoted.quoted, isTrue);
      expect(bare.value, 'yes');
      expect(bare.quoted, isFalse);
    });

    test('keeps parentheses that appear inside strings', () {
      final node = SExprParser.parseDocument(
        '(property "Description" "Dual opamp (SOIC-8)")',
      );

      expect(node.atom(2), 'Dual opamp (SOIC-8)');
    });

    test('unescapes quotes and backslashes', () {
      final node = SExprParser.parseDocument(
        r'(property "Description" "creates a label named \"GND\"")',
      );

      expect(node.atom(2), 'creates a label named "GND"');
    });

    test('handles an empty string value', () {
      final node = SExprParser.parseDocument('(property "Footprint" "")');
      expect(node.atom(2), '');
    });

    test('handles an empty list', () {
      final node = SExprParser.parseDocument('(symbol ())');
      expect((node.items[1] as SList).items, isEmpty);
    });

    test('tolerates arbitrary whitespace and newlines', () {
      final node = SExprParser.parseDocument('''
        (symbol
            "R"
            (in_bom   yes)
        )
      ''');

      expect(node.atom(1), 'R');
      expect(node.child('in_bom')?.atom(1), 'yes');
    });
  });

  group('errors', () {
    test('rejects an unterminated list', () {
      expect(
        () => SExprParser.parseDocument('(symbol "R"'),
        throwsA(isA<SExprParseException>()),
      );
    });

    test('rejects an unterminated string', () {
      expect(
        () => SExprParser.parseDocument('(symbol "R'),
        throwsA(isA<SExprParseException>()),
      );
    });

    test('rejects trailing content after the top-level list', () {
      expect(
        () => SExprParser.parseDocument('(a) (b)'),
        throwsA(isA<SExprParseException>()),
      );
    });

    test('reports the line a problem is on', () {
      try {
        SExprParser.parseDocument('(a\n  (b\n   (c');
        fail('expected a parse exception');
      } on SExprParseException catch (e) {
        expect(e.line, 3);
      }
    });
  });

  group('accessors', () {
    test('flag reads both the bare and the wrapped form', () {
      // KiCad 8 and earlier wrote a bare token.
      final old = SExprParser.parseDocument('(pin_names (offset 1.016) hide)');
      // Version 9 and later wrap it.
      final current = SExprParser.parseDocument(
        '(pin_names (offset 1.016) (hide yes))',
      );
      final off = SExprParser.parseDocument(
        '(pin_names (offset 1.016) (hide no))',
      );
      final absent = SExprParser.parseDocument('(pin_names (offset 1.016))');

      expect(old.flag('hide'), isTrue);
      expect(current.flag('hide'), isTrue);
      expect(off.flag('hide'), isFalse);
      expect(absent.flag('hide'), isFalse);
    });

    test('a quoted token is not mistaken for a flag', () {
      final node = SExprParser.parseDocument('(property "hide" "no")');
      expect(node.flag('hide'), isFalse);
    });

    test('children returns every match in order', () {
      final node = SExprParser.parseDocument(
        '(pts (xy 0 0) (xy 1 1) (xy 2 2))',
      );

      expect(node.children('xy').map((n) => n.number(1)), [0, 1, 2]);
    });

    test('missing values read as null rather than throwing', () {
      final node = SExprParser.parseDocument('(at)');

      expect(node.number(1), isNull);
      expect(node.child('nope'), isNull);
      expect(node.childNumber('nope'), isNull);
    });

    test('parseAt reads one list out of a longer document', () {
      const source = '(lib (symbol "A") (symbol "B"))';
      final offset = source.indexOf('(symbol "B")');

      final node = SExprParser.parseAt(source, offset);
      expect(node.atom(1), 'B');
    });
  });
}
