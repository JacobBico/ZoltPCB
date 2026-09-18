import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../archive/project_archive.dart';
import '../db/database.dart';

/// A saved point in a project's history.
class ProjectSnapshot {
  const ProjectSnapshot({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdAt,
    this.automatic = false,
    this.partCount = 0,
    this.trackCount = 0,
  });

  final String id;
  final String projectId;
  final String name;
  final DateTime createdAt;

  /// Taken by the app, before a restore, rather than by the user.
  final bool automatic;

  /// A glance at what it holds, so two snapshots can be told apart.
  final int partCount;
  final int trackCount;
}

/// Named save points for a project — "before I rerouted the power section".
///
/// Undo covers the last few minutes; a snapshot covers the afternoon. Each
/// is a whole [ProjectArchive], so going back is the same restore a backup
/// file uses.
class SnapshotRepository {
  SnapshotRepository(this._db) : _archiver = ProjectArchiver(_db);

  final AppDatabase _db;
  final ProjectArchiver _archiver;

  Stream<List<ProjectSnapshot>> watch(String projectId) {
    final query = _db.select(_db.projectSnapshots)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toSnapshot).toList());
  }

  Future<List<ProjectSnapshot>> getAll(String projectId) async {
    final query = _db.select(_db.projectSnapshots)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return (await query.get()).map(_toSnapshot).toList();
  }

  /// Saves the project as it stands now.
  Future<ProjectSnapshot> take(
    String projectId,
    String name, {
    bool automatic = false,
  }) async {
    final archive = await _archiver.capture(projectId);
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.projectSnapshots)
        .insert(
          ProjectSnapshotsCompanion.insert(
            id: id,
            projectId: projectId,
            name: name.trim().isEmpty ? 'Snapshot' : name.trim(),
            automatic: Value(automatic),
            data: archive.encode(),
            createdAt: now,
          ),
        );
    return ProjectSnapshot(
      id: id,
      projectId: projectId,
      name: name,
      createdAt: now,
      automatic: automatic,
      partCount: archive.count('parts'),
      trackCount: archive.count('board_tracks'),
    );
  }

  /// Puts the project back the way the snapshot has it.
  ///
  /// The state being left is saved first, automatically, so a restore is
  /// never a one-way door: going back to "before the restore" is just
  /// another restore.
  Future<void> restore(String snapshotId) async {
    final row = await (_db.select(
      _db.projectSnapshots,
    )..where((t) => t.id.equals(snapshotId))).getSingle();
    await take(
      row.projectId,
      'Before restoring "${row.name}"',
      automatic: true,
    );
    await _archiver.restoreInPlace(
      row.projectId,
      ProjectArchive.decode(row.data),
    );
  }

  Future<void> rename(String snapshotId, String name) async {
    await (_db.update(_db.projectSnapshots)
          ..where((t) => t.id.equals(snapshotId)))
        .write(ProjectSnapshotsCompanion(name: Value(name.trim())));
  }

  Future<void> delete(String snapshotId) async {
    await (_db.delete(
      _db.projectSnapshots,
    )..where((t) => t.id.equals(snapshotId))).go();
  }

  ProjectSnapshot _toSnapshot(ProjectSnapshotRow row) {
    // Counting rows means reading the archive, but snapshots are few and
    // the list is only shown on demand.
    var parts = 0;
    var tracks = 0;
    try {
      final archive = ProjectArchive.decode(row.data);
      parts = archive.count('parts');
      tracks = archive.count('board_tracks');
    } catch (_) {}
    return ProjectSnapshot(
      id: row.id,
      projectId: row.projectId,
      name: row.name,
      createdAt: row.createdAt,
      automatic: row.automatic,
      partCount: parts,
      trackCount: tracks,
    );
  }
}
