import 'dart:ui';

/// Which kind of KiCad label: one joining its own sheet, the whole design,
/// or a sheet to the pin of its box on the sheet above.
enum SchematicLabelKind {
  local('label'),
  global('global_label'),
  hierarchical('hierarchical_label');

  const SchematicLabelKind(this.token);

  /// KiCad's name for it.
  final String token;

  static SchematicLabelKind? fromToken(String token) =>
      values.where((k) => k.token == token).firstOrNull;
}

/// A label exactly as it was drawn: on its sheet, at its spot on a wire,
/// facing its way, at its size. Brought in from KiCad, so a design comes in
/// looking as it was left rather than labelled over again by the app.
///
/// Which net it names is not stored. It is whatever is under it — the wire
/// its anchor sits on, or a pin — the same way KiCad works it out.
class SchematicLabel {
  const SchematicLabel({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.text,
    required this.position,
    this.sheetId,
    this.angle = 0,
    this.size = 1.27,
    this.shape = 'bidirectional',
  });

  final String id;
  final String projectId;

  /// The sub-sheet it is on; null for the top sheet.
  final String? sheetId;
  final SchematicLabelKind kind;
  final String text;

  /// The anchor: the point that touches the wire, in sheet millimetres.
  final Offset position;

  /// 0, 90, 180 or 270: which way the text runs from the anchor.
  final double angle;

  /// Character height, in millimetres.
  final double size;

  /// A global or hierarchical label's flag: `input`, `output`,
  /// `bidirectional`, `tri_state` or `passive`.
  final String shape;
}

/// Whether [text] names a bus rather than a net: `D[0..7]`, or a group
/// like `UART{TX RX}`. Braces straight after `~`, `^` or `_` are KiCad's
/// overbar, superscript and subscript, as in `~{RESET}`, not a group.
bool isBusName(String text) =>
    RegExp(r'\[\d+\.\.\d+\]').hasMatch(text) ||
    RegExp(r'(^|[^~^_])\{[^}]*\}').hasMatch(text);
