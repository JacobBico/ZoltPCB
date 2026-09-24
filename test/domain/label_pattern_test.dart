import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/label_pattern.dart';

void main() {
  test('a range counts up, and down', () {
    expect(LabelPattern.expand('D[0..3]'), ['D0', 'D1', 'D2', 'D3']);
    expect(LabelPattern.expand('A[3..1]'), ['A3', 'A2', 'A1']);
  });

  test('what follows the brackets is kept', () {
    expect(LabelPattern.expand('LED[1..2]_EN'), ['LED1_EN', 'LED2_EN']);
  });

  test('a group shares its prefix', () {
    expect(LabelPattern.expand('SPI_{MOSI MISO SCK}'), [
      'SPI_MOSI',
      'SPI_MISO',
      'SPI_SCK',
    ]);
  });

  test('lists, by comma or space, and mixtures', () {
    expect(LabelPattern.expand('SDA, SCL'), ['SDA', 'SCL']);
    expect(LabelPattern.expand('SDA SCL'), ['SDA', 'SCL']);
    expect(LabelPattern.expand('D[0..1], CLK, CS'), ['D0', 'D1', 'CLK', 'CS']);
  });

  test('ranges nest inside groups', () {
    expect(LabelPattern.expand('P{A B}[0..1]'), ['PA0', 'PA1', 'PB0', 'PB1']);
  });

  test('something that does not parse is kept as typed', () {
    expect(LabelPattern.expand('D[0..x]'), ['D[0..x]']);
    expect(LabelPattern.expand(''), isEmpty);
    expect(LabelPattern.expand('   '), isEmpty);
  });
}
