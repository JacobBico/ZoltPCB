import 'package:drift/drift.dart';

import '../converters.dart';

/// A schematic design.
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get paper => text()
      .map(const PaperSizeConverter())
      .withDefault(const Constant('A4'))();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get revision => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A component placed in a project. One row per physical package.
@TableIndex(name: 'idx_parts_project', columns: {#projectId})
@DataClassName('PartRow')
class Parts extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get libId => text()();
  TextColumn get reference => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  TextColumn get footprint => text().withDefault(const Constant(''))();
  TextColumn get datasheet => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get unitCount => integer().withDefault(const Constant(1))();
  BoolColumn get inBom => boolean().withDefault(const Constant(true))();
  BoolColumn get onBoard => boolean().withDefault(const Constant(true))();
  BoolColumn get dnp => boolean().withDefault(const Constant(false))();

  /// Whether the designator and value are drawn beside the symbol. Off for
  /// a part whose label is only in the way — a power symbol whose shape
  /// already says GND, a row of identical decoupling caps.
  BoolColumn get fieldsHidden => boolean().withDefault(const Constant(false))();

  /// The supplier's or manufacturer's number for the part — a JLCPCB / LCSC
  /// part number such as C25804 — for ordering and assembly.
  TextColumn get componentId => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Reference designators are unique within a project.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, reference},
  ];
}

/// One independently placeable unit of a [Parts] row.
@TableIndex(name: 'idx_part_units_part', columns: {#partId})
@DataClassName('PartUnitRow')
class PartUnits extends Table {
  TextColumn get id => text()();
  TextColumn get partId =>
      text().references(Parts, #id, onDelete: KeyAction.cascade)();
  IntColumn get unitNumber => integer()();
  IntColumn get bodyStyle => integer().withDefault(const Constant(1))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  IntColumn get rotation => integer().withDefault(const Constant(0))();
  BoolColumn get mirrorX => boolean().withDefault(const Constant(false))();
  BoolColumn get mirrorY => boolean().withDefault(const Constant(false))();
  BoolColumn get placed => boolean().withDefault(const Constant(false))();

  /// The sub-sheet the unit is drawn on; null for the top sheet.
  TextColumn get sheetId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {partId, unitNumber},
  ];
}

/// A pin of a placed part, snapshotted from the symbol library at add time.
///
/// Pin numbers are deliberately not unique per part: KiCad symbols legally
/// stack several pins on the same number (duplicated supply pads, for
/// instance), and the snapshot has to reproduce the symbol faithfully.
@TableIndex(name: 'idx_part_pins_part', columns: {#partId})
@DataClassName('PartPinRow')
class PartPins extends Table {
  TextColumn get id => text()();
  TextColumn get partId =>
      text().references(Parts, #id, onDelete: KeyAction.cascade)();

  /// `0` means the pin is common to every unit of the package.
  IntColumn get unit => integer().withDefault(const Constant(1))();
  IntColumn get bodyStyle => integer().withDefault(const Constant(1))();
  TextColumn get number => text()();
  TextColumn get name => text().withDefault(const Constant('~'))();
  TextColumn get electricalType =>
      text().map(const PinElectricalTypeConverter())();
  TextColumn get graphicStyle => text()
      .map(const PinGraphicStyleConverter())
      .withDefault(const Constant('line'))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get length => real().withDefault(const Constant(2.54))();
  IntColumn get angle => integer().withDefault(const Constant(0))();
  BoolColumn get noConnect => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// An electrical net. Connectivity lives here, not in drawn geometry.
@TableIndex(name: 'idx_nets_project', columns: {#projectId})
@DataClassName('NetRow')
class Nets extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// User-assigned label; null for an anonymous net.
  TextColumn get name => text().nullable()();

  /// Where the net's label sits on the sheet, in millimetres, once the user
  /// has dragged it. Null means "wherever the drawing puts it" — on the
  /// corner of the net's own wire, which is where it reads best.
  RealColumn get labelX => real().nullable()();
  RealColumn get labelY => real().nullable()();

  /// The label's text height in millimetres, once the user has changed it.
  /// Null is KiCad's own 1.27 mm.
  RealColumn get labelSize => real().nullable()();

  /// The net class the board routes this net with; null for the default.
  TextColumn get netClassId => text().nullable().references(
    NetClasses,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A named set of routing rules — "Power traces, 0.5 mm" — that nets can
/// be put in, so a track picks its width from the net it is on.
@TableIndex(name: 'idx_net_classes_project', columns: {#projectId})
@DataClassName('NetClassRow')
class NetClasses extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get trackWidth => real()();

  /// Null uses the board's design rule.
  RealColumn get clearance => real().nullable()();

  /// The characteristic impedance this class is routed to, in ohms. When
  /// set, a track's width comes from the stackup of the layer it is drawn
  /// on rather than from [trackWidth], which is then only the fallback.
  RealColumn get impedance => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A schematic wire exactly as the user drew it: a run of 90° corners.
///
/// Connectivity still lives in the net; this is its drawing. The pin ids
/// are the ends it is attached to, so it follows a part that is moved and
/// goes when the pin does.
@TableIndex(name: 'idx_schematic_wires_project', columns: {#projectId})
@DataClassName('SchematicWireRow')
class SchematicWires extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get netId =>
      text().references(Nets, #id, onDelete: KeyAction.cascade)();
  TextColumn get pinAId => text().nullable().references(
    PartPins,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get pinBId => text().nullable().references(
    PartPins,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Corners in sheet millimetres, `x,y;x,y;…`, from the A end to the B end.
  TextColumn get points => text()();

  /// The sub-sheet the wire is drawn on; null for the top sheet.
  TextColumn get sheetId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Membership of one pin in one net.
@TableIndex(name: 'idx_net_nodes_net', columns: {#netId})
@DataClassName('NetNodeRow')
class NetNodes extends Table {
  TextColumn get id => text()();
  TextColumn get netId =>
      text().references(Nets, #id, onDelete: KeyAction.cascade)();
  TextColumn get partPinId =>
      text().references(PartPins, #id, onDelete: KeyAction.cascade)();

  /// The pin carries a label of its own — it is on this net by name, the
  /// way a KiCad label at a pin puts it there, rather than by a wire. The
  /// sheet then shows the name at the pin instead of routing a wire to
  /// the rest of the net.
  BoolColumn get labelled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// A pin can be on at most one net. This is the central invariant of the
  /// connectivity model and it is enforced by the database, not by hope.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {partPinId},
  ];
}

/// An imported `.kicad_sym` file. The file itself lives on the filesystem;
/// this row records where and what is in it.
@DataClassName('SymbolLibraryRow')
class SymbolLibraries extends Table {
  TextColumn get id => text()();

  /// Library nickname, e.g. `Device`. Unique, because it forms the first
  /// half of every `lib_id` the library produces and a schematic cannot
  /// resolve two libraries with the same nickname.
  TextColumn get nickname => text()();
  TextColumn get fileName => text()();
  IntColumn get formatVersion => integer().withDefault(const Constant(0))();
  TextColumn get generator => text().withDefault(const Constant(''))();
  IntColumn get symbolCount => integer().withDefault(const Constant(0))();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {nickname},
  ];
}

/// One symbol, indexed for search. Geometry is not stored: [spanStart] and
/// [spanEnd] point at the bytes in the library file that describe it.
@TableIndex(name: 'idx_symbol_index_library', columns: {#libraryId})
@TableIndex(name: 'idx_symbol_index_search', columns: {#searchText})
@DataClassName('SymbolIndexRow')
class SymbolIndexEntries extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId =>
      text().references(SymbolLibraries, #id, onDelete: KeyAction.cascade)();
  TextColumn get libraryNickname => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get keywords => text().withDefault(const Constant(''))();
  TextColumn get referencePrefix => text().withDefault(const Constant('U'))();
  TextColumn get defaultFootprint => text().withDefault(const Constant(''))();
  TextColumn get datasheet => text().withDefault(const Constant(''))();
  TextColumn get footprintFilters => text().withDefault(const Constant(''))();
  IntColumn get unitCount => integer().withDefault(const Constant(1))();
  IntColumn get pinCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPower => boolean().withDefault(const Constant(false))();
  TextColumn get extendsSymbol => text().nullable()();
  IntColumn get spanStart => integer().withDefault(const Constant(0))();
  IntColumn get spanEnd => integer().withDefault(const Constant(0))();

  /// Lower-cased name, description and keywords concatenated, so search is
  /// one LIKE against one column rather than three.
  TextColumn get searchText => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A user's adjustment to where one wire of a net is drawn.
///
/// Connectivity still lives entirely in [Nets]; this only records that the
/// automatic route between two particular pins should be shifted, so the
/// drawing can be tidied without inventing a second source of truth. Losing
/// one of these rows costs nothing but a tidier route.
///
/// Keyed by the pin pair rather than by net id so a hint survives two nets
/// being merged, which changes net ids but not which pins are joined.
@TableIndex(name: 'idx_route_hints_project', columns: {#projectId})
@DataClassName('NetRouteHintRow')
class NetRouteHints extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// The lower-sorting pin id of the pair.
  TextColumn get pinAId =>
      text().references(PartPins, #id, onDelete: KeyAction.cascade)();

  /// The higher-sorting pin id of the pair.
  TextColumn get pinBId =>
      text().references(PartPins, #id, onDelete: KeyAction.cascade)();

  /// How far to shift each movable run of the route, in millimetres,
  /// comma-separated and in the order the router reports them.
  ///
  /// Displacements from the automatic route rather than absolute positions,
  /// so an adjusted wire keeps its shape when the parts at either end move.
  TextColumn get turnOffsets => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {pinAId, pinBId},
  ];
}

/// An imported footprint library.
///
/// A `.pretty` directory is many small files, so an import packs them into
/// one container the same shape as a `.kicad_sym` library: the bytes are
/// concatenated and each entry records where in the file it lives. Lazy
/// loading, one file handle, and one row to delete.
@DataClassName('FootprintLibraryRow')
class FootprintLibraries extends Table {
  TextColumn get id => text()();

  /// Library nickname, e.g. `Resistor_SMD` — the first half of every
  /// footprint id it produces.
  TextColumn get nickname => text()();
  TextColumn get fileName => text()();
  IntColumn get footprintCount => integer().withDefault(const Constant(0))();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {nickname},
  ];
}

/// One footprint, indexed for search. Geometry stays in the container file.
@TableIndex(name: 'idx_footprint_index_library', columns: {#libraryId})
@TableIndex(name: 'idx_footprint_index_search', columns: {#searchText})
@DataClassName('FootprintIndexRow')
class FootprintIndexEntries extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId =>
      text().references(FootprintLibraries, #id, onDelete: KeyAction.cascade)();
  TextColumn get libraryNickname => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get keywords => text().withDefault(const Constant(''))();
  IntColumn get padCount => integer().withDefault(const Constant(0))();
  BoolColumn get isSurfaceMount =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isThroughHole =>
      boolean().withDefault(const Constant(false))();
  IntColumn get spanStart => integer().withDefault(const Constant(0))();
  IntColumn get spanEnd => integer().withDefault(const Constant(0))();
  TextColumn get searchText => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The board belonging to a project: its outline and its design rules.
///
/// One row per project, created on demand the first time the board is
/// opened. A project that never leaves the schematic never gets one.
@DataClassName('BoardRow')
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// The board outline's bounding box, in millimetres. Authoritative for a
  /// rectangle; for a circle it is the square the circle sits in; for a
  /// polygon it is derived from the points and kept for framing the view.
  RealColumn get outlineX => real().withDefault(const Constant(20))();
  RealColumn get outlineY => real().withDefault(const Constant(20))();
  RealColumn get outlineWidth => real().withDefault(const Constant(60))();
  RealColumn get outlineHeight => real().withDefault(const Constant(40))();

  /// `rectangle`, `circle` or `polygon`.
  TextColumn get outlineKind =>
      text().withDefault(const Constant('rectangle'))();

  /// Polygon vertices as `x,y` pairs separated by spaces. Empty for the
  /// other shapes, which the bounding box already describes.
  TextColumn get outlinePoints => text().withDefault(const Constant(''))();

  /// Design rules, in millimetres. Defaults are deliberately conservative —
  /// every board house on earth makes 0.25 mm track and space.
  RealColumn get trackWidth => real().withDefault(const Constant(0.25))();
  RealColumn get clearance => real().withDefault(const Constant(0.2))();
  RealColumn get viaDiameter => real().withDefault(const Constant(0.8))();
  RealColumn get viaDrill => real().withDefault(const Constant(0.4))();

  /// Track widths and via sizes set up in advance, to be picked from while
  /// routing — KiCad keeps the same list in Board Setup. Space-separated
  /// millimetres; a via is `diameter/drill`. Empty means "just the rule".
  TextColumn get trackWidths => text().withDefault(const Constant(''))();
  TextColumn get viaSizes => text().withDefault(const Constant(''))();

  /// How a new pour joins the copper of its own net: `thermal`, `solid` or
  /// `none` for pads, and the same three for vias. Vias default to solid
  /// because nobody solders one, which is the only reason a thermal exists.
  TextColumn get padConnection =>
      text().withDefault(const Constant('thermal'))();
  TextColumn get viaConnection => text().withDefault(const Constant('solid'))();

  /// The gap a thermal relief leaves round the copper, and the width of
  /// the spokes that bridge it.
  RealColumn get thermalGap => real().withDefault(const Constant(0.5))();
  RealColumn get thermalSpoke => real().withDefault(const Constant(0.5))();

  /// Teardrop settings, encoded by `TeardropRules`. Empty means off.
  TextColumn get teardrops => text().withDefault(const Constant(''))();

  /// Placement grid. 0.5 mm rather than the schematic's 1.27 mm: boards are
  /// laid out in a much finer world than schematics.
  RealColumn get gridMm => real().withDefault(const Constant(0.5))();

  /// How many copper layers the board has: 2, 4, 6 or 8.
  IntColumn get copperLayers => integer().withDefault(const Constant(2))();

  /// Finished board thickness, in millimetres.
  RealColumn get thickness => real().withDefault(const Constant(1.6))();

  /// The layer build-up — copper weights, dielectric heights and materials —
  /// as JSON. Empty means "the standard build for this many layers and
  /// this thickness", worked out rather than stored.
  TextColumn get stackup => text().withDefault(const Constant(''))();

  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId},
  ];
}

/// Where one part's footprint sits on the board.
///
/// Keyed by part, not by unit: a multi-unit package is several symbols on
/// the schematic and exactly one physical component on the board. That
/// difference is the whole reason this is a separate table rather than a
/// few more columns on [PartUnits].
@TableIndex(name: 'idx_board_footprints_project', columns: {#projectId})
@DataClassName('BoardFootprintRow')
class BoardFootprints extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get partId =>
      text().references(Parts, #id, onDelete: KeyAction.cascade)();

  /// `Resistor_SMD:R_0805_2012Metric`.
  TextColumn get libId => text()();

  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get rotation => real().withDefault(const Constant(0))();

  /// True when the component is mounted on the back of the board.
  BoolColumn get flipped => boolean().withDefault(const Constant(false))();
  BoolColumn get placed => boolean().withDefault(const Constant(false))();

  /// Where the reference designator sits once it has been moved, in the
  /// footprint's own frame — the frame KiCad writes it in, so it survives
  /// the part being rotated or flipped afterwards. Null leaves it where the
  /// footprint library put it.
  RealColumn get labelX => real().nullable()();
  RealColumn get labelY => real().nullable()();

  /// Designator text height, in millimetres.
  RealColumn get labelSize => real().withDefault(const Constant(1.0))();

  /// Taken off the silkscreen. The part keeps its reference; the board just
  /// does not print it.
  BoolColumn get labelHidden => boolean().withDefault(const Constant(false))();

  /// Held where it is: not picked up, not dragged, not swept into a move.
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// One footprint per part. Assigning a different one replaces the row
  /// rather than adding a second body for the same component.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {partId},
  ];
}

/// One straight copper segment.
///
/// Tracks carry a net id so the board knows what a segment is for, but the
/// net itself is still owned by the schematic: the board is a drawing of
/// connectivity decided elsewhere, exactly as the schematic's wires are.
@TableIndex(name: 'idx_tracks_project', columns: {#projectId})
@DataClassName('BoardTrackRow')
class BoardTracks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// Null for a segment drawn before it was clear what net it belongs to.
  TextColumn get netId =>
      text().nullable().references(Nets, #id, onDelete: KeyAction.setNull)();

  /// `F.Cu` or `B.Cu`.
  TextColumn get layer => text()();

  RealColumn get startX => real()();
  RealColumn get startY => real()();
  RealColumn get endX => real()();
  RealColumn get endY => real()();
  RealColumn get width => real().withDefault(const Constant(0.25))();

  /// Held where it is: not moved, not slid, not deleted by a sweep.
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// An extra shape on the Edge.Cuts layer, beyond the board outline.
///
/// The outline says how big the board is; these are the slots, notches,
/// cutouts and rounded corners on top of it. Every kind is stored as a list
/// of points — see `BoardEdge` for what each reads into them — so one
/// column serves lines, arcs, rectangles, circles and polygons alike.
@TableIndex(name: 'idx_board_edges_project', columns: {#projectId})
@DataClassName('BoardEdgeRow')
class BoardEdges extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// `line`, `arc`, `rectangle`, `circle` or `polygon`.
  TextColumn get kind => text()();

  /// Points as `x,y` pairs separated by spaces.
  TextColumn get points => text().withDefault(const Constant(''))();

  RealColumn get width => real().withDefault(const Constant(0.1))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A copper pour tied to a net.
@TableIndex(name: 'idx_board_zones_project', columns: {#projectId})
@DataClassName('BoardZoneRow')
class BoardZones extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// The net poured into it. Null is a legal unconnected pour, and losing
  /// the net to a deletion leaves one rather than deleting the zone.
  TextColumn get netId =>
      text().nullable().references(Nets, #id, onDelete: KeyAction.setNull)();

  /// The net's name as drawn, kept so a pour still says what it is after
  /// its net has gone.
  TextColumn get netName => text().withDefault(const Constant(''))();

  /// `F.Cu` or `B.Cu`.
  TextColumn get layer => text()();

  /// Outline vertices as `x,y` pairs separated by spaces.
  TextColumn get points => text().withDefault(const Constant(''))();

  RealColumn get clearance => real().withDefault(const Constant(0.5))();
  RealColumn get minThickness => real().withDefault(const Constant(0.25))();

  /// Which pour wins where two overlap: the higher one is filled, the lower
  /// is cut back around it.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// How same-net pads join the pour: `thermal`, `solid` or `none`.
  TextColumn get padConnection =>
      text().withDefault(const Constant('thermal'))();

  /// The same three, for vias and plated holes on the pour's own net.
  TextColumn get viaConnection => text().withDefault(const Constant('solid'))();
  RealColumn get thermalGap => real().withDefault(const Constant(0.5))();
  RealColumn get thermalSpoke => real().withDefault(const Constant(0.5))();

  /// A keepout claims ground rather than filling it: nothing on this list
  /// may be put inside it. An ordinary pour keeps all four false.
  BoolColumn get keepout => boolean().withDefault(const Constant(false))();
  BoolColumn get noTracks => boolean().withDefault(const Constant(true))();
  BoolColumn get noVias => boolean().withDefault(const Constant(true))();
  BoolColumn get noPours => boolean().withDefault(const Constant(true))();
  BoolColumn get noParts => boolean().withDefault(const Constant(false))();

  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Free text on the silkscreen: a board name, a version, a pin-1 note.
@TableIndex(name: 'idx_board_texts_project', columns: {#projectId})
@DataClassName('BoardTextRow')
class BoardTexts extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get rotation => real().withDefault(const Constant(0))();
  RealColumn get size => real().withDefault(const Constant(1.0))();

  /// `F.SilkS` or `B.SilkS`.
  TextColumn get layer => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A plated hole joining the two copper layers.
@TableIndex(name: 'idx_vias_project', columns: {#projectId})
@DataClassName('BoardViaRow')
class BoardVias extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get netId =>
      text().nullable().references(Nets, #id, onDelete: KeyAction.setNull)();

  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get diameter => real().withDefault(const Constant(0.8))();
  RealColumn get drill => real().withDefault(const Constant(0.4))();

  /// `through`, `blind` or `buried`. A through via is drilled from the top
  /// of the board to the bottom and costs nothing extra; the other two are
  /// drilled before the board is pressed together, and every fab charges
  /// for the extra lamination cycle.
  TextColumn get viaKind => text().withDefault(const Constant('through'))();

  /// The copper layers a blind or buried via joins, as layer tokens. Empty
  /// means top to bottom, which is what a through via always is.
  TextColumn get fromLayer => text().withDefault(const Constant(''))();
  TextColumn get toLayer => text().withDefault(const Constant(''))();

  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// App-wide preferences — the theme, the symbol drawing style — as plain
/// key/value text.
///
/// Key/value rather than a column per setting: preferences come and go
/// between versions far more often than the design data does, and a new
/// one should not need a migration.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A saved copy of a whole project, to go back to.
///
/// Stored as the same archive a backup file holds, so a snapshot and a
/// backup are one format and one code path: the only difference is whether
/// it lives in the database or in a file.
@TableIndex(name: 'idx_project_snapshots_project', columns: {#projectId})
@DataClassName('ProjectSnapshotRow')
class ProjectSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// Taken by the app rather than the user — before a restore, say.
  BoolColumn get automatic => boolean().withDefault(const Constant(false))();

  /// The project archive, as JSON.
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Free text and boxes drawn on the schematic sheet.
///
/// Not connectivity and not a component: a note says what a section is
/// for, a box groups it. Both are exported to KiCad as its own text and
/// rectangle items.
@TableIndex(name: 'idx_schematic_notes_project', columns: {#projectId})
@DataClassName('SchematicNoteRow')
class SchematicNotes extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// `text` or `box`.
  TextColumn get kind => text().withDefault(const Constant('text'))();

  /// What the note says; a box's caption.
  TextColumn get content => text().withDefault(const Constant(''))();

  /// Top-left corner, in sheet millimetres.
  RealColumn get x => real()();
  RealColumn get y => real()();

  /// A box's size; zero for a text note.
  RealColumn get width => real().withDefault(const Constant(0))();
  RealColumn get height => real().withDefault(const Constant(0))();

  /// Character height, in millimetres.
  RealColumn get size => real().withDefault(const Constant(1.27))();

  /// The sub-sheet the note is on; null for the top sheet.
  TextColumn get sheetId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-project preferences — which electrical checks matter, for one — as
/// key/value text, for the same reason [AppSettings] is.
@DataClassName('ProjectSettingRow')
class ProjectSettings extends Table {
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, key};
}

/// A piece of circuit saved to reuse — an LDO with its capacitors, an
/// op-amp stage — held across every project rather than in one.
///
/// Stored as the same snapshot copy and paste use, as JSON, so inserting
/// one is a paste: parts, their wiring among themselves, and the wires as
/// they were drawn.
@DataClassName('SavedCircuitRow')
class SavedCircuits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// The circuit, as JSON.
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mounting holes, fiducials and test points: board-only footprints no
/// schematic part stands behind.
@TableIndex(name: 'idx_board_features_project', columns: {#projectId})
@DataClassName('BoardFeatureRow')
class BoardFeatures extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// `mountingHole`, `fiducial` or `testPoint`.
  TextColumn get kind => text()();
  TextColumn get reference => text()();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get rotation => real().withDefault(const Constant(0))();
  BoolColumn get back => boolean().withDefault(const Constant(false))();
  RealColumn get size => real().withDefault(const Constant(3.2))();
  BoolColumn get plated => boolean().withDefault(const Constant(false))();

  /// A test point's or plated hole's net. A deleted net leaves the feature
  /// unconnected rather than deleting it.
  TextColumn get netId =>
      text().nullable().references(Nets, #id, onDelete: KeyAction.setNull)();
  TextColumn get netName => text().withDefault(const Constant(''))();
  BoolColumn get placed => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Measurements drawn on the board.
@TableIndex(name: 'idx_board_dimensions_project', columns: {#projectId})
@DataClassName('BoardDimensionRow')
class BoardDimensions extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  RealColumn get x1 => real()();
  RealColumn get y1 => real()();
  RealColumn get x2 => real()();
  RealColumn get y2 => real()();
  RealColumn get offset => real().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A sub-sheet of a hierarchical schematic.
///
/// Drawn on its parent as a box, the way KiCad draws one, with a pin for
/// every net that crosses its edge. Those pins are not stored: nets are
/// project-wide, so which ones cross is worked out from where their pins
/// are, and can never disagree with it.
@TableIndex(name: 'idx_schematic_sheets_project', columns: {#projectId})
@DataClassName('SchematicSheetRow')
class SchematicSheets extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// The sheet this one sits on; null for a sheet on the top sheet.
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();

  /// The `.kicad_sch` file the sheet is written to.
  TextColumn get fileName => text()();

  /// The box on the parent sheet, in sheet millimetres.
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(30.48))();
  RealColumn get height => real().withDefault(const Constant(20.32))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
