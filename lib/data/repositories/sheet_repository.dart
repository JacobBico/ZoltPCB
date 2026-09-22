import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import '../db/watchers.dart';

/// What moving parts onto another sheet changed, so it can be put back.
class SheetMove {
  const SheetMove({
    required this.units,
    required this.movedWires,
    required this.removedWires,
  });

  /// The units as they were.
  final List<PartUnit> units;

  /// Wires that went with them, as they were.
  final List<SchematicWire> movedWires;

  /// Wires that ran from a moved part to one left behind. A wire cannot
  /// cross from one sheet to another, so they are taken away; the
  /// connection itself stays, and is drawn with labels on each sheet.
  final List<SchematicWire> removedWires;
}

/// The sub-sheets of a hierarchical schematic.
class SheetRepository {
  SheetRepository(this._db);

  final AppDatabase _db;

  Future<List<SchematicSheet>> getAll(String projectId) async {
    final rows = await (_db.select(
      _db.schematicSheets,
    )..where((t) => t.projectId.equals(projectId))).get();
    return rows.map(_toSheet).toList();
  }

  Stream<List<SchematicSheet>> watchAll(String projectId) =>
      _db.watchAggregate({_db.schematicSheets}, () => getAll(projectId));

  /// A new sheet on [parentId] (null: on the top sheet), its box at [at].
  Future<SchematicSheet> add({
    required String projectId,
    required String name,
    String? parentId,
    Offset at = const Offset(25.4, 25.4),
  }) async {
    final existing = await getAll(projectId);
    final sheet = SchematicSheet(
      id: newId(),
      projectId: projectId,
      parentId: parentId,
      name: name.trim(),
      fileName: _uniqueFileName(name, existing),
      box: Rect.fromLTWH(at.dx, at.dy, 30.48, 20.32),
      sortOrder: existing.length,
    );
    await restore(sheet);
    return sheet;
  }

  /// Writes [sheet] exactly, adding it if it is not there.
  Future<void> restore(SchematicSheet sheet) async {
    await _db
        .into(_db.schematicSheets)
        .insert(
          SchematicSheetsCompanion.insert(
            id: sheet.id,
            projectId: sheet.projectId,
            parentId: Value(sheet.parentId),
            name: sheet.name,
            fileName: sheet.fileName,
            x: Value(sheet.box.left),
            y: Value(sheet.box.top),
            width: Value(sheet.box.width),
            height: Value(sheet.box.height),
            sortOrder: Value(sheet.sortOrder),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> update(SchematicSheet sheet) => restore(sheet);

  /// Renames [sheet], and its file with it.
  Future<SchematicSheet> rename(SchematicSheet sheet, String name) async {
    final others = [
      for (final s in await getAll(sheet.projectId))
        if (s.id != sheet.id) s,
    ];
    final renamed = sheet.copyWith(
      name: name.trim(),
      fileName: _uniqueFileName(name, others),
    );
    await update(renamed);
    return renamed;
  }

  /// Deletes [sheet], keeping everything on it: its parts, wires, notes
  /// and sheets move up to the sheet it was on.
  Future<void> delete(SchematicSheet sheet) async {
    await _db.transaction(() async {
      final parent = Value(sheet.parentId);
      await (_db.update(_db.partUnits)
            ..where((t) => t.sheetId.equals(sheet.id)))
          .write(PartUnitsCompanion(sheetId: parent));
      await (_db.update(_db.schematicWires)
            ..where((t) => t.sheetId.equals(sheet.id)))
          .write(SchematicWiresCompanion(sheetId: parent));
      await (_db.update(_db.schematicNotes)
            ..where((t) => t.sheetId.equals(sheet.id)))
          .write(SchematicNotesCompanion(sheetId: parent));
      await (_db.update(_db.schematicSheets)
            ..where((t) => t.parentId.equals(sheet.id)))
          .write(SchematicSheetsCompanion(parentId: parent));
      await (_db.delete(
        _db.schematicSheets,
      )..where((t) => t.id.equals(sheet.id))).go();
    });
  }

  /// Puts the units in [unitIds] on [sheetId] (null: the top sheet), with
  /// the wires between them and those in [wireIds].
  Future<SheetMove> moveToSheet({
    required String projectId,
    required Set<String> unitIds,
    Set<String> wireIds = const {},
    required String? sheetId,
  }) async {
    final unitRows = await (_db.select(
      _db.partUnits,
    )..where((t) => t.id.isIn(unitIds))).get();
    final units = [for (final row in unitRows) _toUnit(row)];

    // The pins that move: every pin of a moved unit, and a package's
    // shared pins, which sit on whichever unit carries them.
    final partIds = {for (final u in units) u.partId};
    final pinRows = await (_db.select(
      _db.partPins,
    )..where((t) => t.partId.isIn(partIds))).get();
    final movedUnitNumbers = <String, Set<int>>{};
    for (final u in units) {
      (movedUnitNumbers[u.partId] ??= {}).add(u.unitNumber);
    }
    final movedPins = {
      for (final pin in pinRows)
        if (pin.unit == 0 ||
            (movedUnitNumbers[pin.partId]?.contains(pin.unit) ?? false))
          pin.id,
    };

    final wireRows = await (_db.select(
      _db.schematicWires,
    )..where((t) => t.projectId.equals(projectId))).get();
    final moved = <SchematicWireRow>[];
    final removed = <SchematicWireRow>[];
    for (final wire in wireRows) {
      final ends = [wire.pinAId, wire.pinBId].nonNulls.toList();
      final allMoved = ends.isNotEmpty && ends.every(movedPins.contains);
      final anyMoved = ends.any(movedPins.contains);
      // Pin to pin within the moved parts, or a free-standing piece of
      // wire that was picked with them: it goes too.
      if (allMoved || (ends.isEmpty && wireIds.contains(wire.id))) {
        moved.add(wire);
      } else if (anyMoved) {
        removed.add(wire);
      }
    }

    await _db.transaction(() async {
      await (_db.update(_db.partUnits)..where((t) => t.id.isIn(unitIds))).write(
        PartUnitsCompanion(sheetId: Value(sheetId)),
      );
      if (moved.isNotEmpty) {
        await (_db.update(_db.schematicWires)
              ..where((t) => t.id.isIn([for (final w in moved) w.id])))
            .write(SchematicWiresCompanion(sheetId: Value(sheetId)));
      }
      if (removed.isNotEmpty) {
        await (_db.delete(
          _db.schematicWires,
        )..where((t) => t.id.isIn([for (final w in removed) w.id]))).go();
      }
    });
    return SheetMove(
      units: units,
      movedWires: [for (final w in moved) _toWire(w)],
      removedWires: [for (final w in removed) _toWire(w)],
    );
  }

  /// Puts a [SheetMove] back.
  Future<void> undoMove(SheetMove move) async {
    await _db.transaction(() async {
      for (final unit in move.units) {
        await (_db.update(_db.partUnits)..where((t) => t.id.equals(unit.id)))
            .write(PartUnitsCompanion(sheetId: Value(unit.sheetId)));
      }
      for (final wire in [...move.movedWires, ...move.removedWires]) {
        await _db
            .into(_db.schematicWires)
            .insert(
              SchematicWiresCompanion.insert(
                id: wire.id,
                projectId: wire.projectId,
                netId: wire.netId,
                pinAId: Value(wire.pinAId),
                pinBId: Value(wire.pinBId),
                sheetId: Value(wire.sheetId),
                points: SchematicWire.encode(wire.points),
                createdAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// `power.kicad_sch`, or `power_2.kicad_sch` when that is taken.
  static String _uniqueFileName(String name, List<SchematicSheet> others) {
    var base = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'sheet';
    final taken = {for (final s in others) s.fileName};
    var candidate = '$base.kicad_sch';
    for (var n = 2; taken.contains(candidate); n++) {
      candidate = '${base}_$n.kicad_sch';
    }
    return candidate;
  }

  static SchematicSheet _toSheet(SchematicSheetRow row) => SchematicSheet(
    id: row.id,
    projectId: row.projectId,
    parentId: row.parentId,
    name: row.name,
    fileName: row.fileName,
    box: Rect.fromLTWH(row.x, row.y, row.width, row.height),
    sortOrder: row.sortOrder,
  );

  static PartUnit _toUnit(PartUnitRow row) => PartUnit(
    id: row.id,
    partId: row.partId,
    unitNumber: row.unitNumber,
    bodyStyle: row.bodyStyle,
    x: row.x,
    y: row.y,
    rotation: row.rotation,
    mirrorX: row.mirrorX,
    mirrorY: row.mirrorY,
    placed: row.placed,
    sheetId: row.sheetId,
  );

  static SchematicWire _toWire(SchematicWireRow row) => SchematicWire(
    id: row.id,
    projectId: row.projectId,
    netId: row.netId,
    pinAId: row.pinAId,
    pinBId: row.pinBId,
    sheetId: row.sheetId,
    points: SchematicWire.decode(row.points),
  );
}
