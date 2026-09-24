import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/export/project_exporter.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/domain/export/export_preview.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/symbols/symbols.dart';

import '../helpers/fixtures.dart';
import '../helpers/library_fixture.dart';

void main() {
  late AppDatabase db;
  late Directory output;
  late SymbolLibraryRepository libraries;
  late ProjectRepository projects;
  late PartRepository parts;
  late NetRepository nets;
  late ProjectExporter exporter;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    output = await Directory.systemTemp.createTemp('zolt_export_test');
    libraries = SymbolLibraryRepository(db, InMemoryLibraryStorage());
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    exporter = ProjectExporter(
      projects: projects,
      parts: parts,
      nets: nets,
      libraries: libraries,
      outputDirectory: output,
    );
    project = await projects.create(name: 'Line Driver');
  });

  tearDown(() async {
    await db.close();
    if (output.existsSync()) await output.delete(recursive: true);
  });

  Uint8List bytes(String source) => Uint8List.fromList(utf8.encode(source));

  group('file names', () {
    test('spaces become underscores', () {
      expect(ProjectExporter.fileNameFor('Line Driver'), 'Line_Driver');
    });

    test('characters no filesystem accepts are dropped', () {
      expect(ProjectExporter.fileNameFor('a/b:c*d?'), 'abcd');
      expect(ProjectExporter.fileNameFor('..hidden..'), 'hidden');
    });

    test('a name with nothing usable in it still gives a file name', () {
      expect(ProjectExporter.fileNameFor('   '), 'schematic');
      expect(ProjectExporter.fileNameFor('///'), 'schematic');
    });

    test('very long names are truncated', () {
      expect(ProjectExporter.fileNameFor('x' * 200).length, 64);
    });
  });

  group('writing files', () {
    test('writes a schematic and a BOM named after the project', () async {
      await parts.addPart(project.id, resistorSpec());

      final files = await exporter.exportAll(project.id);

      expect(files.map((f) => f.fileName), [
        'Line_Driver.kicad_sch',
        'Line_Driver-bom.csv',
      ]);
      for (final file in files) {
        expect(File(file.path).existsSync(), isTrue);
        expect(file.byteSize, greaterThan(0));
      }
    });

    test('the schematic is a KiCad 9 sheet', () async {
      await parts.addPart(project.id, resistorSpec());
      final file = await exporter.exportSchematic(project.id);

      final text = File(file.path).readAsStringSync();
      expect(text, startsWith('(kicad_sch'));
      expect(text, contains('(version 20250114)'));
      expect(text, contains('"Device:R"'));
    });

    test('the BOM has a header and a row per group', () async {
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      final file = await exporter.exportBom(project.id);

      final rows = File(file.path).readAsStringSync().trim().split('\n');
      expect(rows.first, startsWith('Item,Qty,References'));
      expect(rows, hasLength(2));
      expect(rows[1], contains('"R1, R2"'));
    });

    test('exporting twice overwrites rather than accumulating', () async {
      await parts.addPart(project.id, resistorSpec());
      await exporter.exportAll(project.id);
      await exporter.exportAll(project.id);

      expect(output.listSync().whereType<File>(), hasLength(2));
    });

    test('creates its output directory if it is not there', () async {
      final nested = Directory('${output.path}/deeper/still');
      final scoped = ProjectExporter(
        projects: projects,
        parts: parts,
        nets: nets,
        libraries: libraries,
        outputDirectory: nested,
      );
      await parts.addPart(project.id, resistorSpec());

      final file = await scoped.exportSchematic(project.id);
      expect(File(file.path).existsSync(), isTrue);
    });

    test('a project that has been deleted cannot be exported', () async {
      await projects.delete(project.id);
      await expectLater(
        exporter.exportAll(project.id),
        throwsA(isA<ExportException>()),
      );
    });
  });

  group('assembling the document', () {
    test('pulls in the library definition of every part used', () async {
      await libraries.import(
        fileName: 'Device.kicad_sym',
        bytes: bytes(testLibrarySource),
      );
      final symbol = (await libraries.loadSymbol('Device:R'))!;
      await parts.addPart(project.id, symbol.toNewPartSpec());

      final document = await exporter.buildDocument(project.id);

      expect(document.symbols.keys, ['Device:R']);
      expect(document.symbols['Device:R']!.pinCount, 2);
    });

    test('a part whose library is gone still exports', () async {
      await libraries.import(
        fileName: 'Device.kicad_sym',
        bytes: bytes(testLibrarySource),
      );
      final symbol = (await libraries.loadSymbol('Device:R'))!;
      await parts.addPart(project.id, symbol.toNewPartSpec());
      await libraries.deleteLibrary((await libraries.getLibraries()).single.id);

      final document = await exporter.buildDocument(project.id);
      expect(document.symbols, isEmpty);

      final file = await exporter.exportSchematic(project.id);
      final text = File(file.path).readAsStringSync();
      // The pins the project stored are enough to describe the part.
      expect(text, contains('"Device:R"'));
      expect(text, contains('(pin passive line'));
    });
  });

  group('preview', () {
    test('counts what the export will contain', () async {
      final r1 = await parts.addPart(project.id, resistorSpec());
      final r2 = await parts.addPart(project.id, resistorSpec());
      await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );

      expect(preview.partCount, 2);
      expect(preview.unitCount, 2);
      expect(preview.netCount, 1);
      expect(preview.pinCount, 4);
      expect(preview.connectedPinCount, 2);
      expect(preview.unconnectedPinCount, 2);
      expect(preview.bomLineCount, 1);
    });

    test('flags a missing library without refusing to export', () async {
      await parts.addPart(project.id, resistorSpec());

      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );

      expect(preview.missingSymbols, ['Device:R']);
      expect(preview.hasWarnings, isTrue);
    });

    test('flags parts with no footprint', () async {
      final fitted = await parts.addPart(project.id, resistorSpec());
      final bare = await parts.addPart(project.id, resistorSpec());
      await parts.updatePart(bare.part.copyWith(footprint: ''));

      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );

      expect(preview.partsWithoutFootprint, ['R2']);
      expect(fitted.part.footprint, isNotEmpty);
    });

    test('a part kept out of the BOM is not asked for a footprint', () async {
      await parts.addPart(project.id, groundSpec());
      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );
      expect(preview.partsWithoutFootprint, isEmpty);
    });

    test('an empty project has nothing to export', () async {
      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );
      expect(preview.isEmpty, isTrue);
    });

    test('no-connect pins count separately from free ones', () async {
      final added = await parts.addPart(project.id, resistorSpec());
      await parts.setPinNoConnect(added.pins.first.id, true);

      final preview = ExportPreview.of(
        await exporter.buildDocument(project.id),
      );
      expect(preview.noConnectPinCount, 1);
      expect(preview.unconnectedPinCount, 1);
    });
  });

  test('a board footprint no library has stops the export, by name', () async {
    final boards = BoardRepository(db);
    final withBoard = ProjectExporter(
      projects: projects,
      parts: parts,
      nets: nets,
      libraries: libraries,
      outputDirectory: output,
      boards: boards,
      footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
    );
    final r1 = await parts.addPart(project.id, resistorSpec());
    final ref = await boards.assignFootprint(
      projectId: project.id,
      partId: r1.part.id,
      libId: 'Gone:Missing',
    );
    await boards.updatePlacement(ref.copyWith(x: 10, y: 10, placed: true));

    // Written anyway, the board and the Gerbers would be missing R1.
    for (final export in [
      () => withBoard.exportBoard(project.id),
      () => withBoard.exportFabrication(project.id),
    ]) {
      await expectLater(
        export(),
        throwsA(
          isA<ExportException>().having(
            (e) => e.message,
            'message',
            contains('R1 (Gone:Missing)'),
          ),
        ),
      );
    }
  });
}
