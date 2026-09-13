import 'dart:convert';
import 'dart:typed_data';

import '../domain/pcb/pcb.dart';
import 'footprint_parser.dart';
import 'sexpr/sexpr_parser.dart';

/// Where one footprint lives inside a packed library.
class FootprintSpan {
  const FootprintSpan({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final int start;
  final int end;

  int get length => end - start;

  @override
  String toString() => 'FootprintSpan($name, $start..$end)';
}

/// A footprint library, packed and indexed.
class ParsedFootprintLibrary {
  const ParsedFootprintLibrary({
    required this.nickname,
    required this.bytes,
    required this.footprints,
    required this.spans,
    this.warnings = const [],
  });

  final String nickname;

  /// The container to store: every source file, one after another.
  final Uint8List bytes;

  final List<FootprintDefinition> footprints;
  final Map<String, FootprintSpan> spans;

  /// Files that could not be read. Non-fatal: a library with one bad
  /// footprint in it is still worth having.
  final List<String> warnings;

  int get footprintCount => footprints.length;
}

/// Reads `.kicad_mod` files and packs them into one library.
///
/// A `.pretty` library is a directory of hundreds of small files, which is a
/// poor fit for a phone: hundreds of file handles, hundreds of rows, and an
/// import that has to be reassembled from whatever the file picker returned.
/// Packing them into a single container gives footprints exactly the shape
/// symbols already have — one file, one row, byte ranges for lazy loading —
/// and the container is still plain text that could be split back apart by
/// hand.
abstract final class FootprintLibraryReader {
  /// Separates packed footprints. A blank line, so the container stays
  /// readable and a span never abuts the next node.
  static const _separator = '\n\n';

  /// Packs [sources] — the contents of `.kicad_mod` files, keyed by file
  /// name — into one library.
  ///
  /// A file that does not parse is reported in `warnings` and left out
  /// rather than failing the import: one broken footprint in a library of
  /// four hundred is not a reason to reject the other 399.
  static ParsedFootprintLibrary pack({
    required String nickname,
    required Map<String, Uint8List> sources,
  }) {
    final buffer = StringBuffer();
    final footprints = <FootprintDefinition>[];
    final spans = <String, FootprintSpan>{};
    final warnings = <String>[];

    // Byte offsets, not character offsets: the spans exist to seek to.
    var offset = 0;

    final names = sources.keys.toList()..sort();
    for (final fileName in names) {
      final raw = sources[fileName]!;
      final String text;
      final FootprintDefinition footprint;
      try {
        text = utf8.decode(raw, allowMalformed: true);
        footprint = FootprintParser.parse(
          SExprParser.parseDocument(text.trim()),
          nickname,
        );
      } catch (error) {
        warnings.add('$fileName: $error');
        continue;
      }

      if (spans.containsKey(footprint.name)) {
        warnings.add('$fileName: ${footprint.name} appears twice');
        continue;
      }

      final trimmed = text.trim();
      final length = utf8.encode(trimmed).length;
      buffer
        ..write(trimmed)
        ..write(_separator);

      footprints.add(footprint);
      spans[footprint.name] = FootprintSpan(
        name: footprint.name,
        start: offset,
        end: offset + length,
      );
      offset += length + utf8.encode(_separator).length;
    }

    return ParsedFootprintLibrary(
      nickname: nickname,
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      footprints: footprints,
      spans: spans,
      warnings: warnings,
    );
  }

  /// Reads one footprint back out of a packed container's bytes.
  static FootprintDefinition parseOne(
    Uint8List bytes, {
    required String nickname,
  }) => FootprintParser.parse(
    SExprParser.parseDocument(utf8.decode(bytes, allowMalformed: true).trim()),
    nickname,
  );

  /// The nickname a `.pretty` directory or archive implies.
  ///
  /// `Resistor_SMD.pretty` and `Resistor_SMD.zip` both name the library
  /// `Resistor_SMD`, because that is the name the resulting footprint ids
  /// have to carry for a board file to resolve them.
  static String nicknameFor(String fileName) {
    var name = fileName.split('/').last.split('\\').last.trim();
    for (final suffix in const ['.zip', '.pretty', '.kicad_mod']) {
      if (name.toLowerCase().endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
      }
    }
    // A trailing `.pretty` survives inside `Resistor_SMD.pretty.zip`.
    if (name.toLowerCase().endsWith('.pretty')) {
      name = name.substring(0, name.length - '.pretty'.length);
    }
    return name.trim();
  }
}
