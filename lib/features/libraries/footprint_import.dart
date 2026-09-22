import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/repositories/footprint_library_repository.dart';
import '../../data/repositories/symbol_library_repository.dart'
    show LibraryImportException;
import '../../kicad/footprint_library_reader.dart';

/// What one import attempt produced.
class FootprintImportResult {
  const FootprintImportResult({
    this.imported = const [],
    this.failed = const [],
    this.cancelled = false,
  });

  final List<FootprintLibraryInfo> imported;
  final List<String> failed;
  final bool cancelled;

  int get footprintCount =>
      imported.fold(0, (sum, info) => sum + info.footprintCount);

  String get summary {
    if (cancelled) return '';
    if (imported.isEmpty) {
      return failed.isEmpty ? 'Nothing to import' : failed.first;
    }
    final names = imported.map((i) => i.nickname).join(', ');
    final base = 'Imported $footprintCount footprints from $names';
    return failed.isEmpty ? base : '$base — ${failed.length} skipped';
  }
}

/// Brings footprint libraries onto the device.
///
/// A `.pretty` library is a directory of hundreds of tiny files, which is
/// the one shape Android's document picker handles worst. Two ways in, then:
/// a zip of the directory, which is one tap and the way anyone would move it
/// off a desktop, or the `.kicad_mod` files themselves for the handful of
/// footprints a small project actually uses.
abstract final class FootprintImport {
  /// Picks files and imports whatever they turn out to be.
  static Future<FootprintImportResult> run(
    FootprintLibraryRepository repository, {
    Future<String?> Function(String suggestion)? askNickname,
  }) async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Select a .pretty zip, or .kicad_mod files',
        // Android's picker has no MIME type for either, so filtering by
        // extension hides the files on most devices.
        type: FileType.any,
      );
    } catch (error) {
      return FootprintImportResult(
        failed: ['Could not open the picker: $error'],
      );
    }
    if (picked.isEmpty) return const FootprintImportResult(cancelled: true);

    final imported = <FootprintLibraryInfo>[];
    final failed = <String>[];

    // Zips each become their own library, named after the archive. Loose
    // `.kicad_mod` files have no library of their own — the name comes from
    // the directory they sat in, which the picker does not hand over — so
    // they are gathered into one the user names.
    final loose = <String, Uint8List>{};

    for (final file in picked) {
      final bytes = await file.readAsBytes();

      if (file.name.toLowerCase().endsWith('.zip')) {
        try {
          final result = await importZip(repository, file.name, bytes);
          imported.add(result);
        } on LibraryImportException catch (e) {
          failed.add('${file.name}: ${e.message}');
        } catch (e) {
          failed.add('${file.name}: $e');
        }
        continue;
      }

      if (file.name.toLowerCase().endsWith('.kicad_mod')) {
        loose[file.name] = bytes;
        continue;
      }

      failed.add('${file.name}: not a .kicad_mod or a .pretty zip');
    }

    if (loose.isNotEmpty) {
      final suggestion = FootprintLibraryReader.nicknameFor(loose.keys.first);
      final nickname = askNickname == null
          ? suggestion
          : await askNickname(suggestion);
      if (nickname != null && nickname.trim().isNotEmpty) {
        try {
          imported.add(
            await repository.import(nickname: nickname.trim(), sources: loose),
          );
        } on LibraryImportException catch (e) {
          failed.add(e.message);
        } catch (e) {
          failed.add('$e');
        }
      }
    }

    return FootprintImportResult(imported: imported, failed: failed);
  }

  /// Unpacks a zipped `.pretty` directory into a library. Also used for the
  /// libraries downloaded from KiCad, which arrive the same way.
  static Future<FootprintLibraryInfo> importZip(
    FootprintLibraryRepository repository,
    String fileName,
    Uint8List bytes,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (error) {
      throw LibraryImportException('Not a readable zip: $error');
    }

    final sources = <String, Uint8List>{};
    String? innerNickname;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (!name.toLowerCase().endsWith('.kicad_mod')) continue;
      // Skip the junk archivers add.
      if (name
          .split('/')
          .any((part) => part.startsWith('.') || part == '__MACOSX')) {
        continue;
      }

      // `Resistor_SMD.pretty/R_0805.kicad_mod` names its own library, which
      // is a better answer than the name someone gave the zip.
      final segments = name.split('/');
      for (final segment in segments) {
        if (segment.toLowerCase().endsWith('.pretty')) {
          innerNickname = segment.substring(
            0,
            segment.length - '.pretty'.length,
          );
        }
      }

      sources[segments.last] = Uint8List.fromList(entry.content);
    }

    if (sources.isEmpty) {
      throw const LibraryImportException(
        'That zip contains no .kicad_mod files',
      );
    }

    return repository.import(
      nickname: innerNickname ?? FootprintLibraryReader.nicknameFor(fileName),
      sources: sources,
    );
  }
}
