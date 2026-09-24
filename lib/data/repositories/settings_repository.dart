import '../db/database.dart';

/// App preferences, as strings under well-known keys.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const paletteKey = 'appearance.palette';
  static const resistorStyleKey = 'appearance.resistor_style';

  /// The chip the pinout explorer was last looking at. Kept because it is
  /// the one thing that section needs before it can show anything, and
  /// asking for it again on every launch is a chore, not a choice.
  static const pinoutSymbolKey = 'pinout.symbol';

  /// Which of the two board editors the PCB section uses.
  static const boardEditorKey = 'board.editor';
  static const wiringKey = 'schematic.wiring';

  /// Whether a schematic wire is drawn by dragging out of a pin or by
  /// tapping its pins and corners.
  static const wireGestureKey = 'schematic.wire_gesture';

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> set(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}
