import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';

import '../helpers/fixtures.dart';

void main() {
  _undoTests();

  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late NetRepository nets;
  late Project project;

  /// Resistors added on demand, addressed as `pin('R1', '2')`.
  final added = <String, PartWithDetails>{};

  Future<PartWithDetails> addResistor() async {
    final part = await parts.addPart(project.id, resistorSpec());
    added[part.part.reference] = part;
    return part;
  }

  String pin(String reference, String number) => added[reference]!.pins
      .firstWhere((p) => p.number == number)
      .id;

  setUp(() async {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    project = await projects.create(name: 'Test');
    added.clear();
  });

  tearDown(() async => db.close());

  group('connecting', () {
    test('two unconnected pins create a net holding both', () async {
      await addResistor();
      await addResistor();

      final net = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));

      expect(net.endpoints, hasLength(2));
      expect(net.endpoints.map((e) => e.shortLabel), ['R1.2', 'R2.1']);
      expect(net.net.isNamed, isFalse);
      expect(await nets.getNets(project.id), hasLength(1));
    });

    test('a third pin joins the existing net rather than making a new one',
        () async {
      await addResistor();
      await addResistor();
      await addResistor();

      final first = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));
      final second = await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      expect(second.net.id, first.net.id);
      expect(second.endpoints, hasLength(3));
      expect(await nets.getNets(project.id), hasLength(1));
    });

    test('the new pin can be given first and still joins', () async {
      await addResistor();
      await addResistor();
      await addResistor();

      final first = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));
      final second = await nets.connectPins(pin('R3', '1'), pin('R2', '1'));

      expect(second.net.id, first.net.id);
      expect(second.endpoints, hasLength(3));
    });

    test('connecting two pins already on the same net changes nothing',
        () async {
      await addResistor();
      await addResistor();

      final first = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));
      final again = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));

      expect(again.net.id, first.net.id);
      expect(again.endpoints, hasLength(2));
      expect(await db.select(db.netNodes).get(), hasLength(2));
    });

    test('a pin cannot connect to itself', () async {
      await addResistor();

      expect(
        () => nets.connectPins(pin('R1', '1'), pin('R1', '1')),
        throwsA(isA<InvalidConnectionException>()),
      );
    });

    test('an unknown pin id is rejected before anything is written', () async {
      await addResistor();

      await expectLater(
        nets.connectPins(pin('R1', '1'), 'no-such-pin'),
        throwsA(isA<InvalidConnectionException>()),
      );
      expect(await db.select(db.nets).get(), isEmpty);
    });

    test('pins in different projects cannot be connected', () async {
      await addResistor();
      final other = await projects.create(name: 'Other');
      final foreign = await parts.addPart(other.id, resistorSpec());

      await expectLater(
        nets.connectPins(pin('R1', '1'), foreign.pins.first.id),
        throwsA(isA<InvalidConnectionException>()),
      );
      expect(await db.select(db.nets).get(), isEmpty);
    });
  });

  group('merging', () {
    Future<(NetWithEndpoints, NetWithEndpoints)> twoNets() async {
      await addResistor();
      await addResistor();
      await addResistor();
      await addResistor();
      final a = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await nets.connectPins(pin('R3', '1'), pin('R4', '1'));
      return (a, b);
    }

    test('joining two nets merges them into one', () async {
      final (a, b) = await twoNets();

      final merged = await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      expect(merged.endpoints, hasLength(4));
      expect(await nets.getNets(project.id), hasLength(1));
      expect([a.net.id, b.net.id], contains(merged.net.id));
    });

    test('the older net survives when neither is named', () async {
      final (a, _) = await twoNets();

      final merged = await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      expect(merged.net.id, a.net.id);
    });

    test('a named net wins over an anonymous one, whichever side it is on',
        () async {
      final (_, b) = await twoNets();
      await nets.renameNet(b.net.id, 'VCC');

      final merged = await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      expect(merged.net.id, b.net.id);
      expect(merged.net.name, 'VCC');
      expect(merged.endpoints, hasLength(4));
    });

    test('the older label wins when both nets are named', () async {
      final (a, b) = await twoNets();
      await nets.renameNet(a.net.id, 'SIG_A');
      await nets.renameNet(b.net.id, 'SIG_B');

      final merged = await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      expect(merged.net.id, a.net.id);
      expect(merged.net.name, 'SIG_A');
    });
  });

  group('disconnecting', () {
    test('removes one pin and leaves the others connected', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      await nets.disconnectPin(pin('R2', '1'));

      final remaining = await nets.getNet(net.net.id);
      expect(remaining!.endpoints.map((e) => e.shortLabel), ['R1.1', 'R3.1']);
    });

    test('a net left with a single unnamed pin is discarded', () async {
      await addResistor();
      await addResistor();
      await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      await nets.disconnectPin(pin('R2', '1'));

      expect(await nets.getNets(project.id), isEmpty);
      expect(await nets.netIdForPin(pin('R1', '1')), isNull);
    });

    test('a net left with a single named pin is kept', () async {
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await nets.renameNet(net.net.id, 'GND');

      await nets.disconnectPin(pin('R2', '1'));

      final remaining = await nets.getNets(project.id);
      expect(remaining, hasLength(1));
      expect(remaining.single.net.name, 'GND');
      expect(remaining.single.endpoints, hasLength(1));
    });

    test('disconnecting an unconnected pin is a no-op', () async {
      await addResistor();
      await nets.disconnectPin(pin('R1', '1'));
      expect(await nets.getNets(project.id), isEmpty);
    });
  });

  group('lifecycle', () {
    test('deleting a part removes its pins from every net', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      await parts.deletePart(added['R2']!.part.id);

      final remaining = await nets.getNet(net.net.id);
      expect(remaining!.endpoints.map((e) => e.shortLabel), ['R1.1', 'R3.1']);
      expect(await db.select(db.netNodes).get(), hasLength(2));
    });

    test('deleting a net leaves its pins unconnected', () async {
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      await nets.deleteNet(net.net.id);

      expect(await nets.getNets(project.id), isEmpty);
      expect(await nets.netIdForPin(pin('R1', '1')), isNull);
      expect(await db.select(db.partPins).get(), hasLength(4));
    });

    test('addPinToNet moves a pin off whatever net it was on', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      await addResistor();
      final a = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      final b = await nets.connectPins(pin('R3', '1'), pin('R4', '1'));

      await nets.addPinToNet(b.net.id, pin('R2', '1'));

      final netA = await nets.getNet(a.net.id);
      final netB = await nets.getNet(b.net.id);
      expect(netA, isNull, reason: 'left with one unnamed pin, so discarded');
      expect(netB!.endpoints.map((e) => e.shortLabel), [
        'R2.1',
        'R3.1',
        'R4.1',
      ]);
    });

    test('a pin belongs to at most one net', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      await addResistor();
      await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await nets.connectPins(pin('R3', '1'), pin('R4', '1'));
      await nets.addPinToNet(
        (await nets.getNets(project.id)).last.net.id,
        pin('R2', '1'),
      );

      final nodes = await db.select(db.netNodes).get();
      final pinIds = nodes.map((n) => n.partPinId).toList();
      expect(pinIds.toSet(), hasLength(pinIds.length));
    });
  });

  group('power symbols', () {
    test('a net touching a power symbol takes its name', () async {
      await addResistor();
      final gnd = await parts.addPart(project.id, groundSpec());

      final net = await nets.connectPins(pin('R1', '2'), gnd.pins.single.id);

      expect(net.net.name, 'GND');
      expect(net.displayName, 'GND');
    });

    test('a label the user typed is not overwritten', () async {
      await addResistor();
      await addResistor();
      final gnd = await parts.addPart(project.id, groundSpec());

      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      await nets.renameNet(net.id, 'AGND');
      await nets.connectPins(pin('R2', '1'), gnd.pins.single.id);

      expect((await nets.getNet(net.id))!.net.name, 'AGND');
    });

    test('joining a power net to a plain one keeps the power name', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      final gnd = await parts.addPart(project.id, groundSpec());

      final powerNet = await nets.connectPins(
        pin('R1', '1'),
        gnd.pins.single.id,
      );
      await nets.connectPins(pin('R2', '1'), pin('R3', '1'));
      final merged = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      expect(merged.net.id, powerNet.net.id);
      expect(merged.net.name, 'GND');
      expect(merged.endpoints, hasLength(4));
    });

    test('a power symbol is recognised by its designator', () {
      expect(NetRepository.isPowerReference('#PWR01'), isTrue);
      expect(NetRepository.isPowerReference('#FLG01'), isTrue);
      expect(NetRepository.isPowerReference('R1'), isFalse);
    });
  });

  group('naming', () {
    test('an unnamed net falls back to a KiCad-style derived name', () async {
      await addResistor();
      await addResistor();

      final net = await nets.connectPins(pin('R1', '2'), pin('R2', '1'));
      expect(net.displayName, 'Net-(R1-Pad2)');
    });

    test('renaming with blank text clears the label', () async {
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      await nets.renameNet(net.net.id, '  VCC  ');
      expect((await nets.getNet(net.net.id))!.net.name, 'VCC');

      await nets.renameNet(net.net.id, '   ');
      expect((await nets.getNet(net.net.id))!.net.name, isNull);
    });
  });

  test('pinToNetMap reports every connected pin', () async {
    await addResistor();
    await addResistor();
    final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

    final map = await nets.pinToNetMap(project.id);
    expect(map, hasLength(2));
    expect(map[pin('R1', '1')], net.net.id);
    expect(map[pin('R2', '1')], net.net.id);
    expect(map.containsKey(pin('R1', '2')), isFalse);
  });

  test('the nets stream is independent of the parts stream', () async {
    // Both aggregates are driven by a trigger query. If they shared drift's
    // cached stream, connecting two pins would not reach a nets listener
    // until something unrelated changed a part.
    await addResistor();
    await addResistor();

    final partEmissions = <int>[];
    final netEmissions = <int>[];
    final partSub = parts
        .watchPartsWithDetails(project.id)
        .listen((v) => partEmissions.add(v.length));
    final netSub = nets
        .watchNets(project.id)
        .listen((v) => netEmissions.add(v.length));
    await pumpEventQueue();

    await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
    await pumpEventQueue();

    expect(netEmissions.last, 1);

    await partSub.cancel();
    await netSub.cancel();
  });

  test('watchNets emits the current netlist and updates', () async {
    await addResistor();
    await addResistor();

    final emissions = <List<NetWithEndpoints>>[];
    final sub = nets.watchNets(project.id).listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
    await pumpEventQueue();
    expect(emissions.last, hasLength(1));
    expect(emissions.last.single.endpoints, hasLength(2));

    await sub.cancel();
  });
}

/// Undo support for tap-to-connect. Connecting can merge two nets, which
/// destroys where the seam was and which label survived, so nothing else can
/// reconstruct it after the fact.
void _undoTests() {
  group('capture and restore', () {
    late AppDatabase db;
    late ProjectRepository projects;
    late PartRepository parts;
    late NetRepository nets;
    late Project project;
    final added = <String, PartWithDetails>{};

    Future<PartWithDetails> addResistor() async {
      final part = await parts.addPart(project.id, resistorSpec());
      added[part.part.reference] = part;
      return part;
    }

    String pin(String reference, String number) =>
        added[reference]!.pins.firstWhere((p) => p.number == number).id;

    setUp(() async {
      db = AppDatabase.memory();
      projects = ProjectRepository(db);
      parts = PartRepository(db);
      nets = NetRepository(db);
      project = await projects.create(name: 'Undo');
      added.clear();
    });

    tearDown(() async => db.close());

    test('undoes a connection between two free pins', () async {
      await addResistor();
      await addResistor();

      final snapshot = await nets.capture(project.id, [
        pin('R1', '1'),
        pin('R2', '1'),
      ]);
      await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      expect(await nets.getNets(project.id), hasLength(1));

      await nets.restore(snapshot);

      expect(await nets.getNets(project.id), isEmpty);
      expect(await nets.netIdForPin(pin('R1', '1')), isNull);
      expect(await nets.netIdForPin(pin('R2', '1')), isNull);
    });

    test('undoes a merge, restoring both nets and the lost label', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      await addResistor();

      final a = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));
      final b = await nets.connectPins(pin('R3', '1'), pin('R4', '1'));
      await nets.renameNet(a.net.id, 'SIG_A');
      await nets.renameNet(b.net.id, 'SIG_B');

      final snapshot = await nets.capture(project.id, [
        pin('R2', '1'),
        pin('R3', '1'),
      ]);
      await nets.connectPins(pin('R2', '1'), pin('R3', '1'));

      // The merge collapsed two labelled nets into one.
      final merged = await nets.getNets(project.id);
      expect(merged, hasLength(1));
      expect(merged.single.endpoints, hasLength(4));

      await nets.restore(snapshot);

      final restored = await nets.getNets(project.id);
      expect(restored, hasLength(2));
      expect(
        restored.map((n) => n.net.name).toSet(),
        {'SIG_A', 'SIG_B'},
        reason: 'both labels come back, including the one the merge dropped',
      );
      for (final net in restored) {
        expect(net.endpoints, hasLength(2));
      }
      expect(
        await nets.netIdForPin(pin('R1', '1')),
        await nets.netIdForPin(pin('R2', '1')),
        reason: 'R1 and R2 are together again',
      );
      expect(
        await nets.netIdForPin(pin('R3', '1')),
        await nets.netIdForPin(pin('R4', '1')),
      );
      expect(
        await nets.netIdForPin(pin('R1', '1')),
        isNot(await nets.netIdForPin(pin('R3', '1'))),
        reason: 'and the two nets are separate again',
      );
    });

    test('undoes joining a pin to an existing net', () async {
      await addResistor();
      await addResistor();
      await addResistor();
      final net = await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      final snapshot = await nets.capture(project.id, [
        pin('R2', '1'),
        pin('R3', '1'),
      ]);
      await nets.connectPins(pin('R2', '1'), pin('R3', '1'));
      expect((await nets.getNet(net.net.id))!.endpoints, hasLength(3));

      await nets.restore(snapshot);

      final restored = await nets.getNets(project.id);
      expect(restored, hasLength(1));
      expect(restored.single.endpoints.map((e) => e.shortLabel), [
        'R1.1',
        'R2.1',
      ]);
      expect(await nets.netIdForPin(pin('R3', '1')), isNull);
    });

    test('restoring twice is harmless', () async {
      await addResistor();
      await addResistor();
      final snapshot = await nets.capture(project.id, [
        pin('R1', '1'),
        pin('R2', '1'),
      ]);
      await nets.connectPins(pin('R1', '1'), pin('R2', '1'));

      await nets.restore(snapshot);
      await nets.restore(snapshot);

      expect(await nets.getNets(project.id), isEmpty);
    });
  });
}
