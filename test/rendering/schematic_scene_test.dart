import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/rendering/schematic_scene.dart';

import '../helpers/fixtures.dart';

void main() {
  _wireTests();

  _tapResolutionTests();

  _reportedConnectionBug();

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
    project = await projects.create(name: 'Scene');
  });

  tearDown(() async => db.close());

  Future<SchematicScene> buildScene({
    Map<String, SymbolDefinition> symbols = const {},
  }) async {
    return SchematicScene.build(
      paper: project.paper,
      parts: await parts.getPartsWithDetails(project.id),
      nets: await nets.getNets(project.id),
      symbols: symbols,
    );
  }

  test('places every pin of every placed unit on the sheet', () async {
    await parts.addPart(project.id, resistorSpec());
    final scene = await buildScene();

    expect(scene.units, hasLength(1));
    expect(scene.pins, hasLength(2));
    // Pin 1 sits at symbol (0, 3.81); the sheet is Y-down, so it lands
    // above the symbol origin.
    final pin1 = scene.pins.firstWhere((p) => p.pin.number == '1');
    expect(pin1.sheetPosition.dx, closeTo(25.4, 1e-9));
    expect(pin1.sheetPosition.dy, closeTo(25.4 - 3.81, 1e-9));
    expect(pin1.label, 'R1.1');
  });

  test('a multi-unit part becomes one drawing per unit', () async {
    await parts.addPart(project.id, dualOpampSpec());
    final scene = await buildScene();

    expect(scene.units, hasLength(2));
    expect(scene.units.map((u) => u.unit.unitNumber), [1, 2]);
  });

  test('pins shared by every unit are drawn on each of them', () async {
    await parts.addPart(project.id, dualOpampSpec());
    final scene = await buildScene();

    for (final unit in scene.units) {
      final numbers = unit.pins.map((p) => p.pin.number).toSet();
      // 4 and 8 are the supply pins, marked unit 0 in the fixture.
      expect(numbers, containsAll(['4', '8']));
    }
  });

  test('connected pins carry their net through to the drawing', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
    await nets.renameNet(net.id, 'VCC');

    final scene = await buildScene();

    expect(scene.pinsByNet, hasLength(1));
    expect(scene.pinsByNet[net.id], hasLength(2));
    final connected = scene.pins.where((p) => p.isConnected).toList();
    expect(connected, hasLength(2));
    expect(connected.every((p) => p.netName == 'VCC'), isTrue);
  });

  test('a pin can be found by tapping near it', () async {
    await parts.addPart(project.id, resistorSpec());
    final scene = await buildScene();
    final pin1 = scene.pins.firstWhere((p) => p.pin.number == '1');

    expect(scene.pinNear(pin1.sheetPosition, 1)!.id, pin1.id);
    // Slightly off still hits, because fingers are not precise.
    expect(
      scene.pinNear(pin1.sheetPosition + const Offset(0.8, 0.8), 2)!.id,
      pin1.id,
    );
    // Far away hits nothing.
    expect(scene.pinNear(pin1.sheetPosition + const Offset(30, 30), 2), isNull);
  });

  test('the nearest pin wins when two are close together', () async {
    await parts.addPart(project.id, resistorSpec());
    final scene = await buildScene();
    final pin1 = scene.pins.firstWhere((p) => p.pin.number == '1');
    final pin2 = scene.pins.firstWhere((p) => p.pin.number == '2');

    final midpoint = (pin1.sheetPosition + pin2.sheetPosition) / 2;
    final nearerToOne = midpoint + const Offset(0, -0.5);
    expect(scene.pinNear(nearerToOne, 10)!.id, pin1.id);
  });

  test('a unit can be grabbed by its body', () async {
    await parts.addPart(project.id, resistorSpec());
    final scene = await buildScene();

    expect(scene.unitAt(const Offset(25.4, 25.4)), isNotNull);
    expect(scene.unitAt(const Offset(200, 200)), isNull);
  });

  test('a symbol whose library is gone still has pins and bounds', () async {
    await parts.addPart(project.id, resistorSpec());
    // No symbols supplied: the library has been removed.
    final scene = await buildScene();

    expect(scene.units.single.hasSymbol, isFalse);
    expect(scene.units.single.pins, hasLength(2));

    // A resistor's pins are a vertical line, so the box would otherwise
    // have no width and nothing to grab.
    final bounds = scene.boundsOf(scene.units.single);
    expect(bounds.isEmpty, isFalse);
    expect(bounds.width, closeTo(SchematicScene.minimumExtentMm, 1e-9));
    expect(bounds.height, greaterThan(7));
  });

  test('content bounds cover everything placed', () async {
    await parts.addPart(project.id, resistorSpec());
    await parts.addPart(project.id, resistorSpec());
    final scene = await buildScene();

    final bounds = scene.contentBounds;
    for (final pin in scene.pins) {
      expect(bounds.contains(pin.sheetPosition), isTrue);
    }
  });
}

/// Reproduction of a bug reported from the phone: connecting one pin of a
/// capacitor to one pin of an opamp appeared to wire *both* capacitor pins
/// to it.
void _reportedConnectionBug() {
  group('reported: one tap must connect exactly one pin', () {
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
      project = await projects.create(name: 'Repro');
    });

    tearDown(() async => db.close());

    test(
      'a capacitor pin joined to an opamp pin leaves the other pin free',
      () async {
        final cap = await parts.addPart(project.id, resistorSpec());
        final opamp = await parts.addPart(project.id, dualOpampSpec());

        for (final unit in [...cap.units, ...opamp.units]) {
          await parts.updateUnitPlacement(
            unit.copyWith(x: 100, y: 100, placed: true),
          );
        }

        final capPin1 = cap.pins.firstWhere((p) => p.number == '1');
        final capPin2 = cap.pins.firstWhere((p) => p.number == '2');
        final opampPin3 = opamp.pins.firstWhere((p) => p.number == '3');

        await nets.connectPins(capPin1.id, opampPin3.id);

        final netList = await nets.getNets(project.id);
        expect(netList, hasLength(1), reason: 'one tap pair, one net');
        expect(netList.single.endpoints.map((e) => e.pin.id).toSet(), {
          capPin1.id,
          opampPin3.id,
        });

        final scene = SchematicScene.build(
          paper: project.paper,
          parts: await parts.getPartsWithDetails(project.id),
          nets: netList,
          symbols: const {},
        );

        final netId = netList.single.net.id;
        final drawn = scene.pinsByNet[netId] ?? const [];
        expect(
          drawn.map((p) => p.pin.id).toList(),
          unorderedEquals([capPin1.id, opampPin3.id]),
          reason: 'the canvas must draw exactly the two connected pins',
        );

        final freePin = scene.pins.firstWhere((p) => p.pin.id == capPin2.id);
        expect(freePin.netId, isNull);
      },
    );

    test(
      'a shared unit-0 pin is drawn once per net, not once per unit',
      () async {
        // The dual opamp's supply pins are common to every unit, so they are
        // drawn on each placed unit. They must still count as one connection.
        final opamp = await parts.addPart(project.id, dualOpampSpec());
        final resistor = await parts.addPart(project.id, resistorSpec());
        for (final unit in [...opamp.units, ...resistor.units]) {
          await parts.updateUnitPlacement(
            unit.copyWith(x: 100, y: 100, placed: true),
          );
        }

        final supply = opamp.pins.firstWhere((p) => p.number == '8');
        expect(supply.unit, 0, reason: 'fixture models a shared supply pin');

        await nets.connectPins(
          supply.id,
          resistor.pins.firstWhere((p) => p.number == '1').id,
        );

        final netList = await nets.getNets(project.id);
        final scene = SchematicScene.build(
          paper: project.paper,
          parts: await parts.getPartsWithDetails(project.id),
          nets: netList,
          symbols: const {},
        );

        final drawn = scene.pinsByNet[netList.single.net.id] ?? const [];
        expect(
          drawn.map((p) => p.pin.id).toSet(),
          hasLength(2),
          reason: 'two distinct pins are on this net',
        );
        expect(
          drawn,
          hasLength(2),
          reason: 'the shared pin must not be duplicated per placed unit',
        );
      },
    );
  });
}

/// Tap resolution: the rule that decides which pin a finger meant, and when
/// it should decline to guess.
void _tapResolutionTests() {
  group('resolveTap', () {
    late AppDatabase db;
    late ProjectRepository projects;
    late PartRepository parts;
    late NetRepository nets;
    late Project project;

    /// A part whose pins sit at known places, so distances are exact.
    Future<PartWithDetails> addRow() async {
      final spec = NewPartSpec(
        libId: 'Test:Row',
        value: 'Row',
        referencePrefix: 'U',
        pins: [
          for (var i = 0; i < 4; i++)
            NewPinSpec(
              number: '${i + 1}',
              name: 'P${i + 1}',
              electricalType: PinElectricalType.passive,
              // 2.54 mm apart vertically, the standard schematic pitch.
              y: -2.54 * i,
            ),
        ],
      );
      final part = await parts.addPart(project.id, spec);
      for (final unit in part.units) {
        await parts.updateUnitPlacement(
          unit.copyWith(x: 0, y: 0, placed: true),
        );
      }
      return part;
    }

    Future<SchematicScene> sceneNow() async => SchematicScene.build(
      paper: project.paper,
      parts: await parts.getPartsWithDetails(project.id),
      nets: await nets.getNets(project.id),
      symbols: const {},
    );

    setUp(() async {
      db = AppDatabase.memory();
      projects = ProjectRepository(db);
      parts = PartRepository(db);
      nets = NetRepository(db);
      project = await projects.create(name: 'Taps');
    });

    tearDown(() async => db.close());

    test('a tap away from every pin resolves to nothing', () async {
      await addRow();
      final scene = await sceneNow();

      final result = scene.resolveTap(
        const Offset(50, 50),
        toleranceMm: 3,
        ambiguityMarginMm: 2,
      );

      expect(result, isA<PinTapMissed>());
    });

    test('a tap squarely on a pin picks it', () async {
      await addRow();
      final scene = await sceneNow();
      // Pin 1 sits at symbol (0,0), which is sheet (0,0).
      final result = scene.resolveTap(
        Offset.zero,
        toleranceMm: 3,
        ambiguityMarginMm: 1,
      );

      expect(result, isA<PinTapHit>());
      expect((result as PinTapHit).pin.pin.number, '1');
    });

    test('a tap between two pins asks rather than guessing', () async {
      await addRow();
      final scene = await sceneNow();

      // Halfway between pin 1 (y 0) and pin 2 (y 2.54 on the sheet).
      final result = scene.resolveTap(
        const Offset(0, 1.27),
        toleranceMm: 3,
        ambiguityMarginMm: 1,
      );

      expect(result, isA<PinTapAmbiguous>());
      final candidates = (result as PinTapAmbiguous).candidates;
      expect(candidates.map((p) => p.pin.number).take(2), ['1', '2']);
    });

    test('a clear winner is taken even with another pin in range', () async {
      await addRow();
      final scene = await sceneNow();

      // Close to pin 1; pin 2 is 2.54 mm away, well beyond the margin.
      final result = scene.resolveTap(
        const Offset(0, 0.2),
        toleranceMm: 4,
        ambiguityMarginMm: 1,
      );

      expect(result, isA<PinTapHit>());
      expect((result as PinTapHit).pin.pin.number, '1');
    });

    test('a wide tolerance does not reach past the tolerance', () async {
      await addRow();
      final scene = await sceneNow();

      expect(
        scene.resolveTap(
          const Offset(0, 20),
          toleranceMm: 3,
          ambiguityMarginMm: 1,
        ),
        isA<PinTapMissed>(),
      );
    });

    test('candidates come back nearest first', () async {
      await addRow();
      final scene = await sceneNow();

      final near = scene.pinsNear(const Offset(0, 2.6), 10);
      expect(near.map((p) => p.pin.number).take(3), ['2', '3', '1']);
    });
  });
}

/// Wires: the scene routes each net connection so the canvas can both draw
/// and hit-test exactly the same geometry.
void _wireTests() {
  group('routed wires', () {
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
      project = await projects.create(name: 'Wires');
    });

    tearDown(() async => db.close());

    Future<SchematicScene> sceneNow({
      Map<String, List<double>> hints = const {},
    }) async => SchematicScene.build(
      paper: project.paper,
      parts: await parts.getPartsWithDetails(project.id),
      nets: await nets.getNets(project.id),
      symbols: const {},
      routeHints: hints,
    );

    /// Two resistors, placed apart, with one pin of each joined.
    Future<(PartWithDetails, PartWithDetails)> twoJoinedResistors() async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50, y: 50, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 80, y: 70, placed: true),
      );
      await nets.connectPins(
        r1.pins.firstWhere((p) => p.number == '1').id,
        r2.pins.firstWhere((p) => p.number == '1').id,
      );
      return (r1, r2);
    }

    test('a two-pin net becomes exactly one wire', () async {
      await twoJoinedResistors();
      final scene = await sceneNow();

      expect(scene.wires, hasLength(1));
      expect(scene.wires.single.points.length, greaterThanOrEqualTo(2));
    });

    test('every wire segment is horizontal or vertical', () async {
      await twoJoinedResistors();
      final scene = await sceneNow();

      for (final wire in scene.wires) {
        for (var i = 0; i < wire.points.length - 1; i++) {
          final a = wire.points[i];
          final b = wire.points[i + 1];
          final square =
              (a.dx - b.dx).abs() < 1e-6 || (a.dy - b.dy).abs() < 1e-6;
          expect(square, isTrue, reason: '$a -> $b is diagonal');
        }
      }
    });

    test('a wire starts and ends on its pins', () async {
      final (r1, r2) = await twoJoinedResistors();
      final scene = await sceneNow();
      final wire = scene.wires.single;

      final endpoints = {wire.points.first, wire.points.last};
      final pinPositions = {
        for (final pin in scene.pins)
          if (pin.pin.id == r1.pins.firstWhere((p) => p.number == '1').id ||
              pin.pin.id == r2.pins.firstWhere((p) => p.number == '1').id)
            pin.sheetPosition,
      };
      expect(endpoints, pinPositions);
    });

    test('a route hint slides the wire, leaving its ends attached', () async {
      await twoJoinedResistors();
      final plain = await sceneNow();
      final wire = plain.wires.single;
      expect(wire.isAdjustable, isTrue, reason: 'both pins leave vertically');

      final nudged = await sceneNow(
        hints: {
          wire.key: const [6.35],
        },
      );
      final moved = nudged.wires.single;

      expect(moved.points.first, wire.points.first);
      expect(moved.points.last, wire.points.last);
      expect(
        moved.points,
        isNot(equals(wire.points)),
        reason: 'the middle run should have moved',
      );
    });

    test('a wire can be found by touching it, away from any pin', () async {
      await twoJoinedResistors();
      final scene = await sceneNow();
      final wire = scene.wires.single;

      // A point on the middle of the drawn path.
      final middle = wire.points[wire.points.length ~/ 2];
      expect(scene.wireNear(middle, 1.0)?.key, wire.key);
      expect(scene.wireNear(const Offset(200, 200), 1.0), isNull);
    });

    test(
      'the wire key does not depend on which pin was tapped first',
      () async {
        await twoJoinedResistors();
        final scene = await sceneNow();
        final wire = scene.wires.single;

        expect(wire.key, NetRepository.routeKey(wire.pinAId, wire.pinBId));
        expect(wire.key, NetRepository.routeKey(wire.pinBId, wire.pinAId));
      },
    );

    test('touching a run resolves that run, not the wire as a whole', () async {
      await twoJoinedResistors();
      final scene = await sceneNow();
      final wire = scene.wires.single;
      expect(wire.handles, isNotEmpty);

      final handle = wire.handles.first;
      final middle = Offset(
        (handle.start.dx + handle.end.dx) / 2,
        (handle.start.dy + handle.end.dy) / 2,
      );

      final hit = scene.wireHandleNear(middle, 1.0);
      expect(hit, isNotNull);
      expect(hit!.wire.key, wire.key);
      expect(hit.handle.offsetIndex, handle.offsetIndex);
      expect(scene.wireHandleNear(const Offset(250, 250), 1.0), isNull);
    });

    test(
      'a wire can be grabbed anywhere along it, not just at its corner',
      () async {
        // The stretches either end of a wire must stay attached to their
        // pins, so they are not movable themselves — but they are most of
        // what there is to touch. Grabbing one still has to work.
        await twoJoinedResistors();
        final scene = await sceneNow();
        final wire = scene.wires.single;

        final firstSegmentMiddle = Offset(
          (wire.points[0].dx + wire.points[1].dx) / 2,
          (wire.points[0].dy + wire.points[1].dy) / 2,
        );

        final hit = scene.wireHandleNear(firstSegmentMiddle, 1.0);
        expect(hit, isNotNull);
        expect(hit!.wire.key, wire.key);
      },
    );

    test('a straightened wire can still be grabbed and bent again', () async {
      // Once a wire is straight its movable run has collapsed to a point.
      // If that made it unreachable, straightening a wire would be a
      // one-way door.
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      // Same X, so the pins line up and the route is a single straight run.
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50, y: 50, placed: true),
      );
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 50, y: 90, placed: true),
      );
      await nets.connectPins(
        r1.pins.firstWhere((p) => p.number == '2').id,
        r2.pins.firstWhere((p) => p.number == '1').id,
      );

      final scene = await sceneNow();
      final wire = scene.wires.single;
      final middle = Offset(
        (wire.points.first.dx + wire.points.last.dx) / 2,
        (wire.points.first.dy + wire.points.last.dy) / 2,
      );

      expect(scene.wireHandleNear(middle, 1.5), isNotNull);
    });

    test('an unconnected pin produces no wire', () async {
      await parts.addPart(project.id, resistorSpec());
      final scene = await sceneNow();
      expect(scene.wires, isEmpty);
    });
  });

  group('reported: a wire must not be drawn inside a symbol', () {
    // Joining the drain and gate of a MOSFET routed the wire straight
    // through the transistor. A wire inside a symbol cannot be grabbed
    // afterwards — the symbol is drawn on top of it and wins the tap — so
    // it could be neither moved nor tidied.
    test('drain to gate on one MOSFET goes round the body', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final projects = ProjectRepository(db);
      final parts = PartRepository(db);
      final nets = NetRepository(db);

      final project = await projects.create(name: 'P');
      final q1 = await parts.addPart(project.id, mosfetSpec());
      await nets.connectPins(
        q1.pins.firstWhere((p) => p.name == 'G').id,
        q1.pins.firstWhere((p) => p.name == 'D').id,
      );

      final scene = SchematicScene.build(
        paper: PaperSize.a4,
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        symbols: const {},
      );

      expect(scene.wires, hasLength(1));
      final wire = scene.wires.single;
      final body = scene.boundsOf(scene.units.single);

      for (var i = 0; i < wire.points.length - 1; i++) {
        expect(
          _segmentEntersRect(wire.points[i], wire.points[i + 1], body),
          isFalse,
          reason:
              'segment ${wire.points[i]} → ${wire.points[i + 1]} '
              'runs through Q1',
        );
      }

      // And it is still a wire the user can take hold of and adjust.
      expect(wire.isAdjustable, isTrue);
    });
  });

  group('reported: a wire beside a symbol must still be reachable', () {
    // The wire now routes around the MOSFET, but a symbol's hit box reaches
    // out to the tip of every pin — so the detour lands inside it. Deciding
    // by "is it inside the symbol's box" made the wire unselectable again;
    // deciding by which is nearer is what makes both reachable.
    test('a tap on the detour is nearer the wire than the body', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final projects = ProjectRepository(db);
      final parts = PartRepository(db);
      final nets = NetRepository(db);

      final project = await projects.create(name: 'P');
      final q1 = await parts.addPart(project.id, mosfetSpec());
      await nets.connectPins(
        q1.pins.firstWhere((p) => p.name == 'G').id,
        q1.pins.firstWhere((p) => p.name == 'D').id,
      );

      final scene = SchematicScene.build(
        paper: PaperSize.a4,
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        symbols: const {},
      );

      final unit = scene.units.single;
      final wire = scene.wires.single;

      // Walk the drawn wire. Every point on it that is not right at a pin
      // must resolve to the wire rather than to the symbol.
      var checked = 0;
      for (var i = 0; i < wire.points.length - 1; i++) {
        final a = wire.points[i];
        final b = wire.points[i + 1];
        for (final t in const [0.25, 0.5, 0.75]) {
          final point = Offset.lerp(a, b, t)!;
          // Skip samples that sit on a pin: those are a pin tap, not a wire
          // tap, and the pin is meant to win there.
          final nearPin = scene.pins.any(
            (p) => (p.sheetPosition - point).distance < 1.0,
          );
          if (nearPin) continue;

          checked++;
          expect(
            wire.distanceTo(point),
            lessThan(scene.distanceToBody(unit, point)),
            reason: 'the symbol would steal a tap at $point',
          );
        }
      }
      expect(checked, greaterThan(0), reason: 'nothing was actually checked');
    });

    test('a tap inside the body still belongs to the symbol', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final projects = ProjectRepository(db);
      final parts = PartRepository(db);

      final project = await projects.create(name: 'P');
      await parts.addPart(project.id, mosfetSpec());

      final scene = SchematicScene.build(
        paper: PaperSize.a4,
        parts: await parts.getPartsWithDetails(project.id),
        nets: const [],
        symbols: const {},
      );

      final unit = scene.units.single;
      expect(scene.distanceToBody(unit, scene.bodyBoundsOf(unit).center), 0);
    });
  });

  group('reported: shorting a two-pin part must go round it', () {
    // Joining a resistor's, capacitor's or diode's two pins drew the wire
    // straight through the part. Both pins face along one line, away from
    // each other, so every route of the usual shape runs down that line —
    // and a wire inside a symbol can be neither seen properly nor grabbed.
    for (final (name, spec, rotation) in [
      ('upright resistor', resistorSpec(), 0),
      ('capacitor', capacitorSpec(), 0),
      ('resistor turned on its side', resistorSpec(), 90),
    ]) {
      test(name, () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);

        final projects = ProjectRepository(db);
        final parts = PartRepository(db);
        final nets = NetRepository(db);

        final project = await projects.create(name: 'P');
        final part = await parts.addPart(project.id, spec);
        if (rotation != 0) {
          await parts.updateUnitPlacement(
            part.units.single.copyWith(rotation: rotation),
          );
        }
        await nets.connectPins(part.pins.first.id, part.pins.last.id);

        final scene = SchematicScene.build(
          paper: PaperSize.a4,
          parts: await parts.getPartsWithDetails(project.id),
          nets: await nets.getNets(project.id),
          symbols: const {},
        );

        final wire = scene.wires.single;
        final unit = scene.units.single;
        final body = scene.boundsOf(unit);

        for (var i = 0; i < wire.points.length - 1; i++) {
          expect(
            _segmentEntersRect(wire.points[i], wire.points[i + 1], body),
            isFalse,
            reason:
                'segment ${wire.points[i]} → ${wire.points[i + 1]} '
                'runs through the part',
          );
        }

        // And it can be taken hold of: somewhere along it is nearer the
        // wire than the part, and it has a run to drag.
        expect(wire.isAdjustable, isTrue);
        final middle = Offset.lerp(wire.points[2], wire.points[3], 0.5)!;
        expect(
          wire.distanceTo(middle),
          lessThan(scene.distanceToBody(unit, middle)),
        );
      });
    }
  });
}

bool _segmentEntersRect(Offset a, Offset b, Rect rect) {
  final left = math.min(a.dx, b.dx);
  final right = math.max(a.dx, b.dx);
  final top = math.min(a.dy, b.dy);
  final bottom = math.max(a.dy, b.dy);

  const epsilon = 1e-6;
  return left < rect.right - epsilon &&
      right > rect.left + epsilon &&
      top < rect.bottom - epsilon &&
      bottom > rect.top + epsilon;
}
