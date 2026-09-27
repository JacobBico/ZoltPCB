import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/import/kicad_picked_files.dart';

const _top = '''
(kicad_sch
  (sheet (at 10 10) (size 20 20)
    (property "Sheetname" "Power")
    (property "Sheetfile" "power.kicad_sch"))
  (sheet (at 40 10) (size 20 20)
    (property "Sheetname" "Radio")
    (property "Sheetfile" "sch/radio.kicad_sch")))
''';

void main() {
  test('says which sub-sheets were not picked', () {
    final picked = KicadPickedFiles()
      ..add('board.kicad_sch', utf8.encode(_top))
      ..add('board.kicad_pcb', utf8.encode('(kicad_pcb)'));
    expect(picked.missingSheets, ['power.kicad_sch', 'radio.kicad_sch']);

    // A sheet kept in a folder is found by its name alone.
    picked.add('radio.kicad_sch', utf8.encode('(kicad_sch)'));
    expect(picked.missingSheets, ['power.kicad_sch']);
    picked.add('power.kicad_sch', utf8.encode('(kicad_sch)'));
    expect(picked.missingSheets, isEmpty);
  });

  test('a zip of the project folder brings every file at once', () {
    final archive = Archive()
      ..add(ArchiveFile.string('board/board.kicad_sch', _top))
      ..add(ArchiveFile.string('board/power.kicad_sch', '(kicad_sch)'))
      ..add(ArchiveFile.string('board/sch/radio.kicad_sch', '(kicad_sch)'))
      ..add(ArchiveFile.string('board/board.kicad_pcb', '(kicad_pcb)'))
      ..add(ArchiveFile.string('board/board.kicad_pro', '{}'))
      // What an archiver or KiCad leaves lying about is left out.
      ..add(ArchiveFile.string('__MACOSX/board/._board.kicad_sch', 'junk'))
      ..add(
        ArchiveFile.string('board/board-backups/old/board.kicad_pcb', '(old)'),
      )
      ..add(ArchiveFile.string('board/notes.txt', 'hello'));
    final picked = KicadPickedFiles();
    expect(picked.add('board.zip', ZipEncoder().encodeBytes(archive)), isTrue);

    expect(picked.files.keys.toSet(), {
      'board.kicad_sch',
      'power.kicad_sch',
      'radio.kicad_sch',
      'board.kicad_pcb',
      'board.kicad_pro',
    });
    expect(picked.missingSheets, isEmpty);
    expect(picked.withExtension('.kicad_pcb')!.value, '(kicad_pcb)');
  });

  test('anything else picked is left out, and said so', () {
    final picked = KicadPickedFiles();
    expect(picked.add('photo.jpg', [1, 2, 3]), isFalse);
    expect(picked.add('broken.zip', [1, 2, 3]), isFalse);
    expect(picked.files, isEmpty);
  });
}
