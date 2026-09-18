import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/features/board/board_painter.dart';
import 'package:hintpcb/features/board/precision_board_panel.dart';
import 'package:hintpcb/features/project/project_screen.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

BoardPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BoardPainter>()
    .first;

/// Two resistors on one net, placed, with a straight 15 mm track on that
/// net running between them below their pads.
Future<(Project, BoardRepository, String)> _board(
  dynamic db,
  dynamic storage, {
  bool track = true,
}) async {
  final project = await ProjectRepository(db).create(name: 'Tools');
  final parts = PartRepository(db);
  final nets = NetRepository(db);
  final boards = BoardRepository(db);
  await FootprintLibraryRepository(
    db,
    storage,
  ).import(nickname: 'Test', sources: twoPadFootprintSources());

  final r1 = await parts.addPart(
    project.id,
    resistorSpec(footprint: 'Test:TwoPad'),
  );
  final r2 = await parts.addPart(
    project.id,
    resistorSpec(footprint: 'Test:TwoPad'),
  );
  final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
  for (final (part, x) in [(r1, 30.0), (r2, 45.0)]) {
    final ref = await boards.assignFootprint(
      projectId: project.id,
      partId: part.part.id,
      libId: 'Test:TwoPad',
    );
    await boards.updatePlacement(ref.copyWith(x: x, y: 35, placed: true));
  }
  if (track) {
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 25,
      startY: 45,
      endX: 50,
      endY: 45,
      width: 0.25,
      netId: net.id,
    );
  }
  return (project, boards, net.id);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pump();
  await tester.tap(find.text(text).first);
  await settleApp(tester);
}

Future<void> _openMore(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('More'));
  await settleApp(tester);
  await _tapText(tester, item);
}

void main() {
  // "implement the meander loops"
  testAppWithStorage('a track is tuned into loops that add what was asked', (
    tester,
    db,
    storage,
  ) async {
    final footprints = InMemoryLibraryStorageFor();
    final (project, boards, netId) = await _board(db, footprints);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprints,
    );

    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + _painter(tester).viewport.toScreen(const Offset(37.5, 45)),
    );
    await settleApp(tester);
    // The length is shown with the selection.
    final readout = tester.widget<Text>(
      find.byKey(const ValueKey('track-length-readout')),
    );
    expect(readout.data, contains('25 mm'));
    expect(readout.data, contains('Z₀'));

    await _tapText(tester, 'Tune');
    await tester.enterText(find.byKey(const ValueKey('meander-value')), '6');
    await tester.pump();
    expect(find.byKey(const ValueKey('meander-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meander-apply')));
    await settleApp(tester);

    final tracks = await boards.getTracks(project.id);
    final total = tracks.fold<double>(0, (sum, t) => sum + t.lengthMm);
    expect(tracks.length, greaterThan(5));
    expect(total, closeTo(31, 1e-6));
    expect(tracks.every((t) => t.netId == netId && t.width == 0.25), isTrue);

    // One undo puts the straight track back.
    await tester.tap(find.text('Undo'));
    await settleApp(tester);
    final back = await boards.getTracks(project.id);
    expect(back, hasLength(1));
    expect(back.single.lengthMm, closeTo(25, 1e-9));
  });

  // "implement at least a 6 layer board stack up piece, choose the copper
  // size and length of the board"
  testAppWithStorage('the board is built to six layers and routed inside', (
    tester,
    db,
    storage,
  ) async {
    final footprints = InMemoryLibraryStorageFor();
    final (project, boards, _) = await _board(db, footprints);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprints,
    );

    await _openMore(tester, 'Board build');
    await tester.tap(find.text('6'));
    await tester.pump();
    await tester.tap(find.text('1.2'));
    await tester.pump();
    await tester.tap(find.text('2 oz').first);
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    final board = (await boards.getBoard(project.id))!;
    expect(board.copperLayerCount, 6);
    expect(board.stackup.thickness, closeTo(1.2, 0.001));
    expect(board.stackup.copperOf(CopperLayer.front).weight, CopperWeight.two);

    // The layer chip now asks which of six.
    await tester.tap(find.byIcon(Icons.layers_outlined));
    await settleApp(tester);
    expect(find.textContaining('Inner 2'), findsOneWidget);
    await tester.tap(find.textContaining('Inner 2'));
    await settleApp(tester);
    expect(_painter(tester).activeLayer, CopperLayer.inner2);

    // And cannot go back to two while copper is on In2.
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.inner2,
      startX: 25,
      startY: 50,
      endX: 30,
      endY: 50,
      width: 0.2,
    );
    await settleApp(tester);
    await _openMore(tester, 'Board build');
    await tester.tap(find.text('2'));
    await settleApp(tester);
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);
    expect((await boards.getBoard(project.id))!.copperLayerCount, 6);
  });

  // "an automatic impedance trace calculator would be great when routing"
  testAppWithStorage('the calculator finds a 50 Ω width and routes with it', (
    tester,
    db,
    storage,
  ) async {
    final footprints = InMemoryLibraryStorageFor();
    final (project, boards, _) = await _board(db, footprints);
    final board = await boards.ensureBoard(project.id);
    await boards.updateBoard(board.copyWith(copperLayerCount: 4));

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprints,
    );

    await _openMore(tester, 'Impedance calculator');
    await tester.tap(find.byKey(const ValueKey('impedance-solve')));
    await tester.pump();
    expect(find.text('50.0 Ω'), findsOneWidget);
    await tester.tap(find.text('USE THIS WIDTH'));
    await settleApp(tester);

    final width = ImpedanceCalculator.widthFor(
      Stackup.standard(layerCount: 4),
      CopperLayer.front,
      target: 50,
    )!;
    // The strip's width chip, to the micron the calculator gave.
    final shown = width.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    expect(find.text('$shown mm'), findsOneWidget);
  });

  // "Update board from schematic"
  testAppWithStorage('a new part on the schematic is brought onto the board', (
    tester,
    db,
    storage,
  ) async {
    final footprints = InMemoryLibraryStorageFor();
    final (project, boards, _) = await _board(db, footprints, track: false);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprints,
    );
    expect(find.byKey(const ValueKey('board-sync-chip')), findsNothing);

    await PartRepository(
      db,
    ).addPart(project.id, resistorSpec(footprint: 'Test:TwoPad'));
    await settleApp(tester);
    expect(find.byKey(const ValueKey('board-sync-chip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('board-sync-chip')));
    await settleApp(tester);
    expect(find.textContaining('R3'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('board-sync-apply')));
    await settleApp(tester);

    final placed = await boards.getFootprints(project.id);
    expect(placed, hasLength(3));
    expect(placed.every((f) => f.placed), isTrue);
    expect(find.byKey(const ValueKey('board-sync-chip')), findsNothing);
  });

  // "Cross-probing. Tap a net or part in the schematic and have it
  // highlight on the board, and back again"
  testAppWithStorage('a part is shown on the board, and back on the sheet', (
    tester,
    db,
    storage,
  ) async {
    final footprints = InMemoryLibraryStorageFor();
    final (project, _, _) = await _board(db, footprints, track: false);
    final parts = PartRepository(db);
    for (final (i, part) in (await parts.getPartsWithDetails(
      project.id,
    )).indexed) {
      await parts.updateUnitPlacement(
        part.units.single.copyWith(x: 50.8 + i * 25.4, y: 50.8, placed: true),
      );
    }

    await pumpApp(
      tester,
      ProjectScreen(
        projectId: project.id,
        initialSection: ProjectSection.schematic,
      ),
      database: db,
      storage: storage,
      footprintStorage: footprints,
    );

    SchematicPainter sheet() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SchematicPainter>()
        .single;
    final panel = tester.getRect(find.byType(SchematicPanel));
    await tester.tapAt(
      panel.topLeft + sheet().viewport.toScreen(const Offset(76.2, 50.8)),
    );
    await settleApp(tester);
    await _tapText(tester, 'On board');

    expect(find.byType(PrecisionBoardPanel), findsOneWidget);
    final painter = _painter(tester);
    final r2 = painter.scene.footprints.firstWhere(
      (f) => f.part.reference == 'R2',
    );
    expect(painter.selectedFootprintId, r2.ref.id);

    // And back.
    await _tapText(tester, 'Schematic');
    expect(find.byType(SchematicPanel), findsOneWidget);
    expect(sheet().selectedUnitId, isNotNull);
  });
}
