import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import '../db/mappers.dart';

/// Create, read, update and delete for projects.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  /// All projects, most recently modified first.
  Stream<List<Project>> watchAll() {
    final query = _db.select(_db.projects)
      ..orderBy([(t) => OrderingTerm.desc(t.modifiedAt)]);
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  Future<List<Project>> getAll() async {
    final query = _db.select(_db.projects)
      ..orderBy([(t) => OrderingTerm.desc(t.modifiedAt)]);
    final rows = await query.get();
    return rows.map((r) => r.toDomain()).toList();
  }

  /// Projects with their part and net counts, for the project list.
  ///
  /// Counted in SQL rather than by loading each project's contents, so the
  /// list stays cheap as designs grow.
  Stream<List<ProjectSummary>> watchSummaries() {
    return _db
        .customSelect(
          'SELECT p.*, '
          '(SELECT COUNT(*) FROM parts WHERE parts.project_id = p.id) '
          'AS part_count, '
          '(SELECT COUNT(*) FROM nets WHERE nets.project_id = p.id) '
          'AS net_count '
          'FROM projects p ORDER BY p.modified_at DESC',
          readsFrom: {_db.projects, _db.parts, _db.nets},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ProjectSummary(
                  project: _db.projects.map(row.data).toDomain(),
                  partCount: row.read<int>('part_count'),
                  netCount: row.read<int>('net_count'),
                ),
              )
              .toList(),
        );
  }

  Future<Project?> getById(String id) async {
    final row = await (_db.select(
      _db.projects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  Stream<Project?> watchById(String id) {
    return (_db.select(_db.projects)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row?.toDomain());
  }

  Future<Project> create({
    required String name,
    String description = '',
    PaperSize paper = PaperSize.a4,
    String company = '',
    String revision = '',
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: newId(),
      name: name.trim(),
      description: description,
      createdAt: now,
      modifiedAt: now,
      paper: paper,
      company: company,
      revision: revision,
    );
    await _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: project.id,
            name: project.name,
            description: Value(project.description),
            paper: Value(project.paper),
            company: Value(project.company),
            revision: Value(project.revision),
            createdAt: project.createdAt,
            modifiedAt: project.modifiedAt,
          ),
        );
    return project;
  }

  Future<void> update(Project project) async {
    await (_db.update(
      _db.projects,
    )..where((t) => t.id.equals(project.id))).write(
      ProjectsCompanion(
        name: Value(project.name),
        description: Value(project.description),
        paper: Value(project.paper),
        company: Value(project.company),
        revision: Value(project.revision),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name.trim()),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Bumps `modifiedAt`. Called whenever a project's contents change so the
  /// project list stays ordered by real activity.
  Future<void> touch(String id) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(modifiedAt: Value(DateTime.now())),
    );
  }

  /// Deletes a project and, by cascade, its parts, pins and nets.
  Future<void> delete(String id) async {
    await (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
  }
}
