import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/features/project/attach_power.dart';

import '../helpers/fixtures.dart';
import '../helpers/library_fixture.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late NetRepository nets;
  late SymbolLibraryRepository libraries;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    libraries = SymbolLibraryRepository(db, InMemoryLibraryStorage());
    await libraries.import(
      fileName: 'power.kicad_sym',
      bytes: libraryBytes(testPowerLibrarySource),
    );
    project = await projects.create(name: 'P');
  });

  tearDown(() async => db.close());

  Future<AttachPowerResult> ground(
    PartPin pin, {
    Offset at = const Offset(50, 40),
    Offset exit = const Offset(0, 1),
    String libId = 'power:GND',
  }) => attachPower(
    parts: parts,
    nets: nets,
    libraries: libraries,
    projectId: project.id,
    libId: libId,
    pinId: pin.id,
    pinPosition: at,
    pinExit: exit,
  );

  test('one action places the symbol and connects it', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final result = await ground(r1.pins.first);

    final placed = result as AttachPowerPlaced;
    expect(placed.part.part.value, 'GND');
    expect(placed.part.units.single.placed, isTrue);

    // One net, holding the resistor pin and the ground pin and nothing else.
    final allNets = await nets.getNets(project.id);
    expect(allNets, hasLength(1));
    expect(
      allNets.single.endpoints.map((e) => e.pin.id).toSet(),
      {r1.pins.first.id, placed.part.pins.single.id},
    );
  });

  test('the symbol lands on the side the wire leaves the pin', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final result =
        await ground(
              r1.pins.first,
              at: const Offset(50, 40),
              exit: const Offset(0, 1),
            )
            as AttachPowerPlaced;

    final unit = result.part.units.single;
    expect(unit.x, closeTo(50, 1e-9));
    expect(unit.y, greaterThan(40));
  });

  test('joining a pin that is already on a net grows that net', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

    final result = await ground(r1.pins.first) as AttachPowerPlaced;

    final allNets = await nets.getNets(project.id);
    expect(allNets, hasLength(1));
    expect(allNets.single.endpoints, hasLength(3));
    expect(
      allNets.single.endpoints.map((e) => e.pin.id),
      contains(result.part.pins.single.id),
    );
  });

  test('taking it back removes the symbol and the connection', () async {
    // What the undo button does: the part is captured after it has been
    // wired, so deleting it takes the wire with it.
    final r1 = await parts.addPart(project.id, resistorSpec());
    final result = await ground(r1.pins.first) as AttachPowerPlaced;

    final snapshot = await parts.capturePart(result.part.part.id);
    await parts.deletePart(result.part.part.id);
    expect(await parts.getPartWithDetails(result.part.part.id), isNull);

    await parts.restorePart(snapshot!);
    final restored = await nets.getNets(project.id);
    expect(
      restored.single.endpoints.map((e) => e.pin.id),
      containsAll([r1.pins.first.id, result.part.pins.single.id]),
    );
  });

  test('a supply other than ground works the same way', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final result =
        await ground(
              r1.pins.last,
              exit: const Offset(0, -1),
              libId: 'power:VCC',
            )
            as AttachPowerPlaced;

    expect(result.part.part.value, 'VCC');
    expect(result.part.units.single.y, lessThan(40));
  });

  test('a library that is gone is reported, not half-applied', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final result = await ground(r1.pins.first, libId: 'power:MISSING');

    expect(result, isA<AttachPowerFailed>());
    expect(
      (result as AttachPowerFailed).reason,
      AttachPowerFailure.unreadable,
    );
    // Nothing was added along the way.
    expect(await parts.getPartsWithDetails(project.id), hasLength(1));
    expect(await nets.getNets(project.id), isEmpty);
  });
}
