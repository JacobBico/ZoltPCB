import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/symbols/mcu_essentials.dart';

McuPinInfo _pin(
  String number,
  String name, [
  List<String> alternates = const [],
]) => McuPinInfo(number: number, name: name, alternates: alternates);

void main() {
  test('an STM32: oscillator from the alternates, BOOT0 pulled down', () {
    final found = McuEssentials.of([
      _pin('1', 'VBAT'),
      _pin('5', 'PH0', ['RCC_OSC_IN']),
      _pin('6', 'PH1', ['RCC_OSC_OUT']),
      _pin('7', 'NRST'),
      _pin('8', 'VSSA'),
      _pin('9', 'VDDA'),
      _pin('3', 'PC14', ['RCC_OSC32_IN']),
      _pin('23', 'VSS'),
      _pin('24', 'VDD'),
      _pin('31', 'VCAP_1'),
      _pin('35', 'VDD'),
      _pin('60', 'BOOT0'),
      _pin('10', 'PA0', ['ADC1_IN0', 'TIM2_CH1']),
    ]);

    expect(found.railPins, ['1', '9', '24', '35']);
    expect(found.groundPins, ['8', '23']);
    expect(found.vcapPins, ['31']);
    // The 32 kHz pins are not the main oscillator.
    expect(found.oscIn, '5');
    expect(found.oscOut, '6');
    expect(found.reset, '7');
    expect(found.boot, '60');
    expect(found.bootPolarity, BootPolarity.activeHigh);
    expect(found.bootNeedsPullUp, isFalse);
  });

  test('an ATmega: overbarred reset and crystal pins shared with a port', () {
    final found = McuEssentials.of([
      _pin('1', '~{RESET}/PC6'),
      _pin('7', 'VCC'),
      _pin('8', 'GND'),
      _pin('9', 'XTAL1/PB6'),
      _pin('10', 'XTAL2/PB7'),
      _pin('20', 'AVCC'),
      _pin('21', 'AREF'),
    ]);
    expect(found.reset, '1');
    expect(found.oscIn, '9');
    expect(found.oscOut, '10');
    expect(found.railPins, ['7', '20']);
    expect(found.boot, isNull);
  });

  test('an ESP32 module: GPIO0 is the boot pin, low with a pull-up', () {
    final found = McuEssentials.of([
      _pin('2', '3V3'),
      _pin('3', 'EN'),
      _pin('25', 'IO0'),
      _pin('1', 'GND'),
      _pin('39', 'GND'),
    ]);
    expect(found.reset, '3');
    expect(found.boot, '25');
    expect(found.bootPolarity, BootPolarity.activeLow);
    expect(found.bootNeedsPullUp, isTrue);
    expect(found.hasCrystal, isFalse);
    // Stacked pins with one name are still each a ground.
    expect(found.groundPins, ['1', '39']);
  });

  test('an RP2040: core supply kept off the rail, and GPIO0 boots nothing', () {
    final found = McuEssentials.of([
      _pin('1', 'IOVDD'),
      _pin('2', 'GPIO0'),
      _pin('20', 'XIN'),
      _pin('21', 'XOUT'),
      _pin('23', 'DVDD'),
      _pin('26', 'RUN'),
      _pin('44', 'VREG_IN'),
      _pin('45', 'VREG_VOUT'),
      _pin('56', 'QSPI_SS'),
      _pin('57', 'GND'),
    ]);
    expect(found.railPins, ['1', '44']);
    expect(found.corePins, ['23', '45']);
    expect(found.oscIn, '20');
    expect(found.oscOut, '21');
    expect(found.reset, '26');
    expect(found.boot, '56');
    expect(found.bootNeedsPullUp, isFalse);
  });

  test('a part with nothing recognisable finds nothing', () {
    final found = McuEssentials.of([_pin('1', 'IN'), _pin('2', 'OUT')]);
    expect(found.isEmpty, isTrue);
  });
}
