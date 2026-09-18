import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/board_sync.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';

void main() {
  late AppDatabase db;
  late PartRepository parts;
  late BoardRepository boards;
  late NetRepository nets;
  late BoardSync sync;
  late String projectId;

  const twoPad = 'Test:TwoPad';

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    boards = BoardRepository(db);
    nets = NetRepository(db);
    final footprints = FootprintLibraryRepository(
      db,
      InMemoryLibraryStorageFor(),
    );
    await footprints.import(
      nickname: 'Test',
      sources: twoPadFootprintSources(),
    );
    sync = BoardSync(parts: parts, boards: boards, footprints: footprints);
    projectId = (await ProjectRepository(db).create(name: 'Sync')).id;
    await boards.ensureBoard(projectId);
  });
  tearDown(() => db.close());

  test(
    'a board already in step with the schematic has nothing to do',
    () async {
      final r1 = await parts.addPart(
        projectId,
        resistorSpec(footprint: twoPad),
      );
      await boards.assignFootprint(
        projectId: projectId,
        partId: r1.part.id,
        libId: twoPad,
      );
      final plan = await sync.plan(projectId);
      expect(plan.hasWork, isFalse);
    },
  );

  test('new parts are added and placed on the board, apart', () async {
    await parts.addPart(projectId, resistorSpec(footprint: twoPad));
    await parts.addPart(projectId, resistorSpec(footprint: twoPad));

    final plan = await sync.plan(projectId);
    expect(plan.of(BoardSyncKind.add).map((c) => c.reference), ['R1', 'R2']);

    await sync.apply(projectId, plan);
    final placed = await boards.getFootprints(projectId);
    expect(placed, hasLength(2));
    expect(placed.every((f) => f.placed), isTrue);
    expect(placed.every((f) => f.libId == twoPad), isTrue);
    expect(
      (Offset(placed[0].x, placed[0].y) - Offset(placed[1].x, placed[1].y))
          .distance,
      greaterThan(2),
      reason: 'not piled on the same spot',
    );
    expect((await sync.plan(projectId)).hasWork, isFalse);
  });

  test(
    'a changed footprint field swaps the footprint where it stands',
    () async {
      final r1 = await parts.addPart(
        projectId,
        resistorSpec(footprint: twoPad),
      );
      final ref = await boards.assignFootprint(
        projectId: projectId,
        partId: r1.part.id,
        libId: 'Test:Old',
      );
      await boards.updatePlacement(
        ref.copyWith(x: 33, y: 21, rotation: 90, placed: true),
      );

      final plan = await sync.plan(projectId);
      final swap = plan.of(BoardSyncKind.swap).single;
      expect(swap.previousLibId, 'Test:Old');
      expect(swap.libId, twoPad);

      await sync.apply(projectId, plan);
      final after = (await boards.getFootprints(projectId)).single;
      expect(after.libId, twoPad);
      expect((after.x, after.y, after.rotation), (33.0, 21.0, 90.0));
    },
  );

  test('a part taken off the board loses its footprint', () async {
    final r1 = await parts.addPart(projectId, resistorSpec(footprint: twoPad));
    await boards.assignFootprint(
      projectId: projectId,
      partId: r1.part.id,
      libId: twoPad,
    );
    await parts.updatePart(r1.part.copyWith(onBoard: false));

    final plan = await sync.plan(projectId);
    expect(plan.of(BoardSyncKind.remove).single.reference, 'R1');
    await sync.apply(projectId, plan);
    expect(await boards.getFootprints(projectId), isEmpty);
  });

  test('what it cannot do is reported, not guessed at', () async {
    await parts.addPart(projectId, resistorSpec(footprint: 'Nowhere:R_0603'));
    await parts.addPart(projectId, resistorSpec(footprint: ''));
    final plan = await sync.plan(projectId);
    expect(
      plan.of(BoardSyncKind.missingLibrary).single.libId,
      'Nowhere:R_0603',
    );
    expect(plan.of(BoardSyncKind.noFootprint).single.reference, 'R2');
    expect(plan.actionCount, 0);

    await sync.apply(projectId, plan);
    expect(await boards.getFootprints(projectId), isEmpty);
  });

  test('copper left on no net is cleared, and comes back on undo', () async {
    final r1 = await parts.addPart(projectId, resistorSpec(footprint: twoPad));
    final r2 = await parts.addPart(projectId, resistorSpec(footprint: twoPad));
    final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
    for (final r in [r1, r2]) {
      await boards.assignFootprint(
        projectId: projectId,
        partId: r.part.id,
        libId: twoPad,
      );
    }
    await boards.addTrack(
      projectId: projectId,
      layer: CopperLayer.front,
      startX: 0,
      startY: 0,
      endX: 5,
      endY: 0,
      width: 0.25,
      netId: net.id,
    );
    // The schematic drops the connection; the track is left on no net.
    await nets.deleteNet(net.id);
    expect((await boards.getTracks(projectId)).single.netId, isNull);

    final plan = await sync.plan(projectId);
    expect(plan.orphanTracks, 1);
    final undo = await sync.apply(projectId, plan);
    expect(await boards.getTracks(projectId), isEmpty);

    await sync.undo(undo);
    expect(await boards.getTracks(projectId), hasLength(1));
    await sync.redo(undo);
    expect(await boards.getTracks(projectId), isEmpty);
  });

  test('undo puts every footprint back exactly', () async {
    final r1 = await parts.addPart(projectId, resistorSpec(footprint: twoPad));
    final kept = await boards.assignFootprint(
      projectId: projectId,
      partId: r1.part.id,
      libId: 'Test:Old',
    );
    await boards.updatePlacement(kept.copyWith(x: 5, y: 6, placed: true));
    await parts.addPart(projectId, resistorSpec(footprint: twoPad));

    final before = await boards.getFootprints(projectId);
    final undo = await sync.apply(projectId, await sync.plan(projectId));
    expect(await boards.getFootprints(projectId), hasLength(2));

    await sync.undo(undo);
    final after = await boards.getFootprints(projectId);
    expect(
      after.map((f) => (f.id, f.libId, f.x, f.y)),
      before.map((f) => (f.id, f.libId, f.x, f.y)),
    );
  });
}
