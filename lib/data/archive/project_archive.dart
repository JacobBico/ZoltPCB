import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../db/database.dart';

/// A whole project as plain data: every row it owns, table by table.
///
/// One format behind three features. A backup file is an archive written to
/// disk; a snapshot is an archive kept in the database; restoring either is
/// the same insert. Rows are taken as SQL sees them — text, numbers and
/// nulls — rather than through the generated data classes, so the format
/// needs no code per table and survives columns being added: an archive
/// from an older version simply leaves the new columns at their defaults,
/// and one from a newer version has the columns this one does not know
/// dropped rather than refused.
class ProjectArchive {
  const ProjectArchive({
    required this.schemaVersion,
    required this.createdAt,
    required this.tables,
  });

  /// Identifies the file as one of ours before anything else is trusted.
  static const format = 'zolt-project';

  /// What backups said they were before the app was called Zolt. Still
  /// read, never written.
  static const legacyFormats = {'hintpcb-project'};

  /// Bumped only if the layout of this wrapper changes, not the tables.
  static const version = 1;

  /// The file extension a backup is saved with.
  static const extension = 'zolt';

  /// The database schema the rows were read from.
  final int schemaVersion;
  final DateTime createdAt;

  /// Rows by SQL table name, each a column-name to value map.
  final Map<String, List<Map<String, Object?>>> tables;

  /// The project row itself.
  Map<String, Object?> get project => tables['projects']!.single;

  String get projectName => project['name'] as String? ?? 'Project';

  int count(String table) => tables[table]?.length ?? 0;

  Map<String, Object?> toJson() => {
    'format': format,
    'version': version,
    'schema': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'tables': tables,
  };

  static ProjectArchive fromJson(Map<String, Object?> json) {
    final kind = json['format'];
    if (kind != format && !legacyFormats.contains(kind)) {
      throw const FormatException('Not a Zolt project backup');
    }
    final version = json['version'];
    if (version is! int || version > ProjectArchive.version) {
      throw const FormatException(
        'This backup was made by a newer version of Zolt',
      );
    }
    final raw = json['tables'];
    if (raw is! Map) throw const FormatException('The backup has no tables');
    final tables = <String, List<Map<String, Object?>>>{
      for (final entry in raw.entries)
        entry.key as String: [
          for (final row in entry.value as List)
            Map<String, Object?>.from(row as Map),
        ],
    };
    if ((tables['projects'] ?? const []).length != 1) {
      throw const FormatException('The backup does not hold one project');
    }
    return ProjectArchive(
      schemaVersion: json['schema'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      tables: tables,
    );
  }

  /// The archive as JSON text, for keeping in the database.
  String encode() => jsonEncode(toJson());

  static ProjectArchive decode(String text) =>
      fromJson(jsonDecode(text) as Map<String, Object?>);

  /// The archive as a backup file: gzipped JSON. A design is mostly
  /// repeated column names and UUIDs, which compress about tenfold.
  Uint8List toBytes() =>
      Uint8List.fromList(GZipEncoder().encodeBytes(utf8.encode(encode())));

  /// Reads a backup file, gzipped or not.
  static ProjectArchive fromBytes(List<int> bytes) {
    final isGzip = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final List<int> plain;
    try {
      plain = isGzip ? GZipDecoder().decodeBytes(bytes) : bytes;
    } catch (_) {
      throw const FormatException('The backup file is damaged');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw const FormatException('Not a Zolt project backup');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Not a Zolt project backup');
    }
    return fromJson(json);
  }
}

/// Reads a project out of the database into a [ProjectArchive], and writes
/// one back — as a new project, or over the one it came from.
class ProjectArchiver {
  ProjectArchiver(this._db);

  final AppDatabase _db;

  /// Every table a project owns, parents before children, so inserting in
  /// this order never trips a foreign key. Snapshots are deliberately not
  /// here: a snapshot holding the snapshots before it would grow without
  /// end, and a backup is of the design, not of its history.
  static const _tables = [
    'projects',
    'schematic_sheets',
    'parts',
    'part_units',
    'part_pins',
    'net_classes',
    'nets',
    'net_nodes',
    'schematic_wires',
    'net_route_hints',
    'schematic_notes',
    'project_settings',
    'boards',
    'board_footprints',
    'board_tracks',
    'board_vias',
    'board_edges',
    'board_zones',
    'board_texts',
    'board_images',
    'board_features',
    'board_dimensions',
  ];

  /// How each table is reached from the project id.
  static String _whereOwned(String table) => switch (table) {
    'projects' => 'id = ?1',
    'part_units' ||
    'part_pins' => 'part_id IN (SELECT id FROM parts WHERE project_id = ?1)',
    'net_nodes' => 'net_id IN (SELECT id FROM nets WHERE project_id = ?1)',
    _ => 'project_id = ?1',
  };

  Future<ProjectArchive> capture(String projectId) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = await _db
          .customSelect(
            'SELECT * FROM $table WHERE ${_whereOwned(table)}',
            variables: [Variable<String>(projectId)],
          )
          .get();
      tables[table] = [for (final row in rows) Map.of(row.data)];
    }
    if (tables['projects']!.isEmpty) {
      throw StateError('No project $projectId');
    }
    return ProjectArchive(
      schemaVersion: _db.schemaVersion,
      createdAt: DateTime.now(),
      tables: tables,
    );
  }

  /// Adds the archive to the database as a project of its own, with fresh
  /// ids throughout so it can sit beside the one it was taken from, and
  /// returns the new project's id.
  Future<String> restoreAsNew(ProjectArchive archive, {String? name}) async {
    _checkReadable(archive);
    // Every id in the archive gets a replacement, and every column that
    // refers to one follows it. Ids are UUIDs, so a value that happens to
    // match one is one.
    final remap = <String, String>{};
    for (final rows in archive.tables.values) {
      for (final row in rows) {
        final id = row['id'];
        if (id is String) remap.putIfAbsent(id, newId);
      }
    }

    final now = DateTime.now().toIso8601String();
    final projectId = remap[archive.project['id']]!;
    await _db.transaction(() async {
      for (final table in _tables) {
        for (final row
            in archive.tables[table] ?? const <Map<String, Object?>>[]) {
          final copy = {
            for (final entry in row.entries)
              entry.key: _isIdColumn(entry.key) && entry.value is String
                  ? remap[entry.value] ?? entry.value
                  : entry.value,
          };
          if (table == 'projects') {
            if (name != null) copy['name'] = name;
            copy['created_at'] = now;
            copy['modified_at'] = now;
          }
          await _insert(table, copy);
        }
      }
    });
    _markAllUpdated();
    return projectId;
  }

  /// Replaces a project's contents with the archive's, keeping the project
  /// itself — its id, and the snapshots hanging off it.
  ///
  /// The archive must have been taken from this project.
  Future<void> restoreInPlace(String projectId, ProjectArchive archive) async {
    if (archive.project['id'] != projectId) {
      throw ArgumentError('The archive belongs to another project');
    }
    _checkReadable(archive);
    await _db.transaction(() async {
      // Children first. Deleting parts and nets takes their units, pins and
      // memberships with them by cascade.
      for (final table in _tables.reversed) {
        if (table == 'projects') continue;
        await _db.customStatement(
          'DELETE FROM $table WHERE ${_whereOwned(table)}',
          [projectId],
        );
      }
      final columns = await _columns('projects');
      final project = {
        for (final entry in archive.project.entries)
          if (columns.contains(entry.key) &&
              entry.key != 'id' &&
              entry.key != 'created_at')
            entry.key: entry.value,
      }..['modified_at'] = DateTime.now().toIso8601String();
      if (project.isNotEmpty) {
        final sets = project.keys.map((c) => '$c = ?').join(', ');
        await _db.customStatement('UPDATE projects SET $sets WHERE id = ?', [
          ...project.values,
          projectId,
        ]);
      }
      for (final table in _tables.skip(1)) {
        for (final row
            in archive.tables[table] ?? const <Map<String, Object?>>[]) {
          await _insert(table, row);
        }
      }
    });
    _markAllUpdated();
  }

  /// Refuses an archive from a newer database than this one.
  ///
  /// Its rows may carry columns this version does not know, and dropping
  /// them is not harmless: a keepout from a newer version would come back
  /// as a copper pour, its flag silently lost. Better to say so.
  void _checkReadable(ProjectArchive archive) {
    if (archive.schemaVersion > _db.schemaVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Zolt. Update the app '
        'to open it.',
      );
    }
  }

  static bool _isIdColumn(String column) =>
      column == 'id' || column.endsWith('_id');

  final _columnCache = <String, Set<String>>{};

  Future<Set<String>> _columns(String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;
    final rows = await _db.customSelect('PRAGMA table_info($table)').get();
    return _columnCache[table] = {
      for (final row in rows) row.read<String>('name'),
    };
  }

  Future<void> _insert(String table, Map<String, Object?> row) async {
    final known = await _columns(table);
    final columns = [
      for (final column in row.keys)
        if (known.contains(column)) column,
    ];
    if (columns.isEmpty) return;
    await _db.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      [for (final column in columns) row[column]],
    );
  }

  /// Raw statements bypass drift's change tracking, so every stream
  /// watching a project table is told by hand.
  void _markAllUpdated() {
    final names = _tables.toSet();
    _db.markTablesUpdated([
      for (final table in _db.allTables)
        if (names.contains(table.actualTableName)) table,
    ]);
  }
}
