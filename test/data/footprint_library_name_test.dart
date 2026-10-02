import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart'
    show LibraryImportException;

import '../helpers/footprint_fixture.dart';

/// A footprint library's name becomes the name of its file, and loose
/// `.kicad_mod` files take one typed by hand.
void main() {
  late AppDatabase db;
  late InMemoryLibraryStorage storage;
  late FootprintLibraryRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    storage = InMemoryLibraryStorage();
    repository = FootprintLibraryRepository(db, storage);
  });

  tearDown(() async => db.close());

  for (final name in ['My/Parts', r'My\Parts', '../Parts', '.hidden']) {
    test('a name like "$name" is refused before anything is written', () async {
      await expectLater(
        repository.import(nickname: name, sources: twoPadFootprintSources()),
        throwsA(isA<LibraryImportException>()),
      );
      expect(await repository.getLibraries(), isEmpty);
    });
  }

  test('an ordinary name still imports', () async {
    final info = await repository.import(
      nickname: 'My_Parts',
      sources: twoPadFootprintSources(),
    );
    expect(info.footprintCount, 1);
    expect(storage.exists('My_Parts.footprints'), isTrue);
  });
}
