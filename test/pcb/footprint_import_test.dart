@Tags(['corpus'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/kicad/footprint_library_reader.dart';

/// Imports a zipped `.pretty` directory, the way the app expects a user to
/// move one off a desktop.
void main() {
  const root = '/usr/share/kicad/footprints';
  if (!Directory(root).existsSync()) {
    test('KiCad footprint libraries are not installed', () {}, skip: true);
    return;
  }

  late AppDatabase db;
  late FootprintLibraryRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = FootprintLibraryRepository(db, InMemoryLibraryStorage());
  });

  tearDown(() async => db.close());

  /// Zips a real library the way an archiver would: entries nested under the
  /// `.pretty` directory they came from.
  Uint8List zipOf(String library, {int limit = 12, bool nested = true}) {
    final archive = Archive();
    final dir = Directory('$root/$library.pretty');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.kicad_mod'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files.take(limit)) {
      final name = file.path.split('/').last;
      final bytes = file.readAsBytesSync();
      archive.addFile(
        ArchiveFile(
          nested ? '$library.pretty/$name' : name,
          bytes.length,
          bytes,
        ),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// The unpacking half of the import, without the file picker.
  Future<FootprintLibraryInfo> importZip(
    String fileName,
    Uint8List bytes,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sources = <String, Uint8List>{};
    String? innerNickname;

    for (final entry in archive) {
      if (!entry.isFile || !entry.name.endsWith('.kicad_mod')) continue;
      for (final segment in entry.name.split('/')) {
        if (segment.endsWith('.pretty')) {
          innerNickname = segment.substring(
            0,
            segment.length - '.pretty'.length,
          );
        }
      }
      sources[entry.name.split('/').last] = Uint8List.fromList(entry.content);
    }

    return repository.import(
      nickname: innerNickname ?? FootprintLibraryReader.nicknameFor(fileName),
      sources: sources,
    );
  }

  test('a zipped .pretty folder imports and the footprints load', () async {
    final info = await importZip(
      'whatever-the-user-called-it.zip',
      zipOf('Resistor_SMD'),
    );

    // The library names itself from the folder inside the archive, not from
    // whatever the zip happened to be called.
    expect(info.nickname, 'Resistor_SMD');
    expect(info.footprintCount, 12);

    final entries = await repository.search('');
    expect(entries, hasLength(12));

    final loaded = await repository.loadFootprint(entries.first.libId);
    expect(loaded, isNotNull);
    expect(loaded!.pads, isNotEmpty);
    expect(loaded.libraryNickname, 'Resistor_SMD');
  });

  test('a flat zip falls back to the archive name', () async {
    final info = await importZip(
      'Capacitor_SMD.zip',
      zipOf('Capacitor_SMD', nested: false),
    );

    expect(info.nickname, 'Capacitor_SMD');
    final entry = (await repository.search('')).first;
    expect(entry.libId, startsWith('Capacitor_SMD:'));
  });

  test(
    'every imported footprint keeps the geometry it was packed with',
    () async {
      await importZip('Resistor_SMD.zip', zipOf('Resistor_SMD', limit: 30));

      for (final entry in await repository.search('')) {
        final loaded = await repository.loadFootprint(entry.libId);
        expect(loaded, isNotNull, reason: entry.libId);
        expect(
          loaded!.padCount,
          entry.padCount,
          reason: '${entry.libId} pad count changed on the way through',
        );
      }
    },
  );
}
