/// A searchable summary of one symbol in an imported library.
///
/// Only this much is kept in the database. Geometry and pin detail stay in
/// the library file on disk and are parsed on demand, which keeps importing
/// a 4 MB library cheap and the database small.
class SymbolIndexEntry {
  const SymbolIndexEntry({
    required this.id,
    required this.libraryId,
    required this.libraryNickname,
    required this.name,
    required this.unitCount,
    required this.pinCount,
    this.description = '',
    this.keywords = '',
    this.referencePrefix = 'U',
    this.defaultFootprint = '',
    this.datasheet = '',
    this.footprintFilters = '',
    this.isPower = false,
    this.extendsSymbol,
    this.spanStart = 0,
    this.spanEnd = 0,
  });

  final String id;
  final String libraryId;
  final String libraryNickname;
  final String name;
  final String description;
  final String keywords;
  final String referencePrefix;
  final String defaultFootprint;
  final String datasheet;
  final String footprintFilters;
  final int unitCount;
  final int pinCount;
  final bool isPower;
  final String? extendsSymbol;

  /// Byte range of this symbol inside its library file.
  final int spanStart;
  final int spanEnd;

  /// `Device:R` — the identifier a schematic file uses.
  String get libId => '$libraryNickname:$name';

  bool get isMultiUnit => unitCount > 1;

  @override
  String toString() => 'SymbolIndexEntry($libId, $pinCount pins)';
}

/// An imported `.kicad_sym` file.
class SymbolLibraryInfo {
  const SymbolLibraryInfo({
    required this.id,
    required this.nickname,
    required this.fileName,
    required this.symbolCount,
    required this.byteSize,
    required this.importedAt,
    this.formatVersion = 0,
    this.generator = '',
  });

  final String id;

  /// The library nickname, taken from the file name: `Device` for
  /// `Device.kicad_sym`. This is the first half of every `lib_id` it
  /// produces, so it has to match what the desktop expects.
  final String nickname;

  final String fileName;
  final int symbolCount;
  final int byteSize;
  final DateTime importedAt;
  final int formatVersion;
  final String generator;

  @override
  String toString() => 'SymbolLibraryInfo($nickname, $symbolCount symbols)';
}
