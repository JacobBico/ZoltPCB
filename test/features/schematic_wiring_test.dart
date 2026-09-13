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
      await tester.tapAt(canvas.topLeft + viewport.toScreen(free.sheetPosition));
      await settleApp(tester);

      final corner = wire.points[wire.points.length ~/ 2];
      await tester.tapAt(canvas.topLeft + viewport.toScreen(corner));
      await settleApp(tester);

      final after = await nets.getNets(project.id);
      expect(after, hasLength(1), reason: 'the pin should have joined the net');
      expect(
        after.single.endpoints.map((e) => e.pin.id),
        contains(free.id),
      );
    });

    testAppWithStorage('a tap on empty sheet still cancels, as it always did', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Cancel');
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
      expect(container.read(pendingPinProvider), isNull);
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
