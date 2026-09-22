import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/libraries/kicad_library_source.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/features/libraries/kicad_library_downloader.dart';

/// Downloads KiCad's real essentials from gitlab.com and imports them.
///
/// Off by default — it needs the network and takes a while. Run with
/// `HINTPCB_NETWORK=1 flutter test test/data/kicad_download_network_test.dart`.
void main() {
  final skip = Platform.environment['HINTPCB_NETWORK'] == null
      ? 'needs HINTPCB_NETWORK=1 and a connection'
      : null;

  test(
    'the essentials download and import as they are',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final downloader = KicadLibraryDownloader(
        fetcher: HttpLibraryFetcher(),
        symbols: SymbolLibraryRepository(db, InMemoryLibraryStorage()),
        footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
        parseInBackground: false,
      );

      final picked = [
        for (final kind in RemoteLibraryKind.values)
          for (final library in await downloader.catalog(kind))
            if (KicadLibrarySource.essentials[kind]!.contains(library.name))
              library,
      ];
      // Every essential name is one KiCad still publishes.
      expect(
        picked.length,
        KicadLibrarySource.essentials.values.fold<int>(
          0,
          (n, s) => n + s.length,
        ),
      );

      final result = await downloader.download(picked);
      expect(result.failed, isEmpty, reason: '${result.failed}');
      expect(result.installed, hasLength(picked.length));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
