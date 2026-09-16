import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/erc/erc.dart';
import 'package:hintpcb/domain/models/models.dart';

import '../helpers/fixtures.dart';

NewPartSpec _chip({
  PinElectricalType supply = PinElectricalType.powerIn,
  PinElectricalType out = PinElectricalType.output,
}) => NewPartSpec(
  libId: 'Test:Chip',
  value: 'Chip',
  referencePrefix: 'U',
  footprint: 'Package:SOT-23',
  pins: [
    NewPinSpec(number: '1', name: 'VDD', electricalType: supply),
    NewPinSpec(number: '2', name: 'OUT', electricalType: out),
    const NewPinSpec(
      number: '3',
      name: 'GND',
      electricalType: PinElectricalType.powerIn,
    ),
  ],
);

void main() {
  late AppDatabase db;
  late PartRepository parts;
  late NetRepository nets;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    nets = NetRepository(db);
    project = await ProjectRepository(db).create(name: 'ERC');
  });
  tearDown(() async => db.close());

  Future<List<ErcViolation>> check() async => checkSchematic(
    parts: await parts.getPartsWithDetails(project.id),
    nets: await nets.getNets(project.id),
  );

  test('loose pins are one warning per part, not one per pin', () async {
    await parts.addPart(project.id, _chip());
    final found = (await check())
        .where((v) => v.rule == ErcRule.unconnectedPin)
        .toList();
    expect(found, hasLength(1));
    expect(found.single.message, contains('3 pins'));
  });

  test('a pin marked no-connect is not a loose pin', () async {
    final chip = await parts.addPart(project.id, _chip());
    for (final pin in chip.pins) {
      await parts.setPinNoConnect(pin.id, true);
    }
    expect(
      (await check()).where((v) => v.rule == ErcRule.unconnectedPin),
      isEmpty,
    );
  });

  test(
    'a supply nothing drives is an error; a power symbol drives it',
    () async {
      final a = await parts.addPart(project.id, _chip());
      final b = await parts.addPart(project.id, _chip());
      final vdd = await nets.connectPins(a.pins[0].id, b.pins[0].id);

      expect(
        (await check())
            .where((v) => v.rule == ErcRule.undrivenPower)
            .single
            .isError,
        isTrue,
      );

      final symbol = await parts.addPart(project.id, groundSpec(value: '+3V3'));
      await nets.addPinToNet(vdd.net.id, symbol.pins.single.id);
      expect(
        (await check()).where((v) => v.rule == ErcRule.undrivenPower),
        isEmpty,
      );
    },
  );

  test('two outputs on one net are an error', () async {
    final a = await parts.addPart(project.id, _chip());
    final b = await parts.addPart(project.id, _chip());
    await nets.connectPins(a.pins[1].id, b.pins[1].id);
    expect(
      (await check()).where((v) => v.rule == ErcRule.outputsTogether),
      hasLength(1),
    );
  });

  test(
    'a part with no footprint is flagged, unless the board has one',
    () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final without = (await check()).where(
        (v) => v.rule == ErcRule.missingFootprint,
      );
      // The fixture resistor may or may not name one; check both ways.
      if (r1.part.footprint.isEmpty) {
        expect(without, hasLength(1));
        final withBoard = checkSchematic(
          parts: await parts.getPartsWithDetails(project.id),
          nets: await nets.getNets(project.id),
          partsWithBoardFootprint: {r1.part.id},
        ).where((v) => v.rule == ErcRule.missingFootprint);
        expect(withBoard, isEmpty);
      } else {
        expect(without, isEmpty);
      }
    },
  );

  group('renumbering', () {
    test('references follow reading order across the sheet', () async {
      // Added out of order: R1 bottom right, R2 top left, R3 top right.
      final first = await parts.addPart(project.id, resistorSpec());
      final second = await parts.addPart(project.id, resistorSpec());
      final third = await parts.addPart(project.id, resistorSpec());
      for (final (part, x, y) in [
        (first, 100.0, 100.0),
        (second, 20.0, 20.0),
        (third, 100.0, 20.0),
      ]) {
        await parts.updateUnitPlacement(
          part.units.first.copyWith(x: x, y: y, placed: true),
        );
      }

      final changes = await parts.renumberReferences(project.id);
      final byId = {
        for (final p in await parts.getPartsWithDetails(project.id))
          p.part.id: p.part.reference,
      };
      expect(byId[second.part.id], 'R1');
      expect(byId[third.part.id], 'R2');
      expect(byId[first.part.id], 'R3');

      // And all of it goes back.
      await parts.applyReferences({
        for (final e in changes.entries) e.key: e.value.$1,
      }, project.id);
      final restored = {
        for (final p in await parts.getPartsWithDetails(project.id))
          p.part.id: p.part.reference,
      };
      expect(restored[first.part.id], 'R1');
      expect(restored[second.part.id], 'R2');
      expect(restored[third.part.id], 'R3');
    });

    test('already in order changes nothing', () async {
      final a = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        a.units.first.copyWith(x: 10, y: 10, placed: true),
      );
      expect(await parts.renumberReferences(project.id), isEmpty);
    });
  });
}
