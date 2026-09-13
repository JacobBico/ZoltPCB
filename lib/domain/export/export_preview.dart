import '../models/models.dart';
import 'schematic_document.dart';

/// A summary of what an export will contain, and of anything that is likely
/// to look wrong once the file is opened on the desktop.
///
/// Shown before exporting rather than after, because the problems worth
/// knowing about — a component with no footprint, a pin left dangling — are
/// cheaper to fix here than in KiCad.
class ExportPreview {
  const ExportPreview({
    required this.partCount,
    required this.unitCount,
    required this.netCount,
    required this.namedNetCount,
    required this.bomLineCount,
    required this.pinCount,
    required this.connectedPinCount,
    required this.noConnectPinCount,
    required this.missingSymbols,
    required this.partsWithoutFootprint,
    required this.danglingNets,
  });

  factory ExportPreview.of(SchematicDocument document) {
    final connected = document.netByPin;

    var pinCount = 0;
    var noConnectCount = 0;
    final withoutFootprint = <String>[];

    for (final part in document.parts) {
      pinCount += part.pins.length;
      for (final pin in part.pins) {
        if (pin.noConnect) noConnectCount++;
      }
      if (part.part.inBom && part.part.footprint.trim().isEmpty) {
        withoutFootprint.add(part.part.reference);
      }
    }

    final missing = [
      for (final libId in document.usedLibIds)
        if (!document.symbols.containsKey(libId)) libId,
    ];

    return ExportPreview(
      partCount: document.parts.length,
      unitCount: document.placedUnitCount,
      netCount: document.nets.length,
      namedNetCount: document.nets.where((n) => n.net.isNamed).length,
      bomLineCount: _bomLineCount(document.parts),
      pinCount: pinCount,
      connectedPinCount: connected.length,
      noConnectPinCount: noConnectCount,
      missingSymbols: missing,
      partsWithoutFootprint: withoutFootprint..sort(),
      danglingNets: [
        for (final net in document.nets)
          if (net.isDangling) net.displayName,
      ],
    );
  }

  final int partCount;
  final int unitCount;
  final int netCount;
  final int namedNetCount;
  final int bomLineCount;
  final int pinCount;
  final int connectedPinCount;
  final int noConnectPinCount;

  /// `lib_id`s whose library is no longer installed. Not fatal: the export
  /// falls back to the pins the project stored when the part was added.
  final List<String> missingSymbols;

  final List<String> partsWithoutFootprint;
  final List<String> danglingNets;

  int get unconnectedPinCount =>
      (pinCount - connectedPinCount - noConnectPinCount).clamp(0, pinCount);

  bool get isEmpty => partCount == 0;

  bool get hasWarnings =>
      missingSymbols.isNotEmpty ||
      partsWithoutFootprint.isNotEmpty ||
      danglingNets.isNotEmpty;

  static int _bomLineCount(List<PartWithDetails> parts) {
    final keys = <String>{};
    for (final part in parts) {
      if (!part.part.inBom) continue;
      keys.add(
        [
          part.part.value,
          part.part.footprint,
          part.part.libId,
          part.part.dnp,
        ].join(' '),
      );
    }
    return keys.length;
  }
}
