import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/pcb/pcb.dart';
import '../../kicad/footprint_library_reader.dart';
import '../../kicad/sexpr/sexpr.dart';
import '../../kicad/sexpr/sexpr_parser.dart';
import '../db/database.dart';
import '../libraries/library_file_storage.dart';
import 'symbol_library_repository.dart' show LibraryImportException;

/// A searchable summary of one footprint in an imported library.
class FootprintIndexEntry {
  const FootprintIndexEntry({
    required this.id,
    required this.libraryId,
    required this.libraryNickname,
    required this.name,
    this.description = '',
    this.keywords = '',
    this.padCount = 0,
    this.isSurfaceMount = false,
    this.isThroughHole = false,
    this.spanStart = 0,
    this.spanEnd = 0,
  });

  final String id;
  final String libraryId;
  final String libraryNickname;
  final String name;
  final String description;
  final String keywords;
  final int padCount;
  final bool isSurfaceMount;
  final bool isThroughHole;
  final int spanStart;
  final int spanEnd;

  /// `Resistor_SMD:R_0805_2012Metric`.
  String get libId => '$libraryNickname:$name';

  @override
  String toString() => 'FootprintIndexEntry($libId, $padCount pads)';
}

/// An imported footprint library.
class FootprintLibraryInfo {
  const FootprintLibraryInfo({
    required this.id,
    required this.nickname,
    required this.fileName,
    required this.footprintCount,
    required this.byteSize,
    required this.importedAt,
  });

  final String id;
  final String nickname;
  final String fileName;
  final int footprintCount;
  final int byteSize;
  final DateTime importedAt;
}

/// Imported footprint libraries: the index in the database, the packed
/// container on disk.
///
/// Deliberately the same shape as [SymbolLibraryRepository]. Footprints are
/// a second kind of library, not a second kind of problem, and the app has
/// already learned once that indexing metadata while leaving geometry on
/// disk is what makes a 200 MB corpus usable on a phone.
class FootprintLibraryRepository {
  FootprintLibraryRepository(this._db, this._storage);

  final AppDatabase _db;
  final LibraryFileStorage _storage;

  final _cache = <String, FootprintDefinition>{};
  static const _cacheLimit = 64;

  Stream<List<FootprintLibraryInfo>> watchLibraries() {
    final query = _db.select(_db.footprintLibraries)
      ..orderBy([(t) => OrderingTerm.asc(t.nickname)]);
    return query.watch().map((rows) => rows.map(_toInfo).toList());
  }

  Future<List<FootprintLibraryInfo>> getLibraries() async {
    final query = _db.select(_db.footprintLibraries)
      ..orderBy([(t) => OrderingTerm.asc(t.nickname)]);
    return (await query.get()).map(_toInfo).toList();
  }

  Future<int> footprintCount() async {
    final count = _db.footprintIndexEntries.id.count();
    final row = await (_db.selectOnly(
      _db.footprintIndexEntries,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Imports a set of `.kicad_mod` sources as one library.
  ///
  /// [sources] is keyed by file name. Re-importing a nickname replaces what
  /// was there, which is what updating a library from the desktop looks
  /// like.
  Future<FootprintLibraryInfo> import({
    required String nickname,
    required Map<String, Uint8List> sources,
  }) async {
    final cleaned = nickname.trim();
    if (cleaned.isEmpty) {
      throw const LibraryImportException('The library needs a name');
    }
    // The nickname becomes a file name, and it can be typed by hand.
    if (cleaned.contains(RegExp(r'[/\\]')) || cleaned.startsWith('.')) {
      throw const LibraryImportException(
        'A library name cannot contain / or \\, or start with a dot',
      );
    }
    if (sources.isEmpty) {
      throw const LibraryImportException('No footprint files were given');
    }

    final packed = FootprintLibraryReader.pack(
      nickname: cleaned,
      sources: sources,
    );
    if (packed.footprints.isEmpty) {
      throw LibraryImportException(
        'No readable footprints in that import'
        '${packed.warnings.isEmpty ? '' : ': ${packed.warnings.first}'}',
      );
    }

    final storedName = '$cleaned.footprints';
    await _storage.write(storedName, packed.bytes);

    final libraryId = newId();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.footprintLibraries,
      )..where((t) => t.nickname.equals(cleaned))).getSingleOrNull();
      if (existing != null) {
        await (_db.delete(
          _db.footprintLibraries,
        )..where((t) => t.id.equals(existing.id))).go();
      }

      await _db
          .into(_db.footprintLibraries)
          .insert(
            FootprintLibrariesCompanion.insert(
              id: libraryId,
              nickname: cleaned,
              fileName: storedName,
              footprintCount: Value(packed.footprints.length),
              byteSize: Value(packed.bytes.length),
              importedAt: DateTime.now(),
            ),
          );

      await _db.batch((batch) {
        for (final footprint in packed.footprints) {
          final span = packed.spans[footprint.name];
          batch.insert(
            _db.footprintIndexEntries,
            FootprintIndexEntriesCompanion.insert(
              id: newId(),
              libraryId: libraryId,
              libraryNickname: cleaned,
              name: footprint.name,
              description: Value(footprint.description),
              keywords: Value(footprint.keywords),
              padCount: Value(footprint.padCount),
              isSurfaceMount: Value(footprint.isSurfaceMount),
              isThroughHole: Value(footprint.isThroughHole),
              spanStart: Value(span?.start ?? 0),
              spanEnd: Value(span?.end ?? 0),
              searchText: Value(_searchTextFor(footprint)),
            ),
          );
        }
      });
    });

    _cache.removeWhere((key, _) => key.startsWith('$cleaned:'));

    final row = await (_db.select(
      _db.footprintLibraries,
    )..where((t) => t.id.equals(libraryId))).getSingle();
    return _toInfo(row);
  }

  Future<void> deleteLibrary(String id) async {
    final row = await (_db.select(
      _db.footprintLibraries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (_db.delete(
      _db.footprintLibraries,
    )..where((t) => t.id.equals(id))).go();
    await _storage.delete(row.fileName);
    _cache.removeWhere((key, _) => key.startsWith('${row.nickname}:'));
  }

  /// Searches indexed footprints. Every term has to match somewhere, so
  /// `0805 resistor` narrows rather than widens.
  Future<List<FootprintIndexEntry>> search(
    String query, {
    int limit = 200,
    String? libraryId,
    int? padCount,
  }) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final where = <String>[];
    final variables = <Variable<Object>>[];

    for (final term in terms) {
      where.add('search_text LIKE ?');
      variables.add(Variable<String>('%$term%'));
    }
    if (libraryId != null) {
      where.add('library_id = ?');
      variables.add(Variable<String>(libraryId));
    }
    // Filtering by pad count is what turns "every footprint on the phone"
    // into "the ones this part could actually use".
    if (padCount != null) {
      where.add('pad_count = ?');
      variables.add(Variable<int>(padCount));
    }

    final firstTerm = terms.isEmpty ? '' : terms.first;
    final sql =
        'SELECT * FROM footprint_index_entries '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
        'ORDER BY '
        '  CASE WHEN lower(name) = ? THEN 0 '
        '       WHEN lower(name) LIKE ? THEN 1 '
        '       ELSE 2 END, '
        '  length(name), library_nickname, name '
        'LIMIT ?';
    variables
      ..add(Variable<String>(firstTerm))
      ..add(Variable<String>('$firstTerm%'))
      ..add(Variable<int>(limit));

    final rows = await _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.footprintIndexEntries},
        )
        .get();

    return rows
        .map((row) => _toEntry(_db.footprintIndexEntries.map(row.data)))
        .toList();
  }

  Future<FootprintIndexEntry?> findByLibId(String libId) async {
    final parts = _splitLibId(libId);
    if (parts == null) return null;
    final row =
        await (_db.select(_db.footprintIndexEntries)..where(
              (t) =>
                  t.libraryNickname.equals(parts.$1) & t.name.equals(parts.$2),
            ))
            .getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  /// Loads one footprint, reading only its own bytes out of the container.
  Future<FootprintDefinition?> loadFootprint(String libId) async {
    final cached = _cache[libId];
    if (cached != null) return cached;

    final entry = await findByLibId(libId);
    if (entry == null) return null;

    final library = await (_db.select(
      _db.footprintLibraries,
    )..where((t) => t.id.equals(entry.libraryId))).getSingleOrNull();
    if (library == null || !_storage.exists(library.fileName)) return null;

    final bytes = await _storage.readRange(
      library.fileName,
      entry.spanStart,
      entry.spanEnd,
    );

    final FootprintDefinition footprint;
    try {
      footprint = FootprintLibraryReader.parseOne(
        bytes,
        nickname: entry.libraryNickname,
      );
    } catch (_) {
      return null;
    }

    if (_cache.length >= _cacheLimit) _cache.clear();
    _cache[libId] = footprint;
    return footprint;
  }

  /// The raw `(footprint ...)` node, exactly as the library wrote it.
  ///
  /// Used by the board exporter, which places a footprint by editing its own
  /// source rather than rebuilding it from what this app happens to model.
  Future<SList?> loadFootprintNode(String libId) async {
    final entry = await findByLibId(libId);
    if (entry == null) return null;

    final library = await (_db.select(
      _db.footprintLibraries,
    )..where((t) => t.id.equals(entry.libraryId))).getSingleOrNull();
    if (library == null || !_storage.exists(library.fileName)) return null;

    final bytes = await _storage.readRange(
      library.fileName,
      entry.spanStart,
      entry.spanEnd,
    );
    try {
      return SExprParser.parseDocument(
        utf8.decode(bytes, allowMalformed: true).trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static (String, String)? _splitLibId(String libId) {
    final index = libId.indexOf(':');
    if (index <= 0 || index == libId.length - 1) return null;
    return (libId.substring(0, index), libId.substring(index + 1));
  }

  static String _searchTextFor(FootprintDefinition footprint) => [
    footprint.name,
    footprint.description,
    footprint.keywords,
  ].join(' ').toLowerCase();

  static FootprintLibraryInfo _toInfo(FootprintLibraryRow row) =>
      FootprintLibraryInfo(
        id: row.id,
        nickname: row.nickname,
        fileName: row.fileName,
        footprintCount: row.footprintCount,
        byteSize: row.byteSize,
        importedAt: row.importedAt,
      );

  static FootprintIndexEntry _toEntry(FootprintIndexRow row) =>
      FootprintIndexEntry(
        id: row.id,
        libraryId: row.libraryId,
        libraryNickname: row.libraryNickname,
        name: row.name,
        description: row.description,
        keywords: row.keywords,
        padCount: row.padCount,
        isSurfaceMount: row.isSurfaceMount,
        isThroughHole: row.isThroughHole,
        spanStart: row.spanStart,
        spanEnd: row.spanEnd,
      );
}
