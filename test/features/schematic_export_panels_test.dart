import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/providers.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/features/project/component_sidebar.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/features/project/export_panel.dart';
import 'package:hintpcb/features/project/nets_panel.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  _placementTests();

  group('schematic canvas', () {
    testAppWithStorage('explains itself when the sheet is empty', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Empty');

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.text('Nothing on the sheet yet'), findsOneWidget);
    });

    testAppWithStorage('draws the sheet once components are placed', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Sheet');
      final parts = PartRepository(db);
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, dualOpampSpec());

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.byType(CustomPaint), findsWidgets);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SchematicPainter>()
          .single;

      // The resistor plus both units of the opamp.
      expect(painter.scene.units, hasLength(3));
      expect(painter.scene.pins, isNotEmpty);
      // Nothing else over the drawing: the strip of instructions that used
      // to sit across the top is gone, and the sheet is the whole canvas.
      expect(find.textContaining('drag to move'), findsNothing);
    });

    testAppWithStorage('tapping a pin starts a connection', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Connect');
      final parts = PartRepository(db);
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final painterFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SchematicPainter,
      );
      final painter =
          (tester.widget<CustomPaint>(painterFinder.first).painter
              as SchematicPainter);

      // Tap where the canvas actually drew the first pin.
      final pin = painter.scene.pins.first;
      final screen = painter.viewport.toScreen(pin.sheetPosition);
      await tester.tapAt(tester.getTopLeft(painterFinder.first) + screen);
      await settleApp(tester);

      // The action bar takes over from the old status strip: it names the
      // pin being connected from and offers the way out.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      );
      expect(container.read(pendingPinProvider), pin.id);
      expect(find.text(pin.label), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('export', () {
    testAppWithStorage('says there is nothing to export yet', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Empty');

      await pumpApp(
        tester,
        Scaffold(body: ExportPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.text('Nothing to export yet'), findsOneWidget);
    });

    testAppWithStorage('summarises what will be written', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Line Driver');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      await pumpApp(
        tester,
        Scaffold(body: ExportPanel(project: project)),
        database: db,
        storage: storage,
      );

      expect(find.text('Line_Driver.kicad_sch'), findsOneWidget);
      expect(find.text('Line_Driver-bom.csv'), findsOneWidget);
      expect(find.text('WRITE FILES'), findsOneWidget);
      expect(find.text('SHARE'), findsOneWidget);
      expect(find.textContaining('2 connected'), findsOneWidget);
    });

    testAppWithStorage('warns about a missing library before exporting', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Warned');
      await PartRepository(db).addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: ExportPanel(project: project)),
        database: db,
        storage: storage,
      );

      // Panel headings render in small caps.
      expect(find.text('WORTH CHECKING FIRST'), findsOneWidget);
      expect(
        find.textContaining('Library missing for Device:R'),
        findsOneWidget,
      );
    });
  });

  group('shared connection state', () {
    testAppWithStorage(
      'a connection started on the canvas continues in the net list',
      (tester, db, storage) async {
        final project = await ProjectRepository(db).create(name: 'Shared');
        final parts = PartRepository(db);
        final added = await parts.addPart(project.id, resistorSpec());

        await pumpApp(
          tester,
          Scaffold(body: NetsPanel(project: project)),
          database: db,
          storage: storage,
        );

        await tester.tap(find.byKey(ValueKey('pin-${added.pins.first.id}')));
        await settleApp(tester);

        // The pending pin lives in one provider, so both views agree about
        // which connection is half-made.
        expect(find.textContaining('Connecting from R1'), findsOneWidget);
      },
    );
  });
}

void _placementTests() {
  group('the component picker opens on the parts most circuits use', () {
    testAppWithStorage('common parts are one tap each, drawn as symbols', (
      tester,
      db,
      storage,
    ) async {
      await SymbolLibraryRepository(
        db,
        storage,
      ).import(fileName: 'Device.kicad_sym', bytes: libraryBytes());
      final project = await ProjectRepository(db).create(name: 'Quick');

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );
      ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      ).read(componentPickerOpenProvider.notifier).set(true);
      await settleApp(tester);

      // The library has a resistor and a capacitor, and nothing else on
      // the list — so those two are offered and nothing else is.
      expect(find.byKey(const ValueKey('quick-Device:R')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-Device:C')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-Device:LED')), findsNothing);
      expect(find.text('POWER AND GROUND'), findsNothing);

      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('quick-Device:R')),
        );
        await tester.tap(find.byKey(const ValueKey('quick-Device:R')));
        await settleApp(tester);
      }

      final parts = await PartRepository(db).getPartsWithDetails(project.id);
      expect(parts.map((p) => p.part.reference), ['R1', 'R2']);
      // And the project's own parts are offered again.
      // (Above the tiles, which the list has scrolled down to.)
      expect(find.text('IN THIS PROJECT', skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(const ValueKey('used-Device:R'), skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('reported: an added part must land where it can be seen', () {
    // Adding a second component dealt it into a fixed grid 38 mm from the
    // first, which on a phone put it off the edge of the screen: it had
    // been added, and there was no sign of it.
    testAppWithStorage('two parts added from the list are both on screen', (
      tester,
      db,
      storage,
    ) async {
      await SymbolLibraryRepository(
        db,
        storage,
      ).import(fileName: 'Device.kicad_sym', bytes: libraryBytes());
      final project = await ProjectRepository(db).create(name: 'Seen');
      // Start from one part so the canvas exists and is framed on it.
      await PartRepository(db).addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        ProviderScope(
          overrides: const [],
          child: Scaffold(body: SchematicPanel(project: project)),
        ),
        database: db,
        storage: storage,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      );
      container.read(componentPickerOpenProvider.notifier).set(true);
      await settleApp(tester);

      Future<void> addFirstResult(String query) async {
        await tester.enterText(
          find.descendant(
            of: find.byType(ComponentSidebar),
            matching: find.byType(TextField),
          ),
          query,
        );
        await settleApp(tester);
        await tester.tap(find.byIcon(Icons.add).last);
        await settleApp(tester);
      }

      await addFirstResult('resistor');
      await addFirstResult('capacitor');

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SchematicPainter>()
          .single;
      final scene = painter.scene;
      expect(scene.units, hasLength(3));

      // Every unit is inside the part of the sheet actually on screen.
      final canvas = tester.getRect(find.byType(SchematicPanel));
      final viewport = painter.viewport;
      final visible = Rect.fromPoints(
        viewport.toSheet(Offset.zero),
        viewport.toSheet(Offset(canvas.width, canvas.height)),
      );
      for (final unit in scene.units) {
        final bounds = scene.boundsOf(unit);
        expect(
          visible.contains(bounds.center),
          isTrue,
          reason: '${unit.part.reference} was placed off screen at $bounds',
        );
      }

      // And none of them is sitting on another.
      final rects = [for (final unit in scene.units) scene.boundsOf(unit)];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason:
                '${scene.units[i].part.reference} overlaps '
                '${scene.units[j].part.reference}',
          );
        }
      }
    });
  });
}
