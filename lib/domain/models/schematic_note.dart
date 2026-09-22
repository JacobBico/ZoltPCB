import 'dart:math' as math;
import 'dart:ui';

/// What a note on the sheet is.
enum NoteKind {
  /// Words, anchored at their top-left corner.
  text,

  /// A dashed rectangle round a section, its caption at the top-left.
  box;

  static NoteKind byName(String? name) =>
      values.where((k) => k.name == name).firstOrNull ?? text;
}

/// Free text or a box drawn on the schematic: "5 V rail, 500 mA max", or a
/// frame round the power section. Not connectivity and not a component —
/// just how a drawing stays understandable a month later.
class SchematicNote {
  const SchematicNote({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.content,
    required this.position,
    this.size = const Size(0, 0),
    this.textSize = defaultTextSize,
    this.sheetId,
  });

  /// The sub-sheet the note is on; null for the top sheet.
  final String? sheetId;

  /// KiCad's own default text height, in millimetres.
  static const defaultTextSize = 1.27;

  final String id;
  final String projectId;
  final NoteKind kind;
  final String content;

  /// Top-left corner, in sheet millimetres.
  final Offset position;

  /// A box's size; ignored for text.
  final Size size;

  /// Character height, in millimetres.
  final double textSize;

  List<String> get lines => content.split('\n');

  /// The rough extent of the text itself: a character is about 0.7 of its
  /// height across in KiCad's font, and a line about 1.6 heights tall.
  Size get textExtent {
    final longest = lines.fold<int>(0, (m, l) => math.max(m, l.length));
    return Size(longest * textSize * 0.72, lines.length * textSize * 1.6);
  }

  /// Everything the note covers, in sheet millimetres.
  Rect get bounds =>
      kind == NoteKind.box ? position & size : position & textExtent;

  /// Whether a touch at [point] means this note.
  ///
  /// Text anywhere over its words. A box only on its frame or its caption,
  /// never in the middle — the middle is full of parts that the touch is
  /// far more likely to be for.
  bool hit(Offset point, double tolerance) {
    if (kind == NoteKind.text) {
      return bounds.inflate(tolerance).contains(point);
    }
    final outer = bounds.inflate(tolerance);
    final inner = bounds.deflate(tolerance);
    final onFrame =
        outer.contains(point) && (inner.isEmpty || !inner.contains(point));
    final caption = Rect.fromLTWH(
      position.dx,
      position.dy,
      textExtent.width,
      textExtent.height,
    ).inflate(tolerance);
    return onFrame || (content.isNotEmpty && caption.contains(point));
  }

  SchematicNote copyWith({
    NoteKind? kind,
    String? content,
    Offset? position,
    Size? size,
    double? textSize,
  }) => SchematicNote(
    id: id,
    projectId: projectId,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    position: position ?? this.position,
    size: size ?? this.size,
    textSize: textSize ?? this.textSize,
    sheetId: sheetId,
  );

  @override
  bool operator ==(Object other) =>
      other is SchematicNote &&
      other.id == id &&
      other.kind == kind &&
      other.content == content &&
      other.position == position &&
      other.size == size &&
      other.textSize == textSize;

  @override
  int get hashCode => Object.hash(id, kind, content, position, size, textSize);
}
