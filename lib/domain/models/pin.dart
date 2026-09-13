/// KiCad pin electrical types, as written in `.kicad_sym` / `.kicad_sch`.
///
/// The token strings are the wire format and must not be changed casually:
/// the symbol parser reads them and the schematic writer emits them.
enum PinElectricalType {
  input('input'),
  output('output'),
  bidirectional('bidirectional'),
  triState('tri_state'),
  passive('passive'),
  free('free'),
  unspecified('unspecified'),
  powerIn('power_in'),
  powerOut('power_out'),
  openCollector('open_collector'),
  openEmitter('open_emitter'),
  noConnect('no_connect');

  const PinElectricalType(this.token);

  final String token;

  static PinElectricalType fromToken(String token) =>
      PinElectricalType.values.firstWhere(
        (t) => t.token == token,
        orElse: () => PinElectricalType.unspecified,
      );

  /// True for pins that source or sink supply current. Used to spot the
  /// shared power pins of a multi-unit package.
  bool get isPower =>
      this == PinElectricalType.powerIn || this == PinElectricalType.powerOut;
}

/// KiCad pin graphic styles (the shape drawn at the pin's free end).
enum PinGraphicStyle {
  line('line'),
  inverted('inverted'),
  clock('clock'),
  invertedClock('inverted_clock'),
  inputLow('input_low'),
  clockLow('clock_low'),
  outputLow('output_low'),
  edgeClockHigh('edge_clock_high'),
  nonLogic('non_logic');

  const PinGraphicStyle(this.token);

  final String token;

  static PinGraphicStyle fromToken(String token) =>
      PinGraphicStyle.values.firstWhere(
        (t) => t.token == token,
        orElse: () => PinGraphicStyle.line,
      );
}

/// A pin belonging to a placed [Part].
///
/// Pins are snapshotted from the symbol library when a part is added to a
/// project. That keeps a project fully editable — and exportable — even if
/// the library it came from is later removed from the device.
class PartPin {
  const PartPin({
    required this.id,
    required this.partId,
    required this.unit,
    required this.number,
    required this.name,
    required this.electricalType,
    this.graphicStyle = PinGraphicStyle.line,
    this.bodyStyle = 1,
    this.x = 0,
    this.y = 0,
    this.length = 2.54,
    this.angle = 0,
    this.noConnect = false,
    this.hidden = false,
  });

  final String id;
  final String partId;

  /// KiCad unit index. `0` means the pin is common to every unit of the
  /// package — this is how a dual opamp shares its supply pins.
  final int unit;

  /// KiCad body style ("De Morgan" alternate). `1` is the normal style.
  final int bodyStyle;

  /// Pad identifier, e.g. `"1"` or `"A3"`. Not necessarily numeric.
  final String number;

  /// Functional name, e.g. `"VCC"`. KiCad writes `"~"` for unnamed pins.
  final String name;

  final PinElectricalType electricalType;
  final PinGraphicStyle graphicStyle;

  /// Position of the pin's connection point in symbol space, in millimetres.
  final double x;
  final double y;

  /// Length of the pin stub in millimetres.
  final double length;

  /// Direction the pin's stub points, in degrees: 0, 90, 180 or 270.
  final int angle;

  /// Marked with an explicit no-connect flag by the user.
  final bool noConnect;

  /// Hidden in the symbol definition (typically legacy implicit power pins).
  final bool hidden;

  /// True when this pin is shared across all units of a multi-unit package.
  bool get isCommonToAllUnits => unit == 0;

  /// Human-readable label used throughout the UI: `3 (VCC)`, or just `3`
  /// when the pin has no meaningful name.
  String get label =>
      (name.isEmpty || name == '~') ? number : '$number ($name)';

  PartPin copyWith({bool? noConnect}) => PartPin(
    id: id,
    partId: partId,
    unit: unit,
    number: number,
    name: name,
    electricalType: electricalType,
    graphicStyle: graphicStyle,
    bodyStyle: bodyStyle,
    x: x,
    y: y,
    length: length,
    angle: angle,
    noConnect: noConnect ?? this.noConnect,
    hidden: hidden,
  );

  @override
  bool operator ==(Object other) =>
      other is PartPin &&
      other.id == id &&
      other.partId == partId &&
      other.unit == unit &&
      other.bodyStyle == bodyStyle &&
      other.number == number &&
      other.name == name &&
      other.electricalType == electricalType &&
      other.graphicStyle == graphicStyle &&
      other.x == x &&
      other.y == y &&
      other.length == length &&
      other.angle == angle &&
      other.noConnect == noConnect &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(
    id,
    partId,
    unit,
    bodyStyle,
    number,
    name,
    electricalType,
    graphicStyle,
    x,
    y,
    length,
    angle,
    noConnect,
    hidden,
  );

  @override
  String toString() => 'PartPin($id, $number/$name, unit $unit)';
}
