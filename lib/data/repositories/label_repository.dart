import 'dart:ui';

import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/database.dart';

/// Labels as a KiCad file drew them (see [SchematicLabel]).
class LabelRepository {
  LabelRepository(this._db);

  final AppDatabase _db;

  Stream<List<SchematicLabel>> watch(String projectId) =>
      (_db.select(_db.schematicLabels)
            ..where((t) => t.projectId.equals(projectId)))
          .watch()
          .map((rows) => rows.map(_toLabel).toList());

  Future<List<SchematicLabel>> getAll(String projectId) async =>
      (await (_db.select(
            _db.schematicLabels,
          )..where((t) => t.projectId.equals(projectId))).get())
          .map(_toLabel)
          .toList();

  Future<void> addAll(Iterable<SchematicLabel> labels) async {
    await _db.batch((batch) {
      for (final label in labels) {
        batch.insert(
          _db.schematicLabels,
          SchematicLabelsCompanion.insert(
            id: label.id,
            projectId: label.projectId,
            sheetId: Value(label.sheetId),
            kind: label.kind.token,
            content: label.text,
            x: label.position.dx,
            y: label.position.dy,
            angle: Value(label.angle),
            size: Value(label.size),
            shape: Value(label.shape),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static SchematicLabel _toLabel(SchematicLabelRow row) => SchematicLabel(
    id: row.id,
    projectId: row.projectId,
    sheetId: row.sheetId,
    kind: SchematicLabelKind.fromToken(row.kind) ?? SchematicLabelKind.local,
    text: row.content,
    position: Offset(row.x, row.y),
    angle: row.angle,
    size: row.size,
    shape: row.shape,
  );
}
