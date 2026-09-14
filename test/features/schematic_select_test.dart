import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

void main() {
  // "we also need a highlight tool to be added so we can highlight a section
  // and drag it or delete it"
  testAppWithStorage('a box sweeps parts up, and they move and delete as one', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Select');
    final parts = PartRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    final r3 = await parts.addPart(project.id, resistorSpec());
    for (final (part, x, y) in [
      (r1, 50.8, 50.8),
      (r2, 63.5, 50.8),
      (r3, 101.6, 88.9),
    ]) {
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

    await tester.tap(find.text('Select'));
    await settleApp(tester);

    Offset screen(Offset sheet) =>
        tester.getRect(find.byType(SchematicPanel)).topLeft +
        _painter(tester).viewport.toScreen(sheet);

    Future<void> drag(Offset fromSheet, Offset toSheet, {bool lift = true}) async {
      final from = screen(fromSheet);
      final to = screen(toSheet);
      final gesture = await tester.startGesture(from);
      // In steps: one jump reads as a fling and never becomes a drag.
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);
    }

    // Round R1 and R2, not R3.
    await drag(const Offset(42, 44), const Offset(70, 60));
    expect(find.text('2 selected'), findsOneWidget);

    Future<Map<String, Offset>> positions() async => {
      for (final p in await parts.getPartsWithDetails(project.id))
        p.part.reference: Offset(p.units.first.x, p.units.first.y),
    };
    final before = await positions();

    // Dragging either one takes both, and nothing is written mid-drag.
    final from = screen(const Offset(50.8, 50.8));
    final to = screen(const Offset(50.8 + 12.7, 50.8 + 12.7));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await positions(), before, reason: 'written before the finger lifted');
    await gesture.up();
    await settleApp(tester);

    final after = await positions();
    final shift = after['R1']! - before['R1']!;
    expect(shift.distance, greaterThan(5));
    expect(after['R2']! - before['R2']!, shift);
    expect(after['R3'], before['R3']);

    await tester.tap(find.text('Delete'));
    await settleApp(tester);
    expect(
      (await parts.getPartsWithDetails(project.id)).map((p) => p.part.reference),
      ['R3'],
    );

    await tester.tap(find.text('Undo'));
    await settleApp(tester);
    expect(await parts.getPartsWithDetails(project.id), hasLength(3));
  });

  // "when zoomed out, and I move say the MCU ... moving the component doesnt
  // feel smooth and its sort of laggy"
  testAppWithStorage('a dragged part follows live and is written once', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Drag');
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

    final canvas = tester.getRect(find.byType(SchematicPanel));
    final viewport = _painter(tester).viewport;
    final from = canvas.topLeft + viewport.toScreen(const Offset(50.8, 50.8));
    final gesture = await tester.startGesture(from);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Drawn where the finger is...
    final live = _painter(tester).scene.units.single.unit;
    expect(live.x, greaterThan(50.8));
    // ...but the database still has where it started.
    final stored = (await parts.getPartsWithDetails(project.id)).single;
    expect(stored.units.single.x, 50.8);

    await gesture.up();
    await settleApp(tester);
    final written = (await parts.getPartsWithDetails(project.id)).single;
    expect(written.units.single.x, live.x);
  });
}
