import 'dart:math' as math;
import 'dart:ui';

import '../../domain/geometry/drawn_wire_geometry.dart';
import '../../domain/geometry/polyline_wiring.dart';
import '../../domain/geometry/segment_wiring.dart';
import '../../domain/models/models.dart';
import 'net_repository.dart';

/// The drawn wires of one sheet, and the rules that keep them tidy: pieces
/// split where another ends against them, pieces in a line joined, pieces
/// lying over one another or shrunk to nothing taken away.
///
/// The project and the sheet are fixed when one is made, rather than read
/// from whatever is open when it is used. An undo step holds one of these,
/// so taking an edit back works on the sheet the edit was made on —
/// whichever sheet is open by then, and whether or not the schematic is
/// still on screen.
class SheetWires {
  const SheetWires(
    this.repository, {
    required this.projectId,
    required this.sheetId,
  });

  final NetRepository repository;
  final String projectId;

  /// Null for the top sheet.
  final String? sheetId;

  /// The sheet's wires on [netId].
  Future<List<SchematicWire>> ofNet(String netId) async => [
    for (final wire in await repository.getSheetWires(projectId, sheetId))
      if (wire.netId == netId) wire,
  ];

  /// Puts a net's drawing into the shape the dragging rules expect: wires
  /// shrunk to nothing gone, wires in a straight line one wire, every wire
  /// ended at every junction, and nothing drawn twice.
  ///
  /// Joining straight runs can make a wire run through a junction again,
  /// and dropping a duplicate can leave two runs meeting in a line, so the
  /// steps go round until nothing changes.
  Future<void> tidyNet(String netId) => repository.transaction(() async {
    await dropShrunkWires(netId);
    for (var round = 0; round < 4; round++) {
      final (joined, _) = await mergeCollinear(netId);
      final (cut, _) = await splitAtJunctions(netId);
      final dropped = await dropCovered(netId);
      final trimmed = await trimRetracedEnds(netId);
      if (joined.isEmpty && cut.isEmpty && dropped.isEmpty && !trimmed) {
        break;
      }
    }
  });

  /// Cuts back wires of [netId] that leave a pin or junction along a wire
  /// already leaving it — see [PolylineWiring.trimRetracedEnds]. Returns
  /// whether anything changed.
  Future<bool> trimRetracedEnds(String netId) =>
      repository.transaction(() async {
        final stored = [
          for (final wire in await repository.getSheetWires(projectId, sheetId))
            if (wire.netId == netId) wire,
        ];
        final (changed, after) = PolylineWiring.trimRetracedEnds([
          for (final wire in stored)
            PolylineWire(
              id: wire.id,
              points: wire.points,
              pinA: wire.pinAId,
              pinB: wire.pinBId,
            ),
        ]);
        if (changed.isEmpty) return false;
        for (final wire in stored) {
          if (!changed.contains(wire.id)) continue;
          final now = after.where((w) => w.id == wire.id).firstOrNull;
          if (now == null) {
            await repository.deleteWire(wire.id);
            continue;
          }
          await repository.updateWire(wire.copyWith(points: now.points));
          await repository.setWireEnds(
            wire.id,
            pinAId: now.pinA,
            pinBId: now.pinB,
          );
        }
        return true;
      });

  /// Takes away wires of [netId] lying entirely along others of the net.
  ///
  /// A wire dragged along the one it hangs off, with its end held at the
  /// junction, turns a corner that runs back over wire already there. What
  /// is drawn is the same with or without it, and two wires in one place
  /// read as a fault — and are one when the sheet is exported. A wire on a
  /// pin is never taken: it is what holds that pin.
  Future<List<SchematicWire>> dropCovered(String netId) =>
      repository.transaction(() async {
        final removed = <SchematicWire>[];
        var wires = [
          for (final wire in await repository.getSheetWires(projectId, sheetId))
            if (wire.netId == netId) wire,
        ];
        var dropped = true;
        while (dropped) {
          dropped = false;
          for (final wire in wires) {
            if (wire.pinAId != null || wire.pinBId != null) continue;
            final others = [
              for (final other in wires)
                if (other.id != wire.id) other.points,
            ];
            if (!_coveredBy(wire.points, others)) continue;
            removed.add(wire);
            await repository.deleteWire(wire.id);
            wires = [
              for (final other in wires)
                if (other.id != wire.id) other,
            ];
            dropped = true;
            break;
          }
        }
        return removed;
      });

  /// Whether every bit of [points] lies on one of [others].
  static bool _coveredBy(List<Offset> points, List<List<Offset>> others) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final length = (b - a).distance;
      final steps = (length / 0.3).ceil().clamp(1, 2000);
      for (var k = 0; k <= steps; k++) {
        final at = Offset.lerp(a, b, k / steps)!;
        if (!others.any((other) => PolylineWiring.covers(other, at))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Takes away wires of [netId] that have shrunk to nothing.
  ///
  /// A wire dragged until its two ends meet is not a wire any more, and one
  /// left lying there keeps the wires either side of it apart: they meet it
  /// rather than each other, so they never read as the one wire they draw.
  Future<List<SchematicWire>> dropShrunkWires(String netId) =>
      repository.transaction(() async {
        final removed = <SchematicWire>[];
        for (final wire in await repository.getSheetWires(projectId, sheetId)) {
          if (wire.netId != netId) continue;
          var length = 0.0;
          for (var i = 0; i < wire.points.length - 1; i++) {
            length += (wire.points[i + 1] - wire.points[i]).distance;
          }
          if (length < 0.01) {
            removed.add(wire);
            await repository.deleteWire(wire.id);
          }
        }
        return removed;
      });

  /// Cuts wires of [netId] where another wire ends against their middle.
  ///
  /// A junction is where a wire stops against another, and either side of
  /// it is a wire in its own right — that is what lets one side be dragged
  /// without the other coming along. Returns the wires as they were and
  /// the pieces added, so the cut can be taken back.
  Future<(List<SchematicWire>, List<SchematicWire>)> splitAtJunctions(
    String netId,
  ) => repository.transaction(() async {
    final before = <SchematicWire>[];
    final added = <SchematicWire>[];

    final wires = [
      for (final wire in await repository.getSheetWires(projectId, sheetId))
        if (wire.netId == netId) wire,
    ];
    // The rule itself lives with the rest of the dragging rules, so the
    // canvas and their tests agree on where a wire ends.
    final split = PolylineWiring.splitAtJunctions([
      for (final wire in wires)
        PolylineWire(
          id: wire.id,
          points: wire.points,
          pinA: wire.pinAId,
          pinB: wire.pinBId,
        ),
    ]);
    for (final wire in wires) {
      final pieces = [
        for (final piece in split)
          if (piece.id == wire.id || piece.id.startsWith('${wire.id}~')) piece,
      ];
      if (pieces.length < 2) continue;
      final head = pieces.firstWhere((piece) => piece.id == wire.id);
      before.add(wire);
      await repository.updateWire(wire.copyWith(points: head.points));
      await repository.setWireEnds(
        wire.id,
        pinAId: wire.pinAId,
        pinBId: head.pinB,
      );
      for (final piece in pieces) {
        if (piece.id == wire.id) continue;
        final laid = await repository.addWire(
          sheetId: sheetId,
          projectId: projectId,
          points: piece.points,
          pinAId: piece.pinA,
          pinBId: piece.pinB,
          netId: netId,
        );
        if (laid != null) added.add(laid);
      }
    }
    return (before, added);
  });

  /// Nets holding a wire that runs straight through a junction — another
  /// wire of the net ending on its middle rather than at one of its ends.
  static Set<String> netsWithUnsplitJunctions(List<SchematicWire> wires) {
    final byNet = <String, List<SchematicWire>>{};
    for (final wire in wires) {
      (byNet[wire.netId] ??= []).add(wire);
    }
    return {
      for (final entry in byNet.entries)
        if (PolylineWiring.splitAtJunctions([
              for (final wire in entry.value)
                PolylineWire(
                  id: wire.id,
                  points: wire.points,
                  pinA: wire.pinAId,
                  pinB: wire.pinBId,
                ),
            ]).length >
            entry.value.length)
          entry.key,
      for (final entry in byNet.entries)
        if (PolylineWiring.trimRetracedEnds([
          for (final wire in entry.value)
            PolylineWire(
              id: wire.id,
              points: wire.points,
              pinA: wire.pinAId,
              pinB: wire.pinBId,
            ),
        ]).$1.isNotEmpty)
          entry.key,
    };
  }

  /// Joins wires of [netId] that meet end-to-end in a straight line.
  ///
  /// Two wires in a line with nothing between them are one wire, however
  /// they came to be that way — drawn one after the other, or brought
  /// together by dragging. Returns the wires as they were and the ones
  /// absorbed, so the join can be taken back.
  Future<(List<SchematicWire>, List<SchematicWire>)> mergeCollinear(
    String netId,
  ) => repository.transaction(() async {
    final before = <SchematicWire>[];
    final absorbed = <SchematicWire>[];

    var wires = [
      for (final wire in await repository.getSheetWires(projectId, sheetId))
        if (wire.netId == netId) wire,
    ];

    var joinedOne = true;
    while (joinedOne) {
      joinedOne = false;
      for (var i = 0; i < wires.length && !joinedOne; i++) {
        for (var j = i + 1; j < wires.length && !joinedOne; j++) {
          final join = _collinearJoin(wires[i], wires[j]);
          if (join == null) continue;
          final (points, pinA, pinB) = join;
          final kept = wires[i];
          final gone = wires[j];

          before.add(kept);
          absorbed.add(gone);
          await repository.deleteWire(gone.id);
          await repository.updateWire(kept.copyWith(points: points));
          await repository.setWireEnds(kept.id, pinAId: pinA, pinBId: pinB);

          wires = [
            for (final wire in wires)
              if (wire.id == kept.id)
                kept.copyWith(points: points)
              else if (wire.id != gone.id)
                wire,
          ];
          joinedOne = true;
        }
      }
    }
    return (before, absorbed);
  });

  /// Whether [before] runs into [after] in the same direction where they
  /// meet — the only thing that makes them one wire.
  ///
  /// Comparing the tidied length of the two joined instead would call any
  /// pair with a redundant corner anywhere in it a straight run, and merge
  /// wires that simply touch at a corner. That quietly moved the far end
  /// of the other wire, taking it off whatever it was joined to.
  static bool carriesStraightOn(List<Offset> before, List<Offset> after) {
    if (before.length < 2 || after.length < 2) return false;
    final incoming = before.last - before[before.length - 2];
    final outgoing = after[1] - after.first;
    final cross = incoming.dx * outgoing.dy - incoming.dy * outgoing.dx;
    final along = incoming.dx * outgoing.dx + incoming.dy * outgoing.dy;
    return cross.abs() < 0.01 && along > 0;
  }

  /// The one wire two straight overlapping wires are drawing, or null when
  /// they do not lie along each other.
  static (List<Offset>, String?, String?)? _overlapUnion(
    SchematicWire a,
    SchematicWire b,
  ) {
    final horizontal =
        (a.points.first.dy - a.points.last.dy).abs() < 0.01 &&
        (b.points.first.dy - b.points.last.dy).abs() < 0.01 &&
        (a.points.first.dy - b.points.first.dy).abs() < 0.01;
    final vertical =
        (a.points.first.dx - a.points.last.dx).abs() < 0.01 &&
        (b.points.first.dx - b.points.last.dx).abs() < 0.01 &&
        (a.points.first.dx - b.points.first.dx).abs() < 0.01;
    if (!horizontal && !vertical) return null;

    double along(Offset p) => horizontal ? p.dx : p.dy;

    // They have to share more than a single point: meeting end to end is
    // the straight-extension case below, which knows about corners.
    final lowA = math.min(along(a.points.first), along(a.points.last));
    final highA = math.max(along(a.points.first), along(a.points.last));
    final lowB = math.min(along(b.points.first), along(b.points.last));
    final highB = math.max(along(b.points.first), along(b.points.last));
    if (math.min(highA, highB) - math.max(lowA, lowB) <= 0.01) return null;

    final ends = [
      (along(a.points.first), a.points.first, a.pinAId),
      (along(a.points.last), a.points.last, a.pinBId),
      (along(b.points.first), b.points.first, b.pinAId),
      (along(b.points.last), b.points.last, b.pinBId),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    return ([ends.first.$2, ends.last.$2], ends.first.$3, ends.last.$3);
  }

  /// How [a] and [b] read as one wire, when they meet end to end and carry
  /// straight on: the joined shape and the pins its two ends then have.
  /// Null when they meet at a corner, or not at all — a corner is a place a
  /// third wire can be drawn from, so those stay two wires.
  static (List<Offset>, String?, String?)? _collinearJoin(
    SchematicWire a,
    SchematicWire b,
  ) {
    // Two straight wires lying along each other are one wire drawn twice —
    // which happens the moment one is dragged onto the other. They become
    // the single wire they are drawing, rather than a duplicate.
    if (a.points.length == 2 && b.points.length == 2) {
      final union = _overlapUnion(a, b);
      if (union != null) return union;
    }

    for (final flipA in [false, true]) {
      for (final flipB in [false, true]) {
        final pa = flipA ? a.points.reversed.toList() : a.points;
        final pb = flipB ? b.points.reversed.toList() : b.points;
        if ((pa.last - pb.first).distance > 0.01) continue;

        // Neither of the ends being joined may be held by a pin.
        if (((flipA ? a.pinAId : a.pinBId) ?? '').isNotEmpty) continue;
        if (((flipB ? b.pinBId : b.pinAId) ?? '').isNotEmpty) continue;

        if (!carriesStraightOn(pa, pb)) continue;
        final tidied = DrawnWireGeometry.simplify([...pa, ...pb.skip(1)]);
        // A wire needs two ends. Anything shorter means the two were
        // folded back over each other rather than carried on.
        if (tidied.length < 2) continue;

        return (
          tidied,
          flipA ? a.pinBId : a.pinAId,
          flipB ? b.pinAId : b.pinBId,
        );
      }
    }
    return null;
  }

  /// Writes [segments] as the wires of [netId], updating the rows they came
  /// from, adding the pieces that are new and deleting what is left over.
  Future<void> writeSegments(
    String netId,
    List<SchematicWire> rows,
    List<WireSegment> segments,
  ) => repository.transaction(() async {
    final kept = <String>{};
    for (final segment in segments) {
      final row = rows.where((w) => w.id == segment.id).firstOrNull;
      if (row != null) {
        kept.add(row.id);
        await repository.updateWire(
          row.copyWith(points: [segment.a, segment.b]),
        );
        await repository.setWireEnds(
          row.id,
          pinAId: segment.pinA,
          pinBId: segment.pinB,
        );
      } else {
        final added = await repository.addWire(
          sheetId: sheetId,
          projectId: projectId,
          points: [segment.a, segment.b],
          pinAId: segment.pinA,
          pinBId: segment.pinB,
          netId: netId,
        );
        if (added != null) kept.add(added.id);
      }
    }
    for (final row in rows) {
      if (!kept.contains(row.id)) await repository.deleteWire(row.id);
    }
  });

  /// Puts a net's wires back exactly as [rows] had them.
  Future<void> restoreNetWires(String netId, List<SchematicWire> rows) =>
      repository.transaction(() async {
        for (final row in await repository.getSheetWires(projectId, sheetId)) {
          if (row.netId == netId) await repository.deleteWire(row.id);
        }
        for (final row in rows) {
          await repository.restoreWire(row);
        }
      });
}
