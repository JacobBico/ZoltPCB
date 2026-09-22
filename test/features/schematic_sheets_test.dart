import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/sheet_repository.dart';
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
      expect(painter.sheetBoxes.single.pins, ['VMID']);
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
}
