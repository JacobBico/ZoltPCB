import 'package:drift/drift.dart';

import '../db/database.dart';

/// Per-project preferences, as strings under well-known keys — the project
/// counterpart of [SettingsRepository].
class ProjectSettingsRepository {
  ProjectSettingsRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, String>> getAll(String projectId) async {
    final rows = await (_db.select(
      _db.projectSettings,
    )..where((t) => t.projectId.equals(projectId))).get();
    return {for (final row in rows) row.key: row.value};
  }

  Stream<Map<String, String>> watchAll(String projectId) =>
      (_db.select(_db.projectSettings)
            ..where((t) => t.projectId.equals(projectId)))
          .watch()
          .map((rows) => {for (final row in rows) row.key: row.value});

  /// Writes every entry of [values]; a null value removes the key.
  Future<void> setAll(String projectId, Map<String, String?> values) async {
    await _db.transaction(() async {
      for (final entry in values.entries) {
        if (entry.value == null) {
          await (_db.delete(_db.projectSettings)..where(
                (t) => t.projectId.equals(projectId) & t.key.equals(entry.key),
              ))
              .go();
        } else {
          await _db
              .into(_db.projectSettings)
              .insertOnConflictUpdate(
                ProjectSettingsCompanion.insert(
                  projectId: projectId,
                  key: entry.key,
                  value: entry.value!,
                ),
              );
        }
      }
    });
  }
}
