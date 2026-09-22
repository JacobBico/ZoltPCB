import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/libraries/kicad_library_source.dart';
import '../../data/repositories/footprint_library_repository.dart';
import '../../data/repositories/symbol_library_repository.dart';
import 'footprint_import.dart';

/// The downloader the app uses: real HTTPS, parsing in the background.
/// Tests override it with a fetcher that never touches the network.
final kicadLibraryDownloaderProvider = Provider<KicadLibraryDownloader>(
  (ref) => KicadLibraryDownloader(
    fetcher: HttpLibraryFetcher(),
    symbols: ref.watch(symbolLibraryRepositoryProvider),
    footprints: ref.watch(footprintLibraryRepositoryProvider),
  ),
);

/// Where a download has got to.
class LibraryDownloadProgress {
  const LibraryDownloadProgress({
    required this.done,
    required this.total,
    this.current,
    this.received = 0,
    this.size,
  });

  /// Libraries finished, of [total].
  final int done;
  final int total;

  /// The library being fetched now.
  final RemoteLibrary? current;

  /// Bytes of [current] received, of [size] when the server says.
  final int received;
  final int? size;

  /// 0 to 1 over the whole download, counting the current library's share.
  double get fraction {
    if (total == 0) return 1;
    final part = size == null || size == 0 ? 0.0 : received / size!;
    return ((done + part.clamp(0.0, 1.0)) / total).clamp(0.0, 1.0);
  }
}

/// What a download did.
class LibraryDownloadResult {
  const LibraryDownloadResult({
    required this.installed,
    required this.failed,
    required this.cancelled,
  });

  final List<RemoteLibrary> installed;

  /// Libraries that could not be fetched or read, with why.
  final Map<RemoteLibrary, String> failed;
  final bool cancelled;
}

/// Fetches KiCad's own libraries and imports them, one by one, through the
/// same importers a picked file goes through.
class KicadLibraryDownloader {
  KicadLibraryDownloader({
    required this.fetcher,
    required this.symbols,
    required this.footprints,
    this.parseInBackground = true,
  });

  final LibraryFetcher fetcher;
  final SymbolLibraryRepository symbols;
  final FootprintLibraryRepository footprints;

  /// Parse symbol libraries off the UI isolate. Off in widget tests.
  final bool parseInBackground;

  /// Every library KiCad publishes of [kind].
  Future<List<RemoteLibrary>> catalog(RemoteLibraryKind kind) async {
    final bytes = await fetcher.get(KicadLibrarySource.indexUri(kind));
    return KicadLibrarySource.parseIndex(
      kind,
      utf8.decode(bytes, allowMalformed: true),
    );
  }

  /// Downloads and imports [libraries] in order. One that fails is noted
  /// and the rest carry on; [isCancelled] is asked between libraries.
  Future<LibraryDownloadResult> download(
    List<RemoteLibrary> libraries, {
    void Function(LibraryDownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final installed = <RemoteLibrary>[];
    final failed = <RemoteLibrary, String>{};
    var done = 0;

    for (final library in libraries) {
      if (isCancelled?.call() ?? false) {
        return LibraryDownloadResult(
          installed: installed,
          failed: failed,
          cancelled: true,
        );
      }
      onProgress?.call(
        LibraryDownloadProgress(
          done: done,
          total: libraries.length,
          current: library,
        ),
      );
      try {
        final bytes = await fetcher.get(
          KicadLibrarySource.downloadUri(library),
          onProgress: (received, size) => onProgress?.call(
            LibraryDownloadProgress(
              done: done,
              total: libraries.length,
              current: library,
              received: received,
              size: size,
            ),
          ),
        );
        switch (library.kind) {
          case RemoteLibraryKind.symbols:
            await symbols.import(
              fileName: '${library.name}.kicad_sym',
              bytes: bytes,
              inBackground: parseInBackground,
            );
          case RemoteLibraryKind.footprints:
            await FootprintImport.importZip(
              footprints,
              '${library.name}.pretty.zip',
              bytes,
            );
        }
        installed.add(library);
      } on LibraryImportException catch (error) {
        failed[library] = error.message;
      } catch (error) {
        failed[library] = '$error';
      }
      done++;
    }
    onProgress?.call(
      LibraryDownloadProgress(done: done, total: libraries.length),
    );
    return LibraryDownloadResult(
      installed: installed,
      failed: failed,
      cancelled: false,
    );
  }
}
