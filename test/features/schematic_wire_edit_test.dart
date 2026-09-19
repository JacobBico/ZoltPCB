import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/app/appearance.dart';
import 'package:hintpcb/domain/geometry/polyline_wiring.dart';
import 'package:hintpcb/domain/geometry/segment_wiring.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

/// Whether any wire has an end exactly at [at].
bool _endsAt(List<SchematicWire> wires, Offset at) => wires.any(
  (w) =>
      (w.points.first - at).distance < 0.01 ||
      (w.points.last - at).distance < 0.01,
);

/// Whether [at] lies anywhere on the drawing.
bool _covers(List<SchematicWire> wires, Offset at) {
  for (final wire in wires) {
    for (var i = 0; i < wire.points.length - 1; i++) {
      if (SegmentWiring.distanceToSegment(
            at,
            wire.points[i],
            wire.points[i + 1],
          ) <
          0.01) {
        return true;
      }
    }
  }
  return false;
}

/// Whether the drawing is all in one piece — nothing left behind. Wires
/// meet by ending on one another and by crossing, which is what the wiring
/// rules count too.
bool _allJoined(List<SchematicWire> wires) =>
    PolylineWiring.allJoined([for (final w in wires) w.points]);

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
      final wires = await nets.getWires(project.id);
      expect(
        _endsAt(wires, const Offset(50.8, 46.99)),
        isTrue,
        reason: 'still reaches the pin it was drawn from',
      );
      expect(
        _endsAt(wires, const Offset(63.5, 38.1)),
        isTrue,
        reason: 'and reaches the pin it landed on',
      );
      expect(_allJoined(wires), isTrue, reason: 'all in one piece');
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

  // "when drag downwards it SHOULD also drag down the wire that its attached
  // to right? Not just the individual wire itself, it is like directly
  // disconnecting from the circuit"
  testAppWithStorage('a dragged wire takes the wire it is joined to with it', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Follow');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;

    final netId = await nets.netForPin(project.id, pin(r1, '1'));
    // Up out of the pin, then along: two wires meeting at a corner.
    final up = await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 46.99), Offset(50.8, 60.96)],
      pinAId: pin(r1, '1'),
      netId: netId,
    );
    final along = await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 60.96), Offset(63.5, 60.96)],
      netId: netId,
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

    // Drag the horizontal wire down.
    final from = screen(const Offset(57.15, 60.96));
    final to = screen(const Offset(57.15, 68.58));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final after = {
      for (final wire in await nets.getWires(project.id)) wire.id: wire,
    };
    expect(
      after[along!.id]!.points.first.dy,
      closeTo(68.58, 0.01),
      reason: 'the wire dragged moved',
    );
    expect(
      after[up!.id]!.points.last,
      after[along.id]!.points.first,
      reason: 'and the wire it was joined to came with it',
    );
    expect(
      after[up.id]!.points.first,
      const Offset(50.8, 46.99),
      reason: 'while its pinned end stayed on the pin',
    );
  });

  // "another junction point be created because it is essentially INSIDE the
  // already existing vertical wire, but this is misleading"
  testAppWithStorage('a branch drawn back along its own wire is not drawn', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Inside');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;

    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 46.99), Offset(50.8, 66.04)],
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

    // From the loose end, back up inside the wire itself.
    final from = screen(const Offset(50.8, 66.04));
    final to = screen(const Offset(50.8, 58.42));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    expect(
      await nets.getWires(project.id),
      hasLength(1),
      reason: 'nothing drawn on top of what is already there',
    );
    expect(find.textContaining('Already wired'), findsOneWidget);
  });

  // "I still move the wire and it clearly shows that the other wire was left
  // behind even though that is NOT how it should be"
  // "since they are junctions, they shouldnt be moving" — the place they
  // meet slides along the branch instead, and they stay joined.
  testAppWithStorage('a wire slid along a branch hangs from it', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Tee');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '1').id;
    final netId = await nets.netForPin(project.id, pin);

    // A wire down from the pin, with another meeting it half way along.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 46.99), Offset(50.8, 71.12)],
      pinAId: pin,
      netId: netId,
    );
    final branch = await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 60.96), Offset(63.5, 60.96)],
      netId: netId,
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

    // Drag the wire they both belong to sideways.
    final from = screen(const Offset(50.8, 66.04));
    final to = screen(const Offset(58.42, 66.04));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    // The branch is all still drawn where it was — split now where the
    // moved wire hangs from it, which draws the same thing.
    for (final at in const [
      Offset(51.5, 60.96),
      Offset(55, 60.96),
      Offset(62, 60.96),
    ]) {
      expect(_covers(wires, at), isTrue, reason: 'the branch moved at $at');
    }
    expect(branch, isNotNull);
    expect(
      _covers(wires, const Offset(58.42, 66.04)),
      isTrue,
      reason: 'the wire went where it was dragged',
    );
    expect(
      _covers(wires, const Offset(50.8, 66.04)),
      isFalse,
      reason: 'and left nothing behind',
    );
    final shapes = [for (final w in wires) w.points.toString()];
    expect(shapes.toSet().length, shapes.length);
    expect(
      _allJoined(wires),
      isTrue,
      reason: 'and they are still joined, now crossing rather than meeting',
    );
  });

  // "if there is a wire just floating and I decide to extend it ... now this
  // straight piece of wire is seen as two pieces of wire, when it
  // realistically is just one"
  testAppWithStorage('carrying a wire straight on makes it one longer wire', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Extend');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '1').id;
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(60.96, 60.96), Offset(71.12, 60.96)],
      netId: await nets.netForPin(project.id, pin),
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

    // Out of its end, carrying straight on.
    final from = screen(const Offset(71.12, 60.96));
    final to = screen(const Offset(81.28, 60.96));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    expect(wires, hasLength(1), reason: 'one wire, not two in a line');
    expect(wires.single.points, [
      const Offset(60.96, 60.96),
      const Offset(81.28, 60.96),
    ]);
  });

  // The whole thing as it is actually done: draw a wire out of a pin, pull a
  // branch out of its end, then drag that branch. "it SHOULD also drag down
  // the wire that its attached to".
  testAppWithStorage('wires drawn and branched stay joined when dragged', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Drawn');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
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

    Future<void> drag(Offset fromSheet, Offset toSheet) async {
      final from = screen(fromSheet);
      final to = screen(toSheet);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);
    }

    // Out of R1 pin 2, downwards, finished in mid-air.
    await drag(const Offset(50.8, 54.61), const Offset(50.8, 66.04));
    await tester.tap(find.text('Finish'));
    await settleApp(tester);

    // A branch out of its end, to the right.
    await drag(const Offset(50.8, 66.04), const Offset(63.5, 66.04));
    expect(await nets.getWires(project.id), hasLength(2));

    // Now drag that branch down: the wire it came out of follows.
    await drag(const Offset(57.15, 66.04), const Offset(57.15, 73.66));

    final wires = await nets.getWires(project.id);
    final down = wires.firstWhere((w) => w.pinAId != null);
    final across = wires.firstWhere((w) => w.pinAId == null);
    expect(
      across.points.first.dy,
      closeTo(73.66, 0.01),
      reason: 'the branch moved',
    );
    expect(
      down.points.last,
      across.points.first,
      reason: 'and the wire it hangs off came with it',
    );
    expect(
      down.points.first,
      const Offset(50.8, 54.61),
      reason: 'still on the pin it was drawn from',
    );
  });

  // A wire resting part-way along another, dragged clear off the end of it.
  testAppWithStorage(
    'a wire dragged off the one it rested on keeps the junction',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Off');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
      );
      final pin = r1.pins.firstWhere((p) => p.number == '1').id;
      final netId = await nets.netForPin(project.id, pin);
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 46.99), Offset(50.8, 66.04)],
        pinAId: pin,
        netId: netId,
      );
      // Meets it half way along, not at its end.
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 60.96), Offset(63.5, 60.96)],
        netId: netId,
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

      // Down past the end of the wire it was resting on.
      final from = screen(const Offset(57.15, 60.96));
      final to = screen(const Offset(57.15, 71.12));
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      // "if there is a junction between two wires, the junction should NOT
      // move when one wire on either side is being moved"
      final wires = await nets.getWires(project.id);
      expect(
        _covers(wires, const Offset(57.15, 71.12)),
        isTrue,
        reason: 'the wire went where it was dragged',
      );
      expect(
        _covers(wires, const Offset(50.8, 60.96)),
        isTrue,
        reason: 'and still runs through where the junction was',
      );
      expect(
        _covers(wires, const Offset(57.15, 60.96)),
        isFalse,
        reason: 'the run it was dragged off is gone',
      );
      expect(
        _endsAt(wires, const Offset(50.8, 46.99)),
        isTrue,
        reason: 'the wire it rested on is still on its pin',
      );
      expect(_allJoined(wires), isTrue);
      // The stub under the junction lay along the new corner: it was
      // folded in rather than left as a second wire in the same place.
      final shapes = [for (final w in wires) w.points.toString()];
      expect(shapes.toSet().length, shapes.length);
    },
  );

  // "if I drag this vertical wire to the right, it then extends our
  // original floating wire (as expected). However! If I drag the same wire
  // back, our original wire that we have just extended does not move back"
  testAppWithStorage(
    'a wire on the end of another shortens it when dragged back',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Shorten');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
      );
      final pin = r1.pins.firstWhere((p) => p.number == '2').id;
      final netId = await nets.netForPin(project.id, pin);

      // Down from the pin, along to the right, and an upright on its end.
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 54.61), Offset(50.8, 66.04)],
        pinAId: pin,
        netId: netId,
      );
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 66.04), Offset(76.2, 66.04)],
        netId: netId,
      );
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(76.2, 66.04), Offset(76.2, 58.42)],
        netId: netId,
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

      // Drag the upright back to the left.
      final from = screen(const Offset(76.2, 62.23));
      final to = screen(const Offset(63.5, 62.23));
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      final wires = await nets.getWires(project.id);
      expect(
        _covers(wires, const Offset(63.5, 62.23)),
        isTrue,
        reason: 'the upright moved back: $wires',
      );
      expect(
        _covers(wires, const Offset(70, 66.04)),
        isFalse,
        reason: 'the wire it sits on the end of came back too: $wires',
      );
      expect(
        _endsAt(wires, const Offset(50.8, 54.61)),
        isTrue,
        reason: 'still on the pin it was drawn from',
      );
      expect(_allJoined(wires), isTrue, reason: 'all in one piece');
    },
  );

  // "when I put two wires together, they still ACT as two separate wires,
  // when they should be one long wire"
  testAppWithStorage('two wires dragged into line become one', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Join');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '1').id;
    final netId = await nets.netForPin(project.id, pin);

    // Two loose wires in a line, one a couple of grid squares below.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(60.96, 60.96), Offset(71.12, 60.96)],
      netId: netId,
    );
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(71.12, 71.12), Offset(81.28, 71.12)],
      netId: netId,
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

    // Bring the lower one up into line with the upper one.
    final from = screen(const Offset(76.2, 71.12));
    final to = screen(const Offset(76.2, 60.96));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 16; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 16)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    expect(wires, hasLength(1), reason: 'one wire, end to end in a line');
    expect(wires.single.points, [
      const Offset(60.96, 60.96),
      const Offset(81.28, 60.96),
    ]);
  });

  // The segment model on the case from the screenshots: a wire meeting the
  // corner of another, dragged away. "it must drag a wire along side it"
  testAppWithStorage('in the segment model nothing is left behind', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Segments');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '2').id;
    final netId = await nets.netForPin(project.id, pin);

    // Down out of the pin, then along, then a wire up from that corner.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 54.61), Offset(50.8, 66.04)],
      pinAId: pin,
      netId: netId,
    );
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 66.04), Offset(63.5, 66.04)],
      netId: netId,
    );
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 66.04), Offset(50.8, 60.96)],
      netId: netId,
    );

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
      wiring: WiringModel.segments,
    );

    Offset screen(Offset sheet) =>
        tester.getRect(find.byType(SchematicPanel)).topLeft +
        _painter(tester).viewport.toScreen(sheet);

    final from = screen(const Offset(57.15, 66.04));
    final to = screen(const Offset(57.15, 76.2));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    expect(
      _covers(wires, const Offset(57.15, 76.2)),
      isTrue,
      reason: 'the piece dragged went where it was dragged',
    );
    expect(_allJoined(wires), isTrue, reason: 'and the net is in one piece');
    expect(
      _endsAt(wires, const Offset(50.8, 54.61)),
      isTrue,
      reason: 'still on the pin it came from',
    );
    expect(
      wires.every((w) => w.points.length == 2),
      isTrue,
      reason: 'every wire is one straight piece',
    );
  });

  // The same shapes the rules are put through in bulk, driven through the
  // canvas, so the plumbing is covered as well as the geometry.
  for (final drag in const [
    (
      'the upright of an L, sideways',
      Offset(50.8, 60.96),
      Offset(58.42, 60.96),
    ),
    ('the arm of an L, downwards', Offset(57.15, 66.04), Offset(57.15, 73.66)),
    ('the arm of an L, upwards', Offset(57.15, 66.04), Offset(57.15, 58.42)),
  ]) {
    testAppWithStorage('dragging ${drag.$1} keeps the net in one piece', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Joined');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
      );
      final pin = r1.pins.firstWhere((p) => p.number == '2').id;
      final netId = await nets.netForPin(project.id, pin);

      // Down from the pin, along, and a branch back up from the corner.
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 54.61), Offset(50.8, 66.04)],
        pinAId: pin,
        netId: netId,
      );
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 66.04), Offset(63.5, 66.04)],
        netId: netId,
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

      final from = screen(drag.$2);
      final to = screen(drag.$3);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      final wires = await nets.getWires(project.id);
      expect(_allJoined(wires), isTrue, reason: 'left behind: $wires');
      expect(
        _endsAt(wires, const Offset(50.8, 54.61)),
        isTrue,
        reason: 'still on the pin it was drawn from',
      );
      for (final wire in wires) {
        expect(
          PolylineWiring.square(wire.points),
          isTrue,
          reason: 'a run went diagonal: ${wire.points}',
        );
      }
    });
  }

  // Moving a part drags its wire along by the pin. Anything joined to that
  // wire has to come too, or the drawing comes apart the same way.
  testAppWithStorage('moving a part brings the wires joined to its wire', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Part move');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '2').id;
    final netId = await nets.netForPin(project.id, pin);

    // Down out of the pin, with a branch off its end.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 54.61), Offset(50.8, 66.04)],
      pinAId: pin,
      netId: netId,
    );
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 66.04), Offset(63.5, 66.04)],
      netId: netId,
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

    // Drag the part itself sideways.
    final from = screen(const Offset(50.8, 50.8));
    final to = screen(const Offset(63.5, 50.8));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final moved = (await parts.getPartsWithDetails(
      project.id,
    )).firstWhere((p) => p.part.id == r1.part.id);
    expect(moved.units.first.x, greaterThan(50.8), reason: 'the part moved');

    final wires = await nets.getWires(project.id);
    expect(_allJoined(wires), isTrue, reason: 'left behind: $wires');
  });

  // "when we move this horizontal wire downwards, our vertical line ... moves
  // down with it ... they act like two separate wires when they in reality
  // should be one"
  testAppWithStorage('a step flattened out becomes one wire, not three', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Step');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '2').id;
    final netId = await nets.netForPin(project.id, pin);

    // Out of the pin, along, up a step, and along again.
    for (final points in const [
      [Offset(50.8, 54.61), Offset(50.8, 60.96)],
      [Offset(50.8, 60.96), Offset(71.12, 60.96)],
      [Offset(71.12, 60.96), Offset(71.12, 53.34)],
      [Offset(71.12, 53.34), Offset(88.9, 53.34)],
    ]) {
      await nets.addWire(
        projectId: project.id,
        points: points,
        pinAId: points.first == const Offset(50.8, 54.61) ? pin : null,
        netId: netId,
      );
    }

    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );

    Offset screen(Offset sheet) =>
        tester.getRect(find.byType(SchematicPanel)).topLeft +
        _painter(tester).viewport.toScreen(sheet);

    // Drag the top run down until the step is flat.
    final from = screen(const Offset(80.01, 53.34));
    final to = screen(const Offset(80.01, 60.96));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    for (final wire in wires) {
      var length = 0.0;
      for (var i = 0; i < wire.points.length - 1; i++) {
        length += (wire.points[i + 1] - wire.points[i]).distance;
      }
      expect(
        length,
        greaterThan(0.01),
        reason: 'a wire shrunk to nothing was left lying there: $wires',
      );
    }

    // One wire along the whole line, not one either side of where the step
    // used to be.
    final along = [
      for (final wire in wires)
        if (wire.points.every((p) => (p.dy - 60.96).abs() < 0.01)) wire,
    ];
    expect(
      along,
      hasLength(1),
      reason: 'the flattened step should read as one wire: $wires',
    );
    expect(along.single.points.first.dx, closeTo(50.8, 0.01));
    expect(along.single.points.last.dx, closeTo(88.9, 0.01));
    expect(_allJoined(wires), isTrue, reason: 'all in one piece');
  });

  // "if there is a junction between two wires, the junction should NOT move
  // when one wire on either side is being moved up or down, left or right,
  // so basically, two wires should NOT be one long wire if they are
  // connected by a junction"
  for (final (which, grab) in const [
    ('the left wire', Offset(57.15, 60.96)),
    ('the right wire', Offset(76.2, 60.96)),
    ('the branch', Offset(66.04, 69.85)),
  ]) {
    for (final push in const [
      Offset(0, -7.62),
      Offset(0, 7.62),
      Offset(-7.62, 0),
      Offset(7.62, 0),
    ]) {
      testAppWithStorage('$which moved by $push leaves the junction and the '
          'other wires where they are', (tester, db, storage) async {
        final project = await ProjectRepository(db).create(name: 'Junction');
        final parts = PartRepository(db);
        final nets = NetRepository(db);
        final r1 = await parts.addPart(project.id, resistorSpec());
        await parts.updateUnitPlacement(
          r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
        );
        final r3 = await parts.addPart(project.id, resistorSpec());
        await parts.updateUnitPlacement(
          r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
        );
        final pin = r1.pins.firstWhere((p) => p.number == '2').id;
        final netId = await nets.netForPin(project.id, pin);
        // Stored the old way — one wire straight through the junction —
        // which the sheet splits as soon as it opens.
        await nets.addWire(
          projectId: project.id,
          netId: netId,
          points: const [
            Offset(50.8, 54.61),
            Offset(50.8, 60.96),
            Offset(86.36, 60.96),
          ],
          pinAId: pin,
        );
        await nets.addWire(
          projectId: project.id,
          netId: netId,
          points: const [Offset(66.04, 60.96), Offset(66.04, 76.2)],
        );

        await pumpApp(
          tester,
          Scaffold(body: SchematicPanel(project: project)),
          database: db,
          storage: storage,
        );
        final opened = await nets.getWires(project.id);
        expect(opened, hasLength(3), reason: 'split at the junction');

        const junction = Offset(66.04, 60.96);
        Offset screen(Offset sheet) =>
            tester.getRect(find.byType(SchematicPanel)).topLeft +
            _painter(tester).viewport.toScreen(sheet);
        final from = screen(grab);
        final to = screen(grab + push);
        final gesture = await tester.startGesture(from);
        for (var i = 1; i <= 12; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await settleApp(tester);

        final after = await nets.getWires(project.id);
        expect(_allJoined(after), isTrue, reason: 'still one net');
        // The junction is where it was.
        expect(_covers(after, junction), isTrue);
        // The two wires not taken hold of did not move: every point of
        // theirs is still drawn.
        final untouched = {
          'the left wire': [
            const Offset(76.2, 60.96),
            const Offset(66.04, 69.85),
          ],
          'the right wire': [
            const Offset(57.15, 60.96),
            const Offset(66.04, 69.85),
          ],
          'the branch': [const Offset(57.15, 60.96), const Offset(76.2, 60.96)],
        }[which]!;
        for (final point in untouched) {
          expect(
            _covers(after, point),
            isTrue,
            reason: 'a wire that was not dragged moved: nothing at $point',
          );
        }
        // Nothing drawn twice.
        final shapes = [for (final w in after) w.points.toString()];
        expect(shapes.toSet().length, shapes.length);
      });
    }
  }

  // "I was moving the wires around and suddenly I cannot move the wires
  // anymore". A net whose drawing had come apart — a wire cut loose, left
  // on the net — refused every drag, because no drag could put it back in
  // one piece.
  testAppWithStorage('a net in two pieces can still be dragged', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Pieces');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
    );
    final pin = r1.pins.firstWhere((p) => p.number == '2').id;
    final netId = await nets.netForPin(project.id, pin);
    await nets.addWire(
      projectId: project.id,
      netId: netId,
      points: const [Offset(50.8, 54.61), Offset(50.8, 60.96)],
      pinAId: pin,
    );
    await nets.addWire(
      projectId: project.id,
      netId: netId,
      points: const [Offset(63.5, 71.12), Offset(88.9, 71.12)],
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
    Future<void> drag(Offset from, Offset to) async {
      final a = screen(from);
      final b = screen(to);
      final gesture = await tester.startGesture(a);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(a, b, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);
    }

    await drag(const Offset(76.2, 71.12), const Offset(76.2, 78.74));
    var wires = await nets.getWires(project.id);
    expect(_covers(wires, const Offset(76.2, 78.74)), isTrue);
    expect(_covers(wires, const Offset(76.2, 71.12)), isFalse);

    // And again, the way it went wrong: a second drag after the first.
    await drag(const Offset(76.2, 78.74), const Offset(76.2, 83.82));
    wires = await nets.getWires(project.id);
    expect(_covers(wires, const Offset(76.2, 83.82)), isTrue);
  });

  // "if I extend a wire vertically upwards from my capacitor pin ... move
  // this wire horizontally across another long wire ... it seems to drag a
  // new wire with it from the capacitor pin, this wire then overlaps with
  // existing wires"
  testAppWithStorage('a wire slid along another from the same pin draws no '
      'second wire over it', (tester, db, storage) async {
    final project = await ProjectRepository(db).create(name: 'Retrace');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final c1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      c1.units.first.copyWith(x: 50.8, y: 62.23, placed: true),
    );
    final r3 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r3.units.first.copyWith(x: 101.6, y: 30.48, placed: true),
    );
    final pin = c1.pins.firstWhere((p) => p.number == '1').id;
    final netId = await nets.netForPin(project.id, pin);
    await nets.addWire(
      projectId: project.id,
      netId: netId,
      points: const [Offset(50.8, 58.42), Offset(88.9, 58.42)],
      pinAId: pin,
    );
    final up = await nets.addWire(
      projectId: project.id,
      netId: netId,
      points: const [Offset(50.8, 58.42), Offset(50.8, 40.64)],
      pinAId: pin,
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

    // While the finger is down, nothing is drawn along the horizontal
    // wire but the horizontal wire itself.
    final from = screen(const Offset(50.8, 48.26));
    final to = screen(const Offset(63.5, 48.26));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    int drawnOver(List<List<Offset>> shapes, Offset at) =>
        shapes.where((s) => PolylineWiring.covers(s, at)).length;
    final live = [for (final w in _painter(tester).scene.wires) w.points];
    expect(
      drawnOver(live, const Offset(57.15, 58.42)),
      1,
      reason: 'a second wire was drawn along the first while dragging',
    );
    await gesture.up();
    await settleApp(tester);

    final wires = await nets.getWires(project.id);
    final shapes = [for (final w in wires) w.points];
    expect(_covers(wires, const Offset(63.5, 45)), isTrue);
    expect(_covers(wires, const Offset(50.8, 45)), isFalse);
    for (final at in const [
      Offset(52, 58.42),
      Offset(57.15, 58.42),
      Offset(62, 58.42),
      Offset(70, 58.42),
    ]) {
      expect(drawnOver(shapes, at), 1, reason: 'drawn twice at $at');
    }
    expect(_allJoined(wires), isTrue);
    expect(
      (await nets.getNets(project.id)).single.endpoints.map((e) => e.pin.id),
      contains(pin),
      reason: 'the capacitor is still on the net',
    );

    // Taking the upright away leaves only the horizontal wire: nothing was
    // hiding underneath it.
    final upright = wires.firstWhere(
      (w) => PolylineWiring.covers(w.points, const Offset(63.5, 45)),
    );
    await nets.deleteWire(upright.id);
    await settleApp(tester);
    final left = await nets.getWires(project.id);
    for (final at in const [Offset(57.15, 58.42), Offset(70, 58.42)]) {
      expect(drawnOver([for (final w in left) w.points], at), 1);
    }
    expect(up, isNotNull);
  });
}
