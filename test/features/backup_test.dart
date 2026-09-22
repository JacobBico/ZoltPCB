import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/file_saver.dart';
import 'package:hintpcb/data/archive/project_archive.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/features/project/backup_actions.dart';
import 'package:hintpcb/features/project/project_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class _FakeSaver implements FileSaver {
  final saved = <String, Uint8List>{};

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved[fileName] = bytes;
    return true;
  }
}

void main() {
  // "Project backup and restore. One file holding the whole project"
  testAppWithStorage('BACK UP writes one file that restores the project', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Keep Me');
    final parts = PartRepository(db);
    await parts.addPart(project.id, resistorSpec());
    await parts.addPart(project.id, resistorSpec());
    final saver = _FakeSaver();

    await pumpApp(
      tester,
      ProviderScope(
        overrides: [fileSaverProvider.overrideWithValue(saver)],
        child: ProjectScreen(
          projectId: project.id,
          initialSection: ProjectSection.export,
        ),
      ),
      database: db,
      storage: storage,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('backup-project')));
    await tester.tap(find.byKey(const ValueKey('backup-project')));
    await settleApp(tester);

    expect(saver.saved.keys, ['Keep_Me.hintpcb']);
    final bytes = saver.saved.values.single;
    expect(ProjectArchive.fromBytes(bytes).count('parts'), 2);

    // Restored beside the original, under a name that says what it is.
    final restored = await restoreBackupBytes(
      projects: ProjectRepository(db),
      archiver: ProjectArchiver(db),
      bytes: bytes,
    );
    final all = await ProjectRepository(db).getAll();
    expect(
      all.map((p) => p.name),
      containsAll(['Keep Me', 'Keep Me (restored)']),
    );
    expect(await parts.getPartsWithDetails(restored), hasLength(2));
  });

  // "Design snapshots. Named save points you can return to"
  testAppWithStorage('a snapshot is taken from the top bar and gone back to', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'History');
    final parts = PartRepository(db);
    await parts.addPart(project.id, resistorSpec());

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
      storage: storage,
    );

    await tester.tap(find.byKey(const ValueKey('snapshots-button')));
    await settleApp(tester);
    await tester.enterText(
      find.byKey(const ValueKey('snapshot-name')),
      'one resistor',
    );
    await tester.tap(find.byKey(const ValueKey('snapshot-take')));
    await settleApp(tester);
    expect(find.text('one resistor'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await settleApp(tester);

    await parts.addPart(project.id, resistorSpec());
    await parts.addPart(project.id, resistorSpec());
    await settleApp(tester);
    expect(await parts.getPartsWithDetails(project.id), hasLength(3));

    await tester.tap(find.byKey(const ValueKey('snapshots-button')));
    await settleApp(tester);
    await tester.tap(find.text('RESTORE').first);
    await settleApp(tester);
    // Confirm.
    await tester.tap(find.widgetWithText(FilledButton, 'RESTORE'));
    await settleApp(tester);

    expect(await parts.getPartsWithDetails(project.id), hasLength(1));

    // The three-resistor state was kept on the way.
    await tester.tap(find.byKey(const ValueKey('snapshots-button')));
    await settleApp(tester);
    expect(find.textContaining('Before restoring'), findsOneWidget);

    // Deleting one asks first; cancelling keeps it.
    Future<int> count() async =>
        (await db.select(db.projectSnapshots).get()).length;
    final kept = await count();
    await tester.tap(find.byTooltip('Delete').first);
    await settleApp(tester);
    expect(find.textContaining('cannot be taken back'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await settleApp(tester);
    expect(await count(), kept);

    await tester.tap(find.byTooltip('Delete').first);
    await settleApp(tester);
    await tester.tap(find.byKey(const ValueKey('snapshot-delete-confirm')));
    await settleApp(tester);
    expect(await count(), kept - 1);
  });
}
