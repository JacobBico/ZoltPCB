/// A parsed s-expression node.
///
/// KiCad's file formats are all s-expressions, so this layer is deliberately
/// generic: it knows nothing about symbols, schematics or pins. The symbol
/// parser gives the tokens meaning; the schematic writer will reuse the same
/// shapes in the other direction.
sealed class SExpr {
  const SExpr();
}

/// A bare token or a quoted string.
///
/// Whether a value was quoted matters when writing files back out — `yes`
/// and `"yes"` are different tokens to KiCad — so it is preserved rather
/// than normalised away.
final class SAtom extends SExpr {
  const SAtom(this.value, {this.quoted = false});

  final String value;
  final bool quoted;

  @override
  String toString() => quoted ? '"$value"' : value;
}

/// A parenthesised list, e.g. `(at 1.27 -3.81 90)`.
final class SList extends SExpr {
  const SList(this.items);

  final List<SExpr> items;

  /// The leading token, which names the node: `at` in `(at 0 0)`.
  String? get head {
    if (items.isEmpty) return null;
    final first = items.first;
    return first is SAtom ? first.value : null;
  }

  /// The first child list named [name], or null.
  SList? child(String name) {
    for (final item in items) {
      if (item is SList && item.head == name) return item;
    }
    return null;
  }

  /// Every child list named [name], in order.
  Iterable<SList> children(String name) sync* {
    for (final item in items) {
      if (item is SList && item.head == name) yield item;
    }
  }

  /// Every child list, whatever its name.
  Iterable<SList> get lists sync* {
    for (final item in items) {
      if (item is SList) yield item;
    }
  }

  /// The atom at [index] counting the head as 0, or null if absent or a
  /// list.
  String? atom(int index) {
    if (index >= items.length) return null;
    final item = items[index];
    return item is SAtom ? item.value : null;
  }

  double? number(int index) {
    final value = atom(index);
    return value == null ? null : double.tryParse(value);
  }

  int? integer(int index) {
    final value = atom(index);
    if (value == null) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }

  /// The first atom of the child list named [name]: `1.016` for
  /// `(offset 1.016)`.
  String? childAtom(String name, [int index = 1]) => child(name)?.atom(index);

  double? childNumber(String name, [int index = 1]) =>
      child(name)?.number(index);

  int? childInteger(String name, [int index = 1]) =>
      child(name)?.integer(index);

  /// Reads a boolean flag that KiCad has written two different ways.
  ///
  /// Files from version 8 and earlier carry a bare token — `(pin_names
  /// (offset 1.016) hide)`. Version 9 and later wrap it — `(hide yes)`.
  /// Both mean the same thing, and imported libraries may be either.
  bool flag(String name, {bool orElse = false}) {
    for (final item in items) {
      if (item is SAtom && !item.quoted && item.value == name) return true;
      if (item is SList && item.head == name) {
        final value = item.atom(1);
        // `(hide)` with no argument is the older no-argument form.
        if (value == null) return true;
        return value == 'yes' || value == 'true';
      }
    }
    return orElse;
  }

  @override
  String toString() => '(${items.join(' ')})';
}
