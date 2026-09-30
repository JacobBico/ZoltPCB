import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/features/board/board_painter.dart';
import 'package:zolt/features/board/precision_board_panel.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

BoardPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BoardPainter>()
    .first;

void main() {
  test('a pour is named inside itself, not at the middle of its box', () {
    // An L: the middle of the box round it is outside the pour.
    const zone = BoardZone(
      id: 'z',
      projectId: 'p',
      layer: BoardLayer.frontCopper,
      points: [
        Offset(0, 0),
        Offset(4, 0),
        Offset(4, 16),
        Offset(20, 16),
        Offset(20, 20),
        Offset(0, 20),
      ],
      netName: 'GND',
    );
    expect(zone.contains(zone.bounds.center), isFalse);
    expect(zone.contains(zone.labelPoint), isTrue);
  });

  testAppWithStorage('a part inside a pour offers both, and either is taken', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final project = await ProjectRepository(db).create(name: 'Pile');
    final parts = PartRepository(db);
    final boards = BoardRepository(db);
    await FootprintLibraryRepository(
      db,
      footprintStorage,
    ).import(nickname: 'Test', sources: twoPadFootprintSources());
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    final net = await NetRepository(
      db,
    ).connectPins(r1.pins.first.id, r2.pins.first.id);
    for (final (part, x) in [(r1, 30.0), (r2, 45.0)]) {
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: part.part.id,
        libId: 'Test:TwoPad',
      );
      await boards.updatePlacement(ref.copyWith(x: x, y: 35, placed: true));
    }
    await boards.addZone(
      projectId: project.id,
      layer: BoardLayer.frontCopper,
      points: const [
        Offset(20, 25),
        Offset(40, 25),
        Offset(40, 45),
        Offset(20, 45),
      ],
      netId: net.net.id,
      netName: 'GND',
    );

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    // Bring R1 under the crosshair, the sight being the panel's middle.
    // A drag's first pixels only win the gesture; the aim is corrected
    // move by move once it has.
    final panel = tester.getRect(find.byType(PrecisionBoardPanel));
    Offset residual() =>
        panel.center -
        (panel.topLeft +
            _painter(tester).viewport.toScreen(const Offset(30, 35)));
    final gesture = await tester.startGesture(
      panel.topLeft + const Offset(80, 150),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 8 && residual().distance >= 0.2; i++) {
      await gesture.moveBy(residual());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    // Over the part and the pour it sits in: a chip for each.
    expect(find.byKey(const ValueKey('pile-chips')), findsOneWidget);
    final chips = find.descendant(
      of: find.byKey(const ValueKey('pile-chips')),
      matching: find.byType(ChoiceChip),
    );
    expect(chips, findsNWidgets(2));
    expect(find.text('GND POUR'), findsOneWidget);

    // The one underneath, taken directly.
    await tester.tap(find.text('GND POUR'));
    await settleApp(tester);
    expect(_painter(tester).selectedZoneId, isNotNull);
    expect(_painter(tester).selectedFootprintId, isNull);

    // A tap there selects the top one; a second offers the pile.
    await tester.tapAt(panel.center);
    await settleApp(tester);
    expect(_painter(tester).selectedFootprintId, isNotNull);
    await tester.tapAt(panel.center);
    await settleApp(tester);
    await tester.tap(find.byType(PopupMenuItem<String>).last);
    await settleApp(tester);
    expect(_painter(tester).selectedZoneId, isNotNull);
  });
}
