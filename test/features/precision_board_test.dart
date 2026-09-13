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
import 'package:hintpcb/features/board/crosshair.dart';
import 'package:hintpcb/features/board/precision_board_panel.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

BoardPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BoardPainter>()
    .first;

Future<(Project, BoardRepository)> _board(dynamic db, dynamic storage) async {
  final project = await ProjectRepository(db).create(name: 'Aim');
  final parts = PartRepository(db);
  final nets = NetRepository(db);
  final boards = BoardRepository(db);
  await FootprintLibraryRepository(
    db,
    storage,
  ).import(nickname: 'Test', sources: twoPadFootprintSources());

  final r1 = await parts.addPart(project.id, resistorSpec());
  final r2 = await parts.addPart(project.id, resistorSpec());
  await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

  for (final (part, x) in [(r1, 30.0), (r2, 45.0)]) {
    final ref = await boards.assignFootprint(
      projectId: project.id,
      partId: part.part.id,
      libId: 'Test:TwoPad',
    );
    await boards.updatePlacement(ref.copyWith(x: x, y: 35, placed: true));
  }
  return (project, boards);
}

/// Pans the board so [board] sits under the crosshair.
///
/// The correction happens inside one live gesture: a recogniser swallows
/// the first eighteen pixels or so winning the arena, so a short drag from
/// cold moves nothing at all. Once it has won, every further move lands
/// exactly, which is what this converges on.
Future<void> _aimAt(WidgetTester tester, Offset board) async {
  Offset residual() {
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    return rect.center -
        (rect.topLeft + _painter(tester).viewport.toScreen(board));
  }

  if (residual().distance < 0.2) return;

  final rect = tester.getRect(find.byType(PrecisionBoardPanel));
  final gesture = await tester.startGesture(rect.topLeft + const Offset(80, 150));
  await tester.pump(const Duration(milliseconds: 16));
  // Far enough to be recognised as a drag rather than a tap.
  await gesture.moveBy(const Offset(60, 0));
  await tester.pump(const Duration(milliseconds: 16));

  for (var i = 0; i < 8; i++) {
    final delta = residual();
    if (delta.distance < 0.2) break;
    await gesture.moveBy(delta);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await settleApp(tester);
}

void main() {
  group('the crosshair, not the finger', () {
    testAppWithStorage('a point lands where the crosshair says', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // The readout names the point before anything is committed to.
      expect(find.byType(AimBar), findsOneWidget);
      expect(find.text('PLACE'), findsNothing);

      await tester.tap(find.byIcon(Icons.adjust).first);
      await settleApp(tester);
      expect(find.text('VIA'), findsOneWidget);

      await _aimAt(tester, const Offset(38, 30));
      await tester.tap(find.text('VIA'));
      await settleApp(tester);

      final vias = await boards.getVias(project.id);
      expect(vias, hasLength(1));
      // Within a grid square of where it was aimed — the pan is inexact in
      // a test, the placement is not.
      expect((vias.single.x - 38).abs(), lessThanOrEqualTo(0.5));
      expect((vias.single.y - 30).abs(), lessThanOrEqualTo(0.5));
    });

    test('the crosshair catches pads before grid, and says which', () {
      final scene = BoardScene(
        board: Board(
          id: 'b',
          projectId: 'p',
          outlineX: 0,
          outlineY: 0,
          outlineWidth: 40,
          outlineHeight: 30,
          rules: DesignRules.conservative,
          gridMm: 0.5,
          modifiedAt: DateTime(2026),
        ),
        footprints: const [],
        pads: const [],
        tracks: [
          Track(
            id: 't',
            projectId: 'p',
            layer: CopperLayer.front,
            startX: 10,
            startY: 10,
            endX: 20,
            endY: 10,
            width: 0.25,
          ),
        ],
        vias: const [],
        ratsnest: const [],
        unplaced: const [],
      );

      // Near a track end: catches the copper, and says so.
      final copper = resolveSnap(
        at: const Offset(20.08, 10.05),
        scene: scene,
        gridMm: 0.5,
        snapToGrid: true,
        toleranceMm: 0.3,
      );
      expect(copper.at, const Offset(20, 10));
      expect(copper.strong, isTrue);

      // Away from everything: the grid, and it admits that is all it is.
      final grid = resolveSnap(
        at: const Offset(4.6, 7.4),
        scene: scene,
        gridMm: 0.5,
        snapToGrid: true,
        toleranceMm: 0.3,
      );
      expect(grid.at, const Offset(4.5, 7.5));
      expect(grid.strong, isFalse);
      expect(grid.label, contains('grid'));

      // Snapping off means exactly where you aimed.
      final free = resolveSnap(
        at: const Offset(4.63, 7.41),
        scene: scene,
        gridMm: 0.5,
        snapToGrid: false,
        toleranceMm: 0.3,
      );
      expect(free.at, const Offset(4.63, 7.41));
      expect(free.label, 'free');
    });
  });

  group('pours are any shape', () {
    testAppWithStorage('a pour is drawn corner by corner, not board-sized', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.format_color_fill_outlined).first);
      await settleApp(tester);

      // Three corners of a triangle — a shape the old "fill everything"
      // pour could never make.
      for (final corner in const [
        Offset(28, 28),
        Offset(36, 28),
        Offset(32, 34),
      ]) {
        await _aimAt(tester, corner);
        await tester.tap(find.textContaining(RegExp('START|CORNER')));
        await settleApp(tester);
      }

      await tester.tap(find.text('Close pour'));
      await settleApp(tester);

      // It asks which net to fill with, which is the only thing it cannot
      // work out for itself.
      await tester.tap(find.text('No net'));
      await settleApp(tester);

      final zones = await boards.getZones(project.id);
      expect(zones, hasLength(1));
      expect(zones.single.points, hasLength(3));
      // A triangle, not the whole board.
      expect(zones.single.bounds.width, lessThan(20));
    });
  });

  group('edge cuts are drawn, not typed', () {
    testAppWithStorage('a chain of corners becomes a run of cuts', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.content_cut).first);
      await settleApp(tester);

      for (final corner in const [
        Offset(26, 45),
        Offset(34, 45),
        Offset(34, 50),
      ]) {
        await _aimAt(tester, corner);
        await tester.tap(find.textContaining(RegExp('START|CORNER')));
        await settleApp(tester);
      }
      await tester.tap(find.text('Finish cut'));
      await settleApp(tester);

      final edges = await boards.getEdges(project.id);
      // Two segments from three corners, line to line.
      expect(edges, hasLength(2));
      expect(edges.every((e) => e.kind == BoardEdgeKind.line), isTrue);
    });

    testAppWithStorage('a chain back to its start is a closed cutout', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.content_cut).first);
      await settleApp(tester);

      // Round a square and back to where it began — which is how an
      // internal cutout is drawn, rather than spawning a circle and typing
      // its dimensions.
      for (final corner in const [
        Offset(36, 40),
        Offset(40, 40),
        Offset(40, 44),
        Offset(36, 44),
        Offset(36, 40),
      ]) {
        await _aimAt(tester, corner);
        await tester.tap(find.textContaining(RegExp('START|CORNER')));
        await settleApp(tester);
      }
      await tester.tap(find.text('Finish cut'));
      await settleApp(tester);

      final edges = await boards.getEdges(project.id);
      expect(edges, hasLength(1));
      expect(edges.single.kind, BoardEdgeKind.polygon);
      expect(edges.single.points, hasLength(4));
    });
  });

  group('sizes set up in advance', () {
    test('the design rule is always offered, listed or not', () {
      final board = Board(
        id: 'b',
        projectId: 'p',
        outlineX: 0,
        outlineY: 0,
        outlineWidth: 40,
        outlineHeight: 30,
        rules: const DesignRules(trackWidth: 0.25),
        trackWidths: const [0.5, 1.0],
        viaSizes: const [ViaSize(1.2, 0.6)],
        gridMm: 0.5,
        modifiedAt: DateTime(2026),
      );

      expect(board.availableTrackWidths, [0.25, 0.5, 1.0]);
      expect(board.availableViaSizes.length, 2);
      expect(board.availableViaSizes.first.diameter, 0.8);
    });

    test('a hole wider than its pad is not a via', () {
      expect(const ViaSize(0.8, 0.4).isValid, isTrue);
      expect(const ViaSize(0.4, 0.8).isValid, isFalse);
      expect(const ViaSize(0.8, 0).isValid, isFalse);
    });

    testAppWithStorage('the widths survive being written and read back', (
      tester,
      db,
      storage,
    ) async {
      final project = await ProjectRepository(db).create(name: 'Sizes');
      final boards = BoardRepository(db);
      final board = await boards.ensureBoard(project.id);

      await boards.updateBoard(
        board.copyWith(
          trackWidths: [0.2, 0.35, 1.5],
          viaSizes: const [ViaSize(0.6, 0.3), ViaSize(1.2, 0.6)],
        ),
      );

      final back = (await boards.getBoard(project.id))!;
      expect(back.trackWidths, [0.2, 0.35, 1.5]);
      expect(back.viaSizes, const [ViaSize(0.6, 0.3), ViaSize(1.2, 0.6)]);
    });
  });

  testAppWithStorage('a part is carried on the crosshair, not dragged', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final painter = _painter(tester);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + painter.viewport.toScreen(const Offset(30, 35)),
    );
    await settleApp(tester);
    expect(find.text('Move'), findsOneWidget);

    await tester.tap(find.text('Move'));
    await settleApp(tester);
    expect(find.text('DROP'), findsOneWidget);

    await _aimAt(tester, const Offset(34, 41));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final placed = await boards.getFootprints(project.id);
    final moved = placed.firstWhere((p) => (p.y - 35).abs() > 1);
    expect((moved.y - 41).abs(), lessThanOrEqualTo(0.5));
  });

  group('an area you sweep', () {
    testAppWithStorage('everything inside it moves as one', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 31,
        startY: 32,
        endX: 34,
        endY: 32,
        width: 0.25,
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.crop_free).first);
      await settleApp(tester);

      // A box round the track only, not the parts either side of it.
      await _aimAt(tester, const Offset(30, 31));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(35, 33));
      await tester.tap(find.text('FINISH'));
      await settleApp(tester);

      expect(find.textContaining('Move 1'), findsOneWidget);

      await tester.tap(find.textContaining('Move 1'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(32.5, 38));
      await tester.tap(find.text('DROP'));
      await settleApp(tester);

      final tracks = await boards.getTracks(project.id);
      expect(tracks.single.startY, isNot(32));
      // Moved bodily: the segment kept its length.
      expect(tracks.single.endX - tracks.single.startX, closeTo(3, 0.01));
    });

    testAppWithStorage('everything inside it can be deleted at once', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      for (final y in [31.0, 32.0]) {
        await boards.addTrack(
          projectId: project.id,
          layer: CopperLayer.front,
          startX: 31,
          startY: y,
          endX: 34,
          endY: y,
          width: 0.25,
        );
      }

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.crop_free).first);
      await settleApp(tester);
      await _aimAt(tester, const Offset(30, 30));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(35, 33));
      await tester.tap(find.text('FINISH'));
      await settleApp(tester);

      await tester.tap(find.textContaining('Delete 2'));
      await settleApp(tester);

      expect(await boards.getTracks(project.id), isEmpty);
    });

    testAppWithStorage('a box only catches what is wholly inside it', (
      tester,
      db,
      storage,
    ) async {
      // A box that grabs everything it brushes past is a box that deletes
      // a track you could not see.
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 31,
        startY: 32,
        endX: 44,
        endY: 32,
        width: 0.25,
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.crop_free).first);
      await settleApp(tester);
      // Half the track, so neither end pair is enclosed.
      await _aimAt(tester, const Offset(30, 31));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(37, 33));
      await tester.tap(find.text('FINISH'));
      await settleApp(tester);

      expect(find.textContaining('Delete 0'), findsOneWidget);
    });
  });

  testAppWithStorage('an edge cut can be picked up and moved', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    await boards.addEdge(
      projectId: project.id,
      kind: BoardEdgeKind.line,
      points: const [Offset(28, 48), Offset(36, 48)],
    );

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final painter = _painter(tester);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + painter.viewport.toScreen(const Offset(32, 48)),
    );
    await settleApp(tester);
    expect(find.text('Move'), findsOneWidget);

    await tester.tap(find.text('Move'));
    await settleApp(tester);
    await _aimAt(tester, const Offset(32, 44));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final edges = await boards.getEdges(project.id);
    // Moved bodily: both ends shifted, the cut kept its length.
    expect(edges.single.points.first.dy, isNot(48));
    expect(
      edges.single.points.last.dx - edges.single.points.first.dx,
      closeTo(8, 0.01),
    );
  });

  testAppWithStorage('the board outline itself can be picked up', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    final board = await boards.ensureBoard(project.id);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final painter = _painter(tester);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    // The left edge of the board, which is a line like any other.
    await tester.tapAt(
      rect.topLeft +
          painter.viewport.toScreen(
            Offset(board.outlineX, board.outlineY + board.outlineHeight / 2),
          ),
    );
    await settleApp(tester);
    expect(find.text('Move outline'), findsOneWidget);
  });

  testAppWithStorage('delete takes whatever the crosshair is over', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    await boards.addVia(
      projectId: project.id,
      x: 38,
      y: 30,
      diameter: 0.8,
      drill: 0.4,
    );

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    // Nothing under the sight to begin with, so the button is dead.
    await _aimAt(tester, const Offset(33, 47));
    expect(
      tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Delete'),
          matching: find.byType(InkWell),
        ),
      ).onTap,
      isNull,
    );

    await _aimAt(tester, const Offset(38, 30));
    await tester.tap(find.text('Delete'));
    await settleApp(tester);

    expect(await boards.getVias(project.id), isEmpty);
  });
}
