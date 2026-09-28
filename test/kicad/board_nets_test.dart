@Tags(['kicad'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/import/kicad_project_importer.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/board_sync.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/sheet_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';

/// KiCad's own demo boards, brought in with their schematics: every track
/// and via lands on a net of the schematic, so opening the board asks to
/// delete none of it.
///
/// A board names its nets its own way — `/sheet/NAME` through the sheets,
/// `Net-(R1-Pad2)` for unnamed ones — and matching those names against the
/// app's once left most of a routed board on no net at all.
void main() {
  const demos = '/usr/share/kicad/demos';
  if (!Directory(demos).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  for (final (folder, name) in const [
    ('pic_programmer', 'pic_programmer'),
    ('openair-max', 'One-Air-Max'),
    ('complex_hierarchy', 'complex_hierarchy'),
    ('kit-dev-coldfire-xilinx_5213', 'kit-dev-coldfire-xilinx_5213'),
    ('ecc83', 'ecc83-pp'),
    // Not `multichannel`: it draws one channel sheet four times over, and
    // the app keeps a sheet once.
  ]) {
    test(
      '$folder: all its copper is on the schematic\'s nets',
      () async {
        final dir = '$demos/$folder';
        if (!File('$dir/$name.kicad_pcb').existsSync()) {
          markTestSkipped('demo not installed');
          return;
        }
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final boards = BoardRepository(db);
        final footprints = FootprintLibraryRepository(
          db,
          InMemoryLibraryStorage(),
        );
        final result =
            await KicadProjectImporter(
              projects: ProjectRepository(db),
              parts: PartRepository(db),
              nets: NetRepository(db),
              boards: boards,
              symbols: SymbolLibraryRepository(db, InMemoryLibraryStorage()),
              footprints: footprints,
              sheets: SheetRepository(db),
            ).import(
              name: name,
              schematic: File('$dir/$name.kicad_sch').readAsStringSync(),
              board: File('$dir/$name.kicad_pcb').readAsStringSync(),
              sheetFiles: {
                for (final f in Directory(
                  dir,
                ).listSync(recursive: true).whereType<File>())
                  if (f.path.endsWith('.kicad_sch') &&
                      !f.path.endsWith('/$name.kicad_sch'))
                    f.uri.pathSegments.last: f.readAsStringSync(),
              },
            );
        final id = result.project.id;

        final tracks = await boards.getTracks(id);
        expect(tracks, isNotEmpty);
        expect(
          [
            for (final t in tracks)
              if (t.netId == null) '${t.layer.name} ${t.startX},${t.startY}',
          ].take(10),
          isEmpty,
          reason: 'tracks on no net',
        );
        expect(
          (await boards.getVias(id)).where((v) => v.netId == null),
          isEmpty,
          reason: 'vias on no net',
        );

        final plan = await BoardSync(
          parts: PartRepository(db),
          boards: boards,
          footprints: footprints,
        ).plan(id);
        expect(plan.orphanTracks, 0);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
