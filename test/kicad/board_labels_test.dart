@Tags(['kicad'])
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/export/project_exporter.dart';
import 'package:zolt/data/import/kicad_project_importer.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/sheet_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/domain/pcb/pcb.dart';

/// KiCad's own demo boards, brought in and written back out: every
/// designator where the layout put it, and every pad, front and back.
void main() {
  const demos = '/usr/share/kicad/demos';
  if (!Directory(demos).existsSync()) {
    test('KiCad is not installed', () {}, skip: true);
    return;
  }

  // StickHub has parts on both sides, turned every which way.
  for (final (folder, name) in const [
    ('stickhub', 'StickHub'),
    ('pic_programmer', 'pic_programmer'),
  ]) {
    test(
      '$folder: designators land where KiCad put them',
      () async {
        final dir = '$demos/$folder';
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final footprints = FootprintLibraryRepository(
          db,
          InMemoryLibraryStorage(),
        );
        final boards = BoardRepository(db);
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
                for (final f in Directory(dir).listSync().whereType<File>())
                  if (f.path.endsWith('.kicad_sch') &&
                      !f.path.endsWith('/$name.kicad_sch'))
                    f.uri.pathSegments.last: f.readAsStringSync(),
              },
            );

        final placements = await boards.getFootprints(result.project.id);
        final definitions = {
          for (final p in placements)
            p.libId: ?await footprints.loadFootprint(p.libId),
        };
        final scene = BoardScene.build(
          board: await boards.ensureBoard(result.project.id),
          parts: await PartRepository(
            db,
          ).getPartsWithDetails(result.project.id),
          nets: await NetRepository(db).getNets(result.project.id),
          placements: placements,
          definitions: definitions,
        );

        // KiCad's answer, from the file: the footprint's place, and its
        // reference's offset turned by the footprint's angle.
        final expected = <String, (Offset, double)>{};
        final board = File('$dir/$name.kicad_pcb').readAsStringSync();
        for (final block in board.split('\n\t(footprint ').skip(1)) {
          final at = RegExp(r'\n\t\t\(at ([^)]*)\)').firstMatch(block);
          final ref = RegExp(
            r'\(property "Reference" "([^"]+)"\s*\n\s*\(at ([^)]*)\)',
          ).firstMatch(block);
          if (at == null || ref == null) continue;
          final a = at[1]!.split(' ').map(double.parse).toList();
          final r = ref[2]!.split(' ').map(double.parse).toList();
          final turn = (a.length > 2 ? a[2] : 0) * math.pi / 180;
          expected[ref[1]!] = (
            Offset(
              a[0] + r[0] * math.cos(turn) + r[1] * math.sin(turn),
              a[1] - r[0] * math.sin(turn) + r[1] * math.cos(turn),
            ),
            r.length > 2 ? r[2] : 0,
          );
        }

        var compared = 0;
        for (final footprint in scene.footprints) {
          final (position, angle) = expected[footprint.part.reference]!;
          expect(
            (footprint.labelPosition - position).distance,
            lessThan(1e-6),
            reason: footprint.part.reference,
          );
          // Upright, as KiCad draws it: the file's angle, or half a turn
          // from it.
          final drawn = footprint.ref.labelRotation;
          final difference = ((drawn - angle) % 180 + 180) % 180;
          expect(
            difference < 1e-6 || difference > 180 - 1e-6,
            isTrue,
            reason: '${footprint.part.reference}: $drawn against $angle',
          );
          compared++;
        }
        expect(compared, greaterThan(20));

        // Every pad where KiCad has it, on the front and on the back, and
        // where the board Zolt writes back out has it too.
        final theirs = _padsOf(board);
        var pads = 0;
        for (final footprint in scene.footprints) {
          for (final pad in footprint.pads) {
            final spots =
                theirs['${footprint.part.reference}.${pad.pad.number}'];
            if (spots == null) continue;
            final nearest = spots
                .map((s) => (s - pad.position).distance)
                .reduce(math.min);
            expect(
              nearest,
              lessThan(1e-4),
              reason:
                  '${footprint.part.reference} pad ${pad.pad.number}'
                  '${footprint.ref.flipped ? ' (on the back)' : ''}',
            );
            pads++;
          }
        }
        expect(pads, greaterThan(50));

        final out = await Directory.systemTemp.createTemp('zolt_labels');
        addTearDown(() => out.delete(recursive: true));
        final written = await ProjectExporter(
          projects: ProjectRepository(db),
          parts: PartRepository(db),
          nets: NetRepository(db),
          libraries: SymbolLibraryRepository(db, InMemoryLibraryStorage()),
          outputDirectory: out,
          boards: boards,
          footprints: footprints,
        ).exportBoard(result.project.id);
        final ours = _padsOf(File(written.first.path).readAsStringSync());
        for (final entry in theirs.entries) {
          final back = ours[entry.key];
          if (back == null) continue;
          for (final spot in entry.value) {
            final nearest = back
                .map((s) => (s - spot).distance)
                .reduce(math.min);
            expect(nearest, lessThan(1e-4), reason: 'exported ${entry.key}');
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}

/// Every pad of a KiCad board, as `REF.number` to where it is: the
/// footprint's place and its offset turned by the footprint's angle —
/// KiCad's own rule, on either side of the board.
Map<String, List<Offset>> _padsOf(String board) {
  final out = <String, List<Offset>>{};
  for (final block in board.split(RegExp(r'\n\s*\(footprint ')).skip(1)) {
    final at = RegExp(r'\n\s*\(at ([^)]*)\)').firstMatch(block);
    final ref = RegExp(r'\(property "Reference" "([^"]+)"').firstMatch(block);
    if (at == null || ref == null) continue;
    final a = at[1]!.split(' ').map(double.parse).toList();
    final turn = (a.length > 2 ? a[2] : 0) * math.pi / 180;
    for (final pad in RegExp(
      r'\(pad "([^"]*)"[^\n]*\n\s*\(at ([^)]*)\)',
    ).allMatches(block)) {
      final p = pad[2]!.split(' ').map(double.parse).toList();
      (out['${ref[1]}.${pad[1]}'] ??= []).add(
        Offset(
          a[0] + p[0] * math.cos(turn) + p[1] * math.sin(turn),
          a[1] - p[0] * math.sin(turn) + p[1] * math.cos(turn),
        ),
      );
    }
  }
  return out;
}
