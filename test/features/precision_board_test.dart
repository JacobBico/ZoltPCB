import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/app/edit_history.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/features/board/board_painter.dart';
import 'package:zolt/features/board/crosshair.dart';
import 'package:zolt/features/board/footprint_sidebar.dart';
import 'package:zolt/features/board/precision_board_panel.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

BoardPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BoardPainter>()
    .first;

Future<(Project, BoardRepository)> _board(
  AppDatabase db,
  LibraryFileStorage storage,
) async {
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

/// Picks the Edge cut tool drawing [style], through the tool's own menu.
Future<void> _edgeTool(WidgetTester tester, EdgeStyle style) async {
  await tester.tap(find.byKey(const ValueKey('tool-edge')));
  await settleApp(tester);
  // A second tap on the chosen tool opens its menu.
  await tester.tap(find.byKey(const ValueKey('tool-edge')));
  await settleApp(tester);
  await tester.ensureVisible(find.byKey(ValueKey('pick-${style.label}')));
  await tester.tap(find.byKey(ValueKey('pick-${style.label}')));
  await settleApp(tester);
}

/// Gives the board a drawn rectangle outline over its working area.
Future<void> _drawnOutline(BoardRepository boards, String projectId) async {
  final board = await boards.ensureBoard(projectId);
  await boards.updateBoard(
    board.withOutline(board.outline.as(BoardOutlineKind.rectangle)),
  );
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
  final gesture = await tester.startGesture(
    rect.topLeft + const Offset(80, 150),
  );
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

      await _edgeTool(tester, EdgeStyle.lines);

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

      // Undone and done again, the same cuts come back — redo used to do
      // nothing at all here.
      final history = ProviderScope.containerOf(
        tester.element(find.byType(PrecisionBoardPanel)),
      ).read(editHistoryProvider.notifier);
      await history.undo();
      await settleApp(tester);
      expect(await boards.getEdges(project.id), isEmpty);
      await history.redo();
      await settleApp(tester);
      final redone = await boards.getEdges(project.id);
      expect(redone.map((e) => e.id).toSet(), edges.map((e) => e.id).toSet());
    });

    testAppWithStorage('a chain back to its start is a closed cutout', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      // With an outline already there, a closed shape is a hole in it.
      await _drawnOutline(boards, project.id);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await _edgeTool(tester, EdgeStyle.lines);

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

  group('the board outline is drawn, not given', () {
    testAppWithStorage('a new board has none, and a rectangle becomes it', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      expect((await boards.ensureBoard(project.id)).outline.isDrawn, isFalse);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // The strip says what is missing, and takes you to the tool.
      await tester.tap(find.byKey(const ValueKey('draw-outline-chip')));
      await settleApp(tester);

      await _aimAt(tester, const Offset(20, 25));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(60, 50));
      // The second corner finishes it: no Finish to press.
      await tester.tap(find.text('OPPOSITE'));
      await settleApp(tester);

      final board = await boards.ensureBoard(project.id);
      expect(board.outline.kind, BoardOutlineKind.rectangle);
      expect(board.outline.rect.left, closeTo(20, 1e-6));
      expect(board.outline.rect.top, closeTo(25, 1e-6));
      expect(board.outline.rect.width, closeTo(40, 1e-6));
      expect(board.outline.rect.height, closeTo(25, 1e-6));
      expect(await boards.getEdges(project.id), isEmpty);
      expect(find.byKey(const ValueKey('draw-outline-chip')), findsNothing);
    });

    testAppWithStorage('with an outline, a circle is a round cutout', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await _drawnOutline(boards, project.id);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await _edgeTool(tester, EdgeStyle.circle);
      await _aimAt(tester, const Offset(40, 45));
      await tester.tap(find.text('CENTRE'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(43, 45));
      await tester.tap(find.text('RIM'));
      await settleApp(tester);

      final edges = await boards.getEdges(project.id);
      expect(edges, hasLength(1));
      expect(edges.single.kind, BoardEdgeKind.circle);
      expect(edges.single.radius, closeTo(3, 1e-6));
      expect(
        (await boards.ensureBoard(project.id)).outline.kind,
        BoardOutlineKind.rectangle,
      );
    });

    testAppWithStorage('a triangle outline can be deleted and undone', (
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

      await _edgeTool(tester, EdgeStyle.triangle);
      for (final corner in const [
        Offset(20, 55),
        Offset(60, 55),
        Offset(40, 20),
      ]) {
        await _aimAt(tester, corner);
        await tester.tap(find.textContaining(RegExp('START|CORNER')));
        await settleApp(tester);
      }
      var board = await boards.ensureBoard(project.id);
      expect(board.outline.kind, BoardOutlineKind.polygon);
      expect(board.outline.points, hasLength(3));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PrecisionBoardPanel)),
      );
      final history = container.read(editHistoryProvider.notifier);
      await history.undo();
      await settleApp(tester);
      board = await boards.ensureBoard(project.id);
      expect(board.outline.isDrawn, isFalse);
      await history.redo();
      await settleApp(tester);
      expect(
        (await boards.ensureBoard(project.id)).outline.points,
        hasLength(3),
      );
    });
  });

  group('arcs are drawn by their centre', () {
    Future<BoardEdge> drawArc(
      WidgetTester tester,
      BoardRepository boards,
      String projectId, {
      bool otherWay = false,
    }) async {
      await _edgeTool(tester, EdgeStyle.arc);
      await _aimAt(tester, const Offset(40, 44));
      await tester.tap(find.text('CENTRE'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(43, 44));
      await tester.tap(find.text('START'));
      await settleApp(tester);
      if (otherWay) {
        await tester.tap(find.byKey(const ValueKey('arc-other-way')));
        await settleApp(tester);
      }
      await _aimAt(tester, const Offset(40, 41));
      await tester.tap(find.text('END'));
      await settleApp(tester);
      return (await boards.getEdges(projectId)).single;
    }

    testAppWithStorage('centre, start, end: the short way round', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await _drawnOutline(boards, project.id);
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      final arc = await drawArc(tester, boards, project.id);
      expect(arc.kind, BoardEdgeKind.arc);
      expect(arc.start, const Offset(43, 44));
      expect(arc.end.dx, closeTo(40, 1e-6));
      expect(arc.end.dy, closeTo(41, 1e-6));
      // A quarter turn, so its middle is halfway round, up and to the right.
      expect(arc.mid.dx, closeTo(40 + 3 * 0.70710678, 1e-6));
      expect(arc.mid.dy, closeTo(44 - 3 * 0.70710678, 1e-6));
    });

    testAppWithStorage('and Other way takes the long way', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await _drawnOutline(boards, project.id);
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      final arc = await drawArc(tester, boards, project.id, otherWay: true);
      // Three quarters round: the middle is down and to the left.
      expect(arc.mid.dx, closeTo(40 - 3 * 0.70710678, 1e-6));
      expect(arc.mid.dy, closeTo(44 + 3 * 0.70710678, 1e-6));
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

    // Clear of the board's centre lines and edges, which a carried part
    // snaps to.
    await _aimAt(tester, const Offset(34, 46));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final placed = await boards.getFootprints(project.id);
    final moved = placed.firstWhere((p) => (p.y - 35).abs() > 1);
    expect((moved.y - 46).abs(), lessThanOrEqualTo(0.5));
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

    testAppWithStorage('a laid-out channel is copied onto its twin', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      final parts = PartRepository(db);
      final r3 = await parts.addPart(project.id, resistorSpec());
      final r4 = await parts.addPart(project.id, resistorSpec());
      await NetRepository(db).connectPins(r3.pins.first.id, r4.pins.first.id);
      for (final part in [r3, r4]) {
        await boards.assignFootprint(
          projectId: project.id,
          partId: part.part.id,
          libId: 'Test:TwoPad',
        );
      }
      final placed = await boards.getFootprints(project.id);
      final r1 = placed.firstWhere((p) => p.x == 30);
      final net = await NetRepository(db).netIdForPin(
        (await parts.getPartsWithDetails(
          project.id,
        )).firstWhere((p) => p.part.id == r1.partId).pins.first.id,
      );
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 31,
        startY: 35,
        endX: 44,
        endY: 35,
        width: 0.25,
        netId: net,
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );
      await tester.tap(find.byIcon(Icons.crop_free).first);
      await settleApp(tester);
      await _aimAt(tester, const Offset(27, 32));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(48, 38));
      await tester.tap(find.text('FINISH'));
      await settleApp(tester);

      await tester.tap(find.byKey(const ValueKey('replicate')));
      await settleApp(tester);
      expect(find.text('DROP'), findsOneWidget);
      await tester.tap(find.text('DROP'));
      await settleApp(tester);

      final tracks = await boards.getTracks(project.id);
      expect(tracks, hasLength(2));
      expect(tracks.map((t) => t.netId).toSet(), hasLength(2));
      final copies = (await boards.getFootprints(
        project.id,
      )).where((p) => p.partId == r3.part.id || p.partId == r4.part.id);
      expect(copies.every((p) => p.placed), isTrue);
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
    // A drawn outline to take hold of: a new board has none.
    final board = await boards.ensureBoard(project.id).then((b) async {
      final drawn = b.withOutline(b.outline.as(BoardOutlineKind.rectangle));
      await boards.updateBoard(drawn);
      return drawn;
    });

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
      tester
          .widget<InkWell>(
            find.ancestor(
              of: find.text('Delete'),
              matching: find.byType(InkWell),
            ),
          )
          .onTap,
      isNull,
    );

    await _aimAt(tester, const Offset(38, 30));
    await tester.tap(find.text('Delete'));
    await settleApp(tester);

    expect(await boards.getVias(project.id), isEmpty);
  });

  group('routing the way KiCad routes', () {
    testAppWithStorage('pad to pad comes out on legal angles, not a diagonal', (
      tester,
      db,
      storage,
    ) async {
      // "when I try to connect to another pad, it just connects straight
      // from pad a to pad b." Pads sit at whatever millimetre they sit at,
      // so a direct line between two of them is almost never at 45 or 90.
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      // Offset in both axes, so the straight line between them is a stray
      // angle and two segments are needed.
      final placements = await boards.getFootprints(project.id);
      await boards.updatePlacement(
        placements.last.copyWith(x: 45, y: 41, placed: true),
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.timeline).first);
      await settleApp(tester);

      final scene = _painter(tester).scene;
      final line = scene.ratsnest.first;
      final from = scene.padNear(line.from, 0.4)!;
      final to = scene.padNear(line.to, 0.4)!;

      await _aimAt(tester, from.position);
      await tester.tap(find.text('START'));
      await settleApp(tester);
      await _aimAt(tester, to.position);
      await tester.tap(find.textContaining(RegExp('CORNER|START')));
      await settleApp(tester);

      final tracks = await boards.getTracks(project.id);
      expect(
        tracks.length,
        greaterThanOrEqualTo(2),
        reason: 'a stray-angle target needs a run and a 45',
      );

      for (final track in tracks) {
        final dx = track.endX - track.startX;
        final dy = track.endY - track.startY;
        expect(
          isLegalBearing(dx, dy, TrackAngleLock.deg45),
          isTrue,
          reason: 'a segment came out at a stray angle: $dx, $dy',
        );
      }
    });

    testAppWithStorage('the Route chip can lay a meander instead', (
      tester,
      db,
      storage,
    ) async {
      // "it should be like a drop down from the trace tool, like I can mid
      // routing and then swap and it just continues with the meander loop"
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      final tool = find.byKey(const ValueKey('tool-route'));
      await tester.ensureVisible(tool);
      await tester.pump();
      await tester.tap(tool);
      await settleApp(tester);
      await tester.ensureVisible(tool);
      await tester.pump();
      await tester.tap(tool);
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('pick-Meander')));
      await settleApp(tester);

      final scene = _painter(tester).scene;
      final from = scene.padNear(scene.ratsnest.first.from, 0.4)!;
      await _aimAt(tester, from.position);
      await tester.tap(find.text('START'));
      await settleApp(tester);
      await _aimAt(tester, from.position + const Offset(0, -10));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      // The run folded on the way, so it is far longer than the 10 mm it
      // covers — and the readout says by how much.
      expect(find.textContaining(RegExp(r'^\+\d')), findsOneWidget);
      await tester.ensureVisible(find.text('Finish'));
      await tester.pump();
      await tester.tap(find.text('Finish'));
      await settleApp(tester);

      final tracks = await boards.getTracks(project.id);
      final length = tracks.fold<double>(0, (sum, t) => sum + t.lengthMm);
      expect(tracks.length, greaterThan(10), reason: 'loops, not a line');
      expect(length, greaterThan(12));
    });

    testAppWithStorage('a via mid-route keeps the run\'s net', (
      tester,
      db,
      storage,
    ) async {
      // A via that picked its net up from the copper under it got nothing,
      // because the copper had not been written yet. A netless via is
      // copper in everyone\'s way: nothing can route to it and the rule
      // check calls it a clash.
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );
      await tester.tap(find.byIcon(Icons.timeline).first);
      await settleApp(tester);

      final scene = _painter(tester).scene;
      final line = scene.ratsnest.first;
      final from = scene.padNear(line.from, 0.4)!;

      await _aimAt(tester, from.position);
      await tester.tap(find.text('START'));
      await settleApp(tester);
      await _aimAt(tester, from.position + const Offset(0, -6));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);

      // On a two-layer board the layer button just turns it over.
      await tester.tap(find.text('Via + flip'));
      await settleApp(tester);

      final vias = await boards.getVias(project.id);
      expect(vias.single.netId, from.netId);
      expect(from.netId, isNotNull);
    });

    testAppWithStorage('a route can begin on an existing track', (
      tester,
      db,
      storage,
    ) async {
      // "on kicad you can also start routing from the already existing
      // routed trace" — otherwise a third part has to be joined by going
      // back to a pad that is already wired.
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      final nets = await NetRepository(db).getNets(project.id);
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 32,
        startY: 30,
        endX: 40,
        endY: 30,
        width: 0.25,
        netId: nets.first.net.id,
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.byIcon(Icons.timeline).first);
      await settleApp(tester);

      // The middle of that run — not an end, not a pad.
      await _aimAt(tester, const Offset(36, 30));
      expect(find.text('track'), findsOneWidget);

      await tester.tap(find.text('START'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(36, 36));
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
      await tester.tap(find.text('Finish'));
      await settleApp(tester);

      final tracks = await boards.getTracks(project.id);
      expect(tracks.length, greaterThan(1));
      // The branch inherited the net it grew out of, rather than being
      // drawn as unconnected copper.
      final branch = tracks.firstWhere((t) => t.startY != 30 || t.endY != 30);
      expect(branch.netId, nets.first.net.id);
    });

    testAppWithStorage('the crosshair is magnetic along a whole track', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 32,
        startY: 30,
        endX: 40,
        endY: 30,
        width: 0.25,
      );

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // Just off the run: it catches, and says what it caught.
      await _aimAt(tester, const Offset(37, 30.1));
      expect(find.text('track'), findsOneWidget);

      // An end wins over the middle, because continuing from a corner is
      // what you usually want.
      await _aimAt(tester, const Offset(40, 30));
      expect(find.text('corner'), findsOneWidget);
    });
  });

  testAppWithStorage('a placed track can be slid, and stays joined up', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    // A 45 out, a straight run, a 45 back in — the shape routing leaves.
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 31,
      startY: 35,
      endX: 34,
      endY: 32,
      width: 0.25,
    );
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 34,
      startY: 32,
      endX: 41,
      endY: 32,
      width: 0.25,
    );
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 41,
      startY: 32,
      endX: 44,
      endY: 35,
      width: 0.25,
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
      rect.topLeft + painter.viewport.toScreen(const Offset(37.5, 32)),
    );
    await settleApp(tester);
    expect(find.text('Slide'), findsOneWidget);

    await tester.tap(find.text('Slide'));
    await settleApp(tester);
    expect(find.text('DROP'), findsOneWidget);

    await _aimAt(tester, const Offset(37.5, 29.5));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final tracks = await boards.getTracks(project.id);
    final run = tracks.firstWhere((t) => t.startY == t.endY);
    // It moved.
    expect(run.startY, lessThan(32));

    // Every piece of copper left behind is on a legal angle — the whole
    // point, and what the old slide could not promise.
    for (final track in tracks) {
      final dx = track.endX - track.startX;
      final dy = track.endY - track.startY;
      if (dx.abs() < 1e-6 && dy.abs() < 1e-6) continue;
      expect(
        isLegalBearing(dx, dy, TrackAngleLock.deg45),
        isTrue,
        reason: 'a segment came out at a stray angle',
      );
    }

    // And both ends of the original route are still reached by copper.
    for (final end in const [Offset(31, 35), Offset(44, 35)]) {
      expect(
        tracks.any(
          (t) =>
              (Offset(t.startX, t.startY) - end).distance < 1e-4 ||
              (Offset(t.endX, t.endY) - end).distance < 1e-4,
        ),
        isTrue,
        reason: 'nothing reaches $end any more',
      );
    }
  });

  group('getting parts onto the board in the first place', () {
    /// A project whose parts name a footprint but have never been near the
    /// board — which is every project, the first time you open it.
    Future<Project> fresh(AppDatabase db, LibraryFileStorage storage) async {
      final project = await ProjectRepository(db).create(name: 'Fresh');
      final parts = PartRepository(db);
      await FootprintLibraryRepository(
        db,
        storage,
      ).import(nickname: 'Test', sources: twoPadFootprintSources());
      await parts.addPart(project.id, resistorSpec(footprint: 'Test:TwoPad'));
      await parts.addPart(project.id, capacitorSpec(footprint: 'Test:TwoPad'));
      // A power symbol, which never goes on a board.
      await parts.addPart(project.id, groundSpec());
      return project;
    }

    testAppWithStorage('the board says how many parts are waiting', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final project = await fresh(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // Two, not three: the power symbol is not a board part.
      expect(find.text('2 to place'), findsOneWidget);
    });

    testAppWithStorage('they can be assigned and placed without a board yet', (
      tester,
      db,
      storage,
    ) async {
      // The hole this closes: every way into the footprint chooser used to
      // need an already-placed footprint to select, so a board with nothing
      // on it offered no way to put anything on it.
      final footprintStorage = InMemoryLibraryStorageFor();
      final project = await fresh(db, footprintStorage);
      final boards = BoardRepository(db);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.text('2 to place'));
      await settleApp(tester);
      expect(find.text('R1  10k'), findsOneWidget);

      await tester.tap(find.text('ASSIGN 2'));
      await settleApp(tester);
      expect(await boards.getFootprints(project.id), hasLength(2));

      // And each is then placed by carrying it on the crosshair.
      await tester.tap(find.text('2 to place'));
      await settleApp(tester);
      await tester.tap(find.text('PLACE').first);
      await settleApp(tester);
      expect(find.text('DROP'), findsOneWidget);

      await _aimAt(tester, const Offset(34, 33));
      await tester.tap(find.text('DROP'));
      await settleApp(tester);

      final placed = await boards.getFootprints(project.id);
      expect(placed.where((p) => p.placed), hasLength(1));
      final one = placed.firstWhere((p) => p.placed);
      expect((one.x - 34).abs(), lessThanOrEqualTo(0.5));
      expect((one.y - 33).abs(), lessThanOrEqualTo(0.5));
    });

    testAppWithStorage(
      'the chip goes once everything is down, but Parts stays',
      (tester, db, storage) async {
        // A button that can only tell you there is nothing to do is a button
        // taking up room on a strip that has none to spare — but changing a
        // footprint afterwards still has to be possible.
        final footprintStorage = InMemoryLibraryStorageFor();
        final project = await ProjectRepository(db).create(name: 'Done');
        final parts = PartRepository(db);
        final boards = BoardRepository(db);
        await FootprintLibraryRepository(
          db,
          footprintStorage,
        ).import(nickname: 'Test', sources: twoPadFootprintSources());

        final r1 = await parts.addPart(
          project.id,
          resistorSpec(footprint: 'Test:TwoPad'),
        );
        final ref = await boards.assignFootprint(
          projectId: project.id,
          partId: r1.part.id,
          libId: 'Test:TwoPad',
        );
        await boards.updatePlacement(ref.copyWith(x: 35, y: 35, placed: true));

        await pumpApp(
          tester,
          Scaffold(body: PrecisionBoardPanel(project: project)),
          database: db,
          footprintStorage: footprintStorage,
        );

        expect(find.textContaining('to place'), findsNothing);

        // Still reachable, with the footprint still changeable.
        await tester.tap(find.byTooltip('More'));
        await settleApp(tester);
        expect(find.text('Parts and footprints'), findsOneWidget);
        expect(
          find.text('All placed — change a footprint here'),
          findsOneWidget,
        );

        await tester.tap(find.text('Parts and footprints'));
        await settleApp(tester);
        expect(find.text('R1  10k'), findsOneWidget);
        expect(find.text('SHOW'), findsOneWidget);
      },
    );

    testAppWithStorage('a new component makes the chip come back', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final project = await ProjectRepository(db).create(name: 'Grow');
      final parts = PartRepository(db);
      final boards = BoardRepository(db);
      await FootprintLibraryRepository(
        db,
        footprintStorage,
      ).import(nickname: 'Test', sources: twoPadFootprintSources());

      final r1 = await parts.addPart(
        project.id,
        resistorSpec(footprint: 'Test:TwoPad'),
      );
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: r1.part.id,
        libId: 'Test:TwoPad',
      );
      await boards.updatePlacement(ref.copyWith(x: 35, y: 35, placed: true));

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );
      expect(find.textContaining('to place'), findsNothing);

      // The schematic gains a part while the board is open.
      await parts.addPart(project.id, capacitorSpec(footprint: 'Test:TwoPad'));
      await settleApp(tester);

      expect(find.text('1 to place'), findsOneWidget);
    });

    testAppWithStorage('a part with no footprint offers to choose one', (
      tester,
      db,
      storage,
    ) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final project = await ProjectRepository(db).create(name: 'Bare');
      await FootprintLibraryRepository(
        db,
        footprintStorage,
      ).import(nickname: 'Test', sources: twoPadFootprintSources());
      // Names nothing the library has.
      await PartRepository(db).addPart(project.id, resistorSpec(footprint: ''));

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      await tester.tap(find.text('1 to place'));
      await settleApp(tester);
      // Nothing to assign automatically, so it asks.
      expect(find.textContaining('ASSIGN'), findsNothing);
      expect(find.text('No footprint yet'), findsOneWidget);

      await tester.tap(find.text('FOOTPRINT'));
      await settleApp(tester);
      expect(find.byType(FootprintSidebar), findsOneWidget);
    });
  });

  testAppWithStorage('reported: dropping a slide keeps the whole route moved', (
    tester,
    db,
    storage,
  ) async {
    // "when you finish moving it, everything goes back to its original
    // position EXCEPT the trace piece that you were initially moving." DROP
    // was handed the preview, which already had the slide applied, and
    // worked it out a second time from there: the real diagonals were never
    // deleted and stayed exactly where they started.
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    for (final (x1, y1, x2, y2) in const [
      (31.0, 35.0, 34.0, 32.0),
      (34.0, 32.0, 41.0, 32.0),
      (41.0, 32.0, 44.0, 35.0),
    ]) {
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: x1,
        startY: y1,
        endX: x2,
        endY: y2,
        width: 0.25,
      );
    }

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    // Pick the run up from on the run, so the drag is exactly 2.5 mm.
    await _aimAt(tester, const Offset(37.5, 32));
    final painter = _painter(tester);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + painter.viewport.toScreen(const Offset(37.5, 32)),
    );
    await settleApp(tester);
    await tester.tap(find.text('Slide'));
    await settleApp(tester);
    await _aimAt(tester, const Offset(37.5, 29.5));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final tracks = await boards.getTracks(project.id);
    bool at(Offset p) => tracks.any(
      (t) =>
          (Offset(t.startX, t.startY) - p).distance < 1e-3 ||
          (Offset(t.endX, t.endY) - p).distance < 1e-3,
    );

    // The old corners are gone: nothing still meets at (34,32) or (41,32).
    expect(at(const Offset(34, 32)), isFalse, reason: 'old diagonal survived');
    expect(at(const Offset(41, 32)), isFalse, reason: 'old diagonal survived');

    // What replaced them: a 45 off each pad onto a run that got shorter.
    expect(tracks, hasLength(3));
    expect(at(const Offset(36.5, 29.5)), isTrue);
    expect(at(const Offset(38.5, 29.5)), isTrue);
  });

  group('silkscreen', () {
    testAppWithStorage('text can be added, moved and deleted', (
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

      await tester.tap(find.byIcon(Icons.text_fields).first);
      await settleApp(tester);
      await _aimAt(tester, const Offset(33, 45));
      await tester.tap(find.text('TEXT'));
      await settleApp(tester);
      expect(find.text('Add silkscreen text'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Text'), 'ZOLT');
      await tester.pump();
      await tester.tap(find.text('SAVE'));
      await settleApp(tester);
      expect(find.text('Add silkscreen text'), findsNothing);

      var texts = await boards.getTexts(project.id);
      expect(texts.single.content, 'ZOLT');
      expect(
        (texts.single.position - const Offset(33, 45)).distance,
        lessThanOrEqualTo(0.5),
      );

      // Selected on adding, so it can be moved straight away.
      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(36, 47));
      await tester.tap(find.text('DROP'));
      await settleApp(tester);

      texts = await boards.getTexts(project.id);
      expect(
        (texts.single.position - const Offset(36, 47)).distance,
        lessThanOrEqualTo(0.5),
      );

      await tester.tap(find.text('Delete'));
      await settleApp(tester);
      expect(await boards.getTexts(project.id), isEmpty);
    });

    testAppWithStorage('a designator can be hidden', (
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
      await tester.tap(find.text('Label'));
      await settleApp(tester);

      await tester.tap(find.text('Print the designator'));
      await settleApp(tester);
      await tester.tap(find.text('SAVE'));
      await settleApp(tester);

      final placed = await boards.getFootprints(project.id);
      expect(placed.firstWhere((p) => p.x == 30).labelHidden, isTrue);
    });

    testAppWithStorage('a designator can be picked up and moved', (
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
      final r1 = painter.scene.footprints.firstWhere((f) => f.ref.x == 30);
      await tester.tapAt(
        rect.topLeft + painter.viewport.toScreen(r1.labelPosition),
      );
      await settleApp(tester);
      expect(find.text('Hide'), findsOneWidget);

      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await _aimAt(tester, const Offset(30, 30));
      await tester.tap(find.text('DROP'));
      await settleApp(tester);

      final moved = (await boards.getFootprints(
        project.id,
      )).firstWhere((p) => p.x == 30);
      expect(moved.labelOffset, isNotNull);
      final lands = FootprintPlacement.of(
        moved,
      ).apply(moved.labelOffset!.dx, moved.labelOffset!.dy);
      expect((lands - const Offset(30, 30)).distance, lessThanOrEqualTo(0.5));
    });
  });

  // "PCB section needs the edge cut outline to be able to be moved. It can
  // also be sized, like the MAIN board outline"
  testAppWithStorage('the board outline can be resized from a corner', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    // A drawn outline to take hold of: a new board has none.
    final board = await boards.ensureBoard(project.id).then((b) async {
      final drawn = b.withOutline(b.outline.as(BoardOutlineKind.rectangle));
      await boards.updateBoard(drawn);
      return drawn;
    });

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final painter = _painter(tester);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft +
          painter.viewport.toScreen(
            Offset(board.outlineX, board.outlineY + board.outlineHeight / 2),
          ),
    );
    await settleApp(tester);

    // Aim at the bottom-right corner, take hold of it, and pull it out.
    await _aimAt(tester, Offset(board.right, board.bottom));
    await tester.tap(find.text('Resize'));
    await settleApp(tester);
    await _aimAt(tester, Offset(board.right + 10, board.bottom + 5));
    await tester.tap(find.text('DROP'));
    await settleApp(tester);

    final resized = (await boards.getBoard(project.id))!;
    // The opposite corner stays where it was.
    expect(resized.outlineX, closeTo(board.outlineX, 1e-6));
    expect(resized.outlineY, closeTo(board.outlineY, 1e-6));
    expect(resized.outlineWidth, closeTo(board.outlineWidth + 10, 0.51));
    expect(resized.outlineHeight, closeTo(board.outlineHeight + 5, 0.51));
  });

  // "Keepout Rules: This could be a drop down for the pour tool"
  testAppWithStorage('the Pour chip can lay a keepout instead', (
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

    final tool = find.byKey(const ValueKey('tool-zone'));
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await settleApp(tester);
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await settleApp(tester);
    await tester.tap(find.byKey(const ValueKey('pick-Keepout')));
    await settleApp(tester);

    for (final corner in const [
      Offset(30, 30),
      Offset(40, 30),
      Offset(40, 40),
    ]) {
      await _aimAt(tester, corner);
      await tester.tap(find.textContaining(RegExp('START|CORNER')));
      await settleApp(tester);
    }
    await tester.tap(find.text('Close pour'));
    await settleApp(tester);

    // No net was asked for: a keepout claims the area rather than filling
    // it, so there is nothing to fill it with.
    final zone = (await boards.getZones(project.id)).single;
    expect(zone.keepout, isTrue);
    expect(zone.netId, isNull);
    expect(zone.noTracks, isTrue);
    expect(zone.noVias, isTrue);
  });

  // "Object locking: Can be great for pours, components, but also entire
  // traced nets, not just the individual traces"
  testAppWithStorage('a locked part stays put, and a whole net can be held', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    final nets = await NetRepository(db).getNets(project.id);
    for (final at in [const Offset(30, 30), const Offset(36, 30)]) {
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: at.dx,
        startY: at.dy,
        endX: at.dx + 5,
        endY: at.dy,
        width: 0.25,
        netId: nets.first.net.id,
      );
    }

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    Future<void> tapAt(Offset board) async {
      await tester.tapAt(
        rect.topLeft + _painter(tester).viewport.toScreen(board),
      );
      await settleApp(tester);
    }

    // One track held, and then its whole net.
    await tapAt(const Offset(32, 30));
    expect(find.text('Slide'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('track-lock')));
    await settleApp(tester);
    expect(
      (await boards.getTracks(project.id)).where((t) => t.locked),
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey('net-lock')));
    await settleApp(tester);
    expect(
      (await boards.getTracks(project.id)).every((t) => t.locked),
      isTrue,
      reason: 'the whole net is held, not just the one segment',
    );

    // A held part cannot be picked up, and says so rather than doing
    // nothing.
    final part = _painter(tester).scene.footprints.first;
    await tapAt(Offset(part.ref.x, part.ref.y));
    await tester.tap(find.byKey(const ValueKey('part-lock')));
    await settleApp(tester);
    expect(
      (await boards.getFootprints(project.id)).any((f) => f.locked),
      isTrue,
    );
    expect(find.text('Unlock'), findsOneWidget);

    // And a swept box leaves everything held behind rather than catching
    // it and then refusing to move it.
    await tester.tap(find.byIcon(Icons.crop_free).first);
    await settleApp(tester);
    for (final corner in [const Offset(20, 20), const Offset(60, 55)]) {
      await _aimAt(tester, corner);
      await tester.tap(find.textContaining(RegExp('CORNER|FINISH')));
      await settleApp(tester);
    }
    // Two parts and two tracks are inside the box; one part and both
    // tracks are held, so one thing is left to move.
    expect(find.text('Move 1'), findsOneWidget);
  });

  // "I wish VIAs AND traces to have properties where we can choose what net
  // they belong to ... when you have an exposed pad and you want to put
  // vias down for better temperature control, you ideally want to see these
  // vias to ground as well"
  testAppWithStorage('a via can be put on a net by hand', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, boards) = await _board(db, footprintStorage);
    final nets = await NetRepository(db).getNets(project.id);
    await boards.addVia(
      projectId: project.id,
      x: 36,
      y: 40,
      diameter: 0.8,
      drill: 0.4,
    );

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );

    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + _painter(tester).viewport.toScreen(const Offset(36, 40)),
    );
    await settleApp(tester);
    await tester.tap(find.text('Properties'));
    await settleApp(tester);

    // It arrived on no net, which is what a via dropped in an exposed pad
    // with nothing under it gets.
    expect(find.text('No net — unconnected copper'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('copper-net')));
    await settleApp(tester);
    await tester.tap(find.text(nets.first.displayName).last);
    await settleApp(tester);
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    final saved = await boards.getVias(project.id);
    expect(saved.single.netId, nets.first.net.id);
  });

  // "choose the centre of the MCU, and choose the centre of the board, and
  // set the relative properties of X and Y to 0 and 0"
  testAppWithStorage('a part can be centred on the board by its middle', (
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
    final tapped = painter.scene.footprints.firstWhere((f) => f.ref.x == 30);
    final rect = tester.getRect(find.byType(PrecisionBoardPanel));
    await tester.tapAt(
      rect.topLeft + painter.viewport.toScreen(const Offset(30, 35)),
    );
    await settleApp(tester);
    await tester.tap(find.text('Properties'));
    await settleApp(tester);
    await tester.tap(find.text('Centre on board'));
    await settleApp(tester);
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    final scene = _painter(tester).scene;
    final part = scene.footprints.firstWhere((f) => f.ref.id == tapped.ref.id);
    final placed = (await boards.getFootprints(
      project.id,
    )).firstWhere((p) => p.id == part.ref.id);
    final middle = FootprintPlacement.of(placed).apply(
      footprintBounds(part.definition!).center.dx,
      footprintBounds(part.definition!).center.dy,
    );
    final centre = scene.outline.bounds.center;
    expect((middle - centre).distance, lessThan(1e-6));
  });

  // "the user is holding their phone in landscape ... both their thumbs are
  // on either side ... when we hover over something, like a component, we
  // can select it with our RIGHT thumb"
  testAppWithStorage('the sight button selects what it is over, then picks '
      'it up', (tester, db, storage) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, _) = await _board(db, footprintStorage);

    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );
    Finder sightButton() => find.descendant(
      of: find.byKey(const ValueKey('aim-bar')),
      matching: find.byType(FilledButton),
    );

    // Over empty board, nothing to press.
    await _aimAt(tester, const Offset(38, 25));
    expect(sightButton(), findsNothing);

    // Over R1, the button offers it — no tap in the middle of the screen.
    await _aimAt(tester, const Offset(30, 35));
    expect(find.text('SELECT R1'), findsOneWidget);
    await tester.tap(sightButton());
    await settleApp(tester);

    // Its actions are on the left, where the other thumb is.
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Footprint'), findsOneWidget);

    // Pressed again, over the part now selected, it picks it up.
    expect(find.text('MOVE R1'), findsOneWidget);
    await tester.tap(sightButton());
    await settleApp(tester);
    expect(find.text('DROP'), findsOneWidget);
  });

  // "we have 'sharp corners' or 1 mm by default but the user can add a
  // specific radius if so desired, kind of how we have net classes"
  testAppWithStorage('a corner radius of your own is kept with the project', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, _) = await _board(db, footprintStorage);

    Future<void> open() async {
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );
      // Along the strip at the top, which scrolls.
      await tester.dragUntilVisible(
        find.byIcon(Icons.rounded_corner),
        find.byType(ListView).first,
        const Offset(-120, 0),
      );
      await tester.ensureVisible(find.byIcon(Icons.rounded_corner).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.rounded_corner).first);
      await settleApp(tester);
    }

    await open();
    // The two every board has.
    expect(find.text('Sharp'), findsOneWidget);
    expect(find.text('1 mm'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('corner-radius-field')),
      '0.75',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('corner-radius-add')));
    await settleApp(tester);
    // Chosen at once: the strip says so.
    expect(find.text('r0.75'), findsOneWidget);

    // Opened again, it is there to pick, and can be taken away.
    await tester.pumpWidget(const SizedBox.shrink());
    await open();
    expect(find.byKey(const ValueKey('corner-radius-0.75')), findsOneWidget);
    await tester.tap(find.byTooltip('Remove 0.75 mm'));
    await settleApp(tester);
    expect(find.byKey(const ValueKey('corner-radius-0.75')), findsNothing);
    expect(find.text('Sharp'), findsOneWidget, reason: 'built-ins stay');
  });

  // "for the grid choice, similar to what we just did for rounding corners,
  // I think there should be a default option and then classes that the
  // user can add"
  testAppWithStorage('a grid of your own is kept with the project', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final (project, _) = await _board(db, footprintStorage);

    Future<void> open() async {
      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );
      await tester.tap(find.text('0.5 mm').first);
      await settleApp(tester);
    }

    await open();
    expect(find.text('0.5 mm · default'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('grid-field')), '2.54');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('grid-add')));
    await settleApp(tester);
    expect(find.text('2.54 mm'), findsOneWidget, reason: 'the strip says so');

    // Free turns snapping off.
    await tester.tap(find.text('2.54 mm'));
    await settleApp(tester);
    await tester.tap(find.text('Free'));
    await settleApp(tester);
    expect(find.text('free'), findsWidgets);

    // Opened again, the added grid is there to pick, and can go.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(
      tester,
      Scaffold(body: PrecisionBoardPanel(project: project)),
      database: db,
      footprintStorage: footprintStorage,
    );
    await tester.tap(find.text('0.5 mm').first);
    await settleApp(tester);
    expect(find.text('2.54 mm · 0.1 in'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove 2.54 mm'));
    await settleApp(tester);
    expect(find.text('2.54 mm · 0.1 in'), findsNothing);
    expect(find.text('0.5 mm · default'), findsOneWidget);
  });

  testAppWithStorage(
    'holes, fiducials and test points go down where the crosshair is',
    (tester, db, storage) async {
      final footprintStorage = InMemoryLibraryStorageFor();
      final (project, boards) = await _board(db, footprintStorage);

      await pumpApp(
        tester,
        Scaffold(body: PrecisionBoardPanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // Holes live under the Via chip: tap it to take it up, tap it again
      // for the menu of what else it puts down.
      final tool = find.byKey(const ValueKey('tool-via'));
      await tester.ensureVisible(tool);
      await tester.pump();
      await tester.tap(tool);
      await settleApp(tester);
      await tester.ensureVisible(tool);
      await tester.pump();
      await tester.tap(tool);
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('pick-Mounting hole')));
      await settleApp(tester);
      expect(find.text('HOLE'), findsOneWidget);

      // And the chip beside it says which hole, and changes it.
      await tester.tap(find.byKey(const ValueKey('feature-choose')));
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('hole-M2.5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('feature-ok')));
      await settleApp(tester);

      for (final x in [36.0, 40.0]) {
        await _aimAt(tester, Offset(x, 28));
        await tester.tap(find.text('HOLE'));
        await settleApp(tester);
      }
      final features = await boards.getFeatures(project.id);
      expect([for (final f in features) f.reference], ['H1', 'H2']);
      expect(features.first.size, 2.7);
      expect((features.first.x - 36).abs(), lessThanOrEqualTo(0.5));
    },
  );

  testAppWithStorage('a measurement is kept as a dimension', (
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

    final tool = find.byIcon(Icons.straighten).first;
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await settleApp(tester);
    await _aimAt(tester, const Offset(30, 30));
    await tester.tap(find.text('FROM'));
    await settleApp(tester);
    await _aimAt(tester, const Offset(40, 30));
    await tester.tap(find.text('TO'));
    await settleApp(tester);

    await tester.tap(find.byKey(const ValueKey('measure-keep')));
    await settleApp(tester);
    final kept = await boards.getDimensions(project.id);
    expect(kept.single.length, closeTo(10, 1));
    expect(_painter(tester).scene.dimensions, hasLength(1));
  });

  testAppWithStorage('a bus catches connections in a box and lays them', (
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
    final line = _painter(tester).scene.ratsnest.single;

    // A bus is a way of routing, so it is picked from the Route chip.
    final tool = find.byKey(const ValueKey('tool-route'));
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await settleApp(tester);
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await settleApp(tester);
    await tester.tap(find.byKey(const ValueKey('pick-Bus')));
    await settleApp(tester);

    // A box round one end of the connection.
    await _aimAt(tester, line.from - const Offset(3, 3));
    await tester.tap(find.text('BOX'));
    await settleApp(tester);
    await _aimAt(tester, line.from + const Offset(3, 3));
    await tester.tap(find.text('CATCH'));
    await settleApp(tester);
    expect(find.textContaining('1 connections'), findsOneWidget);

    // The path: out and along.
    for (final at in [
      line.from + const Offset(0, -4),
      line.to + const Offset(0, -4),
    ]) {
      await _aimAt(tester, at);
      await tester.tap(find.text('CORNER'));
      await settleApp(tester);
    }
    expect(_painter(tester).pendingBus, hasLength(1));
    await tester.tap(find.text('Lay 1'));
    await settleApp(tester);

    final tracks = await boards.getTracks(project.id);
    expect(tracks, isNotEmpty);
    expect(tracks.map((t) => t.netId).toSet(), hasLength(1));
    // Pad to pad: the copper starts on one end and finishes on the other.
    final ends = {
      for (final t in tracks) ...[
        Offset(t.startX, t.startY),
        Offset(t.endX, t.endY),
      ],
    };
    expect(ends, contains(line.from));
    expect(ends, contains(line.to));
  });
}
