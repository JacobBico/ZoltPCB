import 'pin.dart';

/// A pin to create when adding a part to a project.
///
/// The symbol library layer produces these from parsed `.kicad_sym` data;
/// the repository turns them into rows. Keeping the spec separate from
/// [PartPin] means the library layer never has to invent database ids.
class NewPinSpec {
  const NewPinSpec({
    required this.number,
    required this.name,
    required this.electricalType,
    this.graphicStyle = PinGraphicStyle.line,
    this.unit = 1,
    this.bodyStyle = 1,
    this.x = 0,
    this.y = 0,
    this.length = 2.54,
    this.angle = 0,
    this.hidden = false,
  });

  final String number;
  final String name;
  final PinElectricalType electricalType;
  final PinGraphicStyle graphicStyle;

  /// `0` for pins shared by every unit of the package.
  final int unit;
  final int bodyStyle;
  final double x;
  final double y;
  final double length;
  final int angle;
  final bool hidden;

  @override
  String toString() => 'NewPinSpec($number/$name, unit $unit)';
}

/// Everything needed to add one component to a project.
class NewPartSpec {
  const NewPartSpec({
    required this.libId,
    required this.value,
    required this.pins,
    this.referencePrefix = 'U',
    this.reference,
    this.footprint = '',
    this.datasheet = '',
    this.description = '',
    this.unitCount = 1,
    this.inBom = true,
    this.onBoard = true,
  });

  final String libId;
  final String value;
  final List<NewPinSpec> pins;

  /// Prefix used to allocate the next free designator when [reference] is
  /// null — `R` yields `R1`, `R2`, and so on.
  final String referencePrefix;

  /// An explicit designator. When null the repository allocates one.
  final String? reference;

  final String footprint;
  final String datasheet;
  final String description;
  final int unitCount;
  final bool inBom;
  final bool onBoard;

  @override
  String toString() => 'NewPartSpec($libId, ${pins.length} pins)';
}
