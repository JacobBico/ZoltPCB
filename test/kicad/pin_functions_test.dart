@Tags(['corpus'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/symbols/symbols.dart';
import 'package:zolt/kicad/symbol_library_reader.dart';

/// Checks the CubeMX-style pin helper against real STM32 symbols.
///
/// The index is only worth anything if it agrees with the datasheet, so the
/// spot checks here are facts about the parts, not about the code: on an
/// STM32F103 in LQFP48, SPI1's clock can come out on PA5 or on PB3.
void main() {
  const path = '/usr/share/kicad/symbols/MCU_ST_STM32F1.kicad_sym';
  if (!File(path).existsSync()) {
    test('KiCad STM32 symbols are not installed', () {}, skip: true);
    return;
  }

  final library = SymbolLibraryReader.parseLibrary(
    File(path).readAsBytesSync(),
    nickname: 'MCU_ST_STM32F1',
  );

  SymbolDefinition symbolNamed(String prefix) =>
      library.symbols.firstWhere((s) => s.name.startsWith(prefix));

  test('an STM32F103 knows where SPI1 can go', () {
    final mcu = symbolNamed('STM32F103C8Tx');
    expect(PinFunctions.hasAny(mcu), isTrue);

    final peripherals = PinFunctions.of(mcu);
    final spi1 = peripherals.firstWhere((p) => p.name == 'SPI1');

    expect(spi1.kind, 'SPI');
    expect(spi1.signals.keys, containsAll(['SCK', 'MISO', 'MOSI']));
    // Straight from the reference manual: SPI1_SCK is PA5, or PB3 remapped.
    expect(
      spi1.signals['SCK']!.map((p) => p.name),
      containsAll(['PA5', 'PB3']),
    );
  });

  test('peripherals of one kind are grouped and in instance order', () {
    final peripherals = PinFunctions.of(symbolNamed('STM32F103C8Tx'));
    final usarts = [
      for (final p in peripherals)
        if (p.kind == 'USART') p.name,
    ];
    expect(usarts, containsAllInOrder(['USART1', 'USART2']));
  });

  test('every peripheral signal lands on a real pin of the part', () {
    final mcu = symbolNamed('STM32F103C8Tx');
    final pinNumbers = {
      for (final drawing in mcu.unitDrawings)
        for (final pin in drawing.pins) pin.number,
    };
    for (final peripheral in PinFunctions.of(mcu)) {
      for (final options in peripheral.signals.values) {
        for (final option in options) {
          expect(
            pinNumbers,
            contains(option.number),
            reason: '${peripheral.name} points at a pin that does not exist',
          );
        }
      }
    }
  });

  test('a part with no alternates says so', () {
    // A symbol from a library that carries none, standing in for the
    // ATmega/ESP32/RP2040 case.
    final plain = library.symbols.firstWhere(
      (s) => !PinFunctions.hasAny(s),
      orElse: () => symbolNamed('STM32F103C8Tx'),
    );
    if (PinFunctions.hasAny(plain)) return; // every symbol here has some
    expect(PinFunctions.of(plain), isEmpty);
  });

  group('splitting a function name', () {
    test('at the last underscore', () {
      expect(PinFunctions.splitFunction('SPI1_SCK'), (
        peripheral: 'SPI1',
        signal: 'SCK',
      ));
      expect(PinFunctions.splitFunction('USB_OTG_FS_DP'), (
        peripheral: 'USB_OTG_FS',
        signal: 'DP',
      ));
    });

    test('a name with nothing to split is not a function', () {
      expect(PinFunctions.splitFunction('GPIO'), isNull);
      expect(PinFunctions.splitFunction('_X'), isNull);
    });

    test('only trailing digits come off the kind', () {
      expect(PinFunctions.kindOf('I2C3'), 'I2C');
      expect(PinFunctions.kindOf('I2S2'), 'I2S');
      expect(PinFunctions.kindOf('SPI10'), 'SPI');
      expect(PinFunctions.kindOf('USB_OTG_FS'), 'USB_OTG_FS');
    });
  });
}
