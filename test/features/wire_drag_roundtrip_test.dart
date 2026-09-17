import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/geometry/polyline_wiring.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

/// The wires on the sheet as plain shapes, in a stable order, so what is
/// drawn during a drag can be compared with what is drawn after it.
List<String> _shapes(WidgetTester tester) {
  final wires = [
    for (final wire in _painter(tester).scene.wires)
      wire.points
          .map((p) => '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}')
          .join(' → '),
  ];
  return wires..sort();
}

void main() {
  // What the sheet shows while a wire is being dragged is what it must show
  // once the finger lifts. A drawing that rearranges itself on release is
  // the wires "not acting like we intend".
  for (final shape in const [
    ('a stub with a branch', Offset(57.15, 66.04), Offset(57.15, 73.66)),
    (
      'a stub with a branch, sideways',
      Offset(50.8, 60.96),
      Offset(58.42, 60.96),
    ),
    ('a stub with a branch, up', Offset(57.15, 66.04), Offset(57.15, 60.96)),
  ]) {
    testAppWithStorage('what is drawn while dragging ${shape.$1} is kept', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Round trip');
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

      final from = screen(shape.$2);
      final to = screen(shape.$3);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }

      // What the finger is showing, the moment before it lifts.
      final during = _shapes(tester);

      await gesture.up();
      await settleApp(tester);

      expect(
        _shapes(tester),
        during,
        reason: 'the drawing changed when the finger lifted',
      );
    });
  }

  // Dragging a wire must not conjure another one. When a drag stops the
  // drawn wires from reaching the pins, the router fills the gap with an
  // automatic connection — which looks like a wire appearing from nowhere.
  for (final drag in const [
    ('sideways', Offset(57.15, 60.96), Offset(57.15, 71.12)),
    ('far sideways', Offset(57.15, 60.96), Offset(80.01, 60.96)),
  ]) {
    testAppWithStorage('dragging a pin-to-pin wire ${drag.$1} adds no wire', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'No extras');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
      );
      final r3 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
      );

      final a = r1.pins.firstWhere((p) => p.number == '2').id;
      final b = r2.pins.firstWhere((p) => p.number == '2').id;
      final net = await nets.connectPins(a, b);
      // Drawn down out of one pin, across, and up into the other.
      await nets.addWire(
        projectId: project.id,
        points: const [
          Offset(50.8, 54.61),
          Offset(50.8, 60.96),
          Offset(76.2, 60.96),
          Offset(76.2, 54.61),
        ],
        pinAId: a,
        pinBId: b,
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

      final before = _painter(tester).scene.wires.length;

      final from = screen(drag.$2);
      final to = screen(drag.$3);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      expect(
        _painter(tester).scene.wires.length,
        lessThanOrEqualTo(before),
        reason: 'a wire appeared: ${_shapes(tester)}',
      );
      expect(
        _painter(tester).scene.wires.every((w) => w.isDrawn),
        isTrue,
        reason: 'an automatic connection was drawn in: ${_shapes(tester)}',
      );
    });
  }

  // The wire that moves has to be the one under the finger. Wires a couple
  // of grid squares apart are ordinary on a schematic, and the grab radius
  // at a phone's zoom is far wider than that.
  for (final grab in const [
    ('the upper wire', Offset(60.96, 55.88), Offset(60.96, 50.8), 'upper'),
    ('the lower wire', Offset(60.96, 66.04), Offset(60.96, 71.12), 'lower'),
  ]) {
    testAppWithStorage('dragging ${grab.$1} moves that wire', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Grab');
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

      // Two wires across the sheet, four grid squares apart, joined at the
      // right by an upright.
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 55.88), Offset(71.12, 55.88)],
        pinAId: pin,
        netId: netId,
      );
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(50.8, 66.04), Offset(71.12, 66.04)],
        netId: netId,
      );
      await nets.addWire(
        projectId: project.id,
        points: const [Offset(71.12, 55.88), Offset(71.12, 66.04)],
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

      final from = screen(grab.$2);
      final to = screen(grab.$3);
      final gesture = await tester.startGesture(from);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleApp(tester);

      // By where the wires are, not by their ids: a drag may lay a wire
      // again rather than edit it in place.
      final after = await nets.getWires(project.id);
      bool covers(Offset at) =>
          after.any((wire) => PolylineWiring.covers(wire.points, at));

      // It left where it was: how far it went is the grid's business, not
      // this test's.
      expect(
        covers(grab.$2),
        isFalse,
        reason: 'the wire under the finger did not move: ${_shapes(tester)}',
      );
      expect(
        covers(
          grab.$4 == 'upper'
              ? const Offset(60.96, 66.04)
              : const Offset(60.96, 55.88),
        ),
        isTrue,
        reason: 'the other wire moved instead of staying put',
      );
      expect(
        await nets.netIdForPin(pin),
        isNotNull,
        reason: 'the part came unwired',
      );
      expect(
        PolylineWiring.allJoined([for (final w in after) w.points]),
        isTrue,
        reason: 'the net came apart: ${_shapes(tester)}',
      );
    });
  }
}
