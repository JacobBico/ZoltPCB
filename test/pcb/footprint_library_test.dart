@Tags(['corpus'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/kicad/footprint_library_reader.dart';

/// Packs a real `.pretty` directory and reads it back out one footprint at a
/// time.
///
/// The packed container exists so a phone can hold a library of four hundred
/// files as one row and one file. That only works if a byte range recorded
/// at pack time still parses on its own afterwards — this is the test of
/// exactly that, on real libraries rather than a fixture.
void main() {
  const root = '/usr/share/kicad/footprints';
  if (!Directory(root).existsSync()) {
    test('KiCad footprint libraries are not installed', () {}, skip: true);
    return;
  }

  Map<String, Uint8List> read(String library, {int? limit}) {
    final dir = Directory('$root/$library.pretty');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.kicad_mod'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final chosen = limit == null ? files : files.take(limit);
    return {
      for (final file in chosen)
        file.path.split('/').last: file.readAsBytesSync(),
    };
  }

  test('every packed footprint parses back out of its own span', () {
    final sources = read('Resistor_SMD');
    final packed = FootprintLibraryReader.pack(
      nickname: 'Resistor_SMD',
      sources: sources,
    );

    expect(packed.warnings, isEmpty);
    expect(packed.footprintCount, sources.length);

    for (final footprint in packed.footprints) {
      final span = packed.spans[footprint.name]!;
      final slice = Uint8List.sublistView(packed.bytes, span.start, span.end);
      final reread = FootprintLibraryReader.parseOne(
        slice,
        nickname: 'Resistor_SMD',
      );

      expect(reread.name, footprint.name);
      expect(reread.pads.length, footprint.pads.length);
      for (var i = 0; i < footprint.pads.length; i++) {
        expect(reread.pads[i].number, footprint.pads[i].number);
        expect(reread.pads[i].at.x, footprint.pads[i].at.x);
        expect(reread.pads[i].at.y, footprint.pads[i].at.y);
      }
    }
  });

  test('a file that is not a footprint is reported, not fatal', () {
    final sources = read('Resistor_SMD', limit: 4)
      ..['broken.kicad_mod'] = Uint8List.fromList(utf8.encode('(nonsense'));

    final packed = FootprintLibraryReader.pack(
      nickname: 'Resistor_SMD',
      sources: sources,
    );

    expect(packed.footprintCount, 4);
    expect(packed.warnings, hasLength(1));
    expect(packed.warnings.single, contains('broken.kicad_mod'));
  });

  test('a library nickname comes from the container, not the file', () {
    expect(
      FootprintLibraryReader.nicknameFor('Resistor_SMD.pretty'),
      'Resistor_SMD',
    );
    expect(
      FootprintLibraryReader.nicknameFor('/a/b/Resistor_SMD.pretty.zip'),
      'Resistor_SMD',
    );
    expect(
      FootprintLibraryReader.nicknameFor('Package_DIP.zip'),
      'Package_DIP',
    );
  });

  group('repository', () {
    late AppDatabase db;
    late FootprintLibraryRepository repository;

    setUp(() {
      db = AppDatabase.memory();
      repository = FootprintLibraryRepository(db, InMemoryLibraryStorage());
    });

    tearDown(() async => db.close());

    test('imports a real library and finds one footprint again', () async {
      final sources = read('Resistor_SMD');
      final info = await repository.import(
        nickname: 'Resistor_SMD',
        sources: sources,
      );
      expect(info.footprintCount, sources.length);

      final loaded = await repository.loadFootprint(
        'Resistor_SMD:R_0805_2012Metric',
      );
      expect(loaded, isNotNull);
      expect(loaded!.padCount, 2);
      expect(loaded.pads.first.at.x, closeTo(-0.9125, 1e-9));
      expect(loaded.libId, 'Resistor_SMD:R_0805_2012Metric');
    });

    test('search narrows with every term', () async {
      await repository.import(
        nickname: 'Resistor_SMD',
        sources: read('Resistor_SMD'),
      );

      final all = await repository.search('');
      final metric = await repository.search('0805 metric');

      expect(metric, isNotEmpty);
      expect(metric.length, lessThan(all.length));
      expect(
        metric.every((e) => e.name.toLowerCase().contains('0805')),
        isTrue,
      );
    });

    test('pad count filters to what a part could actually use', () async {
      await repository.import(
        nickname: 'Package_DIP',
        sources: read('Package_DIP'),
      );

      final eight = await repository.search('', padCount: 8);
      expect(eight, isNotEmpty);
      expect(eight.every((e) => e.padCount == 8), isTrue);
    });

    test(
      're-importing a nickname replaces it rather than doubling it',
      () async {
        await repository.import(
          nickname: 'Resistor_SMD',
          sources: read('Resistor_SMD', limit: 10),
        );
        await repository.import(
          nickname: 'Resistor_SMD',
          sources: read('Resistor_SMD', limit: 4),
        );

        expect(await repository.getLibraries(), hasLength(1));
        expect(await repository.footprintCount(), 4);
      },
    );

    test('deleting a library takes its footprints with it', () async {
      final info = await repository.import(
        nickname: 'Resistor_SMD',
        sources: read('Resistor_SMD', limit: 10),
      );
      await repository.deleteLibrary(info.id);

      expect(await repository.getLibraries(), isEmpty);
      expect(await repository.footprintCount(), 0);
    });
  });
}
