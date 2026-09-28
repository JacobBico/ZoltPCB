import 'dart:math' as math;
import 'dart:ui';

import '../models/models.dart';
import 'board.dart';
import 'board_edge.dart';
import 'board_layer.dart';
import 'net_class.dart';
import 'board_outline.dart';
import 'board_feature.dart';
import 'board_image.dart';
import 'board_text.dart';
import 'board_zone.dart';
import 'pour_copper.dart';
import 'pour_fill.dart';
import 'footprint.dart';
import 'footprint_placement.dart';

/// One pad of one placed footprint, resolved to a position on the board.
class PlacedPad {
  const PlacedPad({
    required this.pad,
    required this.partId,
    required this.reference,
    required this.footprintId,
    required this.position,
    required this.angle,
    required this.layers,
    this.netId,
    this.netName,
  });

  final Pad pad;
  final String partId;
  final String reference;

  /// The [PlacedFootprintRef] this pad belongs to.
  final String footprintId;

  /// Centre of the pad, in board millimetres.
  final Offset position;

  /// The pad's own rotation on the board, in degrees.
  final double angle;

  /// The copper layers this pad reaches, after any flip.
  final List<BoardLayer> layers;

  final String? netId;
  final String? netName;

  /// `R1.2` — how the schematic already names this connection.
  String get label => '$reference.${pad.number}';

  /// A stable identity, since a pad has none of its own in the file.
  String get id => '$footprintId/${pad.number}/${pad.at.x}/${pad.at.y}';

  bool get isConnected => netId != null;

  bool reaches(CopperLayer layer) => layers.contains(layer.layer);

  /// Whether [point] falls on the pad's copper.
  ///
  /// Rectangular for every shape but the round ones, which is close enough
  /// for hit-testing a finger and exact enough for deciding whether a track
  /// endpoint has landed on a pad.
  bool contains(Offset point, {double toleranceMm = 0}) {
    final local = _toLocal(point);
    if (pad.shape == PadShape.circle) {
      return local.distance <= pad.sizeX / 2 + toleranceMm;
    }
    return local.dx.abs() <= pad.sizeX / 2 + toleranceMm &&
        local.dy.abs() <= pad.sizeY / 2 + toleranceMm;
  }

  /// Whether the run from [a] to [b] passes over the pad's copper — by the
  /// same shapes as [contains].
  bool crosses(Offset a, Offset b, {double toleranceMm = 0}) {
    if (pad.shape == PadShape.circle) {
      return distanceToSegment(position, a, b) <= pad.sizeX / 2 + toleranceMm;
    }
    // The part of the run inside the pad's box, in the pad's own frame.
    final from = _toLocal(a);
    final d = _toLocal(b) - from;
    final hx = pad.sizeX / 2 + toleranceMm;
    final hy = pad.sizeY / 2 + toleranceMm;
    var enter = 0.0;
    var leave = 1.0;
    for (final (p, q) in [
      (-d.dx, from.dx + hx),
      (d.dx, hx - from.dx),
      (-d.dy, from.dy + hy),
      (d.dy, hy - from.dy),
    ]) {
      if (p == 0) {
        if (q < 0) return false;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        if (t > leave) return false;
        if (t > enter) enter = t;
      } else {
        if (t < enter) return false;
        if (t < leave) leave = t;
      }
    }
    return true;
  }

  Offset _toLocal(Offset point) {
    final d = point - position;
    final radians = -angle * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(d.dx * cos + d.dy * sin, -d.dx * sin + d.dy * cos);
  }
}

/// One footprint, positioned and ready to draw.
class PlacedFootprint {
  const PlacedFootprint({
    required this.ref,
    required this.part,
    required this.placement,
    required this.pads,
    this.definition,
  });

  final PlacedFootprintRef ref;
  final Part part;
  final FootprintPlacement placement;
  final List<PlacedPad> pads;

  /// Null when the footprint's library is no longer installed. Pads are
  /// then absent too — unlike a symbol, a footprint has nothing to fall
  /// back on, because the project never snapshotted one.
  final FootprintDefinition? definition;

  bool get isResolved => definition != null;

  /// Where the reference designator is drawn, in board millimetres.
  ///
  /// Where the user put it when they have moved it — stored in the part's
  /// own frame so it rotates and flips with the part — and otherwise just
  /// above the body, clear of the pads. Shared by the painter and by
  /// hit-testing, so a label is picked up exactly where it is drawn.
  Offset get labelPosition {
    final offset = ref.labelOffset;
    if (offset != null) return placement.apply(offset.dx, offset.dy);
    final box = bounds;
    return Offset(box.center.dx, box.top - ref.labelSize * 0.9);
  }

  /// The footprint's extent on the board.
  Rect get bounds {
    final definition = this.definition;
    if (definition == null) {
      return Rect.fromCenter(center: Offset(ref.x, ref.y), width: 2, height: 2);
    }
    final local = footprintBounds(definition);
    if (local == Rect.zero) {
      return Rect.fromCenter(center: Offset(ref.x, ref.y), width: 2, height: 2);
    }
    var rect = Rect.fromPoints(
      placement.apply(local.left, local.top),
      placement.apply(local.right, local.top),
    );
    for (final corner in [
      placement.apply(local.right, local.bottom),
      placement.apply(local.left, local.bottom),
    ]) {
      rect = rect.expandToInclude(Rect.fromLTWH(corner.dx, corner.dy, 0, 0));
    }
    return rect;
  }
}

/// One line of the ratsnest: a connection the netlist demands and the copper
/// has not yet made.
class RatsnestLine {
  const RatsnestLine({
    required this.netId,
    required this.netName,
    required this.from,
    required this.to,
  });

  final String netId;
  final String netName;
  final Offset from;
  final Offset to;

  double get lengthMm => (to - from).distance;
}

/// Everything the board canvas needs for one frame.
///
/// Built the same way the schematic's scene is, and for the same reason:
/// hit-testing and drawing work from one set of numbers, so a pad is
/// touchable exactly where it is drawn.
class BoardScene {
  const BoardScene({
    required this.board,
    required this.footprints,
    required this.pads,
    required this.tracks,
    required this.vias,
    required this.ratsnest,
    required this.unplaced,
    this.edges = const [],
    this.zones = const [],
    this.texts = const [],
    this.images = const [],
    this.staleTrackIds = const {},
    this.staleViaIds = const {},
    this.netClasses = const [],
    this.netClassByNet = const {},
    this.features = const [],
    this.dimensions = const [],
    this.pourJoins = const [],
    this.previewOf,
  });

  /// What the pours join, on every layer — the part of [ratsnest]'s
  /// working that is costly, kept so a preview can borrow it.
  final List<PourJoin> pourJoins;

  /// For a scene drawn for a moment while something is dragged, the board
  /// as saved. A preview's pours borrow the saved board's islands rather
  /// than finding their own, and its ratsnest counts the saved board's
  /// pour connections: a drag redraws every frame, and neither is worth
  /// working out that often.
  final BoardScene? previewOf;

  bool get isPreview => previewOf != null;

  /// Mounting holes, fiducials and test points, placed or not. The placed
  /// ones are also in [footprints], as the footprints they stand for.
  final List<BoardFeature> features;

  /// Measurements drawn on the board.
  final List<BoardDimension> dimensions;

  /// The feature behind a footprint id, or null for a part's footprint.
  BoardFeature? featureOf(String footprintId) {
    if (!BoardFeature.isFeatureId(footprintId)) return null;
    final id = BoardFeature.featureIdOf(footprintId);
    return features.where((f) => f.id == id).firstOrNull;
  }

  /// The project's net classes, and the class each net routes with.
  final List<NetClass> netClasses;
  final Map<String, NetClass> netClassByNet;

  NetClass? classOf(String? netId) =>
      netId == null ? null : netClassByNet[netId];

  /// The width a new track on [netId] is drawn at on [layer]: its class's,
  /// worked out from the stackup if the class is an impedance, or the
  /// design rule.
  double trackWidthFor(String? netId, CopperLayer layer) =>
      classOf(netId)?.widthOn(board.stackup, layer) ?? board.rules.trackWidth;

  /// The gap copper on [netId] needs from other nets: the design rule, or
  /// the net's class clearance where that is wider.
  double clearanceFor(String? netId) {
    final own = classOf(netId)?.clearance ?? 0;
    return own > board.rules.clearance ? own : board.rules.clearance;
  }

  static BoardScene build({
    required Board board,
    required List<PartWithDetails> parts,
    required List<NetWithEndpoints> nets,
    required List<PlacedFootprintRef> placements,
    required Map<String, FootprintDefinition> definitions,
    List<Track> tracks = const [],
    List<Via> vias = const [],
    List<BoardEdge> edges = const [],
    List<BoardZone> zones = const [],
    List<BoardText> texts = const [],
    List<BoardImage> images = const [],
    List<NetClass> netClasses = const [],
    List<BoardFeature> features = const [],
    List<BoardDimension> dimensions = const [],
    BoardScene? previewOf,
  }) {
    final partsById = {for (final part in parts) part.part.id: part};

    // A pad connects to a net through the schematic pin that carries the
    // same number. That mapping is the whole bridge between the two halves
    // of the app, and it is the reason pad numbers are strings.
    final netByPin = <String, NetWithEndpoints>{
      for (final net in nets)
        for (final endpoint in net.endpoints) endpoint.pin.id: net,
    };

    final placed = <PlacedFootprint>[];
    final allPads = <PlacedPad>[];
    final unplaced = <PlacedFootprintRef>[];

    for (final ref in placements) {
      final part = partsById[ref.partId];
      if (part == null) continue;
      if (!ref.placed) {
        unplaced.add(ref);
        continue;
      }

      final definition = definitions[ref.libId];
      final placement = FootprintPlacement.of(ref);
      final pads = <PlacedPad>[];

      if (definition != null) {
        // Pin numbers repeat legally on a symbol, and a pad number can
        // repeat on a footprint too. Matching on the number rather than on
        // identity is what KiCad does, and it is what makes a ground pad
        // shared by three pins land on one net.
        final netForNumber = <String, NetWithEndpoints>{};
        for (final pin in part.pins) {
          final net = netByPin[pin.id];
          if (net != null) netForNumber.putIfAbsent(pin.number, () => net);
        }

        for (final pad in definition.pads) {
          final net = pad.isConnectable ? netForNumber[pad.number] : null;
          pads.add(
            PlacedPad(
              pad: pad,
              partId: part.part.id,
              reference: part.part.reference,
              footprintId: ref.id,
              position: placement.applyPoint(pad.at),
              angle: placement.padAngle(pad.angle),
              layers: [
                for (final layer in pad.layers) placement.layerOf(layer)!,
              ],
              netId: net?.net.id,
              netName: net?.displayName,
            ),
          );
        }
      }

      placed.add(
        PlacedFootprint(
          ref: ref,
          part: part.part,
          placement: placement,
          pads: pads,
          definition: definition,
        ),
      );
      allPads.addAll(pads);
    }

    // Mounting holes, fiducials and test points, as footprints of their
    // own. A feature's net is found by id, or by name when the schematic
    // has been reshuffled underneath it since.
    for (final feature in features) {
      if (!feature.placed) continue;
      final net = !feature.hasNet
          ? null
          : nets.where((n) => n.net.id == feature.netId).firstOrNull ??
                (feature.netName.isEmpty
                    ? null
                    : nets
                          .where((n) => n.displayName == feature.netName)
                          .firstOrNull);
      final ref = feature.ref;
      final definition = feature.definition;
      final placement = FootprintPlacement.of(ref);
      final pads = [
        for (final pad in definition.pads)
          PlacedPad(
            pad: pad,
            partId: ref.partId,
            reference: feature.reference,
            footprintId: ref.id,
            position: placement.applyPoint(pad.at),
            angle: placement.padAngle(pad.angle),
            layers: [for (final layer in pad.layers) placement.layerOf(layer)!],
            netId: pad.isConnectable ? net?.net.id : null,
            netName: pad.isConnectable ? net?.displayName : null,
          ),
      ];
      placed.add(
        PlacedFootprint(
          ref: ref,
          part: feature.part,
          placement: placement,
          pads: pads,
          definition: definition,
        ),
      );
      allPads.addAll(pads);
    }

    // What net each piece of copper is really on, decided by what it
    // touches rather than by the id it was drawn with. Net ids do not
    // survive the schematic changing underneath the board: merging two nets
    // deletes one, and undoing the merge recreates both under new ids, so a
    // stored id is a hint about intent, not a fact about connectivity.
    final resolved = _resolveCopperNets(allPads, tracks, vias);

    final classById = {for (final c in netClasses) c.id: c};
    final netClassByNet = <String, NetClass>{
      for (final net in nets) net.net.id: ?classById[net.net.netClassId],
    };

    BoardScene withRatsnest(
      List<RatsnestLine> ratsnest, [
      List<PourJoin> joins = const [],
    ]) => BoardScene(
      pourJoins: joins,
      previewOf: previewOf?.previewOf ?? previewOf,
      board: board,
      footprints: placed,
      pads: allPads,
      tracks: resolved.tracks,
      vias: resolved.vias,
      ratsnest: ratsnest,
      unplaced: unplaced,
      edges: edges,
      zones: zones,
      texts: texts,
      images: images,
      netClasses: netClasses,
      netClassByNet: netClassByNet,
      features: features,
      dimensions: dimensions,
      staleTrackIds: resolved.staleTracks,
      staleViaIds: resolved.staleVias,
    );

    if (!zones.any((z) => z.isValid && !z.keepout)) {
      return withRatsnest(_ratsnest(allPads, resolved.tracks, resolved.vias));
    }
    if (previewOf != null) {
      final joins = previewOf.pourJoins;
      return withRatsnest(
        _ratsnest(allPads, resolved.tracks, resolved.vias, joins),
        joins,
      );
    }

    // A pour is routing too: whatever one piece of its fill touches is
    // joined. The fill depends on everything but the ratsnest, so it is
    // worked out on the scene without one and handed on.
    final unrouted = withRatsnest(const []);
    final joins = [
      for (final layer in board.copperLayers)
        ...PourFill.plan(unrouted, layer).joins,
    ];
    final scene = withRatsnest(
      _ratsnest(allPads, resolved.tracks, resolved.vias, joins),
      joins,
    );
    PourFill.carry(unrouted, scene);
    return scene;
  }

  final Board board;

  /// Extra shapes on Edge.Cuts, beyond the board outline.
  final List<BoardEdge> edges;

  /// Copper pours, drawn under the tracks and exported as zone outlines.
  final List<BoardZone> zones;

  /// Free text on the silkscreen, front and back.
  final List<BoardText> texts;

  /// Pictures printed in the silkscreen.
  final List<BoardImage> images;

  final List<PlacedFootprint> footprints;
  final List<PlacedPad> pads;
  final List<Track> tracks;
  final List<Via> vias;

  /// What is still unrouted. Empty means the board is done.
  final List<RatsnestLine> ratsnest;

  /// Footprints assigned to a part but not yet put anywhere.
  final List<PlacedFootprintRef> unplaced;

  /// Copper whose stored net no longer matches what it connects, and whose
  /// net [tracks] and [vias] have already been corrected for. Kept so the
  /// board can write the correction back, making storage — and so the
  /// exported file — agree with what is drawn.
  final Set<String> staleTrackIds;
  final Set<String> staleViaIds;

  bool get hasStaleCopper => staleTrackIds.isNotEmpty || staleViaIds.isNotEmpty;

  /// Copper on no net at all: drawn for a connection the schematic no
  /// longer has.
  List<Track> get orphanTracks => [
    for (final track in tracks)
      if (track.netId == null) track,
  ];

  /// The board edge — a rectangle, a circle or a polygon.
  BoardOutline get outline => board.outline;

  /// The box the edge fits inside, for framing the view.
  Rect get outlineBounds => outline.bounds;

  bool get isEmpty => footprints.isEmpty;

  bool get isFullyRouted => ratsnest.isEmpty;

  /// Nets that still have at least one unrouted connection.
  Set<String> get unroutedNetIds => {for (final line in ratsnest) line.netId};

  /// The pad nearest [point] within [toleranceMm], on [layer] if given.
  PlacedPad? padNear(Offset point, double toleranceMm, {CopperLayer? layer}) {
    PlacedPad? best;
    var bestDistance = double.infinity;
    for (final pad in pads) {
      if (layer != null && !pad.reaches(layer)) continue;
      final distance = (pad.position - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = pad;
      }
    }
    if (best == null) return null;
    // Landing anywhere on the copper counts, however large the pad.
    if (best.contains(point, toleranceMm: toleranceMm)) return best;
    return bestDistance <= toleranceMm ? best : null;
  }

  /// The footprint under [point], topmost first.
  PlacedFootprint? footprintAt(Offset point, {double paddingMm = 0.5}) {
    for (final footprint in footprints.reversed) {
      if (footprint.bounds.inflate(paddingMm).contains(point)) return footprint;
    }
    return null;
  }

  /// The track nearest [point], within [toleranceMm], on [layer].
  Track? trackNear(Offset point, double toleranceMm, {CopperLayer? layer}) {
    Track? best;
    var bestDistance = double.infinity;
    for (final track in tracks) {
      if (layer != null && track.layer != layer) continue;
      final distance = distanceToSegment(
        point,
        Offset(track.startX, track.startY),
        Offset(track.endX, track.endY),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = track;
      }
    }
    return bestDistance <= toleranceMm ? best : null;
  }

  /// Everything a project still owes: what is not placed, and what is not
  /// routed. The board's own to-do list.
  Rect get contentBounds {
    var rect = outlineBounds;
    for (final footprint in footprints) {
      rect = rect.expandToInclude(footprint.bounds);
    }
    return rect.inflate(5);
  }

  // --- ratsnest --------------------------------------------------------

  /// How close copper has to come to a pad or to other copper to count as
  /// joined, in millimetres. Tracks are drawn to snapped coordinates, so
  /// this only has to absorb floating-point noise.
  static const _touchMm = 0.001;

  /// The connections a net still needs, given the copper already drawn.
  ///
  /// This is the feedback loop routing runs on: draw a track and the line it
  /// satisfies disappears. Computing it from the copper rather than from a
  /// "routed" flag means it stays honest when a track is deleted, moved, or
  /// drawn to the wrong place.
  static List<RatsnestLine> _ratsnest(
    List<PlacedPad> pads,
    List<Track> tracks,
    List<Via> vias, [
    List<PourJoin> joins = const [],
  ]) {
    final byNet = <String, List<PlacedPad>>{};
    for (final pad in pads) {
      final netId = pad.netId;
      if (netId == null) continue;
      (byNet[netId] ??= []).add(pad);
    }

    // Each net's own copper, gathered once: going through every track on
    // the board for every net is what made a large board slow to redraw.
    final tracksByNet = <String, List<Track>>{};
    for (final track in tracks) {
      if (track.netId case final netId?) {
        (tracksByNet[netId] ??= []).add(track);
      }
    }
    final viasByNet = <String, List<Via>>{};
    for (final via in vias) {
      if (via.netId case final netId?) (viasByNet[netId] ??= []).add(via);
    }

    final lines = <RatsnestLine>[];
    for (final entry in byNet.entries) {
      final netPads = entry.value;
      if (netPads.length < 2) continue;

      final groups = _copperGroups(
        netPads,
        tracksByNet[entry.key] ?? const [],
        viasByNet[entry.key] ?? const [],
        entry.key,
        [
          for (final join in joins)
            if (join.netId == entry.key) join,
        ],
      );

      // One group means the net is fully routed and owes nothing. Otherwise
      // the tree is built between groups, so a half-routed net shows only
      // the hops it still needs rather than starting again from scratch.
      for (final edge in _spanningTree(groups)) {
        final (from, to) = _closestPair(groups[edge.$1], groups[edge.$2]);
        lines.add(
          RatsnestLine(
            netId: entry.key,
            netName: from.netName ?? '',
            from: from.position,
            to: to.position,
          ),
        );
      }
    }
    return lines;
  }

  /// Groups a net's pads by what the drawn copper already joins.
  ///
  /// Copper is treated as a graph of nodes: one per pad, and one per
  /// distinct point-on-a-layer that a track ends at. A track joins its own
  /// two ends; two tracks meeting at a point share the node for it; a via
  /// joins the two layers at its own point; and a track ending inside a pad
  /// joins that pad. Whatever ends up in one component is one piece of
  /// copper.
  static List<List<PlacedPad>> _copperGroups(
    List<PlacedPad> pads,
    List<Track> tracks,
    List<Via> vias,
    String netId, [
    List<PourJoin> joins = const [],
  ]) {
    final parent = <String, String>{};

    String find(String node) {
      var root = parent.putIfAbsent(node, () => node);
      while (parent[root] != root) {
        root = parent[root]!;
      }
      var current = node;
      while (parent[current] != root) {
        final next = parent[current]!;
        parent[current] = root;
        current = next;
      }
      return root;
    }

    void union(String a, String b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parent[rootA] = rootB;
    }

    /// A point on a layer, quantised so that two tracks drawn to the same
    /// place share one node rather than missing each other by a rounding.
    String pointNode(Offset point, CopperLayer layer) {
      final x = (point.dx / _touchMm).round();
      final y = (point.dy / _touchMm).round();
      return '${layer.name}@$x,$y';
    }

    String padNode(int index) => 'pad:$index';

    /// Joins a point to any pad whose copper covers it.
    final near = _PadIndex(pads);
    void bindToPads(Offset point, CopperLayer layer) {
      for (final i in near.at(point)) {
        final pad = pads[i];
        if (!pad.reaches(layer)) continue;
        if (pad.contains(point, toleranceMm: _touchMm)) {
          union(pointNode(point, layer), padNode(i));
        }
      }
    }

    for (var i = 0; i < pads.length; i++) {
      find(padNode(i));
    }

    final own = [
      for (final track in tracks)
        if (track.netId == netId) track,
    ];
    final ownVias = [
      for (final via in vias)
        if (via.netId == netId) via,
    ];
    String startOf(Track track) =>
        pointNode(Offset(track.startX, track.startY), track.layer);

    for (final track in own) {
      union(
        startOf(track),
        pointNode(Offset(track.endX, track.endY), track.layer),
      );
    }

    for (final via in ownVias) {
      final at = Offset(via.x, via.y);
      // A via is a plated hole through every layer: it joins all of them
      // at its own point. Layers the board does not have carry no copper,
      // so joining them too costs nothing.
      for (final layer in CopperLayer.values) {
        union(pointNode(at, CopperLayer.front), pointNode(at, layer));
        bindToPads(at, layer);
      }
    }

    _contacts(
      pads,
      own,
      ownVias,
      onPad: (t, p) => union(startOf(own[t]), padNode(p)),
      onTrack: (t, o) => union(startOf(own[t]), startOf(own[o])),
      onVia: (t, v) => union(
        startOf(own[t]),
        pointNode(Offset(ownVias[v].x, ownVias[v].y), CopperLayer.front),
      ),
    );

    // A piece of pour joins everything it touches.
    final padIndex = joins.isEmpty
        ? const <String, int>{}
        : {for (var i = pads.length - 1; i >= 0; i--) pads[i].id: i};
    for (final (index, join) in joins.indexed) {
      final node = 'pour:$index';
      for (final pad in join.pads) {
        final i = padIndex[pad.id];
        if (i != null) union(node, padNode(i));
      }
      for (final track in join.tracks) {
        union(node, pointNode(Offset(track.startX, track.startY), track.layer));
      }
      for (final via in join.vias) {
        union(node, pointNode(Offset(via.x, via.y), CopperLayer.front));
      }
    }

    final grouped = <String, List<PlacedPad>>{};
    for (var i = 0; i < pads.length; i++) {
      (grouped[find(padNode(i))] ??= []).add(pads[i]);
    }
    return grouped.values.toList();
  }

  /// Decides each track's and via's net from the pads its copper reaches.
  ///
  /// Copper is grouped by geometry alone — ignoring stored nets — and a
  /// group touching exactly one net's pads is on that net. A group touching
  /// none keeps what it had (it may be a stub routed ahead of time, or an
  /// orphan the design check will report), and a group touching two nets is
  /// a short, which keeps its stored nets so the clearance check can see
  /// the collision rather than have it quietly relabelled away.
  static ({
    List<Track> tracks,
    List<Via> vias,
    Set<String> staleTracks,
    Set<String> staleVias,
  })
  _resolveCopperNets(List<PlacedPad> pads, List<Track> tracks, List<Via> vias) {
    if (tracks.isEmpty && vias.isEmpty) {
      return (
        tracks: tracks,
        vias: vias,
        staleTracks: const {},
        staleVias: const {},
      );
    }

    final parent = <String, String>{};
    String find(String node) {
      var root = parent.putIfAbsent(node, () => node);
      while (parent[root] != root) {
        root = parent[root]!;
      }
      var current = node;
      while (parent[current] != root) {
        final next = parent[current]!;
        parent[current] = root;
        current = next;
      }
      return root;
    }

    void union(String a, String b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parent[rootA] = rootB;
    }

    String pointNode(Offset point, CopperLayer layer) =>
        '${layer.name}@${(point.dx / _touchMm).round()},'
        '${(point.dy / _touchMm).round()}';

    // Which net each pad is on, joined into the graph as its own node.
    final padNets = <String, String>{};
    final near = _PadIndex(pads);
    void bindToPads(Offset point, CopperLayer layer) {
      for (final i in near.at(point)) {
        final pad = pads[i];
        final net = pad.netId;
        if (net == null || !pad.reaches(layer)) continue;
        if (!pad.contains(point, toleranceMm: _touchMm)) continue;
        final node = 'pad:$i';
        padNets[node] = net;
        union(pointNode(point, layer), node);
      }
    }

    for (final track in tracks) {
      final start = Offset(track.startX, track.startY);
      final end = Offset(track.endX, track.endY);
      union('track:${track.id}', pointNode(start, track.layer));
      union('track:${track.id}', pointNode(end, track.layer));
    }

    for (final via in vias) {
      final at = Offset(via.x, via.y);
      for (final layer in CopperLayer.values) {
        union('via:${via.id}', pointNode(at, layer));
        bindToPads(at, layer);
      }
    }

    _contacts(
      pads,
      tracks,
      vias,
      onPad: (t, p) {
        final net = pads[p].netId;
        if (net == null) return;
        padNets['pad:$p'] = net;
        union('track:${tracks[t].id}', 'pad:$p');
      },
      onTrack: (t, o) =>
          union('track:${tracks[t].id}', 'track:${tracks[o].id}'),
      onVia: (t, v) => union('track:${tracks[t].id}', 'via:${vias[v].id}'),
    );

    final netsByGroup = <String, Set<String>>{};
    for (final entry in padNets.entries) {
      (netsByGroup[find(entry.key)] ??= {}).add(entry.value);
    }

    String? netFor(String node, String? stored) {
      final nets = netsByGroup[find(node)];
      if (nets == null || nets.length != 1) return stored;
      return nets.single;
    }

    final staleTracks = <String>{};
    final resolvedTracks = <Track>[];
    for (final track in tracks) {
      final net = netFor('track:${track.id}', track.netId);
      if (net != track.netId) staleTracks.add(track.id);
      resolvedTracks.add(net == track.netId ? track : track.withNet(net));
    }

    final staleVias = <String>{};
    final resolvedVias = <Via>[];
    for (final via in vias) {
      final net = netFor('via:${via.id}', via.netId);
      if (net != via.netId) staleVias.add(via.id);
      resolvedVias.add(net == via.netId ? via : via.withNet(net));
    }

    return (
      tracks: resolvedTracks,
      vias: resolvedVias,
      staleTracks: staleTracks,
      staleVias: staleVias,
    );
  }

  /// What the [tracks] touch, beyond two tracks meeting end to end: every
  /// pad a track's run crosses, not only one it ends in; another track a
  /// track ends on anywhere along it; and every via on a track's run.
  ///
  /// A board drawn in KiCad routes one straight track through a row of
  /// pads as often as it stops at each, and tees one track into the middle
  /// of another; reading only where tracks end left those pads unrouted.
  static void _contacts(
    List<PlacedPad> pads,
    List<Track> tracks,
    List<Via> vias, {
    required void Function(int track, int pad) onPad,
    required void Function(int track, int other) onTrack,
    required void Function(int track, int via) onVia,
  }) {
    final padsAt = _PadIndex(pads);
    // Tracks by the cells their copper passes through.
    final tracksAt = <(int, int), List<int>>{};
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final box = Rect.fromPoints(
        Offset(track.startX, track.startY),
        Offset(track.endX, track.endY),
      ).inflate(track.width / 2 + _touchMm);
      for (final cell in _PadIndex.cellsOver(box)) {
        (tracksAt[cell] ??= []).add(i);
      }
    }

    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final a = Offset(track.startX, track.startY);
      final b = Offset(track.endX, track.endY);
      for (final p in padsAt.within(Rect.fromPoints(a, b))) {
        final pad = pads[p];
        if (pad.reaches(track.layer) &&
            pad.crosses(a, b, toleranceMm: _touchMm)) {
          onPad(i, p);
        }
      }
      for (final end in [a, b]) {
        for (final o in tracksAt[_PadIndex.cellOf(end)] ?? const <int>[]) {
          final other = tracks[o];
          if (o == i || other.layer != track.layer) continue;
          final distance = distanceToSegment(
            end,
            Offset(other.startX, other.startY),
            Offset(other.endX, other.endY),
          );
          if (distance <= other.width / 2 + _touchMm) onTrack(i, o);
        }
      }
    }

    for (var v = 0; v < vias.length; v++) {
      final via = vias[v];
      final at = Offset(via.x, via.y);
      final reach = via.diameter / 2 + _touchMm;
      final seen = <int>{};
      for (final cell in _PadIndex.cellsOver(
        Rect.fromCircle(center: at, radius: reach),
      )) {
        for (final t in tracksAt[cell] ?? const <int>[]) {
          if (!seen.add(t)) continue;
          final track = tracks[t];
          final distance = distanceToSegment(
            at,
            Offset(track.startX, track.startY),
            Offset(track.endX, track.endY),
          );
          if (distance <= reach) onVia(t, v);
        }
      }
    }
  }

  /// The two pads, one from each group, that are closest together.
  static (PlacedPad, PlacedPad) _closestPair(
    List<PlacedPad> a,
    List<PlacedPad> b,
  ) {
    var best = (a.first, b.first);
    var bestDistance = double.infinity;
    for (final left in a) {
      for (final right in b) {
        final distance = (left.position - right.position).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = (left, right);
        }
      }
    }
    return best;
  }

  /// A minimum spanning tree over groups, by nearest-pad distance.
  static List<(int, int)> _spanningTree(List<List<PlacedPad>> groups) {
    if (groups.length < 2) return const [];

    final edges = <(int, int)>[];
    final inTree = List<bool>.filled(groups.length, false);
    final nearest = List<double>.filled(groups.length, double.infinity);
    final parent = List<int>.filled(groups.length, -1);
    nearest[0] = 0;

    for (var step = 0; step < groups.length; step++) {
      var next = -1;
      var nextDistance = double.infinity;
      for (var i = 0; i < groups.length; i++) {
        if (!inTree[i] && nearest[i] < nextDistance) {
          nextDistance = nearest[i];
          next = i;
        }
      }
      if (next < 0) break;

      inTree[next] = true;
      if (parent[next] >= 0) edges.add((parent[next], next));

      for (var i = 0; i < groups.length; i++) {
        if (inTree[i]) continue;
        final (a, b) = _closestPair(groups[i], groups[next]);
        final distance = (a.position - b.position).distance;
        if (distance < nearest[i]) {
          nearest[i] = distance;
          parent[i] = next;
        }
      }
    }
    return edges;
  }
}

/// Shortest distance from [p] to the segment [a]-[b].
double distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared < 1e-12) return (p - a).distance;

  var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}

/// Pads by where they sit on the board, so the pads under a point are
/// found among the few nearby rather than by trying every pad there is.
class _PadIndex {
  _PadIndex(List<PlacedPad> pads) {
    for (var i = 0; i < pads.length; i++) {
      final pad = pads[i];
      // Far enough for any shape turned any way, and the touch tolerance.
      final reach =
          math.sqrt(
                pad.pad.sizeX * pad.pad.sizeX + pad.pad.sizeY * pad.pad.sizeY,
              ) /
              2 +
          0.01;
      for (final cell in cellsOver(
        Rect.fromCircle(center: pad.position, radius: reach),
      )) {
        (_cells[cell] ??= []).add(i);
      }
    }
  }

  /// Millimetres on a side: a few pads' worth.
  static const _cell = 2.0;

  final _cells = <(int, int), List<int>>{};

  /// The indices of the pads that might cover [point].
  List<int> at(Offset point) => _cells[cellOf(point)] ?? const [];

  /// The indices of the pads that might reach into [box], each once.
  Set<int> within(Rect box) => {
    for (final cell in cellsOver(box)) ...?_cells[cell],
  };

  static (int, int) cellOf(Offset point) =>
      ((point.dx / _cell).floor(), (point.dy / _cell).floor());

  static Iterable<(int, int)> cellsOver(Rect box) sync* {
    final (x0, y0) = cellOf(box.topLeft);
    final (x1, y1) = cellOf(box.bottomRight);
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        yield (x, y);
      }
    }
  }
}
