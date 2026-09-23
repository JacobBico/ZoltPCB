import '../../domain/models/models.dart';
import 'net_repository.dart';
import 'part_repository.dart';

/// Everything needed to take a swap back.
class SwapUndo {
  const SwapUndo(this.connections, this.units);

  final ConnectionSnapshot connections;

  /// Gate placements as they were, for a gate swap.
  final List<PartUnit> units;
}

/// Pin and gate swaps: changing which pin of a part carries which net, to
/// untangle a board, with the schematic kept telling the truth.
///
/// A gate swap trades two identical units — the two amplifiers of a dual
/// op-amp — so the gates also trade places on the sheet and the wires
/// follow their new pins: the drawing is unchanged but for the gate
/// letters, and the board's pads swap nets. A pin swap trades two pins of
/// one unit, which cannot move on the symbol, so each pin takes the other's
/// net as a label instead of a wire.
class PinSwapper {
  PinSwapper({required this.parts, required this.nets});

  final PartRepository parts;
  final NetRepository nets;

  /// Pins of gate [a] paired with the pins of gate [b] in the same place
  /// on the symbol, or null when the two gates are not drawn alike.
  static Map<String, String>? gatePairs(PartWithDetails part, int a, int b) {
    if (a == b || a == 0 || b == 0) return null;
    final pinsA = [
      for (final p in part.pins)
        if (p.unit == a) p,
    ];
    final pinsB = [
      for (final p in part.pins)
        if (p.unit == b) p,
    ];
    if (pinsA.isEmpty || pinsA.length != pinsB.length) return null;
    final pairs = <String, String>{};
    final taken = <String>{};
    for (final pin in pinsA) {
      final alike = [
        for (final q in pinsB)
          if (!taken.contains(q.id) &&
              (q.x - pin.x).abs() < 1e-6 &&
              (q.y - pin.y).abs() < 1e-6 &&
              q.electricalType == pin.electricalType)
            q,
      ];
      // The same name first: "+" for "+", where two inputs share a place.
      final twin =
          alike.where((q) => q.name == pin.name).firstOrNull ??
          alike.firstOrNull;
      if (twin == null) return null;
      taken.add(twin.id);
      pairs[pin.id] = twin.id;
    }
    return pairs;
  }

  /// The gates [unit] could swap with.
  static List<int> swappableWith(PartWithDetails part, int unit) => [
    for (final other in part.units)
      if (gatePairs(part, unit, other.unitNumber) != null) other.unitNumber,
  ];

  /// Whether [part] has any gates that can swap at all.
  static bool hasSwappableGates(PartWithDetails part) =>
      part.units.any((u) => swappableWith(part, u.unitNumber).isNotEmpty);

  Future<SwapUndo> swapGates(
    String projectId,
    PartWithDetails part,
    int a,
    int b,
  ) => nets.transaction(() async {
    final pairs = gatePairs(part, a, b);
    if (pairs == null) {
      throw ArgumentError('Gates $a and $b are not drawn alike');
    }
    final snapshot = await nets.capture(projectId, [
      ...pairs.keys,
      ...pairs.values,
    ]);
    final unitA = part.units.firstWhere((u) => u.unitNumber == a);
    final unitB = part.units.firstWhere((u) => u.unitNumber == b);
    await nets.swapConnections(pairs, keepWires: true);
    // Each gate goes where the other was, so the wires, now on the other
    // gate's pins, end exactly where they did.
    await parts.updateUnitPlacement(_placedLike(unitA, unitB));
    await parts.updateUnitPlacement(_placedLike(unitB, unitA));
    return SwapUndo(snapshot, [unitA, unitB]);
  });

  Future<SwapUndo> swapPins(
    String projectId,
    PartWithDetails part,
    PartPin a,
    PartPin b,
  ) => nets.transaction(() async {
    final snapshot = await nets.capture(projectId, [a.id, b.id]);
    // A pin swapped onto a net shows that net's name as a label, so a net
    // with no name is given the one KiCad would have.
    for (final pin in [a, b]) {
      final netId = await nets.netIdForPin(pin.id);
      if (netId == null) continue;
      final net = await nets.getNet(netId);
      if (net != null && !net.net.isNamed) {
        await nets.renameNet(
          netId,
          'Net-(${part.part.reference}-${pin.number})',
        );
      }
    }
    await nets.swapConnections({a.id: b.id}, keepWires: false);
    return SwapUndo(snapshot, const []);
  });

  Future<void> undo(SwapUndo swap) => nets.transaction(() async {
    await nets.restore(swap.connections);
    for (final unit in swap.units) {
      await parts.updateUnitPlacement(unit);
    }
  });

  static PartUnit _placedLike(PartUnit unit, PartUnit where) => unit.copyWith(
    x: where.x,
    y: where.y,
    rotation: where.rotation,
    mirrorX: where.mirrorX,
    mirrorY: where.mirrorY,
    placed: where.placed,
  );
}
