@Tags(['kicad'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/import/kicad_project_importer.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/sheet_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/domain/export/schematic_document.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/symbols/symbols.dart';
import 'package:zolt/kicad/schematic_writer.dart';

/// KiCad's own hierarchical demos, brought in and written back out: every
/// sheet pin has to come in where KiCad drew it, and the files written
/// from them have to give KiCad the netlist the originals do.
void main() {
  const demos = '/usr/share/kicad/demos';
  final kicadCli = [
    '/usr/bin/kicad-cli',
    '/usr/local/bin/kicad-cli',
  ].where((p) => File(p).existsSync()).firstOrNull;
  if (kicadCli == null || !Directory(demos).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  late AppDatabase db;
  late Directory workDir;
  setUp(() async {
    db = AppDatabase.memory();
    workDir = await Directory.systemTemp.createTemp('zolt_sheet_pins');
  });
  tearDown(() async {
    await db.close();
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  Future<Set<String>> netlistOf(String schematic, String name) async {
    final path = '${workDir.path}/$name.net';
    final run = await Process.run(
      kicadCli,
      ['sch', 'export', 'netlist', '--output', path, schematic],
      environment: {'HOME': workDir.path},
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    return {for (final g in _groups(File(path).readAsStringSync())) ?_key(g)};
  }

  // Whether the import itself should match KiCad's netlist: not where the
  // design runs buses through its sheets, which the import cannot follow
  // member by member yet.
  for (final (folder, top, faithful) in const [
    // A label written `VPP{slash}MCLR` beside one written `VPP/MCLR`.
    ('pic_programmer', 'pic_programmer.kicad_sch', true),
    // GND's symbol with its value set to BAT- and PGND.
    ('openair-max', 'One-Air-Max.kicad_sch', true),
    (
      'kit-dev-coldfire-xilinx_5213',
      'kit-dev-coldfire-xilinx_5213.kicad_sch',
      false,
    ),
    // Its sheets are in a folder of their own, `sch/`, and it runs bus
    // groups like UART{TX, RX} through them.
    ('royalblue54L_feather', 'RoyalBlue54L-Feather.kicad_sch', false),
  ]) {
    test(
      '$folder: sheet pins come in where KiCad drew them, and go back out',
      () async {
        final dir = Directory('$demos/$folder');
        if (!File('${dir.path}/$top').existsSync()) {
          markTestSkipped('demo not installed');
          return;
        }
        final sheetFiles = {
          for (final f in dir.listSync(recursive: true).whereType<File>())
            if (f.path.endsWith('.kicad_sch') && !f.path.endsWith('/$top'))
              f.uri.pathSegments.last: f.readAsStringSync(),
        };
        final libraries = SymbolLibraryRepository(db, InMemoryLibraryStorage());
        final sheetRepository = SheetRepository(db);
        final importer = KicadProjectImporter(
          projects: ProjectRepository(db),
          parts: PartRepository(db),
          nets: NetRepository(db),
          boards: BoardRepository(db),
          symbols: libraries,
          footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
          sheets: sheetRepository,
        );
        final result = await importer.import(
          name: top.replaceAll('.kicad_sch', ''),
          schematic: File('${dir.path}/$top').readAsStringSync(),
          sheetFiles: sheetFiles,
        );
        expect(
          result.warnings.where((w) => w.contains('was not picked')),
          isEmpty,
          reason: result.warnings.join('\n'),
        );

        // Every pin the files give a sheet box, on the box as it was drawn.
        final sheets = await sheetRepository.getAll(result.project.id);
        final drawn = <String>{};
        for (final text in [
          File('${dir.path}/$top').readAsStringSync(),
          ...sheetFiles.values,
        ]) {
          for (final m in RegExp(
            r'\(pin "([^"]+)" (\w+)\s*\(at ([\d.\-]+) ([\d.\-]+)',
          ).allMatches(text)) {
            drawn.add(
              '${m[1]} ${m[2]} '
              '${double.parse(m[3]!).toStringAsFixed(2)} '
              '${double.parse(m[4]!).toStringAsFixed(2)}',
            );
          }
        }
        final kept = {
          for (final sheet in sheets)
            for (final pin in sheet.pins)
              '${pin.name} ${pin.shape} '
                  '${pin.at(sheet.box).dx.toStringAsFixed(2)} '
                  '${pin.at(sheet.box).dy.toStringAsFixed(2)}',
        };
        expect(kept, isNotEmpty);
        // Symbol pins match the pattern too; every sheet pin is among them.
        expect(kept.difference(drawn), isEmpty);
        // Each finds the net it carries across, whatever it was renamed to.
        final parts = await PartRepository(
          db,
        ).getPartsWithDetails(result.project.id);
        final appNets = await NetRepository(db).getNets(result.project.id);
        final links = SheetConnections.of(
          parts: parts,
          nets: appNets,
          sheets: sheets,
        );
        final views = [
          for (final sheet in sheets)
            SheetBoxView.of(
              sheet,
              crossing: links.crossing(sheet.id),
              nets: appNets,
            ),
        ];
        // A bus pin (`D[0..7]`, `UART{TX, RX}`) carries many nets, which
        // the import does not follow member by member yet.
        bool bus(String name) => name.contains('[') || name.contains('{');
        final stored = [
          for (final v in views)
            for (final p in v.pins.take(v.sheet.pins.length))
              if (!bus(p.name)) p,
        ];
        expect(
          stored.where((p) => p.net != null).length,
          greaterThan(stored.length * 0.8),
          reason: [
            for (final p in stored)
              if (p.net == null) p.name,
          ].join(', '),
        );
        // And no crossing net is left over for a pin of the app's own.
        if (!sheets.any((s) => s.pins.any((p) => bus(p.name)))) {
          expect([
            for (final v in views)
              for (final p in v.pins.skip(v.sheet.pins.length)) p.name,
          ], isEmpty);
        }

        // Written back out, KiCad joins exactly what the app holds.
        final symbols = <String, SymbolDefinition>{};
        for (final libId in parts.map((p) => p.part.libId).toSet()) {
          final symbol = await libraries.loadSymbol(libId);
          if (symbol != null) symbols[libId] = symbol;
        }
        final document = SchematicDocument(
          project: result.project,
          parts: parts,
          nets: appNets,
          symbols: symbols,
          drawnWires: await NetRepository(db).getWires(result.project.id),
          sheets: sheets,
        );
        final files = const SchematicWriter().writeFiles(
          document,
          topFile: top,
        );
        for (final entry in files.entries) {
          final file = File('${workDir.path}/${entry.key}');
          await file.parent.create(recursive: true);
          await file.writeAsString(entry.value);
        }
        final ours = await netlistOf('${workDir.path}/$top', 'exported');
        final theirs = await netlistOf('${dir.path}/$top', 'original');
        final app = {
          for (final net in appNets)
            ?_key([for (final e in net.endpoints) e.shortLabel]),
        };
        // Nothing the app holds is lost on the way out: each of its nets is
        // all on one net of the export.
        expect(
          [
            for (final net in app)
              if (!_within(net, ours)) net,
          ],
          isEmpty,
          reason: 'the export lost a connection the app has',
        );
        if (faithful) {
          // And for a design of what the import follows, all three agree:
          // the original, the app, and the app's export.
          expect(
            app.difference(theirs),
            isEmpty,
            reason: 'joined in the app but not in KiCad',
          );
          expect(
            theirs.difference(app),
            isEmpty,
            reason: 'joined in KiCad but not in the app',
          );
          expect(ours, theirs, reason: 'the round trip changed the netlist');
        } else {
          // Otherwise the export still joins nothing KiCad did not: what it
          // adds to the app's nets is what the import has yet to follow.
          expect(
            [
              for (final net in ours)
                if (!_within(net, theirs)) net,
            ],
            isEmpty,
            reason: 'the export joined what KiCad does not',
          );
        }
        // ignore: avoid_print
        print('$folder: ${kept.length} sheet pins, ${ours.length} nets');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}

/// Whether every pin of [net] is on one of [nets].
bool _within(String net, Set<String> nets) {
  final pins = net.split(' ').toSet();
  return nets.any((other) => other.split(' ').toSet().containsAll(pins));
}

/// A net as its pins, power symbols left out; null for a net of one pin.
String? _key(Iterable<String> nodes) {
  final kept = [
    for (final n in nodes)
      if (!n.startsWith('#')) n,
  ]..sort();
  return kept.length > 1 ? kept.join(' ') : null;
}

/// The nets of a KiCad netlist as sets of `REF.PIN`.
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
