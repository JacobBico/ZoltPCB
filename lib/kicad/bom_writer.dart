import '../domain/export/schematic_document.dart';
import '../domain/models/models.dart';

/// One line of the bill of materials: a group of identical components.
class BomLine {
  const BomLine({
    required this.references,
    required this.value,
    required this.footprint,
    required this.libId,
    this.description = '',
    this.datasheet = '',
    this.componentId = '',
    this.dnp = false,
  });

  /// Designators in this group, in natural order: `R1, R2, R10`.
  final List<String> references;

  final String value;
  final String footprint;
  final String libId;
  final String description;
  final String datasheet;

  /// The supplier's part number the line is ordered by.
  final String componentId;
  final bool dnp;

  int get quantity => references.length;

  String get referenceList => references.join(', ');

  @override
  String toString() => 'BomLine($referenceList, $value x$quantity)';
}

/// Writes a bill of materials as CSV.
///
/// Grouped the way a BOM is read and ordered: identical parts on one line,
/// designators listed together, quantity alongside. Kept separate from the
/// schematic writer because the two answer different questions — one is
/// what the circuit is, the other is what to buy.
abstract final class BomWriter {
  static const columns = [
    'Item',
    'Qty',
    'References',
    'Value',
    'Footprint',
    'Symbol',
    'Description',
    'Datasheet',
    // What JLCPCB's assembly BOM upload matches a line by.
    'LCSC Part #',
    'DNP',
  ];

  /// Groups a project's parts into BOM lines.
  ///
  /// Parts marked "not in BOM" are left out entirely — that flag exists for
  /// power symbols and other schematic-only annotations, which are not
  /// things anyone buys. "Do not populate" parts are kept, because they are
  /// real footprints on a real board, and flagged in their own column.
  static List<BomLine> group(List<PartWithDetails> parts) {
    final groups = <String, List<Part>>{};
    for (final entry in parts) {
      final part = entry.part;
      if (!part.inBom) continue;
      // Two parts belong on the same line only if everything a buyer cares
      // about matches, including whether they are actually fitted.
      final key = [
        part.value,
        part.footprint,
        part.libId,
        part.componentId,
        part.dnp ? 'dnp' : 'fitted',
      ].join(' ');
      (groups[key] ??= []).add(part);
    }

    final lines = <BomLine>[];
    for (final group in groups.values) {
      group.sort((a, b) => compareReferences(a.reference, b.reference));
      final first = group.first;
      lines.add(
        BomLine(
          references: group.map((p) => p.reference).toList(),
          value: first.value,
          footprint: first.footprint,
          libId: first.libId,
          description: first.description,
          datasheet: first.datasheet,
          componentId: first.componentId,
          dnp: first.dnp,
        ),
      );
    }

    lines.sort(
      (a, b) => compareReferences(a.references.first, b.references.first),
    );
    return lines;
  }

  static String write(SchematicDocument document) =>
      writeLines(group(document.parts));

  static String writeLines(List<BomLine> lines) {
    final buffer = StringBuffer()..writeln(columns.map(escape).join(','));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      buffer.writeln(
        [
          '${i + 1}',
          '${line.quantity}',
          line.referenceList,
          line.value,
          line.footprint,
          line.libId,
          line.description,
          line.datasheet,
          line.componentId,
          line.dnp ? 'DNP' : '',
        ].map(escape).join(','),
      );
    }
    return buffer.toString();
  }

  /// Quotes a field per RFC 4180 when it contains a comma, a quote or a
  /// line break — the three things that would otherwise corrupt the row.
  static String escape(String value) {
    final needsQuoting =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Orders designators the way an engineer reads them: by prefix, then
  /// numerically, so `R2` comes before `R10`.
  static int compareReferences(String a, String b) {
    final pattern = RegExp(r'^([^0-9]*)([0-9]*)');
    final ma = pattern.firstMatch(a)!;
    final mb = pattern.firstMatch(b)!;

    final byPrefix = ma.group(1)!.compareTo(mb.group(1)!);
    if (byPrefix != 0) return byPrefix;

    final na = int.tryParse(ma.group(2)!);
    final nb = int.tryParse(mb.group(2)!);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }
}
