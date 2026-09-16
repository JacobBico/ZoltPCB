import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
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

    Future<void> drag(
      Offset fromSheet,
      Offset toSheet, {
      bool lift = true,
    }) async {
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
    expect(
      await positions(),
      before,
      reason: 'written before the finger lifted',
    );
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
      (await parts.getPartsWithDetails(
        project.id,
      )).map((p) => p.part.reference),
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

  // "when selecting a component ... 'select', 'check' should not be an option
  // there at all ... copy should also be removed ... 'hide label' should be a
  // check box inside the 'Value' menu ... unless the component is moved, then
  // only show the undo option ON the selection of the component"
  testAppWithStorage('a selected part offers only what applies to it', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Bar');
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

    Offset screen(Offset sheet) =>
        tester.getRect(find.byType(SchematicPanel)).topLeft +
        _painter(tester).viewport.toScreen(sheet);

    await tester.tapAt(screen(const Offset(50.8, 50.8)));
    await settleApp(tester);

    expect(find.text('R1'), findsOneWidget, reason: 'the part is selected');
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    for (final gone in ['Check', 'Select', 'Copy', 'Hide label', 'Redo']) {
      expect(
        find.text(gone),
        findsNothing,
        reason: '$gone belongs to the sheet',
      );
    }
    expect(find.text('Undo'), findsNothing, reason: 'nothing changed yet');

    // Turning it is a change to this selection, so undo joins the bar.
    await tester.tap(find.text('Rotate'));
    await settleApp(tester);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settleApp(tester);
    final back = (await parts.getPartsWithDetails(project.id)).single;
    expect(back.units.single.rotation, 0);
    expect(
      find.text('Undo'),
      findsNothing,
      reason: 'nothing left to take back',
    );
  });

  // "if I drag a wire out from a pin and I finish prematurely ... and I select
  // everything and decide to move it, the floating wire does not move with the
  // rest of the circuit" — and "the selection box should have a copy button"
  testAppWithStorage('a group carries its loose wires, and copies whole', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Group');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 63.5, y: 50.8, placed: true),
    );

    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;
    await nets.connectPins(pin(r1, '1'), pin(r2, '1'));

    // A wire dragged out of R1 pin 2 and finished in mid-air.
    const loose = [Offset(50.8, 54.61), Offset(50.8, 64.61)];
    await nets.addWire(
      projectId: project.id,
      points: loose,
      pinAId: pin(r1, '2'),
      netId: await nets.netForPin(project.id, pin(r1, '2')),
    );

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    Offset screen(Offset sheet) =>
        tester.getRect(find.byType(SchematicPanel)).topLeft +
        _painter(tester).viewport.toScreen(sheet);

    // Kept inside the canvas: with only these parts on it the sheet is
    // zoomed right in, so a sheet coordinate a little outside them is off
    // the screen entirely.
    Offset onCanvas(Offset at) {
      final canvas = tester.getRect(find.byType(SchematicPanel)).deflate(2);
      return Offset(
        at.dx.clamp(canvas.left, canvas.right),
        at.dy.clamp(canvas.top, canvas.bottom),
      );
    }

    Future<void> dragScreen(Offset from, Offset to) async {
      final gesture = await tester.startGesture(onCanvas(from));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(onCanvas(Offset.lerp(from, to, i / 10)!));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);
    }

    Future<void> drag(Offset fromSheet, Offset toSheet) =>
        dragScreen(screen(fromSheet), screen(toSheet));

    await tester.tap(find.text('Select'));
    await settleApp(tester);

    // A box round everything on the sheet, taken from where the parts have
    // actually been drawn.
    final scene = _painter(tester).scene;
    var area = scene.boundsOf(scene.units.first);
    for (final unit in scene.units) {
      area = area.expandToInclude(scene.boundsOf(unit));
    }
    await dragScreen(
      screen(area.topLeft) - const Offset(6, 6),
      screen(area.bottomRight) + const Offset(6, 6),
    );
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);

    await drag(const Offset(50.8, 50.8), const Offset(63.5, 63.5));
    final moved = (await nets.getWires(project.id)).single;
    final shift = moved.points.first - loose.first;
    expect(shift.distance, greaterThan(5), reason: 'the loose wire came along');
    expect(moved.points.last - loose.last, shift, reason: 'moved whole');

    // Copied, then put down where the sheet was last tapped.
    await tester.tap(find.text('Copy'));
    await settleApp(tester);
    // Tapping each part takes it back out of the group, leaving nothing
    // selected — where Paste lives.
    for (final unit in _painter(tester).scene.units.toList()) {
      await tester.tapAt(onCanvas(screen(Offset(unit.unit.x, unit.unit.y))));
      await settleApp(tester);
    }
    expect(find.text('Paste'), findsOneWidget);
    await tester.tap(find.text('Paste'));
    await settleApp(tester);

    final all = await parts.getPartsWithDetails(project.id);
    expect(all, hasLength(4), reason: 'both parts pasted');
    expect(
      await nets.getWires(project.id),
      hasLength(2),
      reason: 'the loose wire was pasted too',
    );
    final pasted = all.where((p) => !['R1', 'R2'].contains(p.part.reference));
    final netIds = {
      for (final part in pasted) await nets.netIdForPin(pin(part, '1')),
    };
    expect(netIds, hasLength(1), reason: 'the copies are wired to each other');
    expect(
      netIds.single,
      isNot(await nets.netIdForPin(pin(all.first, '1'))),
      reason: 'on a net of their own, not joined to the originals',
    );
  });
}
