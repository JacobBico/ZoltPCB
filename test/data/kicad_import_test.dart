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
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/domain/export/board_document.dart';
import 'package:hintpcb/domain/export/schematic_document.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/kicad/board_writer.dart';
import 'package:hintpcb/kicad/schematic_writer.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/library_fixture.dart';

/// Everything one in-memory app needs.
class _App {
  _App() : db = AppDatabase.memory() {
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    boards = BoardRepository(db);
    symbols = SymbolLibraryRepository(db, InMemoryLibraryStorage());
    footprints = FootprintLibraryRepository(db, InMemoryLibraryStorage());
    importer = KicadProjectImporter(
      projects: projects,
      parts: parts,
      nets: nets,
      boards: boards,
      symbols: symbols,
      footprints: footprints,
    );
  }

  final AppDatabase db;
  late final ProjectRepository projects;
  late final PartRepository parts;
  late final NetRepository nets;
  late final BoardRepository boards;
  late final SymbolLibraryRepository symbols;
  late final FootprintLibraryRepository footprints;
  late final KicadProjectImporter importer;

  /// Nets as sets of `REF.pin`, with their names, for comparing designs.
  Future<Set<String>> netlist(String projectId) async {
    final all = await nets.getNets(projectId);
    return {
      for (final net in all)
        '${net.net.isNamed ? net.net.name : '~'}: '
            '${(net.endpoints.map((e) => e.shortLabel).toList()..sort()).join(' ')}',
    };
  }
}

void main() {
  late _App source;
  setUp(() async {
    source = _App();
    await source.symbols.import(
      fileName: 'Device.kicad_sym',
      bytes: libraryBytes(),
    );
    await source.symbols.import(
      fileName: 'power.kicad_sym',
      bytes: libraryBytes(testPowerLibrarySource),
    );
  });
  tearDown(() async => source.db.close());

  Future<Project> design() async {
    final project = await source.projects.create(name: 'Divider');
    final r1 = await source.parts.addPart(project.id, resistorSpec());
    final r2 = await source.parts.addPart(project.id, resistorSpec());
    final gnd = await source.parts.addPart(project.id, groundSpec());
    for (final (part, x, y) in [
      (r1, 50.8, 50.8),
      (r2, 76.2, 50.8),
      (gnd, 76.2, 76.2),
    ]) {
      await source.parts.updateUnitPlacement(
        part.units.first.copyWith(x: x, y: y, placed: true),
      );
    }
    final mid = await source.nets.connectPins(r1.pins[1].id, r2.pins[0].id);
    await source.nets.renameNet(mid.net.id, 'VMID');
    await source.nets.connectPins(r2.pins[1].id, gnd.pins.single.id);
    return project;
  }

  Future<String> schematicOf(_App app, Project project) async {
    final partList = await app.parts.getPartsWithDetails(project.id);
    return const SchematicWriter().write(
      SchematicDocument(
        project: project,
        parts: partList,
        nets: await app.nets.getNets(project.id),
        symbols: {
          for (final libId in partList.map((p) => p.part.libId).toSet())
            libId: ?await app.symbols.loadSymbol(libId),
        },
        drawnWires: await app.nets.getWires(project.id),
      ),
    );
  }

  test(
    'a schematic comes back with the same parts and the same nets',
    () async {
      final project = await design();
      final text = await schematicOf(source, project);

      final target = _App();
      addTearDown(() => target.db.close());
      final result = await target.importer.import(
        name: 'Divider',
        schematic: text,
      );

      expect(result.partCount, 3);
      expect(
        {
          for (final p in await target.parts.getPartsWithDetails(
            result.project.id,
          ))
            p.part.reference,
        },
        {
          for (final p in await source.parts.getPartsWithDetails(project.id))
            p.part.reference,
        },
      );
      expect(
        await target.netlist(result.project.id),
        await source.netlist(project.id),
      );
      // The symbols it carried were added, so it draws.
      expect(await target.symbols.loadSymbol('Device:R'), isNotNull);
    },
  );

  test('its placement comes back exactly', () async {
    final project = await design();
    final target = _App();
    addTearDown(() => target.db.close());
    final result = await target.importer.import(
      name: 'Divider',
      schematic: await schematicOf(source, project),
    );
    Map<String, Offset> positions(List<PartWithDetails> all) => {
      for (final p in all)
        p.part.reference: Offset(p.units.first.x, p.units.first.y),
    };
    expect(
      positions(await target.parts.getPartsWithDetails(result.project.id)),
      positions(await source.parts.getPartsWithDetails(project.id)),
    );
  });

  test('a board comes back placed, routed, and with its footprints', () async {
    final project = await design();
    await source.footprints.import(
      nickname: 'Test',
      sources: twoPadFootprintSources(),
    );
    final partList = await source.parts.getPartsWithDetails(project.id);
    final r1 = partList.firstWhere((p) => p.part.reference == 'R1');
    final r2 = partList.firstWhere((p) => p.part.reference == 'R2');
    for (final (part, x, rotation) in [(r1, 30.0, 0.0), (r2, 45.0, 90.0)]) {
      final ref = await source.boards.assignFootprint(
        projectId: project.id,
        partId: part.part.id,
        libId: 'Test:TwoPad',
      );
      await source.boards.updatePlacement(
        ref.copyWith(x: x, y: 35, rotation: rotation, placed: true),
      );
    }
    final vmid = (await source.nets.getNets(
      project.id,
    )).firstWhere((n) => n.net.name == 'VMID');
    await source.boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 31,
      startY: 35,
      endX: 44,
      endY: 35,
      width: 0.4,
      netId: vmid.net.id,
    );

    final placements = await source.boards.getFootprints(project.id);
    final scene = BoardScene.build(
      board: await source.boards.ensureBoard(project.id),
      parts: partList,
      nets: await source.nets.getNets(project.id),
      placements: placements,
      definitions: {
        'Test:TwoPad': (await source.footprints.loadFootprint('Test:TwoPad'))!,
      },
      tracks: await source.boards.getTracks(project.id),
    );
    final boardText = const BoardWriter().write(
      BoardDocument(
        project: project,
        scene: scene,
        nets: await source.nets.getNets(project.id),
        footprintSources: {
          'Test:TwoPad': (await source.footprints.loadFootprintNode(
            'Test:TwoPad',
          ))!,
        },
      ),
    );

    // Into an app that has never seen the Test library.
    final target = _App();
    addTearDown(() => target.db.close());
    final result = await target.importer.import(
      name: 'Divider',
      schematic: await schematicOf(source, project),
      board: boardText,
    );
    expect(result.footprintCount, 2);
    expect(result.trackCount, 1);

    final imported = await target.boards.getFootprints(result.project.id);
    final byPart = {
      for (final p in await target.parts.getPartsWithDetails(result.project.id))
        p.part.id: p.part.reference,
    };
    final r2Placed = imported.firstWhere((f) => byPart[f.partId] == 'R2');
    expect(r2Placed.x, 45);
    expect(r2Placed.rotation, 90);

    // The footprint was learned from the board, with its pads back at the
    // library's own angle rather than the placed one.
    final learned = await target.footprints.loadFootprint('Test:TwoPad');
    final original = await source.footprints.loadFootprint('Test:TwoPad');
    expect(learned, isNotNull);
    expect(
      [for (final pad in learned!.pads) pad.angle],
      [for (final pad in original!.pads) pad.angle],
    );

    // And the track is on the net it was routed on.
    final track = (await target.boards.getTracks(result.project.id)).single;
    final named = (await target.nets.getNets(
      result.project.id,
    )).firstWhere((n) => n.net.id == track.netId);
    expect(named.net.name, 'VMID');
  });

  group('a project made in KiCad', () {
    const demo = '/usr/share/kicad/demos/ecc83/ecc83-pp';
    final available = File('$demo.kicad_sch').existsSync();

    test(
      'opens with its parts, nets, footprints and copper',
      () async {
        final target = _App();
        addTearDown(() => target.db.close());
        final result = await target.importer.import(
          name: 'ecc83',
          schematic: File('$demo.kicad_sch').readAsStringSync(),
          board: File('$demo.kicad_pcb').readAsStringSync(),
          projectFile: File('$demo.kicad_pro').readAsStringSync(),
        );

        final sheet = File('$demo.kicad_sch').readAsStringSync();
        final pcb = File('$demo.kicad_pcb').readAsStringSync();
        expect(result.partCount, greaterThan(10));
        expect(result.netCount, greaterThan(5));
        expect(
          result.footprintCount,
          RegExp(r'\(footprint "').allMatches(pcb).length,
        );
        expect(
          result.trackCount,
          greaterThanOrEqualTo(RegExp(r'\(segment\b').allMatches(pcb).length),
        );
        expect(sheet, contains('kicad_sch'));

        // Ground reaches more than a couple of pins, through wires and symbols.
        final ground = (await target.nets.getNets(
          result.project.id,
        )).where((n) => n.net.name == 'GND');
        expect(ground, hasLength(1));
        expect(ground.single.endpoints.length, greaterThan(3));
      },
      skip: available ? false : 'KiCad demos are not installed',
    );
  });
}
