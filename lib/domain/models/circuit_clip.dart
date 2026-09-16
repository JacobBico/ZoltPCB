import 'dart:ui';

import 'net.dart';
import 'part.dart';
import 'part_clone.dart';
import 'part_spec.dart';
import 'schematic_wire.dart';

/// One unit of a copied part: where it sat relative to the copy's anchor,
/// and which way round.
class ClipUnit {
  const ClipUnit({
    required this.unitNumber,
    required this.offset,
    this.rotation = 0,
    this.mirrorX = false,
    this.mirrorY = false,
  });

  final int unitNumber;
  final Offset offset;
  final int rotation;
  final bool mirrorX;
  final bool mirrorY;
}

class ClipPart {
  const ClipPart({required this.spec, required this.units});

  final NewPartSpec spec;
  final List<ClipUnit> units;
}

/// A pin of a copied part, by the part's place in the clip and the pin's
/// number — ids mean nothing once the copy is pasted as new parts.
class ClipPin {
  const ClipPin({required this.part, required this.unit, required this.number});

  final int part;
  final int unit;
  final String number;
}

/// A connection among the copied pins, with its name when it had one — a
/// named net joins its namesake wherever it is pasted, the way a label does.
class ClipNet {
  const ClipNet({required this.pins, this.name});

  final List<ClipPin> pins;
  final String? name;
}

/// A drawn wire, relative to the anchor, with the copied pins at its ends.
class ClipWire {
  const ClipWire({
    required this.points,
    required this.net,
    this.pinA,
    this.pinB,
  });

  final List<Offset> points;

  /// Index into [CircuitClip.nets].
  final int net;
  final ClipPin? pinA;
  final ClipPin? pinB;
}

/// A piece of a schematic, copied: its parts, how they are wired to one
/// another, and the wires as they were drawn.
class CircuitClip {
  const CircuitClip({
    required this.parts,
    this.nets = const [],
    this.wires = const [],
  });

  final List<ClipPart> parts;
  final List<ClipNet> nets;
  final List<ClipWire> wires;

  /// `10k` for one part, `5 parts` for more.
  String get summary =>
      parts.length == 1 ? parts.single.spec.value : '${parts.length} parts';

  /// Copies the parts with a unit in [unitIds].
  ///
  /// Connections go with them when they join two copied pins, or when they
  /// are named. Wires go with them when every pin they end on was copied —
  /// including a wire left hanging from one, with nothing at its other end —
  /// and a wire ending on no pin at all goes when it lies wholly inside
  /// [area].
  static CircuitClip? of({
    required List<PartWithDetails> parts,
    required List<NetWithEndpoints> nets,
    required List<SchematicWire> wires,
    required Set<String> unitIds,
    Rect? area,
  }) {
    final copied = [
      for (final part in parts)
        if (part.units.any((u) => unitIds.contains(u.id))) part,
    ];
    if (copied.isEmpty) return null;

    final first = copied.first.units.firstWhere((u) => unitIds.contains(u.id));
    final anchor = Offset(first.x, first.y);

    final pinRefs = <String, ClipPin>{};
    for (var i = 0; i < copied.length; i++) {
      for (final pin in copied[i].pins) {
        pinRefs[pin.id] = ClipPin(part: i, unit: pin.unit, number: pin.number);
      }
    }

    final carried = [
      for (final wire in wires)
        if ((wire.pinAId == null || pinRefs.containsKey(wire.pinAId)) &&
            (wire.pinBId == null || pinRefs.containsKey(wire.pinBId)) &&
            (wire.pinAId != null ||
                wire.pinBId != null ||
                (area != null && wire.points.every(area.contains))))
          wire,
    ];
    final wiredNets = {for (final wire in carried) wire.netId};

    final clipNets = <ClipNet>[];
    final netIndex = <String, int>{};
    for (final net in nets) {
      final pins = [
        for (final endpoint in net.endpoints) ?pinRefs[endpoint.pin.id],
      ];
      if (pins.isEmpty) continue;
      // Two copied pins joined, a name to join by, or a wire drawn out of
      // one pin and left hanging — that wire needs its net to come too.
      if (pins.length >= 2 ||
          net.net.isNamed ||
          wiredNets.contains(net.net.id)) {
        netIndex[net.net.id] = clipNets.length;
        clipNets.add(ClipNet(pins: pins, name: net.net.name));
      }
    }

    final clipWires = <ClipWire>[];
    for (final wire in carried) {
      final net = netIndex[wire.netId];
      if (net == null) continue;
      clipWires.add(
        ClipWire(
          points: [for (final p in wire.points) p - anchor],
          net: net,
          pinA: pinRefs[wire.pinAId],
          pinB: pinRefs[wire.pinBId],
        ),
      );
    }

    return CircuitClip(
      parts: [
        for (final part in copied)
          ClipPart(
            spec: part.toSpec(),
            units: [
              for (final unit in part.units)
                ClipUnit(
                  unitNumber: unit.unitNumber,
                  offset: Offset(unit.x, unit.y) - anchor,
                  rotation: unit.rotation,
                  mirrorX: unit.mirrorX,
                  mirrorY: unit.mirrorY,
                ),
            ],
          ),
      ],
      nets: clipNets,
      wires: clipWires,
    );
  }
}
