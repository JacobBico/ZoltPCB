import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../fab/silk_fonts.dart';
import '../../fab/truetype.dart';
import '../db/database.dart';

/// Fonts the user has added for silkscreen text, kept in the database so
/// they are there for every board on the phone.
class FontRepository {
  FontRepository(this._db);

  final AppDatabase _db;

  /// Adds the font in [bytes], read from [fileName], and makes it available
  /// at once. Throws a [FormatException] saying why if it cannot be used.
  Future<SilkFontInfo> add(String fileName, Uint8List bytes) async {
    // Read before storing, so a font that cannot be drawn never gets in.
    final family = TrueTypeFont.parse(bytes).family;
    final id = newId();
    await _db
        .into(_db.userFonts)
        .insert(
          UserFontsCompanion.insert(
            id: id,
            family: family,
            fileName: fileName,
            bytes: bytes,
            createdAt: DateTime.now(),
          ),
        );
    final key = 'user:$id';
    SilkFonts.register(key, bytes, name: family);
    return SilkFontInfo(key, family);
  }

  /// Makes every stored font available. Called once at start-up; a font
  /// that no longer reads is skipped rather than stopping the others.
  Future<void> loadAll() async {
    for (final row in await _db.select(_db.userFonts).get()) {
      try {
        SilkFonts.register('user:${row.id}', row.bytes, name: row.family);
      } on FormatException {
        continue;
      }
    }
  }

  Future<void> delete(String key) async {
    final id = key.startsWith('user:') ? key.substring(5) : key;
    await (_db.delete(_db.userFonts)..where((t) => t.id.equals(id))).go();
    SilkFonts.unregister(key);
  }
}
