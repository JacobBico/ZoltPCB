/// Turns a short description of several net names into the names.
///
/// The notation is KiCad's bus syntax, and a little more:
///
/// * `D[0..7]` — `D0` to `D7`; `A[3..0]` counts down, `LED[1..3]_EN`
///   keeps what follows the brackets.
/// * `SPI_{MOSI MISO SCK}` — a group, each member with the prefix.
/// * `SDA, SCL` or `SDA SCL` — a plain list.
///
/// Pieces combine: `D[0..3], CLK, CS` is six names. Anything that does not
/// parse is taken as a name as it stands, rather than refused — a label
/// the user typed is never silently lost.
abstract final class LabelPattern {
  static List<String> expand(String pattern) {
    final names = <String>[];
    for (final token in _tokens(pattern)) {
      names.addAll(_expandToken(token));
    }
    return names;
  }

  /// Splits at commas and spaces that are not inside brackets or braces.
  static List<String> _tokens(String pattern) {
    final tokens = <String>[];
    final current = StringBuffer();
    var depth = 0;
    for (final char in pattern.split('')) {
      if (char == '[' || char == '{') depth++;
      if (char == ']' || char == '}') depth = depth > 0 ? depth - 1 : 0;
      if (depth == 0 && (char == ',' || char.trim().isEmpty)) {
        if (current.isNotEmpty) tokens.add(current.toString());
        current.clear();
        continue;
      }
      current.write(char);
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    return tokens;
  }

  static final _range = RegExp(r'^(.*?)\[(\d+)\.\.(\d+)\](.*)$');
  static final _group = RegExp(r'^(.*?)\{([^}]*)\}(.*)$');

  static List<String> _expandToken(String token) {
    // Whichever comes first in the name is the outer loop, so the names
    // come out in reading order: P{A B}[0..1] is PA0, PA1, PB0, PB1.
    final brace = token.indexOf('{');
    final bracket = token.indexOf('[');
    final groupFirst = brace >= 0 && (bracket < 0 || brace < bracket);
    final range = groupFirst ? null : _range.firstMatch(token);
    if (range != null) {
      final prefix = range.group(1)!;
      final from = int.parse(range.group(2)!);
      final to = int.parse(range.group(3)!);
      final suffix = range.group(4)!;
      // A range of a thousand labels is a typo, not a bus.
      if ((to - from).abs() > 512) return [token];
      final step = to >= from ? 1 : -1;
      return [
        for (var i = from; step > 0 ? i <= to : i >= to; i += step)
          ..._expandToken('$prefix$i$suffix'),
      ];
    }
    final group = _group.firstMatch(token);
    if (group != null) {
      final prefix = group.group(1)!;
      final suffix = group.group(3)!;
      return [
        for (final member in _tokens(group.group(2)!))
          ..._expandToken('$prefix$member$suffix'),
      ];
    }
    return [token];
  }
}
