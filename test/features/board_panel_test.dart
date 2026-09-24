import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/features/board/board_painter.dart';
import 'package:zolt/features/board/board_panel.dart';
import 'package:zolt/features/board/design_rules_dialog.dart';
import 'package:zolt/features/project/project_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  _pinchZoomTests();
  _gestureTests();
  _padTapTests();

  testAppWithStorage('the board explains itself before there is a schematic', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'P');

    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: project)),
      database: db,
      storage: storage,
    );

    expect(find.text('Nothing to lay out yet'), findsOneWidget);
  });

  testAppWithStorage('a part with no footprint is offered one', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'P');
    await PartRepository(db).addPart(project.id, resistorSpec());

    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: project)),
      database: db,
      storage: storage,
    );

    // The strip along the top is the board's to-do list: R1 has no
    // footprint, so it appears there as something to deal with, carrying the
    // "choose a footprint" icon rather than the "put it down" one.
    expect(find.widgetWithText(ActionChip, 'R1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ActionChip, 'R1'),
        matching: find.byIcon(Icons.dashboard_customize_outlined),
      ),
      findsOneWidget,
    );
  });

  testAppWithStorage('the board counts what is left to route', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final project = await ProjectRepository(db).create(name: 'P');
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final boards = BoardRepository(db);
    final footprints = FootprintLibraryRepository(db, footprintStorage);

    await footprints.import(
      nickname: 'Test',
      sources: twoPadFootprintSources(),
    );

    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await nets.connectPins(
      r1.pins.firstWhere((p) => p.number == '2').id,
      r2.pins.firstWhere((p) => p.number == '1').id,
    );

    await boards.ensureBoard(project.id);
    for (final (part, x) in [(r1, 30.0), (r2, 45.0)]) {
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: part.part.id,
        libId: 'Test:TwoPad',
      );
      await boards.updatePlacement(ref.copyWith(x: x, y: 30, placed: true));
    }

    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: project)),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );

    expect(find.text('1 to route'), findsOneWidget);
    // Both placed, so nothing is left on the to-do strip.
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Front'), findsWidgets);
  });

  testAppWithStorage('the board is reachable from the project rail', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Preamp');

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
      storage: storage,
    );

    await openRail(tester);
    await tester.tap(find.text('Board').last);
    await settleApp(tester);

    expect(find.text('Nothing to lay out yet'), findsOneWidget);
  });

  testAppWithStorage('board settings fit a landscape phone without clipping', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'P');
    final board = await BoardRepository(db).ensureBoard(project.id);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDesignRulesDialog(context, board: board),
            child: const Text('open'),
          ),
        ),
      ),
      database: db,
      storage: storage,
      // The real thing: a short viewport is what pushed the first row of
      // labels up behind the dialog's title.
      size: const Size(1600, 720),
    );

    await tester.tap(find.text('open'));
    await settleApp(tester);

    // Every setting is present and laid out, not overflowing off the box.
    for (final label in [
      'Track width',
      'Clearance',
      'Via diameter',
      'Via drill',
      'Grid',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // The title and the first field must not occupy the same pixels.
    final title = tester.getRect(find.text('Design rules'));
    final trackWidth = tester.getRect(find.text('Track width'));
    expect(
      trackWidth.top,
      greaterThanOrEqualTo(title.bottom),
      reason: 'the Track width label is clipped behind the title',
    );

    expect(tester.takeException(), isNull);
  });
}

void _pinchZoomTests() {
  // Reported: a pinch on the board "zooms into infinity". The gesture's
  // scale is cumulative from the moment it starts, and applying it to the
  // already-zoomed view on every frame compounded it. This drives a real
  // two-finger gesture — something adb cannot synthesise — and checks the
  // zoom lands where the fingers say it should.
  testAppWithStorage(
    'a two-finger pinch zooms by the pinch, not exponentially',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'P');
      await PartRepository(db).addPart(project.id, resistorSpec());

      await pumpApp(
        tester,
        Scaffold(body: BoardPanel(project: project)),
        database: db,
        storage: storage,
      );

      double zoom() {
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(BoardPanel),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        return (paint.painter! as BoardPainter).viewport.pixelsPerMm;
      }

      final centre = tester.getCenter(find.byType(BoardPanel));

      final first = await tester.startGesture(centre - const Offset(50, 0));
      final second = await tester.startGesture(
        centre + const Offset(50, 0),
        pointer: 2,
      );

      Future<void> spreadTo(double halfSpan) async {
        await first.moveTo(centre - Offset(halfSpan, 0));
        await second.moveTo(centre + Offset(halfSpan, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Get the pinch recognised first. Flutter measures scale from the span
      // at recognition, not from first contact, so the opening few pixels are
      // a dead zone in every app — that part is the framework's business.
      for (var half = 55.0; half <= 80; half += 5) {
        await spreadTo(half);
      }
      final zoomAtMid = zoom();

      // From here the zoom has to track the fingers exactly, frame after
      // frame. Compounding — the reported bug — shows up as this ratio
      // growing geometrically with the number of frames instead.
      const midSpan = 160.0;
      const endSpan = 320.0;
      for (var half = 85.0; half <= endSpan / 2; half += 5) {
        await spreadTo(half);
      }
      final zoomAtEnd = zoom();

      await first.up();
      await second.up();
      await settleApp(tester);

      final ratio = zoomAtEnd / zoomAtMid;
      expect(
        ratio,
        closeTo(endSpan / midSpan, 0.05),
        reason: 'spreading the fingers 2x zoomed ${ratio}x',
      );
    },
  );
}

/// A small routed-or-routable board: two resistors 15 mm apart, joined by
/// one net, with footprints assigned and placed.
Future<({String projectId, Project project})> _twoResistorBoard(
  AppDatabase db,
  InMemoryLibraryStorage footprintStorage,
) async {
  final project = await ProjectRepository(db).create(name: 'P');
  final parts = PartRepository(db);
  final nets = NetRepository(db);
  final boards = BoardRepository(db);

  await FootprintLibraryRepository(
    db,
    footprintStorage,
  ).import(nickname: 'Test', sources: twoPadFootprintSources());

  final r1 = await parts.addPart(project.id, resistorSpec());
  final r2 = await parts.addPart(project.id, resistorSpec());
  await nets.connectPins(
    r1.pins.firstWhere((p) => p.number == '2').id,
    r2.pins.firstWhere((p) => p.number == '1').id,
  );

  final board = await boards.ensureBoard(project.id);
  final centre = board.outline.bounds.center;
  for (final (part, dx) in [(r1, -7.5), (r2, 7.5)]) {
    final ref = await boards.assignFootprint(
      projectId: project.id,
      partId: part.part.id,
      libId: 'Test:TwoPad',
    );
    await boards.updatePlacement(
      ref.copyWith(x: centre.dx + dx, y: centre.dy, placed: true),
    );
  }
  return (projectId: project.id, project: project);
}

BoardPainter _boardPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BoardPainter>()
    .single;

void _gestureTests() {
  // Reported: dragging a footprint was "laggy". It was worse than lag — the
  // drag was tracked but never drawn, so the part sat still under the finger
  // and jumped on release. This checks the part is where the finger is
  // *during* the drag, before anything has been committed.
  testAppWithStorage('a footprint follows the finger while it is dragged', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final setup = await _twoResistorBoard(db, footprintStorage);

    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: setup.project)),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );

    final before = _boardPainter(tester);
    final r1 = before.scene.footprints.firstWhere(
      (f) => f.part.reference == 'R1',
    );
    final start = before.viewport.toScreen(r1.bounds.center);

    final gesture = await tester.startGesture(start);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(start + Offset(0, 8.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Still holding on: the painted scene must already show R1 moved.
    final during = _boardPainter(tester);
    final moved = during.scene.footprints.firstWhere(
      (f) => f.part.reference == 'R1',
    );
    expect(
      moved.ref.y,
      greaterThan(r1.ref.y + 1),
      reason: 'R1 did not move under the finger before release',
    );

    await gesture.up();
    await settleApp(tester);
  });

  // Reported: routing by tapping made the trace jump wherever you poked.
  // Routing is now a drag from a pad; letting go on a pad of the same net
  // finishes the track, and the ratsnest line it satisfies disappears.
  testAppWithStorage('dragging from pad to pad routes the connection', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final setup = await _twoResistorBoard(db, footprintStorage);

    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: setup.project)),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );

    expect(find.text('1 to route'), findsOneWidget);

    await tester.tap(find.text('Route'));
    await settleApp(tester);

    final painter = _boardPainter(tester);
    final from = painter.scene.pads.firstWhere((p) => p.label == 'R1.2');
    final to = painter.scene.pads.firstWhere((p) => p.label == 'R2.1');
    final start = painter.viewport.toScreen(from.position);
    final end = painter.viewport.toScreen(to.position);

    final gesture = await tester.startGesture(start);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settleApp(tester);

    final tracks = await BoardRepository(db).getTracks(setup.projectId);
    expect(tracks, isNotEmpty, reason: 'no track was committed');
    expect(find.text('Routed'), findsOneWidget);
  });
}

void _padTapTests() {
  Future<({BoardPainter painter, String projectId})> openInRouteMode(
    WidgetTester tester,
    AppDatabase db,
    LibraryFileStorage storage, {
    bool wired = true,
  }) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final setup = await _twoResistorBoard(db, footprintStorage);
    if (!wired) {
      final nets = NetRepository(db);
      for (final net in await nets.getNets(setup.projectId)) {
        await nets.deleteNet(net.id);
      }
    }
    await pumpApp(
      tester,
      Scaffold(body: BoardPanel(project: setup.project)),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );
    await tester.tap(find.text('Route'));
    await settleApp(tester);
    return (painter: _boardPainter(tester), projectId: setup.projectId);
  }

  Offset screenOf(BoardPainter painter, String label) =>
      painter.viewport.toScreen(
        painter.scene.pads.firstWhere((p) => p.label == label).position,
      );

  testAppWithStorage('tapping one pad then another routes between them', (
    tester,
    db,
    storage,
  ) async {
    final open = await openInRouteMode(tester, db, storage);

    await tester.tapAt(screenOf(open.painter, 'R1.2'));
    await settleApp(tester);
    await tester.tapAt(screenOf(open.painter, 'R2.1'));
    await settleApp(tester);

    expect(await BoardRepository(db).getTracks(open.projectId), isNotEmpty);
  });

  testAppWithStorage('pads not yet wired in the schematic can be joined', (
    tester,
    db,
    storage,
  ) async {
    // Reported: pads could not be connected together. A pad whose pin has
    // no schematic net was refused outright, and the refusal was a pop-up.
    final open = await openInRouteMode(tester, db, storage, wired: false);

    await tester.tapAt(screenOf(open.painter, 'R1.2'));
    await settleApp(tester);
    await tester.tapAt(screenOf(open.painter, 'R2.1'));
    await settleApp(tester);

    final tracks = await BoardRepository(db).getTracks(open.projectId);
    expect(tracks, isNotEmpty, reason: 'no track was drawn');

    // The board made the connection, so the schematic has it too: a board
    // whose copper joins two pins the schematic says are separate would
    // export as a short.
    final nets = await NetRepository(db).getNets(open.projectId);
    expect(nets, hasLength(1));
    expect(
      nets.single.endpoints.map((e) => '${e.part.reference}.${e.pin.number}'),
      containsAll(['R1.2', 'R2.1']),
    );
    expect(tracks.every((t) => t.netId == nets.single.net.id), isTrue);
  });

  testAppWithStorage('a pad on the other copper layer is still reachable', (
    tester,
    db,
    storage,
  ) async {
    final open = await openInRouteMode(tester, db, storage);

    // Switch to the back: the test footprint's pads are front-only.
    await tester.tap(find.text('Front').last);
    await settleApp(tester);

    await tester.tapAt(screenOf(open.painter, 'R1.2'));
    await settleApp(tester);
    await tester.tapAt(screenOf(open.painter, 'R2.1'));
    await settleApp(tester);

    final tracks = await BoardRepository(db).getTracks(open.projectId);
    expect(tracks, isNotEmpty, reason: 'the front pads were ignored');
    expect(tracks.every((t) => t.layer == CopperLayer.front), isTrue);
  });

  testAppWithStorage('no pop-up appears when a route is started', (
    tester,
    db,
    storage,
  ) async {
    final open = await openInRouteMode(tester, db, storage);
    // A tap on empty board used to raise "Touch a pad and drag to route".
    await tester.tapAt(open.painter.viewport.toScreen(const Offset(25, 25)));
    await settleApp(tester);
    expect(find.byType(SnackBar), findsNothing);
  });
}
