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
import 'package:zolt/domain/export/board_document.dart';
import 'package:zolt/domain/export/schematic_document.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/kicad/board_writer.dart';
import 'package:zolt/kicad/schematic_writer.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/library_fixture.dart';

/// A net repository that fails the first time it is asked to join pins.
class _FailingNets extends NetRepository {
  _FailingNets(super.db);

  @override
  Future<NetWithEndpoints> connectPins(String pinA, String pinB) =>
      throw StateError('disk full');
}

/// Everything one in-memory app needs.
class _App {
  _App() : db = AppDatabase.memory() {
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    boards = BoardRepository(db);
    symbols = SymbolLibraryRepository(db, InMemoryLibraryStorage());
    footprints = FootprintLibraryRepository(db, InMemoryLibraryStorage());
    sheets = SheetRepository(db);
    importer = KicadProjectImporter(
      projects: projects,
      parts: parts,
      nets: nets,
      boards: boards,
      symbols: symbols,
      footprints: footprints,
      sheets: sheets,
    );
  }

  late final SheetRepository sheets;

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

  test('sub-sheets come back as sheets, joined as they were', () async {
    // Top: R1. Power: R2. Regulator, inside Power: GND-side R3.
    final project = await source.projects.create(name: 'Nested');
    final power = await source.sheets.add(
      projectId: project.id,
      name: 'Power',
      at: const Offset(101.6, 50.8),
    );
    final regulator = await source.sheets.add(
      projectId: project.id,
      name: 'Regulator',
      parentId: power.id,
      at: const Offset(101.6, 50.8),
    );
    Future<PartWithDetails> place(String value, String? sheetId) async {
      final part = await source.parts.addPart(
        project.id,
        resistorSpec(value: value),
      );
      await source.parts.updateUnitPlacement(
        part.units.first.copyWith(
          x: 50.8,
          y: 50.8,
          placed: true,
          sheetId: sheetId,
        ),
      );
      return (await source.parts.getPartWithDetails(part.part.id))!;
    }

    final r1 = await place('1k', null);
    final r2 = await place('2k', power.id);
    final r3 = await place('3k', regulator.id);
    final vmid = await source.nets.connectPins(r1.pins[1].id, r2.pins[0].id);
    await source.nets.connectPins(r1.pins[1].id, r3.pins[0].id);
    await source.nets.renameNet(vmid.net.id, 'VMID');
    // Unnamed, between Power and Regulator only.
    await source.nets.connectPins(r2.pins[1].id, r3.pins[1].id);

    final partList = await source.parts.getPartsWithDetails(project.id);
    final files = const SchematicWriter().writeFiles(
      SchematicDocument(
        project: project,
        parts: partList,
        nets: await source.nets.getNets(project.id),
        symbols: {'Device:R': (await source.symbols.loadSymbol('Device:R'))!},
        sheets: await source.sheets.getAll(project.id),
      ),
      topFile: 'Nested.kicad_sch',
    );

    final target = _App();
    addTearDown(() => target.db.close());
    final result = await target.importer.import(
      name: 'Nested',
      schematic: files['Nested.kicad_sch']!,
      sheetFiles: {
        for (final e in files.entries)
          if (e.key != 'Nested.kicad_sch') e.key: e.value,
      },
    );
    expect(result.warnings, isEmpty);
    expect(result.partCount, 3);

    final sheets = SheetTree(await target.sheets.getAll(result.project.id));
    expect(
      [for (final s in sheets.inPageOrder()) sheets.pathName(s.id)],
      ['/Power/', '/Power/Regulator/'],
    );
    // Each part on the sheet it was drawn on.
    final sheetOf = {
      for (final p in await target.parts.getPartsWithDetails(result.project.id))
        p.part.value: sheets.byId(p.units.single.sheetId)?.name ?? 'Top',
    };
    expect(sheetOf, {'1k': 'Top', '2k': 'Power', '3k': 'Regulator'});

    // The same connections, and the name the user gave kept.
    expect(
      await target.netlist(result.project.id),
      await source.netlist(project.id),
    );
  });

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

    // A damaged project file costs its rules, with a warning, not the
    // whole import.
    final damaged = await target.importer.import(
      name: 'Damaged pro',
      schematic: await schematicOf(source, project),
      board: boardText,
      projectFile: '{"net_settings": {"classes": [',
    );
    expect(damaged.footprintCount, 2);
    expect(
      damaged.warnings,
      contains(contains('.kicad_pro could not be read')),
    );
  });

  test('an import that fails part way leaves no half-made project', () async {
    final project = await design();
    final target = _App();
    addTearDown(() => target.db.close());
    // Parts go in, then wiring them up fails.
    final importer = KicadProjectImporter(
      projects: target.projects,
      parts: target.parts,
      nets: _FailingNets(target.db),
      boards: target.boards,
      symbols: target.symbols,
      footprints: target.footprints,
    );
    await expectLater(
      importer.import(
        name: 'Divider',
        schematic: await schematicOf(source, project),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await target.projects.getAll(), isEmpty);
    expect(
      await target.db.select(target.db.parts).get(),
      isEmpty,
      reason: 'the parts placed before the failure went with the project',
    );
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
