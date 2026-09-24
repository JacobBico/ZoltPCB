import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/pin_swap.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/models/models.dart';

import '../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late PartRepository parts;
  late NetRepository nets;
  late PinSwapper swapper;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    nets = NetRepository(db);
    swapper = PinSwapper(parts: parts, nets: nets);
    project = await ProjectRepository(db).create(name: 'Swap');
  });
  tearDown(() => db.close());

  PartPin pin(PartWithDetails part, String number) =>
      part.pins.firstWhere((p) => p.number == number);

  Future<String?> netOf(String pinId) => nets.netIdForPin(pinId);

  test('the gates of a dual op-amp pair up pin for pin', () async {
    final u1 = await parts.addPart(project.id, dualOpampSpec());
    final pairs = PinSwapper.gatePairs(u1, 1, 2)!;
    String number(String id) => u1.pins.firstWhere((p) => p.id == id).number;
    expect(
      {for (final e in pairs.entries) number(e.key): number(e.value)},
      {'1': '7', '2': '6', '3': '5'},
    );
    expect(PinSwapper.swappableWith(u1, 1), [2]);
    expect(PinSwapper.hasSwappableGates(u1), isTrue);
  });

  test('a gate swap moves the nets, the gates and keeps the wires', () async {
    final u1 = await parts.addPart(project.id, dualOpampSpec());
    final r1 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      u1.units[0].copyWith(x: 20, y: 20, placed: true),
    );
    await parts.updateUnitPlacement(
      u1.units[1].copyWith(x: 60, y: 20, placed: true),
    );
    // Gate A's output drives R1, with a wire drawn between them.
    final out = await nets.connectPins(pin(u1, '1').id, r1.pins.first.id);
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(20, 20), Offset(30, 20)],
      pinAId: pin(u1, '1').id,
      pinBId: r1.pins.first.id,
    );

    final fresh = (await parts.getPartWithDetails(u1.part.id))!;
    final undo = await swapper.swapGates(project.id, fresh, 1, 2);

    // R1 is now driven by gate B's output, pin 7; pin 1 is free.
    expect(await netOf(pin(u1, '7').id), await netOf(r1.pins.first.id));
    expect(await netOf(pin(u1, '1').id), isNull);
    // The wire follows the pin that took the net, from the same place.
    final wire = (await nets.getWiresOfNet(out.net.id)).single;
    expect(wire.pinAId, pin(u1, '7').id);
    // The gates traded places, so the drawing is where it was.
    final after = (await parts.getPartWithDetails(u1.part.id))!;
    expect(after.units.firstWhere((u) => u.unitNumber == 2).x, 20);
    expect(after.units.firstWhere((u) => u.unitNumber == 1).x, 60);

    await swapper.undo(undo);
    expect(await netOf(pin(u1, '1').id), await netOf(r1.pins.first.id));
    expect(await netOf(pin(u1, '7').id), isNull);
    final back = (await parts.getPartWithDetails(u1.part.id))!;
    expect(back.units.firstWhere((u) => u.unitNumber == 1).x, 20);
  });

  test('a pin swap trades nets and labels both pins with them', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    final r3 = await parts.addPart(project.id, resistorSpec());
    final a = await nets.connectPins(r1.pins[0].id, r2.pins.first.id);
    await nets.renameNet(a.net.id, 'SDA');
    await nets.connectPins(r1.pins[1].id, r3.pins.first.id);
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(0, 0), Offset(10, 0)],
      pinAId: r1.pins[0].id,
      pinBId: r2.pins.first.id,
    );

    final undo = await swapper.swapPins(project.id, r1, r1.pins[0], r1.pins[1]);
    // Pin 1 now carries what pin 2 did, and the other way round.
    expect(await netOf(r1.pins[0].id), await netOf(r3.pins.first.id));
    expect(await netOf(r1.pins[1].id), await netOf(r2.pins.first.id));
    // The wire that ran to pin 1 would now be wrong, so it went.
    expect(await nets.getWires(project.id), isEmpty);
    // Both nets have names to show at the pins.
    final all = await nets.getNets(project.id);
    expect(all.map((n) => n.net.name).toSet(), {'SDA', 'Net-(R1-2)'});
    for (final net in all) {
      final swapped = net.endpoints.where((e) => e.pin.partId == r1.part.id);
      expect(swapped.single.node.labelled, isTrue);
    }

    await swapper.undo(undo);
    expect(await netOf(r1.pins[0].id), await netOf(r2.pins.first.id));
    expect(await nets.getWires(project.id), hasLength(1));
  });
}
