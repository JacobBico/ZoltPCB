import 'dart:ui' show Offset;

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import 'active_sheet.dart';
import '../db/watchers.dart';
import '../db/mappers.dart';

/// Thrown when a requested connection cannot form a valid net.
class InvalidConnectionException implements Exception {
  const InvalidConnectionException(this.message);

  final String message;

  @override
  String toString() => 'InvalidConnectionException: $message';
}

/// One net as it stood before an edit.
class PriorNet {
  const PriorNet({
    required this.name,
    required this.pinIds,
    this.wires = const [],
    this.netClassId,
    this.labelledPinIds = const {},
  });

  final String? name;
  final List<String> pinIds;

  /// The pins that carried a label of their own.
  final Set<String> labelledPinIds;

  /// The net's drawn wires, so undoing a disconnect brings back their
  /// shapes rather than an automatic route.
  final List<SchematicWire> wires;
  final String? netClassId;

  @override
  String toString() => 'PriorNet(${name ?? "<unnamed>"}, ${pinIds.length})';
}

/// Enough of the netlist to undo a single connect.
class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.projectId,
    required this.pins,
    required this.nets,
  });

  final String projectId;

  /// The pins the operation was given.
  final List<String> pins;

  /// The nets those pins belonged to, with their full membership.
  final List<PriorNet> nets;

  @override
  String toString() =>
      'ConnectionSnapshot(${pins.length} pins, ${nets.length} nets)';
}

/// Connectivity: nets and the pins that belong to them.
///
/// The tap-one-pin-then-another interaction reduces to a single call to
/// [connectPins]. All four cases (neither pin connected, one connected,
/// two separate nets, already the same net) are resolved here so the UI
/// never has to reason about them.
class NetRepository {
  NetRepository(this._db);

  final AppDatabase _db;

  Stream<List<NetWithEndpoints>> watchNets(String projectId) {
    return _db.watchAggregate({
      _db.nets,
      _db.netNodes,
      _db.partPins,
      _db.parts,
    }, () => getNets(projectId));
  }

  Future<List<NetWithEndpoints>> getNets(String projectId) async {
    final netRows =
        await (_db.select(_db.nets)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (netRows.isEmpty) return const [];

    final endpointsByNet = await _endpointsForProject(projectId);
    return [
      for (final row in netRows)
        NetWithEndpoints(
          net: row.toDomain(),
          endpoints: endpointsByNet[row.id] ?? const [],
        ),
    ];
  }

  Future<NetWithEndpoints?> getNet(String netId) async {
    final row = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    if (row == null) return null;
    final endpointsByNet = await _endpointsForProject(row.projectId);
    return NetWithEndpoints(
      net: row.toDomain(),
      endpoints: endpointsByNet[netId] ?? const [],
    );
  }

  /// The net a pin belongs to, or null when the pin is unconnected.
  Future<String?> netIdForPin(String pinId) async {
    final row = await (_db.select(
      _db.netNodes,
    )..where((t) => t.partPinId.equals(pinId))).getSingleOrNull();
    return row?.netId;
  }

  /// Pin id to net id for a whole project. The canvas and pinout views use
  /// this to show at a glance which pins are already wired up.
  Future<Map<String, String>> pinToNetMap(String projectId) async {
    final query = _db.select(_db.netNodes).join([
      innerJoin(_db.nets, _db.nets.id.equalsExp(_db.netNodes.netId)),
    ])..where(_db.nets.projectId.equals(projectId));
    final rows = await query.get();
    return {
      for (final row in rows)
        row.readTable(_db.netNodes).partPinId: row
            .readTable(_db.netNodes)
            .netId,
    };
  }

  /// Connects two pins, creating or merging nets as needed.
  ///
  /// * Neither pin connected: a new net is created with both pins.
  /// * One pin connected: the other joins that net.
  /// * Both connected to different nets: the nets are merged.
  /// * Both already on the same net: nothing changes.
  ///
  /// Returns the net the two pins now share.
  Future<NetWithEndpoints> connectPins(String pinAId, String pinBId) async {
    if (pinAId == pinBId) {
      throw const InvalidConnectionException('A pin cannot connect to itself');
    }

    final netId = await _db.transaction(() async {
      final projectId = await _projectIdForPins(pinAId, pinBId);

      final nodeA = await (_db.select(
        _db.netNodes,
      )..where((t) => t.partPinId.equals(pinAId))).getSingleOrNull();
      final nodeB = await (_db.select(
        _db.netNodes,
      )..where((t) => t.partPinId.equals(pinBId))).getSingleOrNull();

      if (nodeA != null && nodeB != null) {
        if (nodeA.netId == nodeB.netId) return nodeA.netId;
        return _mergeNets(nodeA.netId, nodeB.netId);
      }
      if (nodeA != null) {
        await _addNode(nodeA.netId, pinBId);
        return nodeA.netId;
      }
      if (nodeB != null) {
        await _addNode(nodeB.netId, pinAId);
        return nodeB.netId;
      }

      final createdNetId = await _createNet(projectId);
      await _addNode(createdNetId, pinAId);
      await _addNode(createdNetId, pinBId);
      return createdNetId;
    });

    await _applyPowerSymbolName(netId);
    final joined = await _joinSameName(netId);
    await _touchProjectForNet(joined);
    final net = await getNet(joined);
    return net!;
  }

  /// Adds a single pin to an existing net.
  Future<void> addPinToNet(String netId, String pinId) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.netNodes,
      )..where((t) => t.partPinId.equals(pinId))).getSingleOrNull();
      if (existing != null) {
        if (existing.netId == netId) return;
        await (_db.delete(
          _db.netNodes,
        )..where((t) => t.id.equals(existing.id))).go();
        await _pruneNet(existing.netId);
      }
      await _addNode(netId, pinId);
    });
    await _applyPowerSymbolName(netId);
    final joined = await _joinSameName(netId);
    await _touchProjectForNet(joined);
  }

  /// Removes a pin from whatever net it is on.
  ///
  /// Because a net is a set of pins rather than a drawn path, removing one
  /// pin can never split the remainder into two nets — the other members
  /// stay connected to each other.
  Future<void> disconnectPin(String pinId) async {
    final netId = await _db.transaction(() async {
      final node = await (_db.select(
        _db.netNodes,
      )..where((t) => t.partPinId.equals(pinId))).getSingleOrNull();
      if (node == null) return null;
      await (_db.delete(_db.netNodes)..where((t) => t.id.equals(node.id))).go();
      // A drawn wire to a pin that has left the net is drawing nothing.
      await (_db.delete(
        _db.schematicWires,
      )..where((t) => t.pinAId.equals(pinId) | t.pinBId.equals(pinId))).go();
      await _pruneNet(node.netId);
      return node.netId;
    });
    if (netId != null) await _touchProjectForNet(netId);
  }

  /// Exchanges what each pin of each pair in [pairs] is connected to.
  ///
  /// With [keepWires], the drawn wires to one pin of a pair are moved to
  /// the other — a gate swap, where the two gates also trade places on the
  /// sheet, so every wire still ends where it did. Without, the wires to
  /// the pins are removed and each pin carries its new net as a label —
  /// a pin swap, where two pins cannot trade places on the symbol and a
  /// wire left on either would now be drawing the wrong connection.
  Future<void> swapConnections(
    Map<String, String> pairs, {
    required bool keepWires,
  }) async {
    final touched = <String>{};
    await _db.transaction(() async {
      Future<NetNodeRow?> nodeOf(String pinId) => (_db.select(
        _db.netNodes,
      )..where((t) => t.partPinId.equals(pinId))).getSingleOrNull();

      for (final MapEntry(key: a, value: b) in pairs.entries) {
        final na = await nodeOf(a);
        final nb = await nodeOf(b);
        await (_db.delete(
          _db.netNodes,
        )..where((t) => t.partPinId.isIn([a, b]))).go();
        if (na != null) {
          await _addNode(na.netId, b, labelled: na.labelled);
          touched.add(na.netId);
        }
        if (nb != null) {
          await _addNode(nb.netId, a, labelled: nb.labelled);
          touched.add(nb.netId);
        }

        final wires = await (_db.select(
          _db.schematicWires,
        )..where((t) => t.pinAId.isIn([a, b]) | t.pinBId.isIn([a, b]))).get();
        if (!keepWires) {
          await (_db.delete(
            _db.schematicWires,
          )..where((t) => t.id.isIn([for (final w in wires) w.id]))).go();
          continue;
        }
        String? other(String? pin) => pin == a ? b : (pin == b ? a : pin);
        for (final wire in wires) {
          await (_db.update(
            _db.schematicWires,
          )..where((t) => t.id.equals(wire.id))).write(
            SchematicWiresCompanion(
              pinAId: Value(other(wire.pinAId)),
              pinBId: Value(other(wire.pinBId)),
            ),
          );
        }
      }
      if (!keepWires) {
        for (final MapEntry(key: a, value: b) in pairs.entries) {
          await _setLabelled(a, true);
          await _setLabelled(b, true);
        }
      }
    });
    for (final netId in touched) {
      await _touchProjectForNet(netId);
    }
  }

  /// Sets or clears a net's label. Pass null to make the net anonymous
  /// again, in which case it is auto-named on export.
  ///
  /// A name is an identity, the way a label is in KiCad: naming a net SDA
  /// joins it to any other SDA in the project. Returns the id of the net
  /// the pins ended up on.
  Future<String> renameNet(String netId, String? name) async {
    final trimmed = name?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    await (_db.update(_db.nets)..where((t) => t.id.equals(netId))).write(
      NetsCompanion(name: Value(value)),
    );
    final joined = await _joinSameName(netId);
    await _touchProjectForNet(joined);
    return joined;
  }

  /// The pins of every net called [name] in [projectId], for taking a
  /// snapshot before an operation that may join them.
  Future<List<String>> pinsNamed(String projectId, String? name) async {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return const [];
    final query =
        _db.select(_db.netNodes).join([
          innerJoin(_db.nets, _db.nets.id.equalsExp(_db.netNodes.netId)),
        ])..where(
          _db.nets.projectId.equals(projectId) & _db.nets.name.equals(trimmed),
        );
    return [
      for (final row in await query.get())
        row.readTable(_db.netNodes).partPinId,
    ];
  }

  /// Puts a single pin on a net of its own called [name] — a label on one
  /// pin, which joins whatever else carries that name.
  /// The net [pinId] is on, making one holding just that pin when it is on
  /// none — for a wire drawn out from a pin and left open-ended.
  Future<String> netForPin(String projectId, String pinId) async {
    final existing = await netIdForPin(pinId);
    if (existing != null) return existing;
    final netId = await _createNet(projectId);
    await _addNode(netId, pinId);
    await _touchProject(projectId);
    return netId;
  }

  ///
  /// With [joinByName], the pin is marked as carrying its own label, so the
  /// sheet shows the name at it instead of routing a wire to the rest of
  /// the net — what the Labels action wants. Off, the net is named and
  /// drawn exactly as a named net always has been.
  Future<String> labelPin(
    String projectId,
    String pinId,
    String name, {
    bool joinByName = true,
  }) async {
    final existing = await netIdForPin(pinId);
    if (existing != null) {
      if (joinByName) await _setLabelled(pinId, true);
      return renameNet(existing, name);
    }
    final netId = await _createNet(projectId, name: name.trim());
    await _addNode(netId, pinId, labelled: joinByName);
    final joined = await _joinSameName(netId);
    await _touchProject(projectId);
    return joined;
  }

  /// Joins nets sharing a name, for designs that arrive with duplicates.
  Future<void> joinSameNamedNets() => _db.joinSameNamedNets();

  /// Joins every other net in the project with [netId]'s name into it, and
  /// returns the survivor.
  Future<String> _joinSameName(String netId) async {
    final row = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    final name = row?.name;
    if (row == null || name == null || name.isEmpty) return netId;

    final others =
        await (_db.select(_db.nets)..where(
              (t) =>
                  t.projectId.equals(row.projectId) &
                  t.name.equals(name) &
                  t.id.equals(netId).not(),
            ))
            .get();
    var survivor = netId;
    for (final other in others) {
      survivor = await _mergeNets(survivor, other.id);
    }
    return survivor;
  }

  /// Moves a net's label, or clears the position so it goes back to the
  /// spot the drawing chooses for it.
  Future<void> setNetLabelPosition(String netId, Offset? at) async {
    await (_db.update(_db.nets)..where((t) => t.id.equals(netId))).write(
      NetsCompanion(labelX: Value(at?.dx), labelY: Value(at?.dy)),
    );
    await _touchProjectForNet(netId);
  }

  /// Deletes a net and every membership in it. The pins become unconnected.
  Future<void> deleteNet(String netId) async {
    final row = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.nets)..where((t) => t.id.equals(netId))).go();
    await _touchProject(row.projectId);
  }

  /// Names a net after the power symbol on it.
  ///
  /// This is what a power symbol is for. In KiCad a `#PWR` part is not a
  /// component at all — it is a label that happens to have a shape — and the
  /// net it touches takes its value as a name. Connecting a pin to a GND
  /// symbol should therefore produce a net called GND, without the user
  /// having to type it.
  ///
  /// An existing label is left alone: a name the user typed outranks one
  /// inferred from a symbol.
  Future<void> _applyPowerSymbolName(String netId) async {
    final net = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    if (net == null || (net.name != null && net.name!.isNotEmpty)) return;

    final query = _db.select(_db.netNodes).join([
      innerJoin(
        _db.partPins,
        _db.partPins.id.equalsExp(_db.netNodes.partPinId),
      ),
      innerJoin(_db.parts, _db.parts.id.equalsExp(_db.partPins.partId)),
    ])..where(_db.netNodes.netId.equals(netId));

    final rows = await query.get();
    for (final row in rows) {
      final part = row.readTable(_db.parts);
      if (!isPowerReference(part.reference)) continue;
      final name = part.value.trim();
      if (name.isEmpty) continue;
      await (_db.update(_db.nets)..where((t) => t.id.equals(netId))).write(
        NetsCompanion(name: Value(name)),
      );
      return;
    }
  }

  /// KiCad marks power and ground symbols with a `#PWR` designator, which is
  /// also how they are kept out of the BOM.
  static bool isPowerReference(String reference) =>
      Part.isPowerReference(reference);

  /// Captures the connectivity of [pinIds] and of every net they belong
  /// to, so a later [restore] can put it back exactly.
  ///
  /// Connecting two pins can merge two nets into one, which destroys
  /// information: afterwards there is no way to tell where the seam was, or
  /// which label the losing net carried. Anything offering an undo has to
  /// take this before it acts.
  Future<ConnectionSnapshot> capture(
    String projectId,
    List<String> pinIds,
  ) async {
    final netIds = <String>{};
    for (final pinId in pinIds) {
      final netId = await netIdForPin(pinId);
      if (netId != null) netIds.add(netId);
    }

    final priorNets = <PriorNet>[];
    for (final netId in netIds) {
      final net = await (_db.select(
        _db.nets,
      )..where((t) => t.id.equals(netId))).getSingleOrNull();
      if (net == null) continue;
      final nodes =
          await (_db.select(_db.netNodes)
                ..where((t) => t.netId.equals(netId))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      priorNets.add(
        PriorNet(
          name: net.name,
          pinIds: [for (final node in nodes) node.partPinId],
          labelledPinIds: {
            for (final node in nodes)
              if (node.labelled) node.partPinId,
          },
          wires: await getWiresOfNet(netId),
          netClassId: net.netClassId,
        ),
      );
    }

    return ConnectionSnapshot(
      projectId: projectId,
      pins: List.unmodifiable(pinIds),
      nets: List.unmodifiable(priorNets),
    );
  }

  /// Puts connectivity back as [snapshot] recorded it.
  Future<void> restore(ConnectionSnapshot snapshot) async {
    await _db.transaction(() async {
      final affected = <String>{
        ...snapshot.pins,
        for (final net in snapshot.nets) ...net.pinIds,
      };

      // Detach every pin the operation could have touched, remembering the
      // nets they came from so emptied ones can be tidied away.
      final touchedNets = <String>{};
      for (final pinId in affected) {
        final node = await (_db.select(
          _db.netNodes,
        )..where((t) => t.partPinId.equals(pinId))).getSingleOrNull();
        if (node == null) continue;
        touchedNets.add(node.netId);
        await (_db.delete(
          _db.netNodes,
        )..where((t) => t.id.equals(node.id))).go();
      }
      for (final netId in touchedNets) {
        await _pruneNet(netId);
      }

      for (final prior in snapshot.nets) {
        if (prior.pinIds.isEmpty) continue;
        final netId = await _createNet(snapshot.projectId, name: prior.name);
        if (prior.netClassId != null) {
          await (_db.update(_db.nets)..where((t) => t.id.equals(netId))).write(
            NetsCompanion(netClassId: Value(prior.netClassId)),
          );
        }
        for (final pinId in prior.pinIds) {
          await _addNode(
            netId,
            pinId,
            labelled: prior.labelledPinIds.contains(pinId),
          );
        }
        for (final wire in prior.wires) {
          await _db
              .into(_db.schematicWires)
              .insert(
                _wireCompanion(wire.copyWith(netId: netId)),
                mode: InsertMode.insertOrReplace,
              );
        }
      }
    });
    await _touchProject(snapshot.projectId);
  }

  // --- drawn wires -------------------------------------------------------

  Stream<List<SchematicWire>> watchWires(String projectId) {
    final query = _db.select(_db.schematicWires)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => [for (final r in rows) _toWire(r)]);
  }

  /// The project's drawn wires. With [openSheetOnly], only those on the
  /// sheet open in the schematic ([ActiveSheet]) — which is what anything
  /// reshaping a net's drawing must work on, so it never reaches into a
  /// sheet it is not showing.
  Future<List<SchematicWire>> getWires(
    String projectId, {
    bool openSheetOnly = false,
  }) async {
    final rows =
        await (_db.select(_db.schematicWires)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    final sheet = ActiveSheet.of(projectId);
    return [
      for (final r in rows)
        if (!openSheetOnly || r.sheetId == sheet) _toWire(r),
    ];
  }

  Future<List<SchematicWire>> getWiresOfNet(String netId) async {
    final rows =
        await (_db.select(_db.schematicWires)
              ..where((t) => t.netId.equals(netId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return [for (final r in rows) _toWire(r)];
  }

  /// Stores a wire as drawn, on whatever net [pinAId] or [pinBId] is on now.
  Future<SchematicWire?> addWire({
    required String projectId,
    required List<Offset> points,
    String? pinAId,
    String? pinBId,
    String? netId,
    String? sheetId,
  }) async {
    final net =
        netId ??
        (pinAId == null ? null : await netIdForPin(pinAId)) ??
        (pinBId == null ? null : await netIdForPin(pinBId));
    if (net == null || points.length < 2) return null;
    final wire = SchematicWire(
      id: newId(),
      projectId: projectId,
      netId: net,
      pinAId: pinAId,
      pinBId: pinBId,
      sheetId: sheetId ?? ActiveSheet.of(projectId),
      points: points,
    );
    await _db.into(_db.schematicWires).insert(_wireCompanion(wire));
    await _touchProject(projectId);
    return wire;
  }

  /// Re-attaches a wire's ends, for one dragged off a pin or onto another.
  ///
  /// The ends are what makes a drawn wire follow the parts it joins, so a
  /// wire that has been dragged somewhere else has to be told where it now
  /// begins and ends — otherwise it snaps back to the pins it was drawn
  /// between the next time the sheet is drawn.
  Future<void> setWireEnds(
    String id, {
    required String? pinAId,
    required String? pinBId,
  }) async {
    await (_db.update(_db.schematicWires)..where((t) => t.id.equals(id))).write(
      SchematicWiresCompanion(pinAId: Value(pinAId), pinBId: Value(pinBId)),
    );
  }

  Future<void> updateWire(SchematicWire wire) async {
    await (_db.update(
      _db.schematicWires,
    )..where((t) => t.id.equals(wire.id))).write(
      SchematicWiresCompanion(points: Value(SchematicWire.encode(wire.points))),
    );
    await _touchProject(wire.projectId);
  }

  Future<void> deleteWire(String id) async {
    await (_db.delete(_db.schematicWires)..where((t) => t.id.equals(id))).go();
  }

  /// Puts a deleted wire back, if its net is still there to hold it.
  Future<void> restoreWire(SchematicWire wire) async {
    final net = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(wire.netId))).getSingleOrNull();
    if (net == null) return;
    await _db
        .into(_db.schematicWires)
        .insert(_wireCompanion(wire), mode: InsertMode.insertOrReplace);
  }

  SchematicWiresCompanion _wireCompanion(SchematicWire wire) =>
      SchematicWiresCompanion.insert(
        id: wire.id,
        projectId: wire.projectId,
        netId: wire.netId,
        pinAId: Value(wire.pinAId),
        pinBId: Value(wire.pinBId),
        sheetId: Value(wire.sheetId),
        points: SchematicWire.encode(wire.points),
        createdAt: DateTime.now(),
      );

  SchematicWire _toWire(SchematicWireRow row) => SchematicWire(
    id: row.id,
    projectId: row.projectId,
    netId: row.netId,
    pinAId: row.pinAId,
    pinBId: row.pinBId,
    sheetId: row.sheetId,
    points: SchematicWire.decode(row.points),
  );

  /// The stable key for a wire between two pins, independent of the order
  /// they were tapped in or which net they ended up on.
  static String routeKey(String pinAId, String pinBId) =>
      pinAId.compareTo(pinBId) <= 0 ? '$pinAId|$pinBId' : '$pinBId|$pinAId';

  /// User adjustments to drawn wire routes, keyed by [routeKey].
  Future<Map<String, List<double>>> routeHints(String projectId) async {
    final rows = await (_db.select(
      _db.netRouteHints,
    )..where((t) => t.projectId.equals(projectId))).get();
    return {
      for (final row in rows)
        routeKey(row.pinAId, row.pinBId): _decodeOffsets(row.turnOffsets),
    };
  }

  Stream<Map<String, List<double>>> watchRouteHints(String projectId) {
    final query = _db.select(_db.netRouteHints)
      ..where((t) => t.projectId.equals(projectId));
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          routeKey(row.pinAId, row.pinBId): _decodeOffsets(row.turnOffsets),
      },
    );
  }

  /// Records how far each movable run of a wire has been shifted. A list of
  /// all zeroes removes the adjustment rather than storing a no-op.
  Future<void> setRouteHint(
    String projectId,
    String pinAId,
    String pinBId,
    List<double> offsets,
  ) async {
    final first = pinAId.compareTo(pinBId) <= 0 ? pinAId : pinBId;
    final second = pinAId.compareTo(pinBId) <= 0 ? pinBId : pinAId;

    final existing =
        await (_db.select(_db.netRouteHints)
              ..where((t) => t.pinAId.equals(first) & t.pinBId.equals(second)))
            .getSingleOrNull();

    final meaningful = offsets.any((value) => value.abs() >= 1e-6);
    if (!meaningful) {
      if (existing != null) {
        await (_db.delete(
          _db.netRouteHints,
        )..where((t) => t.id.equals(existing.id))).go();
      }
      return;
    }

    final encoded = _encodeOffsets(offsets);
    if (existing == null) {
      await _db
          .into(_db.netRouteHints)
          .insert(
            NetRouteHintsCompanion.insert(
              id: newId(),
              projectId: projectId,
              pinAId: first,
              pinBId: second,
              turnOffsets: Value(encoded),
            ),
          );
      return;
    }
    await (_db.update(_db.netRouteHints)
          ..where((t) => t.id.equals(existing.id)))
        .write(NetRouteHintsCompanion(turnOffsets: Value(encoded)));
  }

  static String _encodeOffsets(List<double> offsets) =>
      offsets.map((value) => value.toStringAsFixed(4)).join(',');

  static List<double> _decodeOffsets(String encoded) {
    if (encoded.isEmpty) return const [];
    return [
      for (final part in encoded.split(',')) double.tryParse(part) ?? 0.0,
    ];
  }

  // --- internals -------------------------------------------------------

  Future<String> _createNet(String projectId, {String? name}) async {
    final id = newId();
    await _db
        .into(_db.nets)
        .insert(
          NetsCompanion.insert(
            id: id,
            projectId: projectId,
            name: Value(name),
            createdAt: DateTime.now(),
          ),
        );
    return id;
  }

  Future<void> _addNode(
    String netId,
    String pinId, {
    bool labelled = false,
  }) async {
    await _db
        .into(_db.netNodes)
        .insert(
          NetNodesCompanion.insert(
            id: newId(),
            netId: netId,
            partPinId: pinId,
            labelled: Value(labelled),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Marks [pinId] as carrying its own label, or not.
  Future<void> _setLabelled(String pinId, bool labelled) async {
    await (_db.update(_db.netNodes)..where((t) => t.partPinId.equals(pinId)))
        .write(NetNodesCompanion(labelled: Value(labelled)));
  }

  /// Merges two nets and returns the id of the survivor.
  ///
  /// A user-named net always wins over an anonymous one, so merging a plain
  /// net into `VCC` keeps the label. When both or neither are named, the
  /// older net survives.
  Future<String> _mergeNets(String netIdA, String netIdB) async {
    final rows = await (_db.select(
      _db.nets,
    )..where((t) => t.id.isIn([netIdA, netIdB]))).get();
    if (rows.length < 2) return netIdA;

    final a = rows.firstWhere((r) => r.id == netIdA);
    final b = rows.firstWhere((r) => r.id == netIdB);
    final aNamed = a.name != null && a.name!.isNotEmpty;
    final bNamed = b.name != null && b.name!.isNotEmpty;

    final NetRow winner;
    final NetRow loser;
    if (aNamed != bNamed) {
      winner = aNamed ? a : b;
      loser = aNamed ? b : a;
    } else if (a.createdAt.isAfter(b.createdAt)) {
      winner = b;
      loser = a;
    } else {
      winner = a;
      loser = b;
    }

    await (_db.update(_db.netNodes)..where((t) => t.netId.equals(loser.id)))
        .write(NetNodesCompanion(netId: Value(winner.id)));
    // Everything else that belongs to the net comes across too. The board's
    // copper points at nets with set-null, so without this a merge quietly
    // left routed tracks on no net at all.
    await (_db.update(_db.boardTracks)..where((t) => t.netId.equals(loser.id)))
        .write(BoardTracksCompanion(netId: Value(winner.id)));
    await (_db.update(_db.boardVias)..where((t) => t.netId.equals(loser.id)))
        .write(BoardViasCompanion(netId: Value(winner.id)));
    await (_db.update(_db.boardZones)..where((t) => t.netId.equals(loser.id)))
        .write(BoardZonesCompanion(netId: Value(winner.id)));
    await (_db.update(_db.boardFeatures)
          ..where((t) => t.netId.equals(loser.id)))
        .write(BoardFeaturesCompanion(netId: Value(winner.id)));
    await (_db.update(_db.schematicWires)
          ..where((t) => t.netId.equals(loser.id)))
        .write(SchematicWiresCompanion(netId: Value(winner.id)));
    if (winner.netClassId == null && loser.netClassId != null) {
      await (_db.update(_db.nets)..where((t) => t.id.equals(winner.id))).write(
        NetsCompanion(netClassId: Value(loser.netClassId)),
      );
    }
    await (_db.delete(_db.nets)..where((t) => t.id.equals(loser.id))).go();
    return winner.id;
  }

  /// Drops a net that no longer carries a meaningful connection: one with
  /// no pins at all, or a single unnamed pin left dangling.
  Future<void> _pruneNet(String netId) async {
    final nodeCount = await (_db.select(
      _db.netNodes,
    )..where((t) => t.netId.equals(netId))).get().then((r) => r.length);
    if (nodeCount == 0) {
      await (_db.delete(_db.nets)..where((t) => t.id.equals(netId))).go();
      return;
    }
    if (nodeCount > 1) return;

    final net = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    // A labelled net stays: a single named pin is a deliberate net label,
    // not leftover debris.
    if (net != null && (net.name == null || net.name!.isEmpty)) {
      await (_db.delete(_db.nets)..where((t) => t.id.equals(netId))).go();
    }
  }

  Future<Map<String, List<NetEndpoint>>> _endpointsForProject(
    String projectId,
  ) async {
    final query =
        _db.select(_db.netNodes).join([
            innerJoin(
              _db.partPins,
              _db.partPins.id.equalsExp(_db.netNodes.partPinId),
            ),
            innerJoin(_db.parts, _db.parts.id.equalsExp(_db.partPins.partId)),
            innerJoin(_db.nets, _db.nets.id.equalsExp(_db.netNodes.netId)),
          ])
          ..where(_db.nets.projectId.equals(projectId))
          ..orderBy([OrderingTerm.asc(_db.netNodes.createdAt)]);

    final rows = await query.get();
    final result = <String, List<NetEndpoint>>{};
    for (final row in rows) {
      final node = row.readTable(_db.netNodes);
      final endpoint = NetEndpoint(
        node: node.toDomain(),
        part: row.readTable(_db.parts).toDomain(),
        pin: row.readTable(_db.partPins).toDomain(),
      );
      (result[node.netId] ??= []).add(endpoint);
    }
    // Ordered by designator and pad rather than by when the connection was
    // made. Insertion order is not stable — two nodes created in the same
    // millisecond can come back either way round — and an unnamed net takes
    // its displayed name from its first endpoint, so an unstable order would
    // make a net appear to rename itself.
    for (final endpoints in result.values) {
      endpoints.sort(_compareEndpoints);
    }
    return result;
  }

  static int _compareEndpoints(NetEndpoint a, NetEndpoint b) {
    final byReference = _compareReferences(a.part.reference, b.part.reference);
    if (byReference != 0) return byReference;
    final na = int.tryParse(a.pin.number);
    final nb = int.tryParse(b.pin.number);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.pin.number.compareTo(b.pin.number);
  }

  /// `R2` before `R10`: designators sort by prefix, then numerically.
  static int _compareReferences(String a, String b) {
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

  /// Resolves the project both pins belong to, rejecting cross-project or
  /// dangling pin ids before any rows are written.
  Future<String> _projectIdForPins(String pinAId, String pinBId) async {
    final query = _db.select(_db.partPins).join([
      innerJoin(_db.parts, _db.parts.id.equalsExp(_db.partPins.partId)),
    ])..where(_db.partPins.id.isIn([pinAId, pinBId]));
    final rows = await query.get();
    if (rows.length != 2) {
      throw const InvalidConnectionException('One or both pins do not exist');
    }
    final projects = rows.map((r) => r.readTable(_db.parts).projectId).toSet();
    if (projects.length != 1) {
      throw const InvalidConnectionException(
        'Pins belong to different projects',
      );
    }
    return projects.single;
  }

  Future<void> _touchProjectForNet(String netId) async {
    final row = await (_db.select(
      _db.nets,
    )..where((t) => t.id.equals(netId))).getSingleOrNull();
    if (row != null) await _touchProject(row.projectId);
  }

  Future<void> _touchProject(String projectId) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
        .write(ProjectsCompanion(modifiedAt: Value(DateTime.now())));
  }
}
