import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/kicad/footprint_parser.dart';
import 'package:zolt/kicad/footprint_writer.dart';
import 'package:zolt/kicad/sexpr/sexpr_parser.dart';

const _source = '''
(footprint "Buzzer"
  (layer "F.Cu")
  (property "Reference" "REF**" (at 0 -3 0) (layer "F.SilkS")
    (effects (font (size 1 1) (thickness 0.15))))
  (fp_text user "+" (at -2 1.5 90) (layer "F.SilkS")
    (effects (font (size 1.2 1.2) (thickness 0.18))))
  (fp_text user "\${REFERENCE}" (at 0 0 0) (layer "F.Fab")
    (effects (font (size 0.8 0.8) (thickness 0.12))))
  (fp_text user "hidden" (at 0 2 0) (layer "F.SilkS")
    (effects (font (size 1 1) (thickness 0.15)) (hide yes)))
  (pad "1" thru_hole circle (at -1.5 0) (size 1.6 1.6) (drill 0.8)
    (layers "*.Cu" "*.Mask")))
''';

void main() {
  test('a footprint keeps the text it prints, and not what it hides', () {
    final footprint = FootprintParser.parse(
      SExprParser.parseDocument(_source),
      'Test',
    );
    final texts = footprint.graphics.whereType<FootprintText>().toList();
    expect(texts.map((t) => t.text), ['+', r'${REFERENCE}']);

    final plus = texts.first;
    expect(plus.layer, BoardLayer.frontSilk);
    expect(plus.at.x, -2);
    expect(plus.at.y, 1.5);
    expect(plus.angle, 90);
    expect(plus.size, 1.2);
    expect(plus.stroke.width, closeTo(0.18, 1e-9));
    expect(
      texts.last.textFor(reference: 'BZ1', value: 'CMT-1603'),
      'BZ1',
    );
  });

  test('and writes it back as it was', () {
    final footprint = FootprintParser.parse(
      SExprParser.parseDocument(_source),
      'Test',
    );
    final again = FootprintParser.parse(
      SExprParser.parseDocument(FootprintWriter.write(footprint)),
      'Test',
    );
    final text = again.graphics.whereType<FootprintText>().first;
    expect(text.text, '+');
    expect(text.angle, 90);
    expect(text.at.x, -2);
  });
}
