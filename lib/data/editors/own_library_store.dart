import 'dart:convert';

import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart';
import '../../kicad/footprint_writer.dart';
import '../../kicad/sexpr/sexpr.dart';
import '../../kicad/sexpr/sexpr_writer.dart';
import '../../kicad/symbol_writer.dart';
import '../repositories/footprint_library_repository.dart';
import '../repositories/symbol_library_repository.dart';

/// The user's own symbols and footprints, kept as ordinary libraries.
///
/// Stored the same way an imported library is, so a symbol made here shows
/// up in Add component, and a footprint in the footprint picker, with no
/// special case anywhere else. A library is saved whole, so saving one
/// symbol rewrites the file with all the others beside it.
class OwnLibraryStore {
  OwnLibraryStore({required this.symbols, required this.footprints});

  final SymbolLibraryRepository symbols;
  final FootprintLibraryRepository footprints;

  static const symbolLibrary = 'My_Symbols';
  static const footprintLibrary = 'My_Footprints';

  // --- symbols ---------------------------------------------------------

  Future<List<SymbolDefinition>> loadSymbols() async {
    final library = (await symbols.getLibraries())
        .where((l) => l.nickname == symbolLibrary)
        .firstOrNull;
    if (library == null) return const [];
    final entries = await symbols.search(
      '',
      libraryId: library.id,
      limit: 5000,
    );
    return [for (final entry in entries) ?await symbols.loadSymbol(entry.libId)]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Saves [symbol], replacing any of the same name and, if it was renamed,
  /// the one called [previousName].
  Future<void> saveSymbol(
    SymbolDefinition symbol, {
    String? previousName,
  }) async {
    final others = [
      for (final existing in await loadSymbols())
        if (existing.name != symbol.name && existing.name != previousName)
          existing,
    ];
    await _writeSymbols([...others, symbol]);
  }

  Future<void> deleteSymbol(String name) async {
    final remaining = [
      for (final existing in await loadSymbols())
        if (existing.name != name) existing,
    ];
    if (remaining.isEmpty) {
      final library = (await symbols.getLibraries())
          .where((l) => l.nickname == symbolLibrary)
          .firstOrNull;
      if (library != null) await symbols.deleteLibrary(library.id);
      return;
    }
    await _writeSymbols(remaining);
  }

  Future<void> _writeSymbols(List<SymbolDefinition> all) async {
    final library = SList([
      SAtom('kicad_symbol_lib'),
      S.of('version', [20241209]),
      SList([SAtom('generator'), S.text('hintpcb')]),
      for (final symbol in all)
        SymbolWriter.libSymbol(symbol, libId: symbol.name),
    ]);
    await symbols.import(
      fileName: '$symbolLibrary.kicad_sym',
      bytes: utf8.encode(const SExprWriter().write(library)),
    );
  }

  // --- footprints ------------------------------------------------------

  Future<List<FootprintDefinition>> loadFootprints() async {
    final library = (await footprints.getLibraries())
        .where((l) => l.nickname == footprintLibrary)
        .firstOrNull;
    if (library == null) return const [];
    final entries = await footprints.search(
      '',
      libraryId: library.id,
      limit: 5000,
    );
    return [
      for (final entry in entries) ?await footprints.loadFootprint(entry.libId),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveFootprint(
    FootprintDefinition footprint, {
    String? previousName,
  }) async {
    final others = [
      for (final existing in await loadFootprints())
        if (existing.name != footprint.name && existing.name != previousName)
          existing,
    ];
    await _writeFootprints([...others, footprint]);
  }

  Future<void> deleteFootprint(String name) async {
    final remaining = [
      for (final existing in await loadFootprints())
        if (existing.name != name) existing,
    ];
    if (remaining.isEmpty) {
      final library = (await footprints.getLibraries())
          .where((l) => l.nickname == footprintLibrary)
          .firstOrNull;
      if (library != null) await footprints.deleteLibrary(library.id);
      return;
    }
    await _writeFootprints(remaining);
  }

  Future<void> _writeFootprints(List<FootprintDefinition> all) async {
    await footprints.import(
      nickname: footprintLibrary,
      sources: {
        for (final footprint in all)
          '${footprint.name}.kicad_mod': utf8.encode(
            FootprintWriter.write(footprint),
          ),
      },
    );
  }
}
