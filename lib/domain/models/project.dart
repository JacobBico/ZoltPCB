/// Standard schematic sheet sizes, matching KiCad's page setup options.
enum PaperSize {
  a5('A5', 210.0, 148.0),
  a4('A4', 297.0, 210.0),
  a3('A3', 420.0, 297.0),
  a2('A2', 594.0, 420.0),
  a1('A1', 841.0, 594.0),
  a0('A0', 1189.0, 841.0),
  usLetter('USLetter', 279.4, 215.9),
  usLegal('USLegal', 355.6, 215.9),
  usLedger('USLedger', 431.8, 279.4);

  const PaperSize(this.kicadName, this.widthMm, this.heightMm);

  /// The token KiCad writes in `(paper "...")`.
  final String kicadName;
  final double widthMm;
  final double heightMm;

  static PaperSize fromKicadName(String name) => PaperSize.values.firstWhere(
    (p) => p.kicadName == name,
    orElse: () => PaperSize.a4,
  );
}

/// A schematic design. The top-level unit of work; everything else in the
/// data model hangs off a project.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.description = '',
    this.paper = PaperSize.a4,
    this.company = '',
    this.revision = '',
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final PaperSize paper;
  final String company;
  final String revision;

  Project copyWith({
    String? name,
    String? description,
    DateTime? modifiedAt,
    PaperSize? paper,
    String? company,
    String? revision,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      paper: paper ?? this.paper,
      company: company ?? this.company,
      revision: revision ?? this.revision,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.createdAt == createdAt &&
      other.modifiedAt == modifiedAt &&
      other.paper == paper &&
      other.company == company &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
    modifiedAt,
    paper,
    company,
    revision,
  );

  @override
  String toString() => 'Project($id, $name)';
}

/// A project plus the counts shown in the project list.
class ProjectSummary {
  const ProjectSummary({
    required this.project,
    required this.partCount,
    required this.netCount,
  });

  final Project project;
  final int partCount;
  final int netCount;

  String get id => project.id;

  bool get isEmpty => partCount == 0 && netCount == 0;

  @override
  String toString() =>
      'ProjectSummary(${project.name}, $partCount parts, $netCount nets)';
}
