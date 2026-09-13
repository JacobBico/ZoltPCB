@Tags(['kicad'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/export/schematic_document.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/kicad/schematic_writer.dart';
import 'package:hintpcb/kicad/symbol_library_reader.dart';

/// Exports a design and hands it to the real KiCad.
///
/// Everything else about the exporter can be verified by reading the file
/// back with our own parser, which proves only that we are self-consistent.
/// This proves the thing that actually matters: KiCad opens the file, and
/// the netlist it extracts is the netlist the user built.
void main() {
  const symbolPath = '/usr/share/kicad/symbols';
  final kicadCli = _findKicadCli();

  if (kicadCli == null || !Directory(symbolPath).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  late AppDatabase db;
  late Directory workDir;

  setUp(() async {
    db = AppDatabase.memory();
    workDir = await Directory.systemTemp.createTemp('hintpcb_export');
  });

  tearDown(() async {
    await db.close();
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  /// Loads a symbol straight out of the installed KiCad libraries.
  SymbolDefinition load(String library, String name) {
    final parsed = SymbolLibraryReader.parseLibrary(
      File('$symbolPath/$library.kicad_sym').readAsBytesSync(),
      nickname: library,
    );
    return parsed.symbols.firstWhere((s) => s.name == name);
  }

  test('an exported schematic opens in KiCad with the right netlist', () async {
    final projects = ProjectRepository(db);
    final parts = PartRepository(db);
    final nets = NetRepository(db);

    final project = await projects.create(name: 'HintPCB Export Test');

    // A resistor divider into one half of a dual opamp, with the supply
    // pins that live in the opamp's third unit tied to power symbols. That
    // exercises single-unit parts, multi-unit parts, power symbols and
    // named and unnamed nets in one design.
    final symbols = <String, SymbolDefinition>{
      'Device:R': load('Device', 'R'),
      'Device:C': load('Device', 'C'),
      'Amplifier_Operational:LM2904': load('Amplifier_Operational', 'LM2904'),
      'power:GND': load('power', 'GND'),
      'power:+5V': load('power', '+5V'),
    };

    final r1 = await parts.addPart(
      project.id,
      symbols['Device:R']!.toNewPartSpec(value: '10k'),
    );
    final r2 = await parts.addPart(
      project.id,
      symbols['Device:R']!.toNewPartSpec(value: '10k'),
    );
    final c1 = await parts.addPart(
      project.id,
      symbols['Device:C']!.toNewPartSpec(value: '100n'),
    );
    final u1 = await parts.addPart(
      project.id,
      symbols['Amplifier_Operational:LM2904']!.toNewPartSpec(),
    );
    final gnd = await parts.addPart(
      project.id,
      symbols['power:GND']!.toNewPartSpec(),
    );
    final v5 = await parts.addPart(
      project.id,
      symbols['power:+5V']!.toNewPartSpec(),
    );

    PartPin pinOf(PartWithDetails part, String number) =>
        part.pins.firstWhere((p) => p.number == number);

    // Divider: +5V - R1 - midpoint - R2 - GND
    final rail = await nets.connectPins(
      pinOf(r1, '1').id,
      v5.pins.single.id,
    );
    final mid = await nets.connectPins(pinOf(r1, '2').id, pinOf(r2, '1').id);
    await nets.connectPins(pinOf(r2, '2').id, gnd.pins.single.id);

    // Midpoint into the opamp's non-inverting input, output fed back.
    await nets.connectPins(pinOf(u1, '3').id, pinOf(r1, '2').id);
    await nets.connectPins(pinOf(u1, '1').id, pinOf(u1, '2').id);
    await nets.renameNet(mid.id, 'VMID');

    // Supply pins of the opamp, which live in its own unit.
    await nets.connectPins(pinOf(u1, '8').id, pinOf(r1, '1').id);
    await nets.connectPins(pinOf(u1, '4').id, pinOf(r2, '2').id);

    // Decoupling across the rails.
    await nets.connectPins(pinOf(c1, '1').id, pinOf(u1, '8').id);
    await nets.connectPins(pinOf(c1, '2').id, pinOf(u1, '4').id);

    final document = SchematicDocument(
      project: (await projects.getById(project.id))!,
      parts: await parts.getPartsWithDetails(project.id),
      nets: await nets.getNets(project.id),
      symbols: symbols,
    );

    final file = File('${workDir.path}/export_test.kicad_sch');
    final text = const SchematicWriter().write(document);
    await file.writeAsString(text);

    // The file has to be a drawing, not just a correct netlist. Every net
    // in this design is routable, so all of them should arrive as wires —
    // and the netlist assertions below then prove those wires join exactly
    // what the user joined and nothing else.
    final wireCount = RegExp(r'\(wire\b').allMatches(text).length;
    expect(wireCount, greaterThan(0), reason: 'no wires were exported');

    // KiCad reads the file and writes out what it believes is connected.
    final netlistPath = '${workDir.path}/export_test.net';
    final result = await Process.run(kicadCli, [
      'sch',
      'export',
      'netlist',
      '--output',
      netlistPath,
      file.path,
    ], environment: {'HOME': workDir.path});

    expect(
      result.exitCode,
      0,
      reason:
          'kicad-cli refused the file\n'
          'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(File(netlistPath).existsSync(), isTrue);

    final netlist = File(netlistPath).readAsStringSync();

    // Every component reached KiCad. Power symbols are deliberately absent:
    // KiCad treats a #PWR part as a label, not a component.
    for (final reference in ['R1', 'R2', 'C1', 'U1']) {
      expect(netlist, contains('(ref "$reference")'), reason: reference);
    }

    final extracted = _parseNets(netlist);

    // KiCad scopes a local label to its sheet and writes it with a leading
    // slash; a net named by a power symbol is global and keeps its bare
    // name. Both are correct, so the comparison ignores the prefix.
    expect(extracted.keys, containsAll(['VMID', 'GND', '+5V']));

    expect(extracted['VMID'], {'R1.2', 'R2.1', 'U1.3'});
    expect(extracted['+5V'], {'R1.1', 'C1.1', 'U1.8'});
    expect(extracted['GND'], {'R2.2', 'C1.2', 'U1.4'});

    // The opamp's own feedback loop, which was never given a label.
    final feedback = extracted.entries.firstWhere(
      (e) => e.value.containsAll({'U1.1', 'U1.2'}),
      orElse: () => const MapEntry('', <String>{}),
    );
    expect(feedback.key, isNotEmpty, reason: 'feedback net missing');

    // The unused half of the opamp is reported unconnected, not wrongly
    // joined to something.
    expect(
      extracted.keys.where((n) => n.startsWith('unconnected-')),
      isNotEmpty,
    );

    expect(rail.net.name, '+5V');

    // ERC additionally proves KiCad loads the sheet and its embedded
    // symbols cleanly: a malformed file or an unresolvable lib_id fails
    // here even when a netlist could still be scraped out of it.
    final erc = await Process.run(kicadCli, [
      'sch',
      'erc',
      '--output',
      '${workDir.path}/erc.rpt',
      file.path,
    ], environment: {'HOME': workDir.path});

    expect(
      erc.exitCode,
      0,
      reason: 'ERC failed to load the sheet\n${erc.stdout}\n${erc.stderr}',
    );
    // The report will contain ordinary design findings — this deliberately
    // small circuit has an unused opamp half and no PWR_FLAG — and a note
    // that the test machine's empty KiCad profile has no library table.
    // What must not appear is any sign that the file itself is malformed.
    final report = File('${workDir.path}/erc.rpt').readAsStringSync();
    for (final complaint in [
      'failed to load',
      'error loading',
      'unable to parse',
      'unresolved',
      'malformed',
    ]) {
      expect(
        report.toLowerCase(),
        isNot(contains(complaint)),
        reason: 'ERC reported "$complaint":\n$report',
      );
    }

    // ignore: avoid_print
    print(
      'kicad-cli accepted the export: ${extracted.length} nets from '
      '${document.parts.length} parts, $wireCount wire segments, ERC clean',
    );
    }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Reads the `(nets ...)` section of a KiCad netlist into net name to the
/// set of `REF.PIN` nodes on it.
Map<String, Set<String>> _parseNets(String netlist) {
  final start = netlist.indexOf('(nets');
  if (start < 0) return {};

  final result = <String, Set<String>>{};
  final blocks = netlist.substring(start).split(RegExp(r'\(net\s*\n'));
  for (final block in blocks.skip(1)) {
    final name = RegExp(r'\(name "([^"]*)"\)').firstMatch(block)?.group(1);
    if (name == null) continue;

    final nodes = <String>{};
    final refs = RegExp(
      r'\(ref "([^"]+)"\)\s*\n\s*\(pin "([^"]+)"\)',
    ).allMatches(block);
    for (final match in refs) {
      nodes.add('${match.group(1)}.${match.group(2)}');
    }
    // Strip the sheet path KiCad prefixes onto local labels.
    result[name.startsWith('/') ? name.substring(1) : name] = nodes;
  }
  return result;
}

String? _findKicadCli() {
  for (final path in ['/usr/bin/kicad-cli', '/usr/local/bin/kicad-cli']) {
    if (File(path).existsSync()) return path;
  }
  return null;
}
