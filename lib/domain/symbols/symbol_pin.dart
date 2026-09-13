import '../models/pin.dart';
import 'symbol_geometry.dart';

/// An alternate function a pin can be switched to in the schematic editor,
/// e.g. an STM32 pin that can act as `SPI1_MOSI` or `TIM2_CH1`.
///
/// Carried through so the pinout view can show what a pin is capable of, not
/// just its default name.
class PinAlternate {
  const PinAlternate({
    required this.name,
    required this.electricalType,
    this.graphicStyle = PinGraphicStyle.line,
  });

  final String name;
  final PinElectricalType electricalType;
  final PinGraphicStyle graphicStyle;

  @override
  String toString() => 'PinAlternate($name, ${electricalType.token})';
}

/// A pin as defined in a symbol library, before it is placed in a project.
class SymbolPin {
  const SymbolPin({
    required this.number,
    required this.name,
    required this.electricalType,
    required this.at,
    this.graphicStyle = PinGraphicStyle.line,
    this.angle = 0,
    this.length = 2.54,
    this.hidden = false,
    this.nameEffects = TextEffects.standard,
    this.numberEffects = TextEffects.standard,
    this.alternates = const [],
  });

  /// Pad identifier. Not necessarily numeric, and not necessarily unique
  /// within a symbol — KiCad allows stacked pins sharing a number.
  final String number;

  /// Functional name. KiCad writes `""` or `"~"` for an unnamed pin.
  final String name;

  final PinElectricalType electricalType;
  final PinGraphicStyle graphicStyle;

  /// The connection point, in symbol space.
  final SymbolPoint at;

  /// Direction the pin stub points, in degrees: 0, 90, 180 or 270. The stub
  /// runs from [at] away from the body.
  final double angle;

  final double length;
  final bool hidden;
  final TextEffects nameEffects;
  final TextEffects numberEffects;
  final List<PinAlternate> alternates;

  bool get hasName => name.isNotEmpty && name != '~';

  /// `3 (VCC)`, or just `3` when the pin has no meaningful name.
  String get label => hasName ? '$number ($name)' : number;

  @override
  String toString() => 'SymbolPin($number, $name, ${electricalType.token})';
}
