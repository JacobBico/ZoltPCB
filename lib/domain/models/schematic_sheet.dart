import 'dart:ui';

/// A sub-sheet of a hierarchical schematic: a page of its own, drawn on its
/// parent as a box with a pin for every net crossing its edge.
class SchematicSheet {
  const SchematicSheet({
    required this.id,
    required this.projectId,
    required this.name,
    required this.fileName,
    this.parentId,
    this.box = const Rect.fromLTWH(0, 0, 30.48, 20.32),
    this.sortOrder = 0,
  });

  final String id;
  final String projectId;

  /// The sheet this one sits on; null when it sits on the top sheet.
  final String? parentId;
  final String name;

  /// The `.kicad_sch` file it is written to, beside the top sheet's.
  final String fileName;

  /// Where its box is drawn on the parent, in sheet millimetres.
  final Rect box;
  final int sortOrder;

  SchematicSheet copyWith({
    String? name,
    String? fileName,
    String? parentId,
    bool toTopSheet = false,
    Rect? box,
    int? sortOrder,
  }) => SchematicSheet(
    id: id,
    projectId: projectId,
    parentId: toTopSheet ? null : (parentId ?? this.parentId),
    name: name ?? this.name,
    fileName: fileName ?? this.fileName,
    box: box ?? this.box,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  String toString() => 'SchematicSheet($name)';
}

/// The sheets of a project as a tree, for walking and for naming.
class SheetTree {
  SheetTree(List<SchematicSheet> sheets)
    : sheets = [...sheets]
        ..sort(
          (a, b) => a.sortOrder != b.sortOrder
              ? a.sortOrder.compareTo(b.sortOrder)
              : a.name.compareTo(b.name),
        );

  final List<SchematicSheet> sheets;

  bool get isEmpty => sheets.isEmpty;

  SchematicSheet? byId(String? id) =>
      id == null ? null : sheets.where((s) => s.id == id).firstOrNull;

  /// The sheets directly on [parentId] (null: the top sheet).
  List<SchematicSheet> childrenOf(String? parentId) => [
    for (final sheet in sheets)
      if (sheet.parentId == parentId) sheet,
  ];

  /// [sheetId] and every sheet beneath it.
  Set<String?> subtree(String? sheetId) {
    final out = <String?>{sheetId};
    final queue = [sheetId];
    while (queue.isNotEmpty) {
      final next = queue.removeLast();
      for (final child in childrenOf(next)) {
        if (out.add(child.id)) queue.add(child.id);
      }
    }
    return out;
  }

  /// The sheets from the top down to [sheetId], not counting the top.
  List<SchematicSheet> pathTo(String? sheetId) {
    final path = <SchematicSheet>[];
    var current = byId(sheetId);
    final seen = <String>{};
    while (current != null && seen.add(current.id)) {
      path.insert(0, current);
      current = byId(current.parentId);
    }
    return path;
  }

  /// How deep [sheetId] is: 0 for the top sheet.
  int depthOf(String? sheetId) => pathTo(sheetId).length;

  /// KiCad's name for the sheet: `/Power/Regulator/`, and `/` for the top.
  String pathName(String? sheetId) =>
      '/${[for (final s in pathTo(sheetId)) '${s.name}/'].join()}';

  /// Every sheet in the order a reader would page through them: each one
  /// followed by the sheets on it.
  List<SchematicSheet> inPageOrder() {
    final out = <SchematicSheet>[];
    void walk(String? parent) {
      for (final child in childrenOf(parent)) {
        out.add(child);
        walk(child.id);
      }
    }

    walk(null);
    return out;
  }
}
