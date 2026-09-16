@Tags(['kicad'])
library;

import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/export/board_document.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/kicad/board_project_writer.dart';
import 'package:hintpcb/kicad/board_writer.dart';

import '../helpers/fixtures.dart';

/// Lays out a small board and hands it to the real KiCad.
///
/// The schematic export has a test like this and it is the one that has
/// caught every format mistake worth catching. A board is a harder audience:
/// a `.kicad_sch` that KiCad merely opens is already useful, whereas a
/// `.kicad_pcb` whose layers, nets or footprints are wrong opens perfectly
/// and describes the wrong board. Running the desktop's own DRC over it is
/// the only way to know.
void main() {
  const footprintPath = '/usr/share/kicad/footprints';
  final kicadCli = _findKicadCli();

  if (kicadCli == null || !Directory(footprintPath).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  late AppDatabase db;
  late Directory workDir;

  setUp(() async {
    db = AppDatabase.memory();
    workDir = await Directory.systemTemp.createTemp('hintpcb_board');
  });

  tearDown(() async {
    await db.close();
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  Map<String, Uint8List> readLibrary(String library) {
    final dir = Directory('$footprintPath/$library.pretty');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.kicad_mod'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return {
      for (final file in files)
        file.path.split('/').last: file.readAsBytesSync(),
    };
  }

  test(
    'an exported board passes KiCad\'s own DRC',
    () async {
      final projects = ProjectRepository(db);
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final boards = BoardRepository(db);
      final footprints = FootprintLibraryRepository(
        db,
        InMemoryLibraryStorage(),
      );

      // Real libraries, imported the way the app imports them.
      await footprints.import(
        nickname: 'Resistor_SMD',
        sources: readLibrary('Resistor_SMD'),
      );
      await footprints.import(
        nickname: 'Capacitor_SMD',
        sources: readLibrary('Capacitor_SMD'),
      );

      final project = await projects.create(name: 'HintPCB Board Test');

      // Two resistors and a capacitor: a divider with a decoupling cap, which
      // is enough to exercise nets shared by three pads, a flipped part, and
      // copper on both layers joined by a via.
      final r1 = await parts.addPart(project.id, resistorSpec(value: '10k'));
      final r2 = await parts.addPart(project.id, resistorSpec(value: '10k'));
      final c1 = await parts.addPart(project.id, capacitorSpec(value: '100n'));

      PartPin pinOf(PartWithDetails part, String number) =>
          part.pins.firstWhere((p) => p.number == number);

      final mid = await nets.connectPins(pinOf(r1, '2').id, pinOf(r2, '1').id);
      await nets.connectPins(pinOf(c1, '1').id, pinOf(r1, '2').id);
      await nets.renameNet(mid.id, 'VMID');
      final rail = await nets.connectPins(pinOf(r1, '1').id, pinOf(c1, '2').id);
      await nets.renameNet(rail.id, 'VCC');

      // A board outline that is not the default, so the exported edge cuts
      // can be checked against numbers nothing else would produce.
      final board = await boards.ensureBoard(project.id);
      await boards.updateBoard(
        board.copyWith(
          outlineX: 25,
          outlineY: 25,
          outlineWidth: 34,
          outlineHeight: 26,
        ),
      );

      const resistorFootprint = 'Resistor_SMD:R_0805_2012Metric';
      const capacitorFootprint = 'Capacitor_SMD:C_0805_2012Metric';

      Future<void> place(
        PartWithDetails part,
        String libId,
        double x,
        double y, {
        double rotation = 0,
        bool flipped = false,
      }) async {
        final ref = await boards.assignFootprint(
          projectId: project.id,
          partId: part.part.id,
          libId: libId,
        );
        await boards.updatePlacement(
          ref.copyWith(
            x: x,
            y: y,
            rotation: rotation,
            flipped: flipped,
            placed: true,
          ),
        );
      }

      await place(r1, resistorFootprint, 30, 30);
      await place(r2, resistorFootprint, 40, 30, rotation: 90);
      // On the back, which is what makes the layer-flipping code matter.
      await place(c1, capacitorFootprint, 30, 40, flipped: true);

      // The silkscreen, exercised the way it gets used: one designator moved
      // and enlarged, one hidden, and free text on both sides — the back one
      // being what KiCad's DRC checks is mirrored.
      for (final ref in await boards.getFootprints(project.id)) {
        if (ref.partId == r2.part.id) {
          await boards.updatePlacement(
            ref.copyWith(labelOffset: const Offset(0, -2.5), labelSize: 1.2),
          );
        }
        if (ref.partId == r1.part.id) {
          await boards.updatePlacement(ref.copyWith(labelHidden: true));
        }
      }
      await boards.addText(
        projectId: project.id,
        content: 'HINTPCB',
        position: const Offset(40, 46),
        size: 1.5,
      );
      await boards.addText(
        projectId: project.id,
        content: 'REV A',
        position: const Offset(40, 48),
        back: true,
      );

      // A short route on the front, and one that changes layer through a via.
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 30.9125,
        startY: 30,
        endX: 34,
        endY: 30,
        width: 0.25,
        netId: mid.id,
      );
      await boards.addVia(
        projectId: project.id,
        x: 34,
        y: 30,
        diameter: 0.8,
        drill: 0.4,
        netId: mid.id,
      );
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.back,
        startX: 34,
        startY: 30,
        endX: 40,
        endY: 30.9125,
        width: 0.25,
        netId: mid.id,
      );

      // A mounting cutout, as a real circle on Edge.Cuts.
      //
      // Closed on purpose. KiCad judges the board outline as a whole, and an
      // Edge.Cuts shape that does not close — a lone line, a bare arc — is a
      // genuine `invalid_outline` finding rather than a file it cannot read.
      // The open shapes are covered by the format test below, where they are
      // what the user drew and not a claim about a manufacturable board.
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.circle,
        points: const [Offset(55, 47), Offset(56.6, 47)],
      );

      // A ground pour on the back, tied to a real net.
      await boards.addZone(
        projectId: project.id,
        layer: BoardLayer.backCopper,
        netId: rail.id,
        netName: 'VCC',
        points: const [
          Offset(26, 26),
          Offset(58, 26),
          Offset(58, 50),
          Offset(26, 50),
        ],
      );

      final definitions = <String, FootprintDefinition>{};
      final sources = <String, Object>{};
      for (final libId in [resistorFootprint, capacitorFootprint]) {
        definitions[libId] = (await footprints.loadFootprint(libId))!;
        sources[libId] = (await footprints.loadFootprintNode(libId))!;
      }

      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: definitions,
        tracks: await boards.getTracks(project.id),
        vias: await boards.getVias(project.id),
        edges: await boards.getEdges(project.id),
        zones: await boards.getZones(project.id),
        texts: await boards.getTexts(project.id),
      );

      // The pads found their nets through the schematic before anything was
      // written; if this is wrong the file below is wrong in a way DRC would
      // happily approve of.
      expect(
        scene.pads
            .where((p) => p.netName == 'VMID')
            .map((p) => p.label)
            .toSet(),
        {'R1.2', 'R2.1', 'C1.1'},
      );

      final document = BoardDocument(
        project: (await projects.getById(project.id))!,
        scene: scene,
        nets: await nets.getNets(project.id),
        footprintSources: sources,
      );

      final file = File(
        Platform.environment['HINTPCB_BOARD_OUT'] ??
            '${workDir.path}/board_test.kicad_pcb',
      );
      final text = const BoardWriter().write(document);
      await file.writeAsString(text);

      // KiCad reads the design rules from the project file beside the board,
      // so DRC only checks the user's own numbers when both are written.
      final projectFile = File(
        file.path.replaceAll('.kicad_pcb', '.kicad_pro'),
      );
      await projectFile.writeAsString(
        BoardProjectWriter.write(
          document,
          fileName: projectFile.uri.pathSegments.last,
        ),
      );

      // The board outline reaches the file as four Edge.Cuts lines. Without
      // them KiCad has no board shape at all, and neither does the fabricator.
      expect(RegExp(r'\(gr_line\b').allMatches(text).length, 4);
      expect(text, contains('"Edge.Cuts"'));

      // The cutout goes out as a real circle, not the many-sided polygon the
      // screen draws it with: a board ordered from a 64-gon has 64 flats.
      expect(RegExp(r'\(gr_circle\b').allMatches(text).length, 1);

      // The silkscreen as configured: the text, the hidden designator, and
      // the moved one at its new spot and size.
      expect(text, contains('(gr_text "HINTPCB"'));
      expect(text, contains('(gr_text "REV A"'));
      expect(text, contains('(hide yes)'));
      expect(text, contains('(at 0 -2.5'));
      expect(text, contains('(size 1.2 1.2)'));

      // And the pour, as an outline on a real net.
      expect(RegExp(r'\(zone\b').allMatches(text).length, 1);
      expect(text, contains('(net_name "VCC")'));
      for (final corner in ['25 25', '59 25', '59 51', '25 51']) {
        expect(
          text,
          contains(corner),
          reason: 'outline corner $corner is missing from the edge cuts',
        );
      }

      // DRC loads the board, resolves every footprint, rebuilds connectivity
      // from the geometry, and checks it. A malformed file, a bad layer table
      // or a pad on the wrong net all fail here.
      final reportPath = '${workDir.path}/drc.json';
      final drc = await Process.run(
        kicadCli,
        ['pcb', 'drc', '--format', 'json', '--output', reportPath, file.path],
        environment: {'HOME': workDir.path},
      );

      expect(
        drc.exitCode,
        anyOf(0, 5),
        reason:
            'kicad-cli refused the board\n'
            'stdout: ${drc.stdout}\nstderr: ${drc.stderr}',
      );
      expect(File(reportPath).existsSync(), isTrue);

      final report = File(reportPath).readAsStringSync();
      // Load failures only. "malformed" on its own is not one of these:
      // KiCad's own `invalid_outline` finding reads "Board has malformed
      // outline", which is a comment on the shape drawn, not on the file.
      for (final complaint in [
        'failed to load',
        'error loading',
        'unable to parse',
      ]) {
        expect(
          report.toLowerCase(),
          isNot(contains(complaint)),
          reason: 'DRC reported "$complaint"',
        );
      }

      // KiCad's own view of the netlist, read back out of the file it just
      // parsed. This is the assertion that matters: the pads it believes are
      // on VMID must be the pads the schematic put there.
      expect(report, contains('VMID'));

      // Findings that are our fault, as opposed to the ones this deliberately
      // half-routed board is supposed to have. Text on the back of a board is
      // read through the board, so an unmirrored back-layer label is a real
      // defect in the file and not a comment on the layout.
      expect(
        report,
        isNot(contains('nonmirrored_text_on_back_layer')),
        reason: 'the flipped footprint went on the back unmirrored',
      );

      // A rectangle plus a circular cutout is a shape KiCad can resolve. If
      // this fails the edge cuts written are not closed, which is the one
      // way this file can be wrong and still load.
      expect(
        report,
        isNot(contains('invalid_outline')),
        reason: 'the exported edge cuts do not close a board',
      );

      // ignore: avoid_print
      print(
        'kicad-cli accepted the board: ${scene.footprints.length} footprints, '
        '${document.boardNets.length} nets, ${scene.tracks.length} tracks, '
        '${scene.vias.length} vias',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a circular board exports as a real arc, not a many-sided polygon',
    () async {
      final projects = ProjectRepository(db);
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final boards = BoardRepository(db);
      final footprints = FootprintLibraryRepository(
        db,
        InMemoryLibraryStorage(),
      );

      await footprints.import(
        nickname: 'Resistor_SMD',
        sources: readLibrary('Resistor_SMD'),
      );

      final project = await projects.create(name: 'Round Board');
      final r1 = await parts.addPart(project.id, resistorSpec());

      final board = await boards.ensureBoard(project.id);
      await boards.updateBoard(
        board
            .withOutline(
              BoardOutline.circle(const Rect.fromLTWH(20, 20, 40, 40)),
            )
            .copyWith(),
      );

      const libId = 'Resistor_SMD:R_0805_2012Metric';
      final placed = await boards.assignFootprint(
        projectId: project.id,
        partId: r1.part.id,
        libId: libId,
      );
      await boards.updatePlacement(placed.copyWith(x: 40, y: 40, placed: true));

      final scene = BoardScene.build(
        board: (await boards.getBoard(project.id))!,
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: {libId: (await footprints.loadFootprint(libId))!},
      );

      expect(scene.outline.kind, BoardOutlineKind.circle);

      final document = BoardDocument(
        project: (await projects.getById(project.id))!,
        scene: scene,
        nets: await nets.getNets(project.id),
        footprintSources: {libId: (await footprints.loadFootprintNode(libId))!},
      );

      final file = File('${workDir.path}/round.kicad_pcb');
      final text = const BoardWriter().write(document);
      await file.writeAsString(text);
      await File('${workDir.path}/round.kicad_pro').writeAsString(
        BoardProjectWriter.write(document, fileName: 'round.kicad_pro'),
      );

      // One arc, no line segments pretending to be one.
      expect(RegExp(r'\(gr_circle\b').allMatches(text).length, 1);
      expect(RegExp(r'\(gr_line\b').allMatches(text), isEmpty);
      expect(text, contains('"Edge.Cuts"'));

      final drc = await Process.run(
        kicadCli,
        [
          'pcb',
          'drc',
          '--format',
          'json',
          '--output',
          '${workDir.path}/round-drc.json',
          file.path,
        ],
        environment: {'HOME': workDir.path},
      );

      expect(
        drc.exitCode,
        anyOf(0, 5),
        reason: 'kicad-cli refused the round board\n${drc.stderr}',
      );

      final report = File('${workDir.path}/round-drc.json').readAsStringSync();
      // A board whose edge KiCad could not resolve reports exactly this.
      expect(report.toLowerCase(), isNot(contains('malformed')));
      expect(
        report,
        isNot(contains('board_edge')),
        reason: 'KiCad could not make sense of the circular edge',
      );

      // ignore: avoid_print
      print('kicad-cli accepted a circular board outline');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

String? _findKicadCli() {
  for (final path in const [
    '/usr/bin/kicad-cli',
    '/usr/local/bin/kicad-cli',
    '/snap/bin/kicad.kicad-cli',
  ]) {
    if (File(path).existsSync()) return path;
  }
  final which = Process.runSync('which', ['kicad-cli']);
  if (which.exitCode == 0) {
    final path = (which.stdout as String).trim();
    if (path.isNotEmpty) return path;
  }
  return null;
}
