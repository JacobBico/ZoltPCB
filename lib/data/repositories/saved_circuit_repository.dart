import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';

/// A saved circuit, ready to insert.
class SavedCircuit {
  const SavedCircuit({
    required this.id,
    required this.name,
    required this.clip,
    required this.createdAt,
  });

  final String id;
  final String name;
  final CircuitClip clip;
  final DateTime createdAt;

  /// `LM1117 · 3 parts`, for the list.
  String get summary {
    final names = {for (final p in clip.parts) p.spec.value}.take(3);
    return '${clip.parts.length} part${clip.parts.length == 1 ? '' : 's'} · '
        '${names.join(', ')}';
  }
}

/// Circuits saved to reuse, across every project.
class SavedCircuitRepository {
  SavedCircuitRepository(this._db);

  final AppDatabase _db;

  Stream<List<SavedCircuit>> watch() {
    final query = _db.select(_db.savedCircuits)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch().map(
      (rows) => [for (final row in rows) ?_toCircuit(row)],
    );
  }

  Future<List<SavedCircuit>> getAll() async {
    final query = _db.select(_db.savedCircuits)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return [for (final row in await query.get()) ?_toCircuit(row)];
  }

  Future<SavedCircuit> save(String name, CircuitClip clip) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.savedCircuits)
        .insert(
          SavedCircuitsCompanion.insert(
            id: id,
            name: name.trim().isEmpty ? 'Circuit' : name.trim(),
            data: jsonEncode(CircuitClipJson.encode(clip)),
            createdAt: now,
          ),
        );
    return SavedCircuit(id: id, name: name, clip: clip, createdAt: now);
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.savedCircuits)..where((t) => t.id.equals(id))).write(
      SavedCircuitsCompanion(name: Value(name.trim())),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.savedCircuits)..where((t) => t.id.equals(id))).go();
  }

  /// A row that no longer reads is skipped rather than breaking the list.
  static SavedCircuit? _toCircuit(SavedCircuitRow row) {
    try {
      return SavedCircuit(
        id: row.id,
        name: row.name,
        clip: CircuitClipJson.decode(
          jsonDecode(row.data) as Map<String, Object?>,
        ),
        createdAt: row.createdAt,
      );
    } catch (_) {
      return null;
    }
  }
}
