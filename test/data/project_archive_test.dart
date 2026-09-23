import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/archive/project_archive.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/snapshot_repository.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

import '../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late NetRepository nets;
  late BoardRepository boards;

  setUp(() {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    boards = BoardRepository(db);
  });
  tearDown(() => db.close());

  /// Two resistors on a named net, a drawn wire, a board with a footprint,
  /// a track and a via — one of everything the archive has to carry.
  Future<String> divider() async {
    final project = await projects.create(name: 'Divider');
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
    final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
    await nets.renameNet(net.net.id, 'MID');
    await nets.addWire(
      projectId: project.id,
      netId: net.net.id,
      points: const [Offset(0, 0), Offset(10, 0)],
      pinAId: r1.pins.first.id,
      pinBId: r2.pins.first.id,
    );
    await boards.ensureBoard(project.id);
    await boards.assignFootprint(
      projectId: project.id,
      partId: r1.part.id,
      libId: 'Resistor_SMD:R_0603_1608Metric',
    );
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 1,
      startY: 2,
      endX: 3,
      endY: 4,
      width: 0.3,
      netId: net.net.id,
    );
    await boards.addVia(
      projectId: project.id,
      x: 3,
      y: 4,
      diameter: 0.8,
      drill: 0.4,
      netId: net.net.id,
    );
    return project.id;
  }

  test('a backup holds every row the project owns and nothing else', () async {
    final id = await divider();
    // Another project, which must not leak into the first one's backup.
    final other = await projects.create(name: 'Other');
    await parts.addPart(other.id, resistorSpec());

    final archive = await ProjectArchiver(db).capture(id);

    expect(archive.projectName, 'Divider');
    expect(archive.count('parts'), 2);
    expect(archive.count('part_pins'), 4);
    expect(archive.count('part_units'), 2);
    expect(archive.count('nets'), 1);
    expect(archive.count('net_nodes'), 2);
    expect(archive.count('schematic_wires'), 1);
    expect(archive.count('boards'), 1);
    expect(archive.count('board_footprints'), 1);
    expect(archive.count('board_tracks'), 1);
    expect(archive.count('board_vias'), 1);
  });

  test('a backup file survives the trip through bytes', () async {
    final id = await divider();
    final archive = await ProjectArchiver(db).capture(id);

    final bytes = archive.toBytes();
    // Gzipped: the magic number, and much smaller than the JSON.
    expect(bytes.take(2), [0x1f, 0x8b]);
    expect(bytes.length, lessThan(archive.encode().length));

    final back = ProjectArchive.fromBytes(bytes);
    expect(back.projectName, 'Divider');
    expect(back.count('part_pins'), 4);
  });

  test('restoring a backup adds a working copy beside the original', () async {
    final id = await divider();
    final archive = ProjectArchive.fromBytes(
      (await ProjectArchiver(db).capture(id)).toBytes(),
    );

    final copyId = await ProjectArchiver(db).restoreAsNew(archive);

    expect(copyId, isNot(id));
    expect((await projects.getAll()).length, 2);

    // Fresh ids throughout, and the relationships follow them.
    final original = await parts.getPartsWithDetails(id);
    final copy = await parts.getPartsWithDetails(copyId);
    expect(copy.map((p) => p.part.reference), ['R1', 'R2']);
    expect(
      copy
          .map((p) => p.part.id)
          .toSet()
          .intersection(original.map((p) => p.part.id).toSet()),
      isEmpty,
    );

    final copyNets = await nets.getNets(copyId);
    expect(copyNets.single.net.name, 'MID');
    expect(copyNets.single.endpoints.length, 2);
    final copyPins = {for (final p in copy) ...p.pins.map((pin) => pin.id)};
    expect(
      copyNets.single.endpoints.every((e) => copyPins.contains(e.pin.id)),
      isTrue,
      reason: 'the net joins the copy\'s own pins, not the original\'s',
    );

    final wire = (await nets.getWires(copyId)).single;
    expect(wire.netId, copyNets.single.net.id);
    expect(copyPins.contains(wire.pinAId), isTrue);

    final tracks = await boards.getTracks(copyId);
    expect(tracks.single.netId, copyNets.single.net.id);
    expect(tracks.single.width, 0.3);
    expect(
      (await boards.getFootprints(copyId)).single.partId,
      copy.first.part.id,
    );

    // Editing the copy leaves the original alone.
    await parts.deletePart(copy.first.part.id);
    expect((await parts.getPartsWithDetails(id)).length, 2);
  });

  test('a backup that is not one is refused, not half-imported', () {
    expect(
      () => ProjectArchive.fromBytes('hello'.codeUnits),
      throwsFormatException,
    );
    expect(
      () => ProjectArchive.decode('{"format":"something-else"}'),
      throwsFormatException,
    );
  });

  test('a column the archive does not know is left at its default', () async {
    final id = await divider();
    final archive = await ProjectArchiver(db).capture(id);
    // As if written by an older version, before board stackups existed,
    // and by a newer one with a column this version has never heard of.
    for (final row in archive.tables['boards']!) {
      row.remove('copper_layers');
      row['from_the_future'] = 42;
    }
    final copyId = await ProjectArchiver(db).restoreAsNew(archive);
    final board = await boards.getBoard(copyId);
    expect(board, isNotNull);
    expect(board!.copperLayerCount, 2);
  });

  test('a backup from a newer database is refused, not half-read', () async {
    final id = await divider();
    final archive = await ProjectArchiver(db).capture(id);
    final newer = ProjectArchive(
      schemaVersion: db.schemaVersion + 1,
      createdAt: archive.createdAt,
      tables: archive.tables,
    );
    expect(
      () => ProjectArchiver(db).restoreAsNew(newer),
      throwsFormatException,
    );
    expect(await projects.getAll(), hasLength(1));
  });

  group('snapshots', () {
    test(
      'restoring one puts the design back and keeps a way forward',
      () async {
        final id = await divider();
        final snapshots = SnapshotRepository(db);
        await snapshots.take(id, 'Two resistors');

        // Change the design after the snapshot.
        final added = await parts.addPart(id, resistorSpec());
        await boards.deleteTracks(
          (await boards.getTracks(id)).map((t) => t.id),
        );
        expect((await parts.getPartsWithDetails(id)).length, 3);

        final saved = (await snapshots.getAll(id)).single;
        expect(saved.partCount, 2);
        await snapshots.restore(saved.id);

        final after = await parts.getPartsWithDetails(id);
        expect(after.map((p) => p.part.reference), ['R1', 'R2']);
        expect(after.any((p) => p.part.id == added.part.id), isFalse);
        expect((await boards.getTracks(id)).length, 1);
        expect((await nets.getNets(id)).single.net.name, 'MID');

        // The state that was left is itself a snapshot now.
        final all = await snapshots.getAll(id);
        expect(all.length, 2);
        final before = all.firstWhere((s) => s.automatic);
        expect(before.partCount, 3);
        expect(before.trackCount, 0);

        // …and restoring that one brings the third resistor back.
        await snapshots.restore(before.id);
        expect((await parts.getPartsWithDetails(id)).length, 3);
      },
    );

    test('snapshots go with the project', () async {
      final id = await divider();
      await SnapshotRepository(db).take(id, 'one');
      await projects.delete(id);
      expect(await SnapshotRepository(db).getAll(id), isEmpty);
    });
  });
}
