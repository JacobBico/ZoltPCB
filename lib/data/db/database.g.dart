// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PaperSize, String> paper =
      GeneratedColumn<String>(
        'paper',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('A4'),
      ).withConverter<PaperSize>($ProjectsTable.$converterpaper);
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    paper,
    company,
    revision,
    createdAt,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      paper: $ProjectsTable.$converterpaper.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}paper'],
        )!,
      ),
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static TypeConverter<PaperSize, String> $converterpaper =
      const PaperSizeConverter();
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final String id;
  final String name;
  final String description;
  final PaperSize paper;
  final String company;
  final String revision;
  final DateTime createdAt;
  final DateTime modifiedAt;
  const ProjectRow({
    required this.id,
    required this.name,
    required this.description,
    required this.paper,
    required this.company,
    required this.revision,
    required this.createdAt,
    required this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    {
      map['paper'] = Variable<String>(
        $ProjectsTable.$converterpaper.toSql(paper),
      );
    }
    map['company'] = Variable<String>(company);
    map['revision'] = Variable<String>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      paper: Value(paper),
      company: Value(company),
      revision: Value(revision),
      createdAt: Value(createdAt),
      modifiedAt: Value(modifiedAt),
    );
  }

  factory ProjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      paper: serializer.fromJson<PaperSize>(json['paper']),
      company: serializer.fromJson<String>(json['company']),
      revision: serializer.fromJson<String>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'paper': serializer.toJson<PaperSize>(paper),
      'company': serializer.toJson<String>(company),
      'revision': serializer.toJson<String>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
    };
  }

  ProjectRow copyWith({
    String? id,
    String? name,
    String? description,
    PaperSize? paper,
    String? company,
    String? revision,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) => ProjectRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    paper: paper ?? this.paper,
    company: company ?? this.company,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
  ProjectRow copyWithCompanion(ProjectsCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      paper: data.paper.present ? data.paper.value : this.paper,
      company: data.company.present ? data.company.value : this.company,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('paper: $paper, ')
          ..write('company: $company, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    paper,
    company,
    revision,
    createdAt,
    modifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.paper == this.paper &&
          other.company == this.company &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<PaperSize> paper;
  final Value<String> company;
  final Value<String> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> modifiedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.paper = const Value.absent(),
    this.company = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.paper = const Value.absent(),
    this.company = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime createdAt,
    required DateTime modifiedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       modifiedAt = Value(modifiedAt);
  static Insertable<ProjectRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? paper,
    Expression<String>? company,
    Expression<String>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (paper != null) 'paper': paper,
      if (company != null) 'company': company,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<PaperSize>? paper,
    Value<String>? company,
    Value<String>? revision,
    Value<DateTime>? createdAt,
    Value<DateTime>? modifiedAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      paper: paper ?? this.paper,
      company: company ?? this.company,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (paper.present) {
      map['paper'] = Variable<String>(
        $ProjectsTable.$converterpaper.toSql(paper.value),
      );
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('paper: $paper, ')
          ..write('company: $company, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartsTable extends Parts with TableInfo<$PartsTable, PartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _libIdMeta = const VerificationMeta('libId');
  @override
  late final GeneratedColumn<String> libId = GeneratedColumn<String>(
    'lib_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _footprintMeta = const VerificationMeta(
    'footprint',
  );
  @override
  late final GeneratedColumn<String> footprint = GeneratedColumn<String>(
    'footprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _datasheetMeta = const VerificationMeta(
    'datasheet',
  );
  @override
  late final GeneratedColumn<String> datasheet = GeneratedColumn<String>(
    'datasheet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _unitCountMeta = const VerificationMeta(
    'unitCount',
  );
  @override
  late final GeneratedColumn<int> unitCount = GeneratedColumn<int>(
    'unit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _inBomMeta = const VerificationMeta('inBom');
  @override
  late final GeneratedColumn<bool> inBom = GeneratedColumn<bool>(
    'in_bom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_bom" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _onBoardMeta = const VerificationMeta(
    'onBoard',
  );
  @override
  late final GeneratedColumn<bool> onBoard = GeneratedColumn<bool>(
    'on_board',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("on_board" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _dnpMeta = const VerificationMeta('dnp');
  @override
  late final GeneratedColumn<bool> dnp = GeneratedColumn<bool>(
    'dnp',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dnp" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fieldsHiddenMeta = const VerificationMeta(
    'fieldsHidden',
  );
  @override
  late final GeneratedColumn<bool> fieldsHidden = GeneratedColumn<bool>(
    'fields_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fields_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    libId,
    reference,
    value,
    footprint,
    datasheet,
    description,
    unitCount,
    inBom,
    onBoard,
    dnp,
    fieldsHidden,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('lib_id')) {
      context.handle(
        _libIdMeta,
        libId.isAcceptableOrUnknown(data['lib_id']!, _libIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libIdMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('footprint')) {
      context.handle(
        _footprintMeta,
        footprint.isAcceptableOrUnknown(data['footprint']!, _footprintMeta),
      );
    }
    if (data.containsKey('datasheet')) {
      context.handle(
        _datasheetMeta,
        datasheet.isAcceptableOrUnknown(data['datasheet']!, _datasheetMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('unit_count')) {
      context.handle(
        _unitCountMeta,
        unitCount.isAcceptableOrUnknown(data['unit_count']!, _unitCountMeta),
      );
    }
    if (data.containsKey('in_bom')) {
      context.handle(
        _inBomMeta,
        inBom.isAcceptableOrUnknown(data['in_bom']!, _inBomMeta),
      );
    }
    if (data.containsKey('on_board')) {
      context.handle(
        _onBoardMeta,
        onBoard.isAcceptableOrUnknown(data['on_board']!, _onBoardMeta),
      );
    }
    if (data.containsKey('dnp')) {
      context.handle(
        _dnpMeta,
        dnp.isAcceptableOrUnknown(data['dnp']!, _dnpMeta),
      );
    }
    if (data.containsKey('fields_hidden')) {
      context.handle(
        _fieldsHiddenMeta,
        fieldsHidden.isAcceptableOrUnknown(
          data['fields_hidden']!,
          _fieldsHiddenMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, reference},
  ];
  @override
  PartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      libId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lib_id'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      footprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}footprint'],
      )!,
      datasheet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datasheet'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      unitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_count'],
      )!,
      inBom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_bom'],
      )!,
      onBoard: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}on_board'],
      )!,
      dnp: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dnp'],
      )!,
      fieldsHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fields_hidden'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PartsTable createAlias(String alias) {
    return $PartsTable(attachedDatabase, alias);
  }
}

class PartRow extends DataClass implements Insertable<PartRow> {
  final String id;
  final String projectId;
  final String libId;
  final String reference;
  final String value;
  final String footprint;
  final String datasheet;
  final String description;
  final int unitCount;
  final bool inBom;
  final bool onBoard;
  final bool dnp;

  /// Whether the designator and value are drawn beside the symbol. Off for
  /// a part whose label is only in the way — a power symbol whose shape
  /// already says GND, a row of identical decoupling caps.
  final bool fieldsHidden;
  final DateTime createdAt;
  const PartRow({
    required this.id,
    required this.projectId,
    required this.libId,
    required this.reference,
    required this.value,
    required this.footprint,
    required this.datasheet,
    required this.description,
    required this.unitCount,
    required this.inBom,
    required this.onBoard,
    required this.dnp,
    required this.fieldsHidden,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['lib_id'] = Variable<String>(libId);
    map['reference'] = Variable<String>(reference);
    map['value'] = Variable<String>(value);
    map['footprint'] = Variable<String>(footprint);
    map['datasheet'] = Variable<String>(datasheet);
    map['description'] = Variable<String>(description);
    map['unit_count'] = Variable<int>(unitCount);
    map['in_bom'] = Variable<bool>(inBom);
    map['on_board'] = Variable<bool>(onBoard);
    map['dnp'] = Variable<bool>(dnp);
    map['fields_hidden'] = Variable<bool>(fieldsHidden);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PartsCompanion toCompanion(bool nullToAbsent) {
    return PartsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      libId: Value(libId),
      reference: Value(reference),
      value: Value(value),
      footprint: Value(footprint),
      datasheet: Value(datasheet),
      description: Value(description),
      unitCount: Value(unitCount),
      inBom: Value(inBom),
      onBoard: Value(onBoard),
      dnp: Value(dnp),
      fieldsHidden: Value(fieldsHidden),
      createdAt: Value(createdAt),
    );
  }

  factory PartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      libId: serializer.fromJson<String>(json['libId']),
      reference: serializer.fromJson<String>(json['reference']),
      value: serializer.fromJson<String>(json['value']),
      footprint: serializer.fromJson<String>(json['footprint']),
      datasheet: serializer.fromJson<String>(json['datasheet']),
      description: serializer.fromJson<String>(json['description']),
      unitCount: serializer.fromJson<int>(json['unitCount']),
      inBom: serializer.fromJson<bool>(json['inBom']),
      onBoard: serializer.fromJson<bool>(json['onBoard']),
      dnp: serializer.fromJson<bool>(json['dnp']),
      fieldsHidden: serializer.fromJson<bool>(json['fieldsHidden']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'libId': serializer.toJson<String>(libId),
      'reference': serializer.toJson<String>(reference),
      'value': serializer.toJson<String>(value),
      'footprint': serializer.toJson<String>(footprint),
      'datasheet': serializer.toJson<String>(datasheet),
      'description': serializer.toJson<String>(description),
      'unitCount': serializer.toJson<int>(unitCount),
      'inBom': serializer.toJson<bool>(inBom),
      'onBoard': serializer.toJson<bool>(onBoard),
      'dnp': serializer.toJson<bool>(dnp),
      'fieldsHidden': serializer.toJson<bool>(fieldsHidden),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PartRow copyWith({
    String? id,
    String? projectId,
    String? libId,
    String? reference,
    String? value,
    String? footprint,
    String? datasheet,
    String? description,
    int? unitCount,
    bool? inBom,
    bool? onBoard,
    bool? dnp,
    bool? fieldsHidden,
    DateTime? createdAt,
  }) => PartRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    libId: libId ?? this.libId,
    reference: reference ?? this.reference,
    value: value ?? this.value,
    footprint: footprint ?? this.footprint,
    datasheet: datasheet ?? this.datasheet,
    description: description ?? this.description,
    unitCount: unitCount ?? this.unitCount,
    inBom: inBom ?? this.inBom,
    onBoard: onBoard ?? this.onBoard,
    dnp: dnp ?? this.dnp,
    fieldsHidden: fieldsHidden ?? this.fieldsHidden,
    createdAt: createdAt ?? this.createdAt,
  );
  PartRow copyWithCompanion(PartsCompanion data) {
    return PartRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      libId: data.libId.present ? data.libId.value : this.libId,
      reference: data.reference.present ? data.reference.value : this.reference,
      value: data.value.present ? data.value.value : this.value,
      footprint: data.footprint.present ? data.footprint.value : this.footprint,
      datasheet: data.datasheet.present ? data.datasheet.value : this.datasheet,
      description: data.description.present
          ? data.description.value
          : this.description,
      unitCount: data.unitCount.present ? data.unitCount.value : this.unitCount,
      inBom: data.inBom.present ? data.inBom.value : this.inBom,
      onBoard: data.onBoard.present ? data.onBoard.value : this.onBoard,
      dnp: data.dnp.present ? data.dnp.value : this.dnp,
      fieldsHidden: data.fieldsHidden.present
          ? data.fieldsHidden.value
          : this.fieldsHidden,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('libId: $libId, ')
          ..write('reference: $reference, ')
          ..write('value: $value, ')
          ..write('footprint: $footprint, ')
          ..write('datasheet: $datasheet, ')
          ..write('description: $description, ')
          ..write('unitCount: $unitCount, ')
          ..write('inBom: $inBom, ')
          ..write('onBoard: $onBoard, ')
          ..write('dnp: $dnp, ')
          ..write('fieldsHidden: $fieldsHidden, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    libId,
    reference,
    value,
    footprint,
    datasheet,
    description,
    unitCount,
    inBom,
    onBoard,
    dnp,
    fieldsHidden,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.libId == this.libId &&
          other.reference == this.reference &&
          other.value == this.value &&
          other.footprint == this.footprint &&
          other.datasheet == this.datasheet &&
          other.description == this.description &&
          other.unitCount == this.unitCount &&
          other.inBom == this.inBom &&
          other.onBoard == this.onBoard &&
          other.dnp == this.dnp &&
          other.fieldsHidden == this.fieldsHidden &&
          other.createdAt == this.createdAt);
}

class PartsCompanion extends UpdateCompanion<PartRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> libId;
  final Value<String> reference;
  final Value<String> value;
  final Value<String> footprint;
  final Value<String> datasheet;
  final Value<String> description;
  final Value<int> unitCount;
  final Value<bool> inBom;
  final Value<bool> onBoard;
  final Value<bool> dnp;
  final Value<bool> fieldsHidden;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PartsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.libId = const Value.absent(),
    this.reference = const Value.absent(),
    this.value = const Value.absent(),
    this.footprint = const Value.absent(),
    this.datasheet = const Value.absent(),
    this.description = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.inBom = const Value.absent(),
    this.onBoard = const Value.absent(),
    this.dnp = const Value.absent(),
    this.fieldsHidden = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartsCompanion.insert({
    required String id,
    required String projectId,
    required String libId,
    required String reference,
    this.value = const Value.absent(),
    this.footprint = const Value.absent(),
    this.datasheet = const Value.absent(),
    this.description = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.inBom = const Value.absent(),
    this.onBoard = const Value.absent(),
    this.dnp = const Value.absent(),
    this.fieldsHidden = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       libId = Value(libId),
       reference = Value(reference),
       createdAt = Value(createdAt);
  static Insertable<PartRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? libId,
    Expression<String>? reference,
    Expression<String>? value,
    Expression<String>? footprint,
    Expression<String>? datasheet,
    Expression<String>? description,
    Expression<int>? unitCount,
    Expression<bool>? inBom,
    Expression<bool>? onBoard,
    Expression<bool>? dnp,
    Expression<bool>? fieldsHidden,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (libId != null) 'lib_id': libId,
      if (reference != null) 'reference': reference,
      if (value != null) 'value': value,
      if (footprint != null) 'footprint': footprint,
      if (datasheet != null) 'datasheet': datasheet,
      if (description != null) 'description': description,
      if (unitCount != null) 'unit_count': unitCount,
      if (inBom != null) 'in_bom': inBom,
      if (onBoard != null) 'on_board': onBoard,
      if (dnp != null) 'dnp': dnp,
      if (fieldsHidden != null) 'fields_hidden': fieldsHidden,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? libId,
    Value<String>? reference,
    Value<String>? value,
    Value<String>? footprint,
    Value<String>? datasheet,
    Value<String>? description,
    Value<int>? unitCount,
    Value<bool>? inBom,
    Value<bool>? onBoard,
    Value<bool>? dnp,
    Value<bool>? fieldsHidden,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PartsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      libId: libId ?? this.libId,
      reference: reference ?? this.reference,
      value: value ?? this.value,
      footprint: footprint ?? this.footprint,
      datasheet: datasheet ?? this.datasheet,
      description: description ?? this.description,
      unitCount: unitCount ?? this.unitCount,
      inBom: inBom ?? this.inBom,
      onBoard: onBoard ?? this.onBoard,
      dnp: dnp ?? this.dnp,
      fieldsHidden: fieldsHidden ?? this.fieldsHidden,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (libId.present) {
      map['lib_id'] = Variable<String>(libId.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (footprint.present) {
      map['footprint'] = Variable<String>(footprint.value);
    }
    if (datasheet.present) {
      map['datasheet'] = Variable<String>(datasheet.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (unitCount.present) {
      map['unit_count'] = Variable<int>(unitCount.value);
    }
    if (inBom.present) {
      map['in_bom'] = Variable<bool>(inBom.value);
    }
    if (onBoard.present) {
      map['on_board'] = Variable<bool>(onBoard.value);
    }
    if (dnp.present) {
      map['dnp'] = Variable<bool>(dnp.value);
    }
    if (fieldsHidden.present) {
      map['fields_hidden'] = Variable<bool>(fieldsHidden.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('libId: $libId, ')
          ..write('reference: $reference, ')
          ..write('value: $value, ')
          ..write('footprint: $footprint, ')
          ..write('datasheet: $datasheet, ')
          ..write('description: $description, ')
          ..write('unitCount: $unitCount, ')
          ..write('inBom: $inBom, ')
          ..write('onBoard: $onBoard, ')
          ..write('dnp: $dnp, ')
          ..write('fieldsHidden: $fieldsHidden, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartUnitsTable extends PartUnits
    with TableInfo<$PartUnitsTable, PartUnitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartUnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _unitNumberMeta = const VerificationMeta(
    'unitNumber',
  );
  @override
  late final GeneratedColumn<int> unitNumber = GeneratedColumn<int>(
    'unit_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyStyleMeta = const VerificationMeta(
    'bodyStyle',
  );
  @override
  late final GeneratedColumn<int> bodyStyle = GeneratedColumn<int>(
    'body_style',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<int> rotation = GeneratedColumn<int>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mirrorXMeta = const VerificationMeta(
    'mirrorX',
  );
  @override
  late final GeneratedColumn<bool> mirrorX = GeneratedColumn<bool>(
    'mirror_x',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mirror_x" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mirrorYMeta = const VerificationMeta(
    'mirrorY',
  );
  @override
  late final GeneratedColumn<bool> mirrorY = GeneratedColumn<bool>(
    'mirror_y',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mirror_y" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _placedMeta = const VerificationMeta('placed');
  @override
  late final GeneratedColumn<bool> placed = GeneratedColumn<bool>(
    'placed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("placed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partId,
    unitNumber,
    bodyStyle,
    x,
    y,
    rotation,
    mirrorX,
    mirrorY,
    placed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'part_units';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartUnitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('unit_number')) {
      context.handle(
        _unitNumberMeta,
        unitNumber.isAcceptableOrUnknown(data['unit_number']!, _unitNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_unitNumberMeta);
    }
    if (data.containsKey('body_style')) {
      context.handle(
        _bodyStyleMeta,
        bodyStyle.isAcceptableOrUnknown(data['body_style']!, _bodyStyleMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('mirror_x')) {
      context.handle(
        _mirrorXMeta,
        mirrorX.isAcceptableOrUnknown(data['mirror_x']!, _mirrorXMeta),
      );
    }
    if (data.containsKey('mirror_y')) {
      context.handle(
        _mirrorYMeta,
        mirrorY.isAcceptableOrUnknown(data['mirror_y']!, _mirrorYMeta),
      );
    }
    if (data.containsKey('placed')) {
      context.handle(
        _placedMeta,
        placed.isAcceptableOrUnknown(data['placed']!, _placedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {partId, unitNumber},
  ];
  @override
  PartUnitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartUnitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      unitNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_number'],
      )!,
      bodyStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}body_style'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotation'],
      )!,
      mirrorX: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mirror_x'],
      )!,
      mirrorY: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mirror_y'],
      )!,
      placed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}placed'],
      )!,
    );
  }

  @override
  $PartUnitsTable createAlias(String alias) {
    return $PartUnitsTable(attachedDatabase, alias);
  }
}

class PartUnitRow extends DataClass implements Insertable<PartUnitRow> {
  final String id;
  final String partId;
  final int unitNumber;
  final int bodyStyle;
  final double x;
  final double y;
  final int rotation;
  final bool mirrorX;
  final bool mirrorY;
  final bool placed;
  const PartUnitRow({
    required this.id,
    required this.partId,
    required this.unitNumber,
    required this.bodyStyle,
    required this.x,
    required this.y,
    required this.rotation,
    required this.mirrorX,
    required this.mirrorY,
    required this.placed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['part_id'] = Variable<String>(partId);
    map['unit_number'] = Variable<int>(unitNumber);
    map['body_style'] = Variable<int>(bodyStyle);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['rotation'] = Variable<int>(rotation);
    map['mirror_x'] = Variable<bool>(mirrorX);
    map['mirror_y'] = Variable<bool>(mirrorY);
    map['placed'] = Variable<bool>(placed);
    return map;
  }

  PartUnitsCompanion toCompanion(bool nullToAbsent) {
    return PartUnitsCompanion(
      id: Value(id),
      partId: Value(partId),
      unitNumber: Value(unitNumber),
      bodyStyle: Value(bodyStyle),
      x: Value(x),
      y: Value(y),
      rotation: Value(rotation),
      mirrorX: Value(mirrorX),
      mirrorY: Value(mirrorY),
      placed: Value(placed),
    );
  }

  factory PartUnitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartUnitRow(
      id: serializer.fromJson<String>(json['id']),
      partId: serializer.fromJson<String>(json['partId']),
      unitNumber: serializer.fromJson<int>(json['unitNumber']),
      bodyStyle: serializer.fromJson<int>(json['bodyStyle']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      rotation: serializer.fromJson<int>(json['rotation']),
      mirrorX: serializer.fromJson<bool>(json['mirrorX']),
      mirrorY: serializer.fromJson<bool>(json['mirrorY']),
      placed: serializer.fromJson<bool>(json['placed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'partId': serializer.toJson<String>(partId),
      'unitNumber': serializer.toJson<int>(unitNumber),
      'bodyStyle': serializer.toJson<int>(bodyStyle),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'rotation': serializer.toJson<int>(rotation),
      'mirrorX': serializer.toJson<bool>(mirrorX),
      'mirrorY': serializer.toJson<bool>(mirrorY),
      'placed': serializer.toJson<bool>(placed),
    };
  }

  PartUnitRow copyWith({
    String? id,
    String? partId,
    int? unitNumber,
    int? bodyStyle,
    double? x,
    double? y,
    int? rotation,
    bool? mirrorX,
    bool? mirrorY,
    bool? placed,
  }) => PartUnitRow(
    id: id ?? this.id,
    partId: partId ?? this.partId,
    unitNumber: unitNumber ?? this.unitNumber,
    bodyStyle: bodyStyle ?? this.bodyStyle,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    mirrorX: mirrorX ?? this.mirrorX,
    mirrorY: mirrorY ?? this.mirrorY,
    placed: placed ?? this.placed,
  );
  PartUnitRow copyWithCompanion(PartUnitsCompanion data) {
    return PartUnitRow(
      id: data.id.present ? data.id.value : this.id,
      partId: data.partId.present ? data.partId.value : this.partId,
      unitNumber: data.unitNumber.present
          ? data.unitNumber.value
          : this.unitNumber,
      bodyStyle: data.bodyStyle.present ? data.bodyStyle.value : this.bodyStyle,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      mirrorX: data.mirrorX.present ? data.mirrorX.value : this.mirrorX,
      mirrorY: data.mirrorY.present ? data.mirrorY.value : this.mirrorY,
      placed: data.placed.present ? data.placed.value : this.placed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartUnitRow(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('unitNumber: $unitNumber, ')
          ..write('bodyStyle: $bodyStyle, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('mirrorX: $mirrorX, ')
          ..write('mirrorY: $mirrorY, ')
          ..write('placed: $placed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partId,
    unitNumber,
    bodyStyle,
    x,
    y,
    rotation,
    mirrorX,
    mirrorY,
    placed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartUnitRow &&
          other.id == this.id &&
          other.partId == this.partId &&
          other.unitNumber == this.unitNumber &&
          other.bodyStyle == this.bodyStyle &&
          other.x == this.x &&
          other.y == this.y &&
          other.rotation == this.rotation &&
          other.mirrorX == this.mirrorX &&
          other.mirrorY == this.mirrorY &&
          other.placed == this.placed);
}

class PartUnitsCompanion extends UpdateCompanion<PartUnitRow> {
  final Value<String> id;
  final Value<String> partId;
  final Value<int> unitNumber;
  final Value<int> bodyStyle;
  final Value<double> x;
  final Value<double> y;
  final Value<int> rotation;
  final Value<bool> mirrorX;
  final Value<bool> mirrorY;
  final Value<bool> placed;
  final Value<int> rowid;
  const PartUnitsCompanion({
    this.id = const Value.absent(),
    this.partId = const Value.absent(),
    this.unitNumber = const Value.absent(),
    this.bodyStyle = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.mirrorX = const Value.absent(),
    this.mirrorY = const Value.absent(),
    this.placed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartUnitsCompanion.insert({
    required String id,
    required String partId,
    required int unitNumber,
    this.bodyStyle = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.mirrorX = const Value.absent(),
    this.mirrorY = const Value.absent(),
    this.placed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partId = Value(partId),
       unitNumber = Value(unitNumber);
  static Insertable<PartUnitRow> custom({
    Expression<String>? id,
    Expression<String>? partId,
    Expression<int>? unitNumber,
    Expression<int>? bodyStyle,
    Expression<double>? x,
    Expression<double>? y,
    Expression<int>? rotation,
    Expression<bool>? mirrorX,
    Expression<bool>? mirrorY,
    Expression<bool>? placed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partId != null) 'part_id': partId,
      if (unitNumber != null) 'unit_number': unitNumber,
      if (bodyStyle != null) 'body_style': bodyStyle,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (rotation != null) 'rotation': rotation,
      if (mirrorX != null) 'mirror_x': mirrorX,
      if (mirrorY != null) 'mirror_y': mirrorY,
      if (placed != null) 'placed': placed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartUnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? partId,
    Value<int>? unitNumber,
    Value<int>? bodyStyle,
    Value<double>? x,
    Value<double>? y,
    Value<int>? rotation,
    Value<bool>? mirrorX,
    Value<bool>? mirrorY,
    Value<bool>? placed,
    Value<int>? rowid,
  }) {
    return PartUnitsCompanion(
      id: id ?? this.id,
      partId: partId ?? this.partId,
      unitNumber: unitNumber ?? this.unitNumber,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      mirrorX: mirrorX ?? this.mirrorX,
      mirrorY: mirrorY ?? this.mirrorY,
      placed: placed ?? this.placed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (unitNumber.present) {
      map['unit_number'] = Variable<int>(unitNumber.value);
    }
    if (bodyStyle.present) {
      map['body_style'] = Variable<int>(bodyStyle.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<int>(rotation.value);
    }
    if (mirrorX.present) {
      map['mirror_x'] = Variable<bool>(mirrorX.value);
    }
    if (mirrorY.present) {
      map['mirror_y'] = Variable<bool>(mirrorY.value);
    }
    if (placed.present) {
      map['placed'] = Variable<bool>(placed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartUnitsCompanion(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('unitNumber: $unitNumber, ')
          ..write('bodyStyle: $bodyStyle, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('mirrorX: $mirrorX, ')
          ..write('mirrorY: $mirrorY, ')
          ..write('placed: $placed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartPinsTable extends PartPins
    with TableInfo<$PartPinsTable, PartPinRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartPinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<int> unit = GeneratedColumn<int>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _bodyStyleMeta = const VerificationMeta(
    'bodyStyle',
  );
  @override
  late final GeneratedColumn<int> bodyStyle = GeneratedColumn<int>(
    'body_style',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('~'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PinElectricalType, String>
  electricalType = GeneratedColumn<String>(
    'electrical_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PinElectricalType>($PartPinsTable.$converterelectricalType);
  @override
  late final GeneratedColumnWithTypeConverter<PinGraphicStyle, String>
  graphicStyle = GeneratedColumn<String>(
    'graphic_style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('line'),
  ).withConverter<PinGraphicStyle>($PartPinsTable.$convertergraphicStyle);
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<double> length = GeneratedColumn<double>(
    'length',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.54),
  );
  static const VerificationMeta _angleMeta = const VerificationMeta('angle');
  @override
  late final GeneratedColumn<int> angle = GeneratedColumn<int>(
    'angle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noConnectMeta = const VerificationMeta(
    'noConnect',
  );
  @override
  late final GeneratedColumn<bool> noConnect = GeneratedColumn<bool>(
    'no_connect',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("no_connect" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partId,
    unit,
    bodyStyle,
    number,
    name,
    electricalType,
    graphicStyle,
    x,
    y,
    length,
    angle,
    noConnect,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'part_pins';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartPinRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('body_style')) {
      context.handle(
        _bodyStyleMeta,
        bodyStyle.isAcceptableOrUnknown(data['body_style']!, _bodyStyleMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    }
    if (data.containsKey('angle')) {
      context.handle(
        _angleMeta,
        angle.isAcceptableOrUnknown(data['angle']!, _angleMeta),
      );
    }
    if (data.containsKey('no_connect')) {
      context.handle(
        _noConnectMeta,
        noConnect.isAcceptableOrUnknown(data['no_connect']!, _noConnectMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartPinRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartPinRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit'],
      )!,
      bodyStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}body_style'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      electricalType: $PartPinsTable.$converterelectricalType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}electrical_type'],
        )!,
      ),
      graphicStyle: $PartPinsTable.$convertergraphicStyle.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}graphic_style'],
        )!,
      ),
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length'],
      )!,
      angle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}angle'],
      )!,
      noConnect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}no_connect'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $PartPinsTable createAlias(String alias) {
    return $PartPinsTable(attachedDatabase, alias);
  }

  static TypeConverter<PinElectricalType, String> $converterelectricalType =
      const PinElectricalTypeConverter();
  static TypeConverter<PinGraphicStyle, String> $convertergraphicStyle =
      const PinGraphicStyleConverter();
}

class PartPinRow extends DataClass implements Insertable<PartPinRow> {
  final String id;
  final String partId;

  /// `0` means the pin is common to every unit of the package.
  final int unit;
  final int bodyStyle;
  final String number;
  final String name;
  final PinElectricalType electricalType;
  final PinGraphicStyle graphicStyle;
  final double x;
  final double y;
  final double length;
  final int angle;
  final bool noConnect;
  final bool hidden;
  const PartPinRow({
    required this.id,
    required this.partId,
    required this.unit,
    required this.bodyStyle,
    required this.number,
    required this.name,
    required this.electricalType,
    required this.graphicStyle,
    required this.x,
    required this.y,
    required this.length,
    required this.angle,
    required this.noConnect,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['part_id'] = Variable<String>(partId);
    map['unit'] = Variable<int>(unit);
    map['body_style'] = Variable<int>(bodyStyle);
    map['number'] = Variable<String>(number);
    map['name'] = Variable<String>(name);
    {
      map['electrical_type'] = Variable<String>(
        $PartPinsTable.$converterelectricalType.toSql(electricalType),
      );
    }
    {
      map['graphic_style'] = Variable<String>(
        $PartPinsTable.$convertergraphicStyle.toSql(graphicStyle),
      );
    }
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['length'] = Variable<double>(length);
    map['angle'] = Variable<int>(angle);
    map['no_connect'] = Variable<bool>(noConnect);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  PartPinsCompanion toCompanion(bool nullToAbsent) {
    return PartPinsCompanion(
      id: Value(id),
      partId: Value(partId),
      unit: Value(unit),
      bodyStyle: Value(bodyStyle),
      number: Value(number),
      name: Value(name),
      electricalType: Value(electricalType),
      graphicStyle: Value(graphicStyle),
      x: Value(x),
      y: Value(y),
      length: Value(length),
      angle: Value(angle),
      noConnect: Value(noConnect),
      hidden: Value(hidden),
    );
  }

  factory PartPinRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartPinRow(
      id: serializer.fromJson<String>(json['id']),
      partId: serializer.fromJson<String>(json['partId']),
      unit: serializer.fromJson<int>(json['unit']),
      bodyStyle: serializer.fromJson<int>(json['bodyStyle']),
      number: serializer.fromJson<String>(json['number']),
      name: serializer.fromJson<String>(json['name']),
      electricalType: serializer.fromJson<PinElectricalType>(
        json['electricalType'],
      ),
      graphicStyle: serializer.fromJson<PinGraphicStyle>(json['graphicStyle']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      length: serializer.fromJson<double>(json['length']),
      angle: serializer.fromJson<int>(json['angle']),
      noConnect: serializer.fromJson<bool>(json['noConnect']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'partId': serializer.toJson<String>(partId),
      'unit': serializer.toJson<int>(unit),
      'bodyStyle': serializer.toJson<int>(bodyStyle),
      'number': serializer.toJson<String>(number),
      'name': serializer.toJson<String>(name),
      'electricalType': serializer.toJson<PinElectricalType>(electricalType),
      'graphicStyle': serializer.toJson<PinGraphicStyle>(graphicStyle),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'length': serializer.toJson<double>(length),
      'angle': serializer.toJson<int>(angle),
      'noConnect': serializer.toJson<bool>(noConnect),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  PartPinRow copyWith({
    String? id,
    String? partId,
    int? unit,
    int? bodyStyle,
    String? number,
    String? name,
    PinElectricalType? electricalType,
    PinGraphicStyle? graphicStyle,
    double? x,
    double? y,
    double? length,
    int? angle,
    bool? noConnect,
    bool? hidden,
  }) => PartPinRow(
    id: id ?? this.id,
    partId: partId ?? this.partId,
    unit: unit ?? this.unit,
    bodyStyle: bodyStyle ?? this.bodyStyle,
    number: number ?? this.number,
    name: name ?? this.name,
    electricalType: electricalType ?? this.electricalType,
    graphicStyle: graphicStyle ?? this.graphicStyle,
    x: x ?? this.x,
    y: y ?? this.y,
    length: length ?? this.length,
    angle: angle ?? this.angle,
    noConnect: noConnect ?? this.noConnect,
    hidden: hidden ?? this.hidden,
  );
  PartPinRow copyWithCompanion(PartPinsCompanion data) {
    return PartPinRow(
      id: data.id.present ? data.id.value : this.id,
      partId: data.partId.present ? data.partId.value : this.partId,
      unit: data.unit.present ? data.unit.value : this.unit,
      bodyStyle: data.bodyStyle.present ? data.bodyStyle.value : this.bodyStyle,
      number: data.number.present ? data.number.value : this.number,
      name: data.name.present ? data.name.value : this.name,
      electricalType: data.electricalType.present
          ? data.electricalType.value
          : this.electricalType,
      graphicStyle: data.graphicStyle.present
          ? data.graphicStyle.value
          : this.graphicStyle,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      length: data.length.present ? data.length.value : this.length,
      angle: data.angle.present ? data.angle.value : this.angle,
      noConnect: data.noConnect.present ? data.noConnect.value : this.noConnect,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartPinRow(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('unit: $unit, ')
          ..write('bodyStyle: $bodyStyle, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('electricalType: $electricalType, ')
          ..write('graphicStyle: $graphicStyle, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('length: $length, ')
          ..write('angle: $angle, ')
          ..write('noConnect: $noConnect, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partId,
    unit,
    bodyStyle,
    number,
    name,
    electricalType,
    graphicStyle,
    x,
    y,
    length,
    angle,
    noConnect,
    hidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartPinRow &&
          other.id == this.id &&
          other.partId == this.partId &&
          other.unit == this.unit &&
          other.bodyStyle == this.bodyStyle &&
          other.number == this.number &&
          other.name == this.name &&
          other.electricalType == this.electricalType &&
          other.graphicStyle == this.graphicStyle &&
          other.x == this.x &&
          other.y == this.y &&
          other.length == this.length &&
          other.angle == this.angle &&
          other.noConnect == this.noConnect &&
          other.hidden == this.hidden);
}

class PartPinsCompanion extends UpdateCompanion<PartPinRow> {
  final Value<String> id;
  final Value<String> partId;
  final Value<int> unit;
  final Value<int> bodyStyle;
  final Value<String> number;
  final Value<String> name;
  final Value<PinElectricalType> electricalType;
  final Value<PinGraphicStyle> graphicStyle;
  final Value<double> x;
  final Value<double> y;
  final Value<double> length;
  final Value<int> angle;
  final Value<bool> noConnect;
  final Value<bool> hidden;
  final Value<int> rowid;
  const PartPinsCompanion({
    this.id = const Value.absent(),
    this.partId = const Value.absent(),
    this.unit = const Value.absent(),
    this.bodyStyle = const Value.absent(),
    this.number = const Value.absent(),
    this.name = const Value.absent(),
    this.electricalType = const Value.absent(),
    this.graphicStyle = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.length = const Value.absent(),
    this.angle = const Value.absent(),
    this.noConnect = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartPinsCompanion.insert({
    required String id,
    required String partId,
    this.unit = const Value.absent(),
    this.bodyStyle = const Value.absent(),
    required String number,
    this.name = const Value.absent(),
    required PinElectricalType electricalType,
    this.graphicStyle = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.length = const Value.absent(),
    this.angle = const Value.absent(),
    this.noConnect = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partId = Value(partId),
       number = Value(number),
       electricalType = Value(electricalType);
  static Insertable<PartPinRow> custom({
    Expression<String>? id,
    Expression<String>? partId,
    Expression<int>? unit,
    Expression<int>? bodyStyle,
    Expression<String>? number,
    Expression<String>? name,
    Expression<String>? electricalType,
    Expression<String>? graphicStyle,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? length,
    Expression<int>? angle,
    Expression<bool>? noConnect,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partId != null) 'part_id': partId,
      if (unit != null) 'unit': unit,
      if (bodyStyle != null) 'body_style': bodyStyle,
      if (number != null) 'number': number,
      if (name != null) 'name': name,
      if (electricalType != null) 'electrical_type': electricalType,
      if (graphicStyle != null) 'graphic_style': graphicStyle,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (length != null) 'length': length,
      if (angle != null) 'angle': angle,
      if (noConnect != null) 'no_connect': noConnect,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartPinsCompanion copyWith({
    Value<String>? id,
    Value<String>? partId,
    Value<int>? unit,
    Value<int>? bodyStyle,
    Value<String>? number,
    Value<String>? name,
    Value<PinElectricalType>? electricalType,
    Value<PinGraphicStyle>? graphicStyle,
    Value<double>? x,
    Value<double>? y,
    Value<double>? length,
    Value<int>? angle,
    Value<bool>? noConnect,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return PartPinsCompanion(
      id: id ?? this.id,
      partId: partId ?? this.partId,
      unit: unit ?? this.unit,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      number: number ?? this.number,
      name: name ?? this.name,
      electricalType: electricalType ?? this.electricalType,
      graphicStyle: graphicStyle ?? this.graphicStyle,
      x: x ?? this.x,
      y: y ?? this.y,
      length: length ?? this.length,
      angle: angle ?? this.angle,
      noConnect: noConnect ?? this.noConnect,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (unit.present) {
      map['unit'] = Variable<int>(unit.value);
    }
    if (bodyStyle.present) {
      map['body_style'] = Variable<int>(bodyStyle.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (electricalType.present) {
      map['electrical_type'] = Variable<String>(
        $PartPinsTable.$converterelectricalType.toSql(electricalType.value),
      );
    }
    if (graphicStyle.present) {
      map['graphic_style'] = Variable<String>(
        $PartPinsTable.$convertergraphicStyle.toSql(graphicStyle.value),
      );
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (length.present) {
      map['length'] = Variable<double>(length.value);
    }
    if (angle.present) {
      map['angle'] = Variable<int>(angle.value);
    }
    if (noConnect.present) {
      map['no_connect'] = Variable<bool>(noConnect.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartPinsCompanion(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('unit: $unit, ')
          ..write('bodyStyle: $bodyStyle, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('electricalType: $electricalType, ')
          ..write('graphicStyle: $graphicStyle, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('length: $length, ')
          ..write('angle: $angle, ')
          ..write('noConnect: $noConnect, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NetClassesTable extends NetClasses
    with TableInfo<$NetClassesTable, NetClassRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NetClassesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackWidthMeta = const VerificationMeta(
    'trackWidth',
  );
  @override
  late final GeneratedColumn<double> trackWidth = GeneratedColumn<double>(
    'track_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clearanceMeta = const VerificationMeta(
    'clearance',
  );
  @override
  late final GeneratedColumn<double> clearance = GeneratedColumn<double>(
    'clearance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _impedanceMeta = const VerificationMeta(
    'impedance',
  );
  @override
  late final GeneratedColumn<double> impedance = GeneratedColumn<double>(
    'impedance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    trackWidth,
    clearance,
    impedance,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'net_classes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NetClassRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('track_width')) {
      context.handle(
        _trackWidthMeta,
        trackWidth.isAcceptableOrUnknown(data['track_width']!, _trackWidthMeta),
      );
    } else if (isInserting) {
      context.missing(_trackWidthMeta);
    }
    if (data.containsKey('clearance')) {
      context.handle(
        _clearanceMeta,
        clearance.isAcceptableOrUnknown(data['clearance']!, _clearanceMeta),
      );
    }
    if (data.containsKey('impedance')) {
      context.handle(
        _impedanceMeta,
        impedance.isAcceptableOrUnknown(data['impedance']!, _impedanceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NetClassRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NetClassRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      trackWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}track_width'],
      )!,
      clearance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}clearance'],
      ),
      impedance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}impedance'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NetClassesTable createAlias(String alias) {
    return $NetClassesTable(attachedDatabase, alias);
  }
}

class NetClassRow extends DataClass implements Insertable<NetClassRow> {
  final String id;
  final String projectId;
  final String name;
  final double trackWidth;

  /// Null uses the board's design rule.
  final double? clearance;

  /// The characteristic impedance this class is routed to, in ohms. When
  /// set, a track's width comes from the stackup of the layer it is drawn
  /// on rather than from [trackWidth], which is then only the fallback.
  final double? impedance;
  final DateTime createdAt;
  const NetClassRow({
    required this.id,
    required this.projectId,
    required this.name,
    required this.trackWidth,
    this.clearance,
    this.impedance,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['track_width'] = Variable<double>(trackWidth);
    if (!nullToAbsent || clearance != null) {
      map['clearance'] = Variable<double>(clearance);
    }
    if (!nullToAbsent || impedance != null) {
      map['impedance'] = Variable<double>(impedance);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NetClassesCompanion toCompanion(bool nullToAbsent) {
    return NetClassesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      trackWidth: Value(trackWidth),
      clearance: clearance == null && nullToAbsent
          ? const Value.absent()
          : Value(clearance),
      impedance: impedance == null && nullToAbsent
          ? const Value.absent()
          : Value(impedance),
      createdAt: Value(createdAt),
    );
  }

  factory NetClassRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NetClassRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      trackWidth: serializer.fromJson<double>(json['trackWidth']),
      clearance: serializer.fromJson<double?>(json['clearance']),
      impedance: serializer.fromJson<double?>(json['impedance']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'trackWidth': serializer.toJson<double>(trackWidth),
      'clearance': serializer.toJson<double?>(clearance),
      'impedance': serializer.toJson<double?>(impedance),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NetClassRow copyWith({
    String? id,
    String? projectId,
    String? name,
    double? trackWidth,
    Value<double?> clearance = const Value.absent(),
    Value<double?> impedance = const Value.absent(),
    DateTime? createdAt,
  }) => NetClassRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearance.present ? clearance.value : this.clearance,
    impedance: impedance.present ? impedance.value : this.impedance,
    createdAt: createdAt ?? this.createdAt,
  );
  NetClassRow copyWithCompanion(NetClassesCompanion data) {
    return NetClassRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      trackWidth: data.trackWidth.present
          ? data.trackWidth.value
          : this.trackWidth,
      clearance: data.clearance.present ? data.clearance.value : this.clearance,
      impedance: data.impedance.present ? data.impedance.value : this.impedance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NetClassRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('trackWidth: $trackWidth, ')
          ..write('clearance: $clearance, ')
          ..write('impedance: $impedance, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    name,
    trackWidth,
    clearance,
    impedance,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetClassRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.trackWidth == this.trackWidth &&
          other.clearance == this.clearance &&
          other.impedance == this.impedance &&
          other.createdAt == this.createdAt);
}

class NetClassesCompanion extends UpdateCompanion<NetClassRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<double> trackWidth;
  final Value<double?> clearance;
  final Value<double?> impedance;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NetClassesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.trackWidth = const Value.absent(),
    this.clearance = const Value.absent(),
    this.impedance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NetClassesCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    required double trackWidth,
    this.clearance = const Value.absent(),
    this.impedance = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       name = Value(name),
       trackWidth = Value(trackWidth),
       createdAt = Value(createdAt);
  static Insertable<NetClassRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<double>? trackWidth,
    Expression<double>? clearance,
    Expression<double>? impedance,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (trackWidth != null) 'track_width': trackWidth,
      if (clearance != null) 'clearance': clearance,
      if (impedance != null) 'impedance': impedance,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NetClassesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? name,
    Value<double>? trackWidth,
    Value<double?>? clearance,
    Value<double?>? impedance,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NetClassesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      trackWidth: trackWidth ?? this.trackWidth,
      clearance: clearance ?? this.clearance,
      impedance: impedance ?? this.impedance,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (trackWidth.present) {
      map['track_width'] = Variable<double>(trackWidth.value);
    }
    if (clearance.present) {
      map['clearance'] = Variable<double>(clearance.value);
    }
    if (impedance.present) {
      map['impedance'] = Variable<double>(impedance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NetClassesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('trackWidth: $trackWidth, ')
          ..write('clearance: $clearance, ')
          ..write('impedance: $impedance, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NetsTable extends Nets with TableInfo<$NetsTable, NetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelXMeta = const VerificationMeta('labelX');
  @override
  late final GeneratedColumn<double> labelX = GeneratedColumn<double>(
    'label_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelYMeta = const VerificationMeta('labelY');
  @override
  late final GeneratedColumn<double> labelY = GeneratedColumn<double>(
    'label_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _netClassIdMeta = const VerificationMeta(
    'netClassId',
  );
  @override
  late final GeneratedColumn<String> netClassId = GeneratedColumn<String>(
    'net_class_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES net_classes (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    labelX,
    labelY,
    netClassId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nets';
  @override
  VerificationContext validateIntegrity(
    Insertable<NetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('label_x')) {
      context.handle(
        _labelXMeta,
        labelX.isAcceptableOrUnknown(data['label_x']!, _labelXMeta),
      );
    }
    if (data.containsKey('label_y')) {
      context.handle(
        _labelYMeta,
        labelY.isAcceptableOrUnknown(data['label_y']!, _labelYMeta),
      );
    }
    if (data.containsKey('net_class_id')) {
      context.handle(
        _netClassIdMeta,
        netClassId.isAcceptableOrUnknown(
          data['net_class_id']!,
          _netClassIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      labelX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_x'],
      ),
      labelY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_y'],
      ),
      netClassId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_class_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NetsTable createAlias(String alias) {
    return $NetsTable(attachedDatabase, alias);
  }
}

class NetRow extends DataClass implements Insertable<NetRow> {
  final String id;
  final String projectId;

  /// User-assigned label; null for an anonymous net.
  final String? name;

  /// Where the net's label sits on the sheet, in millimetres, once the user
  /// has dragged it. Null means "wherever the drawing puts it" — on the
  /// corner of the net's own wire, which is where it reads best.
  final double? labelX;
  final double? labelY;

  /// The net class the board routes this net with; null for the default.
  final String? netClassId;
  final DateTime createdAt;
  const NetRow({
    required this.id,
    required this.projectId,
    this.name,
    this.labelX,
    this.labelY,
    this.netClassId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || labelX != null) {
      map['label_x'] = Variable<double>(labelX);
    }
    if (!nullToAbsent || labelY != null) {
      map['label_y'] = Variable<double>(labelY);
    }
    if (!nullToAbsent || netClassId != null) {
      map['net_class_id'] = Variable<String>(netClassId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NetsCompanion toCompanion(bool nullToAbsent) {
    return NetsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      labelX: labelX == null && nullToAbsent
          ? const Value.absent()
          : Value(labelX),
      labelY: labelY == null && nullToAbsent
          ? const Value.absent()
          : Value(labelY),
      netClassId: netClassId == null && nullToAbsent
          ? const Value.absent()
          : Value(netClassId),
      createdAt: Value(createdAt),
    );
  }

  factory NetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NetRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String?>(json['name']),
      labelX: serializer.fromJson<double?>(json['labelX']),
      labelY: serializer.fromJson<double?>(json['labelY']),
      netClassId: serializer.fromJson<String?>(json['netClassId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String?>(name),
      'labelX': serializer.toJson<double?>(labelX),
      'labelY': serializer.toJson<double?>(labelY),
      'netClassId': serializer.toJson<String?>(netClassId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NetRow copyWith({
    String? id,
    String? projectId,
    Value<String?> name = const Value.absent(),
    Value<double?> labelX = const Value.absent(),
    Value<double?> labelY = const Value.absent(),
    Value<String?> netClassId = const Value.absent(),
    DateTime? createdAt,
  }) => NetRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name.present ? name.value : this.name,
    labelX: labelX.present ? labelX.value : this.labelX,
    labelY: labelY.present ? labelY.value : this.labelY,
    netClassId: netClassId.present ? netClassId.value : this.netClassId,
    createdAt: createdAt ?? this.createdAt,
  );
  NetRow copyWithCompanion(NetsCompanion data) {
    return NetRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      labelX: data.labelX.present ? data.labelX.value : this.labelX,
      labelY: data.labelY.present ? data.labelY.value : this.labelY,
      netClassId: data.netClassId.present
          ? data.netClassId.value
          : this.netClassId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NetRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('labelX: $labelX, ')
          ..write('labelY: $labelY, ')
          ..write('netClassId: $netClassId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, name, labelX, labelY, netClassId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.labelX == this.labelX &&
          other.labelY == this.labelY &&
          other.netClassId == this.netClassId &&
          other.createdAt == this.createdAt);
}

class NetsCompanion extends UpdateCompanion<NetRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> name;
  final Value<double?> labelX;
  final Value<double?> labelY;
  final Value<String?> netClassId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NetsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.labelX = const Value.absent(),
    this.labelY = const Value.absent(),
    this.netClassId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NetsCompanion.insert({
    required String id,
    required String projectId,
    this.name = const Value.absent(),
    this.labelX = const Value.absent(),
    this.labelY = const Value.absent(),
    this.netClassId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       createdAt = Value(createdAt);
  static Insertable<NetRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<double>? labelX,
    Expression<double>? labelY,
    Expression<String>? netClassId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (labelX != null) 'label_x': labelX,
      if (labelY != null) 'label_y': labelY,
      if (netClassId != null) 'net_class_id': netClassId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NetsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? name,
    Value<double?>? labelX,
    Value<double?>? labelY,
    Value<String?>? netClassId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NetsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      labelX: labelX ?? this.labelX,
      labelY: labelY ?? this.labelY,
      netClassId: netClassId ?? this.netClassId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (labelX.present) {
      map['label_x'] = Variable<double>(labelX.value);
    }
    if (labelY.present) {
      map['label_y'] = Variable<double>(labelY.value);
    }
    if (netClassId.present) {
      map['net_class_id'] = Variable<String>(netClassId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NetsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('labelX: $labelX, ')
          ..write('labelY: $labelY, ')
          ..write('netClassId: $netClassId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NetNodesTable extends NetNodes
    with TableInfo<$NetNodesTable, NetNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NetNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _netIdMeta = const VerificationMeta('netId');
  @override
  late final GeneratedColumn<String> netId = GeneratedColumn<String>(
    'net_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partPinIdMeta = const VerificationMeta(
    'partPinId',
  );
  @override
  late final GeneratedColumn<String> partPinId = GeneratedColumn<String>(
    'part_pin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES part_pins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelledMeta = const VerificationMeta(
    'labelled',
  );
  @override
  late final GeneratedColumn<bool> labelled = GeneratedColumn<bool>(
    'labelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("labelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    netId,
    partPinId,
    labelled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'net_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NetNodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('net_id')) {
      context.handle(
        _netIdMeta,
        netId.isAcceptableOrUnknown(data['net_id']!, _netIdMeta),
      );
    } else if (isInserting) {
      context.missing(_netIdMeta);
    }
    if (data.containsKey('part_pin_id')) {
      context.handle(
        _partPinIdMeta,
        partPinId.isAcceptableOrUnknown(data['part_pin_id']!, _partPinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partPinIdMeta);
    }
    if (data.containsKey('labelled')) {
      context.handle(
        _labelledMeta,
        labelled.isAcceptableOrUnknown(data['labelled']!, _labelledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {partPinId},
  ];
  @override
  NetNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NetNodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      netId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_id'],
      )!,
      partPinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_pin_id'],
      )!,
      labelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}labelled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NetNodesTable createAlias(String alias) {
    return $NetNodesTable(attachedDatabase, alias);
  }
}

class NetNodeRow extends DataClass implements Insertable<NetNodeRow> {
  final String id;
  final String netId;
  final String partPinId;

  /// The pin carries a label of its own — it is on this net by name, the
  /// way a KiCad label at a pin puts it there, rather than by a wire. The
  /// sheet then shows the name at the pin instead of routing a wire to
  /// the rest of the net.
  final bool labelled;
  final DateTime createdAt;
  const NetNodeRow({
    required this.id,
    required this.netId,
    required this.partPinId,
    required this.labelled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['net_id'] = Variable<String>(netId);
    map['part_pin_id'] = Variable<String>(partPinId);
    map['labelled'] = Variable<bool>(labelled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NetNodesCompanion toCompanion(bool nullToAbsent) {
    return NetNodesCompanion(
      id: Value(id),
      netId: Value(netId),
      partPinId: Value(partPinId),
      labelled: Value(labelled),
      createdAt: Value(createdAt),
    );
  }

  factory NetNodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NetNodeRow(
      id: serializer.fromJson<String>(json['id']),
      netId: serializer.fromJson<String>(json['netId']),
      partPinId: serializer.fromJson<String>(json['partPinId']),
      labelled: serializer.fromJson<bool>(json['labelled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'netId': serializer.toJson<String>(netId),
      'partPinId': serializer.toJson<String>(partPinId),
      'labelled': serializer.toJson<bool>(labelled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NetNodeRow copyWith({
    String? id,
    String? netId,
    String? partPinId,
    bool? labelled,
    DateTime? createdAt,
  }) => NetNodeRow(
    id: id ?? this.id,
    netId: netId ?? this.netId,
    partPinId: partPinId ?? this.partPinId,
    labelled: labelled ?? this.labelled,
    createdAt: createdAt ?? this.createdAt,
  );
  NetNodeRow copyWithCompanion(NetNodesCompanion data) {
    return NetNodeRow(
      id: data.id.present ? data.id.value : this.id,
      netId: data.netId.present ? data.netId.value : this.netId,
      partPinId: data.partPinId.present ? data.partPinId.value : this.partPinId,
      labelled: data.labelled.present ? data.labelled.value : this.labelled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NetNodeRow(')
          ..write('id: $id, ')
          ..write('netId: $netId, ')
          ..write('partPinId: $partPinId, ')
          ..write('labelled: $labelled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, netId, partPinId, labelled, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetNodeRow &&
          other.id == this.id &&
          other.netId == this.netId &&
          other.partPinId == this.partPinId &&
          other.labelled == this.labelled &&
          other.createdAt == this.createdAt);
}

class NetNodesCompanion extends UpdateCompanion<NetNodeRow> {
  final Value<String> id;
  final Value<String> netId;
  final Value<String> partPinId;
  final Value<bool> labelled;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NetNodesCompanion({
    this.id = const Value.absent(),
    this.netId = const Value.absent(),
    this.partPinId = const Value.absent(),
    this.labelled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NetNodesCompanion.insert({
    required String id,
    required String netId,
    required String partPinId,
    this.labelled = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       netId = Value(netId),
       partPinId = Value(partPinId),
       createdAt = Value(createdAt);
  static Insertable<NetNodeRow> custom({
    Expression<String>? id,
    Expression<String>? netId,
    Expression<String>? partPinId,
    Expression<bool>? labelled,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (netId != null) 'net_id': netId,
      if (partPinId != null) 'part_pin_id': partPinId,
      if (labelled != null) 'labelled': labelled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NetNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? netId,
    Value<String>? partPinId,
    Value<bool>? labelled,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NetNodesCompanion(
      id: id ?? this.id,
      netId: netId ?? this.netId,
      partPinId: partPinId ?? this.partPinId,
      labelled: labelled ?? this.labelled,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (netId.present) {
      map['net_id'] = Variable<String>(netId.value);
    }
    if (partPinId.present) {
      map['part_pin_id'] = Variable<String>(partPinId.value);
    }
    if (labelled.present) {
      map['labelled'] = Variable<bool>(labelled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NetNodesCompanion(')
          ..write('id: $id, ')
          ..write('netId: $netId, ')
          ..write('partPinId: $partPinId, ')
          ..write('labelled: $labelled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchematicWiresTable extends SchematicWires
    with TableInfo<$SchematicWiresTable, SchematicWireRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchematicWiresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _netIdMeta = const VerificationMeta('netId');
  @override
  late final GeneratedColumn<String> netId = GeneratedColumn<String>(
    'net_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pinAIdMeta = const VerificationMeta('pinAId');
  @override
  late final GeneratedColumn<String> pinAId = GeneratedColumn<String>(
    'pin_a_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES part_pins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pinBIdMeta = const VerificationMeta('pinBId');
  @override
  late final GeneratedColumn<String> pinBId = GeneratedColumn<String>(
    'pin_b_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES part_pins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<String> points = GeneratedColumn<String>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    netId,
    pinAId,
    pinBId,
    points,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schematic_wires';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchematicWireRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('net_id')) {
      context.handle(
        _netIdMeta,
        netId.isAcceptableOrUnknown(data['net_id']!, _netIdMeta),
      );
    } else if (isInserting) {
      context.missing(_netIdMeta);
    }
    if (data.containsKey('pin_a_id')) {
      context.handle(
        _pinAIdMeta,
        pinAId.isAcceptableOrUnknown(data['pin_a_id']!, _pinAIdMeta),
      );
    }
    if (data.containsKey('pin_b_id')) {
      context.handle(
        _pinBIdMeta,
        pinBId.isAcceptableOrUnknown(data['pin_b_id']!, _pinBIdMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SchematicWireRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchematicWireRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      netId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_id'],
      )!,
      pinAId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_a_id'],
      ),
      pinBId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_b_id'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SchematicWiresTable createAlias(String alias) {
    return $SchematicWiresTable(attachedDatabase, alias);
  }
}

class SchematicWireRow extends DataClass
    implements Insertable<SchematicWireRow> {
  final String id;
  final String projectId;
  final String netId;
  final String? pinAId;
  final String? pinBId;

  /// Corners in sheet millimetres, `x,y;x,y;…`, from the A end to the B end.
  final String points;
  final DateTime createdAt;
  const SchematicWireRow({
    required this.id,
    required this.projectId,
    required this.netId,
    this.pinAId,
    this.pinBId,
    required this.points,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['net_id'] = Variable<String>(netId);
    if (!nullToAbsent || pinAId != null) {
      map['pin_a_id'] = Variable<String>(pinAId);
    }
    if (!nullToAbsent || pinBId != null) {
      map['pin_b_id'] = Variable<String>(pinBId);
    }
    map['points'] = Variable<String>(points);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SchematicWiresCompanion toCompanion(bool nullToAbsent) {
    return SchematicWiresCompanion(
      id: Value(id),
      projectId: Value(projectId),
      netId: Value(netId),
      pinAId: pinAId == null && nullToAbsent
          ? const Value.absent()
          : Value(pinAId),
      pinBId: pinBId == null && nullToAbsent
          ? const Value.absent()
          : Value(pinBId),
      points: Value(points),
      createdAt: Value(createdAt),
    );
  }

  factory SchematicWireRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchematicWireRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      netId: serializer.fromJson<String>(json['netId']),
      pinAId: serializer.fromJson<String?>(json['pinAId']),
      pinBId: serializer.fromJson<String?>(json['pinBId']),
      points: serializer.fromJson<String>(json['points']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'netId': serializer.toJson<String>(netId),
      'pinAId': serializer.toJson<String?>(pinAId),
      'pinBId': serializer.toJson<String?>(pinBId),
      'points': serializer.toJson<String>(points),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SchematicWireRow copyWith({
    String? id,
    String? projectId,
    String? netId,
    Value<String?> pinAId = const Value.absent(),
    Value<String?> pinBId = const Value.absent(),
    String? points,
    DateTime? createdAt,
  }) => SchematicWireRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    netId: netId ?? this.netId,
    pinAId: pinAId.present ? pinAId.value : this.pinAId,
    pinBId: pinBId.present ? pinBId.value : this.pinBId,
    points: points ?? this.points,
    createdAt: createdAt ?? this.createdAt,
  );
  SchematicWireRow copyWithCompanion(SchematicWiresCompanion data) {
    return SchematicWireRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      netId: data.netId.present ? data.netId.value : this.netId,
      pinAId: data.pinAId.present ? data.pinAId.value : this.pinAId,
      pinBId: data.pinBId.present ? data.pinBId.value : this.pinBId,
      points: data.points.present ? data.points.value : this.points,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchematicWireRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('pinAId: $pinAId, ')
          ..write('pinBId: $pinBId, ')
          ..write('points: $points, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, netId, pinAId, pinBId, points, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchematicWireRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.netId == this.netId &&
          other.pinAId == this.pinAId &&
          other.pinBId == this.pinBId &&
          other.points == this.points &&
          other.createdAt == this.createdAt);
}

class SchematicWiresCompanion extends UpdateCompanion<SchematicWireRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> netId;
  final Value<String?> pinAId;
  final Value<String?> pinBId;
  final Value<String> points;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SchematicWiresCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.netId = const Value.absent(),
    this.pinAId = const Value.absent(),
    this.pinBId = const Value.absent(),
    this.points = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchematicWiresCompanion.insert({
    required String id,
    required String projectId,
    required String netId,
    this.pinAId = const Value.absent(),
    this.pinBId = const Value.absent(),
    required String points,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       netId = Value(netId),
       points = Value(points),
       createdAt = Value(createdAt);
  static Insertable<SchematicWireRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? netId,
    Expression<String>? pinAId,
    Expression<String>? pinBId,
    Expression<String>? points,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (netId != null) 'net_id': netId,
      if (pinAId != null) 'pin_a_id': pinAId,
      if (pinBId != null) 'pin_b_id': pinBId,
      if (points != null) 'points': points,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchematicWiresCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? netId,
    Value<String?>? pinAId,
    Value<String?>? pinBId,
    Value<String>? points,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SchematicWiresCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      netId: netId ?? this.netId,
      pinAId: pinAId ?? this.pinAId,
      pinBId: pinBId ?? this.pinBId,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (netId.present) {
      map['net_id'] = Variable<String>(netId.value);
    }
    if (pinAId.present) {
      map['pin_a_id'] = Variable<String>(pinAId.value);
    }
    if (pinBId.present) {
      map['pin_b_id'] = Variable<String>(pinBId.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(points.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchematicWiresCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('pinAId: $pinAId, ')
          ..write('pinBId: $pinBId, ')
          ..write('points: $points, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SymbolLibrariesTable extends SymbolLibraries
    with TableInfo<$SymbolLibrariesTable, SymbolLibraryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SymbolLibrariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _generatorMeta = const VerificationMeta(
    'generator',
  );
  @override
  late final GeneratedColumn<String> generator = GeneratedColumn<String>(
    'generator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _symbolCountMeta = const VerificationMeta(
    'symbolCount',
  );
  @override
  late final GeneratedColumn<int> symbolCount = GeneratedColumn<int>(
    'symbol_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nickname,
    fileName,
    formatVersion,
    generator,
    symbolCount,
    byteSize,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'symbol_libraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SymbolLibraryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    }
    if (data.containsKey('generator')) {
      context.handle(
        _generatorMeta,
        generator.isAcceptableOrUnknown(data['generator']!, _generatorMeta),
      );
    }
    if (data.containsKey('symbol_count')) {
      context.handle(
        _symbolCountMeta,
        symbolCount.isAcceptableOrUnknown(
          data['symbol_count']!,
          _symbolCountMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {nickname},
  ];
  @override
  SymbolLibraryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SymbolLibraryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      generator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generator'],
      )!,
      symbolCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}symbol_count'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $SymbolLibrariesTable createAlias(String alias) {
    return $SymbolLibrariesTable(attachedDatabase, alias);
  }
}

class SymbolLibraryRow extends DataClass
    implements Insertable<SymbolLibraryRow> {
  final String id;

  /// Library nickname, e.g. `Device`. Unique, because it forms the first
  /// half of every `lib_id` the library produces and a schematic cannot
  /// resolve two libraries with the same nickname.
  final String nickname;
  final String fileName;
  final int formatVersion;
  final String generator;
  final int symbolCount;
  final int byteSize;
  final DateTime importedAt;
  const SymbolLibraryRow({
    required this.id,
    required this.nickname,
    required this.fileName,
    required this.formatVersion,
    required this.generator,
    required this.symbolCount,
    required this.byteSize,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nickname'] = Variable<String>(nickname);
    map['file_name'] = Variable<String>(fileName);
    map['format_version'] = Variable<int>(formatVersion);
    map['generator'] = Variable<String>(generator);
    map['symbol_count'] = Variable<int>(symbolCount);
    map['byte_size'] = Variable<int>(byteSize);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  SymbolLibrariesCompanion toCompanion(bool nullToAbsent) {
    return SymbolLibrariesCompanion(
      id: Value(id),
      nickname: Value(nickname),
      fileName: Value(fileName),
      formatVersion: Value(formatVersion),
      generator: Value(generator),
      symbolCount: Value(symbolCount),
      byteSize: Value(byteSize),
      importedAt: Value(importedAt),
    );
  }

  factory SymbolLibraryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SymbolLibraryRow(
      id: serializer.fromJson<String>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      fileName: serializer.fromJson<String>(json['fileName']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      generator: serializer.fromJson<String>(json['generator']),
      symbolCount: serializer.fromJson<int>(json['symbolCount']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nickname': serializer.toJson<String>(nickname),
      'fileName': serializer.toJson<String>(fileName),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'generator': serializer.toJson<String>(generator),
      'symbolCount': serializer.toJson<int>(symbolCount),
      'byteSize': serializer.toJson<int>(byteSize),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  SymbolLibraryRow copyWith({
    String? id,
    String? nickname,
    String? fileName,
    int? formatVersion,
    String? generator,
    int? symbolCount,
    int? byteSize,
    DateTime? importedAt,
  }) => SymbolLibraryRow(
    id: id ?? this.id,
    nickname: nickname ?? this.nickname,
    fileName: fileName ?? this.fileName,
    formatVersion: formatVersion ?? this.formatVersion,
    generator: generator ?? this.generator,
    symbolCount: symbolCount ?? this.symbolCount,
    byteSize: byteSize ?? this.byteSize,
    importedAt: importedAt ?? this.importedAt,
  );
  SymbolLibraryRow copyWithCompanion(SymbolLibrariesCompanion data) {
    return SymbolLibraryRow(
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      generator: data.generator.present ? data.generator.value : this.generator,
      symbolCount: data.symbolCount.present
          ? data.symbolCount.value
          : this.symbolCount,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SymbolLibraryRow(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('fileName: $fileName, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('generator: $generator, ')
          ..write('symbolCount: $symbolCount, ')
          ..write('byteSize: $byteSize, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nickname,
    fileName,
    formatVersion,
    generator,
    symbolCount,
    byteSize,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymbolLibraryRow &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.fileName == this.fileName &&
          other.formatVersion == this.formatVersion &&
          other.generator == this.generator &&
          other.symbolCount == this.symbolCount &&
          other.byteSize == this.byteSize &&
          other.importedAt == this.importedAt);
}

class SymbolLibrariesCompanion extends UpdateCompanion<SymbolLibraryRow> {
  final Value<String> id;
  final Value<String> nickname;
  final Value<String> fileName;
  final Value<int> formatVersion;
  final Value<String> generator;
  final Value<int> symbolCount;
  final Value<int> byteSize;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const SymbolLibrariesCompanion({
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.fileName = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.generator = const Value.absent(),
    this.symbolCount = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SymbolLibrariesCompanion.insert({
    required String id,
    required String nickname,
    required String fileName,
    this.formatVersion = const Value.absent(),
    this.generator = const Value.absent(),
    this.symbolCount = const Value.absent(),
    this.byteSize = const Value.absent(),
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nickname = Value(nickname),
       fileName = Value(fileName),
       importedAt = Value(importedAt);
  static Insertable<SymbolLibraryRow> custom({
    Expression<String>? id,
    Expression<String>? nickname,
    Expression<String>? fileName,
    Expression<int>? formatVersion,
    Expression<String>? generator,
    Expression<int>? symbolCount,
    Expression<int>? byteSize,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (fileName != null) 'file_name': fileName,
      if (formatVersion != null) 'format_version': formatVersion,
      if (generator != null) 'generator': generator,
      if (symbolCount != null) 'symbol_count': symbolCount,
      if (byteSize != null) 'byte_size': byteSize,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SymbolLibrariesCompanion copyWith({
    Value<String>? id,
    Value<String>? nickname,
    Value<String>? fileName,
    Value<int>? formatVersion,
    Value<String>? generator,
    Value<int>? symbolCount,
    Value<int>? byteSize,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return SymbolLibrariesCompanion(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      fileName: fileName ?? this.fileName,
      formatVersion: formatVersion ?? this.formatVersion,
      generator: generator ?? this.generator,
      symbolCount: symbolCount ?? this.symbolCount,
      byteSize: byteSize ?? this.byteSize,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (generator.present) {
      map['generator'] = Variable<String>(generator.value);
    }
    if (symbolCount.present) {
      map['symbol_count'] = Variable<int>(symbolCount.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SymbolLibrariesCompanion(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('fileName: $fileName, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('generator: $generator, ')
          ..write('symbolCount: $symbolCount, ')
          ..write('byteSize: $byteSize, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SymbolIndexEntriesTable extends SymbolIndexEntries
    with TableInfo<$SymbolIndexEntriesTable, SymbolIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SymbolIndexEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES symbol_libraries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _libraryNicknameMeta = const VerificationMeta(
    'libraryNickname',
  );
  @override
  late final GeneratedColumn<String> libraryNickname = GeneratedColumn<String>(
    'library_nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _keywordsMeta = const VerificationMeta(
    'keywords',
  );
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
    'keywords',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _referencePrefixMeta = const VerificationMeta(
    'referencePrefix',
  );
  @override
  late final GeneratedColumn<String> referencePrefix = GeneratedColumn<String>(
    'reference_prefix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('U'),
  );
  static const VerificationMeta _defaultFootprintMeta = const VerificationMeta(
    'defaultFootprint',
  );
  @override
  late final GeneratedColumn<String> defaultFootprint = GeneratedColumn<String>(
    'default_footprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _datasheetMeta = const VerificationMeta(
    'datasheet',
  );
  @override
  late final GeneratedColumn<String> datasheet = GeneratedColumn<String>(
    'datasheet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _footprintFiltersMeta = const VerificationMeta(
    'footprintFilters',
  );
  @override
  late final GeneratedColumn<String> footprintFilters = GeneratedColumn<String>(
    'footprint_filters',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _unitCountMeta = const VerificationMeta(
    'unitCount',
  );
  @override
  late final GeneratedColumn<int> unitCount = GeneratedColumn<int>(
    'unit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _pinCountMeta = const VerificationMeta(
    'pinCount',
  );
  @override
  late final GeneratedColumn<int> pinCount = GeneratedColumn<int>(
    'pin_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPowerMeta = const VerificationMeta(
    'isPower',
  );
  @override
  late final GeneratedColumn<bool> isPower = GeneratedColumn<bool>(
    'is_power',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_power" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _extendsSymbolMeta = const VerificationMeta(
    'extendsSymbol',
  );
  @override
  late final GeneratedColumn<String> extendsSymbol = GeneratedColumn<String>(
    'extends_symbol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spanStartMeta = const VerificationMeta(
    'spanStart',
  );
  @override
  late final GeneratedColumn<int> spanStart = GeneratedColumn<int>(
    'span_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _spanEndMeta = const VerificationMeta(
    'spanEnd',
  );
  @override
  late final GeneratedColumn<int> spanEnd = GeneratedColumn<int>(
    'span_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    libraryNickname,
    name,
    description,
    keywords,
    referencePrefix,
    defaultFootprint,
    datasheet,
    footprintFilters,
    unitCount,
    pinCount,
    isPower,
    extendsSymbol,
    spanStart,
    spanEnd,
    searchText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'symbol_index_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SymbolIndexRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('library_nickname')) {
      context.handle(
        _libraryNicknameMeta,
        libraryNickname.isAcceptableOrUnknown(
          data['library_nickname']!,
          _libraryNicknameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_libraryNicknameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('keywords')) {
      context.handle(
        _keywordsMeta,
        keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta),
      );
    }
    if (data.containsKey('reference_prefix')) {
      context.handle(
        _referencePrefixMeta,
        referencePrefix.isAcceptableOrUnknown(
          data['reference_prefix']!,
          _referencePrefixMeta,
        ),
      );
    }
    if (data.containsKey('default_footprint')) {
      context.handle(
        _defaultFootprintMeta,
        defaultFootprint.isAcceptableOrUnknown(
          data['default_footprint']!,
          _defaultFootprintMeta,
        ),
      );
    }
    if (data.containsKey('datasheet')) {
      context.handle(
        _datasheetMeta,
        datasheet.isAcceptableOrUnknown(data['datasheet']!, _datasheetMeta),
      );
    }
    if (data.containsKey('footprint_filters')) {
      context.handle(
        _footprintFiltersMeta,
        footprintFilters.isAcceptableOrUnknown(
          data['footprint_filters']!,
          _footprintFiltersMeta,
        ),
      );
    }
    if (data.containsKey('unit_count')) {
      context.handle(
        _unitCountMeta,
        unitCount.isAcceptableOrUnknown(data['unit_count']!, _unitCountMeta),
      );
    }
    if (data.containsKey('pin_count')) {
      context.handle(
        _pinCountMeta,
        pinCount.isAcceptableOrUnknown(data['pin_count']!, _pinCountMeta),
      );
    }
    if (data.containsKey('is_power')) {
      context.handle(
        _isPowerMeta,
        isPower.isAcceptableOrUnknown(data['is_power']!, _isPowerMeta),
      );
    }
    if (data.containsKey('extends_symbol')) {
      context.handle(
        _extendsSymbolMeta,
        extendsSymbol.isAcceptableOrUnknown(
          data['extends_symbol']!,
          _extendsSymbolMeta,
        ),
      );
    }
    if (data.containsKey('span_start')) {
      context.handle(
        _spanStartMeta,
        spanStart.isAcceptableOrUnknown(data['span_start']!, _spanStartMeta),
      );
    }
    if (data.containsKey('span_end')) {
      context.handle(
        _spanEndMeta,
        spanEnd.isAcceptableOrUnknown(data['span_end']!, _spanEndMeta),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SymbolIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SymbolIndexRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      libraryNickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_nickname'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      keywords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords'],
      )!,
      referencePrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_prefix'],
      )!,
      defaultFootprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_footprint'],
      )!,
      datasheet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datasheet'],
      )!,
      footprintFilters: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}footprint_filters'],
      )!,
      unitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_count'],
      )!,
      pinCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_count'],
      )!,
      isPower: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_power'],
      )!,
      extendsSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extends_symbol'],
      ),
      spanStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_start'],
      )!,
      spanEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_end'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
    );
  }

  @override
  $SymbolIndexEntriesTable createAlias(String alias) {
    return $SymbolIndexEntriesTable(attachedDatabase, alias);
  }
}

class SymbolIndexRow extends DataClass implements Insertable<SymbolIndexRow> {
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
  final int spanStart;
  final int spanEnd;

  /// Lower-cased name, description and keywords concatenated, so search is
  /// one LIKE against one column rather than three.
  final String searchText;
  const SymbolIndexRow({
    required this.id,
    required this.libraryId,
    required this.libraryNickname,
    required this.name,
    required this.description,
    required this.keywords,
    required this.referencePrefix,
    required this.defaultFootprint,
    required this.datasheet,
    required this.footprintFilters,
    required this.unitCount,
    required this.pinCount,
    required this.isPower,
    this.extendsSymbol,
    required this.spanStart,
    required this.spanEnd,
    required this.searchText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['library_nickname'] = Variable<String>(libraryNickname);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['keywords'] = Variable<String>(keywords);
    map['reference_prefix'] = Variable<String>(referencePrefix);
    map['default_footprint'] = Variable<String>(defaultFootprint);
    map['datasheet'] = Variable<String>(datasheet);
    map['footprint_filters'] = Variable<String>(footprintFilters);
    map['unit_count'] = Variable<int>(unitCount);
    map['pin_count'] = Variable<int>(pinCount);
    map['is_power'] = Variable<bool>(isPower);
    if (!nullToAbsent || extendsSymbol != null) {
      map['extends_symbol'] = Variable<String>(extendsSymbol);
    }
    map['span_start'] = Variable<int>(spanStart);
    map['span_end'] = Variable<int>(spanEnd);
    map['search_text'] = Variable<String>(searchText);
    return map;
  }

  SymbolIndexEntriesCompanion toCompanion(bool nullToAbsent) {
    return SymbolIndexEntriesCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      libraryNickname: Value(libraryNickname),
      name: Value(name),
      description: Value(description),
      keywords: Value(keywords),
      referencePrefix: Value(referencePrefix),
      defaultFootprint: Value(defaultFootprint),
      datasheet: Value(datasheet),
      footprintFilters: Value(footprintFilters),
      unitCount: Value(unitCount),
      pinCount: Value(pinCount),
      isPower: Value(isPower),
      extendsSymbol: extendsSymbol == null && nullToAbsent
          ? const Value.absent()
          : Value(extendsSymbol),
      spanStart: Value(spanStart),
      spanEnd: Value(spanEnd),
      searchText: Value(searchText),
    );
  }

  factory SymbolIndexRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SymbolIndexRow(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      libraryNickname: serializer.fromJson<String>(json['libraryNickname']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      keywords: serializer.fromJson<String>(json['keywords']),
      referencePrefix: serializer.fromJson<String>(json['referencePrefix']),
      defaultFootprint: serializer.fromJson<String>(json['defaultFootprint']),
      datasheet: serializer.fromJson<String>(json['datasheet']),
      footprintFilters: serializer.fromJson<String>(json['footprintFilters']),
      unitCount: serializer.fromJson<int>(json['unitCount']),
      pinCount: serializer.fromJson<int>(json['pinCount']),
      isPower: serializer.fromJson<bool>(json['isPower']),
      extendsSymbol: serializer.fromJson<String?>(json['extendsSymbol']),
      spanStart: serializer.fromJson<int>(json['spanStart']),
      spanEnd: serializer.fromJson<int>(json['spanEnd']),
      searchText: serializer.fromJson<String>(json['searchText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'libraryNickname': serializer.toJson<String>(libraryNickname),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'keywords': serializer.toJson<String>(keywords),
      'referencePrefix': serializer.toJson<String>(referencePrefix),
      'defaultFootprint': serializer.toJson<String>(defaultFootprint),
      'datasheet': serializer.toJson<String>(datasheet),
      'footprintFilters': serializer.toJson<String>(footprintFilters),
      'unitCount': serializer.toJson<int>(unitCount),
      'pinCount': serializer.toJson<int>(pinCount),
      'isPower': serializer.toJson<bool>(isPower),
      'extendsSymbol': serializer.toJson<String?>(extendsSymbol),
      'spanStart': serializer.toJson<int>(spanStart),
      'spanEnd': serializer.toJson<int>(spanEnd),
      'searchText': serializer.toJson<String>(searchText),
    };
  }

  SymbolIndexRow copyWith({
    String? id,
    String? libraryId,
    String? libraryNickname,
    String? name,
    String? description,
    String? keywords,
    String? referencePrefix,
    String? defaultFootprint,
    String? datasheet,
    String? footprintFilters,
    int? unitCount,
    int? pinCount,
    bool? isPower,
    Value<String?> extendsSymbol = const Value.absent(),
    int? spanStart,
    int? spanEnd,
    String? searchText,
  }) => SymbolIndexRow(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    libraryNickname: libraryNickname ?? this.libraryNickname,
    name: name ?? this.name,
    description: description ?? this.description,
    keywords: keywords ?? this.keywords,
    referencePrefix: referencePrefix ?? this.referencePrefix,
    defaultFootprint: defaultFootprint ?? this.defaultFootprint,
    datasheet: datasheet ?? this.datasheet,
    footprintFilters: footprintFilters ?? this.footprintFilters,
    unitCount: unitCount ?? this.unitCount,
    pinCount: pinCount ?? this.pinCount,
    isPower: isPower ?? this.isPower,
    extendsSymbol: extendsSymbol.present
        ? extendsSymbol.value
        : this.extendsSymbol,
    spanStart: spanStart ?? this.spanStart,
    spanEnd: spanEnd ?? this.spanEnd,
    searchText: searchText ?? this.searchText,
  );
  SymbolIndexRow copyWithCompanion(SymbolIndexEntriesCompanion data) {
    return SymbolIndexRow(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      libraryNickname: data.libraryNickname.present
          ? data.libraryNickname.value
          : this.libraryNickname,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      referencePrefix: data.referencePrefix.present
          ? data.referencePrefix.value
          : this.referencePrefix,
      defaultFootprint: data.defaultFootprint.present
          ? data.defaultFootprint.value
          : this.defaultFootprint,
      datasheet: data.datasheet.present ? data.datasheet.value : this.datasheet,
      footprintFilters: data.footprintFilters.present
          ? data.footprintFilters.value
          : this.footprintFilters,
      unitCount: data.unitCount.present ? data.unitCount.value : this.unitCount,
      pinCount: data.pinCount.present ? data.pinCount.value : this.pinCount,
      isPower: data.isPower.present ? data.isPower.value : this.isPower,
      extendsSymbol: data.extendsSymbol.present
          ? data.extendsSymbol.value
          : this.extendsSymbol,
      spanStart: data.spanStart.present ? data.spanStart.value : this.spanStart,
      spanEnd: data.spanEnd.present ? data.spanEnd.value : this.spanEnd,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SymbolIndexRow(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('libraryNickname: $libraryNickname, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('keywords: $keywords, ')
          ..write('referencePrefix: $referencePrefix, ')
          ..write('defaultFootprint: $defaultFootprint, ')
          ..write('datasheet: $datasheet, ')
          ..write('footprintFilters: $footprintFilters, ')
          ..write('unitCount: $unitCount, ')
          ..write('pinCount: $pinCount, ')
          ..write('isPower: $isPower, ')
          ..write('extendsSymbol: $extendsSymbol, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('searchText: $searchText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    libraryNickname,
    name,
    description,
    keywords,
    referencePrefix,
    defaultFootprint,
    datasheet,
    footprintFilters,
    unitCount,
    pinCount,
    isPower,
    extendsSymbol,
    spanStart,
    spanEnd,
    searchText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymbolIndexRow &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.libraryNickname == this.libraryNickname &&
          other.name == this.name &&
          other.description == this.description &&
          other.keywords == this.keywords &&
          other.referencePrefix == this.referencePrefix &&
          other.defaultFootprint == this.defaultFootprint &&
          other.datasheet == this.datasheet &&
          other.footprintFilters == this.footprintFilters &&
          other.unitCount == this.unitCount &&
          other.pinCount == this.pinCount &&
          other.isPower == this.isPower &&
          other.extendsSymbol == this.extendsSymbol &&
          other.spanStart == this.spanStart &&
          other.spanEnd == this.spanEnd &&
          other.searchText == this.searchText);
}

class SymbolIndexEntriesCompanion extends UpdateCompanion<SymbolIndexRow> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> libraryNickname;
  final Value<String> name;
  final Value<String> description;
  final Value<String> keywords;
  final Value<String> referencePrefix;
  final Value<String> defaultFootprint;
  final Value<String> datasheet;
  final Value<String> footprintFilters;
  final Value<int> unitCount;
  final Value<int> pinCount;
  final Value<bool> isPower;
  final Value<String?> extendsSymbol;
  final Value<int> spanStart;
  final Value<int> spanEnd;
  final Value<String> searchText;
  final Value<int> rowid;
  const SymbolIndexEntriesCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.libraryNickname = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.keywords = const Value.absent(),
    this.referencePrefix = const Value.absent(),
    this.defaultFootprint = const Value.absent(),
    this.datasheet = const Value.absent(),
    this.footprintFilters = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.pinCount = const Value.absent(),
    this.isPower = const Value.absent(),
    this.extendsSymbol = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SymbolIndexEntriesCompanion.insert({
    required String id,
    required String libraryId,
    required String libraryNickname,
    required String name,
    this.description = const Value.absent(),
    this.keywords = const Value.absent(),
    this.referencePrefix = const Value.absent(),
    this.defaultFootprint = const Value.absent(),
    this.datasheet = const Value.absent(),
    this.footprintFilters = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.pinCount = const Value.absent(),
    this.isPower = const Value.absent(),
    this.extendsSymbol = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       libraryNickname = Value(libraryNickname),
       name = Value(name);
  static Insertable<SymbolIndexRow> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? libraryNickname,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? keywords,
    Expression<String>? referencePrefix,
    Expression<String>? defaultFootprint,
    Expression<String>? datasheet,
    Expression<String>? footprintFilters,
    Expression<int>? unitCount,
    Expression<int>? pinCount,
    Expression<bool>? isPower,
    Expression<String>? extendsSymbol,
    Expression<int>? spanStart,
    Expression<int>? spanEnd,
    Expression<String>? searchText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (libraryNickname != null) 'library_nickname': libraryNickname,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (keywords != null) 'keywords': keywords,
      if (referencePrefix != null) 'reference_prefix': referencePrefix,
      if (defaultFootprint != null) 'default_footprint': defaultFootprint,
      if (datasheet != null) 'datasheet': datasheet,
      if (footprintFilters != null) 'footprint_filters': footprintFilters,
      if (unitCount != null) 'unit_count': unitCount,
      if (pinCount != null) 'pin_count': pinCount,
      if (isPower != null) 'is_power': isPower,
      if (extendsSymbol != null) 'extends_symbol': extendsSymbol,
      if (spanStart != null) 'span_start': spanStart,
      if (spanEnd != null) 'span_end': spanEnd,
      if (searchText != null) 'search_text': searchText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SymbolIndexEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? libraryNickname,
    Value<String>? name,
    Value<String>? description,
    Value<String>? keywords,
    Value<String>? referencePrefix,
    Value<String>? defaultFootprint,
    Value<String>? datasheet,
    Value<String>? footprintFilters,
    Value<int>? unitCount,
    Value<int>? pinCount,
    Value<bool>? isPower,
    Value<String?>? extendsSymbol,
    Value<int>? spanStart,
    Value<int>? spanEnd,
    Value<String>? searchText,
    Value<int>? rowid,
  }) {
    return SymbolIndexEntriesCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      libraryNickname: libraryNickname ?? this.libraryNickname,
      name: name ?? this.name,
      description: description ?? this.description,
      keywords: keywords ?? this.keywords,
      referencePrefix: referencePrefix ?? this.referencePrefix,
      defaultFootprint: defaultFootprint ?? this.defaultFootprint,
      datasheet: datasheet ?? this.datasheet,
      footprintFilters: footprintFilters ?? this.footprintFilters,
      unitCount: unitCount ?? this.unitCount,
      pinCount: pinCount ?? this.pinCount,
      isPower: isPower ?? this.isPower,
      extendsSymbol: extendsSymbol ?? this.extendsSymbol,
      spanStart: spanStart ?? this.spanStart,
      spanEnd: spanEnd ?? this.spanEnd,
      searchText: searchText ?? this.searchText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (libraryNickname.present) {
      map['library_nickname'] = Variable<String>(libraryNickname.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (referencePrefix.present) {
      map['reference_prefix'] = Variable<String>(referencePrefix.value);
    }
    if (defaultFootprint.present) {
      map['default_footprint'] = Variable<String>(defaultFootprint.value);
    }
    if (datasheet.present) {
      map['datasheet'] = Variable<String>(datasheet.value);
    }
    if (footprintFilters.present) {
      map['footprint_filters'] = Variable<String>(footprintFilters.value);
    }
    if (unitCount.present) {
      map['unit_count'] = Variable<int>(unitCount.value);
    }
    if (pinCount.present) {
      map['pin_count'] = Variable<int>(pinCount.value);
    }
    if (isPower.present) {
      map['is_power'] = Variable<bool>(isPower.value);
    }
    if (extendsSymbol.present) {
      map['extends_symbol'] = Variable<String>(extendsSymbol.value);
    }
    if (spanStart.present) {
      map['span_start'] = Variable<int>(spanStart.value);
    }
    if (spanEnd.present) {
      map['span_end'] = Variable<int>(spanEnd.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SymbolIndexEntriesCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('libraryNickname: $libraryNickname, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('keywords: $keywords, ')
          ..write('referencePrefix: $referencePrefix, ')
          ..write('defaultFootprint: $defaultFootprint, ')
          ..write('datasheet: $datasheet, ')
          ..write('footprintFilters: $footprintFilters, ')
          ..write('unitCount: $unitCount, ')
          ..write('pinCount: $pinCount, ')
          ..write('isPower: $isPower, ')
          ..write('extendsSymbol: $extendsSymbol, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('searchText: $searchText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NetRouteHintsTable extends NetRouteHints
    with TableInfo<$NetRouteHintsTable, NetRouteHintRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NetRouteHintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pinAIdMeta = const VerificationMeta('pinAId');
  @override
  late final GeneratedColumn<String> pinAId = GeneratedColumn<String>(
    'pin_a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES part_pins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pinBIdMeta = const VerificationMeta('pinBId');
  @override
  late final GeneratedColumn<String> pinBId = GeneratedColumn<String>(
    'pin_b_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES part_pins (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _turnOffsetsMeta = const VerificationMeta(
    'turnOffsets',
  );
  @override
  late final GeneratedColumn<String> turnOffsets = GeneratedColumn<String>(
    'turn_offsets',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    pinAId,
    pinBId,
    turnOffsets,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'net_route_hints';
  @override
  VerificationContext validateIntegrity(
    Insertable<NetRouteHintRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('pin_a_id')) {
      context.handle(
        _pinAIdMeta,
        pinAId.isAcceptableOrUnknown(data['pin_a_id']!, _pinAIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pinAIdMeta);
    }
    if (data.containsKey('pin_b_id')) {
      context.handle(
        _pinBIdMeta,
        pinBId.isAcceptableOrUnknown(data['pin_b_id']!, _pinBIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pinBIdMeta);
    }
    if (data.containsKey('turn_offsets')) {
      context.handle(
        _turnOffsetsMeta,
        turnOffsets.isAcceptableOrUnknown(
          data['turn_offsets']!,
          _turnOffsetsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {pinAId, pinBId},
  ];
  @override
  NetRouteHintRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NetRouteHintRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      pinAId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_a_id'],
      )!,
      pinBId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_b_id'],
      )!,
      turnOffsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_offsets'],
      )!,
    );
  }

  @override
  $NetRouteHintsTable createAlias(String alias) {
    return $NetRouteHintsTable(attachedDatabase, alias);
  }
}

class NetRouteHintRow extends DataClass implements Insertable<NetRouteHintRow> {
  final String id;
  final String projectId;

  /// The lower-sorting pin id of the pair.
  final String pinAId;

  /// The higher-sorting pin id of the pair.
  final String pinBId;

  /// How far to shift each movable run of the route, in millimetres,
  /// comma-separated and in the order the router reports them.
  ///
  /// Displacements from the automatic route rather than absolute positions,
  /// so an adjusted wire keeps its shape when the parts at either end move.
  final String turnOffsets;
  const NetRouteHintRow({
    required this.id,
    required this.projectId,
    required this.pinAId,
    required this.pinBId,
    required this.turnOffsets,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['pin_a_id'] = Variable<String>(pinAId);
    map['pin_b_id'] = Variable<String>(pinBId);
    map['turn_offsets'] = Variable<String>(turnOffsets);
    return map;
  }

  NetRouteHintsCompanion toCompanion(bool nullToAbsent) {
    return NetRouteHintsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      pinAId: Value(pinAId),
      pinBId: Value(pinBId),
      turnOffsets: Value(turnOffsets),
    );
  }

  factory NetRouteHintRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NetRouteHintRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      pinAId: serializer.fromJson<String>(json['pinAId']),
      pinBId: serializer.fromJson<String>(json['pinBId']),
      turnOffsets: serializer.fromJson<String>(json['turnOffsets']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'pinAId': serializer.toJson<String>(pinAId),
      'pinBId': serializer.toJson<String>(pinBId),
      'turnOffsets': serializer.toJson<String>(turnOffsets),
    };
  }

  NetRouteHintRow copyWith({
    String? id,
    String? projectId,
    String? pinAId,
    String? pinBId,
    String? turnOffsets,
  }) => NetRouteHintRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    pinAId: pinAId ?? this.pinAId,
    pinBId: pinBId ?? this.pinBId,
    turnOffsets: turnOffsets ?? this.turnOffsets,
  );
  NetRouteHintRow copyWithCompanion(NetRouteHintsCompanion data) {
    return NetRouteHintRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      pinAId: data.pinAId.present ? data.pinAId.value : this.pinAId,
      pinBId: data.pinBId.present ? data.pinBId.value : this.pinBId,
      turnOffsets: data.turnOffsets.present
          ? data.turnOffsets.value
          : this.turnOffsets,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NetRouteHintRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('pinAId: $pinAId, ')
          ..write('pinBId: $pinBId, ')
          ..write('turnOffsets: $turnOffsets')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, pinAId, pinBId, turnOffsets);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetRouteHintRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.pinAId == this.pinAId &&
          other.pinBId == this.pinBId &&
          other.turnOffsets == this.turnOffsets);
}

class NetRouteHintsCompanion extends UpdateCompanion<NetRouteHintRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> pinAId;
  final Value<String> pinBId;
  final Value<String> turnOffsets;
  final Value<int> rowid;
  const NetRouteHintsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.pinAId = const Value.absent(),
    this.pinBId = const Value.absent(),
    this.turnOffsets = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NetRouteHintsCompanion.insert({
    required String id,
    required String projectId,
    required String pinAId,
    required String pinBId,
    this.turnOffsets = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       pinAId = Value(pinAId),
       pinBId = Value(pinBId);
  static Insertable<NetRouteHintRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? pinAId,
    Expression<String>? pinBId,
    Expression<String>? turnOffsets,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (pinAId != null) 'pin_a_id': pinAId,
      if (pinBId != null) 'pin_b_id': pinBId,
      if (turnOffsets != null) 'turn_offsets': turnOffsets,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NetRouteHintsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? pinAId,
    Value<String>? pinBId,
    Value<String>? turnOffsets,
    Value<int>? rowid,
  }) {
    return NetRouteHintsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      pinAId: pinAId ?? this.pinAId,
      pinBId: pinBId ?? this.pinBId,
      turnOffsets: turnOffsets ?? this.turnOffsets,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (pinAId.present) {
      map['pin_a_id'] = Variable<String>(pinAId.value);
    }
    if (pinBId.present) {
      map['pin_b_id'] = Variable<String>(pinBId.value);
    }
    if (turnOffsets.present) {
      map['turn_offsets'] = Variable<String>(turnOffsets.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NetRouteHintsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('pinAId: $pinAId, ')
          ..write('pinBId: $pinBId, ')
          ..write('turnOffsets: $turnOffsets, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FootprintLibrariesTable extends FootprintLibraries
    with TableInfo<$FootprintLibrariesTable, FootprintLibraryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FootprintLibrariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _footprintCountMeta = const VerificationMeta(
    'footprintCount',
  );
  @override
  late final GeneratedColumn<int> footprintCount = GeneratedColumn<int>(
    'footprint_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nickname,
    fileName,
    footprintCount,
    byteSize,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'footprint_libraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FootprintLibraryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('footprint_count')) {
      context.handle(
        _footprintCountMeta,
        footprintCount.isAcceptableOrUnknown(
          data['footprint_count']!,
          _footprintCountMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {nickname},
  ];
  @override
  FootprintLibraryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FootprintLibraryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      footprintCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}footprint_count'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $FootprintLibrariesTable createAlias(String alias) {
    return $FootprintLibrariesTable(attachedDatabase, alias);
  }
}

class FootprintLibraryRow extends DataClass
    implements Insertable<FootprintLibraryRow> {
  final String id;

  /// Library nickname, e.g. `Resistor_SMD` — the first half of every
  /// footprint id it produces.
  final String nickname;
  final String fileName;
  final int footprintCount;
  final int byteSize;
  final DateTime importedAt;
  const FootprintLibraryRow({
    required this.id,
    required this.nickname,
    required this.fileName,
    required this.footprintCount,
    required this.byteSize,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nickname'] = Variable<String>(nickname);
    map['file_name'] = Variable<String>(fileName);
    map['footprint_count'] = Variable<int>(footprintCount);
    map['byte_size'] = Variable<int>(byteSize);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  FootprintLibrariesCompanion toCompanion(bool nullToAbsent) {
    return FootprintLibrariesCompanion(
      id: Value(id),
      nickname: Value(nickname),
      fileName: Value(fileName),
      footprintCount: Value(footprintCount),
      byteSize: Value(byteSize),
      importedAt: Value(importedAt),
    );
  }

  factory FootprintLibraryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FootprintLibraryRow(
      id: serializer.fromJson<String>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      fileName: serializer.fromJson<String>(json['fileName']),
      footprintCount: serializer.fromJson<int>(json['footprintCount']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nickname': serializer.toJson<String>(nickname),
      'fileName': serializer.toJson<String>(fileName),
      'footprintCount': serializer.toJson<int>(footprintCount),
      'byteSize': serializer.toJson<int>(byteSize),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  FootprintLibraryRow copyWith({
    String? id,
    String? nickname,
    String? fileName,
    int? footprintCount,
    int? byteSize,
    DateTime? importedAt,
  }) => FootprintLibraryRow(
    id: id ?? this.id,
    nickname: nickname ?? this.nickname,
    fileName: fileName ?? this.fileName,
    footprintCount: footprintCount ?? this.footprintCount,
    byteSize: byteSize ?? this.byteSize,
    importedAt: importedAt ?? this.importedAt,
  );
  FootprintLibraryRow copyWithCompanion(FootprintLibrariesCompanion data) {
    return FootprintLibraryRow(
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      footprintCount: data.footprintCount.present
          ? data.footprintCount.value
          : this.footprintCount,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FootprintLibraryRow(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('fileName: $fileName, ')
          ..write('footprintCount: $footprintCount, ')
          ..write('byteSize: $byteSize, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nickname, fileName, footprintCount, byteSize, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FootprintLibraryRow &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.fileName == this.fileName &&
          other.footprintCount == this.footprintCount &&
          other.byteSize == this.byteSize &&
          other.importedAt == this.importedAt);
}

class FootprintLibrariesCompanion extends UpdateCompanion<FootprintLibraryRow> {
  final Value<String> id;
  final Value<String> nickname;
  final Value<String> fileName;
  final Value<int> footprintCount;
  final Value<int> byteSize;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const FootprintLibrariesCompanion({
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.fileName = const Value.absent(),
    this.footprintCount = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FootprintLibrariesCompanion.insert({
    required String id,
    required String nickname,
    required String fileName,
    this.footprintCount = const Value.absent(),
    this.byteSize = const Value.absent(),
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nickname = Value(nickname),
       fileName = Value(fileName),
       importedAt = Value(importedAt);
  static Insertable<FootprintLibraryRow> custom({
    Expression<String>? id,
    Expression<String>? nickname,
    Expression<String>? fileName,
    Expression<int>? footprintCount,
    Expression<int>? byteSize,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (fileName != null) 'file_name': fileName,
      if (footprintCount != null) 'footprint_count': footprintCount,
      if (byteSize != null) 'byte_size': byteSize,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FootprintLibrariesCompanion copyWith({
    Value<String>? id,
    Value<String>? nickname,
    Value<String>? fileName,
    Value<int>? footprintCount,
    Value<int>? byteSize,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return FootprintLibrariesCompanion(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      fileName: fileName ?? this.fileName,
      footprintCount: footprintCount ?? this.footprintCount,
      byteSize: byteSize ?? this.byteSize,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (footprintCount.present) {
      map['footprint_count'] = Variable<int>(footprintCount.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FootprintLibrariesCompanion(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('fileName: $fileName, ')
          ..write('footprintCount: $footprintCount, ')
          ..write('byteSize: $byteSize, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FootprintIndexEntriesTable extends FootprintIndexEntries
    with TableInfo<$FootprintIndexEntriesTable, FootprintIndexRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FootprintIndexEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES footprint_libraries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _libraryNicknameMeta = const VerificationMeta(
    'libraryNickname',
  );
  @override
  late final GeneratedColumn<String> libraryNickname = GeneratedColumn<String>(
    'library_nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _keywordsMeta = const VerificationMeta(
    'keywords',
  );
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
    'keywords',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _padCountMeta = const VerificationMeta(
    'padCount',
  );
  @override
  late final GeneratedColumn<int> padCount = GeneratedColumn<int>(
    'pad_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSurfaceMountMeta = const VerificationMeta(
    'isSurfaceMount',
  );
  @override
  late final GeneratedColumn<bool> isSurfaceMount = GeneratedColumn<bool>(
    'is_surface_mount',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_surface_mount" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isThroughHoleMeta = const VerificationMeta(
    'isThroughHole',
  );
  @override
  late final GeneratedColumn<bool> isThroughHole = GeneratedColumn<bool>(
    'is_through_hole',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_through_hole" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _spanStartMeta = const VerificationMeta(
    'spanStart',
  );
  @override
  late final GeneratedColumn<int> spanStart = GeneratedColumn<int>(
    'span_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _spanEndMeta = const VerificationMeta(
    'spanEnd',
  );
  @override
  late final GeneratedColumn<int> spanEnd = GeneratedColumn<int>(
    'span_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    libraryNickname,
    name,
    description,
    keywords,
    padCount,
    isSurfaceMount,
    isThroughHole,
    spanStart,
    spanEnd,
    searchText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'footprint_index_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FootprintIndexRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('library_nickname')) {
      context.handle(
        _libraryNicknameMeta,
        libraryNickname.isAcceptableOrUnknown(
          data['library_nickname']!,
          _libraryNicknameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_libraryNicknameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('keywords')) {
      context.handle(
        _keywordsMeta,
        keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta),
      );
    }
    if (data.containsKey('pad_count')) {
      context.handle(
        _padCountMeta,
        padCount.isAcceptableOrUnknown(data['pad_count']!, _padCountMeta),
      );
    }
    if (data.containsKey('is_surface_mount')) {
      context.handle(
        _isSurfaceMountMeta,
        isSurfaceMount.isAcceptableOrUnknown(
          data['is_surface_mount']!,
          _isSurfaceMountMeta,
        ),
      );
    }
    if (data.containsKey('is_through_hole')) {
      context.handle(
        _isThroughHoleMeta,
        isThroughHole.isAcceptableOrUnknown(
          data['is_through_hole']!,
          _isThroughHoleMeta,
        ),
      );
    }
    if (data.containsKey('span_start')) {
      context.handle(
        _spanStartMeta,
        spanStart.isAcceptableOrUnknown(data['span_start']!, _spanStartMeta),
      );
    }
    if (data.containsKey('span_end')) {
      context.handle(
        _spanEndMeta,
        spanEnd.isAcceptableOrUnknown(data['span_end']!, _spanEndMeta),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FootprintIndexRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FootprintIndexRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      libraryNickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_nickname'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      keywords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords'],
      )!,
      padCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pad_count'],
      )!,
      isSurfaceMount: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_surface_mount'],
      )!,
      isThroughHole: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_through_hole'],
      )!,
      spanStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_start'],
      )!,
      spanEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_end'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
    );
  }

  @override
  $FootprintIndexEntriesTable createAlias(String alias) {
    return $FootprintIndexEntriesTable(attachedDatabase, alias);
  }
}

class FootprintIndexRow extends DataClass
    implements Insertable<FootprintIndexRow> {
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
  final String searchText;
  const FootprintIndexRow({
    required this.id,
    required this.libraryId,
    required this.libraryNickname,
    required this.name,
    required this.description,
    required this.keywords,
    required this.padCount,
    required this.isSurfaceMount,
    required this.isThroughHole,
    required this.spanStart,
    required this.spanEnd,
    required this.searchText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['library_nickname'] = Variable<String>(libraryNickname);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['keywords'] = Variable<String>(keywords);
    map['pad_count'] = Variable<int>(padCount);
    map['is_surface_mount'] = Variable<bool>(isSurfaceMount);
    map['is_through_hole'] = Variable<bool>(isThroughHole);
    map['span_start'] = Variable<int>(spanStart);
    map['span_end'] = Variable<int>(spanEnd);
    map['search_text'] = Variable<String>(searchText);
    return map;
  }

  FootprintIndexEntriesCompanion toCompanion(bool nullToAbsent) {
    return FootprintIndexEntriesCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      libraryNickname: Value(libraryNickname),
      name: Value(name),
      description: Value(description),
      keywords: Value(keywords),
      padCount: Value(padCount),
      isSurfaceMount: Value(isSurfaceMount),
      isThroughHole: Value(isThroughHole),
      spanStart: Value(spanStart),
      spanEnd: Value(spanEnd),
      searchText: Value(searchText),
    );
  }

  factory FootprintIndexRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FootprintIndexRow(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      libraryNickname: serializer.fromJson<String>(json['libraryNickname']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      keywords: serializer.fromJson<String>(json['keywords']),
      padCount: serializer.fromJson<int>(json['padCount']),
      isSurfaceMount: serializer.fromJson<bool>(json['isSurfaceMount']),
      isThroughHole: serializer.fromJson<bool>(json['isThroughHole']),
      spanStart: serializer.fromJson<int>(json['spanStart']),
      spanEnd: serializer.fromJson<int>(json['spanEnd']),
      searchText: serializer.fromJson<String>(json['searchText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'libraryNickname': serializer.toJson<String>(libraryNickname),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'keywords': serializer.toJson<String>(keywords),
      'padCount': serializer.toJson<int>(padCount),
      'isSurfaceMount': serializer.toJson<bool>(isSurfaceMount),
      'isThroughHole': serializer.toJson<bool>(isThroughHole),
      'spanStart': serializer.toJson<int>(spanStart),
      'spanEnd': serializer.toJson<int>(spanEnd),
      'searchText': serializer.toJson<String>(searchText),
    };
  }

  FootprintIndexRow copyWith({
    String? id,
    String? libraryId,
    String? libraryNickname,
    String? name,
    String? description,
    String? keywords,
    int? padCount,
    bool? isSurfaceMount,
    bool? isThroughHole,
    int? spanStart,
    int? spanEnd,
    String? searchText,
  }) => FootprintIndexRow(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    libraryNickname: libraryNickname ?? this.libraryNickname,
    name: name ?? this.name,
    description: description ?? this.description,
    keywords: keywords ?? this.keywords,
    padCount: padCount ?? this.padCount,
    isSurfaceMount: isSurfaceMount ?? this.isSurfaceMount,
    isThroughHole: isThroughHole ?? this.isThroughHole,
    spanStart: spanStart ?? this.spanStart,
    spanEnd: spanEnd ?? this.spanEnd,
    searchText: searchText ?? this.searchText,
  );
  FootprintIndexRow copyWithCompanion(FootprintIndexEntriesCompanion data) {
    return FootprintIndexRow(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      libraryNickname: data.libraryNickname.present
          ? data.libraryNickname.value
          : this.libraryNickname,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      padCount: data.padCount.present ? data.padCount.value : this.padCount,
      isSurfaceMount: data.isSurfaceMount.present
          ? data.isSurfaceMount.value
          : this.isSurfaceMount,
      isThroughHole: data.isThroughHole.present
          ? data.isThroughHole.value
          : this.isThroughHole,
      spanStart: data.spanStart.present ? data.spanStart.value : this.spanStart,
      spanEnd: data.spanEnd.present ? data.spanEnd.value : this.spanEnd,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FootprintIndexRow(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('libraryNickname: $libraryNickname, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('keywords: $keywords, ')
          ..write('padCount: $padCount, ')
          ..write('isSurfaceMount: $isSurfaceMount, ')
          ..write('isThroughHole: $isThroughHole, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('searchText: $searchText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    libraryNickname,
    name,
    description,
    keywords,
    padCount,
    isSurfaceMount,
    isThroughHole,
    spanStart,
    spanEnd,
    searchText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FootprintIndexRow &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.libraryNickname == this.libraryNickname &&
          other.name == this.name &&
          other.description == this.description &&
          other.keywords == this.keywords &&
          other.padCount == this.padCount &&
          other.isSurfaceMount == this.isSurfaceMount &&
          other.isThroughHole == this.isThroughHole &&
          other.spanStart == this.spanStart &&
          other.spanEnd == this.spanEnd &&
          other.searchText == this.searchText);
}

class FootprintIndexEntriesCompanion
    extends UpdateCompanion<FootprintIndexRow> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> libraryNickname;
  final Value<String> name;
  final Value<String> description;
  final Value<String> keywords;
  final Value<int> padCount;
  final Value<bool> isSurfaceMount;
  final Value<bool> isThroughHole;
  final Value<int> spanStart;
  final Value<int> spanEnd;
  final Value<String> searchText;
  final Value<int> rowid;
  const FootprintIndexEntriesCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.libraryNickname = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.keywords = const Value.absent(),
    this.padCount = const Value.absent(),
    this.isSurfaceMount = const Value.absent(),
    this.isThroughHole = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FootprintIndexEntriesCompanion.insert({
    required String id,
    required String libraryId,
    required String libraryNickname,
    required String name,
    this.description = const Value.absent(),
    this.keywords = const Value.absent(),
    this.padCount = const Value.absent(),
    this.isSurfaceMount = const Value.absent(),
    this.isThroughHole = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       libraryNickname = Value(libraryNickname),
       name = Value(name);
  static Insertable<FootprintIndexRow> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? libraryNickname,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? keywords,
    Expression<int>? padCount,
    Expression<bool>? isSurfaceMount,
    Expression<bool>? isThroughHole,
    Expression<int>? spanStart,
    Expression<int>? spanEnd,
    Expression<String>? searchText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (libraryNickname != null) 'library_nickname': libraryNickname,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (keywords != null) 'keywords': keywords,
      if (padCount != null) 'pad_count': padCount,
      if (isSurfaceMount != null) 'is_surface_mount': isSurfaceMount,
      if (isThroughHole != null) 'is_through_hole': isThroughHole,
      if (spanStart != null) 'span_start': spanStart,
      if (spanEnd != null) 'span_end': spanEnd,
      if (searchText != null) 'search_text': searchText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FootprintIndexEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? libraryNickname,
    Value<String>? name,
    Value<String>? description,
    Value<String>? keywords,
    Value<int>? padCount,
    Value<bool>? isSurfaceMount,
    Value<bool>? isThroughHole,
    Value<int>? spanStart,
    Value<int>? spanEnd,
    Value<String>? searchText,
    Value<int>? rowid,
  }) {
    return FootprintIndexEntriesCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      libraryNickname: libraryNickname ?? this.libraryNickname,
      name: name ?? this.name,
      description: description ?? this.description,
      keywords: keywords ?? this.keywords,
      padCount: padCount ?? this.padCount,
      isSurfaceMount: isSurfaceMount ?? this.isSurfaceMount,
      isThroughHole: isThroughHole ?? this.isThroughHole,
      spanStart: spanStart ?? this.spanStart,
      spanEnd: spanEnd ?? this.spanEnd,
      searchText: searchText ?? this.searchText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (libraryNickname.present) {
      map['library_nickname'] = Variable<String>(libraryNickname.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (padCount.present) {
      map['pad_count'] = Variable<int>(padCount.value);
    }
    if (isSurfaceMount.present) {
      map['is_surface_mount'] = Variable<bool>(isSurfaceMount.value);
    }
    if (isThroughHole.present) {
      map['is_through_hole'] = Variable<bool>(isThroughHole.value);
    }
    if (spanStart.present) {
      map['span_start'] = Variable<int>(spanStart.value);
    }
    if (spanEnd.present) {
      map['span_end'] = Variable<int>(spanEnd.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FootprintIndexEntriesCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('libraryNickname: $libraryNickname, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('keywords: $keywords, ')
          ..write('padCount: $padCount, ')
          ..write('isSurfaceMount: $isSurfaceMount, ')
          ..write('isThroughHole: $isThroughHole, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('searchText: $searchText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardsTable extends Boards with TableInfo<$BoardsTable, BoardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _outlineXMeta = const VerificationMeta(
    'outlineX',
  );
  @override
  late final GeneratedColumn<double> outlineX = GeneratedColumn<double>(
    'outline_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _outlineYMeta = const VerificationMeta(
    'outlineY',
  );
  @override
  late final GeneratedColumn<double> outlineY = GeneratedColumn<double>(
    'outline_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _outlineWidthMeta = const VerificationMeta(
    'outlineWidth',
  );
  @override
  late final GeneratedColumn<double> outlineWidth = GeneratedColumn<double>(
    'outline_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _outlineHeightMeta = const VerificationMeta(
    'outlineHeight',
  );
  @override
  late final GeneratedColumn<double> outlineHeight = GeneratedColumn<double>(
    'outline_height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _outlineKindMeta = const VerificationMeta(
    'outlineKind',
  );
  @override
  late final GeneratedColumn<String> outlineKind = GeneratedColumn<String>(
    'outline_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('rectangle'),
  );
  static const VerificationMeta _outlinePointsMeta = const VerificationMeta(
    'outlinePoints',
  );
  @override
  late final GeneratedColumn<String> outlinePoints = GeneratedColumn<String>(
    'outline_points',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _trackWidthMeta = const VerificationMeta(
    'trackWidth',
  );
  @override
  late final GeneratedColumn<double> trackWidth = GeneratedColumn<double>(
    'track_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.25),
  );
  static const VerificationMeta _clearanceMeta = const VerificationMeta(
    'clearance',
  );
  @override
  late final GeneratedColumn<double> clearance = GeneratedColumn<double>(
    'clearance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.2),
  );
  static const VerificationMeta _viaDiameterMeta = const VerificationMeta(
    'viaDiameter',
  );
  @override
  late final GeneratedColumn<double> viaDiameter = GeneratedColumn<double>(
    'via_diameter',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.8),
  );
  static const VerificationMeta _viaDrillMeta = const VerificationMeta(
    'viaDrill',
  );
  @override
  late final GeneratedColumn<double> viaDrill = GeneratedColumn<double>(
    'via_drill',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.4),
  );
  static const VerificationMeta _trackWidthsMeta = const VerificationMeta(
    'trackWidths',
  );
  @override
  late final GeneratedColumn<String> trackWidths = GeneratedColumn<String>(
    'track_widths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _viaSizesMeta = const VerificationMeta(
    'viaSizes',
  );
  @override
  late final GeneratedColumn<String> viaSizes = GeneratedColumn<String>(
    'via_sizes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _gridMmMeta = const VerificationMeta('gridMm');
  @override
  late final GeneratedColumn<double> gridMm = GeneratedColumn<double>(
    'grid_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _copperLayersMeta = const VerificationMeta(
    'copperLayers',
  );
  @override
  late final GeneratedColumn<int> copperLayers = GeneratedColumn<int>(
    'copper_layers',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _thicknessMeta = const VerificationMeta(
    'thickness',
  );
  @override
  late final GeneratedColumn<double> thickness = GeneratedColumn<double>(
    'thickness',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.6),
  );
  static const VerificationMeta _stackupMeta = const VerificationMeta(
    'stackup',
  );
  @override
  late final GeneratedColumn<String> stackup = GeneratedColumn<String>(
    'stackup',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    outlineX,
    outlineY,
    outlineWidth,
    outlineHeight,
    outlineKind,
    outlinePoints,
    trackWidth,
    clearance,
    viaDiameter,
    viaDrill,
    trackWidths,
    viaSizes,
    gridMm,
    copperLayers,
    thickness,
    stackup,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boards';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('outline_x')) {
      context.handle(
        _outlineXMeta,
        outlineX.isAcceptableOrUnknown(data['outline_x']!, _outlineXMeta),
      );
    }
    if (data.containsKey('outline_y')) {
      context.handle(
        _outlineYMeta,
        outlineY.isAcceptableOrUnknown(data['outline_y']!, _outlineYMeta),
      );
    }
    if (data.containsKey('outline_width')) {
      context.handle(
        _outlineWidthMeta,
        outlineWidth.isAcceptableOrUnknown(
          data['outline_width']!,
          _outlineWidthMeta,
        ),
      );
    }
    if (data.containsKey('outline_height')) {
      context.handle(
        _outlineHeightMeta,
        outlineHeight.isAcceptableOrUnknown(
          data['outline_height']!,
          _outlineHeightMeta,
        ),
      );
    }
    if (data.containsKey('outline_kind')) {
      context.handle(
        _outlineKindMeta,
        outlineKind.isAcceptableOrUnknown(
          data['outline_kind']!,
          _outlineKindMeta,
        ),
      );
    }
    if (data.containsKey('outline_points')) {
      context.handle(
        _outlinePointsMeta,
        outlinePoints.isAcceptableOrUnknown(
          data['outline_points']!,
          _outlinePointsMeta,
        ),
      );
    }
    if (data.containsKey('track_width')) {
      context.handle(
        _trackWidthMeta,
        trackWidth.isAcceptableOrUnknown(data['track_width']!, _trackWidthMeta),
      );
    }
    if (data.containsKey('clearance')) {
      context.handle(
        _clearanceMeta,
        clearance.isAcceptableOrUnknown(data['clearance']!, _clearanceMeta),
      );
    }
    if (data.containsKey('via_diameter')) {
      context.handle(
        _viaDiameterMeta,
        viaDiameter.isAcceptableOrUnknown(
          data['via_diameter']!,
          _viaDiameterMeta,
        ),
      );
    }
    if (data.containsKey('via_drill')) {
      context.handle(
        _viaDrillMeta,
        viaDrill.isAcceptableOrUnknown(data['via_drill']!, _viaDrillMeta),
      );
    }
    if (data.containsKey('track_widths')) {
      context.handle(
        _trackWidthsMeta,
        trackWidths.isAcceptableOrUnknown(
          data['track_widths']!,
          _trackWidthsMeta,
        ),
      );
    }
    if (data.containsKey('via_sizes')) {
      context.handle(
        _viaSizesMeta,
        viaSizes.isAcceptableOrUnknown(data['via_sizes']!, _viaSizesMeta),
      );
    }
    if (data.containsKey('grid_mm')) {
      context.handle(
        _gridMmMeta,
        gridMm.isAcceptableOrUnknown(data['grid_mm']!, _gridMmMeta),
      );
    }
    if (data.containsKey('copper_layers')) {
      context.handle(
        _copperLayersMeta,
        copperLayers.isAcceptableOrUnknown(
          data['copper_layers']!,
          _copperLayersMeta,
        ),
      );
    }
    if (data.containsKey('thickness')) {
      context.handle(
        _thicknessMeta,
        thickness.isAcceptableOrUnknown(data['thickness']!, _thicknessMeta),
      );
    }
    if (data.containsKey('stackup')) {
      context.handle(
        _stackupMeta,
        stackup.isAcceptableOrUnknown(data['stackup']!, _stackupMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId},
  ];
  @override
  BoardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      outlineX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}outline_x'],
      )!,
      outlineY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}outline_y'],
      )!,
      outlineWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}outline_width'],
      )!,
      outlineHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}outline_height'],
      )!,
      outlineKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outline_kind'],
      )!,
      outlinePoints: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outline_points'],
      )!,
      trackWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}track_width'],
      )!,
      clearance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}clearance'],
      )!,
      viaDiameter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}via_diameter'],
      )!,
      viaDrill: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}via_drill'],
      )!,
      trackWidths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_widths'],
      )!,
      viaSizes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}via_sizes'],
      )!,
      gridMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grid_mm'],
      )!,
      copperLayers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}copper_layers'],
      )!,
      thickness: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thickness'],
      )!,
      stackup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stackup'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
    );
  }

  @override
  $BoardsTable createAlias(String alias) {
    return $BoardsTable(attachedDatabase, alias);
  }
}

class BoardRow extends DataClass implements Insertable<BoardRow> {
  final String id;
  final String projectId;

  /// The board outline's bounding box, in millimetres. Authoritative for a
  /// rectangle; for a circle it is the square the circle sits in; for a
  /// polygon it is derived from the points and kept for framing the view.
  final double outlineX;
  final double outlineY;
  final double outlineWidth;
  final double outlineHeight;

  /// `rectangle`, `circle` or `polygon`.
  final String outlineKind;

  /// Polygon vertices as `x,y` pairs separated by spaces. Empty for the
  /// other shapes, which the bounding box already describes.
  final String outlinePoints;

  /// Design rules, in millimetres. Defaults are deliberately conservative —
  /// every board house on earth makes 0.25 mm track and space.
  final double trackWidth;
  final double clearance;
  final double viaDiameter;
  final double viaDrill;

  /// Track widths and via sizes set up in advance, to be picked from while
  /// routing — KiCad keeps the same list in Board Setup. Space-separated
  /// millimetres; a via is `diameter/drill`. Empty means "just the rule".
  final String trackWidths;
  final String viaSizes;

  /// Placement grid. 0.5 mm rather than the schematic's 1.27 mm: boards are
  /// laid out in a much finer world than schematics.
  final double gridMm;

  /// How many copper layers the board has: 2, 4, 6 or 8.
  final int copperLayers;

  /// Finished board thickness, in millimetres.
  final double thickness;

  /// The layer build-up — copper weights, dielectric heights and materials —
  /// as JSON. Empty means "the standard build for this many layers and
  /// this thickness", worked out rather than stored.
  final String stackup;
  final DateTime modifiedAt;
  const BoardRow({
    required this.id,
    required this.projectId,
    required this.outlineX,
    required this.outlineY,
    required this.outlineWidth,
    required this.outlineHeight,
    required this.outlineKind,
    required this.outlinePoints,
    required this.trackWidth,
    required this.clearance,
    required this.viaDiameter,
    required this.viaDrill,
    required this.trackWidths,
    required this.viaSizes,
    required this.gridMm,
    required this.copperLayers,
    required this.thickness,
    required this.stackup,
    required this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['outline_x'] = Variable<double>(outlineX);
    map['outline_y'] = Variable<double>(outlineY);
    map['outline_width'] = Variable<double>(outlineWidth);
    map['outline_height'] = Variable<double>(outlineHeight);
    map['outline_kind'] = Variable<String>(outlineKind);
    map['outline_points'] = Variable<String>(outlinePoints);
    map['track_width'] = Variable<double>(trackWidth);
    map['clearance'] = Variable<double>(clearance);
    map['via_diameter'] = Variable<double>(viaDiameter);
    map['via_drill'] = Variable<double>(viaDrill);
    map['track_widths'] = Variable<String>(trackWidths);
    map['via_sizes'] = Variable<String>(viaSizes);
    map['grid_mm'] = Variable<double>(gridMm);
    map['copper_layers'] = Variable<int>(copperLayers);
    map['thickness'] = Variable<double>(thickness);
    map['stackup'] = Variable<String>(stackup);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    return map;
  }

  BoardsCompanion toCompanion(bool nullToAbsent) {
    return BoardsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      outlineX: Value(outlineX),
      outlineY: Value(outlineY),
      outlineWidth: Value(outlineWidth),
      outlineHeight: Value(outlineHeight),
      outlineKind: Value(outlineKind),
      outlinePoints: Value(outlinePoints),
      trackWidth: Value(trackWidth),
      clearance: Value(clearance),
      viaDiameter: Value(viaDiameter),
      viaDrill: Value(viaDrill),
      trackWidths: Value(trackWidths),
      viaSizes: Value(viaSizes),
      gridMm: Value(gridMm),
      copperLayers: Value(copperLayers),
      thickness: Value(thickness),
      stackup: Value(stackup),
      modifiedAt: Value(modifiedAt),
    );
  }

  factory BoardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      outlineX: serializer.fromJson<double>(json['outlineX']),
      outlineY: serializer.fromJson<double>(json['outlineY']),
      outlineWidth: serializer.fromJson<double>(json['outlineWidth']),
      outlineHeight: serializer.fromJson<double>(json['outlineHeight']),
      outlineKind: serializer.fromJson<String>(json['outlineKind']),
      outlinePoints: serializer.fromJson<String>(json['outlinePoints']),
      trackWidth: serializer.fromJson<double>(json['trackWidth']),
      clearance: serializer.fromJson<double>(json['clearance']),
      viaDiameter: serializer.fromJson<double>(json['viaDiameter']),
      viaDrill: serializer.fromJson<double>(json['viaDrill']),
      trackWidths: serializer.fromJson<String>(json['trackWidths']),
      viaSizes: serializer.fromJson<String>(json['viaSizes']),
      gridMm: serializer.fromJson<double>(json['gridMm']),
      copperLayers: serializer.fromJson<int>(json['copperLayers']),
      thickness: serializer.fromJson<double>(json['thickness']),
      stackup: serializer.fromJson<String>(json['stackup']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'outlineX': serializer.toJson<double>(outlineX),
      'outlineY': serializer.toJson<double>(outlineY),
      'outlineWidth': serializer.toJson<double>(outlineWidth),
      'outlineHeight': serializer.toJson<double>(outlineHeight),
      'outlineKind': serializer.toJson<String>(outlineKind),
      'outlinePoints': serializer.toJson<String>(outlinePoints),
      'trackWidth': serializer.toJson<double>(trackWidth),
      'clearance': serializer.toJson<double>(clearance),
      'viaDiameter': serializer.toJson<double>(viaDiameter),
      'viaDrill': serializer.toJson<double>(viaDrill),
      'trackWidths': serializer.toJson<String>(trackWidths),
      'viaSizes': serializer.toJson<String>(viaSizes),
      'gridMm': serializer.toJson<double>(gridMm),
      'copperLayers': serializer.toJson<int>(copperLayers),
      'thickness': serializer.toJson<double>(thickness),
      'stackup': serializer.toJson<String>(stackup),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
    };
  }

  BoardRow copyWith({
    String? id,
    String? projectId,
    double? outlineX,
    double? outlineY,
    double? outlineWidth,
    double? outlineHeight,
    String? outlineKind,
    String? outlinePoints,
    double? trackWidth,
    double? clearance,
    double? viaDiameter,
    double? viaDrill,
    String? trackWidths,
    String? viaSizes,
    double? gridMm,
    int? copperLayers,
    double? thickness,
    String? stackup,
    DateTime? modifiedAt,
  }) => BoardRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    outlineX: outlineX ?? this.outlineX,
    outlineY: outlineY ?? this.outlineY,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    outlineHeight: outlineHeight ?? this.outlineHeight,
    outlineKind: outlineKind ?? this.outlineKind,
    outlinePoints: outlinePoints ?? this.outlinePoints,
    trackWidth: trackWidth ?? this.trackWidth,
    clearance: clearance ?? this.clearance,
    viaDiameter: viaDiameter ?? this.viaDiameter,
    viaDrill: viaDrill ?? this.viaDrill,
    trackWidths: trackWidths ?? this.trackWidths,
    viaSizes: viaSizes ?? this.viaSizes,
    gridMm: gridMm ?? this.gridMm,
    copperLayers: copperLayers ?? this.copperLayers,
    thickness: thickness ?? this.thickness,
    stackup: stackup ?? this.stackup,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
  BoardRow copyWithCompanion(BoardsCompanion data) {
    return BoardRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      outlineX: data.outlineX.present ? data.outlineX.value : this.outlineX,
      outlineY: data.outlineY.present ? data.outlineY.value : this.outlineY,
      outlineWidth: data.outlineWidth.present
          ? data.outlineWidth.value
          : this.outlineWidth,
      outlineHeight: data.outlineHeight.present
          ? data.outlineHeight.value
          : this.outlineHeight,
      outlineKind: data.outlineKind.present
          ? data.outlineKind.value
          : this.outlineKind,
      outlinePoints: data.outlinePoints.present
          ? data.outlinePoints.value
          : this.outlinePoints,
      trackWidth: data.trackWidth.present
          ? data.trackWidth.value
          : this.trackWidth,
      clearance: data.clearance.present ? data.clearance.value : this.clearance,
      viaDiameter: data.viaDiameter.present
          ? data.viaDiameter.value
          : this.viaDiameter,
      viaDrill: data.viaDrill.present ? data.viaDrill.value : this.viaDrill,
      trackWidths: data.trackWidths.present
          ? data.trackWidths.value
          : this.trackWidths,
      viaSizes: data.viaSizes.present ? data.viaSizes.value : this.viaSizes,
      gridMm: data.gridMm.present ? data.gridMm.value : this.gridMm,
      copperLayers: data.copperLayers.present
          ? data.copperLayers.value
          : this.copperLayers,
      thickness: data.thickness.present ? data.thickness.value : this.thickness,
      stackup: data.stackup.present ? data.stackup.value : this.stackup,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('outlineX: $outlineX, ')
          ..write('outlineY: $outlineY, ')
          ..write('outlineWidth: $outlineWidth, ')
          ..write('outlineHeight: $outlineHeight, ')
          ..write('outlineKind: $outlineKind, ')
          ..write('outlinePoints: $outlinePoints, ')
          ..write('trackWidth: $trackWidth, ')
          ..write('clearance: $clearance, ')
          ..write('viaDiameter: $viaDiameter, ')
          ..write('viaDrill: $viaDrill, ')
          ..write('trackWidths: $trackWidths, ')
          ..write('viaSizes: $viaSizes, ')
          ..write('gridMm: $gridMm, ')
          ..write('copperLayers: $copperLayers, ')
          ..write('thickness: $thickness, ')
          ..write('stackup: $stackup, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    outlineX,
    outlineY,
    outlineWidth,
    outlineHeight,
    outlineKind,
    outlinePoints,
    trackWidth,
    clearance,
    viaDiameter,
    viaDrill,
    trackWidths,
    viaSizes,
    gridMm,
    copperLayers,
    thickness,
    stackup,
    modifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.outlineX == this.outlineX &&
          other.outlineY == this.outlineY &&
          other.outlineWidth == this.outlineWidth &&
          other.outlineHeight == this.outlineHeight &&
          other.outlineKind == this.outlineKind &&
          other.outlinePoints == this.outlinePoints &&
          other.trackWidth == this.trackWidth &&
          other.clearance == this.clearance &&
          other.viaDiameter == this.viaDiameter &&
          other.viaDrill == this.viaDrill &&
          other.trackWidths == this.trackWidths &&
          other.viaSizes == this.viaSizes &&
          other.gridMm == this.gridMm &&
          other.copperLayers == this.copperLayers &&
          other.thickness == this.thickness &&
          other.stackup == this.stackup &&
          other.modifiedAt == this.modifiedAt);
}

class BoardsCompanion extends UpdateCompanion<BoardRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<double> outlineX;
  final Value<double> outlineY;
  final Value<double> outlineWidth;
  final Value<double> outlineHeight;
  final Value<String> outlineKind;
  final Value<String> outlinePoints;
  final Value<double> trackWidth;
  final Value<double> clearance;
  final Value<double> viaDiameter;
  final Value<double> viaDrill;
  final Value<String> trackWidths;
  final Value<String> viaSizes;
  final Value<double> gridMm;
  final Value<int> copperLayers;
  final Value<double> thickness;
  final Value<String> stackup;
  final Value<DateTime> modifiedAt;
  final Value<int> rowid;
  const BoardsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.outlineX = const Value.absent(),
    this.outlineY = const Value.absent(),
    this.outlineWidth = const Value.absent(),
    this.outlineHeight = const Value.absent(),
    this.outlineKind = const Value.absent(),
    this.outlinePoints = const Value.absent(),
    this.trackWidth = const Value.absent(),
    this.clearance = const Value.absent(),
    this.viaDiameter = const Value.absent(),
    this.viaDrill = const Value.absent(),
    this.trackWidths = const Value.absent(),
    this.viaSizes = const Value.absent(),
    this.gridMm = const Value.absent(),
    this.copperLayers = const Value.absent(),
    this.thickness = const Value.absent(),
    this.stackup = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardsCompanion.insert({
    required String id,
    required String projectId,
    this.outlineX = const Value.absent(),
    this.outlineY = const Value.absent(),
    this.outlineWidth = const Value.absent(),
    this.outlineHeight = const Value.absent(),
    this.outlineKind = const Value.absent(),
    this.outlinePoints = const Value.absent(),
    this.trackWidth = const Value.absent(),
    this.clearance = const Value.absent(),
    this.viaDiameter = const Value.absent(),
    this.viaDrill = const Value.absent(),
    this.trackWidths = const Value.absent(),
    this.viaSizes = const Value.absent(),
    this.gridMm = const Value.absent(),
    this.copperLayers = const Value.absent(),
    this.thickness = const Value.absent(),
    this.stackup = const Value.absent(),
    required DateTime modifiedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       modifiedAt = Value(modifiedAt);
  static Insertable<BoardRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<double>? outlineX,
    Expression<double>? outlineY,
    Expression<double>? outlineWidth,
    Expression<double>? outlineHeight,
    Expression<String>? outlineKind,
    Expression<String>? outlinePoints,
    Expression<double>? trackWidth,
    Expression<double>? clearance,
    Expression<double>? viaDiameter,
    Expression<double>? viaDrill,
    Expression<String>? trackWidths,
    Expression<String>? viaSizes,
    Expression<double>? gridMm,
    Expression<int>? copperLayers,
    Expression<double>? thickness,
    Expression<String>? stackup,
    Expression<DateTime>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (outlineX != null) 'outline_x': outlineX,
      if (outlineY != null) 'outline_y': outlineY,
      if (outlineWidth != null) 'outline_width': outlineWidth,
      if (outlineHeight != null) 'outline_height': outlineHeight,
      if (outlineKind != null) 'outline_kind': outlineKind,
      if (outlinePoints != null) 'outline_points': outlinePoints,
      if (trackWidth != null) 'track_width': trackWidth,
      if (clearance != null) 'clearance': clearance,
      if (viaDiameter != null) 'via_diameter': viaDiameter,
      if (viaDrill != null) 'via_drill': viaDrill,
      if (trackWidths != null) 'track_widths': trackWidths,
      if (viaSizes != null) 'via_sizes': viaSizes,
      if (gridMm != null) 'grid_mm': gridMm,
      if (copperLayers != null) 'copper_layers': copperLayers,
      if (thickness != null) 'thickness': thickness,
      if (stackup != null) 'stackup': stackup,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<double>? outlineX,
    Value<double>? outlineY,
    Value<double>? outlineWidth,
    Value<double>? outlineHeight,
    Value<String>? outlineKind,
    Value<String>? outlinePoints,
    Value<double>? trackWidth,
    Value<double>? clearance,
    Value<double>? viaDiameter,
    Value<double>? viaDrill,
    Value<String>? trackWidths,
    Value<String>? viaSizes,
    Value<double>? gridMm,
    Value<int>? copperLayers,
    Value<double>? thickness,
    Value<String>? stackup,
    Value<DateTime>? modifiedAt,
    Value<int>? rowid,
  }) {
    return BoardsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      outlineX: outlineX ?? this.outlineX,
      outlineY: outlineY ?? this.outlineY,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      outlineHeight: outlineHeight ?? this.outlineHeight,
      outlineKind: outlineKind ?? this.outlineKind,
      outlinePoints: outlinePoints ?? this.outlinePoints,
      trackWidth: trackWidth ?? this.trackWidth,
      clearance: clearance ?? this.clearance,
      viaDiameter: viaDiameter ?? this.viaDiameter,
      viaDrill: viaDrill ?? this.viaDrill,
      trackWidths: trackWidths ?? this.trackWidths,
      viaSizes: viaSizes ?? this.viaSizes,
      gridMm: gridMm ?? this.gridMm,
      copperLayers: copperLayers ?? this.copperLayers,
      thickness: thickness ?? this.thickness,
      stackup: stackup ?? this.stackup,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (outlineX.present) {
      map['outline_x'] = Variable<double>(outlineX.value);
    }
    if (outlineY.present) {
      map['outline_y'] = Variable<double>(outlineY.value);
    }
    if (outlineWidth.present) {
      map['outline_width'] = Variable<double>(outlineWidth.value);
    }
    if (outlineHeight.present) {
      map['outline_height'] = Variable<double>(outlineHeight.value);
    }
    if (outlineKind.present) {
      map['outline_kind'] = Variable<String>(outlineKind.value);
    }
    if (outlinePoints.present) {
      map['outline_points'] = Variable<String>(outlinePoints.value);
    }
    if (trackWidth.present) {
      map['track_width'] = Variable<double>(trackWidth.value);
    }
    if (clearance.present) {
      map['clearance'] = Variable<double>(clearance.value);
    }
    if (viaDiameter.present) {
      map['via_diameter'] = Variable<double>(viaDiameter.value);
    }
    if (viaDrill.present) {
      map['via_drill'] = Variable<double>(viaDrill.value);
    }
    if (trackWidths.present) {
      map['track_widths'] = Variable<String>(trackWidths.value);
    }
    if (viaSizes.present) {
      map['via_sizes'] = Variable<String>(viaSizes.value);
    }
    if (gridMm.present) {
      map['grid_mm'] = Variable<double>(gridMm.value);
    }
    if (copperLayers.present) {
      map['copper_layers'] = Variable<int>(copperLayers.value);
    }
    if (thickness.present) {
      map['thickness'] = Variable<double>(thickness.value);
    }
    if (stackup.present) {
      map['stackup'] = Variable<String>(stackup.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('outlineX: $outlineX, ')
          ..write('outlineY: $outlineY, ')
          ..write('outlineWidth: $outlineWidth, ')
          ..write('outlineHeight: $outlineHeight, ')
          ..write('outlineKind: $outlineKind, ')
          ..write('outlinePoints: $outlinePoints, ')
          ..write('trackWidth: $trackWidth, ')
          ..write('clearance: $clearance, ')
          ..write('viaDiameter: $viaDiameter, ')
          ..write('viaDrill: $viaDrill, ')
          ..write('trackWidths: $trackWidths, ')
          ..write('viaSizes: $viaSizes, ')
          ..write('gridMm: $gridMm, ')
          ..write('copperLayers: $copperLayers, ')
          ..write('thickness: $thickness, ')
          ..write('stackup: $stackup, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardFootprintsTable extends BoardFootprints
    with TableInfo<$BoardFootprintsTable, BoardFootprintRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardFootprintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _libIdMeta = const VerificationMeta('libId');
  @override
  late final GeneratedColumn<String> libId = GeneratedColumn<String>(
    'lib_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _flippedMeta = const VerificationMeta(
    'flipped',
  );
  @override
  late final GeneratedColumn<bool> flipped = GeneratedColumn<bool>(
    'flipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("flipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _placedMeta = const VerificationMeta('placed');
  @override
  late final GeneratedColumn<bool> placed = GeneratedColumn<bool>(
    'placed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("placed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _labelXMeta = const VerificationMeta('labelX');
  @override
  late final GeneratedColumn<double> labelX = GeneratedColumn<double>(
    'label_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelYMeta = const VerificationMeta('labelY');
  @override
  late final GeneratedColumn<double> labelY = GeneratedColumn<double>(
    'label_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelSizeMeta = const VerificationMeta(
    'labelSize',
  );
  @override
  late final GeneratedColumn<double> labelSize = GeneratedColumn<double>(
    'label_size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _labelHiddenMeta = const VerificationMeta(
    'labelHidden',
  );
  @override
  late final GeneratedColumn<bool> labelHidden = GeneratedColumn<bool>(
    'label_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("label_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    partId,
    libId,
    x,
    y,
    rotation,
    flipped,
    placed,
    labelX,
    labelY,
    labelSize,
    labelHidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_footprints';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardFootprintRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('lib_id')) {
      context.handle(
        _libIdMeta,
        libId.isAcceptableOrUnknown(data['lib_id']!, _libIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('flipped')) {
      context.handle(
        _flippedMeta,
        flipped.isAcceptableOrUnknown(data['flipped']!, _flippedMeta),
      );
    }
    if (data.containsKey('placed')) {
      context.handle(
        _placedMeta,
        placed.isAcceptableOrUnknown(data['placed']!, _placedMeta),
      );
    }
    if (data.containsKey('label_x')) {
      context.handle(
        _labelXMeta,
        labelX.isAcceptableOrUnknown(data['label_x']!, _labelXMeta),
      );
    }
    if (data.containsKey('label_y')) {
      context.handle(
        _labelYMeta,
        labelY.isAcceptableOrUnknown(data['label_y']!, _labelYMeta),
      );
    }
    if (data.containsKey('label_size')) {
      context.handle(
        _labelSizeMeta,
        labelSize.isAcceptableOrUnknown(data['label_size']!, _labelSizeMeta),
      );
    }
    if (data.containsKey('label_hidden')) {
      context.handle(
        _labelHiddenMeta,
        labelHidden.isAcceptableOrUnknown(
          data['label_hidden']!,
          _labelHiddenMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {partId},
  ];
  @override
  BoardFootprintRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardFootprintRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      libId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lib_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      flipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flipped'],
      )!,
      placed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}placed'],
      )!,
      labelX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_x'],
      ),
      labelY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_y'],
      ),
      labelSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_size'],
      )!,
      labelHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}label_hidden'],
      )!,
    );
  }

  @override
  $BoardFootprintsTable createAlias(String alias) {
    return $BoardFootprintsTable(attachedDatabase, alias);
  }
}

class BoardFootprintRow extends DataClass
    implements Insertable<BoardFootprintRow> {
  final String id;
  final String projectId;
  final String partId;

  /// `Resistor_SMD:R_0805_2012Metric`.
  final String libId;
  final double x;
  final double y;
  final double rotation;

  /// True when the component is mounted on the back of the board.
  final bool flipped;
  final bool placed;

  /// Where the reference designator sits once it has been moved, in the
  /// footprint's own frame — the frame KiCad writes it in, so it survives
  /// the part being rotated or flipped afterwards. Null leaves it where the
  /// footprint library put it.
  final double? labelX;
  final double? labelY;

  /// Designator text height, in millimetres.
  final double labelSize;

  /// Taken off the silkscreen. The part keeps its reference; the board just
  /// does not print it.
  final bool labelHidden;
  const BoardFootprintRow({
    required this.id,
    required this.projectId,
    required this.partId,
    required this.libId,
    required this.x,
    required this.y,
    required this.rotation,
    required this.flipped,
    required this.placed,
    this.labelX,
    this.labelY,
    required this.labelSize,
    required this.labelHidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['part_id'] = Variable<String>(partId);
    map['lib_id'] = Variable<String>(libId);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['rotation'] = Variable<double>(rotation);
    map['flipped'] = Variable<bool>(flipped);
    map['placed'] = Variable<bool>(placed);
    if (!nullToAbsent || labelX != null) {
      map['label_x'] = Variable<double>(labelX);
    }
    if (!nullToAbsent || labelY != null) {
      map['label_y'] = Variable<double>(labelY);
    }
    map['label_size'] = Variable<double>(labelSize);
    map['label_hidden'] = Variable<bool>(labelHidden);
    return map;
  }

  BoardFootprintsCompanion toCompanion(bool nullToAbsent) {
    return BoardFootprintsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      partId: Value(partId),
      libId: Value(libId),
      x: Value(x),
      y: Value(y),
      rotation: Value(rotation),
      flipped: Value(flipped),
      placed: Value(placed),
      labelX: labelX == null && nullToAbsent
          ? const Value.absent()
          : Value(labelX),
      labelY: labelY == null && nullToAbsent
          ? const Value.absent()
          : Value(labelY),
      labelSize: Value(labelSize),
      labelHidden: Value(labelHidden),
    );
  }

  factory BoardFootprintRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardFootprintRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      partId: serializer.fromJson<String>(json['partId']),
      libId: serializer.fromJson<String>(json['libId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      rotation: serializer.fromJson<double>(json['rotation']),
      flipped: serializer.fromJson<bool>(json['flipped']),
      placed: serializer.fromJson<bool>(json['placed']),
      labelX: serializer.fromJson<double?>(json['labelX']),
      labelY: serializer.fromJson<double?>(json['labelY']),
      labelSize: serializer.fromJson<double>(json['labelSize']),
      labelHidden: serializer.fromJson<bool>(json['labelHidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'partId': serializer.toJson<String>(partId),
      'libId': serializer.toJson<String>(libId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'rotation': serializer.toJson<double>(rotation),
      'flipped': serializer.toJson<bool>(flipped),
      'placed': serializer.toJson<bool>(placed),
      'labelX': serializer.toJson<double?>(labelX),
      'labelY': serializer.toJson<double?>(labelY),
      'labelSize': serializer.toJson<double>(labelSize),
      'labelHidden': serializer.toJson<bool>(labelHidden),
    };
  }

  BoardFootprintRow copyWith({
    String? id,
    String? projectId,
    String? partId,
    String? libId,
    double? x,
    double? y,
    double? rotation,
    bool? flipped,
    bool? placed,
    Value<double?> labelX = const Value.absent(),
    Value<double?> labelY = const Value.absent(),
    double? labelSize,
    bool? labelHidden,
  }) => BoardFootprintRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    partId: partId ?? this.partId,
    libId: libId ?? this.libId,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    flipped: flipped ?? this.flipped,
    placed: placed ?? this.placed,
    labelX: labelX.present ? labelX.value : this.labelX,
    labelY: labelY.present ? labelY.value : this.labelY,
    labelSize: labelSize ?? this.labelSize,
    labelHidden: labelHidden ?? this.labelHidden,
  );
  BoardFootprintRow copyWithCompanion(BoardFootprintsCompanion data) {
    return BoardFootprintRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      partId: data.partId.present ? data.partId.value : this.partId,
      libId: data.libId.present ? data.libId.value : this.libId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      flipped: data.flipped.present ? data.flipped.value : this.flipped,
      placed: data.placed.present ? data.placed.value : this.placed,
      labelX: data.labelX.present ? data.labelX.value : this.labelX,
      labelY: data.labelY.present ? data.labelY.value : this.labelY,
      labelSize: data.labelSize.present ? data.labelSize.value : this.labelSize,
      labelHidden: data.labelHidden.present
          ? data.labelHidden.value
          : this.labelHidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardFootprintRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('partId: $partId, ')
          ..write('libId: $libId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('flipped: $flipped, ')
          ..write('placed: $placed, ')
          ..write('labelX: $labelX, ')
          ..write('labelY: $labelY, ')
          ..write('labelSize: $labelSize, ')
          ..write('labelHidden: $labelHidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    partId,
    libId,
    x,
    y,
    rotation,
    flipped,
    placed,
    labelX,
    labelY,
    labelSize,
    labelHidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardFootprintRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.partId == this.partId &&
          other.libId == this.libId &&
          other.x == this.x &&
          other.y == this.y &&
          other.rotation == this.rotation &&
          other.flipped == this.flipped &&
          other.placed == this.placed &&
          other.labelX == this.labelX &&
          other.labelY == this.labelY &&
          other.labelSize == this.labelSize &&
          other.labelHidden == this.labelHidden);
}

class BoardFootprintsCompanion extends UpdateCompanion<BoardFootprintRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> partId;
  final Value<String> libId;
  final Value<double> x;
  final Value<double> y;
  final Value<double> rotation;
  final Value<bool> flipped;
  final Value<bool> placed;
  final Value<double?> labelX;
  final Value<double?> labelY;
  final Value<double> labelSize;
  final Value<bool> labelHidden;
  final Value<int> rowid;
  const BoardFootprintsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.partId = const Value.absent(),
    this.libId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.flipped = const Value.absent(),
    this.placed = const Value.absent(),
    this.labelX = const Value.absent(),
    this.labelY = const Value.absent(),
    this.labelSize = const Value.absent(),
    this.labelHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardFootprintsCompanion.insert({
    required String id,
    required String projectId,
    required String partId,
    required String libId,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.flipped = const Value.absent(),
    this.placed = const Value.absent(),
    this.labelX = const Value.absent(),
    this.labelY = const Value.absent(),
    this.labelSize = const Value.absent(),
    this.labelHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       partId = Value(partId),
       libId = Value(libId);
  static Insertable<BoardFootprintRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? partId,
    Expression<String>? libId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? rotation,
    Expression<bool>? flipped,
    Expression<bool>? placed,
    Expression<double>? labelX,
    Expression<double>? labelY,
    Expression<double>? labelSize,
    Expression<bool>? labelHidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (partId != null) 'part_id': partId,
      if (libId != null) 'lib_id': libId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (rotation != null) 'rotation': rotation,
      if (flipped != null) 'flipped': flipped,
      if (placed != null) 'placed': placed,
      if (labelX != null) 'label_x': labelX,
      if (labelY != null) 'label_y': labelY,
      if (labelSize != null) 'label_size': labelSize,
      if (labelHidden != null) 'label_hidden': labelHidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardFootprintsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? partId,
    Value<String>? libId,
    Value<double>? x,
    Value<double>? y,
    Value<double>? rotation,
    Value<bool>? flipped,
    Value<bool>? placed,
    Value<double?>? labelX,
    Value<double?>? labelY,
    Value<double>? labelSize,
    Value<bool>? labelHidden,
    Value<int>? rowid,
  }) {
    return BoardFootprintsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      partId: partId ?? this.partId,
      libId: libId ?? this.libId,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      flipped: flipped ?? this.flipped,
      placed: placed ?? this.placed,
      labelX: labelX ?? this.labelX,
      labelY: labelY ?? this.labelY,
      labelSize: labelSize ?? this.labelSize,
      labelHidden: labelHidden ?? this.labelHidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (libId.present) {
      map['lib_id'] = Variable<String>(libId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (flipped.present) {
      map['flipped'] = Variable<bool>(flipped.value);
    }
    if (placed.present) {
      map['placed'] = Variable<bool>(placed.value);
    }
    if (labelX.present) {
      map['label_x'] = Variable<double>(labelX.value);
    }
    if (labelY.present) {
      map['label_y'] = Variable<double>(labelY.value);
    }
    if (labelSize.present) {
      map['label_size'] = Variable<double>(labelSize.value);
    }
    if (labelHidden.present) {
      map['label_hidden'] = Variable<bool>(labelHidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardFootprintsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('partId: $partId, ')
          ..write('libId: $libId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('flipped: $flipped, ')
          ..write('placed: $placed, ')
          ..write('labelX: $labelX, ')
          ..write('labelY: $labelY, ')
          ..write('labelSize: $labelSize, ')
          ..write('labelHidden: $labelHidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardTracksTable extends BoardTracks
    with TableInfo<$BoardTracksTable, BoardTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _netIdMeta = const VerificationMeta('netId');
  @override
  late final GeneratedColumn<String> netId = GeneratedColumn<String>(
    'net_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startXMeta = const VerificationMeta('startX');
  @override
  late final GeneratedColumn<double> startX = GeneratedColumn<double>(
    'start_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startYMeta = const VerificationMeta('startY');
  @override
  late final GeneratedColumn<double> startY = GeneratedColumn<double>(
    'start_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endXMeta = const VerificationMeta('endX');
  @override
  late final GeneratedColumn<double> endX = GeneratedColumn<double>(
    'end_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endYMeta = const VerificationMeta('endY');
  @override
  late final GeneratedColumn<double> endY = GeneratedColumn<double>(
    'end_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.25),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    netId,
    layer,
    startX,
    startY,
    endX,
    endY,
    width,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardTrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('net_id')) {
      context.handle(
        _netIdMeta,
        netId.isAcceptableOrUnknown(data['net_id']!, _netIdMeta),
      );
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('start_x')) {
      context.handle(
        _startXMeta,
        startX.isAcceptableOrUnknown(data['start_x']!, _startXMeta),
      );
    } else if (isInserting) {
      context.missing(_startXMeta);
    }
    if (data.containsKey('start_y')) {
      context.handle(
        _startYMeta,
        startY.isAcceptableOrUnknown(data['start_y']!, _startYMeta),
      );
    } else if (isInserting) {
      context.missing(_startYMeta);
    }
    if (data.containsKey('end_x')) {
      context.handle(
        _endXMeta,
        endX.isAcceptableOrUnknown(data['end_x']!, _endXMeta),
      );
    } else if (isInserting) {
      context.missing(_endXMeta);
    }
    if (data.containsKey('end_y')) {
      context.handle(
        _endYMeta,
        endY.isAcceptableOrUnknown(data['end_y']!, _endYMeta),
      );
    } else if (isInserting) {
      context.missing(_endYMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardTrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardTrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      netId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_id'],
      ),
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      startX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_x'],
      )!,
      startY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_y'],
      )!,
      endX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_x'],
      )!,
      endY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
    );
  }

  @override
  $BoardTracksTable createAlias(String alias) {
    return $BoardTracksTable(attachedDatabase, alias);
  }
}

class BoardTrackRow extends DataClass implements Insertable<BoardTrackRow> {
  final String id;
  final String projectId;

  /// Null for a segment drawn before it was clear what net it belongs to.
  final String? netId;

  /// `F.Cu` or `B.Cu`.
  final String layer;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double width;
  const BoardTrackRow({
    required this.id,
    required this.projectId,
    this.netId,
    required this.layer,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.width,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || netId != null) {
      map['net_id'] = Variable<String>(netId);
    }
    map['layer'] = Variable<String>(layer);
    map['start_x'] = Variable<double>(startX);
    map['start_y'] = Variable<double>(startY);
    map['end_x'] = Variable<double>(endX);
    map['end_y'] = Variable<double>(endY);
    map['width'] = Variable<double>(width);
    return map;
  }

  BoardTracksCompanion toCompanion(bool nullToAbsent) {
    return BoardTracksCompanion(
      id: Value(id),
      projectId: Value(projectId),
      netId: netId == null && nullToAbsent
          ? const Value.absent()
          : Value(netId),
      layer: Value(layer),
      startX: Value(startX),
      startY: Value(startY),
      endX: Value(endX),
      endY: Value(endY),
      width: Value(width),
    );
  }

  factory BoardTrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardTrackRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      netId: serializer.fromJson<String?>(json['netId']),
      layer: serializer.fromJson<String>(json['layer']),
      startX: serializer.fromJson<double>(json['startX']),
      startY: serializer.fromJson<double>(json['startY']),
      endX: serializer.fromJson<double>(json['endX']),
      endY: serializer.fromJson<double>(json['endY']),
      width: serializer.fromJson<double>(json['width']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'netId': serializer.toJson<String?>(netId),
      'layer': serializer.toJson<String>(layer),
      'startX': serializer.toJson<double>(startX),
      'startY': serializer.toJson<double>(startY),
      'endX': serializer.toJson<double>(endX),
      'endY': serializer.toJson<double>(endY),
      'width': serializer.toJson<double>(width),
    };
  }

  BoardTrackRow copyWith({
    String? id,
    String? projectId,
    Value<String?> netId = const Value.absent(),
    String? layer,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    double? width,
  }) => BoardTrackRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    netId: netId.present ? netId.value : this.netId,
    layer: layer ?? this.layer,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    endX: endX ?? this.endX,
    endY: endY ?? this.endY,
    width: width ?? this.width,
  );
  BoardTrackRow copyWithCompanion(BoardTracksCompanion data) {
    return BoardTrackRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      netId: data.netId.present ? data.netId.value : this.netId,
      layer: data.layer.present ? data.layer.value : this.layer,
      startX: data.startX.present ? data.startX.value : this.startX,
      startY: data.startY.present ? data.startY.value : this.startY,
      endX: data.endX.present ? data.endX.value : this.endX,
      endY: data.endY.present ? data.endY.value : this.endY,
      width: data.width.present ? data.width.value : this.width,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardTrackRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('layer: $layer, ')
          ..write('startX: $startX, ')
          ..write('startY: $startY, ')
          ..write('endX: $endX, ')
          ..write('endY: $endY, ')
          ..write('width: $width')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    netId,
    layer,
    startX,
    startY,
    endX,
    endY,
    width,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardTrackRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.netId == this.netId &&
          other.layer == this.layer &&
          other.startX == this.startX &&
          other.startY == this.startY &&
          other.endX == this.endX &&
          other.endY == this.endY &&
          other.width == this.width);
}

class BoardTracksCompanion extends UpdateCompanion<BoardTrackRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> netId;
  final Value<String> layer;
  final Value<double> startX;
  final Value<double> startY;
  final Value<double> endX;
  final Value<double> endY;
  final Value<double> width;
  final Value<int> rowid;
  const BoardTracksCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.netId = const Value.absent(),
    this.layer = const Value.absent(),
    this.startX = const Value.absent(),
    this.startY = const Value.absent(),
    this.endX = const Value.absent(),
    this.endY = const Value.absent(),
    this.width = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardTracksCompanion.insert({
    required String id,
    required String projectId,
    this.netId = const Value.absent(),
    required String layer,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    this.width = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       layer = Value(layer),
       startX = Value(startX),
       startY = Value(startY),
       endX = Value(endX),
       endY = Value(endY);
  static Insertable<BoardTrackRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? netId,
    Expression<String>? layer,
    Expression<double>? startX,
    Expression<double>? startY,
    Expression<double>? endX,
    Expression<double>? endY,
    Expression<double>? width,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (netId != null) 'net_id': netId,
      if (layer != null) 'layer': layer,
      if (startX != null) 'start_x': startX,
      if (startY != null) 'start_y': startY,
      if (endX != null) 'end_x': endX,
      if (endY != null) 'end_y': endY,
      if (width != null) 'width': width,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? netId,
    Value<String>? layer,
    Value<double>? startX,
    Value<double>? startY,
    Value<double>? endX,
    Value<double>? endY,
    Value<double>? width,
    Value<int>? rowid,
  }) {
    return BoardTracksCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      netId: netId ?? this.netId,
      layer: layer ?? this.layer,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      width: width ?? this.width,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (netId.present) {
      map['net_id'] = Variable<String>(netId.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (startX.present) {
      map['start_x'] = Variable<double>(startX.value);
    }
    if (startY.present) {
      map['start_y'] = Variable<double>(startY.value);
    }
    if (endX.present) {
      map['end_x'] = Variable<double>(endX.value);
    }
    if (endY.present) {
      map['end_y'] = Variable<double>(endY.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardTracksCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('layer: $layer, ')
          ..write('startX: $startX, ')
          ..write('startY: $startY, ')
          ..write('endX: $endX, ')
          ..write('endY: $endY, ')
          ..write('width: $width, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardViasTable extends BoardVias
    with TableInfo<$BoardViasTable, BoardViaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardViasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _netIdMeta = const VerificationMeta('netId');
  @override
  late final GeneratedColumn<String> netId = GeneratedColumn<String>(
    'net_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diameterMeta = const VerificationMeta(
    'diameter',
  );
  @override
  late final GeneratedColumn<double> diameter = GeneratedColumn<double>(
    'diameter',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.8),
  );
  static const VerificationMeta _drillMeta = const VerificationMeta('drill');
  @override
  late final GeneratedColumn<double> drill = GeneratedColumn<double>(
    'drill',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.4),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    netId,
    x,
    y,
    diameter,
    drill,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_vias';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardViaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('net_id')) {
      context.handle(
        _netIdMeta,
        netId.isAcceptableOrUnknown(data['net_id']!, _netIdMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('diameter')) {
      context.handle(
        _diameterMeta,
        diameter.isAcceptableOrUnknown(data['diameter']!, _diameterMeta),
      );
    }
    if (data.containsKey('drill')) {
      context.handle(
        _drillMeta,
        drill.isAcceptableOrUnknown(data['drill']!, _drillMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardViaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardViaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      netId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_id'],
      ),
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      diameter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diameter'],
      )!,
      drill: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}drill'],
      )!,
    );
  }

  @override
  $BoardViasTable createAlias(String alias) {
    return $BoardViasTable(attachedDatabase, alias);
  }
}

class BoardViaRow extends DataClass implements Insertable<BoardViaRow> {
  final String id;
  final String projectId;
  final String? netId;
  final double x;
  final double y;
  final double diameter;
  final double drill;
  const BoardViaRow({
    required this.id,
    required this.projectId,
    this.netId,
    required this.x,
    required this.y,
    required this.diameter,
    required this.drill,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || netId != null) {
      map['net_id'] = Variable<String>(netId);
    }
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['diameter'] = Variable<double>(diameter);
    map['drill'] = Variable<double>(drill);
    return map;
  }

  BoardViasCompanion toCompanion(bool nullToAbsent) {
    return BoardViasCompanion(
      id: Value(id),
      projectId: Value(projectId),
      netId: netId == null && nullToAbsent
          ? const Value.absent()
          : Value(netId),
      x: Value(x),
      y: Value(y),
      diameter: Value(diameter),
      drill: Value(drill),
    );
  }

  factory BoardViaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardViaRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      netId: serializer.fromJson<String?>(json['netId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      diameter: serializer.fromJson<double>(json['diameter']),
      drill: serializer.fromJson<double>(json['drill']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'netId': serializer.toJson<String?>(netId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'diameter': serializer.toJson<double>(diameter),
      'drill': serializer.toJson<double>(drill),
    };
  }

  BoardViaRow copyWith({
    String? id,
    String? projectId,
    Value<String?> netId = const Value.absent(),
    double? x,
    double? y,
    double? diameter,
    double? drill,
  }) => BoardViaRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    netId: netId.present ? netId.value : this.netId,
    x: x ?? this.x,
    y: y ?? this.y,
    diameter: diameter ?? this.diameter,
    drill: drill ?? this.drill,
  );
  BoardViaRow copyWithCompanion(BoardViasCompanion data) {
    return BoardViaRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      netId: data.netId.present ? data.netId.value : this.netId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      diameter: data.diameter.present ? data.diameter.value : this.diameter,
      drill: data.drill.present ? data.drill.value : this.drill,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardViaRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('diameter: $diameter, ')
          ..write('drill: $drill')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, netId, x, y, diameter, drill);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardViaRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.netId == this.netId &&
          other.x == this.x &&
          other.y == this.y &&
          other.diameter == this.diameter &&
          other.drill == this.drill);
}

class BoardViasCompanion extends UpdateCompanion<BoardViaRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> netId;
  final Value<double> x;
  final Value<double> y;
  final Value<double> diameter;
  final Value<double> drill;
  final Value<int> rowid;
  const BoardViasCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.netId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.diameter = const Value.absent(),
    this.drill = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardViasCompanion.insert({
    required String id,
    required String projectId,
    this.netId = const Value.absent(),
    required double x,
    required double y,
    this.diameter = const Value.absent(),
    this.drill = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       x = Value(x),
       y = Value(y);
  static Insertable<BoardViaRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? netId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? diameter,
    Expression<double>? drill,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (netId != null) 'net_id': netId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (diameter != null) 'diameter': diameter,
      if (drill != null) 'drill': drill,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardViasCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? netId,
    Value<double>? x,
    Value<double>? y,
    Value<double>? diameter,
    Value<double>? drill,
    Value<int>? rowid,
  }) {
    return BoardViasCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      netId: netId ?? this.netId,
      x: x ?? this.x,
      y: y ?? this.y,
      diameter: diameter ?? this.diameter,
      drill: drill ?? this.drill,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (netId.present) {
      map['net_id'] = Variable<String>(netId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (diameter.present) {
      map['diameter'] = Variable<double>(diameter.value);
    }
    if (drill.present) {
      map['drill'] = Variable<double>(drill.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardViasCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('diameter: $diameter, ')
          ..write('drill: $drill, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardEdgesTable extends BoardEdges
    with TableInfo<$BoardEdgesTable, BoardEdgeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<String> points = GeneratedColumn<String>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    kind,
    points,
    width,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardEdgeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardEdgeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardEdgeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BoardEdgesTable createAlias(String alias) {
    return $BoardEdgesTable(attachedDatabase, alias);
  }
}

class BoardEdgeRow extends DataClass implements Insertable<BoardEdgeRow> {
  final String id;
  final String projectId;

  /// `line`, `arc`, `rectangle`, `circle` or `polygon`.
  final String kind;

  /// Points as `x,y` pairs separated by spaces.
  final String points;
  final double width;
  final DateTime createdAt;
  const BoardEdgeRow({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.points,
    required this.width,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['kind'] = Variable<String>(kind);
    map['points'] = Variable<String>(points);
    map['width'] = Variable<double>(width);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BoardEdgesCompanion toCompanion(bool nullToAbsent) {
    return BoardEdgesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      kind: Value(kind),
      points: Value(points),
      width: Value(width),
      createdAt: Value(createdAt),
    );
  }

  factory BoardEdgeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardEdgeRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      points: serializer.fromJson<String>(json['points']),
      width: serializer.fromJson<double>(json['width']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'kind': serializer.toJson<String>(kind),
      'points': serializer.toJson<String>(points),
      'width': serializer.toJson<double>(width),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BoardEdgeRow copyWith({
    String? id,
    String? projectId,
    String? kind,
    String? points,
    double? width,
    DateTime? createdAt,
  }) => BoardEdgeRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    kind: kind ?? this.kind,
    points: points ?? this.points,
    width: width ?? this.width,
    createdAt: createdAt ?? this.createdAt,
  );
  BoardEdgeRow copyWithCompanion(BoardEdgesCompanion data) {
    return BoardEdgeRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      points: data.points.present ? data.points.value : this.points,
      width: data.width.present ? data.width.value : this.width,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardEdgeRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('points: $points, ')
          ..write('width: $width, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, kind, points, width, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardEdgeRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.points == this.points &&
          other.width == this.width &&
          other.createdAt == this.createdAt);
}

class BoardEdgesCompanion extends UpdateCompanion<BoardEdgeRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> kind;
  final Value<String> points;
  final Value<double> width;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BoardEdgesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.points = const Value.absent(),
    this.width = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardEdgesCompanion.insert({
    required String id,
    required String projectId,
    required String kind,
    this.points = const Value.absent(),
    this.width = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<BoardEdgeRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? kind,
    Expression<String>? points,
    Expression<double>? width,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (points != null) 'points': points,
      if (width != null) 'width': width,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardEdgesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? kind,
    Value<String>? points,
    Value<double>? width,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BoardEdgesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      points: points ?? this.points,
      width: width ?? this.width,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(points.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardEdgesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('points: $points, ')
          ..write('width: $width, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardZonesTable extends BoardZones
    with TableInfo<$BoardZonesTable, BoardZoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _netIdMeta = const VerificationMeta('netId');
  @override
  late final GeneratedColumn<String> netId = GeneratedColumn<String>(
    'net_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _netNameMeta = const VerificationMeta(
    'netName',
  );
  @override
  late final GeneratedColumn<String> netName = GeneratedColumn<String>(
    'net_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<String> points = GeneratedColumn<String>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _clearanceMeta = const VerificationMeta(
    'clearance',
  );
  @override
  late final GeneratedColumn<double> clearance = GeneratedColumn<double>(
    'clearance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _minThicknessMeta = const VerificationMeta(
    'minThickness',
  );
  @override
  late final GeneratedColumn<double> minThickness = GeneratedColumn<double>(
    'min_thickness',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.25),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    netId,
    netName,
    layer,
    points,
    clearance,
    minThickness,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardZoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('net_id')) {
      context.handle(
        _netIdMeta,
        netId.isAcceptableOrUnknown(data['net_id']!, _netIdMeta),
      );
    }
    if (data.containsKey('net_name')) {
      context.handle(
        _netNameMeta,
        netName.isAcceptableOrUnknown(data['net_name']!, _netNameMeta),
      );
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('clearance')) {
      context.handle(
        _clearanceMeta,
        clearance.isAcceptableOrUnknown(data['clearance']!, _clearanceMeta),
      );
    }
    if (data.containsKey('min_thickness')) {
      context.handle(
        _minThicknessMeta,
        minThickness.isAcceptableOrUnknown(
          data['min_thickness']!,
          _minThicknessMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardZoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardZoneRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      netId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_id'],
      ),
      netName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_name'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points'],
      )!,
      clearance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}clearance'],
      )!,
      minThickness: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_thickness'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BoardZonesTable createAlias(String alias) {
    return $BoardZonesTable(attachedDatabase, alias);
  }
}

class BoardZoneRow extends DataClass implements Insertable<BoardZoneRow> {
  final String id;
  final String projectId;

  /// The net poured into it. Null is a legal unconnected pour, and losing
  /// the net to a deletion leaves one rather than deleting the zone.
  final String? netId;

  /// The net's name as drawn, kept so a pour still says what it is after
  /// its net has gone.
  final String netName;

  /// `F.Cu` or `B.Cu`.
  final String layer;

  /// Outline vertices as `x,y` pairs separated by spaces.
  final String points;
  final double clearance;
  final double minThickness;
  final DateTime createdAt;
  const BoardZoneRow({
    required this.id,
    required this.projectId,
    this.netId,
    required this.netName,
    required this.layer,
    required this.points,
    required this.clearance,
    required this.minThickness,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || netId != null) {
      map['net_id'] = Variable<String>(netId);
    }
    map['net_name'] = Variable<String>(netName);
    map['layer'] = Variable<String>(layer);
    map['points'] = Variable<String>(points);
    map['clearance'] = Variable<double>(clearance);
    map['min_thickness'] = Variable<double>(minThickness);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BoardZonesCompanion toCompanion(bool nullToAbsent) {
    return BoardZonesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      netId: netId == null && nullToAbsent
          ? const Value.absent()
          : Value(netId),
      netName: Value(netName),
      layer: Value(layer),
      points: Value(points),
      clearance: Value(clearance),
      minThickness: Value(minThickness),
      createdAt: Value(createdAt),
    );
  }

  factory BoardZoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardZoneRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      netId: serializer.fromJson<String?>(json['netId']),
      netName: serializer.fromJson<String>(json['netName']),
      layer: serializer.fromJson<String>(json['layer']),
      points: serializer.fromJson<String>(json['points']),
      clearance: serializer.fromJson<double>(json['clearance']),
      minThickness: serializer.fromJson<double>(json['minThickness']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'netId': serializer.toJson<String?>(netId),
      'netName': serializer.toJson<String>(netName),
      'layer': serializer.toJson<String>(layer),
      'points': serializer.toJson<String>(points),
      'clearance': serializer.toJson<double>(clearance),
      'minThickness': serializer.toJson<double>(minThickness),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BoardZoneRow copyWith({
    String? id,
    String? projectId,
    Value<String?> netId = const Value.absent(),
    String? netName,
    String? layer,
    String? points,
    double? clearance,
    double? minThickness,
    DateTime? createdAt,
  }) => BoardZoneRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    netId: netId.present ? netId.value : this.netId,
    netName: netName ?? this.netName,
    layer: layer ?? this.layer,
    points: points ?? this.points,
    clearance: clearance ?? this.clearance,
    minThickness: minThickness ?? this.minThickness,
    createdAt: createdAt ?? this.createdAt,
  );
  BoardZoneRow copyWithCompanion(BoardZonesCompanion data) {
    return BoardZoneRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      netId: data.netId.present ? data.netId.value : this.netId,
      netName: data.netName.present ? data.netName.value : this.netName,
      layer: data.layer.present ? data.layer.value : this.layer,
      points: data.points.present ? data.points.value : this.points,
      clearance: data.clearance.present ? data.clearance.value : this.clearance,
      minThickness: data.minThickness.present
          ? data.minThickness.value
          : this.minThickness,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardZoneRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('netName: $netName, ')
          ..write('layer: $layer, ')
          ..write('points: $points, ')
          ..write('clearance: $clearance, ')
          ..write('minThickness: $minThickness, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    netId,
    netName,
    layer,
    points,
    clearance,
    minThickness,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardZoneRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.netId == this.netId &&
          other.netName == this.netName &&
          other.layer == this.layer &&
          other.points == this.points &&
          other.clearance == this.clearance &&
          other.minThickness == this.minThickness &&
          other.createdAt == this.createdAt);
}

class BoardZonesCompanion extends UpdateCompanion<BoardZoneRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> netId;
  final Value<String> netName;
  final Value<String> layer;
  final Value<String> points;
  final Value<double> clearance;
  final Value<double> minThickness;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BoardZonesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.netId = const Value.absent(),
    this.netName = const Value.absent(),
    this.layer = const Value.absent(),
    this.points = const Value.absent(),
    this.clearance = const Value.absent(),
    this.minThickness = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardZonesCompanion.insert({
    required String id,
    required String projectId,
    this.netId = const Value.absent(),
    this.netName = const Value.absent(),
    required String layer,
    this.points = const Value.absent(),
    this.clearance = const Value.absent(),
    this.minThickness = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       layer = Value(layer),
       createdAt = Value(createdAt);
  static Insertable<BoardZoneRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? netId,
    Expression<String>? netName,
    Expression<String>? layer,
    Expression<String>? points,
    Expression<double>? clearance,
    Expression<double>? minThickness,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (netId != null) 'net_id': netId,
      if (netName != null) 'net_name': netName,
      if (layer != null) 'layer': layer,
      if (points != null) 'points': points,
      if (clearance != null) 'clearance': clearance,
      if (minThickness != null) 'min_thickness': minThickness,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardZonesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? netId,
    Value<String>? netName,
    Value<String>? layer,
    Value<String>? points,
    Value<double>? clearance,
    Value<double>? minThickness,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BoardZonesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      netId: netId ?? this.netId,
      netName: netName ?? this.netName,
      layer: layer ?? this.layer,
      points: points ?? this.points,
      clearance: clearance ?? this.clearance,
      minThickness: minThickness ?? this.minThickness,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (netId.present) {
      map['net_id'] = Variable<String>(netId.value);
    }
    if (netName.present) {
      map['net_name'] = Variable<String>(netName.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(points.value);
    }
    if (clearance.present) {
      map['clearance'] = Variable<double>(clearance.value);
    }
    if (minThickness.present) {
      map['min_thickness'] = Variable<double>(minThickness.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardZonesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('netId: $netId, ')
          ..write('netName: $netName, ')
          ..write('layer: $layer, ')
          ..write('points: $points, ')
          ..write('clearance: $clearance, ')
          ..write('minThickness: $minThickness, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardTextsTable extends BoardTexts
    with TableInfo<$BoardTextsTable, BoardTextRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardTextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<double> size = GeneratedColumn<double>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    content,
    x,
    y,
    rotation,
    size,
    layer,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_texts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardTextRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardTextRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardTextRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}size'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BoardTextsTable createAlias(String alias) {
    return $BoardTextsTable(attachedDatabase, alias);
  }
}

class BoardTextRow extends DataClass implements Insertable<BoardTextRow> {
  final String id;
  final String projectId;
  final String content;
  final double x;
  final double y;
  final double rotation;
  final double size;

  /// `F.SilkS` or `B.SilkS`.
  final String layer;
  final DateTime createdAt;
  const BoardTextRow({
    required this.id,
    required this.projectId,
    required this.content,
    required this.x,
    required this.y,
    required this.rotation,
    required this.size,
    required this.layer,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['content'] = Variable<String>(content);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['rotation'] = Variable<double>(rotation);
    map['size'] = Variable<double>(size);
    map['layer'] = Variable<String>(layer);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BoardTextsCompanion toCompanion(bool nullToAbsent) {
    return BoardTextsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      content: Value(content),
      x: Value(x),
      y: Value(y),
      rotation: Value(rotation),
      size: Value(size),
      layer: Value(layer),
      createdAt: Value(createdAt),
    );
  }

  factory BoardTextRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardTextRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      content: serializer.fromJson<String>(json['content']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      rotation: serializer.fromJson<double>(json['rotation']),
      size: serializer.fromJson<double>(json['size']),
      layer: serializer.fromJson<String>(json['layer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'content': serializer.toJson<String>(content),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'rotation': serializer.toJson<double>(rotation),
      'size': serializer.toJson<double>(size),
      'layer': serializer.toJson<String>(layer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BoardTextRow copyWith({
    String? id,
    String? projectId,
    String? content,
    double? x,
    double? y,
    double? rotation,
    double? size,
    String? layer,
    DateTime? createdAt,
  }) => BoardTextRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    content: content ?? this.content,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    size: size ?? this.size,
    layer: layer ?? this.layer,
    createdAt: createdAt ?? this.createdAt,
  );
  BoardTextRow copyWithCompanion(BoardTextsCompanion data) {
    return BoardTextRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      content: data.content.present ? data.content.value : this.content,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      size: data.size.present ? data.size.value : this.size,
      layer: data.layer.present ? data.layer.value : this.layer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardTextRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('content: $content, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('size: $size, ')
          ..write('layer: $layer, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    content,
    x,
    y,
    rotation,
    size,
    layer,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardTextRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.content == this.content &&
          other.x == this.x &&
          other.y == this.y &&
          other.rotation == this.rotation &&
          other.size == this.size &&
          other.layer == this.layer &&
          other.createdAt == this.createdAt);
}

class BoardTextsCompanion extends UpdateCompanion<BoardTextRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> content;
  final Value<double> x;
  final Value<double> y;
  final Value<double> rotation;
  final Value<double> size;
  final Value<String> layer;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BoardTextsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.content = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.rotation = const Value.absent(),
    this.size = const Value.absent(),
    this.layer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardTextsCompanion.insert({
    required String id,
    required String projectId,
    required String content,
    required double x,
    required double y,
    this.rotation = const Value.absent(),
    this.size = const Value.absent(),
    required String layer,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       content = Value(content),
       x = Value(x),
       y = Value(y),
       layer = Value(layer),
       createdAt = Value(createdAt);
  static Insertable<BoardTextRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? content,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? rotation,
    Expression<double>? size,
    Expression<String>? layer,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (content != null) 'content': content,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (rotation != null) 'rotation': rotation,
      if (size != null) 'size': size,
      if (layer != null) 'layer': layer,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardTextsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? content,
    Value<double>? x,
    Value<double>? y,
    Value<double>? rotation,
    Value<double>? size,
    Value<String>? layer,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BoardTextsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      size: size ?? this.size,
      layer: layer ?? this.layer,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (size.present) {
      map['size'] = Variable<double>(size.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardTextsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('content: $content, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('rotation: $rotation, ')
          ..write('size: $size, ')
          ..write('layer: $layer, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) =>
      AppSettingRow(key: key ?? this.key, value: value ?? this.value);
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectSnapshotsTable extends ProjectSnapshots
    with TableInfo<$ProjectSnapshotsTable, ProjectSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _automaticMeta = const VerificationMeta(
    'automatic',
  );
  @override
  late final GeneratedColumn<bool> automatic = GeneratedColumn<bool>(
    'automatic',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("automatic" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    automatic,
    data,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('automatic')) {
      context.handle(
        _automaticMeta,
        automatic.isAcceptableOrUnknown(data['automatic']!, _automaticMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      automatic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProjectSnapshotsTable createAlias(String alias) {
    return $ProjectSnapshotsTable(attachedDatabase, alias);
  }
}

class ProjectSnapshotRow extends DataClass
    implements Insertable<ProjectSnapshotRow> {
  final String id;
  final String projectId;
  final String name;

  /// Taken by the app rather than the user — before a restore, say.
  final bool automatic;

  /// The project archive, as JSON.
  final String data;
  final DateTime createdAt;
  const ProjectSnapshotRow({
    required this.id,
    required this.projectId,
    required this.name,
    required this.automatic,
    required this.data,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['automatic'] = Variable<bool>(automatic);
    map['data'] = Variable<String>(data);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ProjectSnapshotsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      automatic: Value(automatic),
      data: Value(data),
      createdAt: Value(createdAt),
    );
  }

  factory ProjectSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSnapshotRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      automatic: serializer.fromJson<bool>(json['automatic']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'automatic': serializer.toJson<bool>(automatic),
      'data': serializer.toJson<String>(data),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProjectSnapshotRow copyWith({
    String? id,
    String? projectId,
    String? name,
    bool? automatic,
    String? data,
    DateTime? createdAt,
  }) => ProjectSnapshotRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    automatic: automatic ?? this.automatic,
    data: data ?? this.data,
    createdAt: createdAt ?? this.createdAt,
  );
  ProjectSnapshotRow copyWithCompanion(ProjectSnapshotsCompanion data) {
    return ProjectSnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      automatic: data.automatic.present ? data.automatic.value : this.automatic,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSnapshotRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('automatic: $automatic, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, name, automatic, data, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSnapshotRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.automatic == this.automatic &&
          other.data == this.data &&
          other.createdAt == this.createdAt);
}

class ProjectSnapshotsCompanion extends UpdateCompanion<ProjectSnapshotRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<bool> automatic;
  final Value<String> data;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProjectSnapshotsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.automatic = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSnapshotsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    this.automatic = const Value.absent(),
    required String data,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       name = Value(name),
       data = Value(data),
       createdAt = Value(createdAt);
  static Insertable<ProjectSnapshotRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<bool>? automatic,
    Expression<String>? data,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (automatic != null) 'automatic': automatic,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? name,
    Value<bool>? automatic,
    Value<String>? data,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProjectSnapshotsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      automatic: automatic ?? this.automatic,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (automatic.present) {
      map['automatic'] = Variable<bool>(automatic.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('automatic: $automatic, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchematicNotesTable extends SchematicNotes
    with TableInfo<$SchematicNotesTable, SchematicNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchematicNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<double> size = GeneratedColumn<double>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.27),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    kind,
    content,
    x,
    y,
    width,
    height,
    size,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schematic_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchematicNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SchematicNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchematicNoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SchematicNotesTable createAlias(String alias) {
    return $SchematicNotesTable(attachedDatabase, alias);
  }
}

class SchematicNoteRow extends DataClass
    implements Insertable<SchematicNoteRow> {
  final String id;
  final String projectId;

  /// `text` or `box`.
  final String kind;

  /// What the note says; a box's caption.
  final String content;

  /// Top-left corner, in sheet millimetres.
  final double x;
  final double y;

  /// A box's size; zero for a text note.
  final double width;
  final double height;

  /// Character height, in millimetres.
  final double size;
  final DateTime createdAt;
  const SchematicNoteRow({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.content,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.size,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['size'] = Variable<double>(size);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SchematicNotesCompanion toCompanion(bool nullToAbsent) {
    return SchematicNotesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      kind: Value(kind),
      content: Value(content),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      size: Value(size),
      createdAt: Value(createdAt),
    );
  }

  factory SchematicNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchematicNoteRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      size: serializer.fromJson<double>(json['size']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'size': serializer.toJson<double>(size),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SchematicNoteRow copyWith({
    String? id,
    String? projectId,
    String? kind,
    String? content,
    double? x,
    double? y,
    double? width,
    double? height,
    double? size,
    DateTime? createdAt,
  }) => SchematicNoteRow(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    size: size ?? this.size,
    createdAt: createdAt ?? this.createdAt,
  );
  SchematicNoteRow copyWithCompanion(SchematicNotesCompanion data) {
    return SchematicNoteRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      size: data.size.present ? data.size.value : this.size,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchematicNoteRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    kind,
    content,
    x,
    y,
    width,
    height,
    size,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchematicNoteRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.size == this.size &&
          other.createdAt == this.createdAt);
}

class SchematicNotesCompanion extends UpdateCompanion<SchematicNoteRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> kind;
  final Value<String> content;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<double> size;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SchematicNotesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.size = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchematicNotesCompanion.insert({
    required String id,
    required String projectId,
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    required double x,
    required double y,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.size = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       x = Value(x),
       y = Value(y),
       createdAt = Value(createdAt);
  static Insertable<SchematicNoteRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? size,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (size != null) 'size': size,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchematicNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? kind,
    Value<String>? content,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<double>? size,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SchematicNotesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (size.present) {
      map['size'] = Variable<double>(size.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchematicNotesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectSettingsTable extends ProjectSettings
    with TableInfo<$ProjectSettingsTable, ProjectSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [projectId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId, key};
  @override
  ProjectSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSettingRow(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ProjectSettingsTable createAlias(String alias) {
    return $ProjectSettingsTable(attachedDatabase, alias);
  }
}

class ProjectSettingRow extends DataClass
    implements Insertable<ProjectSettingRow> {
  final String projectId;
  final String key;
  final String value;
  const ProjectSettingRow({
    required this.projectId,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ProjectSettingsCompanion toCompanion(bool nullToAbsent) {
    return ProjectSettingsCompanion(
      projectId: Value(projectId),
      key: Value(key),
      value: Value(value),
    );
  }

  factory ProjectSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSettingRow(
      projectId: serializer.fromJson<String>(json['projectId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ProjectSettingRow copyWith({String? projectId, String? key, String? value}) =>
      ProjectSettingRow(
        projectId: projectId ?? this.projectId,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  ProjectSettingRow copyWithCompanion(ProjectSettingsCompanion data) {
    return ProjectSettingRow(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSettingRow(')
          ..write('projectId: $projectId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(projectId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSettingRow &&
          other.projectId == this.projectId &&
          other.key == this.key &&
          other.value == this.value);
}

class ProjectSettingsCompanion extends UpdateCompanion<ProjectSettingRow> {
  final Value<String> projectId;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ProjectSettingsCompanion({
    this.projectId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSettingsCompanion.insert({
    required String projectId,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId),
       key = Value(key),
       value = Value(value);
  static Insertable<ProjectSettingRow> custom({
    Expression<String>? projectId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSettingsCompanion copyWith({
    Value<String>? projectId,
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ProjectSettingsCompanion(
      projectId: projectId ?? this.projectId,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSettingsCompanion(')
          ..write('projectId: $projectId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $PartsTable parts = $PartsTable(this);
  late final $PartUnitsTable partUnits = $PartUnitsTable(this);
  late final $PartPinsTable partPins = $PartPinsTable(this);
  late final $NetClassesTable netClasses = $NetClassesTable(this);
  late final $NetsTable nets = $NetsTable(this);
  late final $NetNodesTable netNodes = $NetNodesTable(this);
  late final $SchematicWiresTable schematicWires = $SchematicWiresTable(this);
  late final $SymbolLibrariesTable symbolLibraries = $SymbolLibrariesTable(
    this,
  );
  late final $SymbolIndexEntriesTable symbolIndexEntries =
      $SymbolIndexEntriesTable(this);
  late final $NetRouteHintsTable netRouteHints = $NetRouteHintsTable(this);
  late final $FootprintLibrariesTable footprintLibraries =
      $FootprintLibrariesTable(this);
  late final $FootprintIndexEntriesTable footprintIndexEntries =
      $FootprintIndexEntriesTable(this);
  late final $BoardsTable boards = $BoardsTable(this);
  late final $BoardFootprintsTable boardFootprints = $BoardFootprintsTable(
    this,
  );
  late final $BoardTracksTable boardTracks = $BoardTracksTable(this);
  late final $BoardViasTable boardVias = $BoardViasTable(this);
  late final $BoardEdgesTable boardEdges = $BoardEdgesTable(this);
  late final $BoardZonesTable boardZones = $BoardZonesTable(this);
  late final $BoardTextsTable boardTexts = $BoardTextsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ProjectSnapshotsTable projectSnapshots = $ProjectSnapshotsTable(
    this,
  );
  late final $SchematicNotesTable schematicNotes = $SchematicNotesTable(this);
  late final $ProjectSettingsTable projectSettings = $ProjectSettingsTable(
    this,
  );
  late final Index idxPartsProject = Index(
    'idx_parts_project',
    'CREATE INDEX idx_parts_project ON parts (project_id)',
  );
  late final Index idxPartUnitsPart = Index(
    'idx_part_units_part',
    'CREATE INDEX idx_part_units_part ON part_units (part_id)',
  );
  late final Index idxPartPinsPart = Index(
    'idx_part_pins_part',
    'CREATE INDEX idx_part_pins_part ON part_pins (part_id)',
  );
  late final Index idxNetsProject = Index(
    'idx_nets_project',
    'CREATE INDEX idx_nets_project ON nets (project_id)',
  );
  late final Index idxNetClassesProject = Index(
    'idx_net_classes_project',
    'CREATE INDEX idx_net_classes_project ON net_classes (project_id)',
  );
  late final Index idxNetNodesNet = Index(
    'idx_net_nodes_net',
    'CREATE INDEX idx_net_nodes_net ON net_nodes (net_id)',
  );
  late final Index idxSchematicWiresProject = Index(
    'idx_schematic_wires_project',
    'CREATE INDEX idx_schematic_wires_project ON schematic_wires (project_id)',
  );
  late final Index idxSymbolIndexLibrary = Index(
    'idx_symbol_index_library',
    'CREATE INDEX idx_symbol_index_library ON symbol_index_entries (library_id)',
  );
  late final Index idxSymbolIndexSearch = Index(
    'idx_symbol_index_search',
    'CREATE INDEX idx_symbol_index_search ON symbol_index_entries (search_text)',
  );
  late final Index idxRouteHintsProject = Index(
    'idx_route_hints_project',
    'CREATE INDEX idx_route_hints_project ON net_route_hints (project_id)',
  );
  late final Index idxFootprintIndexLibrary = Index(
    'idx_footprint_index_library',
    'CREATE INDEX idx_footprint_index_library ON footprint_index_entries (library_id)',
  );
  late final Index idxFootprintIndexSearch = Index(
    'idx_footprint_index_search',
    'CREATE INDEX idx_footprint_index_search ON footprint_index_entries (search_text)',
  );
  late final Index idxBoardFootprintsProject = Index(
    'idx_board_footprints_project',
    'CREATE INDEX idx_board_footprints_project ON board_footprints (project_id)',
  );
  late final Index idxTracksProject = Index(
    'idx_tracks_project',
    'CREATE INDEX idx_tracks_project ON board_tracks (project_id)',
  );
  late final Index idxViasProject = Index(
    'idx_vias_project',
    'CREATE INDEX idx_vias_project ON board_vias (project_id)',
  );
  late final Index idxBoardEdgesProject = Index(
    'idx_board_edges_project',
    'CREATE INDEX idx_board_edges_project ON board_edges (project_id)',
  );
  late final Index idxBoardZonesProject = Index(
    'idx_board_zones_project',
    'CREATE INDEX idx_board_zones_project ON board_zones (project_id)',
  );
  late final Index idxBoardTextsProject = Index(
    'idx_board_texts_project',
    'CREATE INDEX idx_board_texts_project ON board_texts (project_id)',
  );
  late final Index idxProjectSnapshotsProject = Index(
    'idx_project_snapshots_project',
    'CREATE INDEX idx_project_snapshots_project ON project_snapshots (project_id)',
  );
  late final Index idxSchematicNotesProject = Index(
    'idx_schematic_notes_project',
    'CREATE INDEX idx_schematic_notes_project ON schematic_notes (project_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    parts,
    partUnits,
    partPins,
    netClasses,
    nets,
    netNodes,
    schematicWires,
    symbolLibraries,
    symbolIndexEntries,
    netRouteHints,
    footprintLibraries,
    footprintIndexEntries,
    boards,
    boardFootprints,
    boardTracks,
    boardVias,
    boardEdges,
    boardZones,
    boardTexts,
    appSettings,
    projectSnapshots,
    schematicNotes,
    projectSettings,
    idxPartsProject,
    idxPartUnitsPart,
    idxPartPinsPart,
    idxNetsProject,
    idxNetClassesProject,
    idxNetNodesNet,
    idxSchematicWiresProject,
    idxSymbolIndexLibrary,
    idxSymbolIndexSearch,
    idxRouteHintsProject,
    idxFootprintIndexLibrary,
    idxFootprintIndexSearch,
    idxBoardFootprintsProject,
    idxTracksProject,
    idxViasProject,
    idxBoardEdgesProject,
    idxBoardZonesProject,
    idxBoardTextsProject,
    idxProjectSnapshotsProject,
    idxSchematicNotesProject,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('parts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('part_units', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('part_pins', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_classes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('nets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'net_classes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('nets', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_nodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'part_pins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_nodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schematic_wires', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schematic_wires', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'part_pins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schematic_wires', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'part_pins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schematic_wires', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'symbol_libraries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('symbol_index_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_route_hints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'part_pins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_route_hints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'part_pins',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('net_route_hints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'footprint_libraries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('footprint_index_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('boards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_footprints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_footprints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_tracks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_vias', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_vias', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_zones', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_zones', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('board_texts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('project_snapshots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schematic_notes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('project_settings', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      Value<String> description,
      Value<PaperSize> paper,
      Value<String> company,
      Value<String> revision,
      required DateTime createdAt,
      required DateTime modifiedAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<PaperSize> paper,
      Value<String> company,
      Value<String> revision,
      Value<DateTime> createdAt,
      Value<DateTime> modifiedAt,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRow> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PartsTable, List<PartRow>> _partsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.parts,
    aliasName: $_aliasNameGenerator(db.projects.id, db.parts.projectId),
  );

  $$PartsTableProcessedTableManager get partsRefs {
    final manager = $$PartsTableTableManager(
      $_db,
      $_db.parts,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_partsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NetClassesTable, List<NetClassRow>>
  _netClassesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.netClasses,
    aliasName: $_aliasNameGenerator(db.projects.id, db.netClasses.projectId),
  );

  $$NetClassesTableProcessedTableManager get netClassesRefs {
    final manager = $$NetClassesTableTableManager(
      $_db,
      $_db.netClasses,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netClassesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NetsTable, List<NetRow>> _netsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.nets,
    aliasName: $_aliasNameGenerator(db.projects.id, db.nets.projectId),
  );

  $$NetsTableProcessedTableManager get netsRefs {
    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SchematicWiresTable, List<SchematicWireRow>>
  _schematicWiresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.schematicWires,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.schematicWires.projectId,
    ),
  );

  $$SchematicWiresTableProcessedTableManager get schematicWiresRefs {
    final manager = $$SchematicWiresTableTableManager(
      $_db,
      $_db.schematicWires,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_schematicWiresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NetRouteHintsTable, List<NetRouteHintRow>>
  _netRouteHintsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.netRouteHints,
    aliasName: $_aliasNameGenerator(db.projects.id, db.netRouteHints.projectId),
  );

  $$NetRouteHintsTableProcessedTableManager get netRouteHintsRefs {
    final manager = $$NetRouteHintsTableTableManager(
      $_db,
      $_db.netRouteHints,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netRouteHintsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardsTable, List<BoardRow>> _boardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.boards,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boards.projectId),
  );

  $$BoardsTableProcessedTableManager get boardsRefs {
    final manager = $$BoardsTableTableManager(
      $_db,
      $_db.boards,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardFootprintsTable, List<BoardFootprintRow>>
  _boardFootprintsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardFootprints,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.boardFootprints.projectId,
    ),
  );

  $$BoardFootprintsTableProcessedTableManager get boardFootprintsRefs {
    final manager = $$BoardFootprintsTableTableManager(
      $_db,
      $_db.boardFootprints,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _boardFootprintsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardTracksTable, List<BoardTrackRow>>
  _boardTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardTracks,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boardTracks.projectId),
  );

  $$BoardTracksTableProcessedTableManager get boardTracksRefs {
    final manager = $$BoardTracksTableTableManager(
      $_db,
      $_db.boardTracks,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardViasTable, List<BoardViaRow>>
  _boardViasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardVias,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boardVias.projectId),
  );

  $$BoardViasTableProcessedTableManager get boardViasRefs {
    final manager = $$BoardViasTableTableManager(
      $_db,
      $_db.boardVias,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardViasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardEdgesTable, List<BoardEdgeRow>>
  _boardEdgesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardEdges,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boardEdges.projectId),
  );

  $$BoardEdgesTableProcessedTableManager get boardEdgesRefs {
    final manager = $$BoardEdgesTableTableManager(
      $_db,
      $_db.boardEdges,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardEdgesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardZonesTable, List<BoardZoneRow>>
  _boardZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardZones,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boardZones.projectId),
  );

  $$BoardZonesTableProcessedTableManager get boardZonesRefs {
    final manager = $$BoardZonesTableTableManager(
      $_db,
      $_db.boardZones,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardTextsTable, List<BoardTextRow>>
  _boardTextsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardTexts,
    aliasName: $_aliasNameGenerator(db.projects.id, db.boardTexts.projectId),
  );

  $$BoardTextsTableProcessedTableManager get boardTextsRefs {
    final manager = $$BoardTextsTableTableManager(
      $_db,
      $_db.boardTexts,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardTextsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectSnapshotsTable, List<ProjectSnapshotRow>>
  _projectSnapshotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.projectSnapshots,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.projectSnapshots.projectId,
    ),
  );

  $$ProjectSnapshotsTableProcessedTableManager get projectSnapshotsRefs {
    final manager = $$ProjectSnapshotsTableTableManager(
      $_db,
      $_db.projectSnapshots,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SchematicNotesTable, List<SchematicNoteRow>>
  _schematicNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.schematicNotes,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.schematicNotes.projectId,
    ),
  );

  $$SchematicNotesTableProcessedTableManager get schematicNotesRefs {
    final manager = $$SchematicNotesTableTableManager(
      $_db,
      $_db.schematicNotes,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_schematicNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectSettingsTable, List<ProjectSettingRow>>
  _projectSettingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.projectSettings,
    aliasName: $_aliasNameGenerator(
      db.projects.id,
      db.projectSettings.projectId,
    ),
  );

  $$ProjectSettingsTableProcessedTableManager get projectSettingsRefs {
    final manager = $$ProjectSettingsTableTableManager(
      $_db,
      $_db.projectSettings,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectSettingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PaperSize, PaperSize, String> get paper =>
      $composableBuilder(
        column: $table.paper,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> partsRefs(
    Expression<bool> Function($$PartsTableFilterComposer f) f,
  ) {
    final $$PartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableFilterComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> netClassesRefs(
    Expression<bool> Function($$NetClassesTableFilterComposer f) f,
  ) {
    final $$NetClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netClasses,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetClassesTableFilterComposer(
            $db: $db,
            $table: $db.netClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> netsRefs(
    Expression<bool> Function($$NetsTableFilterComposer f) f,
  ) {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> schematicWiresRefs(
    Expression<bool> Function($$SchematicWiresTableFilterComposer f) f,
  ) {
    final $$SchematicWiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicWires,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicWiresTableFilterComposer(
            $db: $db,
            $table: $db.schematicWires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> netRouteHintsRefs(
    Expression<bool> Function($$NetRouteHintsTableFilterComposer f) f,
  ) {
    final $$NetRouteHintsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netRouteHints,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetRouteHintsTableFilterComposer(
            $db: $db,
            $table: $db.netRouteHints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardsRefs(
    Expression<bool> Function($$BoardsTableFilterComposer f) f,
  ) {
    final $$BoardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boards,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardsTableFilterComposer(
            $db: $db,
            $table: $db.boards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardFootprintsRefs(
    Expression<bool> Function($$BoardFootprintsTableFilterComposer f) f,
  ) {
    final $$BoardFootprintsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardFootprints,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardFootprintsTableFilterComposer(
            $db: $db,
            $table: $db.boardFootprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardTracksRefs(
    Expression<bool> Function($$BoardTracksTableFilterComposer f) f,
  ) {
    final $$BoardTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTracks,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTracksTableFilterComposer(
            $db: $db,
            $table: $db.boardTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardViasRefs(
    Expression<bool> Function($$BoardViasTableFilterComposer f) f,
  ) {
    final $$BoardViasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardVias,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardViasTableFilterComposer(
            $db: $db,
            $table: $db.boardVias,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardEdgesRefs(
    Expression<bool> Function($$BoardEdgesTableFilterComposer f) f,
  ) {
    final $$BoardEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardEdges,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardEdgesTableFilterComposer(
            $db: $db,
            $table: $db.boardEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardZonesRefs(
    Expression<bool> Function($$BoardZonesTableFilterComposer f) f,
  ) {
    final $$BoardZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardZones,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardZonesTableFilterComposer(
            $db: $db,
            $table: $db.boardZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardTextsRefs(
    Expression<bool> Function($$BoardTextsTableFilterComposer f) f,
  ) {
    final $$BoardTextsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTexts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTextsTableFilterComposer(
            $db: $db,
            $table: $db.boardTexts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectSnapshotsRefs(
    Expression<bool> Function($$ProjectSnapshotsTableFilterComposer f) f,
  ) {
    final $$ProjectSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSnapshots,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.projectSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> schematicNotesRefs(
    Expression<bool> Function($$SchematicNotesTableFilterComposer f) f,
  ) {
    final $$SchematicNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicNotes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicNotesTableFilterComposer(
            $db: $db,
            $table: $db.schematicNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectSettingsRefs(
    Expression<bool> Function($$ProjectSettingsTableFilterComposer f) f,
  ) {
    final $$ProjectSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSettings,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSettingsTableFilterComposer(
            $db: $db,
            $table: $db.projectSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paper => $composableBuilder(
    column: $table.paper,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PaperSize, String> get paper =>
      $composableBuilder(column: $table.paper, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  Expression<T> partsRefs<T extends Object>(
    Expression<T> Function($$PartsTableAnnotationComposer a) f,
  ) {
    final $$PartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableAnnotationComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> netClassesRefs<T extends Object>(
    Expression<T> Function($$NetClassesTableAnnotationComposer a) f,
  ) {
    final $$NetClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netClasses,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.netClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> netsRefs<T extends Object>(
    Expression<T> Function($$NetsTableAnnotationComposer a) f,
  ) {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> schematicWiresRefs<T extends Object>(
    Expression<T> Function($$SchematicWiresTableAnnotationComposer a) f,
  ) {
    final $$SchematicWiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicWires,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicWiresTableAnnotationComposer(
            $db: $db,
            $table: $db.schematicWires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> netRouteHintsRefs<T extends Object>(
    Expression<T> Function($$NetRouteHintsTableAnnotationComposer a) f,
  ) {
    final $$NetRouteHintsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netRouteHints,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetRouteHintsTableAnnotationComposer(
            $db: $db,
            $table: $db.netRouteHints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardsRefs<T extends Object>(
    Expression<T> Function($$BoardsTableAnnotationComposer a) f,
  ) {
    final $$BoardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boards,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardsTableAnnotationComposer(
            $db: $db,
            $table: $db.boards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardFootprintsRefs<T extends Object>(
    Expression<T> Function($$BoardFootprintsTableAnnotationComposer a) f,
  ) {
    final $$BoardFootprintsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardFootprints,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardFootprintsTableAnnotationComposer(
            $db: $db,
            $table: $db.boardFootprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardTracksRefs<T extends Object>(
    Expression<T> Function($$BoardTracksTableAnnotationComposer a) f,
  ) {
    final $$BoardTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTracks,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.boardTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardViasRefs<T extends Object>(
    Expression<T> Function($$BoardViasTableAnnotationComposer a) f,
  ) {
    final $$BoardViasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardVias,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardViasTableAnnotationComposer(
            $db: $db,
            $table: $db.boardVias,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardEdgesRefs<T extends Object>(
    Expression<T> Function($$BoardEdgesTableAnnotationComposer a) f,
  ) {
    final $$BoardEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardEdges,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.boardEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardZonesRefs<T extends Object>(
    Expression<T> Function($$BoardZonesTableAnnotationComposer a) f,
  ) {
    final $$BoardZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardZones,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.boardZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardTextsRefs<T extends Object>(
    Expression<T> Function($$BoardTextsTableAnnotationComposer a) f,
  ) {
    final $$BoardTextsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTexts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTextsTableAnnotationComposer(
            $db: $db,
            $table: $db.boardTexts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectSnapshotsRefs<T extends Object>(
    Expression<T> Function($$ProjectSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$ProjectSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSnapshots,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> schematicNotesRefs<T extends Object>(
    Expression<T> Function($$SchematicNotesTableAnnotationComposer a) f,
  ) {
    final $$SchematicNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicNotes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.schematicNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectSettingsRefs<T extends Object>(
    Expression<T> Function($$ProjectSettingsTableAnnotationComposer a) f,
  ) {
    final $$ProjectSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectSettings,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          ProjectRow,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (ProjectRow, $$ProjectsTableReferences),
          ProjectRow,
          PrefetchHooks Function({
            bool partsRefs,
            bool netClassesRefs,
            bool netsRefs,
            bool schematicWiresRefs,
            bool netRouteHintsRefs,
            bool boardsRefs,
            bool boardFootprintsRefs,
            bool boardTracksRefs,
            bool boardViasRefs,
            bool boardEdgesRefs,
            bool boardZonesRefs,
            bool boardTextsRefs,
            bool projectSnapshotsRefs,
            bool schematicNotesRefs,
            bool projectSettingsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<PaperSize> paper = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                description: description,
                paper: paper,
                company: company,
                revision: revision,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                Value<PaperSize> paper = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> revision = const Value.absent(),
                required DateTime createdAt,
                required DateTime modifiedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                description: description,
                paper: paper,
                company: company,
                revision: revision,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                partsRefs = false,
                netClassesRefs = false,
                netsRefs = false,
                schematicWiresRefs = false,
                netRouteHintsRefs = false,
                boardsRefs = false,
                boardFootprintsRefs = false,
                boardTracksRefs = false,
                boardViasRefs = false,
                boardEdgesRefs = false,
                boardZonesRefs = false,
                boardTextsRefs = false,
                projectSnapshotsRefs = false,
                schematicNotesRefs = false,
                projectSettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (partsRefs) db.parts,
                    if (netClassesRefs) db.netClasses,
                    if (netsRefs) db.nets,
                    if (schematicWiresRefs) db.schematicWires,
                    if (netRouteHintsRefs) db.netRouteHints,
                    if (boardsRefs) db.boards,
                    if (boardFootprintsRefs) db.boardFootprints,
                    if (boardTracksRefs) db.boardTracks,
                    if (boardViasRefs) db.boardVias,
                    if (boardEdgesRefs) db.boardEdges,
                    if (boardZonesRefs) db.boardZones,
                    if (boardTextsRefs) db.boardTexts,
                    if (projectSnapshotsRefs) db.projectSnapshots,
                    if (schematicNotesRefs) db.schematicNotes,
                    if (projectSettingsRefs) db.projectSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (partsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          PartRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._partsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).partsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (netClassesRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          NetClassRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._netClassesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).netClassesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (netsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          NetRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._netsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(db, table, p0).netsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (schematicWiresRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          SchematicWireRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._schematicWiresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).schematicWiresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (netRouteHintsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          NetRouteHintRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._netRouteHintsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).netRouteHintsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardFootprintsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardFootprintRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardFootprintsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardFootprintsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardTracksRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardTrackRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardViasRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardViaRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardViasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardViasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardEdgesRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardEdgeRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardEdgesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardEdgesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardZonesRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardZoneRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardZonesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardZonesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardTextsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          BoardTextRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._boardTextsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardTextsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectSnapshotsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          ProjectSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (schematicNotesRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          SchematicNoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._schematicNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).schematicNotesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectSettingsRefs)
                        await $_getPrefetchedData<
                          ProjectRow,
                          $ProjectsTable,
                          ProjectSettingRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      ProjectRow,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRow, $$ProjectsTableReferences),
      ProjectRow,
      PrefetchHooks Function({
        bool partsRefs,
        bool netClassesRefs,
        bool netsRefs,
        bool schematicWiresRefs,
        bool netRouteHintsRefs,
        bool boardsRefs,
        bool boardFootprintsRefs,
        bool boardTracksRefs,
        bool boardViasRefs,
        bool boardEdgesRefs,
        bool boardZonesRefs,
        bool boardTextsRefs,
        bool projectSnapshotsRefs,
        bool schematicNotesRefs,
        bool projectSettingsRefs,
      })
    >;
typedef $$PartsTableCreateCompanionBuilder =
    PartsCompanion Function({
      required String id,
      required String projectId,
      required String libId,
      required String reference,
      Value<String> value,
      Value<String> footprint,
      Value<String> datasheet,
      Value<String> description,
      Value<int> unitCount,
      Value<bool> inBom,
      Value<bool> onBoard,
      Value<bool> dnp,
      Value<bool> fieldsHidden,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PartsTableUpdateCompanionBuilder =
    PartsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> libId,
      Value<String> reference,
      Value<String> value,
      Value<String> footprint,
      Value<String> datasheet,
      Value<String> description,
      Value<int> unitCount,
      Value<bool> inBom,
      Value<bool> onBoard,
      Value<bool> dnp,
      Value<bool> fieldsHidden,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PartsTableReferences
    extends BaseReferences<_$AppDatabase, $PartsTable, PartRow> {
  $$PartsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.parts.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PartUnitsTable, List<PartUnitRow>>
  _partUnitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.partUnits,
    aliasName: $_aliasNameGenerator(db.parts.id, db.partUnits.partId),
  );

  $$PartUnitsTableProcessedTableManager get partUnitsRefs {
    final manager = $$PartUnitsTableTableManager(
      $_db,
      $_db.partUnits,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_partUnitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PartPinsTable, List<PartPinRow>>
  _partPinsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.partPins,
    aliasName: $_aliasNameGenerator(db.parts.id, db.partPins.partId),
  );

  $$PartPinsTableProcessedTableManager get partPinsRefs {
    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_partPinsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardFootprintsTable, List<BoardFootprintRow>>
  _boardFootprintsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardFootprints,
    aliasName: $_aliasNameGenerator(db.parts.id, db.boardFootprints.partId),
  );

  $$BoardFootprintsTableProcessedTableManager get boardFootprintsRefs {
    final manager = $$BoardFootprintsTableTableManager(
      $_db,
      $_db.boardFootprints,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _boardFootprintsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PartsTableFilterComposer extends Composer<_$AppDatabase, $PartsTable> {
  $$PartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libId => $composableBuilder(
    column: $table.libId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get footprint => $composableBuilder(
    column: $table.footprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasheet => $composableBuilder(
    column: $table.datasheet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inBom => $composableBuilder(
    column: $table.inBom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onBoard => $composableBuilder(
    column: $table.onBoard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dnp => $composableBuilder(
    column: $table.dnp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fieldsHidden => $composableBuilder(
    column: $table.fieldsHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> partUnitsRefs(
    Expression<bool> Function($$PartUnitsTableFilterComposer f) f,
  ) {
    final $$PartUnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partUnits,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartUnitsTableFilterComposer(
            $db: $db,
            $table: $db.partUnits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> partPinsRefs(
    Expression<bool> Function($$PartPinsTableFilterComposer f) f,
  ) {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardFootprintsRefs(
    Expression<bool> Function($$BoardFootprintsTableFilterComposer f) f,
  ) {
    final $$BoardFootprintsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardFootprints,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardFootprintsTableFilterComposer(
            $db: $db,
            $table: $db.boardFootprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartsTableOrderingComposer
    extends Composer<_$AppDatabase, $PartsTable> {
  $$PartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libId => $composableBuilder(
    column: $table.libId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get footprint => $composableBuilder(
    column: $table.footprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasheet => $composableBuilder(
    column: $table.datasheet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inBom => $composableBuilder(
    column: $table.inBom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onBoard => $composableBuilder(
    column: $table.onBoard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dnp => $composableBuilder(
    column: $table.dnp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fieldsHidden => $composableBuilder(
    column: $table.fieldsHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartsTable> {
  $$PartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libId =>
      $composableBuilder(column: $table.libId, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get footprint =>
      $composableBuilder(column: $table.footprint, builder: (column) => column);

  GeneratedColumn<String> get datasheet =>
      $composableBuilder(column: $table.datasheet, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitCount =>
      $composableBuilder(column: $table.unitCount, builder: (column) => column);

  GeneratedColumn<bool> get inBom =>
      $composableBuilder(column: $table.inBom, builder: (column) => column);

  GeneratedColumn<bool> get onBoard =>
      $composableBuilder(column: $table.onBoard, builder: (column) => column);

  GeneratedColumn<bool> get dnp =>
      $composableBuilder(column: $table.dnp, builder: (column) => column);

  GeneratedColumn<bool> get fieldsHidden => $composableBuilder(
    column: $table.fieldsHidden,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> partUnitsRefs<T extends Object>(
    Expression<T> Function($$PartUnitsTableAnnotationComposer a) f,
  ) {
    final $$PartUnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partUnits,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartUnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.partUnits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> partPinsRefs<T extends Object>(
    Expression<T> Function($$PartPinsTableAnnotationComposer a) f,
  ) {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardFootprintsRefs<T extends Object>(
    Expression<T> Function($$BoardFootprintsTableAnnotationComposer a) f,
  ) {
    final $$BoardFootprintsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardFootprints,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardFootprintsTableAnnotationComposer(
            $db: $db,
            $table: $db.boardFootprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartsTable,
          PartRow,
          $$PartsTableFilterComposer,
          $$PartsTableOrderingComposer,
          $$PartsTableAnnotationComposer,
          $$PartsTableCreateCompanionBuilder,
          $$PartsTableUpdateCompanionBuilder,
          (PartRow, $$PartsTableReferences),
          PartRow,
          PrefetchHooks Function({
            bool projectId,
            bool partUnitsRefs,
            bool partPinsRefs,
            bool boardFootprintsRefs,
          })
        > {
  $$PartsTableTableManager(_$AppDatabase db, $PartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> libId = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> footprint = const Value.absent(),
                Value<String> datasheet = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<bool> inBom = const Value.absent(),
                Value<bool> onBoard = const Value.absent(),
                Value<bool> dnp = const Value.absent(),
                Value<bool> fieldsHidden = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartsCompanion(
                id: id,
                projectId: projectId,
                libId: libId,
                reference: reference,
                value: value,
                footprint: footprint,
                datasheet: datasheet,
                description: description,
                unitCount: unitCount,
                inBom: inBom,
                onBoard: onBoard,
                dnp: dnp,
                fieldsHidden: fieldsHidden,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String libId,
                required String reference,
                Value<String> value = const Value.absent(),
                Value<String> footprint = const Value.absent(),
                Value<String> datasheet = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<bool> inBom = const Value.absent(),
                Value<bool> onBoard = const Value.absent(),
                Value<bool> dnp = const Value.absent(),
                Value<bool> fieldsHidden = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PartsCompanion.insert(
                id: id,
                projectId: projectId,
                libId: libId,
                reference: reference,
                value: value,
                footprint: footprint,
                datasheet: datasheet,
                description: description,
                unitCount: unitCount,
                inBom: inBom,
                onBoard: onBoard,
                dnp: dnp,
                fieldsHidden: fieldsHidden,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PartsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                partUnitsRefs = false,
                partPinsRefs = false,
                boardFootprintsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (partUnitsRefs) db.partUnits,
                    if (partPinsRefs) db.partPins,
                    if (boardFootprintsRefs) db.boardFootprints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$PartsTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$PartsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (partUnitsRefs)
                        await $_getPrefetchedData<
                          PartRow,
                          $PartsTable,
                          PartUnitRow
                        >(
                          currentTable: table,
                          referencedTable: $$PartsTableReferences
                              ._partUnitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PartsTableReferences(
                                db,
                                table,
                                p0,
                              ).partUnitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (partPinsRefs)
                        await $_getPrefetchedData<
                          PartRow,
                          $PartsTable,
                          PartPinRow
                        >(
                          currentTable: table,
                          referencedTable: $$PartsTableReferences
                              ._partPinsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PartsTableReferences(
                                db,
                                table,
                                p0,
                              ).partPinsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardFootprintsRefs)
                        await $_getPrefetchedData<
                          PartRow,
                          $PartsTable,
                          BoardFootprintRow
                        >(
                          currentTable: table,
                          referencedTable: $$PartsTableReferences
                              ._boardFootprintsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PartsTableReferences(
                                db,
                                table,
                                p0,
                              ).boardFootprintsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartsTable,
      PartRow,
      $$PartsTableFilterComposer,
      $$PartsTableOrderingComposer,
      $$PartsTableAnnotationComposer,
      $$PartsTableCreateCompanionBuilder,
      $$PartsTableUpdateCompanionBuilder,
      (PartRow, $$PartsTableReferences),
      PartRow,
      PrefetchHooks Function({
        bool projectId,
        bool partUnitsRefs,
        bool partPinsRefs,
        bool boardFootprintsRefs,
      })
    >;
typedef $$PartUnitsTableCreateCompanionBuilder =
    PartUnitsCompanion Function({
      required String id,
      required String partId,
      required int unitNumber,
      Value<int> bodyStyle,
      Value<double> x,
      Value<double> y,
      Value<int> rotation,
      Value<bool> mirrorX,
      Value<bool> mirrorY,
      Value<bool> placed,
      Value<int> rowid,
    });
typedef $$PartUnitsTableUpdateCompanionBuilder =
    PartUnitsCompanion Function({
      Value<String> id,
      Value<String> partId,
      Value<int> unitNumber,
      Value<int> bodyStyle,
      Value<double> x,
      Value<double> y,
      Value<int> rotation,
      Value<bool> mirrorX,
      Value<bool> mirrorY,
      Value<bool> placed,
      Value<int> rowid,
    });

final class $$PartUnitsTableReferences
    extends BaseReferences<_$AppDatabase, $PartUnitsTable, PartUnitRow> {
  $$PartUnitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PartsTable _partIdTable(_$AppDatabase db) => db.parts.createAlias(
    $_aliasNameGenerator(db.partUnits.partId, db.parts.id),
  );

  $$PartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$PartsTableTableManager(
      $_db,
      $_db.parts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PartUnitsTableFilterComposer
    extends Composer<_$AppDatabase, $PartUnitsTable> {
  $$PartUnitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bodyStyle => $composableBuilder(
    column: $table.bodyStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mirrorX => $composableBuilder(
    column: $table.mirrorX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mirrorY => $composableBuilder(
    column: $table.mirrorY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get placed => $composableBuilder(
    column: $table.placed,
    builder: (column) => ColumnFilters(column),
  );

  $$PartsTableFilterComposer get partId {
    final $$PartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableFilterComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartUnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $PartUnitsTable> {
  $$PartUnitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bodyStyle => $composableBuilder(
    column: $table.bodyStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mirrorX => $composableBuilder(
    column: $table.mirrorX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mirrorY => $composableBuilder(
    column: $table.mirrorY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get placed => $composableBuilder(
    column: $table.placed,
    builder: (column) => ColumnOrderings(column),
  );

  $$PartsTableOrderingComposer get partId {
    final $$PartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableOrderingComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartUnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartUnitsTable> {
  $$PartUnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get unitNumber => $composableBuilder(
    column: $table.unitNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bodyStyle =>
      $composableBuilder(column: $table.bodyStyle, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<int> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<bool> get mirrorX =>
      $composableBuilder(column: $table.mirrorX, builder: (column) => column);

  GeneratedColumn<bool> get mirrorY =>
      $composableBuilder(column: $table.mirrorY, builder: (column) => column);

  GeneratedColumn<bool> get placed =>
      $composableBuilder(column: $table.placed, builder: (column) => column);

  $$PartsTableAnnotationComposer get partId {
    final $$PartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableAnnotationComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartUnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartUnitsTable,
          PartUnitRow,
          $$PartUnitsTableFilterComposer,
          $$PartUnitsTableOrderingComposer,
          $$PartUnitsTableAnnotationComposer,
          $$PartUnitsTableCreateCompanionBuilder,
          $$PartUnitsTableUpdateCompanionBuilder,
          (PartUnitRow, $$PartUnitsTableReferences),
          PartUnitRow,
          PrefetchHooks Function({bool partId})
        > {
  $$PartUnitsTableTableManager(_$AppDatabase db, $PartUnitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartUnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartUnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartUnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<int> unitNumber = const Value.absent(),
                Value<int> bodyStyle = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<int> rotation = const Value.absent(),
                Value<bool> mirrorX = const Value.absent(),
                Value<bool> mirrorY = const Value.absent(),
                Value<bool> placed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartUnitsCompanion(
                id: id,
                partId: partId,
                unitNumber: unitNumber,
                bodyStyle: bodyStyle,
                x: x,
                y: y,
                rotation: rotation,
                mirrorX: mirrorX,
                mirrorY: mirrorY,
                placed: placed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partId,
                required int unitNumber,
                Value<int> bodyStyle = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<int> rotation = const Value.absent(),
                Value<bool> mirrorX = const Value.absent(),
                Value<bool> mirrorY = const Value.absent(),
                Value<bool> placed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartUnitsCompanion.insert(
                id: id,
                partId: partId,
                unitNumber: unitNumber,
                bodyStyle: bodyStyle,
                x: x,
                y: y,
                rotation: rotation,
                mirrorX: mirrorX,
                mirrorY: mirrorY,
                placed: placed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PartUnitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({partId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (partId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partId,
                                referencedTable: $$PartUnitsTableReferences
                                    ._partIdTable(db),
                                referencedColumn: $$PartUnitsTableReferences
                                    ._partIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PartUnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartUnitsTable,
      PartUnitRow,
      $$PartUnitsTableFilterComposer,
      $$PartUnitsTableOrderingComposer,
      $$PartUnitsTableAnnotationComposer,
      $$PartUnitsTableCreateCompanionBuilder,
      $$PartUnitsTableUpdateCompanionBuilder,
      (PartUnitRow, $$PartUnitsTableReferences),
      PartUnitRow,
      PrefetchHooks Function({bool partId})
    >;
typedef $$PartPinsTableCreateCompanionBuilder =
    PartPinsCompanion Function({
      required String id,
      required String partId,
      Value<int> unit,
      Value<int> bodyStyle,
      required String number,
      Value<String> name,
      required PinElectricalType electricalType,
      Value<PinGraphicStyle> graphicStyle,
      Value<double> x,
      Value<double> y,
      Value<double> length,
      Value<int> angle,
      Value<bool> noConnect,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$PartPinsTableUpdateCompanionBuilder =
    PartPinsCompanion Function({
      Value<String> id,
      Value<String> partId,
      Value<int> unit,
      Value<int> bodyStyle,
      Value<String> number,
      Value<String> name,
      Value<PinElectricalType> electricalType,
      Value<PinGraphicStyle> graphicStyle,
      Value<double> x,
      Value<double> y,
      Value<double> length,
      Value<int> angle,
      Value<bool> noConnect,
      Value<bool> hidden,
      Value<int> rowid,
    });

final class $$PartPinsTableReferences
    extends BaseReferences<_$AppDatabase, $PartPinsTable, PartPinRow> {
  $$PartPinsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PartsTable _partIdTable(_$AppDatabase db) => db.parts.createAlias(
    $_aliasNameGenerator(db.partPins.partId, db.parts.id),
  );

  $$PartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$PartsTableTableManager(
      $_db,
      $_db.parts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NetNodesTable, List<NetNodeRow>>
  _netNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.netNodes,
    aliasName: $_aliasNameGenerator(db.partPins.id, db.netNodes.partPinId),
  );

  $$NetNodesTableProcessedTableManager get netNodesRefs {
    final manager = $$NetNodesTableTableManager(
      $_db,
      $_db.netNodes,
    ).filter((f) => f.partPinId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PartPinsTableFilterComposer
    extends Composer<_$AppDatabase, $PartPinsTable> {
  $$PartPinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bodyStyle => $composableBuilder(
    column: $table.bodyStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PinElectricalType, PinElectricalType, String>
  get electricalType => $composableBuilder(
    column: $table.electricalType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PinGraphicStyle, PinGraphicStyle, String>
  get graphicStyle => $composableBuilder(
    column: $table.graphicStyle,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get angle => $composableBuilder(
    column: $table.angle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get noConnect => $composableBuilder(
    column: $table.noConnect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  $$PartsTableFilterComposer get partId {
    final $$PartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableFilterComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> netNodesRefs(
    Expression<bool> Function($$NetNodesTableFilterComposer f) f,
  ) {
    final $$NetNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netNodes,
      getReferencedColumn: (t) => t.partPinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetNodesTableFilterComposer(
            $db: $db,
            $table: $db.netNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartPinsTableOrderingComposer
    extends Composer<_$AppDatabase, $PartPinsTable> {
  $$PartPinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bodyStyle => $composableBuilder(
    column: $table.bodyStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get electricalType => $composableBuilder(
    column: $table.electricalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get graphicStyle => $composableBuilder(
    column: $table.graphicStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get angle => $composableBuilder(
    column: $table.angle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get noConnect => $composableBuilder(
    column: $table.noConnect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  $$PartsTableOrderingComposer get partId {
    final $$PartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableOrderingComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PartPinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartPinsTable> {
  $$PartPinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get bodyStyle =>
      $composableBuilder(column: $table.bodyStyle, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PinElectricalType, String>
  get electricalType => $composableBuilder(
    column: $table.electricalType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PinGraphicStyle, String> get graphicStyle =>
      $composableBuilder(
        column: $table.graphicStyle,
        builder: (column) => column,
      );

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<int> get angle =>
      $composableBuilder(column: $table.angle, builder: (column) => column);

  GeneratedColumn<bool> get noConnect =>
      $composableBuilder(column: $table.noConnect, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  $$PartsTableAnnotationComposer get partId {
    final $$PartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableAnnotationComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> netNodesRefs<T extends Object>(
    Expression<T> Function($$NetNodesTableAnnotationComposer a) f,
  ) {
    final $$NetNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netNodes,
      getReferencedColumn: (t) => t.partPinId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.netNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PartPinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartPinsTable,
          PartPinRow,
          $$PartPinsTableFilterComposer,
          $$PartPinsTableOrderingComposer,
          $$PartPinsTableAnnotationComposer,
          $$PartPinsTableCreateCompanionBuilder,
          $$PartPinsTableUpdateCompanionBuilder,
          (PartPinRow, $$PartPinsTableReferences),
          PartPinRow,
          PrefetchHooks Function({bool partId, bool netNodesRefs})
        > {
  $$PartPinsTableTableManager(_$AppDatabase db, $PartPinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartPinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartPinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartPinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<int> unit = const Value.absent(),
                Value<int> bodyStyle = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<PinElectricalType> electricalType = const Value.absent(),
                Value<PinGraphicStyle> graphicStyle = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> length = const Value.absent(),
                Value<int> angle = const Value.absent(),
                Value<bool> noConnect = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartPinsCompanion(
                id: id,
                partId: partId,
                unit: unit,
                bodyStyle: bodyStyle,
                number: number,
                name: name,
                electricalType: electricalType,
                graphicStyle: graphicStyle,
                x: x,
                y: y,
                length: length,
                angle: angle,
                noConnect: noConnect,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partId,
                Value<int> unit = const Value.absent(),
                Value<int> bodyStyle = const Value.absent(),
                required String number,
                Value<String> name = const Value.absent(),
                required PinElectricalType electricalType,
                Value<PinGraphicStyle> graphicStyle = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> length = const Value.absent(),
                Value<int> angle = const Value.absent(),
                Value<bool> noConnect = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartPinsCompanion.insert(
                id: id,
                partId: partId,
                unit: unit,
                bodyStyle: bodyStyle,
                number: number,
                name: name,
                electricalType: electricalType,
                graphicStyle: graphicStyle,
                x: x,
                y: y,
                length: length,
                angle: angle,
                noConnect: noConnect,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PartPinsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({partId = false, netNodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (netNodesRefs) db.netNodes],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (partId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partId,
                                referencedTable: $$PartPinsTableReferences
                                    ._partIdTable(db),
                                referencedColumn: $$PartPinsTableReferences
                                    ._partIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (netNodesRefs)
                    await $_getPrefetchedData<
                      PartPinRow,
                      $PartPinsTable,
                      NetNodeRow
                    >(
                      currentTable: table,
                      referencedTable: $$PartPinsTableReferences
                          ._netNodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PartPinsTableReferences(db, table, p0).netNodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.partPinId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PartPinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartPinsTable,
      PartPinRow,
      $$PartPinsTableFilterComposer,
      $$PartPinsTableOrderingComposer,
      $$PartPinsTableAnnotationComposer,
      $$PartPinsTableCreateCompanionBuilder,
      $$PartPinsTableUpdateCompanionBuilder,
      (PartPinRow, $$PartPinsTableReferences),
      PartPinRow,
      PrefetchHooks Function({bool partId, bool netNodesRefs})
    >;
typedef $$NetClassesTableCreateCompanionBuilder =
    NetClassesCompanion Function({
      required String id,
      required String projectId,
      required String name,
      required double trackWidth,
      Value<double?> clearance,
      Value<double?> impedance,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$NetClassesTableUpdateCompanionBuilder =
    NetClassesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> name,
      Value<double> trackWidth,
      Value<double?> clearance,
      Value<double?> impedance,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$NetClassesTableReferences
    extends BaseReferences<_$AppDatabase, $NetClassesTable, NetClassRow> {
  $$NetClassesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.netClasses.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NetsTable, List<NetRow>> _netsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.nets,
    aliasName: $_aliasNameGenerator(db.netClasses.id, db.nets.netClassId),
  );

  $$NetsTableProcessedTableManager get netsRefs {
    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.netClassId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NetClassesTableFilterComposer
    extends Composer<_$AppDatabase, $NetClassesTable> {
  $$NetClassesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get impedance => $composableBuilder(
    column: $table.impedance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> netsRefs(
    Expression<bool> Function($$NetsTableFilterComposer f) f,
  ) {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.netClassId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NetClassesTableOrderingComposer
    extends Composer<_$AppDatabase, $NetClassesTable> {
  $$NetClassesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get impedance => $composableBuilder(
    column: $table.impedance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetClassesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NetClassesTable> {
  $$NetClassesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get clearance =>
      $composableBuilder(column: $table.clearance, builder: (column) => column);

  GeneratedColumn<double> get impedance =>
      $composableBuilder(column: $table.impedance, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> netsRefs<T extends Object>(
    Expression<T> Function($$NetsTableAnnotationComposer a) f,
  ) {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.netClassId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NetClassesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NetClassesTable,
          NetClassRow,
          $$NetClassesTableFilterComposer,
          $$NetClassesTableOrderingComposer,
          $$NetClassesTableAnnotationComposer,
          $$NetClassesTableCreateCompanionBuilder,
          $$NetClassesTableUpdateCompanionBuilder,
          (NetClassRow, $$NetClassesTableReferences),
          NetClassRow,
          PrefetchHooks Function({bool projectId, bool netsRefs})
        > {
  $$NetClassesTableTableManager(_$AppDatabase db, $NetClassesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NetClassesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NetClassesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NetClassesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> trackWidth = const Value.absent(),
                Value<double?> clearance = const Value.absent(),
                Value<double?> impedance = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetClassesCompanion(
                id: id,
                projectId: projectId,
                name: name,
                trackWidth: trackWidth,
                clearance: clearance,
                impedance: impedance,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String name,
                required double trackWidth,
                Value<double?> clearance = const Value.absent(),
                Value<double?> impedance = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NetClassesCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                trackWidth: trackWidth,
                clearance: clearance,
                impedance: impedance,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NetClassesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, netsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (netsRefs) db.nets],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$NetClassesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$NetClassesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (netsRefs)
                    await $_getPrefetchedData<
                      NetClassRow,
                      $NetClassesTable,
                      NetRow
                    >(
                      currentTable: table,
                      referencedTable: $$NetClassesTableReferences
                          ._netsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NetClassesTableReferences(db, table, p0).netsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.netClassId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NetClassesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NetClassesTable,
      NetClassRow,
      $$NetClassesTableFilterComposer,
      $$NetClassesTableOrderingComposer,
      $$NetClassesTableAnnotationComposer,
      $$NetClassesTableCreateCompanionBuilder,
      $$NetClassesTableUpdateCompanionBuilder,
      (NetClassRow, $$NetClassesTableReferences),
      NetClassRow,
      PrefetchHooks Function({bool projectId, bool netsRefs})
    >;
typedef $$NetsTableCreateCompanionBuilder =
    NetsCompanion Function({
      required String id,
      required String projectId,
      Value<String?> name,
      Value<double?> labelX,
      Value<double?> labelY,
      Value<String?> netClassId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$NetsTableUpdateCompanionBuilder =
    NetsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> name,
      Value<double?> labelX,
      Value<double?> labelY,
      Value<String?> netClassId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$NetsTableReferences
    extends BaseReferences<_$AppDatabase, $NetsTable, NetRow> {
  $$NetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.nets.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NetClassesTable _netClassIdTable(_$AppDatabase db) => db.netClasses
      .createAlias($_aliasNameGenerator(db.nets.netClassId, db.netClasses.id));

  $$NetClassesTableProcessedTableManager? get netClassId {
    final $_column = $_itemColumn<String>('net_class_id');
    if ($_column == null) return null;
    final manager = $$NetClassesTableTableManager(
      $_db,
      $_db.netClasses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netClassIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NetNodesTable, List<NetNodeRow>>
  _netNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.netNodes,
    aliasName: $_aliasNameGenerator(db.nets.id, db.netNodes.netId),
  );

  $$NetNodesTableProcessedTableManager get netNodesRefs {
    final manager = $$NetNodesTableTableManager(
      $_db,
      $_db.netNodes,
    ).filter((f) => f.netId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_netNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SchematicWiresTable, List<SchematicWireRow>>
  _schematicWiresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.schematicWires,
    aliasName: $_aliasNameGenerator(db.nets.id, db.schematicWires.netId),
  );

  $$SchematicWiresTableProcessedTableManager get schematicWiresRefs {
    final manager = $$SchematicWiresTableTableManager(
      $_db,
      $_db.schematicWires,
    ).filter((f) => f.netId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_schematicWiresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardTracksTable, List<BoardTrackRow>>
  _boardTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardTracks,
    aliasName: $_aliasNameGenerator(db.nets.id, db.boardTracks.netId),
  );

  $$BoardTracksTableProcessedTableManager get boardTracksRefs {
    final manager = $$BoardTracksTableTableManager(
      $_db,
      $_db.boardTracks,
    ).filter((f) => f.netId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardViasTable, List<BoardViaRow>>
  _boardViasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardVias,
    aliasName: $_aliasNameGenerator(db.nets.id, db.boardVias.netId),
  );

  $$BoardViasTableProcessedTableManager get boardViasRefs {
    final manager = $$BoardViasTableTableManager(
      $_db,
      $_db.boardVias,
    ).filter((f) => f.netId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardViasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BoardZonesTable, List<BoardZoneRow>>
  _boardZonesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.boardZones,
    aliasName: $_aliasNameGenerator(db.nets.id, db.boardZones.netId),
  );

  $$BoardZonesTableProcessedTableManager get boardZonesRefs {
    final manager = $$BoardZonesTableTableManager(
      $_db,
      $_db.boardZones,
    ).filter((f) => f.netId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_boardZonesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NetsTableFilterComposer extends Composer<_$AppDatabase, $NetsTable> {
  $$NetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelX => $composableBuilder(
    column: $table.labelX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelY => $composableBuilder(
    column: $table.labelY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetClassesTableFilterComposer get netClassId {
    final $$NetClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netClassId,
      referencedTable: $db.netClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetClassesTableFilterComposer(
            $db: $db,
            $table: $db.netClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> netNodesRefs(
    Expression<bool> Function($$NetNodesTableFilterComposer f) f,
  ) {
    final $$NetNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netNodes,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetNodesTableFilterComposer(
            $db: $db,
            $table: $db.netNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> schematicWiresRefs(
    Expression<bool> Function($$SchematicWiresTableFilterComposer f) f,
  ) {
    final $$SchematicWiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicWires,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicWiresTableFilterComposer(
            $db: $db,
            $table: $db.schematicWires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardTracksRefs(
    Expression<bool> Function($$BoardTracksTableFilterComposer f) f,
  ) {
    final $$BoardTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTracks,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTracksTableFilterComposer(
            $db: $db,
            $table: $db.boardTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardViasRefs(
    Expression<bool> Function($$BoardViasTableFilterComposer f) f,
  ) {
    final $$BoardViasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardVias,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardViasTableFilterComposer(
            $db: $db,
            $table: $db.boardVias,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> boardZonesRefs(
    Expression<bool> Function($$BoardZonesTableFilterComposer f) f,
  ) {
    final $$BoardZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardZones,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardZonesTableFilterComposer(
            $db: $db,
            $table: $db.boardZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NetsTableOrderingComposer extends Composer<_$AppDatabase, $NetsTable> {
  $$NetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelX => $composableBuilder(
    column: $table.labelX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelY => $composableBuilder(
    column: $table.labelY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetClassesTableOrderingComposer get netClassId {
    final $$NetClassesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netClassId,
      referencedTable: $db.netClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetClassesTableOrderingComposer(
            $db: $db,
            $table: $db.netClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NetsTable> {
  $$NetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get labelX =>
      $composableBuilder(column: $table.labelX, builder: (column) => column);

  GeneratedColumn<double> get labelY =>
      $composableBuilder(column: $table.labelY, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetClassesTableAnnotationComposer get netClassId {
    final $$NetClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netClassId,
      referencedTable: $db.netClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.netClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> netNodesRefs<T extends Object>(
    Expression<T> Function($$NetNodesTableAnnotationComposer a) f,
  ) {
    final $$NetNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.netNodes,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.netNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> schematicWiresRefs<T extends Object>(
    Expression<T> Function($$SchematicWiresTableAnnotationComposer a) f,
  ) {
    final $$SchematicWiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schematicWires,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchematicWiresTableAnnotationComposer(
            $db: $db,
            $table: $db.schematicWires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardTracksRefs<T extends Object>(
    Expression<T> Function($$BoardTracksTableAnnotationComposer a) f,
  ) {
    final $$BoardTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardTracks,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.boardTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardViasRefs<T extends Object>(
    Expression<T> Function($$BoardViasTableAnnotationComposer a) f,
  ) {
    final $$BoardViasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardVias,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardViasTableAnnotationComposer(
            $db: $db,
            $table: $db.boardVias,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> boardZonesRefs<T extends Object>(
    Expression<T> Function($$BoardZonesTableAnnotationComposer a) f,
  ) {
    final $$BoardZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boardZones,
      getReferencedColumn: (t) => t.netId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.boardZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NetsTable,
          NetRow,
          $$NetsTableFilterComposer,
          $$NetsTableOrderingComposer,
          $$NetsTableAnnotationComposer,
          $$NetsTableCreateCompanionBuilder,
          $$NetsTableUpdateCompanionBuilder,
          (NetRow, $$NetsTableReferences),
          NetRow,
          PrefetchHooks Function({
            bool projectId,
            bool netClassId,
            bool netNodesRefs,
            bool schematicWiresRefs,
            bool boardTracksRefs,
            bool boardViasRefs,
            bool boardZonesRefs,
          })
        > {
  $$NetsTableTableManager(_$AppDatabase db, $NetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<double?> labelX = const Value.absent(),
                Value<double?> labelY = const Value.absent(),
                Value<String?> netClassId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetsCompanion(
                id: id,
                projectId: projectId,
                name: name,
                labelX: labelX,
                labelY: labelY,
                netClassId: netClassId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> name = const Value.absent(),
                Value<double?> labelX = const Value.absent(),
                Value<double?> labelY = const Value.absent(),
                Value<String?> netClassId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NetsCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                labelX: labelX,
                labelY: labelY,
                netClassId: netClassId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NetsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                netClassId = false,
                netNodesRefs = false,
                schematicWiresRefs = false,
                boardTracksRefs = false,
                boardViasRefs = false,
                boardZonesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (netNodesRefs) db.netNodes,
                    if (schematicWiresRefs) db.schematicWires,
                    if (boardTracksRefs) db.boardTracks,
                    if (boardViasRefs) db.boardVias,
                    if (boardZonesRefs) db.boardZones,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$NetsTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$NetsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (netClassId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.netClassId,
                                    referencedTable: $$NetsTableReferences
                                        ._netClassIdTable(db),
                                    referencedColumn: $$NetsTableReferences
                                        ._netClassIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (netNodesRefs)
                        await $_getPrefetchedData<
                          NetRow,
                          $NetsTable,
                          NetNodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$NetsTableReferences
                              ._netNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NetsTableReferences(db, table, p0).netNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.netId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (schematicWiresRefs)
                        await $_getPrefetchedData<
                          NetRow,
                          $NetsTable,
                          SchematicWireRow
                        >(
                          currentTable: table,
                          referencedTable: $$NetsTableReferences
                              ._schematicWiresRefsTable(db),
                          managerFromTypedResult: (p0) => $$NetsTableReferences(
                            db,
                            table,
                            p0,
                          ).schematicWiresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.netId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardTracksRefs)
                        await $_getPrefetchedData<
                          NetRow,
                          $NetsTable,
                          BoardTrackRow
                        >(
                          currentTable: table,
                          referencedTable: $$NetsTableReferences
                              ._boardTracksRefsTable(db),
                          managerFromTypedResult: (p0) => $$NetsTableReferences(
                            db,
                            table,
                            p0,
                          ).boardTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.netId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardViasRefs)
                        await $_getPrefetchedData<
                          NetRow,
                          $NetsTable,
                          BoardViaRow
                        >(
                          currentTable: table,
                          referencedTable: $$NetsTableReferences
                              ._boardViasRefsTable(db),
                          managerFromTypedResult: (p0) => $$NetsTableReferences(
                            db,
                            table,
                            p0,
                          ).boardViasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.netId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (boardZonesRefs)
                        await $_getPrefetchedData<
                          NetRow,
                          $NetsTable,
                          BoardZoneRow
                        >(
                          currentTable: table,
                          referencedTable: $$NetsTableReferences
                              ._boardZonesRefsTable(db),
                          managerFromTypedResult: (p0) => $$NetsTableReferences(
                            db,
                            table,
                            p0,
                          ).boardZonesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.netId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NetsTable,
      NetRow,
      $$NetsTableFilterComposer,
      $$NetsTableOrderingComposer,
      $$NetsTableAnnotationComposer,
      $$NetsTableCreateCompanionBuilder,
      $$NetsTableUpdateCompanionBuilder,
      (NetRow, $$NetsTableReferences),
      NetRow,
      PrefetchHooks Function({
        bool projectId,
        bool netClassId,
        bool netNodesRefs,
        bool schematicWiresRefs,
        bool boardTracksRefs,
        bool boardViasRefs,
        bool boardZonesRefs,
      })
    >;
typedef $$NetNodesTableCreateCompanionBuilder =
    NetNodesCompanion Function({
      required String id,
      required String netId,
      required String partPinId,
      Value<bool> labelled,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$NetNodesTableUpdateCompanionBuilder =
    NetNodesCompanion Function({
      Value<String> id,
      Value<String> netId,
      Value<String> partPinId,
      Value<bool> labelled,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$NetNodesTableReferences
    extends BaseReferences<_$AppDatabase, $NetNodesTable, NetNodeRow> {
  $$NetNodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NetsTable _netIdTable(_$AppDatabase db) =>
      db.nets.createAlias($_aliasNameGenerator(db.netNodes.netId, db.nets.id));

  $$NetsTableProcessedTableManager get netId {
    final $_column = $_itemColumn<String>('net_id')!;

    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartPinsTable _partPinIdTable(_$AppDatabase db) => db.partPins
      .createAlias($_aliasNameGenerator(db.netNodes.partPinId, db.partPins.id));

  $$PartPinsTableProcessedTableManager get partPinId {
    final $_column = $_itemColumn<String>('part_pin_id')!;

    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partPinIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NetNodesTableFilterComposer
    extends Composer<_$AppDatabase, $NetNodesTable> {
  $$NetNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get labelled => $composableBuilder(
    column: $table.labelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NetsTableFilterComposer get netId {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableFilterComposer get partPinId {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partPinId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $NetNodesTable> {
  $$NetNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get labelled => $composableBuilder(
    column: $table.labelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NetsTableOrderingComposer get netId {
    final $$NetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableOrderingComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableOrderingComposer get partPinId {
    final $$PartPinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partPinId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableOrderingComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NetNodesTable> {
  $$NetNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get labelled =>
      $composableBuilder(column: $table.labelled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NetsTableAnnotationComposer get netId {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableAnnotationComposer get partPinId {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partPinId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NetNodesTable,
          NetNodeRow,
          $$NetNodesTableFilterComposer,
          $$NetNodesTableOrderingComposer,
          $$NetNodesTableAnnotationComposer,
          $$NetNodesTableCreateCompanionBuilder,
          $$NetNodesTableUpdateCompanionBuilder,
          (NetNodeRow, $$NetNodesTableReferences),
          NetNodeRow,
          PrefetchHooks Function({bool netId, bool partPinId})
        > {
  $$NetNodesTableTableManager(_$AppDatabase db, $NetNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NetNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NetNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NetNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> netId = const Value.absent(),
                Value<String> partPinId = const Value.absent(),
                Value<bool> labelled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetNodesCompanion(
                id: id,
                netId: netId,
                partPinId: partPinId,
                labelled: labelled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String netId,
                required String partPinId,
                Value<bool> labelled = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NetNodesCompanion.insert(
                id: id,
                netId: netId,
                partPinId: partPinId,
                labelled: labelled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NetNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({netId = false, partPinId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (netId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.netId,
                                referencedTable: $$NetNodesTableReferences
                                    ._netIdTable(db),
                                referencedColumn: $$NetNodesTableReferences
                                    ._netIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (partPinId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partPinId,
                                referencedTable: $$NetNodesTableReferences
                                    ._partPinIdTable(db),
                                referencedColumn: $$NetNodesTableReferences
                                    ._partPinIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NetNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NetNodesTable,
      NetNodeRow,
      $$NetNodesTableFilterComposer,
      $$NetNodesTableOrderingComposer,
      $$NetNodesTableAnnotationComposer,
      $$NetNodesTableCreateCompanionBuilder,
      $$NetNodesTableUpdateCompanionBuilder,
      (NetNodeRow, $$NetNodesTableReferences),
      NetNodeRow,
      PrefetchHooks Function({bool netId, bool partPinId})
    >;
typedef $$SchematicWiresTableCreateCompanionBuilder =
    SchematicWiresCompanion Function({
      required String id,
      required String projectId,
      required String netId,
      Value<String?> pinAId,
      Value<String?> pinBId,
      required String points,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SchematicWiresTableUpdateCompanionBuilder =
    SchematicWiresCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> netId,
      Value<String?> pinAId,
      Value<String?> pinBId,
      Value<String> points,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SchematicWiresTableReferences
    extends
        BaseReferences<_$AppDatabase, $SchematicWiresTable, SchematicWireRow> {
  $$SchematicWiresTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.schematicWires.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NetsTable _netIdTable(_$AppDatabase db) => db.nets.createAlias(
    $_aliasNameGenerator(db.schematicWires.netId, db.nets.id),
  );

  $$NetsTableProcessedTableManager get netId {
    final $_column = $_itemColumn<String>('net_id')!;

    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartPinsTable _pinAIdTable(_$AppDatabase db) =>
      db.partPins.createAlias(
        $_aliasNameGenerator(db.schematicWires.pinAId, db.partPins.id),
      );

  $$PartPinsTableProcessedTableManager? get pinAId {
    final $_column = $_itemColumn<String>('pin_a_id');
    if ($_column == null) return null;
    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pinAIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartPinsTable _pinBIdTable(_$AppDatabase db) =>
      db.partPins.createAlias(
        $_aliasNameGenerator(db.schematicWires.pinBId, db.partPins.id),
      );

  $$PartPinsTableProcessedTableManager? get pinBId {
    final $_column = $_itemColumn<String>('pin_b_id');
    if ($_column == null) return null;
    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pinBIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SchematicWiresTableFilterComposer
    extends Composer<_$AppDatabase, $SchematicWiresTable> {
  $$SchematicWiresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableFilterComposer get netId {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableFilterComposer get pinAId {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableFilterComposer get pinBId {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicWiresTableOrderingComposer
    extends Composer<_$AppDatabase, $SchematicWiresTable> {
  $$SchematicWiresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableOrderingComposer get netId {
    final $$NetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableOrderingComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableOrderingComposer get pinAId {
    final $$PartPinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableOrderingComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableOrderingComposer get pinBId {
    final $$PartPinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableOrderingComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicWiresTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchematicWiresTable> {
  $$SchematicWiresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableAnnotationComposer get netId {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableAnnotationComposer get pinAId {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableAnnotationComposer get pinBId {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicWiresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchematicWiresTable,
          SchematicWireRow,
          $$SchematicWiresTableFilterComposer,
          $$SchematicWiresTableOrderingComposer,
          $$SchematicWiresTableAnnotationComposer,
          $$SchematicWiresTableCreateCompanionBuilder,
          $$SchematicWiresTableUpdateCompanionBuilder,
          (SchematicWireRow, $$SchematicWiresTableReferences),
          SchematicWireRow,
          PrefetchHooks Function({
            bool projectId,
            bool netId,
            bool pinAId,
            bool pinBId,
          })
        > {
  $$SchematicWiresTableTableManager(
    _$AppDatabase db,
    $SchematicWiresTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchematicWiresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchematicWiresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchematicWiresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> netId = const Value.absent(),
                Value<String?> pinAId = const Value.absent(),
                Value<String?> pinBId = const Value.absent(),
                Value<String> points = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchematicWiresCompanion(
                id: id,
                projectId: projectId,
                netId: netId,
                pinAId: pinAId,
                pinBId: pinBId,
                points: points,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String netId,
                Value<String?> pinAId = const Value.absent(),
                Value<String?> pinBId = const Value.absent(),
                required String points,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SchematicWiresCompanion.insert(
                id: id,
                projectId: projectId,
                netId: netId,
                pinAId: pinAId,
                pinBId: pinBId,
                points: points,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SchematicWiresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                netId = false,
                pinAId = false,
                pinBId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$SchematicWiresTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$SchematicWiresTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (netId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.netId,
                                    referencedTable:
                                        $$SchematicWiresTableReferences
                                            ._netIdTable(db),
                                    referencedColumn:
                                        $$SchematicWiresTableReferences
                                            ._netIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (pinAId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.pinAId,
                                    referencedTable:
                                        $$SchematicWiresTableReferences
                                            ._pinAIdTable(db),
                                    referencedColumn:
                                        $$SchematicWiresTableReferences
                                            ._pinAIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (pinBId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.pinBId,
                                    referencedTable:
                                        $$SchematicWiresTableReferences
                                            ._pinBIdTable(db),
                                    referencedColumn:
                                        $$SchematicWiresTableReferences
                                            ._pinBIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$SchematicWiresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchematicWiresTable,
      SchematicWireRow,
      $$SchematicWiresTableFilterComposer,
      $$SchematicWiresTableOrderingComposer,
      $$SchematicWiresTableAnnotationComposer,
      $$SchematicWiresTableCreateCompanionBuilder,
      $$SchematicWiresTableUpdateCompanionBuilder,
      (SchematicWireRow, $$SchematicWiresTableReferences),
      SchematicWireRow,
      PrefetchHooks Function({
        bool projectId,
        bool netId,
        bool pinAId,
        bool pinBId,
      })
    >;
typedef $$SymbolLibrariesTableCreateCompanionBuilder =
    SymbolLibrariesCompanion Function({
      required String id,
      required String nickname,
      required String fileName,
      Value<int> formatVersion,
      Value<String> generator,
      Value<int> symbolCount,
      Value<int> byteSize,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$SymbolLibrariesTableUpdateCompanionBuilder =
    SymbolLibrariesCompanion Function({
      Value<String> id,
      Value<String> nickname,
      Value<String> fileName,
      Value<int> formatVersion,
      Value<String> generator,
      Value<int> symbolCount,
      Value<int> byteSize,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

final class $$SymbolLibrariesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SymbolLibrariesTable, SymbolLibraryRow> {
  $$SymbolLibrariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SymbolIndexEntriesTable, List<SymbolIndexRow>>
  _symbolIndexEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.symbolIndexEntries,
        aliasName: $_aliasNameGenerator(
          db.symbolLibraries.id,
          db.symbolIndexEntries.libraryId,
        ),
      );

  $$SymbolIndexEntriesTableProcessedTableManager get symbolIndexEntriesRefs {
    final manager = $$SymbolIndexEntriesTableTableManager(
      $_db,
      $_db.symbolIndexEntries,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _symbolIndexEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SymbolLibrariesTableFilterComposer
    extends Composer<_$AppDatabase, $SymbolLibrariesTable> {
  $$SymbolLibrariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generator => $composableBuilder(
    column: $table.generator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get symbolCount => $composableBuilder(
    column: $table.symbolCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> symbolIndexEntriesRefs(
    Expression<bool> Function($$SymbolIndexEntriesTableFilterComposer f) f,
  ) {
    final $$SymbolIndexEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.symbolIndexEntries,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymbolIndexEntriesTableFilterComposer(
            $db: $db,
            $table: $db.symbolIndexEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SymbolLibrariesTableOrderingComposer
    extends Composer<_$AppDatabase, $SymbolLibrariesTable> {
  $$SymbolLibrariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generator => $composableBuilder(
    column: $table.generator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get symbolCount => $composableBuilder(
    column: $table.symbolCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SymbolLibrariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SymbolLibrariesTable> {
  $$SymbolLibrariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generator =>
      $composableBuilder(column: $table.generator, builder: (column) => column);

  GeneratedColumn<int> get symbolCount => $composableBuilder(
    column: $table.symbolCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  Expression<T> symbolIndexEntriesRefs<T extends Object>(
    Expression<T> Function($$SymbolIndexEntriesTableAnnotationComposer a) f,
  ) {
    final $$SymbolIndexEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.symbolIndexEntries,
          getReferencedColumn: (t) => t.libraryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SymbolIndexEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.symbolIndexEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SymbolLibrariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SymbolLibrariesTable,
          SymbolLibraryRow,
          $$SymbolLibrariesTableFilterComposer,
          $$SymbolLibrariesTableOrderingComposer,
          $$SymbolLibrariesTableAnnotationComposer,
          $$SymbolLibrariesTableCreateCompanionBuilder,
          $$SymbolLibrariesTableUpdateCompanionBuilder,
          (SymbolLibraryRow, $$SymbolLibrariesTableReferences),
          SymbolLibraryRow,
          PrefetchHooks Function({bool symbolIndexEntriesRefs})
        > {
  $$SymbolLibrariesTableTableManager(
    _$AppDatabase db,
    $SymbolLibrariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SymbolLibrariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SymbolLibrariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SymbolLibrariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> generator = const Value.absent(),
                Value<int> symbolCount = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SymbolLibrariesCompanion(
                id: id,
                nickname: nickname,
                fileName: fileName,
                formatVersion: formatVersion,
                generator: generator,
                symbolCount: symbolCount,
                byteSize: byteSize,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nickname,
                required String fileName,
                Value<int> formatVersion = const Value.absent(),
                Value<String> generator = const Value.absent(),
                Value<int> symbolCount = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => SymbolLibrariesCompanion.insert(
                id: id,
                nickname: nickname,
                fileName: fileName,
                formatVersion: formatVersion,
                generator: generator,
                symbolCount: symbolCount,
                byteSize: byteSize,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SymbolLibrariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbolIndexEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (symbolIndexEntriesRefs) db.symbolIndexEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (symbolIndexEntriesRefs)
                    await $_getPrefetchedData<
                      SymbolLibraryRow,
                      $SymbolLibrariesTable,
                      SymbolIndexRow
                    >(
                      currentTable: table,
                      referencedTable: $$SymbolLibrariesTableReferences
                          ._symbolIndexEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SymbolLibrariesTableReferences(
                            db,
                            table,
                            p0,
                          ).symbolIndexEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.libraryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SymbolLibrariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SymbolLibrariesTable,
      SymbolLibraryRow,
      $$SymbolLibrariesTableFilterComposer,
      $$SymbolLibrariesTableOrderingComposer,
      $$SymbolLibrariesTableAnnotationComposer,
      $$SymbolLibrariesTableCreateCompanionBuilder,
      $$SymbolLibrariesTableUpdateCompanionBuilder,
      (SymbolLibraryRow, $$SymbolLibrariesTableReferences),
      SymbolLibraryRow,
      PrefetchHooks Function({bool symbolIndexEntriesRefs})
    >;
typedef $$SymbolIndexEntriesTableCreateCompanionBuilder =
    SymbolIndexEntriesCompanion Function({
      required String id,
      required String libraryId,
      required String libraryNickname,
      required String name,
      Value<String> description,
      Value<String> keywords,
      Value<String> referencePrefix,
      Value<String> defaultFootprint,
      Value<String> datasheet,
      Value<String> footprintFilters,
      Value<int> unitCount,
      Value<int> pinCount,
      Value<bool> isPower,
      Value<String?> extendsSymbol,
      Value<int> spanStart,
      Value<int> spanEnd,
      Value<String> searchText,
      Value<int> rowid,
    });
typedef $$SymbolIndexEntriesTableUpdateCompanionBuilder =
    SymbolIndexEntriesCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String> libraryNickname,
      Value<String> name,
      Value<String> description,
      Value<String> keywords,
      Value<String> referencePrefix,
      Value<String> defaultFootprint,
      Value<String> datasheet,
      Value<String> footprintFilters,
      Value<int> unitCount,
      Value<int> pinCount,
      Value<bool> isPower,
      Value<String?> extendsSymbol,
      Value<int> spanStart,
      Value<int> spanEnd,
      Value<String> searchText,
      Value<int> rowid,
    });

final class $$SymbolIndexEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SymbolIndexEntriesTable,
          SymbolIndexRow
        > {
  $$SymbolIndexEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SymbolLibrariesTable _libraryIdTable(_$AppDatabase db) =>
      db.symbolLibraries.createAlias(
        $_aliasNameGenerator(
          db.symbolIndexEntries.libraryId,
          db.symbolLibraries.id,
        ),
      );

  $$SymbolLibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$SymbolLibrariesTableTableManager(
      $_db,
      $_db.symbolLibraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SymbolIndexEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SymbolIndexEntriesTable> {
  $$SymbolIndexEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencePrefix => $composableBuilder(
    column: $table.referencePrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultFootprint => $composableBuilder(
    column: $table.defaultFootprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasheet => $composableBuilder(
    column: $table.datasheet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get footprintFilters => $composableBuilder(
    column: $table.footprintFilters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinCount => $composableBuilder(
    column: $table.pinCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPower => $composableBuilder(
    column: $table.isPower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extendsSymbol => $composableBuilder(
    column: $table.extendsSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  $$SymbolLibrariesTableFilterComposer get libraryId {
    final $$SymbolLibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.symbolLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymbolLibrariesTableFilterComposer(
            $db: $db,
            $table: $db.symbolLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SymbolIndexEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SymbolIndexEntriesTable> {
  $$SymbolIndexEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencePrefix => $composableBuilder(
    column: $table.referencePrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultFootprint => $composableBuilder(
    column: $table.defaultFootprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasheet => $composableBuilder(
    column: $table.datasheet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get footprintFilters => $composableBuilder(
    column: $table.footprintFilters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinCount => $composableBuilder(
    column: $table.pinCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPower => $composableBuilder(
    column: $table.isPower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extendsSymbol => $composableBuilder(
    column: $table.extendsSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  $$SymbolLibrariesTableOrderingComposer get libraryId {
    final $$SymbolLibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.symbolLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymbolLibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.symbolLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SymbolIndexEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SymbolIndexEntriesTable> {
  $$SymbolIndexEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<String> get referencePrefix => $composableBuilder(
    column: $table.referencePrefix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultFootprint => $composableBuilder(
    column: $table.defaultFootprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datasheet =>
      $composableBuilder(column: $table.datasheet, builder: (column) => column);

  GeneratedColumn<String> get footprintFilters => $composableBuilder(
    column: $table.footprintFilters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitCount =>
      $composableBuilder(column: $table.unitCount, builder: (column) => column);

  GeneratedColumn<int> get pinCount =>
      $composableBuilder(column: $table.pinCount, builder: (column) => column);

  GeneratedColumn<bool> get isPower =>
      $composableBuilder(column: $table.isPower, builder: (column) => column);

  GeneratedColumn<String> get extendsSymbol => $composableBuilder(
    column: $table.extendsSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<int> get spanStart =>
      $composableBuilder(column: $table.spanStart, builder: (column) => column);

  GeneratedColumn<int> get spanEnd =>
      $composableBuilder(column: $table.spanEnd, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  $$SymbolLibrariesTableAnnotationComposer get libraryId {
    final $$SymbolLibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.symbolLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymbolLibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.symbolLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SymbolIndexEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SymbolIndexEntriesTable,
          SymbolIndexRow,
          $$SymbolIndexEntriesTableFilterComposer,
          $$SymbolIndexEntriesTableOrderingComposer,
          $$SymbolIndexEntriesTableAnnotationComposer,
          $$SymbolIndexEntriesTableCreateCompanionBuilder,
          $$SymbolIndexEntriesTableUpdateCompanionBuilder,
          (SymbolIndexRow, $$SymbolIndexEntriesTableReferences),
          SymbolIndexRow,
          PrefetchHooks Function({bool libraryId})
        > {
  $$SymbolIndexEntriesTableTableManager(
    _$AppDatabase db,
    $SymbolIndexEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SymbolIndexEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SymbolIndexEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SymbolIndexEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> libraryNickname = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<String> referencePrefix = const Value.absent(),
                Value<String> defaultFootprint = const Value.absent(),
                Value<String> datasheet = const Value.absent(),
                Value<String> footprintFilters = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<int> pinCount = const Value.absent(),
                Value<bool> isPower = const Value.absent(),
                Value<String?> extendsSymbol = const Value.absent(),
                Value<int> spanStart = const Value.absent(),
                Value<int> spanEnd = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SymbolIndexEntriesCompanion(
                id: id,
                libraryId: libraryId,
                libraryNickname: libraryNickname,
                name: name,
                description: description,
                keywords: keywords,
                referencePrefix: referencePrefix,
                defaultFootprint: defaultFootprint,
                datasheet: datasheet,
                footprintFilters: footprintFilters,
                unitCount: unitCount,
                pinCount: pinCount,
                isPower: isPower,
                extendsSymbol: extendsSymbol,
                spanStart: spanStart,
                spanEnd: spanEnd,
                searchText: searchText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                required String libraryNickname,
                required String name,
                Value<String> description = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<String> referencePrefix = const Value.absent(),
                Value<String> defaultFootprint = const Value.absent(),
                Value<String> datasheet = const Value.absent(),
                Value<String> footprintFilters = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<int> pinCount = const Value.absent(),
                Value<bool> isPower = const Value.absent(),
                Value<String?> extendsSymbol = const Value.absent(),
                Value<int> spanStart = const Value.absent(),
                Value<int> spanEnd = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SymbolIndexEntriesCompanion.insert(
                id: id,
                libraryId: libraryId,
                libraryNickname: libraryNickname,
                name: name,
                description: description,
                keywords: keywords,
                referencePrefix: referencePrefix,
                defaultFootprint: defaultFootprint,
                datasheet: datasheet,
                footprintFilters: footprintFilters,
                unitCount: unitCount,
                pinCount: pinCount,
                isPower: isPower,
                extendsSymbol: extendsSymbol,
                spanStart: spanStart,
                spanEnd: spanEnd,
                searchText: searchText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SymbolIndexEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable:
                                    $$SymbolIndexEntriesTableReferences
                                        ._libraryIdTable(db),
                                referencedColumn:
                                    $$SymbolIndexEntriesTableReferences
                                        ._libraryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SymbolIndexEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SymbolIndexEntriesTable,
      SymbolIndexRow,
      $$SymbolIndexEntriesTableFilterComposer,
      $$SymbolIndexEntriesTableOrderingComposer,
      $$SymbolIndexEntriesTableAnnotationComposer,
      $$SymbolIndexEntriesTableCreateCompanionBuilder,
      $$SymbolIndexEntriesTableUpdateCompanionBuilder,
      (SymbolIndexRow, $$SymbolIndexEntriesTableReferences),
      SymbolIndexRow,
      PrefetchHooks Function({bool libraryId})
    >;
typedef $$NetRouteHintsTableCreateCompanionBuilder =
    NetRouteHintsCompanion Function({
      required String id,
      required String projectId,
      required String pinAId,
      required String pinBId,
      Value<String> turnOffsets,
      Value<int> rowid,
    });
typedef $$NetRouteHintsTableUpdateCompanionBuilder =
    NetRouteHintsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> pinAId,
      Value<String> pinBId,
      Value<String> turnOffsets,
      Value<int> rowid,
    });

final class $$NetRouteHintsTableReferences
    extends
        BaseReferences<_$AppDatabase, $NetRouteHintsTable, NetRouteHintRow> {
  $$NetRouteHintsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.netRouteHints.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartPinsTable _pinAIdTable(_$AppDatabase db) =>
      db.partPins.createAlias(
        $_aliasNameGenerator(db.netRouteHints.pinAId, db.partPins.id),
      );

  $$PartPinsTableProcessedTableManager get pinAId {
    final $_column = $_itemColumn<String>('pin_a_id')!;

    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pinAIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartPinsTable _pinBIdTable(_$AppDatabase db) =>
      db.partPins.createAlias(
        $_aliasNameGenerator(db.netRouteHints.pinBId, db.partPins.id),
      );

  $$PartPinsTableProcessedTableManager get pinBId {
    final $_column = $_itemColumn<String>('pin_b_id')!;

    final manager = $$PartPinsTableTableManager(
      $_db,
      $_db.partPins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pinBIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NetRouteHintsTableFilterComposer
    extends Composer<_$AppDatabase, $NetRouteHintsTable> {
  $$NetRouteHintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnOffsets => $composableBuilder(
    column: $table.turnOffsets,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableFilterComposer get pinAId {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableFilterComposer get pinBId {
    final $$PartPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableFilterComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetRouteHintsTableOrderingComposer
    extends Composer<_$AppDatabase, $NetRouteHintsTable> {
  $$NetRouteHintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnOffsets => $composableBuilder(
    column: $table.turnOffsets,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableOrderingComposer get pinAId {
    final $$PartPinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableOrderingComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableOrderingComposer get pinBId {
    final $$PartPinsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableOrderingComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetRouteHintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NetRouteHintsTable> {
  $$NetRouteHintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get turnOffsets => $composableBuilder(
    column: $table.turnOffsets,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableAnnotationComposer get pinAId {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinAId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartPinsTableAnnotationComposer get pinBId {
    final $$PartPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pinBId,
      referencedTable: $db.partPins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.partPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NetRouteHintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NetRouteHintsTable,
          NetRouteHintRow,
          $$NetRouteHintsTableFilterComposer,
          $$NetRouteHintsTableOrderingComposer,
          $$NetRouteHintsTableAnnotationComposer,
          $$NetRouteHintsTableCreateCompanionBuilder,
          $$NetRouteHintsTableUpdateCompanionBuilder,
          (NetRouteHintRow, $$NetRouteHintsTableReferences),
          NetRouteHintRow,
          PrefetchHooks Function({bool projectId, bool pinAId, bool pinBId})
        > {
  $$NetRouteHintsTableTableManager(_$AppDatabase db, $NetRouteHintsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NetRouteHintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NetRouteHintsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NetRouteHintsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> pinAId = const Value.absent(),
                Value<String> pinBId = const Value.absent(),
                Value<String> turnOffsets = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetRouteHintsCompanion(
                id: id,
                projectId: projectId,
                pinAId: pinAId,
                pinBId: pinBId,
                turnOffsets: turnOffsets,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String pinAId,
                required String pinBId,
                Value<String> turnOffsets = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetRouteHintsCompanion.insert(
                id: id,
                projectId: projectId,
                pinAId: pinAId,
                pinBId: pinBId,
                turnOffsets: turnOffsets,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NetRouteHintsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, pinAId = false, pinBId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$NetRouteHintsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$NetRouteHintsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (pinAId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.pinAId,
                                    referencedTable:
                                        $$NetRouteHintsTableReferences
                                            ._pinAIdTable(db),
                                    referencedColumn:
                                        $$NetRouteHintsTableReferences
                                            ._pinAIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (pinBId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.pinBId,
                                    referencedTable:
                                        $$NetRouteHintsTableReferences
                                            ._pinBIdTable(db),
                                    referencedColumn:
                                        $$NetRouteHintsTableReferences
                                            ._pinBIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$NetRouteHintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NetRouteHintsTable,
      NetRouteHintRow,
      $$NetRouteHintsTableFilterComposer,
      $$NetRouteHintsTableOrderingComposer,
      $$NetRouteHintsTableAnnotationComposer,
      $$NetRouteHintsTableCreateCompanionBuilder,
      $$NetRouteHintsTableUpdateCompanionBuilder,
      (NetRouteHintRow, $$NetRouteHintsTableReferences),
      NetRouteHintRow,
      PrefetchHooks Function({bool projectId, bool pinAId, bool pinBId})
    >;
typedef $$FootprintLibrariesTableCreateCompanionBuilder =
    FootprintLibrariesCompanion Function({
      required String id,
      required String nickname,
      required String fileName,
      Value<int> footprintCount,
      Value<int> byteSize,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$FootprintLibrariesTableUpdateCompanionBuilder =
    FootprintLibrariesCompanion Function({
      Value<String> id,
      Value<String> nickname,
      Value<String> fileName,
      Value<int> footprintCount,
      Value<int> byteSize,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

final class $$FootprintLibrariesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FootprintLibrariesTable,
          FootprintLibraryRow
        > {
  $$FootprintLibrariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $FootprintIndexEntriesTable,
    List<FootprintIndexRow>
  >
  _footprintIndexEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.footprintIndexEntries,
        aliasName: $_aliasNameGenerator(
          db.footprintLibraries.id,
          db.footprintIndexEntries.libraryId,
        ),
      );

  $$FootprintIndexEntriesTableProcessedTableManager
  get footprintIndexEntriesRefs {
    final manager = $$FootprintIndexEntriesTableTableManager(
      $_db,
      $_db.footprintIndexEntries,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _footprintIndexEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FootprintLibrariesTableFilterComposer
    extends Composer<_$AppDatabase, $FootprintLibrariesTable> {
  $$FootprintLibrariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get footprintCount => $composableBuilder(
    column: $table.footprintCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> footprintIndexEntriesRefs(
    Expression<bool> Function($$FootprintIndexEntriesTableFilterComposer f) f,
  ) {
    final $$FootprintIndexEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.footprintIndexEntries,
          getReferencedColumn: (t) => t.libraryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FootprintIndexEntriesTableFilterComposer(
                $db: $db,
                $table: $db.footprintIndexEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FootprintLibrariesTableOrderingComposer
    extends Composer<_$AppDatabase, $FootprintLibrariesTable> {
  $$FootprintLibrariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get footprintCount => $composableBuilder(
    column: $table.footprintCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FootprintLibrariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FootprintLibrariesTable> {
  $$FootprintLibrariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get footprintCount => $composableBuilder(
    column: $table.footprintCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  Expression<T> footprintIndexEntriesRefs<T extends Object>(
    Expression<T> Function($$FootprintIndexEntriesTableAnnotationComposer a) f,
  ) {
    final $$FootprintIndexEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.footprintIndexEntries,
          getReferencedColumn: (t) => t.libraryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FootprintIndexEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.footprintIndexEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FootprintLibrariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FootprintLibrariesTable,
          FootprintLibraryRow,
          $$FootprintLibrariesTableFilterComposer,
          $$FootprintLibrariesTableOrderingComposer,
          $$FootprintLibrariesTableAnnotationComposer,
          $$FootprintLibrariesTableCreateCompanionBuilder,
          $$FootprintLibrariesTableUpdateCompanionBuilder,
          (FootprintLibraryRow, $$FootprintLibrariesTableReferences),
          FootprintLibraryRow,
          PrefetchHooks Function({bool footprintIndexEntriesRefs})
        > {
  $$FootprintLibrariesTableTableManager(
    _$AppDatabase db,
    $FootprintLibrariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FootprintLibrariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FootprintLibrariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FootprintLibrariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> footprintCount = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FootprintLibrariesCompanion(
                id: id,
                nickname: nickname,
                fileName: fileName,
                footprintCount: footprintCount,
                byteSize: byteSize,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nickname,
                required String fileName,
                Value<int> footprintCount = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => FootprintLibrariesCompanion.insert(
                id: id,
                nickname: nickname,
                fileName: fileName,
                footprintCount: footprintCount,
                byteSize: byteSize,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FootprintLibrariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({footprintIndexEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (footprintIndexEntriesRefs) db.footprintIndexEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (footprintIndexEntriesRefs)
                    await $_getPrefetchedData<
                      FootprintLibraryRow,
                      $FootprintLibrariesTable,
                      FootprintIndexRow
                    >(
                      currentTable: table,
                      referencedTable: $$FootprintLibrariesTableReferences
                          ._footprintIndexEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FootprintLibrariesTableReferences(
                            db,
                            table,
                            p0,
                          ).footprintIndexEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.libraryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FootprintLibrariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FootprintLibrariesTable,
      FootprintLibraryRow,
      $$FootprintLibrariesTableFilterComposer,
      $$FootprintLibrariesTableOrderingComposer,
      $$FootprintLibrariesTableAnnotationComposer,
      $$FootprintLibrariesTableCreateCompanionBuilder,
      $$FootprintLibrariesTableUpdateCompanionBuilder,
      (FootprintLibraryRow, $$FootprintLibrariesTableReferences),
      FootprintLibraryRow,
      PrefetchHooks Function({bool footprintIndexEntriesRefs})
    >;
typedef $$FootprintIndexEntriesTableCreateCompanionBuilder =
    FootprintIndexEntriesCompanion Function({
      required String id,
      required String libraryId,
      required String libraryNickname,
      required String name,
      Value<String> description,
      Value<String> keywords,
      Value<int> padCount,
      Value<bool> isSurfaceMount,
      Value<bool> isThroughHole,
      Value<int> spanStart,
      Value<int> spanEnd,
      Value<String> searchText,
      Value<int> rowid,
    });
typedef $$FootprintIndexEntriesTableUpdateCompanionBuilder =
    FootprintIndexEntriesCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String> libraryNickname,
      Value<String> name,
      Value<String> description,
      Value<String> keywords,
      Value<int> padCount,
      Value<bool> isSurfaceMount,
      Value<bool> isThroughHole,
      Value<int> spanStart,
      Value<int> spanEnd,
      Value<String> searchText,
      Value<int> rowid,
    });

final class $$FootprintIndexEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FootprintIndexEntriesTable,
          FootprintIndexRow
        > {
  $$FootprintIndexEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FootprintLibrariesTable _libraryIdTable(_$AppDatabase db) =>
      db.footprintLibraries.createAlias(
        $_aliasNameGenerator(
          db.footprintIndexEntries.libraryId,
          db.footprintLibraries.id,
        ),
      );

  $$FootprintLibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$FootprintLibrariesTableTableManager(
      $_db,
      $_db.footprintLibraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FootprintIndexEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FootprintIndexEntriesTable> {
  $$FootprintIndexEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get padCount => $composableBuilder(
    column: $table.padCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSurfaceMount => $composableBuilder(
    column: $table.isSurfaceMount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isThroughHole => $composableBuilder(
    column: $table.isThroughHole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  $$FootprintLibrariesTableFilterComposer get libraryId {
    final $$FootprintLibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.footprintLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FootprintLibrariesTableFilterComposer(
            $db: $db,
            $table: $db.footprintLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FootprintIndexEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FootprintIndexEntriesTable> {
  $$FootprintIndexEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get padCount => $composableBuilder(
    column: $table.padCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSurfaceMount => $composableBuilder(
    column: $table.isSurfaceMount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isThroughHole => $composableBuilder(
    column: $table.isThroughHole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  $$FootprintLibrariesTableOrderingComposer get libraryId {
    final $$FootprintLibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.footprintLibraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FootprintLibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.footprintLibraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FootprintIndexEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FootprintIndexEntriesTable> {
  $$FootprintIndexEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryNickname => $composableBuilder(
    column: $table.libraryNickname,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<int> get padCount =>
      $composableBuilder(column: $table.padCount, builder: (column) => column);

  GeneratedColumn<bool> get isSurfaceMount => $composableBuilder(
    column: $table.isSurfaceMount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isThroughHole => $composableBuilder(
    column: $table.isThroughHole,
    builder: (column) => column,
  );

  GeneratedColumn<int> get spanStart =>
      $composableBuilder(column: $table.spanStart, builder: (column) => column);

  GeneratedColumn<int> get spanEnd =>
      $composableBuilder(column: $table.spanEnd, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  $$FootprintLibrariesTableAnnotationComposer get libraryId {
    final $$FootprintLibrariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.libraryId,
          referencedTable: $db.footprintLibraries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FootprintLibrariesTableAnnotationComposer(
                $db: $db,
                $table: $db.footprintLibraries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$FootprintIndexEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FootprintIndexEntriesTable,
          FootprintIndexRow,
          $$FootprintIndexEntriesTableFilterComposer,
          $$FootprintIndexEntriesTableOrderingComposer,
          $$FootprintIndexEntriesTableAnnotationComposer,
          $$FootprintIndexEntriesTableCreateCompanionBuilder,
          $$FootprintIndexEntriesTableUpdateCompanionBuilder,
          (FootprintIndexRow, $$FootprintIndexEntriesTableReferences),
          FootprintIndexRow,
          PrefetchHooks Function({bool libraryId})
        > {
  $$FootprintIndexEntriesTableTableManager(
    _$AppDatabase db,
    $FootprintIndexEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FootprintIndexEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FootprintIndexEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FootprintIndexEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> libraryNickname = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<int> padCount = const Value.absent(),
                Value<bool> isSurfaceMount = const Value.absent(),
                Value<bool> isThroughHole = const Value.absent(),
                Value<int> spanStart = const Value.absent(),
                Value<int> spanEnd = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FootprintIndexEntriesCompanion(
                id: id,
                libraryId: libraryId,
                libraryNickname: libraryNickname,
                name: name,
                description: description,
                keywords: keywords,
                padCount: padCount,
                isSurfaceMount: isSurfaceMount,
                isThroughHole: isThroughHole,
                spanStart: spanStart,
                spanEnd: spanEnd,
                searchText: searchText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                required String libraryNickname,
                required String name,
                Value<String> description = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<int> padCount = const Value.absent(),
                Value<bool> isSurfaceMount = const Value.absent(),
                Value<bool> isThroughHole = const Value.absent(),
                Value<int> spanStart = const Value.absent(),
                Value<int> spanEnd = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FootprintIndexEntriesCompanion.insert(
                id: id,
                libraryId: libraryId,
                libraryNickname: libraryNickname,
                name: name,
                description: description,
                keywords: keywords,
                padCount: padCount,
                isSurfaceMount: isSurfaceMount,
                isThroughHole: isThroughHole,
                spanStart: spanStart,
                spanEnd: spanEnd,
                searchText: searchText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FootprintIndexEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable:
                                    $$FootprintIndexEntriesTableReferences
                                        ._libraryIdTable(db),
                                referencedColumn:
                                    $$FootprintIndexEntriesTableReferences
                                        ._libraryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FootprintIndexEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FootprintIndexEntriesTable,
      FootprintIndexRow,
      $$FootprintIndexEntriesTableFilterComposer,
      $$FootprintIndexEntriesTableOrderingComposer,
      $$FootprintIndexEntriesTableAnnotationComposer,
      $$FootprintIndexEntriesTableCreateCompanionBuilder,
      $$FootprintIndexEntriesTableUpdateCompanionBuilder,
      (FootprintIndexRow, $$FootprintIndexEntriesTableReferences),
      FootprintIndexRow,
      PrefetchHooks Function({bool libraryId})
    >;
typedef $$BoardsTableCreateCompanionBuilder =
    BoardsCompanion Function({
      required String id,
      required String projectId,
      Value<double> outlineX,
      Value<double> outlineY,
      Value<double> outlineWidth,
      Value<double> outlineHeight,
      Value<String> outlineKind,
      Value<String> outlinePoints,
      Value<double> trackWidth,
      Value<double> clearance,
      Value<double> viaDiameter,
      Value<double> viaDrill,
      Value<String> trackWidths,
      Value<String> viaSizes,
      Value<double> gridMm,
      Value<int> copperLayers,
      Value<double> thickness,
      Value<String> stackup,
      required DateTime modifiedAt,
      Value<int> rowid,
    });
typedef $$BoardsTableUpdateCompanionBuilder =
    BoardsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<double> outlineX,
      Value<double> outlineY,
      Value<double> outlineWidth,
      Value<double> outlineHeight,
      Value<String> outlineKind,
      Value<String> outlinePoints,
      Value<double> trackWidth,
      Value<double> clearance,
      Value<double> viaDiameter,
      Value<double> viaDrill,
      Value<String> trackWidths,
      Value<String> viaSizes,
      Value<double> gridMm,
      Value<int> copperLayers,
      Value<double> thickness,
      Value<String> stackup,
      Value<DateTime> modifiedAt,
      Value<int> rowid,
    });

final class $$BoardsTableReferences
    extends BaseReferences<_$AppDatabase, $BoardsTable, BoardRow> {
  $$BoardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.boards.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outlineX => $composableBuilder(
    column: $table.outlineX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outlineY => $composableBuilder(
    column: $table.outlineY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outlineWidth => $composableBuilder(
    column: $table.outlineWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outlineHeight => $composableBuilder(
    column: $table.outlineHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outlineKind => $composableBuilder(
    column: $table.outlineKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outlinePoints => $composableBuilder(
    column: $table.outlinePoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viaDiameter => $composableBuilder(
    column: $table.viaDiameter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viaDrill => $composableBuilder(
    column: $table.viaDrill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackWidths => $composableBuilder(
    column: $table.trackWidths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaSizes => $composableBuilder(
    column: $table.viaSizes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gridMm => $composableBuilder(
    column: $table.gridMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get copperLayers => $composableBuilder(
    column: $table.copperLayers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thickness => $composableBuilder(
    column: $table.thickness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stackup => $composableBuilder(
    column: $table.stackup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outlineX => $composableBuilder(
    column: $table.outlineX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outlineY => $composableBuilder(
    column: $table.outlineY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outlineWidth => $composableBuilder(
    column: $table.outlineWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outlineHeight => $composableBuilder(
    column: $table.outlineHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outlineKind => $composableBuilder(
    column: $table.outlineKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outlinePoints => $composableBuilder(
    column: $table.outlinePoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viaDiameter => $composableBuilder(
    column: $table.viaDiameter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viaDrill => $composableBuilder(
    column: $table.viaDrill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackWidths => $composableBuilder(
    column: $table.trackWidths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaSizes => $composableBuilder(
    column: $table.viaSizes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gridMm => $composableBuilder(
    column: $table.gridMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copperLayers => $composableBuilder(
    column: $table.copperLayers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thickness => $composableBuilder(
    column: $table.thickness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stackup => $composableBuilder(
    column: $table.stackup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get outlineX =>
      $composableBuilder(column: $table.outlineX, builder: (column) => column);

  GeneratedColumn<double> get outlineY =>
      $composableBuilder(column: $table.outlineY, builder: (column) => column);

  GeneratedColumn<double> get outlineWidth => $composableBuilder(
    column: $table.outlineWidth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get outlineHeight => $composableBuilder(
    column: $table.outlineHeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outlineKind => $composableBuilder(
    column: $table.outlineKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outlinePoints => $composableBuilder(
    column: $table.outlinePoints,
    builder: (column) => column,
  );

  GeneratedColumn<double> get trackWidth => $composableBuilder(
    column: $table.trackWidth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get clearance =>
      $composableBuilder(column: $table.clearance, builder: (column) => column);

  GeneratedColumn<double> get viaDiameter => $composableBuilder(
    column: $table.viaDiameter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get viaDrill =>
      $composableBuilder(column: $table.viaDrill, builder: (column) => column);

  GeneratedColumn<String> get trackWidths => $composableBuilder(
    column: $table.trackWidths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaSizes =>
      $composableBuilder(column: $table.viaSizes, builder: (column) => column);

  GeneratedColumn<double> get gridMm =>
      $composableBuilder(column: $table.gridMm, builder: (column) => column);

  GeneratedColumn<int> get copperLayers => $composableBuilder(
    column: $table.copperLayers,
    builder: (column) => column,
  );

  GeneratedColumn<double> get thickness =>
      $composableBuilder(column: $table.thickness, builder: (column) => column);

  GeneratedColumn<String> get stackup =>
      $composableBuilder(column: $table.stackup, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardsTable,
          BoardRow,
          $$BoardsTableFilterComposer,
          $$BoardsTableOrderingComposer,
          $$BoardsTableAnnotationComposer,
          $$BoardsTableCreateCompanionBuilder,
          $$BoardsTableUpdateCompanionBuilder,
          (BoardRow, $$BoardsTableReferences),
          BoardRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$BoardsTableTableManager(_$AppDatabase db, $BoardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<double> outlineX = const Value.absent(),
                Value<double> outlineY = const Value.absent(),
                Value<double> outlineWidth = const Value.absent(),
                Value<double> outlineHeight = const Value.absent(),
                Value<String> outlineKind = const Value.absent(),
                Value<String> outlinePoints = const Value.absent(),
                Value<double> trackWidth = const Value.absent(),
                Value<double> clearance = const Value.absent(),
                Value<double> viaDiameter = const Value.absent(),
                Value<double> viaDrill = const Value.absent(),
                Value<String> trackWidths = const Value.absent(),
                Value<String> viaSizes = const Value.absent(),
                Value<double> gridMm = const Value.absent(),
                Value<int> copperLayers = const Value.absent(),
                Value<double> thickness = const Value.absent(),
                Value<String> stackup = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardsCompanion(
                id: id,
                projectId: projectId,
                outlineX: outlineX,
                outlineY: outlineY,
                outlineWidth: outlineWidth,
                outlineHeight: outlineHeight,
                outlineKind: outlineKind,
                outlinePoints: outlinePoints,
                trackWidth: trackWidth,
                clearance: clearance,
                viaDiameter: viaDiameter,
                viaDrill: viaDrill,
                trackWidths: trackWidths,
                viaSizes: viaSizes,
                gridMm: gridMm,
                copperLayers: copperLayers,
                thickness: thickness,
                stackup: stackup,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<double> outlineX = const Value.absent(),
                Value<double> outlineY = const Value.absent(),
                Value<double> outlineWidth = const Value.absent(),
                Value<double> outlineHeight = const Value.absent(),
                Value<String> outlineKind = const Value.absent(),
                Value<String> outlinePoints = const Value.absent(),
                Value<double> trackWidth = const Value.absent(),
                Value<double> clearance = const Value.absent(),
                Value<double> viaDiameter = const Value.absent(),
                Value<double> viaDrill = const Value.absent(),
                Value<String> trackWidths = const Value.absent(),
                Value<String> viaSizes = const Value.absent(),
                Value<double> gridMm = const Value.absent(),
                Value<int> copperLayers = const Value.absent(),
                Value<double> thickness = const Value.absent(),
                Value<String> stackup = const Value.absent(),
                required DateTime modifiedAt,
                Value<int> rowid = const Value.absent(),
              }) => BoardsCompanion.insert(
                id: id,
                projectId: projectId,
                outlineX: outlineX,
                outlineY: outlineY,
                outlineWidth: outlineWidth,
                outlineHeight: outlineHeight,
                outlineKind: outlineKind,
                outlinePoints: outlinePoints,
                trackWidth: trackWidth,
                clearance: clearance,
                viaDiameter: viaDiameter,
                viaDrill: viaDrill,
                trackWidths: trackWidths,
                viaSizes: viaSizes,
                gridMm: gridMm,
                copperLayers: copperLayers,
                thickness: thickness,
                stackup: stackup,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BoardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardsTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardsTable,
      BoardRow,
      $$BoardsTableFilterComposer,
      $$BoardsTableOrderingComposer,
      $$BoardsTableAnnotationComposer,
      $$BoardsTableCreateCompanionBuilder,
      $$BoardsTableUpdateCompanionBuilder,
      (BoardRow, $$BoardsTableReferences),
      BoardRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$BoardFootprintsTableCreateCompanionBuilder =
    BoardFootprintsCompanion Function({
      required String id,
      required String projectId,
      required String partId,
      required String libId,
      Value<double> x,
      Value<double> y,
      Value<double> rotation,
      Value<bool> flipped,
      Value<bool> placed,
      Value<double?> labelX,
      Value<double?> labelY,
      Value<double> labelSize,
      Value<bool> labelHidden,
      Value<int> rowid,
    });
typedef $$BoardFootprintsTableUpdateCompanionBuilder =
    BoardFootprintsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> partId,
      Value<String> libId,
      Value<double> x,
      Value<double> y,
      Value<double> rotation,
      Value<bool> flipped,
      Value<bool> placed,
      Value<double?> labelX,
      Value<double?> labelY,
      Value<double> labelSize,
      Value<bool> labelHidden,
      Value<int> rowid,
    });

final class $$BoardFootprintsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $BoardFootprintsTable,
          BoardFootprintRow
        > {
  $$BoardFootprintsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardFootprints.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PartsTable _partIdTable(_$AppDatabase db) => db.parts.createAlias(
    $_aliasNameGenerator(db.boardFootprints.partId, db.parts.id),
  );

  $$PartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$PartsTableTableManager(
      $_db,
      $_db.parts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardFootprintsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardFootprintsTable> {
  $$BoardFootprintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libId => $composableBuilder(
    column: $table.libId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get flipped => $composableBuilder(
    column: $table.flipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get placed => $composableBuilder(
    column: $table.placed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelX => $composableBuilder(
    column: $table.labelX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelY => $composableBuilder(
    column: $table.labelY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelSize => $composableBuilder(
    column: $table.labelSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get labelHidden => $composableBuilder(
    column: $table.labelHidden,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsTableFilterComposer get partId {
    final $$PartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableFilterComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardFootprintsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardFootprintsTable> {
  $$BoardFootprintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libId => $composableBuilder(
    column: $table.libId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flipped => $composableBuilder(
    column: $table.flipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get placed => $composableBuilder(
    column: $table.placed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelX => $composableBuilder(
    column: $table.labelX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelY => $composableBuilder(
    column: $table.labelY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelSize => $composableBuilder(
    column: $table.labelSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get labelHidden => $composableBuilder(
    column: $table.labelHidden,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsTableOrderingComposer get partId {
    final $$PartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableOrderingComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardFootprintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardFootprintsTable> {
  $$BoardFootprintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libId =>
      $composableBuilder(column: $table.libId, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<bool> get flipped =>
      $composableBuilder(column: $table.flipped, builder: (column) => column);

  GeneratedColumn<bool> get placed =>
      $composableBuilder(column: $table.placed, builder: (column) => column);

  GeneratedColumn<double> get labelX =>
      $composableBuilder(column: $table.labelX, builder: (column) => column);

  GeneratedColumn<double> get labelY =>
      $composableBuilder(column: $table.labelY, builder: (column) => column);

  GeneratedColumn<double> get labelSize =>
      $composableBuilder(column: $table.labelSize, builder: (column) => column);

  GeneratedColumn<bool> get labelHidden => $composableBuilder(
    column: $table.labelHidden,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PartsTableAnnotationComposer get partId {
    final $$PartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.parts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PartsTableAnnotationComposer(
            $db: $db,
            $table: $db.parts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardFootprintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardFootprintsTable,
          BoardFootprintRow,
          $$BoardFootprintsTableFilterComposer,
          $$BoardFootprintsTableOrderingComposer,
          $$BoardFootprintsTableAnnotationComposer,
          $$BoardFootprintsTableCreateCompanionBuilder,
          $$BoardFootprintsTableUpdateCompanionBuilder,
          (BoardFootprintRow, $$BoardFootprintsTableReferences),
          BoardFootprintRow,
          PrefetchHooks Function({bool projectId, bool partId})
        > {
  $$BoardFootprintsTableTableManager(
    _$AppDatabase db,
    $BoardFootprintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardFootprintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardFootprintsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardFootprintsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String> libId = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<bool> flipped = const Value.absent(),
                Value<bool> placed = const Value.absent(),
                Value<double?> labelX = const Value.absent(),
                Value<double?> labelY = const Value.absent(),
                Value<double> labelSize = const Value.absent(),
                Value<bool> labelHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardFootprintsCompanion(
                id: id,
                projectId: projectId,
                partId: partId,
                libId: libId,
                x: x,
                y: y,
                rotation: rotation,
                flipped: flipped,
                placed: placed,
                labelX: labelX,
                labelY: labelY,
                labelSize: labelSize,
                labelHidden: labelHidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String partId,
                required String libId,
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<bool> flipped = const Value.absent(),
                Value<bool> placed = const Value.absent(),
                Value<double?> labelX = const Value.absent(),
                Value<double?> labelY = const Value.absent(),
                Value<double> labelSize = const Value.absent(),
                Value<bool> labelHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardFootprintsCompanion.insert(
                id: id,
                projectId: projectId,
                partId: partId,
                libId: libId,
                x: x,
                y: y,
                rotation: rotation,
                flipped: flipped,
                placed: placed,
                labelX: labelX,
                labelY: labelY,
                labelSize: labelSize,
                labelHidden: labelHidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardFootprintsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, partId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$BoardFootprintsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$BoardFootprintsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (partId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.partId,
                                referencedTable:
                                    $$BoardFootprintsTableReferences
                                        ._partIdTable(db),
                                referencedColumn:
                                    $$BoardFootprintsTableReferences
                                        ._partIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardFootprintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardFootprintsTable,
      BoardFootprintRow,
      $$BoardFootprintsTableFilterComposer,
      $$BoardFootprintsTableOrderingComposer,
      $$BoardFootprintsTableAnnotationComposer,
      $$BoardFootprintsTableCreateCompanionBuilder,
      $$BoardFootprintsTableUpdateCompanionBuilder,
      (BoardFootprintRow, $$BoardFootprintsTableReferences),
      BoardFootprintRow,
      PrefetchHooks Function({bool projectId, bool partId})
    >;
typedef $$BoardTracksTableCreateCompanionBuilder =
    BoardTracksCompanion Function({
      required String id,
      required String projectId,
      Value<String?> netId,
      required String layer,
      required double startX,
      required double startY,
      required double endX,
      required double endY,
      Value<double> width,
      Value<int> rowid,
    });
typedef $$BoardTracksTableUpdateCompanionBuilder =
    BoardTracksCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> netId,
      Value<String> layer,
      Value<double> startX,
      Value<double> startY,
      Value<double> endX,
      Value<double> endY,
      Value<double> width,
      Value<int> rowid,
    });

final class $$BoardTracksTableReferences
    extends BaseReferences<_$AppDatabase, $BoardTracksTable, BoardTrackRow> {
  $$BoardTracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardTracks.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NetsTable _netIdTable(_$AppDatabase db) => db.nets.createAlias(
    $_aliasNameGenerator(db.boardTracks.netId, db.nets.id),
  );

  $$NetsTableProcessedTableManager? get netId {
    final $_column = $_itemColumn<String>('net_id');
    if ($_column == null) return null;
    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardTracksTableFilterComposer
    extends Composer<_$AppDatabase, $BoardTracksTable> {
  $$BoardTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startX => $composableBuilder(
    column: $table.startX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startY => $composableBuilder(
    column: $table.startY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endX => $composableBuilder(
    column: $table.endX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endY => $composableBuilder(
    column: $table.endY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableFilterComposer get netId {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardTracksTable> {
  $$BoardTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startX => $composableBuilder(
    column: $table.startX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startY => $composableBuilder(
    column: $table.startY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endX => $composableBuilder(
    column: $table.endX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endY => $composableBuilder(
    column: $table.endY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableOrderingComposer get netId {
    final $$NetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableOrderingComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardTracksTable> {
  $$BoardTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<double> get startX =>
      $composableBuilder(column: $table.startX, builder: (column) => column);

  GeneratedColumn<double> get startY =>
      $composableBuilder(column: $table.startY, builder: (column) => column);

  GeneratedColumn<double> get endX =>
      $composableBuilder(column: $table.endX, builder: (column) => column);

  GeneratedColumn<double> get endY =>
      $composableBuilder(column: $table.endY, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableAnnotationComposer get netId {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardTracksTable,
          BoardTrackRow,
          $$BoardTracksTableFilterComposer,
          $$BoardTracksTableOrderingComposer,
          $$BoardTracksTableAnnotationComposer,
          $$BoardTracksTableCreateCompanionBuilder,
          $$BoardTracksTableUpdateCompanionBuilder,
          (BoardTrackRow, $$BoardTracksTableReferences),
          BoardTrackRow,
          PrefetchHooks Function({bool projectId, bool netId})
        > {
  $$BoardTracksTableTableManager(_$AppDatabase db, $BoardTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> netId = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<double> startX = const Value.absent(),
                Value<double> startY = const Value.absent(),
                Value<double> endX = const Value.absent(),
                Value<double> endY = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardTracksCompanion(
                id: id,
                projectId: projectId,
                netId: netId,
                layer: layer,
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                width: width,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> netId = const Value.absent(),
                required String layer,
                required double startX,
                required double startY,
                required double endX,
                required double endY,
                Value<double> width = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardTracksCompanion.insert(
                id: id,
                projectId: projectId,
                netId: netId,
                layer: layer,
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                width: width,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, netId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardTracksTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardTracksTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (netId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.netId,
                                referencedTable: $$BoardTracksTableReferences
                                    ._netIdTable(db),
                                referencedColumn: $$BoardTracksTableReferences
                                    ._netIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardTracksTable,
      BoardTrackRow,
      $$BoardTracksTableFilterComposer,
      $$BoardTracksTableOrderingComposer,
      $$BoardTracksTableAnnotationComposer,
      $$BoardTracksTableCreateCompanionBuilder,
      $$BoardTracksTableUpdateCompanionBuilder,
      (BoardTrackRow, $$BoardTracksTableReferences),
      BoardTrackRow,
      PrefetchHooks Function({bool projectId, bool netId})
    >;
typedef $$BoardViasTableCreateCompanionBuilder =
    BoardViasCompanion Function({
      required String id,
      required String projectId,
      Value<String?> netId,
      required double x,
      required double y,
      Value<double> diameter,
      Value<double> drill,
      Value<int> rowid,
    });
typedef $$BoardViasTableUpdateCompanionBuilder =
    BoardViasCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> netId,
      Value<double> x,
      Value<double> y,
      Value<double> diameter,
      Value<double> drill,
      Value<int> rowid,
    });

final class $$BoardViasTableReferences
    extends BaseReferences<_$AppDatabase, $BoardViasTable, BoardViaRow> {
  $$BoardViasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardVias.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NetsTable _netIdTable(_$AppDatabase db) =>
      db.nets.createAlias($_aliasNameGenerator(db.boardVias.netId, db.nets.id));

  $$NetsTableProcessedTableManager? get netId {
    final $_column = $_itemColumn<String>('net_id');
    if ($_column == null) return null;
    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardViasTableFilterComposer
    extends Composer<_$AppDatabase, $BoardViasTable> {
  $$BoardViasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get drill => $composableBuilder(
    column: $table.drill,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableFilterComposer get netId {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardViasTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardViasTable> {
  $$BoardViasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get drill => $composableBuilder(
    column: $table.drill,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableOrderingComposer get netId {
    final $$NetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableOrderingComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardViasTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardViasTable> {
  $$BoardViasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get diameter =>
      $composableBuilder(column: $table.diameter, builder: (column) => column);

  GeneratedColumn<double> get drill =>
      $composableBuilder(column: $table.drill, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableAnnotationComposer get netId {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardViasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardViasTable,
          BoardViaRow,
          $$BoardViasTableFilterComposer,
          $$BoardViasTableOrderingComposer,
          $$BoardViasTableAnnotationComposer,
          $$BoardViasTableCreateCompanionBuilder,
          $$BoardViasTableUpdateCompanionBuilder,
          (BoardViaRow, $$BoardViasTableReferences),
          BoardViaRow,
          PrefetchHooks Function({bool projectId, bool netId})
        > {
  $$BoardViasTableTableManager(_$AppDatabase db, $BoardViasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardViasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardViasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardViasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> netId = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> diameter = const Value.absent(),
                Value<double> drill = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardViasCompanion(
                id: id,
                projectId: projectId,
                netId: netId,
                x: x,
                y: y,
                diameter: diameter,
                drill: drill,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> netId = const Value.absent(),
                required double x,
                required double y,
                Value<double> diameter = const Value.absent(),
                Value<double> drill = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardViasCompanion.insert(
                id: id,
                projectId: projectId,
                netId: netId,
                x: x,
                y: y,
                diameter: diameter,
                drill: drill,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardViasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, netId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardViasTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardViasTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (netId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.netId,
                                referencedTable: $$BoardViasTableReferences
                                    ._netIdTable(db),
                                referencedColumn: $$BoardViasTableReferences
                                    ._netIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardViasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardViasTable,
      BoardViaRow,
      $$BoardViasTableFilterComposer,
      $$BoardViasTableOrderingComposer,
      $$BoardViasTableAnnotationComposer,
      $$BoardViasTableCreateCompanionBuilder,
      $$BoardViasTableUpdateCompanionBuilder,
      (BoardViaRow, $$BoardViasTableReferences),
      BoardViaRow,
      PrefetchHooks Function({bool projectId, bool netId})
    >;
typedef $$BoardEdgesTableCreateCompanionBuilder =
    BoardEdgesCompanion Function({
      required String id,
      required String projectId,
      required String kind,
      Value<String> points,
      Value<double> width,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$BoardEdgesTableUpdateCompanionBuilder =
    BoardEdgesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> kind,
      Value<String> points,
      Value<double> width,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BoardEdgesTableReferences
    extends BaseReferences<_$AppDatabase, $BoardEdgesTable, BoardEdgeRow> {
  $$BoardEdgesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardEdges.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $BoardEdgesTable> {
  $$BoardEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardEdgesTable> {
  $$BoardEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardEdgesTable> {
  $$BoardEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardEdgesTable,
          BoardEdgeRow,
          $$BoardEdgesTableFilterComposer,
          $$BoardEdgesTableOrderingComposer,
          $$BoardEdgesTableAnnotationComposer,
          $$BoardEdgesTableCreateCompanionBuilder,
          $$BoardEdgesTableUpdateCompanionBuilder,
          (BoardEdgeRow, $$BoardEdgesTableReferences),
          BoardEdgeRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$BoardEdgesTableTableManager(_$AppDatabase db, $BoardEdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> points = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardEdgesCompanion(
                id: id,
                projectId: projectId,
                kind: kind,
                points: points,
                width: width,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String kind,
                Value<String> points = const Value.absent(),
                Value<double> width = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BoardEdgesCompanion.insert(
                id: id,
                projectId: projectId,
                kind: kind,
                points: points,
                width: width,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardEdgesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardEdgesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardEdgesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardEdgesTable,
      BoardEdgeRow,
      $$BoardEdgesTableFilterComposer,
      $$BoardEdgesTableOrderingComposer,
      $$BoardEdgesTableAnnotationComposer,
      $$BoardEdgesTableCreateCompanionBuilder,
      $$BoardEdgesTableUpdateCompanionBuilder,
      (BoardEdgeRow, $$BoardEdgesTableReferences),
      BoardEdgeRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$BoardZonesTableCreateCompanionBuilder =
    BoardZonesCompanion Function({
      required String id,
      required String projectId,
      Value<String?> netId,
      Value<String> netName,
      required String layer,
      Value<String> points,
      Value<double> clearance,
      Value<double> minThickness,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$BoardZonesTableUpdateCompanionBuilder =
    BoardZonesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> netId,
      Value<String> netName,
      Value<String> layer,
      Value<String> points,
      Value<double> clearance,
      Value<double> minThickness,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BoardZonesTableReferences
    extends BaseReferences<_$AppDatabase, $BoardZonesTable, BoardZoneRow> {
  $$BoardZonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardZones.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NetsTable _netIdTable(_$AppDatabase db) => db.nets.createAlias(
    $_aliasNameGenerator(db.boardZones.netId, db.nets.id),
  );

  $$NetsTableProcessedTableManager? get netId {
    final $_column = $_itemColumn<String>('net_id');
    if ($_column == null) return null;
    final manager = $$NetsTableTableManager(
      $_db,
      $_db.nets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_netIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardZonesTableFilterComposer
    extends Composer<_$AppDatabase, $BoardZonesTable> {
  $$BoardZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get netName => $composableBuilder(
    column: $table.netName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minThickness => $composableBuilder(
    column: $table.minThickness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableFilterComposer get netId {
    final $$NetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableFilterComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardZonesTable> {
  $$BoardZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get netName => $composableBuilder(
    column: $table.netName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get clearance => $composableBuilder(
    column: $table.clearance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minThickness => $composableBuilder(
    column: $table.minThickness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableOrderingComposer get netId {
    final $$NetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableOrderingComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardZonesTable> {
  $$BoardZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get netName =>
      $composableBuilder(column: $table.netName, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<double> get clearance =>
      $composableBuilder(column: $table.clearance, builder: (column) => column);

  GeneratedColumn<double> get minThickness => $composableBuilder(
    column: $table.minThickness,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NetsTableAnnotationComposer get netId {
    final $$NetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.netId,
      referencedTable: $db.nets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NetsTableAnnotationComposer(
            $db: $db,
            $table: $db.nets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardZonesTable,
          BoardZoneRow,
          $$BoardZonesTableFilterComposer,
          $$BoardZonesTableOrderingComposer,
          $$BoardZonesTableAnnotationComposer,
          $$BoardZonesTableCreateCompanionBuilder,
          $$BoardZonesTableUpdateCompanionBuilder,
          (BoardZoneRow, $$BoardZonesTableReferences),
          BoardZoneRow,
          PrefetchHooks Function({bool projectId, bool netId})
        > {
  $$BoardZonesTableTableManager(_$AppDatabase db, $BoardZonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> netId = const Value.absent(),
                Value<String> netName = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<String> points = const Value.absent(),
                Value<double> clearance = const Value.absent(),
                Value<double> minThickness = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardZonesCompanion(
                id: id,
                projectId: projectId,
                netId: netId,
                netName: netName,
                layer: layer,
                points: points,
                clearance: clearance,
                minThickness: minThickness,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> netId = const Value.absent(),
                Value<String> netName = const Value.absent(),
                required String layer,
                Value<String> points = const Value.absent(),
                Value<double> clearance = const Value.absent(),
                Value<double> minThickness = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BoardZonesCompanion.insert(
                id: id,
                projectId: projectId,
                netId: netId,
                netName: netName,
                layer: layer,
                points: points,
                clearance: clearance,
                minThickness: minThickness,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardZonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, netId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardZonesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardZonesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (netId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.netId,
                                referencedTable: $$BoardZonesTableReferences
                                    ._netIdTable(db),
                                referencedColumn: $$BoardZonesTableReferences
                                    ._netIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardZonesTable,
      BoardZoneRow,
      $$BoardZonesTableFilterComposer,
      $$BoardZonesTableOrderingComposer,
      $$BoardZonesTableAnnotationComposer,
      $$BoardZonesTableCreateCompanionBuilder,
      $$BoardZonesTableUpdateCompanionBuilder,
      (BoardZoneRow, $$BoardZonesTableReferences),
      BoardZoneRow,
      PrefetchHooks Function({bool projectId, bool netId})
    >;
typedef $$BoardTextsTableCreateCompanionBuilder =
    BoardTextsCompanion Function({
      required String id,
      required String projectId,
      required String content,
      required double x,
      required double y,
      Value<double> rotation,
      Value<double> size,
      required String layer,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$BoardTextsTableUpdateCompanionBuilder =
    BoardTextsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> content,
      Value<double> x,
      Value<double> y,
      Value<double> rotation,
      Value<double> size,
      Value<String> layer,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BoardTextsTableReferences
    extends BaseReferences<_$AppDatabase, $BoardTextsTable, BoardTextRow> {
  $$BoardTextsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.boardTexts.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BoardTextsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardTextsTable> {
  $$BoardTextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTextsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardTextsTable> {
  $$BoardTextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardTextsTable> {
  $$BoardTextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<double> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoardTextsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardTextsTable,
          BoardTextRow,
          $$BoardTextsTableFilterComposer,
          $$BoardTextsTableOrderingComposer,
          $$BoardTextsTableAnnotationComposer,
          $$BoardTextsTableCreateCompanionBuilder,
          $$BoardTextsTableUpdateCompanionBuilder,
          (BoardTextRow, $$BoardTextsTableReferences),
          BoardTextRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$BoardTextsTableTableManager(_$AppDatabase db, $BoardTextsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardTextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardTextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardTextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<double> size = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardTextsCompanion(
                id: id,
                projectId: projectId,
                content: content,
                x: x,
                y: y,
                rotation: rotation,
                size: size,
                layer: layer,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String content,
                required double x,
                required double y,
                Value<double> rotation = const Value.absent(),
                Value<double> size = const Value.absent(),
                required String layer,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BoardTextsCompanion.insert(
                id: id,
                projectId: projectId,
                content: content,
                x: x,
                y: y,
                rotation: rotation,
                size: size,
                layer: layer,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BoardTextsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$BoardTextsTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$BoardTextsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BoardTextsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardTextsTable,
      BoardTextRow,
      $$BoardTextsTableFilterComposer,
      $$BoardTextsTableOrderingComposer,
      $$BoardTextsTableAnnotationComposer,
      $$BoardTextsTableCreateCompanionBuilder,
      $$BoardTextsTableUpdateCompanionBuilder,
      (BoardTextRow, $$BoardTextsTableReferences),
      BoardTextRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$ProjectSnapshotsTableCreateCompanionBuilder =
    ProjectSnapshotsCompanion Function({
      required String id,
      required String projectId,
      required String name,
      Value<bool> automatic,
      required String data,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProjectSnapshotsTableUpdateCompanionBuilder =
    ProjectSnapshotsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> name,
      Value<bool> automatic,
      Value<String> data,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProjectSnapshotsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ProjectSnapshotsTable,
          ProjectSnapshotRow
        > {
  $$ProjectSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.projectSnapshots.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectSnapshotsTable> {
  $$ProjectSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automatic => $composableBuilder(
    column: $table.automatic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectSnapshotsTable> {
  $$ProjectSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automatic => $composableBuilder(
    column: $table.automatic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectSnapshotsTable> {
  $$ProjectSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get automatic =>
      $composableBuilder(column: $table.automatic, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectSnapshotsTable,
          ProjectSnapshotRow,
          $$ProjectSnapshotsTableFilterComposer,
          $$ProjectSnapshotsTableOrderingComposer,
          $$ProjectSnapshotsTableAnnotationComposer,
          $$ProjectSnapshotsTableCreateCompanionBuilder,
          $$ProjectSnapshotsTableUpdateCompanionBuilder,
          (ProjectSnapshotRow, $$ProjectSnapshotsTableReferences),
          ProjectSnapshotRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$ProjectSnapshotsTableTableManager(
    _$AppDatabase db,
    $ProjectSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> automatic = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSnapshotsCompanion(
                id: id,
                projectId: projectId,
                name: name,
                automatic: automatic,
                data: data,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String name,
                Value<bool> automatic = const Value.absent(),
                required String data,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectSnapshotsCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                automatic: automatic,
                data: data,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$ProjectSnapshotsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$ProjectSnapshotsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectSnapshotsTable,
      ProjectSnapshotRow,
      $$ProjectSnapshotsTableFilterComposer,
      $$ProjectSnapshotsTableOrderingComposer,
      $$ProjectSnapshotsTableAnnotationComposer,
      $$ProjectSnapshotsTableCreateCompanionBuilder,
      $$ProjectSnapshotsTableUpdateCompanionBuilder,
      (ProjectSnapshotRow, $$ProjectSnapshotsTableReferences),
      ProjectSnapshotRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$SchematicNotesTableCreateCompanionBuilder =
    SchematicNotesCompanion Function({
      required String id,
      required String projectId,
      Value<String> kind,
      Value<String> content,
      required double x,
      required double y,
      Value<double> width,
      Value<double> height,
      Value<double> size,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SchematicNotesTableUpdateCompanionBuilder =
    SchematicNotesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> kind,
      Value<String> content,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<double> size,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SchematicNotesTableReferences
    extends
        BaseReferences<_$AppDatabase, $SchematicNotesTable, SchematicNoteRow> {
  $$SchematicNotesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.schematicNotes.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SchematicNotesTableFilterComposer
    extends Composer<_$AppDatabase, $SchematicNotesTable> {
  $$SchematicNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $SchematicNotesTable> {
  $$SchematicNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchematicNotesTable> {
  $$SchematicNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchematicNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchematicNotesTable,
          SchematicNoteRow,
          $$SchematicNotesTableFilterComposer,
          $$SchematicNotesTableOrderingComposer,
          $$SchematicNotesTableAnnotationComposer,
          $$SchematicNotesTableCreateCompanionBuilder,
          $$SchematicNotesTableUpdateCompanionBuilder,
          (SchematicNoteRow, $$SchematicNotesTableReferences),
          SchematicNoteRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$SchematicNotesTableTableManager(
    _$AppDatabase db,
    $SchematicNotesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchematicNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchematicNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchematicNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> size = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchematicNotesCompanion(
                id: id,
                projectId: projectId,
                kind: kind,
                content: content,
                x: x,
                y: y,
                width: width,
                height: height,
                size: size,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                required double x,
                required double y,
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> size = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SchematicNotesCompanion.insert(
                id: id,
                projectId: projectId,
                kind: kind,
                content: content,
                x: x,
                y: y,
                width: width,
                height: height,
                size: size,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SchematicNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$SchematicNotesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn:
                                    $$SchematicNotesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SchematicNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchematicNotesTable,
      SchematicNoteRow,
      $$SchematicNotesTableFilterComposer,
      $$SchematicNotesTableOrderingComposer,
      $$SchematicNotesTableAnnotationComposer,
      $$SchematicNotesTableCreateCompanionBuilder,
      $$SchematicNotesTableUpdateCompanionBuilder,
      (SchematicNoteRow, $$SchematicNotesTableReferences),
      SchematicNoteRow,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$ProjectSettingsTableCreateCompanionBuilder =
    ProjectSettingsCompanion Function({
      required String projectId,
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ProjectSettingsTableUpdateCompanionBuilder =
    ProjectSettingsCompanion Function({
      Value<String> projectId,
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

final class $$ProjectSettingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ProjectSettingsTable,
          ProjectSettingRow
        > {
  $$ProjectSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.projectSettings.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTable> {
  $$ProjectSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectSettingsTable,
          ProjectSettingRow,
          $$ProjectSettingsTableFilterComposer,
          $$ProjectSettingsTableOrderingComposer,
          $$ProjectSettingsTableAnnotationComposer,
          $$ProjectSettingsTableCreateCompanionBuilder,
          $$ProjectSettingsTableUpdateCompanionBuilder,
          (ProjectSettingRow, $$ProjectSettingsTableReferences),
          ProjectSettingRow,
          PrefetchHooks Function({bool projectId})
        > {
  $$ProjectSettingsTableTableManager(
    _$AppDatabase db,
    $ProjectSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSettingsCompanion(
                projectId: projectId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ProjectSettingsCompanion.insert(
                projectId: projectId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$ProjectSettingsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$ProjectSettingsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectSettingsTable,
      ProjectSettingRow,
      $$ProjectSettingsTableFilterComposer,
      $$ProjectSettingsTableOrderingComposer,
      $$ProjectSettingsTableAnnotationComposer,
      $$ProjectSettingsTableCreateCompanionBuilder,
      $$ProjectSettingsTableUpdateCompanionBuilder,
      (ProjectSettingRow, $$ProjectSettingsTableReferences),
      ProjectSettingRow,
      PrefetchHooks Function({bool projectId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$PartsTableTableManager get parts =>
      $$PartsTableTableManager(_db, _db.parts);
  $$PartUnitsTableTableManager get partUnits =>
      $$PartUnitsTableTableManager(_db, _db.partUnits);
  $$PartPinsTableTableManager get partPins =>
      $$PartPinsTableTableManager(_db, _db.partPins);
  $$NetClassesTableTableManager get netClasses =>
      $$NetClassesTableTableManager(_db, _db.netClasses);
  $$NetsTableTableManager get nets => $$NetsTableTableManager(_db, _db.nets);
  $$NetNodesTableTableManager get netNodes =>
      $$NetNodesTableTableManager(_db, _db.netNodes);
  $$SchematicWiresTableTableManager get schematicWires =>
      $$SchematicWiresTableTableManager(_db, _db.schematicWires);
  $$SymbolLibrariesTableTableManager get symbolLibraries =>
      $$SymbolLibrariesTableTableManager(_db, _db.symbolLibraries);
  $$SymbolIndexEntriesTableTableManager get symbolIndexEntries =>
      $$SymbolIndexEntriesTableTableManager(_db, _db.symbolIndexEntries);
  $$NetRouteHintsTableTableManager get netRouteHints =>
      $$NetRouteHintsTableTableManager(_db, _db.netRouteHints);
  $$FootprintLibrariesTableTableManager get footprintLibraries =>
      $$FootprintLibrariesTableTableManager(_db, _db.footprintLibraries);
  $$FootprintIndexEntriesTableTableManager get footprintIndexEntries =>
      $$FootprintIndexEntriesTableTableManager(_db, _db.footprintIndexEntries);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db, _db.boards);
  $$BoardFootprintsTableTableManager get boardFootprints =>
      $$BoardFootprintsTableTableManager(_db, _db.boardFootprints);
  $$BoardTracksTableTableManager get boardTracks =>
      $$BoardTracksTableTableManager(_db, _db.boardTracks);
  $$BoardViasTableTableManager get boardVias =>
      $$BoardViasTableTableManager(_db, _db.boardVias);
  $$BoardEdgesTableTableManager get boardEdges =>
      $$BoardEdgesTableTableManager(_db, _db.boardEdges);
  $$BoardZonesTableTableManager get boardZones =>
      $$BoardZonesTableTableManager(_db, _db.boardZones);
  $$BoardTextsTableTableManager get boardTexts =>
      $$BoardTextsTableTableManager(_db, _db.boardTexts);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ProjectSnapshotsTableTableManager get projectSnapshots =>
      $$ProjectSnapshotsTableTableManager(_db, _db.projectSnapshots);
  $$SchematicNotesTableTableManager get schematicNotes =>
      $$SchematicNotesTableTableManager(_db, _db.schematicNotes);
  $$ProjectSettingsTableTableManager get projectSettings =>
      $$ProjectSettingsTableTableManager(_db, _db.projectSettings);
}
