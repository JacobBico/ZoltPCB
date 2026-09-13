import 'sexpr.dart';

/// Thrown when a file is not well-formed s-expression syntax.
class SExprParseException implements Exception {
  SExprParseException(this.message, this.source, this.offset);

  final String message;
  final String source;
  final int offset;

  /// 1-based line number of [offset], computed only when reported.
  int get line {
    var line = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source.codeUnitAt(i) == _lf) line++;
    }
    return line;
  }

  @override
  String toString() => 'SExprParseException: $message (line $line)';
}

const int _lf = 0x0a;
const int _cr = 0x0d;
const int _tab = 0x09;
const int _space = 0x20;
const int _openParen = 0x28;
const int _closeParen = 0x29;
const int _quote = 0x22;
const int _backslash = 0x5c;

/// A recursive-descent reader for KiCad's s-expression syntax.
///
/// Written against code units rather than regular expressions or repeated
/// substring calls: symbol libraries run to several megabytes and are parsed
/// on a phone, so allocation per token is the thing to avoid.
class SExprParser {
  SExprParser(this.source);

  final String source;
  int _pos = 0;

  /// Parses a whole document containing exactly one top-level list, which is
  /// what every KiCad file is.
  static SList parseDocument(String source) {
    final parser = SExprParser(source);
    parser._skipWhitespace();
    final root = parser._parseList();
    parser._skipWhitespace();
    if (parser._pos < source.length) {
      throw SExprParseException(
        'Trailing content after the top-level list',
        source,
        parser._pos,
      );
    }
    return root;
  }

  /// Parses the single list starting at [offset]. Used to read one symbol
  /// out of a library file without parsing the rest of it.
  static SList parseAt(String source, int offset) {
    final parser = SExprParser(source).._pos = offset;
    parser._skipWhitespace();
    return parser._parseList();
  }

  void _skipWhitespace() {
    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if (c == _space || c == _tab || c == _lf || c == _cr) {
        _pos++;
      } else {
        break;
      }
    }
  }

  SList _parseList() {
    if (_pos >= source.length || source.codeUnitAt(_pos) != _openParen) {
      throw SExprParseException('Expected "("', source, _pos);
    }
    _pos++; // consume '('

    final items = <SExpr>[];
    while (true) {
      _skipWhitespace();
      if (_pos >= source.length) {
        throw SExprParseException('Unterminated list', source, _pos);
      }
      final c = source.codeUnitAt(_pos);
      if (c == _closeParen) {
        _pos++;
        return SList(items);
      }
      if (c == _openParen) {
        items.add(_parseList());
      } else if (c == _quote) {
        items.add(_parseQuotedAtom());
      } else {
        items.add(_parseBareAtom());
      }
    }
  }

  SAtom _parseQuotedAtom() {
    _pos++; // consume opening quote
    final start = _pos;
    var hasEscape = false;

    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if (c == _backslash) {
        hasEscape = true;
        _pos += 2;
        continue;
      }
      if (c == _quote) {
        final raw = source.substring(start, _pos);
        _pos++; // consume closing quote
        return SAtom(hasEscape ? _unescape(raw) : raw, quoted: true);
      }
      _pos++;
    }
    throw SExprParseException('Unterminated string', source, start);
  }

  SAtom _parseBareAtom() {
    final start = _pos;
    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if (c == _space ||
          c == _tab ||
          c == _lf ||
          c == _cr ||
          c == _openParen ||
          c == _closeParen) {
        break;
      }
      _pos++;
    }
    if (_pos == start) {
      throw SExprParseException('Empty token', source, _pos);
    }
    return SAtom(source.substring(start, _pos));
  }

  static String _unescape(String raw) {
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (raw.codeUnitAt(i) != _backslash || i + 1 >= raw.length) {
        buffer.writeCharCode(raw.codeUnitAt(i));
        continue;
      }
      i++;
      switch (raw[i]) {
        case 'n':
          buffer.write('\n');
        case 't':
          buffer.write('\t');
        case 'r':
          buffer.write('\r');
        default:
          // KiCad escapes only \" and \; anything else passes through as
          // the literal character, which is what its own reader does.
          buffer.write(raw[i]);
      }
    }
    return buffer.toString();
  }
}
