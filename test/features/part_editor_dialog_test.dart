import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/features/project/part_editor_dialog.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  // "the 'value' and 'reference' texts are pre-maturely cut-off"
  testApp('the part editor opens with its labels in full view', (
    tester,
    db,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Fields');
    final added = await PartRepository(db).addPart(project.id, resistorSpec());

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPartEditorDialog(context, part: added.part),
            child: const Text('OPEN'),
          ),
        ),
      ),
      database: db,
    );

    await tester.tap(find.text('OPEN'));
    await settleApp(tester);

    // It all fits: nothing to scroll, on a phone in landscape.
    final scroll = tester.widget<Scrollable>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      scroll.controller?.position.maxScrollExtent ?? 0,
      0,
      reason: 'the dialog should fit without scrolling',
    );

    // The floating labels are drawn above their boxes, so anything that
    // scrolls the fields up slices them against the top of the dialog.
    final dialog = tester.getRect(find.byType(AlertDialog));
    for (final label in ['Reference', 'Value', 'Footprint']) {
      final box = tester.getRect(find.text(label));
      expect(
        box.top,
        greaterThan(dialog.top),
        reason: '$label is cut off by the top of the dialog',
      );
      expect(
        box.bottom,
        lessThan(dialog.bottom),
        reason: '$label is cut off by the bottom of the dialog',
      );
    }
  });
}
