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
  // "if we want to unwire that small section, then we unwire the entirety of
  // the wire, which makes no sense ... in KiCAD, you are just able to delete
  // that small piece of wire"
  testAppWithStorage('cutting one run parts the pins it joined', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Cut');
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
    // Out of the way, so the sheet is not zoomed in so far that the
    // wire ends up against the edge of the canvas.
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;

    final net = await nets.connectPins(pin(r1, '1'), pin(r2, '1'));
    await nets.addWire(
      projectId: project.id,
      points: const [
        Offset(50.8, 46.99),
        Offset(50.8, 40),
        Offset(63.5, 40),
        Offset(63.5, 46.99),
      ],
      pinAId: pin(r1, '1'),
      pinBId: pin(r2, '1'),
      netId: net.net.id,
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

    // The run across the top, between the two corners.
    await tester.tapAt(screen(const Offset(57.15, 40)));
    await settleApp(tester);
    expect(find.text('Cut'), findsOneWidget);
    // Only the run tapped is picked out; the rest of the net is left alone.
    expect(_painter(tester).selectedWireRun, 1);
    expect(_painter(tester).highlightedNetId, isNull);
    expect(find.text('Unwire'), findsOneWidget, reason: 'the net, if wanted');

    await tester.tap(find.text('Cut'));
    await settleApp(tester);

    expect(
      await nets.netIdForPin(pin(r1, '1')),
      isNot(await nets.netIdForPin(pin(r2, '1'))),
      reason: 'the gap means they are no longer joined',
    );
    final left = await nets.getWires(project.id);
    expect(left, hasLength(2), reason: 'both stubs stay where they were drawn');
    expect(left.every((w) => w.points.length == 2), isTrue);

    await tester.tap(find.text('Undo'));
    await settleApp(tester);
    expect(
      await nets.netIdForPin(pin(r1, '1')),
      await nets.netIdForPin(pin(r2, '1')),
      reason: 'joined again',
    );
    expect(await nets.getWires(project.id), hasLength(1));
  });

  // A wire left hanging can be dragged onto a pin to join it, while the end
  // already on a pin stays put: "the wire physics when moving around is
  // definitely more wonky now".
  testAppWithStorage(
    'a loose end dropped on a pin joins it, the pinned end stays put',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Drop');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      // Placed so its pin 1 is exactly where the loose end will be dragged.
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 63.5, y: 41.91, placed: true),
      );
      // Out of the way, so the sheet is not zoomed in so far that the
      // wire ends up against the edge of the canvas.
      final r3 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
      );
      String pin(PartWithDetails part, String number) =>
          part.pins.firstWhere((p) => p.number == number).id;

      // Drawn out of R1 pin 1 and left hanging.
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 46.99), Offset(50.8, 38.1)],
        pinAId: pin(r1, '1'),
        netId: await nets.netForPin(project.id, pin(r1, '1')),
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
      Offset onCanvas(Offset at) {
        final canvas = tester.getRect(find.byType(SchematicPanel)).deflate(2);
        return Offset(
          at.dx.clamp(canvas.left, canvas.right),
          at.dy.clamp(canvas.top, canvas.bottom),
        );
      }

      // Slide the whole run sideways, so its lower end lands on R2 pin 1.
      final from = screen(const Offset(50.8, 42.5));
      final to = screen(const Offset(63.5, 42.5));
      final gesture = await tester.startGesture(onCanvas(from));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(onCanvas(Offset.lerp(from, to, i / 10)!));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      final joined = await nets.netIdForPin(pin(r2, '1'));
      expect(joined, isNotNull, reason: 'the pin it was dropped on joined');
      expect(
        await nets.netIdForPin(pin(r1, '1')),
        joined,
        reason: 'the end on a pin stayed on it, and now they are one net',
      );
      final wire = (await nets.getWires(project.id)).single;
      expect(wire.pinAId, pin(r1, '1'), reason: 'still anchored where it was');
      expect(wire.pinBId, pin(r2, '1'), reason: 'and joined where it landed');
      expect(wire.points.first, const Offset(50.8, 46.99));
      expect(wire.points.last, const Offset(63.5, 38.1));
    },
  );

  // "at EACH INTERSECTION in the net, there is a separate wire basically.
  // And at each intersection, I should be able to drag another wire out"
  testAppWithStorage('a wire can be pulled out of a junction', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Branch');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    // Its pin 1 is where the branch will be dragged to.
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 63.5, y: 41.91, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;

    // A wire out of R1 pin 1, stopping in mid-air: its far end is a junction.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 46.99), Offset(50.8, 38.1)],
      pinAId: pin(r1, '1'),
      netId: await nets.netForPin(project.id, pin(r1, '1')),
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

    final from = screen(const Offset(50.8, 38.1));
    final to = screen(const Offset(63.5, 38.1));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    expect(wires, hasLength(2), reason: 'the original and the new branch');
    expect(
      await nets.netIdForPin(pin(r2, '1')),
      await nets.netIdForPin(pin(r1, '1')),
      reason: 'the pin it was dragged to joined the net',
    );
    final branch = wires.firstWhere((w) => w.pinBId == pin(r2, '1'));
    expect(branch.points.first, const Offset(50.8, 38.1));
    expect(branch.points.last, const Offset(63.5, 38.1));
  });
}
