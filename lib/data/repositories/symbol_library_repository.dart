import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/symbols/symbols.dart';
import '../../kicad/symbol_library_reader.dart';
import '../db/database.dart';
import '../libraries/library_file_storage.dart';

/// Thrown when a file cannot be imported as a symbol library.
class LibraryImportException implements Exception {
  const LibraryImportException(this.message);

  final String message;

  @override
  String toString() => 'LibraryImportException: $message';
}

/// Imported symbol libraries: the index in the database, the files on disk.
class SymbolLibraryRepository {
  SymbolLibraryRepository(this._db, this._storage);

  final AppDatabase _db;
  final LibraryFileStorage _storage;

  /// Parsed symbols kept around after being loaded. Small and bounded: the
  /// pinout view and the canvas ask for the same handful repeatedly.
  final _cache = <String, SymbolDefinition>{};
  static const _cacheLimit = 64;

  Stream<List<SymbolLibraryInfo>> watchLibraries() {
    final query = _db.select(_db.symbolLibraries)
      ..orderBy([(t) => OrderingTerm.asc(t.nickname)]);
    return query.watch().map((rows) => rows.map(_toInfo).toList());
  }

  Future<List<SymbolLibraryInfo>> getLibraries() async {
    final query = _db.select(_db.symbolLibraries)
      ..orderBy([(t) => OrderingTerm.asc(t.nickname)]);
    return (await query.get()).map(_toInfo).toList();
  }

  Future<int> symbolCount() async {
    final count = _db.symbolIndexEntries.id.count();
    final row = await (_db.selectOnly(
      _db.symbolIndexEntries,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Imports a `.kicad_sym` file: stores it, parses it, indexes every symbol.
  ///
  /// Re-importing a library with a nickname that is already present replaces
  /// it, which is what updating a library from the desktop looks like.
  Future<SymbolLibraryInfo> import({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final nickname = _nicknameFor(fileName);
    if (nickname.isEmpty) {
      throw const LibraryImportException('The file needs a name');
    }

    final ParsedSymbolLibrary parsed;
    try {
      parsed = SymbolLibraryReader.parseLibrary(bytes, nickname: nickname);
    } catch (error) {
      throw LibraryImportException('Not a readable .kicad_sym file: $error');
    }
    if (parsed.symbols.isEmpty) {
      throw const LibraryImportException('That file contains no symbols');
    }

    final storedName = '$nickname.kicad_sym';
    await _storage.write(storedName, bytes);

    final libraryId = newId();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.symbolLibraries,
      )..where((t) => t.nickname.equals(nickname))).getSingleOrNull();
      if (existing != null) {
        await (_db.delete(
          _db.symbolLibraries,
        )..where((t) => t.id.equals(existing.id))).go();
      }

      await _db
          .into(_db.symbolLibraries)
          .insert(
            SymbolLibrariesCompanion.insert(
              id: libraryId,
              nickname: nickname,
              fileName: storedName,
              formatVersion: Value(parsed.header.version),
              generator: Value(parsed.header.generator),
              symbolCount: Value(parsed.symbols.length),
              byteSize: Value(bytes.length),
              importedAt: DateTime.now(),
            ),
          );

      await _db.batch((batch) {
        for (final symbol in parsed.symbols) {
          final span = parsed.spans[symbol.name];
          batch.insert(
            _db.symbolIndexEntries,
            SymbolIndexEntriesCompanion.insert(
              id: newId(),
              libraryId: libraryId,
              libraryNickname: nickname,
              name: symbol.name,
              description: Value(symbol.description),
              keywords: Value(symbol.keywords),
              referencePrefix: Value(symbol.referencePrefix),
              defaultFootprint: Value(symbol.footprint),
              datasheet: Value(symbol.datasheet),
              footprintFilters: Value(symbol.properties['ki_fp_filters'] ?? ''),
              unitCount: Value(symbol.unitCount),
              pinCount: Value(symbol.pinCount),
              isPower: Value(symbol.isPower),
              extendsSymbol: Value(symbol.extendsSymbol),
              spanStart: Value(span?.start ?? 0),
              spanEnd: Value(span?.end ?? 0),
              searchText: Value(_searchTextFor(symbol)),
            ),
          );
        }
      });
    });

    _cache.removeWhere((key, _) => key.startsWith('$nickname:'));

    final info = await (_db.select(
      _db.symbolLibraries,
    )..where((t) => t.id.equals(libraryId))).getSingle();
    return _toInfo(info);
  }

  Future<void> deleteLibrary(String id) async {
    final row = await (_db.select(
      _db.symbolLibraries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (_db.delete(_db.symbolLibraries)..where((t) => t.id.equals(id))).go();
    await _storage.delete(row.fileName);
    _cache.removeWhere((key, _) => key.startsWith('${row.nickname}:'));
  }

  /// Searches indexed symbols.
  ///
  /// Every term has to match somewhere in the symbol's name, description or
  /// keywords, so `stm32 lqfp` narrows rather than widens. Results are
  /// ranked exact name first, then name prefix, then everything else.
  Future<List<SymbolIndexEntry>> search(
    String query, {
    int limit = 200,
    String? libraryId,
    bool powerOnly = false,
    bool microcontrollersOnly = false,
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
    if (powerOnly) {
      where.add('is_power = 1');
    }
    // Judged by the library the part came from. KiCad files every
    // microcontroller under MCU_* (and the bigger processors under CPU_*),
    // which is the only signal available without opening every symbol in
    // the index — and opening twenty thousand symbols to answer a search is
    // not a trade worth making.
    if (microcontrollersOnly) {
      where.add(
        "(library_nickname LIKE 'MCU%' OR library_nickname LIKE 'CPU%')",
      );
    }

    final firstTerm = terms.isEmpty ? '' : terms.first;
    final sql =
        'SELECT * FROM symbol_index_entries '
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
          readsFrom: {_db.symbolIndexEntries},
        )
        .get();

    return rows
        .map((row) => _toEntry(_db.symbolIndexEntries.map(row.data)))
        .toList();
  }

  Future<SymbolIndexEntry?> findByLibId(String libId) async {
    final parts = _splitLibId(libId);
    if (parts == null) return null;
    final row =
        await (_db.select(_db.symbolIndexEntries)..where(
              (t) =>
                  t.libraryNickname.equals(parts.$1) & t.name.equals(parts.$2),
            ))
            .getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  /// Loads the full definition of one symbol, resolving inheritance.
  ///
  /// Reads only that symbol's bytes out of the library file, then does the
  /// same for its parent if it has one.
  Future<SymbolDefinition?> loadSymbol(String libId) async {
    final cached = _cache[libId];
    if (cached != null) return cached;

    final resolved = await _loadResolved(libId, <String>{});
    if (resolved != null) _remember(libId, resolved);
    return resolved;
  }

  Future<SymbolDefinition?> _loadResolved(
    String libId,
    Set<String> visiting,
  ) async {
    if (!visiting.add(libId)) return null; // inheritance cycle

    final entry = await findByLibId(libId);
    if (entry == null) return null;

    final library = await (_db.select(
      _db.symbolLibraries,
    )..where((t) => t.id.equals(entry.libraryId))).getSingleOrNull();
    if (library == null) return null;
    if (!_storage.exists(library.fileName)) return null;

    final bytes = await _storage.readRange(
      library.fileName,
      entry.spanStart,
      entry.spanEnd,
    );
    final symbol = SymbolLibraryReader.parseSymbolBytes(
      bytes,
      nickname: entry.libraryNickname,
    );

    final parentName = symbol.extendsSymbol;
    if (parentName == null) return symbol;

    final parent = await _loadResolved(
      '${entry.libraryNickname}:$parentName',
      visiting,
    );
    return parent == null ? symbol : symbol.resolvedAgainst(parent);
  }

  void _remember(String libId, SymbolDefinition symbol) {
    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[libId] = symbol;
  }

  static (String, String)? _splitLibId(String libId) {
    final index = libId.indexOf(':');
    if (index <= 0 || index == libId.length - 1) return null;
    return (libId.substring(0, index), libId.substring(index + 1));
  }

  /// `Device.kicad_sym` and `Device` both give the nickname `Device`.
  static String _nicknameFor(String fileName) {
    var name = fileName.split(RegExp(r'[/\\]')).last.trim();
    if (name.toLowerCase().endsWith('.kicad_sym')) {
      name = name.substring(0, name.length - '.kicad_sym'.length);
    }
    return name;
  }

  static String _searchTextFor(SymbolDefinition symbol) =>
      '${symbol.name} ${symbol.description} ${symbol.keywords}'.toLowerCase();

  static SymbolLibraryInfo _toInfo(SymbolLibraryRow row) => SymbolLibraryInfo(
    id: row.id,
    nickname: row.nickname,
    fileName: row.fileName,
    symbolCount: row.symbolCount,
    byteSize: row.byteSize,
    importedAt: row.importedAt,
    formatVersion: row.formatVersion,
    generator: row.generator,
  );

  static SymbolIndexEntry _toEntry(SymbolIndexRow row) => SymbolIndexEntry(
    id: row.id,
    libraryId: row.libraryId,
    libraryNickname: row.libraryNickname,
    name: row.name,
    description: row.description,
    keywords: row.keywords,
    referencePrefix: row.referencePrefix,
    defaultFootprint: row.defaultFootprint,
    datasheet: row.datasheet,
    footprintFilters: row.footprintFilters,
    unitCount: row.unitCount,
    pinCount: row.pinCount,
    isPower: row.isPower,
    extendsSymbol: row.extendsSymbol,
    spanStart: row.spanStart,
    spanEnd: row.spanEnd,
  );
}
