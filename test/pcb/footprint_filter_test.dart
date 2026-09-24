import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

void main() {
  test('a resistor filter takes resistors and nothing else', () {
    final filter = FootprintFilter('R_*');
    expect(filter.matches('R_0805_2012Metric'), isTrue);
    expect(filter.matches('R_Axial_DIN0207_L6.3mm_D2.5mm_P10.16mm'), isTrue);
    expect(filter.matches('D_SMA'), isFalse);
    expect(filter.matches('C_0805_2012Metric'), isFalse);
  });

  test('a filter of several globs takes any of them', () {
    // The stock diode's filter, as KiCad writes it.
    final filter = FootprintFilter('TO-???* *_Diode_* *SingleDiode* D_*');
    expect(filter.matches('D_SMA'), isTrue);
    expect(filter.matches('TO-220-2_Vertical'), isTrue);
    expect(filter.matches('Fuse_1206'), isFalse);
  });

  test('? stands for exactly one character', () {
    final filter = FootprintFilter('TO-???*');
    expect(filter.matches('TO-220'), isTrue);
    expect(filter.matches('TO-92'), isFalse, reason: 'only two characters');
  });

  test('dots and underscores are taken literally', () {
    // Footprint names are full of both. Treating "." as "any character"
    // would let R_0805 match R_0805x as well as R_0805.
    final filter = FootprintFilter('R_0805.2*');
    expect(filter.matches('R_0805.25'), isTrue);
    expect(filter.matches('R_0805x25'), isFalse);
  });

  test('a library prefix does not stop a match', () {
    final filter = FootprintFilter('R_*');
    expect(filter.matches('Resistor_SMD:R_0805_2012Metric'), isTrue);
  });

  test('no filter means everything suits', () {
    final filter = FootprintFilter('');
    expect(filter.isEmpty, isTrue);
    expect(filter.matches('Anything_At_All'), isTrue);
  });

  test('matching ignores case, like KiCad does', () {
    expect(FootprintFilter('r_*').matches('R_0805_2012Metric'), isTrue);
  });
}
