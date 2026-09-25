import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/models.dart';
import 'converters.dart';
import 'tables/tables.dart';

part 'database.g.dart';

/// The on-device SQLite database. Zolt is local-first: this file is the
/// only home a design has until the user exports it.
@DriftDatabase(
  tables: [
    Projects,
    Parts,
    PartUnits,
    PartPins,
    Nets,
    NetClasses,
    NetNodes,
    SchematicWires,
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
    BoardTexts,
    AppSettings,
    ProjectSnapshots,
    SchematicNotes,
    ProjectSettings,
    SavedCircuits,
    BoardFeatures,
    BoardDimensions,
    SchematicSheets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An ephemeral database for tests. Runs natively, so the whole data layer
  /// can be exercised without an emulator.
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// The app's persistent database, stored in the application support
  /// directory.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: _databaseName));

  static const _databaseName = 'zolt';

  /// Timestamps are stored as ISO-8601 text rather than drift's default
  /// unix-seconds integer. Second resolution is too coarse for ordering the
  /// project list by recent activity, and text keeps sub-second precision.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// Merges nets that share a name within a project into the oldest of
  /// them, carrying pins, copper and drawn wires across.
  ///
  /// Plain SQL, because it runs inside a migration, before any repository
  /// can safely be used.
  Future<void> joinSameNamedNets() async {
    final groups = await customSelect(
      "SELECT project_id, name FROM nets WHERE name IS NOT NULL AND name != '' "
      'GROUP BY project_id, name HAVING COUNT(*) > 1',
    ).get();
    for (final group in groups) {
      final ids = await customSelect(
        'SELECT id FROM nets WHERE project_id = ? AND name = ? '
        'ORDER BY created_at',
        variables: [
          Variable<String>(group.read<String>('project_id')),
          Variable<String>(group.read<String>('name')),
        ],
      ).get();
      final keep = ids.first.read<String>('id');
      for (final row in ids.skip(1)) {
        final lose = row.read<String>('id');
        for (final table in const [
          'net_nodes',
          'board_tracks',
          'board_vias',
          'board_zones',
          'schematic_wires',
        ]) {
          await customStatement(
            'UPDATE $table SET net_id = ? WHERE net_id = ?',
            [keep, lose],
          );
        }
        await customStatement('DELETE FROM nets WHERE id = ?', [lose]);
      }
    }
  }

  @override
  int get schemaVersion => 22;

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
      // v12 adds the silkscreen: where each designator sits and whether it
      // is printed, and free board text. A board from before has neither
      // moved a label nor written any text, which the defaults say.
      if (from >= 5 && from < 12) {
        await m.addColumn(boardFootprints, boardFootprints.labelX);
        await m.addColumn(boardFootprints, boardFootprints.labelY);
        await m.addColumn(boardFootprints, boardFootprints.labelSize);
        await m.addColumn(boardFootprints, boardFootprints.labelHidden);
      }
      if (from < 12) {
        await m.createTable(boardTexts);
        await m.createIndex(idxBoardTextsProject);
      }
      // v13 adds named net classes and drawn schematic wires, and makes a
      // net's name its identity: two nets both called GND were always meant
      // to be one, and from here on they are.
      if (from < 13) {
        await m.createTable(netClasses);
        await m.createIndex(idxNetClassesProject);
        await m.addColumn(nets, nets.netClassId);
        await m.createTable(schematicWires);
        await m.createIndex(idxSchematicWiresProject);
        await joinSameNamedNets();
      }
      // v14 adds snapshots, sheet notes, per-project settings, and a board
      // stackup with more than two copper layers. Every addition defaults
      // to what a project had before: no snapshots, no notes, two layers
      // of 1.6 mm board, and net classes routed by width alone.
      if (from < 14) {
        await m.createTable(projectSnapshots);
        await m.createIndex(idxProjectSnapshotsProject);
        await m.createTable(schematicNotes);
        await m.createIndex(idxSchematicNotesProject);
        await m.createTable(projectSettings);
      }
      if (from >= 5 && from < 14) {
        await m.addColumn(boards, boards.copperLayers);
        await m.addColumn(boards, boards.thickness);
        await m.addColumn(boards, boards.stackup);
      }
      if (from >= 13 && from < 14) {
        await m.addColumn(netClasses, netClasses.impedance);
      }
      if (from < 14) {
        await m.addColumn(netNodes, netNodes.labelled);
      }
      // v15 keeps saved circuits, across projects. Nothing to migrate.
      if (from < 15) {
        await m.createTable(savedCircuits);
      }
      // v16 gives pours a priority and a way of joining their pads. Only
      // for a table from before: one made at step 10 above has them.
      if (from >= 10 && from < 16) {
        await m.addColumn(boardZones, boardZones.priority);
        await m.addColumn(boardZones, boardZones.padConnection);
        await m.addColumn(boardZones, boardZones.thermalGap);
        await m.addColumn(boardZones, boardZones.thermalSpoke);
      }
      // v17: mounting holes, fiducials, test points and dimensions.
      if (from < 17) {
        await m.createTable(boardFeatures);
        await m.createIndex(idxBoardFeaturesProject);
        await m.createTable(boardDimensions);
        await m.createIndex(idxBoardDimensionsProject);
      }
      // v18: sub-sheets. Everything already drawn is on the top sheet,
      // which is what a missing sheet says.
      if (from < 18) {
        await m.createTable(schematicSheets);
        await m.createIndex(idxSchematicSheetsProject);
        await m.addColumn(partUnits, partUnits.sheetId);
        if (from >= 13) {
          await m.addColumn(schematicWires, schematicWires.sheetId);
        }
        // Before 14 there were no notes; step 14 made the table as it is
        // now, sheet column and all.
        if (from >= 14) {
          await m.addColumn(schematicNotes, schematicNotes.sheetId);
        }
      }
      // v19: how a pour joins its own net, vias included, and the defaults
      // a new pour is made with.
      if (from < 19) {
        await m.addColumn(boards, boards.padConnection);
        await m.addColumn(boards, boards.viaConnection);
        await m.addColumn(boards, boards.thermalGap);
        await m.addColumn(boards, boards.thermalSpoke);
        await m.addColumn(boardZones, boardZones.viaConnection);
      }
      // v20: keepout areas, blind and buried vias, and holding copper and
      // parts where they are.
      //
      // The flags go in as raw SQL rather than through the migrator, and
      // deliberately without the `CHECK (x IN (0, 1))` a boolean column
      // normally carries. SQLite validates a new CHECK against the rows
      // already in the table, and once other columns have been added to
      // that table earlier in the same transaction it reads those rows
      // with the old column count — so it finds nothing where the columns
      // it just added should be, and refuses the whole migration with a
      // NOT NULL failure. Nothing but this app writes these columns, and a
      // database made fresh still gets the check from the schema.
      Future<void> flag(String table, String column, bool value) =>
          customStatement(
            'ALTER TABLE $table ADD COLUMN "$column" INTEGER NOT NULL '
            'DEFAULT ${value ? 1 : 0}',
          );

      if (from < 20) {
        await flag('board_tracks', 'locked', false);
        await flag('board_vias', 'locked', false);
        await m.addColumn(boardVias, boardVias.viaKind);
        await m.addColumn(boardVias, boardVias.fromLayer);
        await m.addColumn(boardVias, boardVias.toLayer);
        await flag('board_footprints', 'locked', false);
        await m.addColumn(boards, boards.teardrops);
        await flag('board_zones', 'keepout', false);
        await flag('board_zones', 'no_tracks', true);
        await flag('board_zones', 'no_vias', true);
        await flag('board_zones', 'no_pours', true);
        await flag('board_zones', 'no_parts', false);
        await flag('board_zones', 'locked', false);
      }
      // v21: a net label's own text size.
      if (from < 21) {
        await m.addColumn(nets, nets.labelSize);
      }
      // v22: a part's component ID, for ordering and assembly.
      if (from < 22) {
        await m.addColumn(parts, parts.componentId);
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
