import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/note_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/project_settings_repository.dart';
import 'package:hintpcb/domain/erc/erc.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

Offset _screen(WidgetTester tester, Offset sheet) =>
    tester.getRect(find.byType(SchematicPanel)).topLeft +
    _painter(tester).viewport.toScreen(sheet);

Future<void> _drag(
  WidgetTester tester,
  Offset fromSheet,
  Offset toSheet,
) async {
  final from = _screen(tester, fromSheet);
  final to = _screen(tester, toSheet);
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await settleApp(tester);
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await settleApp(tester);
}

/// A four-pin part, two pins either side, so a tap on its middle means the
/// part rather than any one pin.
NewPartSpec _fourPin() => const NewPartSpec(
  libId: 'Test:Conn4',
  value: 'Conn',
  referencePrefix: 'J',
  pins: [
    NewPinSpec(
      number: '1',
      name: 'A',
      electricalType: PinElectricalType.passive,
      x: -7.62,
      y: 1.27,
    ),
    NewPinSpec(
      number: '2',
      name: 'B',
      electricalType: PinElectricalType.passive,
      x: -7.62,
      y: -1.27,
    ),
    NewPinSpec(
      number: '3',
      name: 'C',
      electricalType: PinElectricalType.passive,
      x: 7.62,
      y: 1.27,
      angle: 180,
    ),
    NewPinSpec(
      number: '4',
      name: 'D',
      electricalType: PinElectricalType.passive,
      x: 7.62,
      y: -1.27,
      angle: 180,
    ),
  ],
);

void main() {
  // "Sheet notes. Free text and boxes on the drawing"
  testAppWithStorage('a note is written, picked up, moved and deleted', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Notes');
    final parts = PartRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    // Tap an empty spot first, so the note goes there: to the right of the
    // resistor, on screen whatever the fit.
    final rect = tester.getRect(find.byType(SchematicPanel));
    final spotScreen = rect.center + const Offset(180, -80);
    final spot = _painter(tester).viewport.toSheet(spotScreen - rect.topLeft);
    await tester.tapAt(spotScreen);
    await settleApp(tester);

    await _tapAction(tester, 'Note');
    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      '5 V rail',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-save')));
    await settleApp(tester);

    final notes = NoteRepository(db);
    final note = (await notes.getAll(project.id)).single;
    expect(note.content, '5 V rail');
    expect((note.position - spot).distance, lessThan(1.5));
    expect(_painter(tester).notes.single.content, '5 V rail');
    // Just added, it is the selection.
    expect(find.text('Note — drag to move'), findsOneWidget);

    // Dragging it moves it.
    final grab = note.position + const Offset(1, 0.5);
    await _drag(tester, grab, grab + const Offset(12.7, 12.7));
    final moved = (await notes.getAll(project.id)).single;
    expect(
      (moved.position - note.position - const Offset(12.7, 12.7)).distance,
      lessThan(1.5),
    );

    await _tapAction(tester, 'Delete');
    expect(await notes.getAll(project.id), isEmpty);
    await _tapAction(tester, 'Undo');
    expect((await notes.getAll(project.id)).single.id, note.id);
  });

  // "Bulk field edit. Select several parts and set value, footprint or DNP
  // in one go"
  testAppWithStorage('several parts take one value at once, and undo', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Bulk');
    final parts = PartRepository(db);
    for (final (x, y, value) in [
      (50.8, 50.8, '10k'),
      (63.5, 50.8, '4k7'),
      (101.6, 88.9, '1k'),
    ]) {
      final part = await parts.addPart(project.id, resistorSpec(value: value));
      await parts.updateUnitPlacement(
        part.units.first.copyWith(x: x, y: y, placed: true),
      );
    }

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    await _tapAction(tester, 'Select');
    await _drag(tester, const Offset(42, 44), const Offset(70, 60));
    expect(find.text('2 parts selected'), findsOneWidget);

    await _tapAction(tester, 'Edit');
    // They differ, so the field starts empty and says so.
    expect(find.text('Mixed'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('bulk-value')), '100k');
    await tester.pump();
    await tester.ensureVisible(find.text('Do not populate'));
    await tester.pump();
    await tester.tap(find.text('Do not populate'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bulk-save')));
    await settleApp(tester);

    Future<Map<String, (String, bool)>> state() async => {
      for (final p in await parts.getPartsWithDetails(project.id))
        p.part.reference: (p.part.value, p.part.dnp),
    };
    expect(await state(), {
      'R1': ('100k', true),
      'R2': ('100k', true),
      'R3': ('1k', false),
    });

    await _tapAction(tester, 'Undo');
    expect(await state(), {
      'R1': ('10k', false),
      'R2': ('4k7', false),
      'R3': ('1k', false),
    });
  });

  // "Buses and repeated labels. Wire D0..D7 without drawing eight wires and
  // typing eight labels"
  testAppWithStorage('a range of labels joins two parts pin for pin', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Bus');
    final parts = PartRepository(db);
    final u1 = await parts.addPart(project.id, _fourPin());
    final u2 = await parts.addPart(project.id, _fourPin());
    for (final (part, x) in [(u1, 50.8), (u2, 101.6)]) {
      await parts.updateUnitPlacement(
        part.units.single.copyWith(x: x, y: 63.5, placed: true),
      );
    }
    final nets = NetRepository(db);

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    Future<void> label(Offset at) async {
      await tester.tapAt(_screen(tester, at));
      await settleApp(tester);
      await _tapAction(tester, 'Labels');
      await tester.enterText(
        find.byKey(const ValueKey('pin-labels-pattern')),
        'D[0..2]',
      );
      await tester.pump();
      // The first three unwired pins, in pin order: 1, 2, 3.
      await tester.tap(find.byKey(const ValueKey('pin-labels-apply')));
      await settleApp(tester);
    }

    Future<void> tapAway() async {
      final rect = tester.getRect(find.byType(SchematicPanel));
      await tester.tapAt(rect.center + const Offset(0, -120));
      await settleApp(tester);
    }

    await label(const Offset(50.8, 63.5));
    await tapAway();
    await label(const Offset(101.6, 63.5));

    final byName = {
      for (final net in await nets.getNets(project.id))
        net.displayName: {
          for (final e in net.endpoints) '${e.part.reference}.${e.pin.number}',
        },
    };
    expect(byName['D0'], {'J1.1', 'J2.1'});
    expect(byName['D1'], {'J1.2', 'J2.2'});
    expect(byName['D2'], {'J1.3', 'J2.3'});
    expect(byName.keys.where((k) => k.startsWith('D')), hasLength(3));

    // Both ends say so on the sheet.
    final drawn = _painter(tester).scene.labels.where((l) => l.text == 'D0');
    expect(drawn, hasLength(2));

    // One undo takes back the second part's labels, and only those.
    await tapAway();
    await _tapAction(tester, 'Undo');
    final after = {
      for (final net in await nets.getNets(project.id))
        net.displayName: {
          for (final e in net.endpoints) '${e.part.reference}.${e.pin.number}',
        },
    };
    expect(after['D0'], {'J1.1'});
    expect(after['D2'], {'J1.3'});
  });

  // "Configurable ERC rules"
  testAppWithStorage('a check switched off stays off for the project', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Checks');
    final parts = PartRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    await _tapAction(tester, 'Check');
    expect(find.textContaining('unconnected'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('erc-rules')));
    await settleApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('erc-level-unconnectedPin')),
        matching: find.text('Off'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    // The check runs again, without it.
    expect(find.textContaining('unconnected'), findsNothing);
    expect(find.textContaining('1 check off'), findsOneWidget);
    final saved = ErcSettings.fromSettings(
      await ProjectSettingsRepository(db).getAll(project.id),
    );
    expect(saved.levelOf(ErcRule.unconnectedPin), ErcLevel.ignore);
  });
}
