import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

import '../helpers/fixtures.dart';

/// "labels that connect wires without drawing them" — and the grounds that
/// were quietly separate nets on the board.
void main() {
  late AppDatabase db;
  late PartRepository parts;
  late NetRepository nets;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    nets = NetRepository(db);
    project = await ProjectRepository(db).create(name: 'Names');
  });

  tearDown(() async => db.close());

  Future<String> pinOf(NewPartSpec spec, [int index = 0]) async =>
      (await parts.addPart(project.id, spec)).pins[index].id;

  test('naming a net after another joins them', () async {
    final a = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    final b = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    await nets.renameNet(a.net.id, 'SDA');
    final survivor = await nets.renameNet(b.net.id, 'SDA');

    final all = await nets.getNets(project.id);
    expect(all, hasLength(1));
    expect(all.single.net.id, survivor);
    expect(all.single.endpoints, hasLength(4));
  });

  test('different names stay apart, and names are exact', () async {
    final a = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    final b = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    await nets.renameNet(a.net.id, 'SDA');
    await nets.renameNet(b.net.id, 'sda');
    expect(await nets.getNets(project.id), hasLength(2));
  });

  test('two ground symbols are one ground', () async {
    final r1 = await pinOf(resistorSpec());
    final r2 = await pinOf(resistorSpec());
    await nets.connectPins(r1, await pinOf(groundSpec()));
    await nets.connectPins(r2, await pinOf(groundSpec()));

    final all = await nets.getNets(project.id);
    expect(all, hasLength(1));
    expect(all.single.net.name, 'GND');
    expect(all.single.endpoints.map((e) => e.pin.id), containsAll([r1, r2]));
  });

  test('routed copper follows a merge instead of losing its net', () async {
    final boards = BoardRepository(db);
    final a = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    final b = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    for (final net in [a, b]) {
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 0,
        startY: 0,
        endX: 1,
        endY: 0,
        width: 0.25,
        netId: net.net.id,
      );
    }
    await nets.renameNet(a.net.id, 'VBUS');
    final survivor = await nets.renameNet(b.net.id, 'VBUS');

    final tracks = await boards.getTracks(project.id);
    expect(tracks.map((t) => t.netId), everyElement(survivor));
  });

  test('a snapshot taken first splits a join back apart', () async {
    final a = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    final b = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    await nets.renameNet(a.net.id, 'SDA');

    final snapshot = await nets.capture(project.id, [
      for (final e in b.endpoints) e.pin.id,
      ...await nets.pinsNamed(project.id, 'SDA'),
    ]);
    await nets.renameNet(b.net.id, 'SDA');
    expect(await nets.getNets(project.id), hasLength(1));

    await nets.restore(snapshot);
    final all = await nets.getNets(project.id);
    expect(all, hasLength(2));
    expect(all.where((n) => n.net.name == 'SDA'), hasLength(1));
  });

  test('the upgrade joins duplicates a design already had', () async {
    final a = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    final b = await nets.connectPins(
      await pinOf(resistorSpec()),
      await pinOf(resistorSpec()),
    );
    // Written behind the repository's back, the way v12 could leave them.
    for (final net in [a, b]) {
      await (db.update(db.nets)..where((t) => t.id.equals(net.net.id))).write(
        const NetsCompanion(name: Value('GND')),
      );
    }
    expect(await nets.getNets(project.id), hasLength(2));

    await db.joinSameNamedNets();
    final all = await nets.getNets(project.id);
    expect(all, hasLength(1));
    expect(all.single.endpoints, hasLength(4));
  });
}
