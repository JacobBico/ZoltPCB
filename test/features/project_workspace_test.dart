import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/features/project/components_panel.dart';
import 'package:hintpcb/features/project/nets_panel.dart';
import 'package:hintpcb/features/project/value_keypad.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  group('components', () {
    testAppWithStorage('explains itself when the project is empty', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'P');

      await pumpApp(
        tester,
        Scaffold(body: ProjectComponentsPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.text('No components yet'), findsOneWidget);
      expect(find.text('ADD COMPONENT'), findsOneWidget);
    });

    testAppWithStorage('lists parts with designator, value and pin count', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'P');
      final parts = PartRepository(db);
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, dualOpampSpec());

      await pumpApp(
        tester,
        Scaffold(body: ProjectComponentsPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.text('R1'), findsOneWidget);
      expect(find.text('10k'), findsOneWidget);
      expect(find.text('Device:R'), findsOneWidget);
      expect(find.text('U1'), findsOneWidget);
      expect(find.text('NE5532'), findsOneWidget);
      // The opamp is a two-unit package.
      expect(find.text('2'), findsWidgets);
    });

    testAppWithStorage('editing a part writes the new value through', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'P');
      final parts = PartRepository(db);
      final added = await parts.addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: ProjectComponentsPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.tap(find.text('R1'));
      await settleApp(tester);

      // A resistor's value opens on the keypad, not the phone's keyboard;
      // the field itself is read-only until you ask for letters.
      expect(find.byType(ValueKeypad), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
      await settleApp(tester);
      expect(find.byType(ValueKeypad), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Value'),
        '4k7',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Footprint'),
        'Resistor_SMD:R_0402',
      );
      await tester.tap(find.text('SAVE'));
      await settleApp(tester);

      final stored = await parts.getPartWithDetails(added.part.id);
      expect(stored!.part.value, '4k7');
      expect(stored.part.footprint, 'Resistor_SMD:R_0402');
    });

    testAppWithStorage('deleting a part asks first', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'P');
      final parts = PartRepository(db);
      await parts.addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: ProjectComponentsPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await settleApp(tester);
      await tester.tap(find.text('Delete'));
      await settleApp(tester);
      expect(find.text('Delete R1?'), findsOneWidget);

      await tester.tap(find.text('DELETE'));
      await settleApp(tester);

      expect(await parts.getPartsWithDetails(project.id), isEmpty);
      expect(find.text('No components yet'), findsOneWidget);
    });
  });

  group('tap-to-connect', () {
    Future<(Project, PartRepository, NetRepository)> setUpProject(
      dynamic db,
    ) async {
      final project = await ProjectRepository(db).create(name: 'P');
      final parts = PartRepository(db);
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, resistorSpec());
      return (project, parts, NetRepository(db));
    }

    testAppWithStorage('says what to do before anything is connected', (
      tester,
      db,
      storage,
    ) async {
      final (project, _, _) = await setUpProject(db);

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(
        find.text('Tap a pin, then tap another to connect them'),
        findsOneWidget,
      );
      expect(find.text('No nets yet'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);
    });

    testAppWithStorage('two taps make a net', (tester, db, storage) async {
      final (project, parts, nets) = await setUpProject(db);
      final all = await parts.getPartsWithDetails(project.id);
      final r1Pin1 = all[0].pins.first;
      final r2Pin1 = all[1].pins.first;

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.tap(find.byKey(ValueKey('pin-${r1Pin1.id}')));
      await settleApp(tester);
      expect(find.textContaining('Connecting from R1'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('pin-${r2Pin1.id}')));
      await settleApp(tester);

      final stored = await nets.getNets(project.id);
      expect(stored, hasLength(1));
      expect(stored.single.endpoints.map((e) => e.pin.id).toSet(), {
        r1Pin1.id,
        r2Pin1.id,
      });
      // Endpoints are ordered by designator, so the auto-generated name is
      // stable regardless of which pin was tapped first.
      expect(stored.single.endpoints.map((e) => e.shortLabel), [
        'R1.1',
        'R2.1',
      ]);

      await settleApp(tester);
      expect(find.text('Net-(R1-Pad1)'), findsWidgets);
    });

    testAppWithStorage('tapping the same pin again cancels', (
      tester,
      db,
      storage,
    ) async {
      final (project, parts, nets) = await setUpProject(db);
      final pin = (await parts.getPartsWithDetails(project.id))[0].pins.first;

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.tap(find.byKey(ValueKey('pin-${pin.id}')));
      await settleApp(tester);
      expect(find.textContaining('Connecting from'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('pin-${pin.id}')));
      await settleApp(tester);

      expect(find.textContaining('Connecting from'), findsNothing);
      expect(await nets.getNets(project.id), isEmpty);
    });

    testAppWithStorage('the cancel button clears a pending pin', (
      tester,
      db,
      storage,
    ) async {
      final (project, parts, _) = await setUpProject(db);
      final pin = (await parts.getPartsWithDetails(project.id))[0].pins.first;

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );

      await tester.tap(find.byKey(ValueKey('pin-${pin.id}')));
      await settleApp(tester);
      await tester.tap(find.text('CANCEL'));
      await settleApp(tester);

      expect(find.textContaining('Connecting from'), findsNothing);
    });

    testAppWithStorage('disconnecting a pin drops the two-pin net', (
      tester,
      db,
      storage,
    ) async {
      final (project, parts, nets) = await setUpProject(db);
      final all = await parts.getPartsWithDetails(project.id);
      await nets.connectPins(all[0].pins.first.id, all[1].pins.first.id);

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );
      expect(find.byIcon(Icons.link_off), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.link_off).first);
      await settleApp(tester);

      expect(await nets.getNets(project.id), isEmpty);
      await settleApp(tester);
      expect(find.text('No nets yet'), findsOneWidget);
    });

    testAppWithStorage('a net can be labelled', (tester, db, storage) async {
      final (project, parts, nets) = await setUpProject(db);
      final all = await parts.getPartsWithDetails(project.id);
      final net = await nets.connectPins(
        all[0].pins.first.id,
        all[1].pins.first.id,
      );

      await pumpApp(
        tester,
        Scaffold(body: NetsPanel(project: project)),
        database: db,
        storage: storage,
      );

      // By key: the net's name also appears on each connected pin row.
      await tester.tap(find.byKey(ValueKey('net-${net.id}')));
      await settleApp(tester);

      await tester.enterText(find.byType(TextField), 'VCC');
      await tester.tap(find.text('SAVE'));
      await settleApp(tester);

      expect((await nets.getNets(project.id)).single.net.name, 'VCC');
      await settleApp(tester);
      expect(find.text('VCC'), findsWidgets);
    });
  });
}
