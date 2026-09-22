import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/providers.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/libraries/kicad_library_source.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/features/libraries/kicad_library_downloader.dart';
import 'package:hintpcb/features/libraries/libraries_panel.dart';

import '../helpers/footprint_fixture.dart';
import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

const _symbolIndex = '''
(sym_lib_table
  (version 7)
  (lib (name "Device")(type "KiCad")(uri "\${KICAD9_SYMBOL_DIR}/Device.kicad_sym")(options "")(descr "Generic symbols"))
  (lib (name "Audio")(type "KiCad")(uri "\${KICAD9_SYMBOL_DIR}/Audio.kicad_sym")(options "")(descr "Audio chips"))
)
''';

// The footprint index writes its names unquoted.
const _footprintIndex = '''
(fp_lib_table
  (version 7)
  (lib (name Resistor_SMD)(type KiCad)(uri \${KICAD9_FOOTPRINT_DIR}/Resistor_SMD.pretty)(options "")(descr "Resistor SMD footprints"))
  (lib (name Battery)(type KiCad)(uri \${KICAD9_FOOTPRINT_DIR}/Battery.pretty)(options "")(descr "Battery holders"))
)
''';

/// A `.pretty` folder zipped the way GitLab hands one over: inside a
/// folder named after the archive.
Uint8List _prettyZip(String name) {
  final archive = Archive();
  for (final entry in twoPadFootprintSources().entries) {
    archive.addFile(
      ArchiveFile.bytes(
        'kicad-footprints-${KicadLibrarySource.version}-$name.pretty/'
        '$name.pretty/${entry.key}',
        entry.value,
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// Serves KiCad's repositories from memory; anything else is a 404.
class _FakeKicad implements LibraryFetcher {
  _FakeKicad({this.missing = const {}});

  /// Library names that fail to download.
  final Set<String> missing;
  final requested = <Uri>[];

  @override
  Future<Uint8List> get(
    Uri uri, {
    void Function(int received, int? total)? onProgress,
  }) async {
    requested.add(uri);
    final text = uri.toString();
    Uint8List? body;
    if (text.endsWith('/sym-lib-table')) {
      body = Uint8List.fromList(_symbolIndex.codeUnits);
    } else if (text.endsWith('/fp-lib-table')) {
      body = Uint8List.fromList(_footprintIndex.codeUnits);
    } else {
      for (final name in ['Device', 'Audio']) {
        if (text.endsWith('/$name.kicad_sym') && !missing.contains(name)) {
          body = libraryBytes();
        }
      }
      for (final name in ['Resistor_SMD', 'Battery']) {
        if (text.contains('path=$name.pretty') && !missing.contains(name)) {
          body = _prettyZip(name);
        }
      }
    }
    if (body == null) throw HttpException('Server answered 404', uri: uri);
    onProgress?.call(body.length, body.length);
    return body;
  }
}

void main() {
  group('the index', () {
    test('lists every library with its description, sorted', () {
      final symbols = KicadLibrarySource.parseIndex(
        RemoteLibraryKind.symbols,
        _symbolIndex,
      );
      expect([for (final l in symbols) l.name], ['Audio', 'Device']);
      expect(symbols.last.description, 'Generic symbols');

      final footprints = KicadLibrarySource.parseIndex(
        RemoteLibraryKind.footprints,
        _footprintIndex,
      );
      expect([for (final l in footprints) l.name], ['Battery', 'Resistor_SMD']);
    });

    test('points at the pinned KiCad 9 release', () {
      const device = RemoteLibrary(
        kind: RemoteLibraryKind.symbols,
        name: 'Device',
      );
      const pins = RemoteLibrary(
        kind: RemoteLibraryKind.footprints,
        name: 'Connector_PinHeader_2.54mm',
      );
      expect(
        KicadLibrarySource.downloadUri(device).toString(),
        'https://gitlab.com/kicad/libraries/kicad-symbols/-/raw/'
        '${KicadLibrarySource.version}/Device.kicad_sym',
      );
      final zip = KicadLibrarySource.downloadUri(pins);
      expect(zip.path, endsWith('.zip'));
      expect(zip.queryParameters['path'], 'Connector_PinHeader_2.54mm.pretty');
    });
  });

  group('downloading', () {
    late AppDatabase db;
    late SymbolLibraryRepository symbols;
    late FootprintLibraryRepository footprints;
    setUp(() {
      db = AppDatabase.memory();
      symbols = SymbolLibraryRepository(db, InMemoryLibraryStorage());
      footprints = FootprintLibraryRepository(db, InMemoryLibraryStorage());
    });
    tearDown(() => db.close());

    KicadLibraryDownloader downloader(LibraryFetcher fetcher) =>
        KicadLibraryDownloader(
          fetcher: fetcher,
          symbols: symbols,
          footprints: footprints,
          parseInBackground: false,
        );

    test('imports what was picked, and carries on past a failure', () async {
      final kicad = downloader(_FakeKicad(missing: {'Audio'}));
      final all = [
        ...await kicad.catalog(RemoteLibraryKind.symbols),
        ...await kicad.catalog(RemoteLibraryKind.footprints),
      ];
      final progress = <double>[];
      final result = await kicad.download(
        all,
        onProgress: (p) => progress.add(p.fraction),
      );

      expect(
        [for (final l in result.installed) l.name],
        ['Device', 'Battery', 'Resistor_SMD'],
      );
      expect(result.failed.keys.single.name, 'Audio');
      expect(result.cancelled, isFalse);
      expect(progress.last, 1);

      expect(
        [for (final l in await symbols.getLibraries()) l.nickname],
        ['Device'],
      );
      // Named after the .pretty folder, as KiCad names it.
      expect(
        {for (final l in await footprints.getLibraries()) l.nickname},
        {'Battery', 'Resistor_SMD'},
      );
    });

    test('stops between libraries when cancelled', () async {
      final kicad = downloader(_FakeKicad());
      final all = await kicad.catalog(RemoteLibraryKind.symbols);
      var calls = 0;
      final result = await kicad.download(all, isCancelled: () => calls++ > 0);
      expect(result.cancelled, isTrue);
      expect(result.installed, hasLength(1));
    });
  });

  testAppWithStorage(
    'from an empty library screen, the essentials download in one tap',
    (tester, db, storage) async {
      final fake = _FakeKicad();
      await pumpApp(
        tester,
        const Scaffold(body: LibrariesPanel()),
        database: db,
        storage: storage,
        overrides: [
          kicadLibraryDownloaderProvider.overrideWith(
            (ref) => KicadLibraryDownloader(
              fetcher: fake,
              symbols: ref.watch(symbolLibraryRepositoryProvider),
              footprints: ref.watch(footprintLibraryRepositoryProvider),
              parseInBackground: false,
            ),
          ),
        ],
      );

      expect(find.text('No symbol libraries yet'), findsOneWidget);
      await tester.tap(find.text('DOWNLOAD FROM KICAD').last);
      await settleApp(tester);

      // Both lists are offered; the essentials start ticked.
      expect(find.text('Audio chips'), findsOneWidget);
      expect(find.text('DOWNLOAD 2 LIBRARIES'), findsOneWidget);
      CheckboxListTile tile(String kind, String name) =>
          tester.widget(find.byKey(ValueKey('kicad-lib-$kind-$name')));
      expect(tile('symbols', 'Device').value, isTrue);
      expect(tile('symbols', 'Audio').value, isFalse);

      // Search narrows the list; a tick adds one more.
      await tester.enterText(
        find.byKey(const ValueKey('kicad-download-search')),
        'audio',
      );
      await settleApp(tester);
      expect(find.text('Generic symbols'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kicad-lib-symbols-Audio')));
      await settleApp(tester);
      expect(find.text('DOWNLOAD 3 LIBRARIES'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kicad-download-start')));
      await settleApp(tester);
      expect(find.text('3 libraries installed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kicad-download-done')));
      await settleApp(tester);

      expect(
        {
          for (final l in await SymbolLibraryRepository(
            db,
            storage,
          ).getLibraries())
            l.nickname,
        },
        {'Device', 'Audio'},
      );
      expect(find.text('No symbol libraries yet'), findsNothing);
    },
  );
}
