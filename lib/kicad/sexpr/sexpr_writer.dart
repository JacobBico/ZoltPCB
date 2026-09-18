import 'sexpr.dart';

/// Builds s-expression nodes.
///
/// A thin convenience over [SList]/[SAtom] so the writers read like the
/// files they produce.
abstract final class S {
  static SList list(String head, List<SExpr> children) =>
      SList([SAtom(head), ...children]);

  /// A node whose arguments are all plain values: `(at 1.27 -3.81 90)`.
  static SList of(String head, List<Object?> values) => SList([
    SAtom(head),
    for (final value in values)
      if (value != null) _atom(value),
  ]);

  static SAtom text(String value) => SAtom(value, quoted: true);

  static SAtom token(String value) => SAtom(value);

  /// KiCad writes booleans as the bare tokens `yes` and `no`.
  static SAtom yesNo(bool value) => SAtom(value ? 'yes' : 'no');

  static SList flag(String head, bool value) =>
      SList([SAtom(head), yesNo(value)]);

  static SAtom number(num value) => SAtom(formatNumber(value.toDouble()));

  static SAtom _atom(Object value) => switch (value) {
    SAtom() => value,
    bool() => yesNo(value),
    num() => number(value),
    _ => SAtom('$value'),
  };

  /// Formats a coordinate the way KiCad does: no exponent, no trailing
  /// zeros, and whole numbers without a decimal point.
  ///
  /// This matters beyond tidiness — KiCad's parser is strict about numeric
  /// tokens, and `1e-7` or `NaN` in a coordinate makes a file it refuses to
  /// open.
  static String formatNumber(double value) {
    if (!value.isFinite) return '0';
    // Round to KiCad's internal resolution (1 nm) to avoid values like
    // 25.399999999999999 surviving from floating-point arithmetic.
    final rounded = (value * 1000000).round() / 1000000;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toInt().toString();
    }
    var text = rounded.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text == '-0' ? '0' : text;
  }
}

/// Writes an s-expression tree in KiCad's own layout.
///
/// The formatting is not cosmetic: files are read back by people and by
/// version control, and matching KiCad's own style means a HintPCB export
/// and a KiCad re-save differ only where the content differs.
class SExprWriter {
  const SExprWriter({this.indent = '\t'});

  final String indent;

  String write(SList root) {
    final buffer = StringBuffer();
    _writeList(buffer, root, 0);
    buffer.writeln();
    return buffer.toString();
  }

  void _writeList(StringBuffer buffer, SList node, int depth) {
    final children = node.items.whereType<SList>().toList();
    final atoms = node.items.whereType<SAtom>().toList();

    buffer.write('(');
    for (var i = 0; i < atoms.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(_atomText(atoms[i]));
    }

    if (children.isEmpty) {
      buffer.write(')');
      return;
    }

    for (final child in children) {
      buffer.writeln();
      buffer.write(indent * (depth + 1));
      _writeList(buffer, child, depth + 1);
    }
    buffer.writeln();
    buffer.write(indent * depth);
    buffer.write(')');
  }

  String _atomText(SAtom atom) =>
      atom.quoted ? '"${escape(atom.value)}"' : atom.value;

  /// Escapes what KiCad's reader treats specially inside a quoted string:
  /// the backslash, the quote, and a line break, which KiCad writes as
  /// `\n` in multi-line text.
  static String escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
}
