import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/models.dart';
import 'converters.dart';
import 'tables/tables.dart';

part 'database.g.dart';

/// The on-device SQLite database. HintPCB is local-first: this file is the
/// only home a design has until the user exports it.
@DriftDatabase(
  tables: [
    Projects,
    Parts,
    PartUnits,
    PartPins,
    Nets,
    NetNodes,
    SymbolLibraries,
    SymbolIndexEntries,
    NetRouteHints,
    FootprintLibraries,
    FootprintIndexEntries,
    Boards,
    BoardFootprints,
    BoardTracks,
    BoardVias,
    BoardEdges,
    BoardZones,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An ephemeral database for tests. Runs natively, so the whole data layer
  /// can be exercised without an emulator.
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// The app's persistent database, stored in the application support
  /// directory.
  factory AppDatabase.open() =>
      AppDatabase(driftDatabase(name: _databaseName));

  static const _databaseName = 'hintpcb';

  /// Timestamps are stored as ISO-8601 text rather than drift's default
  /// unix-seconds integer. Second resolution is too coarse for ordering the
  /// project list by recent activity, and text keeps sub-second precision.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v2 added the symbol library index. Projects created under v1 are
      // untouched by it.
      if (from < 2) {
        await m.createTable(symbolLibraries);
        await m.createTable(symbolIndexEntries);
        await m.createIndex(idxSymbolIndexLibrary);
        await m.createIndex(idxSymbolIndexSearch);
      }
      // v3 lets a drawn wire be nudged off its automatic route. Purely
      // cosmetic, so existing projects simply have no hints.
      if (from < 3) {
        await m.createTable(netRouteHints);
        await m.createIndex(idxRouteHintsProject);
      }
      // v4 gives each movable run of a wire its own offset instead of the
      // whole wire sharing one. The old single-offset rows have no sensible
      // translation and are purely cosmetic, so they are discarded.
      if (from == 3) {
        await m.deleteTable(netRouteHints.actualTableName);
        await m.createTable(netRouteHints);
        await m.createIndex(idxRouteHintsProject);
      }
      // v5 adds the board: footprint libraries, and the placement and
      // copper of one board per project. Purely additive — a project that
      // has only ever been a schematic gains empty tables and nothing else.
      if (from < 5) {
        await m.createTable(footprintLibraries);
        await m.createTable(footprintIndexEntries);
        await m.createIndex(idxFootprintIndexLibrary);
        await m.createIndex(idxFootprintIndexSearch);
        await m.createTable(boards);
        await m.createTable(boardFootprints);
        await m.createIndex(idxBoardFootprintsProject);
        await m.createTable(boardTracks);
        await m.createIndex(idxTracksProject);
        await m.createTable(boardVias);
        await m.createIndex(idxViasProject);
      }
      // v6 lets the board edge be a circle or a polygon rather than only a
      // rectangle. Existing boards are rectangles and the defaults say so,
      // so nothing needs migrating beyond adding the columns.
      //
      // Only for a database that already had the board tables: one arriving
      // from v4 gets them from `createTable` above, new columns included,
      // and adding them again would fail.
      if (from >= 5 && from < 6) {
        await m.addColumn(boards, boards.outlineKind);
        await m.addColumn(boards, boards.outlinePoints);
      }
      // v7 remembers app preferences. Nothing to migrate: an absent setting
      // simply means the default.
      if (from < 7) {
        await m.createTable(appSettings);
      }
      // v8 lets a net label be dragged off its default spot. An existing
      // net has no stored position, which reads as "leave it where the
      // drawing puts it" — the same as before the columns existed.
      if (from < 8) {
        await m.addColumn(nets, nets.labelX);
        await m.addColumn(nets, nets.labelY);
      }
      // v9 lets a symbol's designator and value be taken off the drawing.
      // Existing parts keep theirs, which is what the default says.
      if (from < 9) {
        await m.addColumn(parts, parts.fieldsHidden);
      }
      // v10 adds extra edge cuts and copper pours. Purely additive: a
      // board drawn before this has neither, which is exactly what two
      // empty tables say.
      if (from < 10) {
        await m.createTable(boardEdges);
        await m.createIndex(idxBoardEdgesProject);
        await m.createTable(boardZones);
        await m.createIndex(idxBoardZonesProject);
      }
      // v11 lets a board carry a set of track widths and via sizes to pick
      // from while routing. An existing board has none, which reads as
      // "just the design rule" — what it had before.
      if (from >= 5 && from < 11) {
        await m.addColumn(boards, boards.trackWidths);
        await m.addColumn(boards, boards.viaSizes);
      }
    },
    beforeOpen: (details) async {
      // Cascading deletes are the backbone of the schema (deleting a part
      // must take its units, pins and net memberships with it), and SQLite
      // leaves foreign keys off unless asked.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
