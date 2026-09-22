@Tags(['kicad'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/import/kicad_project_importer.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/sheet_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/domain/export/schematic_document.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/kicad/schematic_writer.dart';
import 'package:hintpcb/kicad/symbol_library_reader.dart';

/// A schematic of three sheets, one inside another, written out and handed
/// to the real KiCad: it has to load every file, and its netlist has to be
/// the one the app built.
void main() {
  const symbolPath = '/usr/share/kicad/symbols';
  final kicadCli = [
    '/usr/bin/kicad-cli',
    '/usr/local/bin/kicad-cli',
  ].where((p) => File(p).existsSync()).firstOrNull;
  if (kicadCli == null || !Directory(symbolPath).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  late AppDatabase db;
  late Directory workDir;
  setUp(() async {
    db = AppDatabase.memory();
    workDir = await Directory.systemTemp.createTemp('hintpcb_hierarchy');
  });
  tearDown(() async {
    await db.close();
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  SymbolDefinition load(String library, String name) =>
      SymbolLibraryReader.parseLibrary(
        File('$symbolPath/$library.kicad_sym').readAsBytesSync(),
        nickname: library,
      ).symbols.firstWhere((s) => s.name == name);

  test(
    'three nested sheets load in KiCad with the netlist the app built',
    () async {
      final project = await ProjectRepository(db).create(name: 'Nested');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final sheets = SheetRepository(db);
      final symbols = {
        'Device:R': load('Device', 'R'),
        'power:GND': load('power', 'GND'),
      };

      final power = await sheets.add(
        projectId: project.id,
        name: 'Power',
        at: const Offset(101.6, 50.8),
      );
      final regulator = await sheets.add(
        projectId: project.id,
        name: 'Regulator',
        parentId: power.id,
        at: const Offset(101.6, 50.8),
      );

      Future<PartWithDetails> place(
        String libId,
        Offset at,
        String? sheetId,
      ) async {
        final part = await parts.addPart(
          project.id,
          symbols[libId]!.toNewPartSpec(),
        );
        await parts.updateUnitPlacement(
          part.units.first.copyWith(
            x: at.dx,
            y: at.dy,
            placed: true,
            sheetId: sheetId,
          ),
        );
        return (await parts.getPartWithDetails(part.part.id))!;
      }

      // Top: R1 to ground by a symbol, and on to the sheets below.
      final r1 = await place('Device:R', const Offset(50.8, 50.8), null);
      final gnd = await place('power:GND', const Offset(50.8, 76.2), null);
      // Power: R2. Regulator, inside it: R3 and R4.
      final r2 = await place('Device:R', const Offset(50.8, 50.8), power.id);
      final r3 = await place(
        'Device:R',
        const Offset(50.8, 50.8),
        regulator.id,
      );
      final r4 = await place(
        'Device:R',
        const Offset(76.2, 50.8),
        regulator.id,
      );

      PartPin pin(PartWithDetails part, String n) =>
          part.pins.firstWhere((p) => p.number == n);

      // VMID reaches all three sheets.
      final vmid = await nets.connectPins(pin(r1, '2').id, pin(r2, '1').id);
      await nets.connectPins(pin(r1, '2').id, pin(r3, '1').id);
      await nets.renameNet(vmid.net.id, 'VMID');
      // An unnamed net only between Power and Regulator.
      await nets.connectPins(pin(r2, '2').id, pin(r4, '1').id);
      // Ground: a symbol on the top sheet only, pins on the bottom one.
      await nets.connectPins(pin(r1, '1').id, gnd.pins.single.id);
      await nets.connectPins(pin(r3, '2').id, gnd.pins.single.id);
      await nets.connectPins(pin(r4, '2').id, gnd.pins.single.id);

      final document = SchematicDocument(
        project: (await ProjectRepository(db).getById(project.id))!,
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        symbols: symbols,
        sheets: await sheets.getAll(project.id),
      );
      final files = const SchematicWriter().writeFiles(
        document,
        topFile: 'Nested.kicad_sch',
      );
      expect(files.keys.toSet(), {
        'Nested.kicad_sch',
        'power.kicad_sch',
        'regulator.kicad_sch',
      });
      for (final entry in files.entries) {
        await File('${workDir.path}/${entry.key}').writeAsString(entry.value);
      }
      final top = files['Nested.kicad_sch']!;
      expect(RegExp(r'\(sheet\b').allMatches(top).length, 1);
      expect(files['power.kicad_sch'], contains('(hierarchical_label "VMID"'));
      expect(files['regulator.kicad_sch'], contains('(global_label "GND"'));

      final netlistPath = '${workDir.path}/nested.net';
      final result = await Process.run(
        kicadCli,
        [
          'sch',
          'export',
          'netlist',
          '--output',
          netlistPath,
          '${workDir.path}/Nested.kicad_sch',
        ],
        environment: {'HOME': workDir.path},
      );
      expect(
        result.exitCode,
        0,
        reason: 'kicad-cli refused it\n${result.stdout}\n${result.stderr}',
      );
      final netlist = File(netlistPath).readAsStringSync();
      for (final reference in ['R1', 'R2', 'R3', 'R4']) {
        expect(netlist, contains('(ref "$reference")'), reason: reference);
      }

      // What KiCad joined, as groups of REF.PIN, against the app's nets.
      final groups = _groups(netlist);
      bool joined(List<String> pins) =>
          groups.any((g) => g.length == pins.length && g.containsAll(pins));
      expect(joined(['R1.2', 'R2.1', 'R3.1']), isTrue, reason: '$groups');
      expect(joined(['R2.2', 'R4.1']), isTrue, reason: '$groups');
      // Ground on every sheet: by its symbol on the top one, and by global
      // labels below, which KiCad joins to the symbol.
      expect(joined(['R1.1', 'R3.2', 'R4.2']), isTrue, reason: '$groups');

      // And it loads cleanly for ERC.
      final erc = await Process.run(
        kicadCli,
        [
          'sch',
          'erc',
          '--output',
          '${workDir.path}/erc.rpt',
          '${workDir.path}/Nested.kicad_sch',
        ],
        environment: {'HOME': workDir.path},
      );
      expect(erc.exitCode, 0, reason: '${erc.stdout}\n${erc.stderr}');
      final report = File('${workDir.path}/erc.rpt').readAsStringSync();
      for (final complaint in [
        'failed to load',
        'error loading',
        'unable to parse',
        'malformed',
        'hier_label_mismatch',
        'Hierarchical label',
      ]) {
        expect(
          report,
          isNot(contains(complaint)),
          reason: 'ERC: "$complaint"\n$report',
        );
      }
      // ignore: avoid_print
      print('kicad-cli joined three nested sheets: ${groups.length} nets');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'KiCad\'s complex_hierarchy demo opens with KiCad\'s own netlist',
    () async {
      const demo = '/usr/share/kicad/demos/complex_hierarchy';
      if (!File('$demo/complex_hierarchy.kicad_sch').existsSync()) {
        markTestSkipped('demo not installed');
        return;
      }
      final importer = KicadProjectImporter(
        projects: ProjectRepository(db),
        parts: PartRepository(db),
        nets: NetRepository(db),
        boards: BoardRepository(db),
        symbols: SymbolLibraryRepository(db, InMemoryLibraryStorage()),
        footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
        sheets: SheetRepository(db),
      );
      final result = await importer.import(
        name: 'complex_hierarchy',
        schematic: File('$demo/complex_hierarchy.kicad_sch').readAsStringSync(),
        sheetFiles: {
          'ampli_ht.kicad_sch': File(
            '$demo/ampli_ht.kicad_sch',
          ).readAsStringSync(),
        },
      );
      // The amplifier sheet is used twice: two sheets, two sets of parts.
      final sheets = await SheetRepository(db).getAll(result.project.id);
      expect(sheets, hasLength(2));
      expect(
        result.warnings.where((w) => w.contains('more than once')),
        isNotEmpty,
      );

      // KiCad's own netlist of the same project.
      final netlistPath = '${workDir.path}/demo.net';
      final run = await Process.run(
        kicadCli,
        [
          'sch',
          'export',
          'netlist',
          '--output',
          netlistPath,
          '$demo/complex_hierarchy.kicad_sch',
        ],
        environment: {'HOME': workDir.path},
      );
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      // Power symbols and flags have pins in the app; KiCad's netlist
      // leaves them out. Compared without them, and nets of one pin.
      String? key(Iterable<String> nodes) {
        final kept = [
          for (final n in nodes)
            if (!n.startsWith('#')) n,
        ]..sort();
        return kept.length > 1 ? kept.join(' ') : null;
      }

      final theirs = {
        for (final g in _groups(File(netlistPath).readAsStringSync())) ?key(g),
      };
      final ours = {
        for (final net in await NetRepository(db).getNets(result.project.id))
          ?key([for (final e in net.endpoints) e.shortLabel]),
      };
      expect(
        ours.difference(theirs),
        isEmpty,
        reason: 'joined in the app but not in KiCad',
      );
      expect(
        theirs.difference(ours),
        isEmpty,
        reason: 'joined in KiCad but not in the app',
      );
      // ignore: avoid_print
      print('complex_hierarchy: ${ours.length} nets, the same as KiCad\'s');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// The nets of a KiCad netlist as sets of `REF.PIN`, power symbols left out.
Set<Set<String>> _groups(String netlist) {
  final start = netlist.indexOf('(nets');
  final out = <Set<String>>{};
  for (final block
      in netlist.substring(start).split(RegExp(r'\(net\s*\n')).skip(1)) {
    final nodes = {
      for (final m in RegExp(
        r'\(ref "([^"]+)"\)\s*\n\s*\(pin "([^"]+)"\)',
      ).allMatches(block))
        '${m.group(1)}.${m.group(2)}',
    };
    if (nodes.isNotEmpty) out.add(nodes);
  }
  return out;
}
