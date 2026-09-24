import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/features/project/schematic_panel.dart';
import 'package:zolt/rendering/schematic_painter.dart';
import 'package:zolt/rendering/schematic_scene.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

void main() {
  // "i want to make the wire draggable rather than tappable" and "there is
  // no button to say finish, so if I dont want to end on a different node,
  // its not possible"
  late NetRepository nets;
  late PartRepository parts;

  Future<(String, PlacedPin, PlacedPin)> setUpSheet(
    WidgetTester tester,
    AppDatabase db,
    LibraryFileStorage storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Drag');
    parts = PartRepository(db);
    nets = NetRepository(db);
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 63.5, y: 50.8, placed: true),
    );
    await pumpApp(
      tester,
      Scaffold(body: SchematicPanel(project: project)),
      database: db,
      storage: storage,
    );
    final scene = _painter(tester).scene;
    PlacedPin top(String partId) => scene.pins
        .where((p) => p.partId == partId)
        .reduce((a, b) => a.sheetPosition.dy < b.sheetPosition.dy ? a : b);
    return (project.id, top(r1.part.id), top(r2.part.id));
  }

  Offset screen(WidgetTester tester, Offset sheet) =>
      tester.getRect(find.byType(SchematicPanel)).topLeft +
      _painter(tester).viewport.toScreen(sheet);

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final a = screen(tester, from);
    final b = screen(tester, to);
    final gesture = await tester.startGesture(a);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(a, b, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);
  }

  testAppWithStorage('dragging from one pin to another draws the wire', (
    tester,
    db,
    storage,
  ) async {
    final (projectId, from, to) = await setUpSheet(tester, db, storage);

    await drag(tester, from.sheetPosition, to.sheetPosition);

    final all = await nets.getNets(projectId);
    expect(all, hasLength(1));
    expect(all.single.endpoints.map((e) => e.pin.id).toSet(), {from.id, to.id});
  });

  testAppWithStorage('let go on empty sheet, then Finish, leaves it open', (
    tester,
    db,
    storage,
  ) async {
    final (projectId, from, _) = await setUpSheet(tester, db, storage);
    final corner = from.sheetPosition.translate(0, -5.08);

    await drag(tester, from.sheetPosition, corner);
    // Still drawing: the corner is down and the wire waits for more.
    expect(_painter(tester).pendingWire, isNotNull);
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await settleApp(tester);

    final wires = await nets.getWires(projectId);
    expect(wires, hasLength(1));
    expect(wires.single.pinAId, from.id);
    expect(wires.single.pinBId, isNull);
    expect((wires.single.points.last - corner).distance, lessThan(1e-3));
    // On a net of its own, ready to be joined later.
    expect(await nets.netIdForPin(from.id), wires.single.netId);
    expect(_painter(tester).pendingWire, isNull);
  });

  testAppWithStorage('a drag from the loose end carries the wire on', (
    tester,
    db,
    storage,
  ) async {
    final (projectId, from, to) = await setUpSheet(tester, db, storage);
    final corner = from.sheetPosition.translate(0, -5.08);

    await drag(tester, from.sheetPosition, corner);
    await drag(tester, corner, to.sheetPosition);

    final all = await nets.getNets(projectId);
    expect(all, hasLength(1));
    final wire = (await nets.getWires(projectId)).single;
    expect(wire.points.any((p) => (p - corner).distance < 1e-3), isTrue);
  });

  testAppWithStorage('a drag on the body still moves the part', (
    tester,
    db,
    storage,
  ) async {
    final (projectId, from, _) = await setUpSheet(tester, db, storage);
    final body = from.sheetPosition.translate(0, 3.81);

    await drag(tester, body, body.translate(0, 10));

    expect(await nets.getNets(projectId), isEmpty);
    final moved = (await parts.getPartsWithDetails(
      projectId,
    )).firstWhere((p) => p.part.id == from.partId);
    expect(moved.units.first.y, greaterThan(50.8));
  });
}
