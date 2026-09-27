import 'dart:convert';
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
    this.pins = const [],
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

  /// The pins its box was given where it came from — a KiCad file's sheet
  /// pins, each on the edge it was drawn on. A net crossing the edge that
  /// none of them carries still gets a pin, added below them on the left.
  final List<SheetPin> pins;

  SchematicSheet copyWith({
    String? name,
    String? fileName,
    String? parentId,
    bool toTopSheet = false,
    Rect? box,
    int? sortOrder,
    List<SheetPin>? pins,
  }) => SchematicSheet(
    id: id,
    projectId: projectId,
    parentId: toTopSheet ? null : (parentId ?? this.parentId),
    name: name ?? this.name,
    fileName: fileName ?? this.fileName,
    box: box ?? this.box,
    sortOrder: sortOrder ?? this.sortOrder,
    pins: pins ?? this.pins,
  );

  @override
  String toString() => 'SchematicSheet($name)';
}

/// Which edge of a sheet's box a pin sits on.
enum SheetSide { left, right, top, bottom }

/// A pin on a sheet's box, as KiCad has it: a name matching a hierarchical
/// label inside the sheet, a shape, and a place on one edge.
///
/// Its place is kept along the edge, from the box's top or left, so the pin
/// goes with the box when it is moved or resized.
class SheetPin {
  const SheetPin({
    required this.name,
    required this.side,
    required this.offset,
    this.shape = 'bidirectional',
    this.netId,
  });

  final String name;
  final SheetSide side;

  /// Along its edge, in millimetres: down from the top for the left and
  /// right edges, across from the left for the top and bottom.
  final double offset;

  /// KiCad's `input`, `output`, `bidirectional`, `tri_state` or `passive`.
  final String shape;

  /// The net it carried when it came in. Nets are renamed on the way in
  /// (`/Power/VIN` for a pin called `VIN`), so the name alone cannot find
  /// it; the name is the fallback for a net since merged away.
  final String? netId;

  /// Where it is, on the sheet, for a box at [box].
  Offset at(Rect box) => switch (side) {
    SheetSide.left => Offset(box.left, box.top + offset),
    SheetSide.right => Offset(box.right, box.top + offset),
    SheetSide.top => Offset(box.left + offset, box.top),
    SheetSide.bottom => Offset(box.left + offset, box.bottom),
  };

  /// The pin at [point] on the nearest edge of [box].
  static SheetPin onEdge({
    required String name,
    required Rect box,
    required Offset point,
    String shape = 'bidirectional',
    String? netId,
  }) {
    final distances = {
      SheetSide.left: (point.dx - box.left).abs(),
      SheetSide.right: (point.dx - box.right).abs(),
      SheetSide.top: (point.dy - box.top).abs(),
      SheetSide.bottom: (point.dy - box.bottom).abs(),
    };
    final side = distances.entries
        .reduce((a, b) => b.value < a.value ? b : a)
        .key;
    final offset = switch (side) {
      SheetSide.left || SheetSide.right => point.dy - box.top,
      SheetSide.top || SheetSide.bottom => point.dx - box.left,
    };
    return SheetPin(
      name: name,
      side: side,
      offset: offset,
      shape: shape,
      netId: netId,
    );
  }

  SheetPin withNet(String? netId) => SheetPin(
    name: name,
    side: side,
    offset: offset,
    shape: shape,
    netId: netId,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'side': side.name,
    'offset': offset,
    'shape': shape,
    if (netId != null) 'net': netId,
  };

  static SheetPin fromJson(Map<String, Object?> json) => SheetPin(
    name: json['name'] as String? ?? '',
    side: SheetSide.values.asNameMap()[json['side']] ?? SheetSide.left,
    offset: (json['offset'] as num?)?.toDouble() ?? 0,
    shape: json['shape'] as String? ?? 'bidirectional',
    netId: json['net'] as String?,
  );

  static String encode(List<SheetPin> pins) =>
      pins.isEmpty ? '' : jsonEncode([for (final p in pins) p.toJson()]);

  static List<SheetPin> decode(String text) {
    if (text.trim().isEmpty) return const [];
    try {
      return [
        for (final raw in jsonDecode(text) as List)
          fromJson((raw as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }
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
