import 'dart:math' as math;

import '../domain/models/models.dart';
import '../domain/symbols/symbols.dart';

/// A pin as the renderer needs it, with a stable identity for hit-testing.
///
/// Both a library symbol and a placed part can produce these. The canvas
/// draws pins from the placed part's snapshot rather than from the library,
/// so a project whose library has been removed still shows and connects its
/// pins — only the symbol body goes missing.
class RenderablePin {
  const RenderablePin({
    required this.id,
    required this.number,
    required this.name,
    required this.electricalType,
    required this.x,
    required this.y,
    required this.length,
    required this.angle,
    required this.unit,
    this.hidden = false,
    this.noConnect = false,
  });

  factory RenderablePin.fromPart(PartPin pin) => RenderablePin(
    id: pin.id,
    number: pin.number,
    name: pin.name,
    electricalType: pin.electricalType,
    x: pin.x,
    y: pin.y,
    length: pin.length,
    angle: pin.angle.toDouble(),
    unit: pin.unit,
    hidden: pin.hidden,
    noConnect: pin.noConnect,
  );

  factory RenderablePin.fromSymbol(SymbolPin pin, {required int unit}) =>
      RenderablePin(
        id: '$unit/${pin.number}/${pin.at.x}/${pin.at.y}',
        number: pin.number,
        name: pin.name,
        electricalType: pin.electricalType,
        x: pin.at.x,
        y: pin.at.y,
        length: pin.length,
        angle: pin.angle,
        unit: unit,
        hidden: pin.hidden,
      );

  final String id;
  final String number;
  final String name;
  final PinElectricalType electricalType;

  /// Connection point in symbol space.
  final double x;
  final double y;

  final double length;

  /// Degrees; the stub runs from the connection point in this direction,
  /// towards the symbol body.
  final double angle;

  final int unit;
  final bool hidden;
  final bool noConnect;

  bool get hasName => name.isNotEmpty && name != '~';

  /// Where the stub meets the symbol body, in symbol space.
  (double, double) get bodyEnd {
    final radians = angle * math.pi / 180;
    return (x + length * math.cos(radians), y + length * math.sin(radians));
  }
}
