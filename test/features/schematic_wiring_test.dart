import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/features/project/nets_panel.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

/// The painter currently on screen, which carries the scene and the
/// viewport — the only honest way to turn sheet millimetres into the screen
/// point a finger has to land on.
SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

void main() {
  group('reported: joining a third part to an existing wire', () {
    // "I have a resistor and capacitor set up as a lowpass filter, I connect
    // their pins and the wires make a right angle... I add another resistor,
    // so instead of just tapping the corner of that right angle wire and
    // connecting to the new resistor pin, I can't."
    testAppWithStorage('tapping a wire finishes a connection onto its net', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Filter');
      final parts = PartRepository(db);
      final nets = NetRepository(db);

      final r1 = await parts.addPart(project.id, resistorSpec());
      final c1 = await parts.addPart(project.id, capacitorSpec());
      await parts.updateUnitPlacement(
        c1.units.first.copyWith(x: 50.8, y: 25.4, placed: true),
      );
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
      );

      await nets.connectPins(r1.pins.first.id, c1.pins.first.id);

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final painter = _painter(tester);
      final scene = painter.scene;
      final viewport = painter.viewport;
      final canvas = tester.getRect(find.byType(SchematicPanel));

      final free = scene.pins.firstWhere((p) => p.partId == r2.part.id);
      final wire = scene.wires.single;

      // Tap the free pin, then the wire — not another pin.
      await tester.tapAt(
        canvas.topLeft + viewport.toScreen(free.sheetPosition),
      );
      await settleApp(tester);

      // Somewhere along the wire and well away from either end: a tap
      // within reach of a pin is a tap on that pin, and tapping a second
      // pin no longer connects anything.
      Offset farthestFromPins() {
        var best = wire.points.first;
        var bestGap = -1.0;
        for (var i = 0; i < wire.points.length - 1; i++) {
          for (var t = 1; t < 8; t++) {
            final at = Offset.lerp(wire.points[i], wire.points[i + 1], t / 8)!;
            final gap = scene.pins
                .map((p) => (p.sheetPosition - at).distance)
                .reduce((a, b) => a < b ? a : b);
            if (gap > bestGap) {
              bestGap = gap;
              best = at;
            }
          }
        }
        return best;
      }

      await tester.tapAt(
        canvas.topLeft + viewport.toScreen(farthestFromPins()),
      );
      await settleApp(tester);

      final after = await nets.getNets(project.id);
      expect(after, hasLength(1), reason: 'the pin should have joined the net');
      expect(after.single.endpoints.map((e) => e.pin.id), contains(free.id));
    });

    // "I want the pin to pin tapping to be removed, it only causes issues in
    // my experience."
    testAppWithStorage('tapping two pins picks each up and connects neither', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Taps');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
      );

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final painter = _painter(tester);
      final canvas = tester.getRect(find.byType(SchematicPanel));
      final a = painter.scene.pins.firstWhere((p) => p.partId == r1.part.id);
      final b = painter.scene.pins.firstWhere((p) => p.partId == r2.part.id);

      await tester.tapAt(
        canvas.topLeft + painter.viewport.toScreen(a.sheetPosition),
      );
      await settleApp(tester);
      await tester.tapAt(
        canvas.topLeft + painter.viewport.toScreen(b.sheetPosition),
      );
      await settleApp(tester);

      expect(await nets.getNets(project.id), isEmpty);
      expect(await nets.getWires(project.id), isEmpty);
      // The second tap moved the selection rather than doing nothing at all.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      );
      expect(container.read(pendingPinProvider), b.id);
    });

    // "I feel like it is better to have them work in a similar way to how
    // the pcb section works... only 90 degree wires in the schematics"
    testAppWithStorage('a tap on empty sheet lays a corner; Cancel lets go', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Corner');
      final parts = PartRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final painter = _painter(tester);
      final canvas = tester.getRect(find.byType(SchematicPanel));
      final pin = painter.scene.pins.firstWhere((p) => p.partId == r1.part.id);

      await tester.tapAt(
        canvas.topLeft + painter.viewport.toScreen(pin.sheetPosition),
      );
      await settleApp(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchematicPanel)),
      );
      expect(container.read(pendingPinProvider), pin.id);

      // Somewhere with nothing on it at all.
      await tester.tapAt(canvas.bottomLeft + const Offset(30, -120));
      await settleApp(tester);
      expect(container.read(pendingPinProvider), pin.id);
      expect(_painter(tester).pendingWire, isNotNull);

      await tester.tap(find.text('Cancel'));
      await settleApp(tester);
      expect(container.read(pendingPinProvider), isNull);
      expect(_painter(tester).pendingWire, isNull);
    });

    testAppWithStorage('pin, corner, pin: the wire is kept as drawn, dragged', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Drawn');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
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

      final scene = _painter(tester).scene;
      // The top pin of each resistor.
      final from = scene.pins
          .where((p) => p.partId == r1.part.id)
          .reduce((a, b) => a.sheetPosition.dy < b.sheetPosition.dy ? a : b);
      final to = scene.pins
          .where((p) => p.partId == r2.part.id)
          .reduce((a, b) => a.sheetPosition.dy < b.sheetPosition.dy ? a : b);
      // Clear of both pins, and still on the test's small canvas.
      final corner = Offset(
        from.sheetPosition.dx,
        from.sheetPosition.dy - 5.08,
      );

      // Dragged, not tapped: a tap on a pin picks it up and nothing more.
      Future<void> drag(Offset fromSheet, Offset toSheet) async {
        final a = screen(fromSheet);
        final b = screen(toSheet);
        final gesture = await tester.startGesture(a);
        for (var i = 1; i <= 10; i++) {
          await gesture.moveTo(Offset.lerp(a, b, i / 10)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await settleApp(tester);
      }

      await drag(from.sheetPosition, corner);
      await drag(corner, to.sheetPosition);

      final wires = await nets.getWires(project.id);
      expect(wires, hasLength(1));
      final points = wires.single.points;
      bool near(Offset a, Offset b) => (a - b).distance < 1e-3;
      expect(near(points.first, from.sheetPosition), isTrue);
      expect(near(points.last, to.sheetPosition), isTrue);
      expect(points.any((p) => near(p, corner)), isTrue);
      for (var i = 0; i < points.length - 1; i++) {
        final square =
            (points[i].dx - points[i + 1].dx).abs() < 1e-6 ||
            (points[i].dy - points[i + 1].dy).abs() < 1e-6;
        expect(square, isTrue, reason: 'run $i is not at a right angle');
      }
      expect(await nets.getNets(project.id), hasLength(1));

      // Drawn as laid, not re-routed: the scene shows the stored corners.
      final shown = _painter(tester).scene.wires.single;
      expect(shown.isDrawn, isTrue);
      expect(shown.points, hasLength(points.length));
      for (var i = 0; i < points.length; i++) {
        expect(near(shown.points[i], points[i]), isTrue);
      }
    });

    testAppWithStorage('sliding a routed wire keeps the shape it was given', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Slide');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 88.9, y: 50.8, placed: true),
      );
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final wire = _painter(tester).scene.wires.single;
      expect(wire.isDrawn, isFalse);
      // The middle of the longest run.
      var longest = 0;
      for (var i = 1; i < wire.points.length - 1; i++) {
        if ((wire.points[i + 1] - wire.points[i]).distance >
            (wire.points[longest + 1] - wire.points[longest]).distance) {
          longest = i;
        }
      }
      final grab = (wire.points[longest] + wire.points[longest + 1]) / 2;
      final horizontal =
          (wire.points[longest].dy - wire.points[longest + 1].dy).abs() < 1e-6;
      final push = horizontal ? const Offset(0, -40) : const Offset(40, 0);

      final canvas = tester.getRect(find.byType(SchematicPanel));
      final from = canvas.topLeft + _painter(tester).viewport.toScreen(grab);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(from + push * (i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      final stored = await nets.getWires(project.id);
      expect(stored, hasLength(1));
      expect(stored.single.points, isNot(wire.points));
      expect(_painter(tester).scene.wires.single.isDrawn, isTrue);
    });
  });

  group('reported: net labels crowd the pins', () {
    // "when I label the wire... the names show up at the pin connection
    // points, when wires are close together it looks really ugly."
    testAppWithStorage('a label can be dragged, and stays where it is put', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Labels');
      final parts = PartRepository(db);
      final nets = NetRepository(db);

      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
      await nets.renameNet(net.id, 'OUTPUT');

      await pumpApp(
        tester,
        Scaffold(body: SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );

      final painter = _painter(tester);
      final viewport = painter.viewport;
      final canvas = tester.getRect(find.byType(SchematicPanel));
      final label = painter.scene.labels.single;
      final from = canvas.topLeft + viewport.toScreen(label.position);

      final gesture = await tester.startGesture(from);
      // Past the drag slop, then a good way further, in steps — one jump is
      // read as a fling and never becomes a drag.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(6, 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      final stored = (await nets.getNets(project.id)).single.net.labelAt;
      expect(stored, isNotNull, reason: 'the drag should have been written');
      expect(
        (stored! - label.position).distance,
        greaterThan(1.0),
        reason: 'the label should have moved with the finger',
      );

      // And it is drawn where it was left.
      expect(_painter(tester).scene.labels.single.position, stored);
      expect(_painter(tester).scene.labels.single.pinned, isTrue);
    });
  });
}
