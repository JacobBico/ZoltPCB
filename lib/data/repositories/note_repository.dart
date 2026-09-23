import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import 'active_sheet.dart';

/// Text and boxes on the schematic sheet.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;

  Stream<List<SchematicNote>> watch(String projectId) {
    final query = _db.select(_db.schematicNotes)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toNote).toList());
  }

  Future<List<SchematicNote>> getAll(String projectId) async {
    final query = _db.select(_db.schematicNotes)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return (await query.get()).map(_toNote).toList();
  }

  Future<SchematicNote> add({
    required String projectId,
    required NoteKind kind,
    required String content,
    required Offset position,
    Size size = Size.zero,
    double textSize = SchematicNote.defaultTextSize,
    String? sheetId,
  }) async {
    final note = SchematicNote(
      id: newId(),
      projectId: projectId,
      sheetId: sheetId ?? ActiveSheet.of(_db, projectId),
      kind: kind,
      content: content,
      position: position,
      size: size,
      textSize: textSize,
    );
    await restore(note);
    return note;
  }

  /// Writes [note] back, or puts it back if it was deleted — so an undone
  /// deletion keeps its id.
  Future<void> restore(SchematicNote note) async {
    await _db
        .into(_db.schematicNotes)
        .insert(
          SchematicNotesCompanion.insert(
            id: note.id,
            projectId: note.projectId,
            kind: Value(note.kind.name),
            content: Value(note.content),
            x: note.position.dx,
            y: note.position.dy,
            width: Value(note.size.width),
            height: Value(note.size.height),
            size: Value(note.textSize),
            sheetId: Value(note.sheetId),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> update(SchematicNote note) async {
    await (_db.update(
      _db.schematicNotes,
    )..where((t) => t.id.equals(note.id))).write(
      SchematicNotesCompanion(
        kind: Value(note.kind.name),
        content: Value(note.content),
        x: Value(note.position.dx),
        y: Value(note.position.dy),
        width: Value(note.size.width),
        height: Value(note.size.height),
        size: Value(note.textSize),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.schematicNotes)..where((t) => t.id.equals(id))).go();
  }

  static SchematicNote _toNote(SchematicNoteRow row) => SchematicNote(
    id: row.id,
    projectId: row.projectId,
    kind: NoteKind.byName(row.kind),
    content: row.content,
    position: Offset(row.x, row.y),
    size: Size(row.width, row.height),
    textSize: row.size,
    sheetId: row.sheetId,
  );
}
