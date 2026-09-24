import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/circuit_paster.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/models/models.dart';

import '../helpers/fixtures.dart';

void main() {
  // "the selection box should have a copy button as when you are
  // highlighting something, it is usually quite a big portion of the
  // circuit, so its like normal to expect to copy ... a big chunk"
  test('a copied chunk comes back wired the way it was', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final project = await ProjectRepository(db).create(name: 'Clip');
    final parts = PartRepository(db);
    final nets = NetRepository(db);

    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
    await parts.updateUnitPlacement(
      r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
    );
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 63.5, y: 50.8, placed: true),
    );
    String pin(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number).id;

    await nets.connectPins(pin(r1, '1'), pin(r2, '1'));
    // A wire left hanging off R1 pin 2, the case that used to stay behind.
    await nets.addWire(
      projectId: project.id,
      points: const [Offset(50.8, 54.61), Offset(50.8, 64.61)],
      pinAId: pin(r1, '2'),
      netId: await nets.netForPin(project.id, pin(r1, '2')),
    );

    final details = await parts.getPartsWithDetails(project.id);
    final clip = CircuitClip.of(
      parts: details,
      nets: await nets.getNets(project.id),
      wires: await nets.getWires(project.id),
      unitIds: {for (final part in details) part.units.first.id},
    );
    expect(clip, isNotNull);
    expect(clip!.parts, hasLength(2));
    expect(
      clip.nets,
      hasLength(2),
      reason: 'the two pins joined, and the loose wire on its own',
    );
    expect(clip.wires, hasLength(1), reason: 'the loose wire came along');

    final pasted = await CircuitPaster(
      parts,
      nets,
    ).paste(project.id, clip, at: const Offset(101.6, 88.9));

    expect(pasted.partIds, hasLength(2));
    final all = await parts.getPartsWithDetails(project.id);
    expect(all, hasLength(4));

    final copies = all.where((p) => pasted.partIds.contains(p.part.id));
    expect(
      copies.map((p) => p.part.value).toSet(),
      {'10k', '4k7'},
      reason: 'the parts themselves, not just their outlines',
    );
    // Laid out the same, moved to where it was pasted.
    final places = copies.map((p) => Offset(p.units.first.x, p.units.first.y));
    expect(places, contains(const Offset(101.6, 88.9)));
    expect(places, contains(const Offset(101.6 + 12.7, 88.9)));

    // Wired to each other, and not to the originals.
    final netIds = {
      for (final p in copies) await nets.netIdForPin(pin(p, '1')),
    };
    expect(netIds, hasLength(1));
    expect(netIds.single, isNot(await nets.netIdForPin(pin(r1, '1'))));

    final wires = await nets.getWires(project.id);
    expect(wires, hasLength(2));
    final copied = wires.firstWhere((w) => w.id != wires.first.id);
    expect(copied.points.first, const Offset(101.6, 92.71));
  });
}
