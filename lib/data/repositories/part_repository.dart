import 'dart:math' as math;
import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import 'active_sheet.dart';
import '../db/watchers.dart';
import '../db/mappers.dart';

/// Where one pin sat in the netlist before its part was deleted.
class PinConnection {
  const PinConnection({
    required this.netId,
    required this.netName,
    required this.netCreatedAt,
  });

  final String netId;
  final String? netName;
  final DateTime netCreatedAt;
}

/// A part and its connectivity, captured so a delete can be undone.
class PartSnapshot {
  const PartSnapshot({required this.details, required this.connections});

  final PartWithDetails details;

  /// Pin id to the net it was on.
  final Map<String, PinConnection> connections;

  @override
  String toString() =>
      'PartSnapshot(${details.part.reference}, '
      '${connections.length} connections)';
}

/// Thrown when a reference designator would collide with an existing part.
class DuplicateReferenceException implements Exception {
  const DuplicateReferenceException(this.reference);

  final String reference;

  @override
  String toString() =>
      'DuplicateReferenceException: "$reference" is already used in this '
      'project';
}

/// Parts, their units and their pins.
class PartRepository {
  PartRepository(this._db);

  final AppDatabase _db;

  Stream<List<Part>> watchParts(String projectId) {
    final query = _db.select(_db.parts)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  /// Parts with their units and pins loaded.
  ///
  /// Re-reads whenever any of the three underlying tables changes. Designs
  /// on a phone are small enough that a full reload is cheaper than keeping
  /// three joined streams in sync.
  Stream<List<PartWithDetails>> watchPartsWithDetails(String projectId) {
    return _db.watchAggregate({
      _db.parts,
      _db.partUnits,
      _db.partPins,
    }, () => getPartsWithDetails(projectId));
  }

  Future<List<PartWithDetails>> getPartsWithDetails(String projectId) async {
    final partRows =
        await (_db.select(_db.parts)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (partRows.isEmpty) return const [];

    final ids = partRows.map((p) => p.id).toList();
    final unitRows =
        await (_db.select(_db.partUnits)
              ..where((t) => t.partId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.unitNumber)]))
            .get();
    final pinRows = await (_db.select(
      _db.partPins,
    )..where((t) => t.partId.isIn(ids))).get();

    final unitsByPart = <String, List<PartUnit>>{};
    for (final row in unitRows) {
      (unitsByPart[row.partId] ??= []).add(row.toDomain());
    }
    final pinsByPart = <String, List<PartPin>>{};
    for (final row in pinRows) {
      (pinsByPart[row.partId] ??= []).add(row.toDomain());
    }
    for (final pins in pinsByPart.values) {
      pins.sort(_comparePins);
    }

    return [
      for (final row in partRows)
        PartWithDetails(
          part: row.toDomain(),
          units: unitsByPart[row.id] ?? const [],
          pins: pinsByPart[row.id] ?? const [],
        ),
    ];
  }

  Future<PartWithDetails?> getPartWithDetails(String partId) async {
    final partRow = await (_db.select(
      _db.parts,
    )..where((t) => t.id.equals(partId))).getSingleOrNull();
    if (partRow == null) return null;

    final unitRows =
        await (_db.select(_db.partUnits)
              ..where((t) => t.partId.equals(partId))
              ..orderBy([(t) => OrderingTerm.asc(t.unitNumber)]))
            .get();
    final pinRows = await (_db.select(
      _db.partPins,
    )..where((t) => t.partId.equals(partId))).get();
    final pins = pinRows.map((r) => r.toDomain()).toList()..sort(_comparePins);

    return PartWithDetails(
      part: partRow.toDomain(),
      units: unitRows.map((r) => r.toDomain()).toList(),
      pins: pins,
    );
  }

  Future<List<PartPin>> getPins(String partId) async {
    final rows = await (_db.select(
      _db.partPins,
    )..where((t) => t.partId.equals(partId))).get();
    return rows.map((r) => r.toDomain()).toList()..sort(_comparePins);
  }

  Future<PartPin?> getPin(String pinId) async {
    final row = await (_db.select(
      _db.partPins,
    )..where((t) => t.id.equals(pinId))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Adds a component to a project, creating its units and snapshotting its
  /// pins. Runs in a transaction so a designator is never half-allocated.
  Future<PartWithDetails> addPart(String projectId, NewPartSpec spec) async {
    return _db.transaction(() async {
      final reference =
          spec.reference ??
          await _nextReference(projectId, spec.referencePrefix);

      final existing =
          await (_db.select(_db.parts)..where(
                (t) =>
                    t.projectId.equals(projectId) &
                    t.reference.equals(reference),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw DuplicateReferenceException(reference);
      }

      final now = DateTime.now();
      final partId = newId();
      final unitCount = spec.unitCount < 1 ? 1 : spec.unitCount;

      await _db
          .into(_db.parts)
          .insert(
            PartsCompanion.insert(
              id: partId,
              projectId: projectId,
              libId: spec.libId,
              reference: reference,
              value: Value(spec.value),
              footprint: Value(spec.footprint),
              datasheet: Value(spec.datasheet),
              description: Value(spec.description),
              unitCount: Value(unitCount),
              inBom: Value(spec.inBom),
              onBoard: Value(spec.onBoard),
              createdAt: now,
            ),
          );

      // Units are given a position on the sheet as they are created, so a
      // part is visible on the canvas the moment it is added rather than
      // waiting somewhere off-sheet to be found.
      final sheetId = ActiveSheet.of(_db, projectId);
      final spots = await _freeSpots(projectId, sheetId, unitCount);

      await _db.batch((batch) {
        batch.insertAll(_db.partUnits, [
          for (var unit = 1; unit <= unitCount; unit++)
            PartUnitsCompanion.insert(
              id: newId(),
              partId: partId,
              unitNumber: unit,
              x: Value(spots[unit - 1].dx),
              y: Value(spots[unit - 1].dy),
              placed: const Value(true),
              sheetId: Value(sheetId),
            ),
        ]);
        batch.insertAll(_db.partPins, [
          for (final pin in spec.pins)
            PartPinsCompanion.insert(
              id: newId(),
              partId: partId,
              number: pin.number,
              electricalType: pin.electricalType,
              unit: Value(pin.unit),
              bodyStyle: Value(pin.bodyStyle),
              name: Value(pin.name),
              graphicStyle: Value(pin.graphicStyle),
              x: Value(pin.x),
              y: Value(pin.y),
              length: Value(pin.length),
              angle: Value(pin.angle),
              hidden: Value(pin.hidden),
            ),
        ]);
      });

      await _touchProject(projectId);
      final result = await getPartWithDetails(partId);
      return result!;
    });
  }

  Future<void> updatePart(Part part) async {
    await (_db.update(_db.parts)..where((t) => t.id.equals(part.id))).write(
      PartsCompanion(
        reference: Value(part.reference),
        value: Value(part.value),
        footprint: Value(part.footprint),
        datasheet: Value(part.datasheet),
        description: Value(part.description),
        inBom: Value(part.inBom),
        onBoard: Value(part.onBoard),
        dnp: Value(part.dnp),
        fieldsHidden: Value(part.fieldsHidden),
      ),
    );
    await _touchProject(part.projectId);
  }

  /// Numbers every part afresh, prefix by prefix, in reading order across
  /// the sheet — top row first, left to right — the way a finished
  /// schematic is annotated.
  ///
  /// Returns the new reference of every part that changed, keyed by part id,
  /// together with the old one, so the whole thing can be put back.
  Future<Map<String, (String, String)>> renumberReferences(
    String projectId,
  ) async {
    final all = await getPartsWithDetails(projectId);
    final byPrefix = <String, List<PartWithDetails>>{};
    for (final part in all) {
      final prefix = part.part.referencePrefix.isEmpty
          ? 'U'
          : part.part.referencePrefix;
      (byPrefix[prefix] ??= []).add(part);
    }

    final changes = <String, (String, String)>{};
    for (final entry in byPrefix.entries) {
      final ordered = [...entry.value]..sort(_readingOrder);
      // Power symbols keep KiCad's two-digit style: #PWR01, #PWR02.
      final width = entry.key.startsWith('#') ? 2 : 0;
      for (var i = 0; i < ordered.length; i++) {
        final next = '${entry.key}${'${i + 1}'.padLeft(width, '0')}';
        final part = ordered[i].part;
        if (part.reference != next) changes[part.id] = (part.reference, next);
      }
    }
    await applyReferences({
      for (final e in changes.entries) e.key: e.value.$2,
    }, projectId);
    return changes;
  }

  /// Sets references in one go, stepping through placeholders so two parts
  /// swapping numbers never collide on the unique designator.
  Future<void> applyReferences(
    Map<String, String> references,
    String projectId,
  ) async {
    if (references.isEmpty) return;
    await _db.transaction(() async {
      for (final id in references.keys) {
        await (_db.update(_db.parts)..where((t) => t.id.equals(id))).write(
          PartsCompanion(reference: Value('~renumber~$id')),
        );
      }
      for (final entry in references.entries) {
        await (_db.update(_db.parts)..where((t) => t.id.equals(entry.key)))
            .write(PartsCompanion(reference: Value(entry.value)));
      }
    });
    await _touchProject(projectId);
  }

  static int _readingOrder(PartWithDetails a, PartWithDetails b) {
    Offset at(PartWithDetails p) {
      final placed = p.units.where((u) => u.placed).toList();
      if (placed.isEmpty) return const Offset(1e9, 1e9);
      return Offset(placed.first.x, placed.first.y);
    }

    final pa = at(a);
    final pb = at(b);
    // Rows a couple of grid squares tall, so parts almost level read as one
    // row rather than being ordered by a fraction of a millimetre.
    final rowA = (pa.dy / 12.7).floor();
    final rowB = (pb.dy / 12.7).floor();
    if (rowA != rowB) return rowA.compareTo(rowB);
    return pa.dx.compareTo(pb.dx);
  }

  Future<void> updateUnitPlacement(PartUnit unit) async {
    var sheetId = unit.sheetId;
    if (unit.placed && sheetId == null) {
      // Put down for the first time: on the sheet open in the schematic.
      final row = await (_db.select(
        _db.partUnits,
      )..where((t) => t.id.equals(unit.id))).getSingleOrNull();
      if (row != null && !row.placed) {
        final part = await (_db.select(
          _db.parts,
        )..where((t) => t.id.equals(unit.partId))).getSingleOrNull();
        if (part != null) sheetId = ActiveSheet.of(_db, part.projectId);
      }
    }
    await (_db.update(_db.partUnits)..where((t) => t.id.equals(unit.id))).write(
      PartUnitsCompanion(
        x: Value(unit.x),
        y: Value(unit.y),
        rotation: Value(unit.rotation),
        mirrorX: Value(unit.mirrorX),
        mirrorY: Value(unit.mirrorY),
        placed: Value(unit.placed),
        bodyStyle: Value(unit.bodyStyle),
        sheetId: Value(sheetId),
      ),
    );
  }

  Future<void> setPinNoConnect(String pinId, bool noConnect) async {
    await (_db.update(_db.partPins)..where((t) => t.id.equals(pinId))).write(
      PartPinsCompanion(noConnect: Value(noConnect)),
    );
  }

  /// Everything needed to put a deleted part back, including which nets its
  /// pins were on.
  ///
  /// Deleting a part destroys connectivity as well as the part itself, and
  /// nothing else can reconstruct that afterwards — so anything offering an
  /// undo has to capture it first.
  Future<PartSnapshot?> capturePart(String partId) async {
    final details = await getPartWithDetails(partId);
    if (details == null) return null;

    final pinIds = [for (final pin in details.pins) pin.id];
    final nodes = await (_db.select(
      _db.netNodes,
    )..where((t) => t.partPinId.isIn(pinIds))).get();

    final connections = <String, PinConnection>{};
    for (final node in nodes) {
      final net = await (_db.select(
        _db.nets,
      )..where((t) => t.id.equals(node.netId))).getSingleOrNull();
      if (net == null) continue;
      connections[node.partPinId] = PinConnection(
        netId: net.id,
        netName: net.name,
        netCreatedAt: net.createdAt,
      );
    }

    return PartSnapshot(details: details, connections: connections);
  }

  /// Re-creates a part exactly as [snapshot] recorded it, reusing the
  /// original ids so its net memberships come back with it.
  Future<void> restorePart(PartSnapshot snapshot) async {
    final part = snapshot.details.part;
    await _db.transaction(() async {
      await _db
          .into(_db.parts)
          .insert(
            PartsCompanion.insert(
              id: part.id,
              projectId: part.projectId,
              libId: part.libId,
              reference: part.reference,
              value: Value(part.value),
              footprint: Value(part.footprint),
              datasheet: Value(part.datasheet),
              description: Value(part.description),
              unitCount: Value(part.unitCount),
              inBom: Value(part.inBom),
              onBoard: Value(part.onBoard),
              dnp: Value(part.dnp),
              fieldsHidden: Value(part.fieldsHidden),
              createdAt: part.createdAt,
            ),
            mode: InsertMode.insertOrReplace,
          );

      await _db.batch((batch) {
        batch.insertAll(_db.partUnits, [
          for (final unit in snapshot.details.units)
            PartUnitsCompanion.insert(
              id: unit.id,
              partId: unit.partId,
              unitNumber: unit.unitNumber,
              bodyStyle: Value(unit.bodyStyle),
              x: Value(unit.x),
              y: Value(unit.y),
              rotation: Value(unit.rotation),
              mirrorX: Value(unit.mirrorX),
              mirrorY: Value(unit.mirrorY),
              placed: Value(unit.placed),
              sheetId: Value(unit.sheetId),
            ),
        ], mode: InsertMode.insertOrReplace);
        batch.insertAll(_db.partPins, [
          for (final pin in snapshot.details.pins)
            PartPinsCompanion.insert(
              id: pin.id,
              partId: pin.partId,
              number: pin.number,
              electricalType: pin.electricalType,
              unit: Value(pin.unit),
              bodyStyle: Value(pin.bodyStyle),
              name: Value(pin.name),
              graphicStyle: Value(pin.graphicStyle),
              x: Value(pin.x),
              y: Value(pin.y),
              length: Value(pin.length),
              angle: Value(pin.angle),
              noConnect: Value(pin.noConnect),
              hidden: Value(pin.hidden),
            ),
        ], mode: InsertMode.insertOrReplace);
      });

      for (final entry in snapshot.connections.entries) {
        final connection = entry.value;
        // The net may have been tidied away when the part went; put it back
        // under its original id so anything else pointing at it still fits.
        await _db
            .into(_db.nets)
            .insert(
              NetsCompanion.insert(
                id: connection.netId,
                projectId: part.projectId,
                name: Value(connection.netName),
                createdAt: connection.netCreatedAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _db
            .into(_db.netNodes)
            .insert(
              NetNodesCompanion.insert(
                id: newId(),
                netId: connection.netId,
                partPinId: entry.key,
                createdAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
    await _touchProject(part.projectId);
  }

  /// Adds another part just like [partId], with the next free designator and
  /// no connections of its own.
  Future<PartWithDetails?> duplicatePart(
    String partId, {
    Offset offset = const Offset(12.7, 12.7),
  }) async {
    final original = await getPartWithDetails(partId);
    if (original == null) return null;

    final copy = await addPart(original.part.projectId, original.toSpec());
    await _placeLike(original, copy, offset);
    return getPartWithDetails(copy.part.id);
  }

  /// Adds a part from a copied spec, anchored at [at] on the sheet.
  Future<PartWithDetails> pastePart(
    String projectId,
    NewPartSpec spec, {
    Offset? at,
  }) async {
    final added = await addPart(projectId, spec);
    if (at == null) return added;

    // Keep the units' relative layout, moving the group so its first unit
    // lands where the user asked.
    final anchor = added.units.isEmpty
        ? Offset.zero
        : Offset(added.units.first.x, added.units.first.y);
    for (final unit in added.units) {
      await updateUnitPlacement(
        unit.copyWith(
          x: at.dx + (unit.x - anchor.dx),
          y: at.dy + (unit.y - anchor.dy),
          placed: true,
        ),
      );
    }
    return (await getPartWithDetails(added.part.id))!;
  }

  Future<void> _placeLike(
    PartWithDetails original,
    PartWithDetails copy,
    Offset offset,
  ) async {
    for (final unit in copy.units) {
      final source = original.units
          .where((u) => u.unitNumber == unit.unitNumber)
          .firstOrNull;
      if (source == null) continue;
      await updateUnitPlacement(
        unit.copyWith(
          x: source.x + offset.dx,
          y: source.y + offset.dy,
          rotation: source.rotation,
          mirrorX: source.mirrorX,
          mirrorY: source.mirrorY,
          placed: true,
        ),
      );
    }
  }

  /// Deletes a part. Units, pins and any net memberships those pins had go
  /// with it via cascade.
  Future<void> deletePart(String partId) async {
    final row = await (_db.select(
      _db.parts,
    )..where((t) => t.id.equals(partId))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.parts)..where((t) => t.id.equals(partId))).go();
    await _touchProject(row.projectId);
  }

  /// The next free designator for [prefix] in a project: `R1`, then `R2`.
  ///
  /// Gaps are filled only at the end — deleting `R2` of `R1, R2, R3` still
  /// yields `R4`, matching how KiCad annotates.
  Future<String> nextReference(String projectId, String prefix) =>
      _nextReference(projectId, prefix);

  Future<String> _nextReference(String projectId, String prefix) async {
    final normalized = prefix.trim().isEmpty ? 'U' : prefix.trim();
    final rows =
        await (_db.select(_db.parts)..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.reference.like('$normalized%'),
            ))
            .get();

    final pattern = RegExp('^${RegExp.escape(normalized)}([0-9]+)\$');
    var highest = 0;
    for (final row in rows) {
      final match = pattern.firstMatch(row.reference);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n > highest) highest = n;
    }
    return '$normalized${highest + 1}';
  }

  /// Layout of the automatic placement grid, in sheet millimetres. The
  /// step is a multiple of KiCad's 1.27 mm grid so placed symbols land on
  /// it, and wide enough that a typical symbol and its pin labels fit in a
  /// cell without overlapping its neighbour.
  static const _gridOriginMm = 25.4;
  static const _gridStepMm = 38.1;

  /// Room left round the edge of the sheet, so a symbol dropped in the last
  /// column is not half off the paper.
  static const _marginMm = 12.7;

  /// Where the next [count] units go: free spots on a grid that fits inside
  /// the sheet, on the sheet being drawn on.
  ///
  /// It used to be a fixed six-column grid counted from every unit in the
  /// project, which walked off the bottom of an A4 page at the thirty-first
  /// unit and off any page at all once a project had sub-sheets — so parts
  /// arrived somewhere off the paper and had to be found and dragged back.
  /// The grid is now sized to the paper, and a spot already occupied is
  /// skipped rather than landed on.
  Future<List<Offset>> _freeSpots(
    String projectId,
    String? sheetId,
    int count,
  ) async {
    final project = await (_db.select(
      _db.projects,
    )..where((t) => t.id.equals(projectId))).getSingleOrNull();
    final paper = project?.paper ?? PaperSize.a4;

    final query = _db.select(_db.partUnits).join([
      innerJoin(_db.parts, _db.parts.id.equalsExp(_db.partUnits.partId)),
    ])..where(_db.parts.projectId.equals(projectId));
    final taken = [
      for (final row in await query.get())
        if (row.readTable(_db.partUnits) case final unit
            when unit.placed && unit.sheetId == sheetId)
          Offset(unit.x, unit.y),
    ];

    // The last column's own position has to be a margin inside the paper,
    // not just its left edge: a symbol dropped at 292 mm on a 297 mm sheet
    // is off the page as surely as one dropped at 320.
    final columns = math.max(
      1,
      ((paper.widthMm - _marginMm - _gridOriginMm) / _gridStepMm).floor() + 1,
    );
    final rows = math.max(
      1,
      ((paper.heightMm - _marginMm - _gridOriginMm) / _gridStepMm).floor() + 1,
    );

    Offset spotAt(int slot) => Offset(
      _gridOriginMm + (slot % columns) * _gridStepMm,
      _gridOriginMm + ((slot ~/ columns) % rows) * _gridStepMm,
    );

    final out = <Offset>[];
    var slot = 0;
    while (out.length < count) {
      // Past the last row everything is occupied as far as this can tell;
      // wrapping and overlapping is still better than landing off the page,
      // where a part cannot be seen at all.
      if (slot >= columns * rows) {
        out.add(spotAt(out.length));
        continue;
      }
      final at = spotAt(slot++);
      final free =
          taken.every((p) => (p - at).distance > _gridStepMm / 2) &&
          out.every((p) => (p - at).distance > _gridStepMm / 2);
      if (free) out.add(at);
    }
    return out;
  }

  Future<void> _touchProject(String projectId) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
        .write(ProjectsCompanion(modifiedAt: Value(DateTime.now())));
  }

  /// Orders pins by unit, then numerically by pad number where possible so
  /// `2` sorts before `10`, falling back to string order for pads like `A3`.
  static int _comparePins(PartPin a, PartPin b) {
    if (a.unit != b.unit) return a.unit.compareTo(b.unit);
    final na = int.tryParse(a.number);
    final nb = int.tryParse(b.number);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.number.compareTo(b.number);
  }
}
