import 'package:zolt/domain/models/models.dart';

/// A two-pin passive, the simplest thing that can join a net.
NewPartSpec resistorSpec({
  String value = '10k',
  String footprint = 'Resistor_SMD:R_0603_1608Metric',
}) => NewPartSpec(
  libId: 'Device:R',
  value: value,
  referencePrefix: 'R',
  footprint: footprint,
  pins: const [
    NewPinSpec(
      number: '1',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: 3.81,
      angle: 270,
    ),
    NewPinSpec(
      number: '2',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: -3.81,
      angle: 90,
    ),
  ],
);

/// A dual opamp: two amplifier units plus a third "unit" of supply pins that
/// KiCad marks as common to all units. This is the multi-unit case the
/// data model has to get right.
NewPartSpec dualOpampSpec() => const NewPartSpec(
  libId: 'Amplifier_Operational:NE5532',
  value: 'NE5532',
  referencePrefix: 'U',
  unitCount: 2,
  pins: [
    // Unit 1
    NewPinSpec(
      number: '1',
      name: '~',
      electricalType: PinElectricalType.output,
      unit: 1,
    ),
    NewPinSpec(
      number: '2',
      name: '-',
      electricalType: PinElectricalType.input,
      unit: 1,
    ),
    NewPinSpec(
      number: '3',
      name: '+',
      electricalType: PinElectricalType.input,
      unit: 1,
    ),
    // Unit 2
    NewPinSpec(
      number: '5',
      name: '+',
      electricalType: PinElectricalType.input,
      unit: 2,
    ),
    NewPinSpec(
      number: '6',
      name: '-',
      electricalType: PinElectricalType.input,
      unit: 2,
    ),
    NewPinSpec(
      number: '7',
      name: '~',
      electricalType: PinElectricalType.output,
      unit: 2,
    ),
    // Supply pins, shared by both units.
    NewPinSpec(
      number: '8',
      name: 'V+',
      electricalType: PinElectricalType.powerIn,
      unit: 0,
    ),
    NewPinSpec(
      number: '4',
      name: 'V-',
      electricalType: PinElectricalType.powerIn,
      unit: 0,
    ),
  ],
);

/// A ground symbol, as KiCad models one: a `#PWR` designator, a single
/// power-input pin, and no place in the BOM.
NewPartSpec groundSpec({String value = 'GND'}) => NewPartSpec(
  libId: 'power:$value',
  value: value,
  referencePrefix: '#PWR',
  unitCount: 1,
  inBom: false,
  onBoard: false,
  pins: const [
    NewPinSpec(
      number: '1',
      name: '',
      electricalType: PinElectricalType.powerIn,
      angle: 270,
      length: 0,
    ),
  ],
);

/// A two-pin capacitor, so a board test can have more than one kind of
/// part without reaching for a multi-unit package.
NewPartSpec capacitorSpec({
  String value = '100n',
  String footprint = 'Capacitor_SMD:C_0603_1608Metric',
}) => NewPartSpec(
  libId: 'Device:C',
  value: value,
  referencePrefix: 'C',
  footprint: footprint,
  pins: const [
    NewPinSpec(
      number: '1',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: 2.54,
      angle: 270,
    ),
    NewPinSpec(
      number: '2',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: -2.54,
      angle: 90,
    ),
  ],
);

/// A MOSFET, shaped the way KiCad draws one: gate out to the left, drain up,
/// source down, with the body between all three.
///
/// The awkward shape for a router. Joining any two of these pins means
/// getting past the transistor itself, and the pins face three different
/// ways while doing it.
NewPartSpec mosfetSpec({String value = 'BSS138'}) => NewPartSpec(
  libId: 'Transistor_FET:$value',
  value: value,
  referencePrefix: 'Q',
  pins: const [
    NewPinSpec(
      number: '1',
      name: 'G',
      electricalType: PinElectricalType.input,
      x: -5.08,
      y: 0,
      angle: 0,
      length: 2.54,
    ),
    NewPinSpec(
      number: '2',
      name: 'S',
      electricalType: PinElectricalType.passive,
      x: 0,
      y: -5.08,
      angle: 90,
      length: 2.54,
    ),
    NewPinSpec(
      number: '3',
      name: 'D',
      electricalType: PinElectricalType.passive,
      x: 0,
      y: 5.08,
      angle: 270,
      length: 2.54,
    ),
  ],
);
