import 'dart:convert';
import 'dart:typed_data';

import '../domain/symbols/symbols.dart';
import 'sexpr/sexpr_parser.dart';
import 'symbol_parser.dart';

const int _quote = 0x22;
const int _openParen = 0x28;
const int _closeParen = 0x29;
const int _backslash = 0x5c;

/// Where one symbol lives inside a library file.
///
/// Byte offsets, not character offsets: the point of recording them is to
/// seek straight to a symbol later and read just those bytes, without
/// decoding the rest of a multi-megabyte file.
class SymbolSpan {
  const SymbolSpan({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final int start;
  final int end;

  int get length => end - start;

  @override
  String toString() => 'SymbolSpan($name, $start..$end)';
}

/// The `(kicad_symbol_lib (version ...) (generator ...))` preamble.
class SymbolLibraryHeader {
  const SymbolLibraryHeader({
    this.version = 0,
    this.generator = '',
    this.generatorVersion = '',
  });

  /// Format version, e.g. 20251024. KiCad bumps this per release.
  final int version;
  final String generator;
  final String generatorVersion;

  @override
  String toString() => 'SymbolLibraryHeader($version, $generator)';
}

/// A library file read end to end.
class ParsedSymbolLibrary {
  const ParsedSymbolLibrary({
    required this.nickname,
    required this.header,
    required this.symbols,
    required this.spans,
    this.warnings = const [],
  });

  final String nickname;
  final SymbolLibraryHeader header;

  /// Symbols with `extends` already resolved, in file order.
  final List<SymbolDefinition> symbols;

  /// Byte ranges, parallel to [symbols] by name.
  final Map<String, SymbolSpan> spans;

  /// Non-fatal problems, e.g. a symbol extending one that is not present.
  final List<String> warnings;

  int get symbolCount => symbols.length;

  @override
  String toString() =>
      'ParsedSymbolLibrary($nickname, $symbolCount symbols, '
      '${warnings.length} warnings)';
}

/// Reads `.kicad_sym` files.
///
/// Kept separate from [SymbolParser] because the two jobs have different
/// shapes: this one is about locating symbols in a file and resolving
/// inheritance between them, while the parser turns a single node into a
/// definition.
abstract final class SymbolLibraryReader {
  /// Locates every top-level symbol without parsing any of them.
  ///
  /// A plain scan for `(symbol "` would be wrong: parentheses and quotes
  /// occur inside property values (`"Dual opamp (SOIC-8)"`), and every
  /// symbol contains nested child symbols. So this tracks nesting depth and
  /// string state, and only records lists that begin at depth 1.
  static List<SymbolSpan> scanSpans(Uint8List bytes) {
    final spans = <SymbolSpan>[];
    final length = bytes.length;

    var depth = 0;
    var index = 0;
    int? symbolStart;
    String? symbolName;

    while (index < length) {
      final byte = bytes[index];

      if (byte == _quote) {
        index = _skipString(bytes, index);
        continue;
      }

      if (byte == _openParen) {
        if (depth == 1) {
          final head = _readBareToken(bytes, index + 1);
          if (head != null && head.value == 'symbol') {
            final name = _readQuotedToken(bytes, head.end);
            if (name != null) {
              symbolStart = index;
              symbolName = name.value;
            }
          }
        }
        depth++;
        index++;
        continue;
      }

      if (byte == _closeParen) {
        depth--;
        index++;
        if (depth == 1 && symbolStart != null) {
          spans.add(
            SymbolSpan(name: symbolName!, start: symbolStart, end: index),
          );
          symbolStart = null;
          symbolName = null;
        }
        continue;
      }

      index++;
    }

    return spans;
  }

  /// Reads the file preamble. Only the first part of the file is decoded.
  static SymbolLibraryHeader readHeader(Uint8List bytes) {
    final probe = utf8.decode(
      bytes.sublist(0, bytes.length < 2048 ? bytes.length : 2048),
      allowMalformed: true,
    );
    final version = RegExp(r'\(version\s+(\d+)\)').firstMatch(probe);
    final generator = RegExp(r'\(generator\s+"?([^")\s]+)"?\)').firstMatch(
      probe,
    );
    final generatorVersion = RegExp(
      r'\(generator_version\s+"?([^")\s]+)"?\)',
    ).firstMatch(probe);

    return SymbolLibraryHeader(
      version: int.tryParse(version?.group(1) ?? '') ?? 0,
      generator: generator?.group(1) ?? '',
      generatorVersion: generatorVersion?.group(1) ?? '',
    );
  }

  /// Parses the single symbol occupying [span].
  static SymbolDefinition parseSpan(
    Uint8List bytes,
    SymbolSpan span, {
    required String nickname,
  }) {
    final source = utf8.decode(bytes.sublist(span.start, span.end));
    final node = SExprParser.parseDocument(source);
    return SymbolParser.parseSymbol(node, nickname);
  }

  /// Parses a symbol from bytes that already contain exactly one symbol.
  static SymbolDefinition parseSymbolBytes(
    Uint8List bytes, {
    required String nickname,
  }) {
    final node = SExprParser.parseDocument(utf8.decode(bytes));
    return SymbolParser.parseSymbol(node, nickname);
  }

  /// Reads a whole library and resolves inheritance.
  ///
  /// Over half of KiCad's stock symbols are derived from another symbol, so
  /// an unresolved definition is rarely useful on its own; every symbol
  /// returned here already carries its parent's drawings and pins.
  static ParsedSymbolLibrary parseLibrary(
    Uint8List bytes, {
    required String nickname,
  }) {
    final header = readHeader(bytes);
    final spans = scanSpans(bytes);
    final warnings = <String>[];

    final raw = <String, SymbolDefinition>{};
    final order = <String>[];
    for (final span in spans) {
      try {
        final symbol = parseSpan(bytes, span, nickname: nickname);
        raw[symbol.name] = symbol;
        order.add(symbol.name);
      } on SExprParseException catch (e) {
        warnings.add('${span.name}: ${e.message}');
      } on SymbolParseException catch (e) {
        warnings.add('${span.name}: ${e.message}');
      }
    }

    final resolved = <String, SymbolDefinition>{};
    for (final name in order) {
      resolved[name] = _resolve(name, raw, resolved, warnings, <String>{});
    }

    return ParsedSymbolLibrary(
      nickname: nickname,
      header: header,
      symbols: [for (final name in order) resolved[name]!],
      spans: {for (final span in spans) span.name: span},
      warnings: warnings,
    );
  }

  /// Resolves one symbol against its ancestors, memoising as it goes.
  ///
  /// [visiting] guards against a library whose inheritance forms a cycle —
  /// KiCad would reject such a file, but a hand-edited one can contain it
  /// and it must not hang the importer.
  static SymbolDefinition _resolve(
    String name,
    Map<String, SymbolDefinition> raw,
    Map<String, SymbolDefinition> resolved,
    List<String> warnings,
    Set<String> visiting,
  ) {
    final cached = resolved[name];
    if (cached != null) return cached;

    final symbol = raw[name]!;
    final parentName = symbol.extendsSymbol;
    if (parentName == null) return symbol;

    if (!raw.containsKey(parentName)) {
      warnings.add('$name extends "$parentName", which is not in this library');
      return symbol;
    }
    if (!visiting.add(name)) {
      warnings.add('$name is part of an inheritance cycle');
      return symbol;
    }

    final parent = _resolve(parentName, raw, resolved, warnings, visiting);
    visiting.remove(name);

    final merged = symbol.resolvedAgainst(parent);
    resolved[name] = merged;
    return merged;
  }

  // --- byte-level token helpers ---------------------------------------

  static int _skipString(Uint8List bytes, int start) {
    var index = start + 1;
    while (index < bytes.length) {
      final byte = bytes[index];
      if (byte == _backslash) {
        index += 2;
        continue;
      }
      if (byte == _quote) return index + 1;
      index++;
    }
    return index;
  }

  static _Token? _readBareToken(Uint8List bytes, int from) {
    var index = _skipWhitespace(bytes, from);
    final start = index;
    while (index < bytes.length && !_isDelimiter(bytes[index])) {
      index++;
    }
    if (index == start) return null;
    return _Token(
      ascii.decode(bytes.sublist(start, index), allowInvalid: true),
      index,
    );
  }

  static _Token? _readQuotedToken(Uint8List bytes, int from) {
    final index = _skipWhitespace(bytes, from);
    if (index >= bytes.length || bytes[index] != _quote) return null;
    final end = _skipString(bytes, index);
    return _Token(
      utf8.decode(bytes.sublist(index + 1, end - 1), allowMalformed: true),
      end,
    );
  }

  static int _skipWhitespace(Uint8List bytes, int from) {
    var index = from;
    while (index < bytes.length) {
      final byte = bytes[index];
      if (byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d) {
        index++;
      } else {
        break;
      }
    }
    return index;
  }

  static bool _isDelimiter(int byte) =>
      byte == 0x20 ||
      byte == 0x09 ||
      byte == 0x0a ||
      byte == 0x0d ||
      byte == _openParen ||
      byte == _closeParen ||
      byte == _quote;
}

class _Token {
  const _Token(this.value, this.end);

  final String value;
  final int end;
}
