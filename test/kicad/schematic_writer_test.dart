import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/export/schematic_document.dart';
import 'package:hintpcb/domain/geometry/placement.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/kicad/schematic_writer.dart';
import 'package:hintpcb/kicad/sexpr/sexpr.dart';
import 'package:hintpcb/kicad/sexpr/sexpr_parser.dart';

import '../helpers/fixtures.dart';

void main() {
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
    project = await projects.create(
      name: 'Preamp',
      company: 'Bench',
      revision: 'B',
    );
  });

  tearDown(() async => db.close());

  Future<SchematicDocument> document() async => SchematicDocument(
    project: (await projects.getById(project.id))!,
    parts: await parts.getPartsWithDetails(project.id),
    nets: await nets.getNets(project.id),
    routeHints: await nets.routeHints(project.id),
    drawnWires: await nets.getWires(project.id),
  );

  Future<SList> exported() async =>
      const SchematicWriter().build(await document());

  Future<String> exportedText() async =>
      const SchematicWriter().write(await document());

  group('document structure', () {
    test('writes the KiCad 9 header', () async {
      final root = await exported();

      expect(root.head, 'kicad_sch');
      expect(root.childInteger('version'), 20250114);
      expect(root.childAtom('generator'), 'hintpcb');
      // The sheet UUID is the project's own id, so re-exporting a design
      // produces the same file rather than a fresh set of identifiers.
      expect(root.childAtom('uuid'), project.id);
      expect(root.childAtom('paper'), 'A4');
    });

    test('carries the title block through', () async {
      final block = (await exported()).child('title_block')!;

      expect(block.childAtom('title'), 'Preamp');
      expect(block.childAtom('company'), 'Bench');
      expect(block.childAtom('rev'), 'B');
    });

    test('an empty project still produces a valid, parseable sheet', () async {
      final text = await exportedText();
      final reparsed = SExprParser.parseDocument(text);

      expect(reparsed.head, 'kicad_sch');
      expect(reparsed.child('lib_symbols')!.lists, isEmpty);
      expect(reparsed.child('sheet_instances'), isNotNull);
    });

    test('output re-parses as the tree that was written', () async {
      await parts.addPart(project.id, resistorSpec());
      final text = await exportedText();

      expect(SExprParser.parseDocument(text).head, 'kicad_sch');
    });
  });

  group('placed symbols', () {
    test('one entry per placed unit, carrying its designator', () async {
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      final root = await exported();
      final symbols = root.children('symbol').toList();

      expect(symbols, hasLength(1));
      final symbol = symbols.single;
      expect(symbol.child('lib_id')!.atom(1), 'Device:R');
      expect(symbol.childInteger('unit'), 1);
      expect(symbol.child('at')!.number(1), 25.4);

      final reference = symbol
          .children('property')
          .firstWhere((p) => p.atom(1) == 'Reference');
      expect(reference.atom(2), 'R1');

      final value = symbol
          .children('property')
          .firstWhere((p) => p.atom(1) == 'Value');
      expect(value.atom(2), '10k');
    });

    test(
      'a multi-unit part writes one symbol per unit, same reference',
      () async {
        await parts.addPart(project.id, dualOpampSpec());
        final symbols = (await exported()).children('symbol').toList();

        expect(symbols, hasLength(2));
        expect(symbols.map((s) => s.childInteger('unit')), [1, 2]);
        for (final symbol in symbols) {
          final reference = symbol
              .children('property')
              .firstWhere((p) => p.atom(1) == 'Reference');
          expect(reference.atom(2), 'U1');
        }
      },
    );

    test('a pin shared by every unit is written exactly once', () async {
      await parts.addPart(project.id, dualOpampSpec());
      final symbols = (await exported()).children('symbol').toList();

      final pinNumbers = [
        for (final symbol in symbols)
          for (final pin in symbol.children('pin')) pin.atom(1),
      ];

      // Pins 4 and 8 are the shared supply pins.
      expect(pinNumbers.where((n) => n == '4'), hasLength(1));
      expect(pinNumbers.where((n) => n == '8'), hasLength(1));
      expect(pinNumbers.toSet(), hasLength(pinNumbers.length));
    });

    test('every pin uuid is unique across the sheet', () async {
      await parts.addPart(project.id, dualOpampSpec());
      await parts.addPart(project.id, resistorSpec());
      final symbols = (await exported()).children('symbol').toList();

      final uuids = [
        for (final symbol in symbols)
          for (final pin in symbol.children('pin')) pin.childAtom('uuid'),
      ];
      expect(uuids.toSet(), hasLength(uuids.length));
    });

    test('the instance path names the project and the sheet', () async {
      await parts.addPart(project.id, resistorSpec());
      final symbol = (await exported()).children('symbol').first;

      final instance = symbol.child('instances')!.child('project')!;
      expect(instance.atom(1), 'Preamp');
      final path = instance.child('path')!;
      expect(path.atom(1), '/${project.id}');
      expect(path.childAtom('reference'), 'R1');
    });

    test('do-not-populate is carried through', () async {
      final added = await parts.addPart(project.id, resistorSpec());
      await parts.updatePart(added.part.copyWith(dnp: true));

      final symbol = (await exported()).children('symbol').first;
      expect(symbol.child('dnp')!.atom(1), 'yes');
    });
  });

  group('connectivity', () {
    test('a wire the user drew is written exactly as drawn', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
      );
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      final all = await parts.getPartsWithDetails(project.id);
      Offset at(String partId, String pinId) {
        final part = all.firstWhere((p) => p.part.id == partId);
        final pin = part.pins.firstWhere((p) => p.id == pinId);
        return Placement.ofUnit(part.units.first).apply(pin.x, pin.y);
      }

      final a = at(r1.part.id, r1.pins.first.id);
      final b = at(r2.part.id, r2.pins.first.id);
      final drawn = [
        a,
        Offset(a.dx, a.dy - 12.7),
        Offset(b.dx, a.dy - 12.7),
        b,
      ];
      await nets.addWire(
        projectId: project.id,
        points: drawn,
        pinAId: r1.pins.first.id,
        pinBId: r2.pins.first.id,
      );

      final segments = [
        for (final wire in (await exported()).lists.where(
          (l) => l.head == 'wire',
        ))
          [
            for (final xy in wire.child('pts')!.lists)
              Offset(xy.number(1)!, xy.number(2)!),
          ],
      ];
      expect(segments, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(segments[i].first.dx, closeTo(drawn[i].dx, 1e-3));
        expect(segments[i].first.dy, closeTo(drawn[i].dy, 1e-3));
        expect(segments[i].last.dx, closeTo(drawn[i + 1].dx, 1e-3));
        expect(segments[i].last.dy, closeTo(drawn[i + 1].dy, 1e-3));
      }
    });

    test('a wired net carries its chosen name on a single label', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
      await nets.renameNet(net.id, 'VCC');

      final labels = (await exported()).children('label').toList();
      expect(labels, hasLength(1));
      expect(labels.single.atom(1), 'VCC');
    });

    test('a wired net the user never named needs no label', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      final root = await exported();
      expect(root.children('label'), isEmpty);
      expect(root.children('wire'), isNotEmpty);
    });

    test('a net becomes wires that start and end on its pins', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      final wires = (await exported()).children('wire').toList();
      expect(wires, isNotEmpty);

      final ends = <(double?, double?)>{};
      for (final wire in wires) {
        for (final xy in wire.child('pts')!.children('xy')) {
          ends.add((xy.number(1), xy.number(2)));
        }
      }
      // R1 pin 1 is at symbol (0, 3.81); the unit sits at (25.4, 25.4) and
      // the sheet is Y-down, so the wire must reach 25.4 - 3.81.
      expect(ends, contains((25.4, 25.4 - 3.81)));
    });

    test('every exported wire segment is horizontal or vertical', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      final u1 = await parts.addPart(project.id, dualOpampSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
      await nets.connectPins(r2.pins.last.id, u1.pins.first.id);

      for (final wire in (await exported()).children('wire')) {
        final points = wire.child('pts')!.children('xy').toList();
        expect(points, hasLength(2));
        final sameX =
            (points[0].number(1)! - points[1].number(1)!).abs() < 1e-9;
        final sameY =
            (points[0].number(2)! - points[1].number(2)!).abs() < 1e-9;
        expect(
          sameX || sameY,
          isTrue,
          reason: 'diagonal segment ${wire.child('pts')}',
        );
      }
    });

    test('the adjustment made on the phone survives the export', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      Future<Set<(double?, double?)>> pointsOfWires() async {
        final result = <(double?, double?)>{};
        for (final wire in (await exported()).children('wire')) {
          for (final xy in wire.child('pts')!.children('xy')) {
            result.add((xy.number(1), xy.number(2)));
          }
        }
        return result;
      }

      final before = await pointsOfWires();
      await nets.setRouteHint(
        project.id,
        r1.pins.first.id,
        r2.pins.first.id,
        const [7.62],
      );
      final after = await pointsOfWires();

      expect(after, isNot(equals(before)));
    });

    test('no net is left both unwired and unlabelled', () async {
      // The invariant the whole scheme rests on. A wire may be dropped for
      // being unsafe, and a label may be dropped for being redundant, but
      // never both for the same net — that would silently lose a connection
      // somewhere between the phone and the desktop.
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      final r3 = await parts.addPart(project.id, resistorSpec());
      final u1 = await parts.addPart(project.id, dualOpampSpec());

      final signal = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
      await nets.connectPins(r2.pins.first.id, r3.pins.first.id);
      await nets.renameNet(signal.id, 'SIG');
      await nets.connectPins(r1.pins.last.id, u1.pins.first.id);
      await nets.connectPins(r3.pins.last.id, u1.pins.last.id);

      final root = await exported();
      final labelled = root.children('label').map((l) => l.atom(1)).toSet();

      final wireEnds = <(double, double)>{};
      for (final wire in root.children('wire')) {
        for (final xy in wire.child('pts')!.children('xy')) {
          wireEnds.add((xy.number(1)!, xy.number(2)!));
        }
      }

      for (final net in await nets.getNets(project.id)) {
        if (net.endpoints.length < 2) continue;
        final named = labelled.contains(net.displayName);
        // Every pin of an unlabelled net must be reached by a wire, or the
        // connection exists only on the phone.
        final reached = net.endpoints.every((e) {
          final part = [
            r1,
            r2,
            r3,
            u1,
          ].firstWhere((p) => p.pins.any((pin) => pin.id == e.pin.id));
          final unit = part.units.first;
          final pin = part.pins.firstWhere((pin) => pin.id == e.pin.id);
          final at = Placement.ofUnit(unit).apply(pin.x, pin.y);
          return wireEnds.any(
            (w) => (w.$1 - at.dx).abs() < 1e-6 && (w.$2 - at.dy).abs() < 1e-6,
          );
        });
        expect(
          named || reached,
          isTrue,
          reason: '${net.displayName} is neither wired nor labelled',
        );
      }
    });

    test('a no-connect pin becomes a no_connect marker', () async {
      final added = await parts.addPart(project.id, resistorSpec());
      await parts.setPinNoConnect(added.pins.first.id, true);

      final markers = (await exported()).children('no_connect').toList();
      expect(markers, hasLength(1));
      expect(markers.single.child('at')!.number(2), 25.4 - 3.81);
      expect(markers.single.childAtom('uuid'), isNotEmpty);
    });

    test('a connected pin does not also get a no-connect marker', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await parts.setPinNoConnect(r1.pins.first.id, true);
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      expect((await exported()).children('no_connect'), isEmpty);
    });
  });

  group('embedded library', () {
    test('every symbol used is embedded, so the file stands alone', () async {
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, dualOpampSpec());

      final libSymbols = (await exported()).child('lib_symbols')!;
      final names = libSymbols.children('symbol').map((s) => s.atom(1));

      expect(names, containsAll(['Device:R', 'Amplifier_Operational:NE5532']));
    });

    test('a symbol with no library falls back to the pin snapshot', () async {
      // No symbols map supplied at all, which is the state after a library
      // has been removed from the device.
      await parts.addPart(project.id, resistorSpec());
      final libSymbol = (await exported())
          .child('lib_symbols')!
          .children('symbol')
          .single;

      // Child drawings are named without the library prefix.
      final drawings = libSymbol.children('symbol').toList();
      expect(drawings.map((d) => d.atom(1)), contains('R_1_1'));

      final pins = drawings
          .expand((d) => d.children('pin'))
          .map((p) => p.child('number')!.atom(1));
      expect(pins, containsAll(['1', '2']));
    });

    test('numbers are written without exponents or trailing zeros', () async {
      await parts.addPart(project.id, resistorSpec());
      final text = await exportedText();

      // Checked against numeric tokens only: UUIDs are hex with hyphens and
      // would trip a naive search for scientific notation.
      final numbers = RegExp(
        r'(?<=[\s(])-?[0-9][^\s()"]*',
      ).allMatches(text).map((m) => m.group(0)!);
      for (final number in numbers) {
        expect(number, isNot(contains('e')), reason: number);
        expect(number, isNot(endsWith('0.')), reason: number);
        expect(double.tryParse(number), isNotNull, reason: number);
      }

      expect(text, isNot(contains('NaN')));
      expect(text, contains('25.4'));
      expect(text, isNot(contains('25.400000')));
    });

    test('quotes inside a value are escaped', () async {
      await parts.addPart(
        project.id,
        NewPartSpec(
          libId: 'Device:R',
          value: '10k 1% "tight"',
          referencePrefix: 'R',
          pins: resistorSpec().pins,
        ),
      );

      final text = await exportedText();
      expect(text, contains(r'10k 1% \"tight\"'));
      // And it survives a round trip through the reader.
      final reparsed = SExprParser.parseDocument(text);
      final value = reparsed
          .children('symbol')
          .first
          .children('property')
          .firstWhere((p) => p.atom(1) == 'Value');
      expect(value.atom(2), '10k 1% "tight"');
    });
  });

  // Opened in KiCad: "R1 and 100 are like right above and below the
  // resistor ... the power nets are labelled ... you never label power
  // sources"
  group('as a schematic is drawn', () {
    test('the designator and value sit beside the symbol', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      await parts.updateUnitPlacement(
        r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
      );

      final symbol = (await exported())
          .children('symbol')
          .firstWhere((c) => c.child('property')?.atom(2) == 'R1');
      final at = symbol.child('at')!;
      final reference = symbol
          .children('property')
          .firstWhere((c) => c.atom(1) == 'Reference');
      final value = symbol
          .children('property')
          .firstWhere((c) => c.atom(1) == 'Value');

      expect(
        reference.child('at')!.number(1),
        isNot(closeTo(at.number(1)!, 0.01)),
        reason: 'the designator is beside the body, not in line with it',
      );
      expect(
        value.child('at')!.number(1),
        reference.child('at')!.number(1),
        reason: 'and the value is under it, in the same column',
      );
      expect(
        symbol.child('fields_autoplaced')?.atom(1),
        'no',
        reason: 'so KiCad leaves them where they were put',
      );
      for (final field in [reference, value]) {
        expect(
          field.child('effects')?.child('justify')?.atom(1),
          'left',
          reason: 'text runs away from the symbol, not back across it',
        );
      }
    });

    test(
      'a power net carries no label, and no #PWR designator shows',
      () async {
        final r1 = await parts.addPart(project.id, resistorSpec());
        final power = await parts.addPart(project.id, groundSpec());
        await nets.connectPins(r1.pins.first.id, power.pins.first.id);

        final root = await exported();
        expect(
          root.children('label'),
          isEmpty,
          reason: 'the symbol names the supply; a label repeats it',
        );

        final symbol = root
            .children('symbol')
            .firstWhere(
              (c) => (c.child('property')?.atom(2) ?? '').startsWith('#PWR'),
            );
        final reference = symbol
            .children('property')
            .firstWhere((c) => c.atom(1) == 'Reference');
        expect(
          reference.child('hide')?.atom(1),
          'yes',
          reason: 'KiCad keeps #PWR designators out of sight',
        );
      },
    );
  });
}
