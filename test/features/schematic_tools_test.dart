import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/note_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/project_settings_repository.dart';
import 'package:hintpcb/data/repositories/saved_circuit_repository.dart';
import 'package:hintpcb/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// A capacitor: another kind of part from a resistor.
NewPartSpec _capacitor() => const NewPartSpec(
  libId: 'Device:C',
  value: '100n',
  referencePrefix: 'C',
  pins: [
    NewPinSpec(
      number: '1',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: 3.81,
      angle: 270,
    ),
    NewPinSpec(
      number: '2',
      name: '~',
      electricalType: PinElectricalType.passive,
      y: -3.81,
      angle: 90,
    ),
  ],
);

/// A ground symbol, which has no footprint and is never fitted.
NewPartSpec _ground() => const NewPartSpec(
  libId: 'power:GND',
  value: 'GND',
  referencePrefix: '#PWR',
  inBom: false,
  onBoard: false,
  pins: [
    NewPinSpec(
      number: '1',
      name: 'GND',
      electricalType: PinElectricalType.powerIn,
    ),
  ],
);

Future<void> _placeAll(
  PartRepository parts,
  String projectId,
  List<(NewPartSpec, double, double)> specs,
) async {
  for (final (spec, x, y) in specs) {
    final part = await parts.addPart(projectId, spec);
    await parts.updateUnitPlacement(
      part.units.first.copyWith(x: x, y: y, placed: true),
    );
  }
}

void main() {
  testAppWithStorage(
    'a long press starts picking parts, and DNP marks them all, undoably',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Pick');
      final parts = PartRepository(db);
      await _placeAll(parts, project.id, [
        (resistorSpec(), 50.8, 50.8),
        (resistorSpec(value: '4k7'), 76.2, 50.8),
        (_capacitor(), 101.6, 50.8),
      ]);

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      // No Select mode: a long press on R1 starts the pick, taps add to it.
      await tester.longPressAt(_screen(tester, const Offset(50.8, 50.8)));
      await settleApp(tester);
      expect(find.textContaining('Tap more parts'), findsOneWidget);
      await tester.tapAt(_screen(tester, const Offset(101.6, 50.8)));
      await settleApp(tester);
      expect(find.text('2 parts selected'), findsOneWidget);
      // A second tap takes one back out.
      await tester.tapAt(_screen(tester, const Offset(101.6, 50.8)));
      await settleApp(tester);
      await tester.tapAt(_screen(tester, const Offset(76.2, 50.8)));
      await settleApp(tester);
      expect(find.text('2 parts selected'), findsOneWidget);

      Future<Map<String, bool>> dnp() async => {
        for (final p in await parts.getPartsWithDetails(project.id))
          p.part.reference: p.part.dnp,
      };

      await _tapAction(tester, 'DNP');
      expect(await dnp(), {'R1': true, 'R2': true, 'C1': false});
      // Still placed and still counted for ordering.
      for (final p in await parts.getPartsWithDetails(project.id)) {
        expect(p.part.inBom, isTrue);
        expect(p.units.first.placed, isTrue);
      }
      // All of them are DNP now, so the same button fits them again.
      expect(find.text('Fit'), findsOneWidget);

      await _tapAction(tester, 'Undo');
      expect(await dnp(), {'R1': false, 'R2': false, 'C1': false});
    },
  );

  testAppWithStorage(
    'editing mixed kinds of parts offers no shared value or footprint',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Mixed');
      final parts = PartRepository(db);
      await _placeAll(parts, project.id, [
        (resistorSpec(), 50.8, 50.8),
        (_capacitor(), 76.2, 50.8),
        (_ground(), 101.6, 50.8),
      ]);

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.longPressAt(_screen(tester, const Offset(50.8, 50.8)));
      await settleApp(tester);
      for (final x in [76.2, 101.6]) {
        await tester.tapAt(_screen(tester, Offset(x, 50.8)));
        await settleApp(tester);
      }
      expect(find.text('3 parts selected'), findsOneWidget);

      await _tapAction(tester, 'Edit');
      // Two parts, not three: the ground symbol is not a part to edit.
      expect(find.text('Edit 2 parts'), findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-value')), findsNothing);
      expect(find.byKey(const ValueKey('bulk-footprint')), findsNothing);
      expect(find.byKey(const ValueKey('bulk-mixed-kinds')), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await settleApp(tester);

      // Marking them DNP leaves the ground symbol alone.
      await _tapAction(tester, 'DNP');
      final byRef = {
        for (final p in await parts.getPartsWithDetails(project.id))
          p.part.reference: p.part.dnp,
      };
      expect(byRef['R1'], isTrue);
      expect(byRef['C1'], isTrue);
      expect(
        byRef.entries.where((e) => e.key.startsWith('#PWR')).single.value,
        isFalse,
      );
    },
  );

  testAppWithStorage(
    'a picked circuit is saved and added again from the list',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Saved');
      final parts = PartRepository(db);
      await _placeAll(parts, project.id, [
        (resistorSpec(value: '100k'), 50.8, 50.8),
        (_capacitor(), 76.2, 50.8),
      ]);

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.longPressAt(_screen(tester, const Offset(50.8, 50.8)));
      await settleApp(tester);
      await tester.tapAt(_screen(tester, const Offset(76.2, 50.8)));
      await settleApp(tester);
      await _tapAction(tester, 'Save');
      await tester.enterText(
        find.byKey(const ValueKey('save-circuit-name')),
        'RC filter',
      );
      await tester.tap(find.byKey(const ValueKey('save-circuit-confirm')));
      await settleApp(tester);

      final saved = await SavedCircuitRepository(db).getAll();
      expect(saved.single.name, 'RC filter');
      expect(saved.single.clip.parts, hasLength(2));

      // Let the selection go, then add it back from the component list.
      await tester.tapAt(_screen(tester, const Offset(20, 20)));
      await settleApp(tester);
      ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      ).read(componentPickerOpenProvider.notifier).set(true);
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('saved-circuits-tab')));
      await settleApp(tester);
      expect(find.text('RC filter'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('saved-circuit-${saved.single.id}')),
      );
      await settleApp(tester);

      final values = [
        for (final p in await parts.getPartsWithDetails(project.id))
          p.part.value,
      ]..sort();
      expect(values, ['100k', '100k', '100n', '100n']);

      // And it can be deleted from the list.
      await tester.tap(
        find.byKey(ValueKey('saved-circuit-delete-${saved.single.id}')),
      );
      await settleApp(tester);
      await tester.tap(
        find.byKey(const ValueKey('saved-circuit-delete-confirm')),
      );
      await settleApp(tester);
      expect(await SavedCircuitRepository(db).getAll(), isEmpty);
    },
  );

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
