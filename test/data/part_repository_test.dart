import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';

import '../helpers/fixtures.dart';

void main() {
  _editingTests();

  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    project = await projects.create(name: 'Test');
  });

  tearDown(() async => db.close());

  group('adding parts', () {
    test('creates one unit and snapshots every pin', () async {
      final added = await parts.addPart(project.id, resistorSpec());

      expect(added.part.reference, 'R1');
      expect(added.part.libId, 'Device:R');
      expect(added.part.value, '10k');
      expect(added.units, hasLength(1));
      expect(added.units.single.unitNumber, 1);
      // Placed automatically, so it is on the sheet straight away.
      expect(added.units.single.placed, isTrue);
      expect(added.units.single.x, 25.4);
      expect(added.units.single.y, 25.4);
      expect(added.pins.map((p) => p.number), ['1', '2']);
      expect(added.pins.first.electricalType, PinElectricalType.passive);
    });

    test('allocates sequential designators per prefix', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
      final u1 = await parts.addPart(project.id, dualOpampSpec());

      expect(r1.part.reference, 'R1');
      expect(r2.part.reference, 'R2');
      expect(u1.part.reference, 'U1');
    });

    test('designators are allocated per project, not globally', () async {
      final other = await projects.create(name: 'Other');
      await parts.addPart(project.id, resistorSpec());
      final inOther = await parts.addPart(other.id, resistorSpec());

      expect(inOther.part.reference, 'R1');
    });

    test('never reuses a designator after a deletion', () async {
      await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, resistorSpec());
      await parts.deletePart(r2.part.id);

      final next = await parts.addPart(project.id, resistorSpec());
      expect(next.part.reference, 'R4');
    });

    test('rejects an explicit designator that is already taken', () async {
      await parts.addPart(project.id, resistorSpec());

      expect(
        () => parts.addPart(
          project.id,
          NewPartSpec(
            libId: 'Device:R',
            value: '1k',
            reference: 'R1',
            pins: resistorSpec().pins,
          ),
        ),
        throwsA(isA<DuplicateReferenceException>()),
      );
    });

    test('a failed add leaves no partial rows behind', () async {
      await parts.addPart(project.id, resistorSpec());
      final pinsBefore = await db.select(db.partPins).get();

      try {
        await parts.addPart(
          project.id,
          NewPartSpec(
            libId: 'Device:R',
            value: '1k',
            reference: 'R1',
            pins: resistorSpec().pins,
          ),
        );
      } on DuplicateReferenceException {
        // expected
      }

      expect(await db.select(db.parts).get(), hasLength(1));
      expect(await db.select(db.partPins).get(), hasLength(pinsBefore.length));
    });
  });

  group('multi-unit parts', () {
    test('creates one placeable unit per unit in the package', () async {
      final opamp = await parts.addPart(project.id, dualOpampSpec());

      expect(opamp.part.unitCount, 2);
      expect(opamp.part.isMultiUnit, isTrue);
      expect(opamp.units.map((u) => u.unitNumber), [1, 2]);
    });

    test('each unit lands in its own slot on the placement grid', () async {
      final first = await parts.addPart(project.id, resistorSpec());
      final opamp = await parts.addPart(project.id, dualOpampSpec());

      // One grid slot per placed unit, filling a row before wrapping.
      expect(first.units.single.x, 25.4);
      expect(opamp.units[0].x, 25.4 + 38.1);
      expect(opamp.units[1].x, 25.4 + 2 * 38.1);
      expect(opamp.units.every((u) => u.y == 25.4), isTrue);
    });

    test('placement wraps onto a second row', () async {
      // Six columns, so the seventh unit starts a new row.
      for (var i = 0; i < 6; i++) {
        await parts.addPart(project.id, resistorSpec());
      }
      final seventh = await parts.addPart(project.id, resistorSpec());

      expect(seventh.units.single.x, 25.4);
      expect(seventh.units.single.y, 25.4 + 38.1);
    });

    test('supply pins marked unit 0 belong to every unit', () async {
      final opamp = await parts.addPart(project.id, dualOpampSpec());

      final shared = opamp.pins.where((p) => p.isCommonToAllUnits).toList();
      expect(shared.map((p) => p.name), containsAll(['V+', 'V-']));

      final unit1 = opamp.pinsForUnit(1).map((p) => p.number).toSet();
      final unit2 = opamp.pinsForUnit(2).map((p) => p.number).toSet();

      expect(unit1, containsAll(['1', '2', '3', '4', '8']));
      expect(unit2, containsAll(['5', '6', '7', '4', '8']));
      expect(unit1.intersection(unit2), {'4', '8'});
    });
  });

  test('pins sort numerically, not lexically', () async {
    final spec = NewPartSpec(
      libId: 'Connector:Conn_01x12',
      value: 'Conn',
      referencePrefix: 'J',
      pins: [
        for (final n in [1, 2, 10, 11, 3, 12])
          NewPinSpec(
            number: '$n',
            name: 'P$n',
            electricalType: PinElectricalType.passive,
          ),
      ],
    );
    final added = await parts.addPart(project.id, spec);

    expect(added.pins.map((p) => p.number), ['1', '2', '3', '10', '11', '12']);
  });

  test('updating a part persists field changes', () async {
    final added = await parts.addPart(project.id, resistorSpec());
    await parts.updatePart(
      added.part.copyWith(value: '22k', dnp: true, footprint: 'R_0402'),
    );

    final reloaded = await parts.getPartWithDetails(added.part.id);
    expect(reloaded!.part.value, '22k');
    expect(reloaded.part.dnp, isTrue);
    expect(reloaded.part.footprint, 'R_0402');
  });

  test('unit placement round-trips', () async {
    final added = await parts.addPart(project.id, dualOpampSpec());
    final unit = added.units.first;

    await parts.updateUnitPlacement(
      unit.copyWith(x: 101.6, y: 63.5, rotation: 90, placed: true),
    );

    final reloaded = await parts.getPartWithDetails(added.part.id);
    final stored = reloaded!.units.firstWhere((u) => u.id == unit.id);
    expect(stored.x, 101.6);
    expect(stored.y, 63.5);
    expect(stored.rotation, 90);
    expect(stored.placed, isTrue);
  });

  test('no-connect flag round-trips on a pin', () async {
    final added = await parts.addPart(project.id, dualOpampSpec());
    final pin = added.pins.firstWhere((p) => p.number == '5');

    await parts.setPinNoConnect(pin.id, true);

    final reloaded = await parts.getPin(pin.id);
    expect(reloaded!.noConnect, isTrue);
  });

  test('deleting a part removes its units and pins', () async {
    final added = await parts.addPart(project.id, dualOpampSpec());
    await parts.deletePart(added.part.id);

    expect(await parts.getPartWithDetails(added.part.id), isNull);
    expect(await db.select(db.partUnits).get(), isEmpty);
    expect(await db.select(db.partPins).get(), isEmpty);
  });

  test('watchPartsWithDetails re-emits when pins change', () async {
    final emissions = <List<PartWithDetails>>[];
    final sub = parts.watchPartsWithDetails(project.id).listen(emissions.add);
    await pumpEventQueue();

    final added = await parts.addPart(project.id, resistorSpec());
    await pumpEventQueue();
    expect(emissions.last, hasLength(1));

    await parts.setPinNoConnect(added.pins.first.id, true);
    await pumpEventQueue();
    expect(emissions.last.single.pins.first.noConnect, isTrue);

    await sub.cancel();
  });
}

/// Editing verbs the canvas needs: undoable delete, duplicate and paste.
void _editingTests() {
  group('editing', () {
    late AppDatabase db;
    late ProjectRepository projects;
    late PartRepository parts;
    late NetRepository nets;
    late Project project;

    setUp(() async {
      db = AppDatabase.memory();
      projects = ProjectRepository(db);
      parts = PartRepository(db);
      nets = NetRepository(db);
      project = await projects.create(name: 'Editing');
    });

    tearDown(() async => db.close());

    test('deleting a part can be undone, connections included', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
      await nets.renameNet(net.net.id, 'VOUT');

      final snapshot = await parts.capturePart(r1.part.id);
      expect(snapshot, isNotNull);
      await parts.deletePart(r1.part.id);

      expect(await parts.getPartWithDetails(r1.part.id), isNull);

      await parts.restorePart(snapshot!);

      final restored = await parts.getPartWithDetails(r1.part.id);
      expect(restored, isNotNull);
      expect(restored!.part.reference, r1.part.reference);
      expect(restored.pins.map((p) => p.id).toSet(),
          r1.pins.map((p) => p.id).toSet());

      final restoredNets = await nets.getNets(project.id);
      expect(restoredNets, hasLength(1));
      expect(restoredNets.single.net.name, 'VOUT');
      expect(
        restoredNets.single.endpoints.map((e) => e.shortLabel).toSet(),
        {'R1.1', 'R2.1'},
        reason: 'the connection comes back with the part',
      );
    });

    test('undoing a delete restores placement and rotation', () async {
      final part = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        part.units.first.copyWith(
          x: 55.88,
          y: 33.02,
          rotation: 90,
          mirrorX: true,
          placed: true,
        ),
      );

      final snapshot = await parts.capturePart(part.part.id);
      await parts.deletePart(part.part.id);
      await parts.restorePart(snapshot!);

      final unit = (await parts.getPartWithDetails(part.part.id))!.units.first;
      expect(unit.x, 55.88);
      expect(unit.y, 33.02);
      expect(unit.rotation, 90);
      expect(unit.mirrorX, isTrue);
    });

    test('duplicating gives a new designator and no connections', () async {
      final r1 = await parts.addPart(project.id, resistorSpec(value: '4k7'));
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      final copy = await parts.duplicatePart(r1.part.id);

      expect(copy, isNotNull);
      expect(copy!.part.reference, 'R3');
      expect(copy.part.value, '4k7');
      expect(copy.pins.map((p) => p.number), r1.pins.map((p) => p.number));

      for (final pin in copy.pins) {
        expect(
          await nets.netIdForPin(pin.id),
          isNull,
          reason: 'a copy starts unconnected',
        );
      }
    });

    test('a duplicate is offset from the original, not stacked on it',
        () async {
      final original = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        original.units.first.copyWith(x: 50, y: 50, placed: true),
      );

      final copy = await parts.duplicatePart(original.part.id);

      expect(copy!.units.first.x, isNot(50));
      expect(copy.units.first.placed, isTrue);
    });

    test('pasting places the part where it was asked for', () async {
      final source = await parts.addPart(project.id, resistorSpec());

      final pasted = await parts.pastePart(
        project.id,
        source.toSpec(),
        at: const Offset(101.6, 76.2),
      );

      expect(pasted.part.reference, 'R2');
      expect(pasted.units.first.x, 101.6);
      expect(pasted.units.first.y, 76.2);
      expect(pasted.units.first.placed, isTrue);
    });

    test('pasting a multi-unit part keeps the units apart', () async {
      final source = await parts.addPart(project.id, dualOpampSpec());

      final pasted = await parts.pastePart(
        project.id,
        source.toSpec(),
        at: const Offset(50, 50),
      );

      expect(pasted.units, hasLength(2));
      final positions = pasted.units.map((u) => (u.x, u.y)).toSet();
      expect(positions, hasLength(2), reason: 'units must not stack');
    });
  });
}
