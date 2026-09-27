import 'dart:convert';

import 'package:archive/archive.dart';

/// The KiCad files of a project, however they arrived: picked one by one,
/// or inside a `.zip` of the project's folder, which is the easy way to
/// bring a design with sub-sheets across in one go.
///
/// Files are known by their names alone. A sheet kept in a folder of its
/// own (`sch/power.kicad_sch`) is found by `power.kicad_sch`, which is also
/// all a picker tells us about a file.
class KicadPickedFiles {
  /// File name to text, for `.kicad_sch`, `.kicad_pcb` and `.kicad_pro`.
  final files = <String, String>{};

  static const _extensions = ['.kicad_sch', '.kicad_pcb', '.kicad_pro'];

  static bool isKicad(String name) =>
      _extensions.any((e) => name.toLowerCase().endsWith(e));

  static String baseName(String path) => path.split('/').last;

  /// Takes [bytes] picked as [name]: a KiCad file as it is, a zip opened
  /// for the KiCad files inside it. Anything else is left out, and false
  /// says so.
  bool add(String name, List<int> bytes) {
    if (name.toLowerCase().endsWith('.zip')) return _addZip(bytes);
    if (!isKicad(name)) return false;
    files[baseName(name)] = utf8.decode(bytes, allowMalformed: true);
    return true;
  }

  bool _addZip(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return false;
    }
    var any = false;
    for (final entry in archive) {
      if (!entry.isFile || !isKicad(entry.name)) continue;
      final parts = entry.name.split('/');
      // The junk archivers add, and KiCad's own backups of the project.
      if (parts.any(
        (p) =>
            p.startsWith('.') ||
            p == '__MACOSX' ||
            p.toLowerCase().endsWith('-backups'),
      )) {
        continue;
      }
      files[baseName(entry.name)] = utf8.decode(
        entry.content,
        allowMalformed: true,
      );
      any = true;
    }
    return any;
  }

  Map<String, String> get schematics => {
    for (final e in files.entries)
      if (e.key.toLowerCase().endsWith('.kicad_sch')) e.key: e.value,
  };

  /// The file ending in [extension], preferring the one named after
  /// [project] when there are several.
  MapEntry<String, String>? withExtension(String extension, {String? project}) {
    final matching = [
      for (final e in files.entries)
        if (e.key.toLowerCase().endsWith(extension)) e,
    ];
    if (matching.isEmpty) return null;
    if (project != null) {
      for (final e in matching) {
        if (e.key.toLowerCase() == '$project$extension'.toLowerCase()) {
          return e;
        }
      }
    }
    return matching.first;
  }

  /// The sheet files the picked schematics name that were not picked: the
  /// sub-sheets whose parts, and whose footprints on the board, would
  /// otherwise be left out without a word.
  List<String> get missingSheets {
    final have = {for (final name in schematics.keys) name.toLowerCase()};
    final missing = <String>{};
    for (final text in schematics.values) {
      for (final m in RegExp(
        r'\(property\s+"Sheetfile"\s+"([^"]+)"',
      ).allMatches(text)) {
        final name = baseName(m.group(1)!);
        if (!have.contains(name.toLowerCase())) missing.add(name);
      }
    }
    return missing.toList()..sort();
  }
}
