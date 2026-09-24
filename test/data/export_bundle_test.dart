import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/export/project_exporter.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';

import '../helpers/fixtures.dart';

void main() {
  // "I press write files, seemingly they have been written, and then I try
  // to press share ... it just sends a message"
  test('the export goes out as one zip holding every file', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final directory = await Directory.systemTemp.createTemp('zolt_export');
    addTearDown(() => directory.delete(recursive: true));

    final projects = ProjectRepository(db);
    final parts = PartRepository(db);
    final project = await projects.create(name: 'Divider');
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await NetRepository(db).connectPins(r1.pins.first.id, r2.pins.first.id);

    final exporter = ProjectExporter(
      projects: projects,
      parts: parts,
      nets: NetRepository(db),
      libraries: SymbolLibraryRepository(db, InMemoryLibraryStorage()),
      boards: BoardRepository(db),
      footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
      outputDirectory: directory,
    );

    final share = Directory('${directory.path}/share');
    final bundle = await exporter.exportBundle(project.id, into: share);

    expect(bundle.fileName, 'Divider.zip');
    expect(bundle.byteSize, greaterThan(0));

    final entries = ZipDecoder()
        .decodeBytes(await File(bundle.path).readAsBytes())
        .files
        .map((f) => f.name)
        .toList();
    expect(
      entries.any((name) => name.endsWith('.kicad_sch')),
      isTrue,
      reason: 'the schematic is in the zip: $entries',
    );
    expect(
      entries.any((name) => name.endsWith('-bom.csv')),
      isTrue,
      reason: 'and the parts list: $entries',
    );
  });
}
