import '../models/models.dart';

enum ErcSeverity { error, warning }

enum ErcRule {
  unconnectedPin('Unconnected pins'),
  lonelyNet('Net with one pin'),
  undrivenPower('Supply with nothing driving it'),
  outputsTogether('Outputs driving each other'),
  missingFootprint('No footprint'),
  unannotated('Not numbered');

  const ErcRule(this.label);
  final String label;
}

class ErcViolation {
  const ErcViolation({
    required this.rule,
    required this.severity,
    required this.message,
    this.partId,
    this.netId,
  });

  final ErcRule rule;
  final ErcSeverity severity;
  final String message;

  /// The part to show the user, when there is one.
  final String? partId;
  final String? netId;

  bool get isError => severity == ErcSeverity.error;

  @override
  String toString() => 'ErcViolation(${rule.name}: $message)';
}

/// Checks a schematic for the mistakes that make a wrong board.
///
/// Deliberately gentler than KiCad's ERC. KiCad wants a PWR_FLAG on every
/// supply before it believes anything drives it; here a power symbol is
/// taken at its word, because that is what the person who placed it meant,
/// and a checker that complains about correct circuits gets ignored.
List<ErcViolation> checkSchematic({
  required List<PartWithDetails> parts,
  required List<NetWithEndpoints> nets,
  Set<String>? partsWithBoardFootprint,
}) {
  final violations = <ErcViolation>[];
  final netByPin = <String, NetWithEndpoints>{
    for (final net in nets)
      for (final endpoint in net.endpoints) endpoint.pin.id: net,
  };

  bool isPowerSymbol(Part part) =>
      part.reference.startsWith('#PWR') || part.reference.startsWith('#FLG');

  // --- per part --------------------------------------------------------
  for (final part in parts) {
    if (isPowerSymbol(part.part)) continue;

    final loose = [
      for (final pin in part.pins)
        if (!netByPin.containsKey(pin.id) &&
            !pin.noConnect &&
            pin.electricalType != PinElectricalType.noConnect)
          pin,
    ];
    // One entry per part, not one per pin: a microcontroller with forty
    // unused pins is one thing to decide about, not forty.
    if (loose.isNotEmpty) {
      final names = [for (final pin in loose.take(6)) pin.label];
      violations.add(
        ErcViolation(
          rule: ErcRule.unconnectedPin,
          severity: ErcSeverity.warning,
          message:
              '${part.part.reference}: ${loose.length} '
              '${loose.length == 1 ? 'pin is' : 'pins are'} unconnected '
              '(${names.join(', ')}${loose.length > 6 ? ', …' : ''}) — wire '
              'them, or mark them no-connect',
          partId: part.part.id,
        ),
      );
    }

    if (part.part.reference.contains('?')) {
      violations.add(
        ErcViolation(
          rule: ErcRule.unannotated,
          severity: ErcSeverity.warning,
          message: '${part.part.reference} has no number — renumber',
          partId: part.part.id,
        ),
      );
    }

    final onBoard = part.part.onBoard && !part.part.dnp;
    final hasFootprint =
        part.part.footprint.isNotEmpty ||
        (partsWithBoardFootprint?.contains(part.part.id) ?? false);
    if (onBoard && !hasFootprint) {
      violations.add(
        ErcViolation(
          rule: ErcRule.missingFootprint,
          severity: ErcSeverity.warning,
          message:
              '${part.part.reference} has no footprint, so it cannot go '
              'on the board',
          partId: part.part.id,
        ),
      );
    }
  }

  // --- per net ---------------------------------------------------------
  for (final net in nets) {
    final real = [
      for (final e in net.endpoints)
        if (!isPowerSymbol(e.part)) e,
    ];
    final hasPowerSymbol = net.endpoints.any((e) => isPowerSymbol(e.part));

    if (net.endpoints.length < 2) {
      violations.add(
        ErcViolation(
          rule: ErcRule.lonelyNet,
          severity: ErcSeverity.warning,
          message:
              '${net.displayName} only reaches '
              '${net.endpoints.isEmpty ? 'nothing' : net.endpoints.first.shortLabel}',
          netId: net.net.id,
          partId: net.endpoints.firstOrNull?.part.id,
        ),
      );
    }

    final powerInputs = [
      for (final e in real)
        if (e.pin.electricalType == PinElectricalType.powerIn) e,
    ];
    final drivers = [
      for (final e in real)
        if (e.pin.electricalType == PinElectricalType.powerOut) e,
    ];
    if (powerInputs.isNotEmpty && drivers.isEmpty && !hasPowerSymbol) {
      violations.add(
        ErcViolation(
          rule: ErcRule.undrivenPower,
          severity: ErcSeverity.error,
          message:
              '${net.displayName} feeds ${powerInputs.first.shortLabel}'
              '${powerInputs.length > 1 ? ' and ${powerInputs.length - 1} more' : ''}'
              ' but nothing supplies it — add a power symbol or a regulator',
          netId: net.net.id,
          partId: powerInputs.first.part.id,
        ),
      );
    }

    final outputs = [
      for (final e in real)
        if (e.pin.electricalType == PinElectricalType.output ||
            e.pin.electricalType == PinElectricalType.powerOut)
          e,
    ];
    if (outputs.length >= 2) {
      violations.add(
        ErcViolation(
          rule: ErcRule.outputsTogether,
          severity: ErcSeverity.error,
          message:
              '${outputs[0].shortLabel} and ${outputs[1].shortLabel} '
              'both drive ${net.displayName}',
          netId: net.net.id,
          partId: outputs.first.part.id,
        ),
      );
    }
  }

  violations.sort((a, b) {
    if (a.isError != b.isError) return a.isError ? -1 : 1;
    return a.rule.index.compareTo(b.rule.index);
  });
  return violations;
}
