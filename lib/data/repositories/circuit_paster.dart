import 'dart:ui';

import '../../domain/models/models.dart';
import 'net_repository.dart';
import 'part_repository.dart';

/// What a paste put on the sheet, so it can be selected and taken back.
class PastedCircuit {
  const PastedCircuit({
    required this.partIds,
    required this.unitIds,
    required this.wires,
  });

  final List<String> partIds;
  final Set<String> unitIds;
  final List<SchematicWire> wires;
}

/// Puts a copied piece of schematic back on the sheet as new parts, wired
/// among themselves the way the originals were.
class CircuitPaster {
  const CircuitPaster(this.parts, this.nets);

  final PartRepository parts;
  final NetRepository nets;

  Future<PastedCircuit> paste(
    String projectId,
    CircuitClip clip, {
    required Offset at,
  }) => nets.transaction(() async {
    final added = <PartWithDetails>[];
    for (final copied in clip.parts) {
      final part = await parts.addPart(projectId, copied.spec);
      for (final unit in part.units) {
        final source = copied.units
            .where((u) => u.unitNumber == unit.unitNumber)
            .firstOrNull;
        if (source == null) continue;
        await parts.updateUnitPlacement(
          unit.copyWith(
            x: at.dx + source.offset.dx,
            y: at.dy + source.offset.dy,
            rotation: source.rotation,
            mirrorX: source.mirrorX,
            mirrorY: source.mirrorY,
            placed: true,
          ),
        );
      }
      added.add(part);
    }

    String? pinId(ClipPin? ref) {
      if (ref == null || ref.part >= added.length) return null;
      return added[ref.part].pins
          .where((p) => p.number == ref.number && p.unit == ref.unit)
          .firstOrNull
          ?.id;
    }

    // The first pasted pin of each connection: the net a wire belongs on is
    // looked up through it, since naming a net can fold it into another.
    final firstPinOfNet = <int, String>{};
    for (var i = 0; i < clip.nets.length; i++) {
      final net = clip.nets[i];
      final ids = [for (final ref in net.pins) ?pinId(ref)];
      if (ids.isEmpty) continue;
      firstPinOfNet[i] = ids.first;
      try {
        var netId = await nets.netForPin(projectId, ids.first);
        for (final other in ids.skip(1)) {
          netId = (await nets.connectPins(ids.first, other)).net.id;
        }
        if (net.name != null) await nets.renameNet(netId, net.name);
      } on InvalidConnectionException {
        // Left unjoined rather than failing the whole paste.
      }
    }

    final wires = <SchematicWire>[];
    for (final wire in clip.wires) {
      final a = pinId(wire.pinA);
      final b = pinId(wire.pinB);
      final through = a ?? b ?? firstPinOfNet[wire.net];
      final netId = through == null ? null : await nets.netIdForPin(through);
      if (netId == null) continue;
      final laid = await nets.addWire(
        projectId: projectId,
        points: [for (final p in wire.points) p + at],
        pinAId: a,
        pinBId: b,
        netId: netId,
      );
      if (laid != null) wires.add(laid);
    }

    return PastedCircuit(
      partIds: [for (final part in added) part.part.id],
      unitIds: {
        for (final part in added)
          for (final unit in part.units) unit.id,
      },
      wires: wires,
    );
  });
}
