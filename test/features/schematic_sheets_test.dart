import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/sheet_repository.dart';
import 'package:zolt/features/project/schematic_panel.dart';
import 'package:zolt/rendering/schematic_painter.dart';

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

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await settleApp(tester);
}

void main() {
  testAppWithStorage(
    'a part moved to a new sheet leaves a box with a pin for its net',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Sheets');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
      for (final (part, x) in [(r1, 50.8), (r2, 101.6)]) {
        await parts.updateUnitPlacement(
          part.units.first.copyWith(x: x, y: 50.8, placed: true),
        );
      }
      final vmid = await nets.connectPins(r1.pins[1].id, r2.pins[0].id);
      await nets.renameNet(vmid.net.id, 'VMID');

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );
      // No sheets yet: no path shown.
      expect(find.byKey(const ValueKey('sheet-path')), findsNothing);

      // Pick R2 and send it to a new sheet.
      await tester.longPressAt(_screen(tester, const Offset(101.6, 50.8)));
      await settleApp(tester);
      await _tapAction(tester, 'Sheet');
      await tester.tap(find.byKey(const ValueKey('move-to-new-sheet')));
      await settleApp(tester);
      await tester.enterText(find.byKey(const ValueKey('sheet-name')), 'Out');
      await tester.tap(find.byKey(const ValueKey('sheet-name-ok')));
      await settleApp(tester);

      final sheets = await SheetRepository(db).getAll(project.id);
      expect(sheets.single.name, 'Out');
      expect(sheets.single.fileName, 'out.kicad_sch');
      final moved = (await parts.getPartWithDetails(r2.part.id))!;
      expect(moved.units.single.sheetId, sheets.single.id);

      // On the top sheet: R1, the box, and VMID going into it.
      var painter = _painter(tester);
      expect(painter.scene.units.map((u) => u.part.reference), ['R1']);
      expect(painter.sheetBoxes.single.pins.map((p) => p.name), ['VMID']);
      expect(painter.offSheetLabels.single.name, 'VMID');
      expect(painter.offSheetLabels.single.hierarchical, isFalse);
      expect(find.byKey(const ValueKey('sheet-path')), findsOneWidget);

      // Into the sheet: R2, and VMID leaving it by a hierarchical label.
      await tester.tapAt(_screen(tester, painter.sheetBoxes.single.box.center));
      await settleApp(tester);
      await _tapAction(tester, 'Open');
      painter = _painter(tester);
      expect(painter.scene.units.map((u) => u.part.reference), ['R2']);
      expect(painter.offSheetLabels.single.hierarchical, isTrue);
      expect(painter.sheetBoxes, isEmpty);

      // Back up by the path, and the move undone puts R2 back on top.
      await tester.tap(find.text('Top'));
      await settleApp(tester);
      expect(_painter(tester).scene.units, hasLength(1));
      await _tapAction(tester, 'Undo');
      await _tapAction(tester, 'Undo');
      expect(
        (await parts.getPartWithDetails(r2.part.id))!.units.single.sheetId,
        isNull,
      );
    },
  );

  testAppWithStorage(
    'a wire joins a sheet\'s pin to a part, dragged either way',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Sheets');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
      final r3 = await parts.addPart(project.id, resistorSpec(value: '1k'));
      final sheet = await SheetRepository(
        db,
      ).add(projectId: project.id, name: 'Out', at: const Offset(66.04, 30.48));
      // R1 and R3 on the top sheet, R2 inside Out: VMID goes into the box.
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 40.64, y: 50.8, placed: true),
      );
      await parts.updateUnitPlacement(
        r3.units.first.copyWith(x: 50.8, y: 38.1, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(
          x: 50.8,
          y: 50.8,
          placed: true,
          sheetId: sheet.id,
        ),
      );
      final vmid = await nets.connectPins(r1.pins[1].id, r2.pins[0].id);
      await nets.renameNet(vmid.net.id, 'VMID');

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );
      final boxPin = _painter(tester).sheetBoxes.single.pins.single;
      expect(boxPin.name, 'VMID');

      Future<void> drag(Offset fromSheet, Offset toSheet) async {
        final a = _screen(tester, fromSheet);
        final b = _screen(tester, toSheet);
        final gesture = await tester.startGesture(a);
        for (var i = 1; i <= 10; i++) {
          await gesture.moveTo(Offset.lerp(a, b, i / 10)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await settleApp(tester);
      }

      Future<Set<String>> onVmid() async => {
        for (final net in await nets.getNets(project.id))
          if (net.endpoints.any((e) => e.pin.id == r2.pins[0].id))
            for (final e in net.endpoints) e.pin.id,
      };
      bool near(Offset a, Offset b) => (a - b).distance < 1e-3;
      final r3Pins = _painter(
        tester,
      ).scene.pins.where((p) => p.partId == r3.part.id).toList();
      final top = r3Pins.reduce(
        (a, b) => a.sheetPosition.dy < b.sheetPosition.dy ? a : b,
      );
      final bottom = r3Pins.firstWhere((p) => p != top);

      // From R3's pin onto the box's: R3 is on VMID, by a wire to the box.
      await drag(top.sheetPosition, boxPin.at);
      expect(await onVmid(), contains(top.pin.id));
      var wires = await nets.getWires(project.id);
      expect(wires, hasLength(1));
      expect(near(wires.single.points.first, top.sheetPosition), isTrue);
      expect(near(wires.single.points.last, boxPin.at), isTrue);

      // Undone, both are gone.
      await _tapAction(tester, 'Undo');
      expect(await onVmid(), isNot(contains(top.pin.id)));
      expect(await nets.getWires(project.id), isEmpty);

      // Out of the box's pin onto R3's other one: the same, the other way.
      await drag(boxPin.at, bottom.sheetPosition);
      expect(await onVmid(), contains(bottom.pin.id));
      wires = await nets.getWires(project.id);
      expect(wires, hasLength(1));
      expect(near(wires.single.points.first, boxPin.at), isTrue);
      expect(near(wires.single.points.last, bottom.sheetPosition), isTrue);
      // Still one pin on the box, carrying the net it carried.
      expect(_painter(tester).sheetBoxes.single.pins.single.name, 'VMID');
    },
  );
}
