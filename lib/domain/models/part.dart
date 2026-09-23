import 'pin.dart';

/// A component placed in a project: one physical package, one reference
/// designator, one entry in the BOM.
///
/// A multi-unit package (a dual opamp, a hex inverter) is a single [Part]
/// with several [PartUnit]s that can be positioned independently on the
/// sheet while sharing a reference designator, value and footprint.
class Part {
  const Part({
    required this.id,
    required this.projectId,
    required this.libId,
    required this.reference,
    required this.value,
    required this.createdAt,
    this.footprint = '',
    this.datasheet = '',
    this.description = '',
    this.unitCount = 1,
    this.inBom = true,
    this.onBoard = true,
    this.dnp = false,
    this.fieldsHidden = false,
  });

  final String id;
  final String projectId;

  /// Fully qualified library identifier, e.g. `Device:R` or
  /// `Amplifier_Operational:NE5532`. Must resolve for `.kicad_sch` export.
  final String libId;

  /// Reference designator, e.g. `R1`, `U3`. Unique within a project.
  final String reference;

  final String value;
  final String footprint;
  final String datasheet;
  final String description;

  /// Number of units in the package; 1 for ordinary parts.
  final int unitCount;

  final bool inBom;
  final bool onBoard;

  /// "Do not populate" — fitted in the schematic but omitted from assembly.
  final bool dnp;

  /// Whether to leave the designator and value off the drawing. Display
  /// only: the fields are still exported, and still in the BOM.
  final bool fieldsHidden;

  final DateTime createdAt;

  bool get isMultiUnit => unitCount > 1;

  /// Whether this is a power or ground symbol rather than a component.
  ///
  /// KiCad marks them with a `#PWR` or `#FLG` designator, which is also how
  /// they stay out of the BOM. They are labels that happen to have a shape:
  /// what joins two of them is their name, not a wire.
  bool get isPowerSymbol => isPowerReference(reference);

  /// The same question, for somewhere that has only the designator.
  static bool isPowerReference(String reference) =>
      reference.startsWith('#PWR') || reference.startsWith('#FLG');

  /// The library nickname half of [libId] (`Device` in `Device:R`).
  String get libraryNickname {
    final i = libId.indexOf(':');
    return i < 0 ? '' : libId.substring(0, i);
  }

  /// The symbol name half of [libId] (`R` in `Device:R`).
  String get symbolName {
    final i = libId.indexOf(':');
    return i < 0 ? libId : libId.substring(i + 1);
  }

  /// The alphabetic prefix of [reference] (`R` for `R12`), used when
  /// allocating the next free designator.
  String get referencePrefix {
    final match = RegExp(r'^([A-Za-z_]+)').firstMatch(reference);
    return match?.group(1) ?? reference;
  }

  Part copyWith({
    String? reference,
    String? value,
    String? footprint,
    String? datasheet,
    String? description,
    bool? inBom,
    bool? onBoard,
    bool? dnp,
    bool? fieldsHidden,
  }) {
    return Part(
      id: id,
      projectId: projectId,
      libId: libId,
      reference: reference ?? this.reference,
      value: value ?? this.value,
      footprint: footprint ?? this.footprint,
      datasheet: datasheet ?? this.datasheet,
      description: description ?? this.description,
      unitCount: unitCount,
      inBom: inBom ?? this.inBom,
      onBoard: onBoard ?? this.onBoard,
      dnp: dnp ?? this.dnp,
      fieldsHidden: fieldsHidden ?? this.fieldsHidden,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Part &&
      other.id == id &&
      other.projectId == projectId &&
      other.libId == libId &&
      other.reference == reference &&
      other.value == value &&
      other.footprint == footprint &&
      other.datasheet == datasheet &&
      other.description == description &&
      other.unitCount == unitCount &&
      other.inBom == inBom &&
      other.onBoard == onBoard &&
      other.fieldsHidden == fieldsHidden &&
      other.dnp == dnp &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    libId,
    reference,
    value,
    footprint,
    datasheet,
    description,
    unitCount,
    inBom,
    onBoard,
    dnp,
    createdAt,
  );

  @override
  String toString() => 'Part($id, $reference, $libId)';
}

/// One unit of a [Part] placed on the schematic sheet.
///
/// Placement fields are carried from the start even though the canvas comes
/// later: they are part of the persisted document and the exporter needs
/// them. Until a unit is placed, [placed] is false and the coordinates are
/// not meaningful.
class PartUnit {
  const PartUnit({
    required this.id,
    required this.partId,
    required this.unitNumber,
    this.bodyStyle = 1,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.mirrorX = false,
    this.mirrorY = false,
    this.placed = false,
    this.sheetId,
  });

  final String id;
  final String partId;

  /// The sub-sheet the unit is drawn on; null for the top sheet.
  final String? sheetId;

  /// 1-based KiCad unit index.
  final int unitNumber;

  final int bodyStyle;

  /// Position on the sheet in millimetres.
  final double x;
  final double y;

  /// Rotation in degrees: 0, 90, 180 or 270.
  final int rotation;

  final bool mirrorX;
  final bool mirrorY;
  final bool placed;

  PartUnit copyWith({
    double? x,
    double? y,
    int? rotation,
    bool? mirrorX,
    bool? mirrorY,
    bool? placed,
    int? bodyStyle,
    String? sheetId,
    bool toTopSheet = false,
  }) {
    return PartUnit(
      id: id,
      partId: partId,
      sheetId: toTopSheet ? null : (sheetId ?? this.sheetId),
      unitNumber: unitNumber,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      mirrorX: mirrorX ?? this.mirrorX,
      mirrorY: mirrorY ?? this.mirrorY,
      placed: placed ?? this.placed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PartUnit &&
      other.id == id &&
      other.partId == partId &&
      other.unitNumber == unitNumber &&
      other.bodyStyle == bodyStyle &&
      other.x == x &&
      other.y == y &&
      other.rotation == rotation &&
      other.mirrorX == mirrorX &&
      other.mirrorY == mirrorY &&
      other.placed == placed &&
      other.sheetId == sheetId;

  @override
  int get hashCode => Object.hash(
    id,
    partId,
    unitNumber,
    bodyStyle,
    x,
    y,
    rotation,
    mirrorX,
    mirrorY,
    placed,
  );

  @override
  String toString() => 'PartUnit($id, unit $unitNumber)';
}

/// A [Part] together with its units and pins — the shape most of the UI and
/// the exporter actually want to work with.
class PartWithDetails {
  const PartWithDetails({
    required this.part,
    required this.units,
    required this.pins,
  });

  final Part part;
  final List<PartUnit> units;
  final List<PartPin> pins;

  /// Pins belonging to [unitNumber], including pins common to all units.
  List<PartPin> pinsForUnit(int unitNumber) => pins
      .where((p) => p.unit == unitNumber || p.isCommonToAllUnits)
      .toList(growable: false);

  @override
  String toString() =>
      'PartWithDetails(${part.reference}, ${units.length} units, '
      '${pins.length} pins)';
}
