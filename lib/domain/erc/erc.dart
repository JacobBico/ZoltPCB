import '../models/models.dart';

enum ErcSeverity { error, warning }

enum ErcRule {
  unconnectedPin('Unconnected pins', ErcSeverity.warning),
  lonelyNet('Net with one pin', ErcSeverity.warning),
  undrivenPower('Supply with nothing driving it', ErcSeverity.error),
  outputsTogether('Outputs driving each other', ErcSeverity.error),
  missingFootprint('No footprint', ErcSeverity.warning),
  unannotated('Not numbered', ErcSeverity.warning);

  const ErcRule(this.label, this.defaultSeverity);
  final String label;

  /// How much it matters unless the project says otherwise.
  final ErcSeverity defaultSeverity;
}

/// What a project wants done about one rule.
enum ErcLevel {
  error('Error'),
  warning('Warning'),
  ignore('Off');

  const ErcLevel(this.label);

  final String label;

  static ErcLevel? byName(String? name) =>
      values.where((l) => l.name == name).firstOrNull;
}

/// Which checks matter for one project, and how much.
///
/// A board with a deliberately floating test net does not need to hear
/// about it every time; a design review might want every warning an error.
/// The check itself is unchanged — this only decides what it reports.
class ErcSettings {
  const ErcSettings([this.levels = const {}]);

  /// Rules set away from their default. A rule not here is at its default.
  final Map<ErcRule, ErcLevel> levels;

  static const defaults = ErcSettings();

  ErcLevel levelOf(ErcRule rule) =>
      levels[rule] ??
      (rule.defaultSeverity == ErcSeverity.error
          ? ErcLevel.error
          : ErcLevel.warning);

  ErcSettings withLevel(ErcRule rule, ErcLevel level) {
    final next = {...levels};
    final isDefault =
        (rule.defaultSeverity == ErcSeverity.error) ==
            (level == ErcLevel.error) &&
        level != ErcLevel.ignore;
    if (isDefault) {
      next.remove(rule);
    } else {
      next[rule] = level;
    }
    return ErcSettings(next);
  }

  bool get isDefault => levels.isEmpty;

  /// The prefix these are stored under in the project's settings.
  static const keyPrefix = 'erc.';

  Map<String, String> toSettings() => {
    for (final rule in ErcRule.values)
      '$keyPrefix${rule.name}': levelOf(rule).name,
  };

  static ErcSettings fromSettings(Map<String, String> settings) {
    final levels = <ErcRule, ErcLevel>{};
    for (final rule in ErcRule.values) {
      final level = ErcLevel.byName(settings['$keyPrefix${rule.name}']);
      if (level != null) levels[rule] = level;
    }
    // Normalise, so a stored default does not count as a change.
    var result = const ErcSettings();
    for (final entry in levels.entries) {
      result = result.withLevel(entry.key, entry.value);
    }
    return result;
  }

  /// [violations] as this project wants them: ignored rules dropped, and
  /// the rest at the severity it chose.
  List<ErcViolation> apply(List<ErcViolation> violations) {
    final result = <ErcViolation>[];
    for (final v in violations) {
      final level = levelOf(v.rule);
      if (level == ErcLevel.ignore) continue;
      final severity = level == ErcLevel.error
          ? ErcSeverity.error
          : ErcSeverity.warning;
      result.add(
        severity == v.severity
            ? v
            : ErcViolation(
                rule: v.rule,
                severity: severity,
                message: v.message,
                partId: v.partId,
                netId: v.netId,
              ),
      );
    }
    result.sort((a, b) {
      if (a.isError != b.isError) return a.isError ? -1 : 1;
      return a.rule.index.compareTo(b.rule.index);
    });
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ErcSettings &&
      other.levels.length == levels.length &&
      other.levels.entries.every((e) => levels[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    levels.entries.map((e) => Object.hash(e.key, e.value)),
  );
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
  ErcSettings settings = ErcSettings.defaults,
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

  return settings.apply(violations);
}
