import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/archive/project_archive.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/note_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/models/models.dart';

void main() {
  late AppDatabase db;
  late NoteRepository notes;
  late String projectId;

  setUp(() async {
    db = AppDatabase.memory();
    notes = NoteRepository(db);
    projectId = (await ProjectRepository(db).create(name: 'Notes')).id;
  });
  tearDown(() => db.close());

  test('a note is kept, changed, deleted and put back', () async {
    final note = await notes.add(
      projectId: projectId,
      kind: NoteKind.box,
      content: 'Power',
      position: const Offset(10, 20),
      size: const Size(40, 25),
    );
    expect((await notes.getAll(projectId)).single, note);

    final moved = note.copyWith(position: const Offset(30, 40), content: 'PSU');
    await notes.update(moved);
    expect((await notes.getAll(projectId)).single, moved);

    await notes.delete(note.id);
    expect(await notes.getAll(projectId), isEmpty);
    await notes.restore(moved);
    expect((await notes.getAll(projectId)).single.id, note.id);
  });

  test('notes travel in a backup', () async {
    await notes.add(
      projectId: projectId,
      kind: NoteKind.text,
      content: '5 V rail, 500 mA max',
      position: const Offset(1, 2),
    );
    final archiver = ProjectArchiver(db);
    final copy = await archiver.restoreAsNew(await archiver.capture(projectId));
    expect((await notes.getAll(copy)).single.content, '5 V rail, 500 mA max');
  });

  test('a box is touched on its frame and caption, not its middle', () {
    const box = SchematicNote(
      id: 'n',
      projectId: 'p',
      kind: NoteKind.box,
      content: 'Power',
      position: Offset(0, 0),
      size: Size(50, 30),
    );
    expect(box.hit(const Offset(25, 0.2), 0.5), isTrue);
    expect(box.hit(const Offset(49.8, 15), 0.5), isTrue);
    expect(box.hit(const Offset(1, 1), 0.5), isTrue, reason: 'the caption');
    expect(box.hit(const Offset(25, 15), 0.5), isFalse);
  });
}
