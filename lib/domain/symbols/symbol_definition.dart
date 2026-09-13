import 'symbol_geometry.dart';
import 'symbol_pin.dart';

/// The drawing and pins of one (unit, body style) combination of a symbol.
///
/// KiCad stores these as child symbols named `<name>_<unit>_<bodyStyle>`.
class SymbolUnitDrawing {
  const SymbolUnitDrawing({
    required this.unit,
    required this.bodyStyle,
    this.graphics = const [],
    this.pins = const [],
  });

  /// 1-based unit index. `0` means the drawing belongs to every unit — a
  /// resistor's body rectangle, or the supply pins some logic families share
  /// across all gates in the package.
  final int unit;

  /// 1 is the normal shape, 2 the De Morgan alternate. `0` means the drawing
  /// applies to every body style.
  final int bodyStyle;

  final List<SymbolGraphic> graphics;
  final List<SymbolPin> pins;

  bool get isCommonToAllUnits => unit == 0;
  bool get isCommonToAllBodyStyles => bodyStyle == 0;

  @override
  String toString() =>
      'Unit $unit/$bodyStyle (${graphics.length} graphics, '
      '${pins.length} pins)';
}

/// A symbol as defined in a `.kicad_sym` library.
///
/// A derived symbol — one with [extendsSymbol] set — carries only its own
/// properties in the file and inherits everything else. Over half of KiCad's
/// stock symbols are derived, so callers should use a definition that has
/// already been resolved rather than reading [extendsSymbol] themselves.
class SymbolDefinition {
  const SymbolDefinition({
    required this.libraryNickname,
    required this.name,
    this.extendsSymbol,
    this.properties = const {},
    this.unitDrawings = const [],
    this.pinNamesHidden = false,
    this.pinNamesOffset = 0.508,
    this.pinNumbersHidden = false,
    this.isPower = false,
    this.excludeFromSim = false,
    this.inBom = true,
    this.onBoard = true,
    this.hasDeMorganAlternate = false,
  });

  /// The library this came from, e.g. `Device`.
  final String libraryNickname;

  /// The symbol's own name, e.g. `R` or `NE5532`.
  final String name;

  /// The symbol this one derives from, or null.
  final String? extendsSymbol;

  /// Every `(property ...)` on the symbol, keyed by name. Includes KiCad's
  /// internal `ki_keywords` and `ki_fp_filters`.
  final Map<String, String> properties;

  final List<SymbolUnitDrawing> unitDrawings;

  final bool pinNamesHidden;
  final double pinNamesOffset;
  final bool pinNumbersHidden;

  /// True for power and ground symbols, which KiCad treats specially: they
  /// create a global label rather than appearing in the BOM.
  final bool isPower;

  final bool excludeFromSim;
  final bool inBom;
  final bool onBoard;
  final bool hasDeMorganAlternate;

  /// `Device:R` — the identifier a schematic file uses to refer back here.
  String get libId => '$libraryNickname:$name';

  bool get isDerived => extendsSymbol != null;

  String get reference => properties['Reference'] ?? 'U';
  String get value => properties['Value'] ?? name;
  String get footprint => properties['Footprint'] ?? '';
  String get datasheet => properties['Datasheet'] ?? '';
  String get description => properties['Description'] ?? '';
  String get keywords => properties['ki_keywords'] ?? '';

  /// Footprint filter patterns, e.g. `R_* Resistor_*`.
  List<String> get footprintFilters {
    final raw = properties['ki_fp_filters'] ?? '';
    if (raw.trim().isEmpty) return const [];
    return raw.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }

  /// The reference prefix used when allocating designators: `R` from `R?`.
  String get referencePrefix {
    final match = RegExp(r'^([A-Za-z_#]+)').firstMatch(reference);
    return match?.group(1) ?? 'U';
  }

  /// Number of independently placeable units in the package. Unit 0 is
  /// shared rather than placeable, so it does not count.
  int get unitCount {
    var highest = 0;
    for (final drawing in unitDrawings) {
      if (drawing.unit > highest) highest = drawing.unit;
    }
    return highest == 0 ? 1 : highest;
  }

  bool get isMultiUnit => unitCount > 1;

  /// Every pin in the symbol, across all units, for the default body style.
  List<SymbolPin> get pins => [
    for (final drawing in unitDrawings)
      if (drawing.bodyStyle <= 1) ...drawing.pins,
  ];

  int get pinCount => pins.length;

  /// Pins that belong to [unit], including those common to every unit.
  List<SymbolPin> pinsForUnit(int unit, {int bodyStyle = 1}) => [
    for (final drawing in unitDrawings)
      if ((drawing.unit == unit || drawing.isCommonToAllUnits) &&
          (drawing.bodyStyle == bodyStyle || drawing.isCommonToAllBodyStyles))
        ...drawing.pins,
  ];

  /// Graphics that belong to [unit], including those common to every unit.
  List<SymbolGraphic> graphicsForUnit(int unit, {int bodyStyle = 1}) => [
    for (final drawing in unitDrawings)
      if ((drawing.unit == unit || drawing.isCommonToAllUnits) &&
          (drawing.bodyStyle == bodyStyle || drawing.isCommonToAllBodyStyles))
        ...drawing.graphics,
  ];

  /// Returns a copy of this symbol with everything it did not define taken
  /// from [parent].
  ///
  /// KiCad's rule for a derived symbol: it keeps its own properties and
  /// inherits the parent's drawings, pins and flags. `Value` defaults to the
  /// derived symbol's own name rather than the parent's value.
  SymbolDefinition resolvedAgainst(SymbolDefinition parent) {
    final merged = <String, String>{...parent.properties, ...properties};
    merged['Value'] = properties['Value'] ?? name;

    return SymbolDefinition(
      libraryNickname: libraryNickname,
      name: name,
      // Kept after resolution, not cleared: it records where the drawings
      // came from, and loading this symbol on its own later means finding
      // and resolving the parent again.
      extendsSymbol: extendsSymbol,
      properties: merged,
      unitDrawings: unitDrawings.isEmpty ? parent.unitDrawings : unitDrawings,
      pinNamesHidden: parent.pinNamesHidden,
      pinNamesOffset: parent.pinNamesOffset,
      pinNumbersHidden: parent.pinNumbersHidden,
      isPower: isPower || parent.isPower,
      excludeFromSim: excludeFromSim,
      inBom: inBom,
      onBoard: onBoard,
      hasDeMorganAlternate: parent.hasDeMorganAlternate,
    );
  }

  @override
  String toString() =>
      'SymbolDefinition($libId, $unitCount units, $pinCount pins'
      '${isDerived ? ", extends $extendsSymbol" : ""})';
}
