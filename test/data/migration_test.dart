import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/saved_circuit_repository.dart';
import 'package:hintpcb/data/repositories/sheet_repository.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

import '../helpers/fixtures.dart';

void main() {
  // The phone already holds a v13 database with the user's designs in it.
  // Upgrading has to add the new pieces around them and lose nothing.
  test(
    'a v13 database upgrades to the latest with its designs intact',
    () async {
      final dir = await Directory.systemTemp.createTemp('hintpcb_migrate');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      // Build a design at today's schema, then take the schema back to how
      // v13 had it: no stackup, no impedance, no pin labels, no snapshots,
      // notes, project settings or saved circuits.
      var db = AppDatabase(NativeDatabase(file));
      final project = await ProjectRepository(db).create(name: 'Old');
      final parts = PartRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await NetRepository(db).connectPins(r1.pins.first.id, r2.pins.first.id);
      await BoardRepository(db).ensureBoard(project.id);
      for (final statement in const [
        'DROP TABLE saved_circuits',
        'DROP TABLE board_features',
        'DROP TABLE board_dimensions',
        'DROP TABLE schematic_sheets',
        'ALTER TABLE part_units DROP COLUMN sheet_id',
        'ALTER TABLE schematic_wires DROP COLUMN sheet_id',
        'ALTER TABLE schematic_notes DROP COLUMN sheet_id',
        'DROP TABLE project_snapshots',
        'DROP TABLE schematic_notes',
        'DROP TABLE project_settings',
        'ALTER TABLE boards DROP COLUMN copper_layers',
        'ALTER TABLE boards DROP COLUMN thickness',
        'ALTER TABLE boards DROP COLUMN stackup',
        'ALTER TABLE net_classes DROP COLUMN impedance',
        'ALTER TABLE net_nodes DROP COLUMN labelled',
        'ALTER TABLE boards DROP COLUMN pad_connection',
        'ALTER TABLE boards DROP COLUMN via_connection',
        'ALTER TABLE boards DROP COLUMN thermal_gap',
        'ALTER TABLE boards DROP COLUMN thermal_spoke',
        'ALTER TABLE board_zones DROP COLUMN via_connection',
        'ALTER TABLE board_zones DROP COLUMN priority',
        'ALTER TABLE board_zones DROP COLUMN pad_connection',
        'ALTER TABLE board_zones DROP COLUMN thermal_gap',
        'ALTER TABLE board_zones DROP COLUMN thermal_spoke',
        'PRAGMA user_version = 13',
      ]) {
        await db.customStatement(statement);
      }
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final board = await BoardRepository(db).getBoard(project.id);
      expect(board, isNotNull);
      expect(board!.copperLayerCount, 2);
      expect(board.thickness, 1.6);
      expect(
        await PartRepository(db).getPartsWithDetails(project.id),
        hasLength(2),
      );
      final nets = await NetRepository(db).getNets(project.id);
      expect(nets.single.endpoints, hasLength(2));
      expect(nets.single.endpoints.every((e) => !e.node.labelled), isTrue);

      // The new tables work.
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, db.schemaVersion);
      await db.customStatement(
        "INSERT INTO project_settings (project_id, key, value) "
        "VALUES ('${project.id}', 'erc.lonelyNet', 'ignore')",
      );
      expect(await SavedCircuitRepository(db).getAll(), isEmpty);
    },
  );

  // What the phone had installed before sub-sheets: pours with no priority,
  // no holes or fiducials, no sheets.
  test('a v15 database upgrades with its board and parts intact', () async {
    final dir = await Directory.systemTemp.createTemp('hintpcb_migrate15');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    final project = await ProjectRepository(db).create(name: 'Fifteen');
    final r1 = await PartRepository(db).addPart(project.id, resistorSpec());
    await PartRepository(
      db,
    ).updateUnitPlacement(r1.units.first.copyWith(x: 10, y: 10, placed: true));
    final boards = BoardRepository(db);
    await boards.ensureBoard(project.id);
    await boards.addZone(
      projectId: project.id,
      layer: BoardLayer.frontCopper,
      points: const [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
    );
    for (final statement in const [
      'DROP TABLE board_features',
      'DROP TABLE board_dimensions',
      'DROP TABLE schematic_sheets',
      'ALTER TABLE part_units DROP COLUMN sheet_id',
      'ALTER TABLE schematic_wires DROP COLUMN sheet_id',
      'ALTER TABLE schematic_notes DROP COLUMN sheet_id',
      'ALTER TABLE boards DROP COLUMN pad_connection',
      'ALTER TABLE boards DROP COLUMN via_connection',
      'ALTER TABLE boards DROP COLUMN thermal_gap',
      'ALTER TABLE boards DROP COLUMN thermal_spoke',
      'ALTER TABLE board_zones DROP COLUMN via_connection',
      'ALTER TABLE board_zones DROP COLUMN priority',
      'ALTER TABLE board_zones DROP COLUMN pad_connection',
      'ALTER TABLE board_zones DROP COLUMN thermal_gap',
      'ALTER TABLE board_zones DROP COLUMN thermal_spoke',
      'PRAGMA user_version = 15',
    ]) {
      await db.customStatement(statement);
    }
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final zone = (await BoardRepository(db).getZones(project.id)).single;
    expect(zone.priority, 0);
    expect(zone.padConnection, PadConnection.thermal);
    final part = (await PartRepository(
      db,
    ).getPartsWithDetails(project.id)).single;
    expect(part.units.single.placed, isTrue);
    expect(part.units.single.sheetId, isNull, reason: 'on the top sheet');
    expect(await SheetRepository(db).getAll(project.id), isEmpty);
    expect(await BoardRepository(db).getFeatures(project.id), isEmpty);
  });
}
