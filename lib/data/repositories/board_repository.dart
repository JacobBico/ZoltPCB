import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/pcb/pcb.dart';
import '../db/database.dart';
import '../db/watchers.dart';

/// The board side of a project: its outline, its rules, where the
/// footprints sit and what copper has been drawn.
///
/// Connectivity is deliberately absent. Nets belong to the schematic and the
/// board only refers to them — the same relationship the schematic's drawn
/// wires already have. A track is a claim about where copper goes, never
/// about what is connected to what.
class BoardRepository {
  BoardRepository(this._db);

  final AppDatabase _db;

  // --- the board itself ------------------------------------------------

  /// The project's board, created on first use.
  ///
  /// A project that never leaves the schematic never gets a row, so opening
  /// the board is what brings it into existence rather than creating a
  /// project doing so.
  Future<Board> ensureBoard(String projectId) async {
    final existing = await _boardRow(projectId);
    if (existing != null) return _toBoard(existing);

    final id = newId();
    await _db
        .into(_db.boards)
        .insert(
          BoardsCompanion.insert(
            id: id,
            projectId: projectId,
            modifiedAt: DateTime.now(),
          ),
        );
    return _toBoard((await _boardRow(projectId))!);
  }

  Future<Board?> getBoard(String projectId) async {
    final row = await _boardRow(projectId);
    return row == null ? null : _toBoard(row);
  }

  Stream<Board> watchBoard(String projectId) =>
      _db.watchAggregate({_db.boards}, () => ensureBoard(projectId));

  Future<void> updateBoard(Board board) async {
    await (_db.update(_db.boards)..where((t) => t.id.equals(board.id))).write(
      BoardsCompanion(
        outlineX: Value(board.outlineX),
        outlineY: Value(board.outlineY),
        outlineWidth: Value(board.outlineWidth),
        outlineHeight: Value(board.outlineHeight),
        outlineKind: Value(board.outlineKind.name),
        outlinePoints: Value(_encodePoints(board.outlinePoints)),
        trackWidth: Value(board.rules.trackWidth),
        clearance: Value(board.rules.clearance),
        viaDiameter: Value(board.rules.viaDiameter),
        viaDrill: Value(board.rules.viaDrill),
        trackWidths: Value(_encodeWidths(board.trackWidths)),
        viaSizes: Value(_encodeViaSizes(board.viaSizes)),
        gridMm: Value(board.gridMm),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  // --- footprint placement ---------------------------------------------

  Future<List<PlacedFootprintRef>> getFootprints(String projectId) async {
    final query = _db.select(_db.boardFootprints)
      ..where((t) => t.projectId.equals(projectId));
    return (await query.get()).map(_toFootprint).toList();
  }

  Stream<List<PlacedFootprintRef>> watchFootprints(String projectId) => _db
      .watchAggregate({_db.boardFootprints}, () => getFootprints(projectId));

  Future<PlacedFootprintRef?> footprintForPart(String partId) async {
    final row = await (_db.select(
      _db.boardFootprints,
    )..where((t) => t.partId.equals(partId))).getSingleOrNull();
    return row == null ? null : _toFootprint(row);
  }

  /// Gives a part a footprint, replacing whatever it had.
  ///
  /// The placement survives a change of footprint: swapping an 0805 for an
  /// 0603 late in a layout should not throw away the position that was
  /// chosen for it.
  Future<PlacedFootprintRef> assignFootprint({
    required String projectId,
    required String partId,
    required String libId,
  }) async {
    final existing = await footprintForPart(partId);
    if (existing != null) {
      await (_db.update(
        _db.boardFootprints,
      )..where((t) => t.id.equals(existing.id))).write(
        BoardFootprintsCompanion(libId: Value(libId)),
      );
      return existing.copyWith(libId: libId);
    }

    final id = newId();
    await _db
        .into(_db.boardFootprints)
        .insert(
          BoardFootprintsCompanion.insert(
            id: id,
            projectId: projectId,
            partId: partId,
            libId: libId,
          ),
        );
    return PlacedFootprintRef(
      id: id,
      projectId: projectId,
      partId: partId,
      libId: libId,
    );
  }

  Future<void> updatePlacement(PlacedFootprintRef footprint) async {
    await (_db.update(
      _db.boardFootprints,
    )..where((t) => t.id.equals(footprint.id))).write(
      BoardFootprintsCompanion(
        x: Value(footprint.x),
        y: Value(footprint.y),
        rotation: Value(footprint.rotation),
        flipped: Value(footprint.flipped),
        placed: Value(footprint.placed),
        labelX: Value(footprint.labelOffset?.dx),
        labelY: Value(footprint.labelOffset?.dy),
        labelSize: Value(footprint.labelSize),
        labelHidden: Value(footprint.labelHidden),
      ),
    );
  }

  Future<void> removeFootprint(String partId) async {
    await (_db.delete(
      _db.boardFootprints,
    )..where((t) => t.partId.equals(partId))).go();
  }

  // --- copper ----------------------------------------------------------

  Future<List<Track>> getTracks(String projectId) async {
    final query = _db.select(_db.boardTracks)
      ..where((t) => t.projectId.equals(projectId));
    return (await query.get()).map(_toTrack).toList();
  }

  Future<List<Via>> getVias(String projectId) async {
    final query = _db.select(_db.boardVias)
      ..where((t) => t.projectId.equals(projectId));
    return (await query.get()).map(_toVia).toList();
  }

  Stream<List<Track>> watchTracks(String projectId) =>
      _db.watchAggregate({_db.boardTracks}, () => getTracks(projectId));

  Stream<List<Via>> watchVias(String projectId) =>
      _db.watchAggregate({_db.boardVias}, () => getVias(projectId));

  /// Adds one segment. Returns its id so a route drawn as several segments
  /// can be taken back as a whole.
  Future<String> addTrack({
    required String projectId,
    required CopperLayer layer,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required double width,
    String? netId,
  }) async {
    final id = newId();
    await _db
        .into(_db.boardTracks)
        .insert(
          BoardTracksCompanion.insert(
            id: id,
            projectId: projectId,
            netId: Value(netId),
            layer: layer.layer.token,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            width: Value(width),
          ),
        );
    return id;
  }

  Future<String> addVia({
    required String projectId,
    required double x,
    required double y,
    required double diameter,
    required double drill,
    String? netId,
  }) async {
    final id = newId();
    await _db
        .into(_db.boardVias)
        .insert(
          BoardViasCompanion.insert(
            id: id,
            projectId: projectId,
            netId: Value(netId),
            x: x,
            y: y,
            diameter: Value(diameter),
            drill: Value(drill),
          ),
        );
    return id;
  }

  /// Writes a segment's own numbers back.
  Future<void> updateTrack(Track track) async {
    await (_db.update(_db.boardTracks)..where((t) => t.id.equals(track.id)))
        .write(
          BoardTracksCompanion(
            layer: Value(track.layer.layer.token),
            startX: Value(track.startX),
            startY: Value(track.startY),
            endX: Value(track.endX),
            endY: Value(track.endY),
            width: Value(track.width),
            netId: Value(track.netId),
          ),
        );
  }

  Future<void> updateVia(Via via) async {
    await (_db.update(_db.boardVias)..where((t) => t.id.equals(via.id))).write(
      BoardViasCompanion(
        x: Value(via.x),
        y: Value(via.y),
        diameter: Value(via.diameter),
        drill: Value(via.drill),
        netId: Value(via.netId),
      ),
    );
  }

  Future<void> deleteTracks(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (_db.delete(_db.boardTracks)..where((t) => t.id.isIn(list))).go();
  }

  Future<void> deleteVias(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (_db.delete(_db.boardVias)..where((t) => t.id.isIn(list))).go();
  }

  /// Rewrites the net of each listed track and via.
  ///
  /// A repair rather than an edit: it brings stored nets back into line
  /// with what the copper actually connects after the schematic changed
  /// underneath it. Not something anyone would want to undo.
  Future<void> setCopperNets({
    Map<String, String?> tracks = const {},
    Map<String, String?> vias = const {},
  }) async {
    if (tracks.isEmpty && vias.isEmpty) return;
    await _db.transaction(() async {
      for (final entry in tracks.entries) {
        await (_db.update(_db.boardTracks)
              ..where((t) => t.id.equals(entry.key)))
            .write(BoardTracksCompanion(netId: Value(entry.value)));
      }
      for (final entry in vias.entries) {
        await (_db.update(_db.boardVias)
              ..where((t) => t.id.equals(entry.key)))
            .write(BoardViasCompanion(netId: Value(entry.value)));
      }
    });
  }

  /// Rips up every track and via on one net.
  Future<void> ripUpNet(String projectId, String netId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.boardTracks)..where(
            (t) => t.projectId.equals(projectId) & t.netId.equals(netId),
          ))
          .go();
      await (_db.delete(_db.boardVias)..where(
            (t) => t.projectId.equals(projectId) & t.netId.equals(netId),
          ))
          .go();
    });
  }

  /// Puts back a set of tracks and vias exactly as they were, ids included,
  /// so ripping up a net can be undone.
  Future<void> restoreCopper({
    required List<Track> tracks,
    required List<Via> vias,
  }) async {
    if (tracks.isEmpty && vias.isEmpty) return;
    await _db.batch((batch) {
      for (final track in tracks) {
        batch.insert(
          _db.boardTracks,
          BoardTracksCompanion.insert(
            id: track.id,
            projectId: track.projectId,
            netId: Value(track.netId),
            layer: track.layer.layer.token,
            startX: track.startX,
            startY: track.startY,
            endX: track.endX,
            endY: track.endY,
            width: Value(track.width),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final via in vias) {
        batch.insert(
          _db.boardVias,
          BoardViasCompanion.insert(
            id: via.id,
            projectId: via.projectId,
            netId: Value(via.netId),
            x: via.x,
            y: via.y,
            diameter: Value(via.diameter),
            drill: Value(via.drill),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<BoardRow?> _boardRow(String projectId) => (_db.select(
    _db.boards,
  )..where((t) => t.projectId.equals(projectId))).getSingleOrNull();

  // --- edge cuts -------------------------------------------------------

  Future<List<BoardEdge>> getEdges(String projectId) async {
    final query = _db.select(_db.boardEdges)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return (await query.get()).map(_toEdge).toList();
  }

  Stream<List<BoardEdge>> watchEdges(String projectId) =>
      _db.watchAggregate({_db.boardEdges}, () => getEdges(projectId));

  Future<BoardEdge> addEdge({
    required String projectId,
    required BoardEdgeKind kind,
    required List<Offset> points,
    double width = 0.1,
  }) async {
    final id = newId();
    await _db
        .into(_db.boardEdges)
        .insert(
          BoardEdgesCompanion.insert(
            id: id,
            projectId: projectId,
            kind: kind.name,
            points: Value(_encodePoints(points)),
            width: Value(width),
            createdAt: DateTime.now(),
          ),
        );
    return BoardEdge(
      id: id,
      projectId: projectId,
      kind: kind,
      points: points,
      width: width,
    );
  }

  Future<void> updateEdge(BoardEdge edge) async {
    await (_db.update(_db.boardEdges)..where((t) => t.id.equals(edge.id)))
        .write(
          BoardEdgesCompanion(
            kind: Value(edge.kind.name),
            points: Value(_encodePoints(edge.points)),
            width: Value(edge.width),
          ),
        );
  }

  Future<void> deleteEdge(String id) async {
    await (_db.delete(_db.boardEdges)..where((t) => t.id.equals(id))).go();
  }

  /// Puts a deleted edge back exactly as it was, for undo.
  Future<void> restoreEdge(BoardEdge edge) async {
    await _db
        .into(_db.boardEdges)
        .insert(
          BoardEdgesCompanion.insert(
            id: edge.id,
            projectId: edge.projectId,
            kind: edge.kind.name,
            points: Value(_encodePoints(edge.points)),
            width: Value(edge.width),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  // --- silkscreen text -------------------------------------------------

  Future<List<BoardText>> getTexts(String projectId) async {
    final query = _db.select(_db.boardTexts)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return (await query.get()).map(_toText).toList();
  }

  Stream<List<BoardText>> watchTexts(String projectId) =>
      _db.watchAggregate({_db.boardTexts}, () => getTexts(projectId));

  Future<BoardText> addText({
    required String projectId,
    required String content,
    required Offset position,
    double rotation = 0,
    double size = 1.0,
    bool back = false,
  }) async {
    final text = BoardText(
      id: newId(),
      projectId: projectId,
      content: content,
      position: position,
      rotation: rotation,
      size: size,
      back: back,
    );
    await restoreText(text);
    return text;
  }

  Future<void> updateText(BoardText text) async {
    await (_db.update(_db.boardTexts)..where((t) => t.id.equals(text.id)))
        .write(
          BoardTextsCompanion(
            content: Value(text.content),
            x: Value(text.position.dx),
            y: Value(text.position.dy),
            rotation: Value(text.rotation),
            size: Value(text.size),
            layer: Value(text.layer.token),
          ),
        );
  }

  Future<void> deleteText(String id) async {
    await (_db.delete(_db.boardTexts)..where((t) => t.id.equals(id))).go();
  }

  /// Writes a text exactly as given, for adding one and for undoing its
  /// deletion alike.
  Future<void> restoreText(BoardText text) async {
    await _db
        .into(_db.boardTexts)
        .insert(
          BoardTextsCompanion.insert(
            id: text.id,
            projectId: text.projectId,
            content: text.content,
            x: text.position.dx,
            y: text.position.dy,
            rotation: Value(text.rotation),
            size: Value(text.size),
            layer: text.layer.token,
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  static BoardText _toText(BoardTextRow row) => BoardText(
    id: row.id,
    projectId: row.projectId,
    content: row.content,
    position: Offset(row.x, row.y),
    rotation: row.rotation,
    size: row.size,
    back: row.layer == BoardLayer.backSilk.token,
  );

  // --- copper pours ----------------------------------------------------

  Future<List<BoardZone>> getZones(String projectId) async {
    final query = _db.select(_db.boardZones)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return (await query.get()).map(_toZone).toList();
  }

  Stream<List<BoardZone>> watchZones(String projectId) =>
      _db.watchAggregate({_db.boardZones}, () => getZones(projectId));

  Future<BoardZone> addZone({
    required String projectId,
    required BoardLayer layer,
    required List<Offset> points,
    String? netId,
    String netName = '',
    double clearance = 0.5,
    double minThickness = 0.25,
  }) async {
    final id = newId();
    await _db
        .into(_db.boardZones)
        .insert(
          BoardZonesCompanion.insert(
            id: id,
            projectId: projectId,
            layer: layer.token,
            netId: Value(netId),
            netName: Value(netName),
            points: Value(_encodePoints(points)),
            clearance: Value(clearance),
            minThickness: Value(minThickness),
            createdAt: DateTime.now(),
          ),
        );
    return BoardZone(
      id: id,
      projectId: projectId,
      layer: layer,
      points: points,
      netId: netId,
      netName: netName,
      clearance: clearance,
      minThickness: minThickness,
    );
  }

  Future<void> updateZone(BoardZone zone) async {
    await (_db.update(_db.boardZones)..where((t) => t.id.equals(zone.id)))
        .write(
          BoardZonesCompanion(
            layer: Value(zone.layer.token),
            netId: Value(zone.netId),
            netName: Value(zone.netName),
            points: Value(_encodePoints(zone.points)),
            clearance: Value(zone.clearance),
            minThickness: Value(zone.minThickness),
          ),
        );
  }

  Future<void> deleteZone(String id) async {
    await (_db.delete(_db.boardZones)..where((t) => t.id.equals(id))).go();
  }

  Future<void> restoreZone(BoardZone zone) async {
    await _db
        .into(_db.boardZones)
        .insert(
          BoardZonesCompanion.insert(
            id: zone.id,
            projectId: zone.projectId,
            layer: zone.layer.token,
            netId: Value(zone.netId),
            netName: Value(zone.netName),
            points: Value(_encodePoints(zone.points)),
            clearance: Value(zone.clearance),
            minThickness: Value(zone.minThickness),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  static BoardEdge _toEdge(BoardEdgeRow row) => BoardEdge(
    id: row.id,
    projectId: row.projectId,
    kind: BoardEdgeKind.values.firstWhere(
      (kind) => kind.name == row.kind,
      orElse: () => BoardEdgeKind.line,
    ),
    points: _decodePoints(row.points),
    width: row.width,
  );

  static BoardZone _toZone(BoardZoneRow row) => BoardZone(
    id: row.id,
    projectId: row.projectId,
    layer: BoardLayer.fromToken(row.layer) ?? BoardLayer.frontCopper,
    points: _decodePoints(row.points),
    netId: row.netId,
    netName: row.netName,
    clearance: row.clearance,
    minThickness: row.minThickness,
  );

  /// Track widths as plain millimetres separated by spaces.
  static String _encodeWidths(List<double> widths) => widths.join(' ');

  static List<double> _decodeWidths(String encoded) => [
    for (final part in encoded.split(' ')) ?double.tryParse(part),
  ];

  /// Via sizes as `diameter/drill` pairs separated by spaces.
  static String _encodeViaSizes(List<ViaSize> sizes) =>
      sizes.map((s) => '${s.diameter}/${s.drill}').join(' ');

  static List<ViaSize> _decodeViaSizes(String encoded) {
    final sizes = <ViaSize>[];
    for (final pair in encoded.split(' ')) {
      final parts = pair.split('/');
      if (parts.length != 2) continue;
      final diameter = double.tryParse(parts[0]);
      final drill = double.tryParse(parts[1]);
      if (diameter == null || drill == null) continue;
      sizes.add(ViaSize(diameter, drill));
    }
    return sizes;
  }

  /// Polygon vertices as `x,y` pairs separated by spaces.
  ///
  /// Text rather than JSON for the same reason the schematic's route hints
  /// are: it is a short list of numbers, and a column anyone can read in a
  /// database browser is worth more than a nested structure here.
  static String _encodePoints(List<Offset> points) =>
      points.map((p) => '${p.dx},${p.dy}').join(' ');

  static List<Offset> _decodePoints(String encoded) {
    final points = <Offset>[];
    for (final pair in encoded.split(' ')) {
      if (pair.isEmpty) continue;
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      if (x == null || y == null) continue;
      points.add(Offset(x, y));
    }
    return points;
  }

  static Board _toBoard(BoardRow row) => Board(
    id: row.id,
    projectId: row.projectId,
    outlineX: row.outlineX,
    outlineY: row.outlineY,
    outlineWidth: row.outlineWidth,
    outlineHeight: row.outlineHeight,
    outlineKind: BoardOutlineKind.values.firstWhere(
      (kind) => kind.name == row.outlineKind,
      orElse: () => BoardOutlineKind.rectangle,
    ),
    outlinePoints: _decodePoints(row.outlinePoints),
    rules: DesignRules(
      trackWidth: row.trackWidth,
      clearance: row.clearance,
      viaDiameter: row.viaDiameter,
      viaDrill: row.viaDrill,
    ),
    trackWidths: _decodeWidths(row.trackWidths),
    viaSizes: _decodeViaSizes(row.viaSizes),
    gridMm: row.gridMm,
    modifiedAt: row.modifiedAt,
  );

  static PlacedFootprintRef _toFootprint(BoardFootprintRow row) =>
      PlacedFootprintRef(
        id: row.id,
        projectId: row.projectId,
        partId: row.partId,
        libId: row.libId,
        x: row.x,
        y: row.y,
        rotation: row.rotation,
        flipped: row.flipped,
        placed: row.placed,
        labelOffset: row.labelX == null || row.labelY == null
            ? null
            : Offset(row.labelX!, row.labelY!),
        labelSize: row.labelSize,
        labelHidden: row.labelHidden,
      );

  static Track _toTrack(BoardTrackRow row) => Track(
    id: row.id,
    projectId: row.projectId,
    netId: row.netId,
    layer: row.layer == BoardLayer.backCopper.token
        ? CopperLayer.back
        : CopperLayer.front,
    startX: row.startX,
    startY: row.startY,
    endX: row.endX,
    endY: row.endY,
    width: row.width,
  );

  static Via _toVia(BoardViaRow row) => Via(
    id: row.id,
    projectId: row.projectId,
    netId: row.netId,
    x: row.x,
    y: row.y,
    diameter: row.diameter,
    drill: row.drill,
  );
}
