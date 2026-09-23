import 'dart:math' as math;
import 'dart:ui';

import 'board_layer.dart';
import 'board_scene.dart';
import 'board_zone.dart';
import 'courtyard.dart';
import 'fab_presets.dart';

/// How much a rule violation matters.
enum DrcSeverity {
  /// The board cannot be made, or will not work.
  error,

  /// The board is unfinished, or is doing something worth a second look.
  warning,
}

/// What kind of problem was found. Kept as an enum so the UI can group and
/// count without matching on prose.
enum DrcRule {
  clearance('Clearance'),
  trackWidth('Track width'),
  viaSize('Via size'),
  unrouted('Unrouted'),
  offBoard('Outside the board'),
  unplaced('Not placed'),
  missingFootprint('No footprint'),
  orphanCopper('Copper on no net'),
  courtyardOverlap('Courtyards overlap'),
  courtyardOffBoard('Part off the board'),
  missingLayer('No such layer'),
  fabLimit('Below the fab\'s limit'),
  drillSize('Hole too small'),
  annularRing('Annular ring'),
  holeSpacing('Holes too close'),
  edgeClearance('Copper at the edge'),
  silkscreen('Silkscreen'),
  boardSize('Board size'),
  pourConnection('Pad not joined to its pour'),
  keepout('Inside a keepout'),
  viaSpan('Via span');

  const DrcRule(this.label);

  final String label;
}

/// One rule violation, with somewhere to look.
class DrcViolation {
  const DrcViolation({
    required this.rule,
    required this.severity,
    required this.message,
    required this.position,
    this.netId,
  });

  final DrcRule rule;
  final DrcSeverity severity;
  final String message;

  /// Where on the board to point the user, in millimetres.
  final Offset position;

  final String? netId;

  bool get isError => severity == DrcSeverity.error;

  @override
  String toString() => '${rule.label}: $message';
}

/// The design rule check.
///
/// Deliberately not a substitute for KiCad's. It catches the mistakes a
/// phone layout actually makes — copper too close, a track hanging off the
/// board, a connection never drawn — and leaves the rest to the desktop,
/// which is where the board is going anyway. Being fast and honest about a
/// small set of rules beats being slow and approximate about all of them.
///
/// With [fab], also what that board house would refuse — see
/// [fabViolations].
List<DrcViolation> checkBoard(BoardScene scene, {FabPreset? fab}) {
  final violations = <DrcViolation>[];
  final rules = scene.board.rules;
  final outline = scene.outline;
  final outlineBounds = scene.outlineBounds;

  // --- things that are simply not finished -----------------------------

  if (scene.unplaced.isNotEmpty) {
    violations.add(
      DrcViolation(
        rule: DrcRule.unplaced,
        severity: DrcSeverity.warning,
        message: scene.unplaced.length == 1
            ? 'One footprint has not been placed on the board'
            : '${scene.unplaced.length} footprints have not been placed',
        position: outlineBounds.center,
      ),
    );
  }

  for (final footprint in scene.footprints) {
    if (footprint.isResolved) continue;
    violations.add(
      DrcViolation(
        rule: DrcRule.missingFootprint,
        severity: DrcSeverity.error,
        message:
            '${footprint.part.reference} uses ${footprint.ref.libId}, '
            'which is not installed',
        position: Offset(footprint.ref.x, footprint.ref.y),
      ),
    );
  }

  for (final line in scene.ratsnest) {
    violations.add(
      DrcViolation(
        rule: DrcRule.unrouted,
        severity: DrcSeverity.warning,
        message: '${line.netName} is not routed',
        position: Offset.lerp(line.from, line.to, 0.5)!,
        netId: line.netId,
      ),
    );
  }

  // Copper drawn for a connection the schematic no longer has. Reported on
  // its own rather than left to the clearance check, which would otherwise
  // describe it as a mysterious clash with the very pads it was drawn to.
  final orphans = scene.orphanTracks;
  if (orphans.isNotEmpty) {
    violations.add(
      DrcViolation(
        rule: DrcRule.orphanCopper,
        severity: DrcSeverity.error,
        message: orphans.length == 1
            ? 'A track belongs to no net — the connection it was drawn for '
                  'was removed from the schematic'
            : '${orphans.length} tracks belong to no net — the connections '
                  'they were drawn for were removed from the schematic',
        position: Offset(orphans.first.startX, orphans.first.startY),
      ),
    );
  }

  // --- things that are wrong -------------------------------------------

  for (final track in scene.tracks) {
    if (track.width < rules.trackWidth - 1e-9) {
      violations.add(
        DrcViolation(
          rule: DrcRule.trackWidth,
          severity: DrcSeverity.error,
          message:
              'A track is ${_mm(track.width)} wide, below the '
              '${_mm(rules.trackWidth)} minimum',
          position: Offset(track.startX, track.startY),
          netId: track.netId,
        ),
      );
    }

    // Copper that leaves the board is copper that gets milled through.
    final start = Offset(track.startX, track.startY);
    final end = Offset(track.endX, track.endY);
    if (!outline.contains(start) || !outline.contains(end)) {
      violations.add(
        DrcViolation(
          rule: DrcRule.offBoard,
          severity: DrcSeverity.error,
          message: 'A track runs outside the board outline',
          position: outline.contains(start) ? end : start,
          netId: track.netId,
        ),
      );
    }
  }

  for (final via in scene.vias) {
    if (via.diameter <= via.drill) {
      violations.add(
        DrcViolation(
          rule: DrcRule.viaSize,
          severity: DrcSeverity.error,
          message: 'A via has no copper around its hole',
          position: Offset(via.x, via.y),
          netId: via.netId,
        ),
      );
    }
  }

  // A track left on a layer the board no longer has — drawn on In3, then
  // the board cut back to four layers — would simply vanish at the fab.
  final layers = scene.board.copperLayers.toSet();
  for (final track in scene.tracks) {
    if (layers.contains(track.layer)) continue;
    violations.add(
      DrcViolation(
        rule: DrcRule.missingLayer,
        severity: DrcSeverity.error,
        message:
            'A track is on ${track.layer.label}, which this '
            '${scene.board.copperLayerCount}-layer board does not have',
        position: Offset(track.startX, track.startY),
        netId: track.netId,
      ),
    );
  }

  violations.addAll(_keepoutViolations(scene));
  violations.addAll(_viaSpanViolations(scene));
  violations.addAll(_clearanceViolations(scene));
  violations.addAll(courtyardViolations(scene));
  violations.addAll(pourViolations(scene));
  if (fab != null) violations.addAll(fabViolations(scene, fab));
  return violations;
}

/// Parts that physically collide, and parts hanging off the board.
///
/// Compared courtyard to courtyard on the same side, the way KiCad does:
/// a resistor on the back can sit under a chip on the front. A part with
/// no courtyard drawn is not checked — there is nothing to check it with —
/// rather than guessed at from its silkscreen.
List<DrcViolation> courtyardViolations(BoardScene scene) {
  final courtyards = Courtyard.claims(scene);
  final violations = <DrcViolation>[];

  for (var i = 0; i < courtyards.length; i++) {
    for (var j = i + 1; j < courtyards.length; j++) {
      final a = courtyards[i];
      final b = courtyards[j];
      if (a.footprint.ref.id == b.footprint.ref.id) continue;
      if (!a.overlaps(b)) continue;
      final overlap = a.bounds.intersect(b.bounds);
      // Two drawn courtyards on the same ground is an error: their authors
      // said how much room the parts need and there is not that much. With
      // no courtyard drawn it is the bodies that were compared, which is a
      // good enough reason to look but not to be certain.
      final drawn = a.drawn && b.drawn;
      violations.add(
        DrcViolation(
          rule: DrcRule.courtyardOverlap,
          severity: drawn ? DrcSeverity.error : DrcSeverity.warning,
          message: drawn
              ? '${a.reference} and ${b.reference} overlap on the '
                    '${a.back ? 'back' : 'front'} — there is not room to '
                    'fit both'
              : '${a.reference} and ${b.reference} sit on top of each other '
                    'on the ${a.back ? 'back' : 'front'} — neither '
                    'footprint has a courtyard drawn, so this is the '
                    'bodies overlapping',
          position: overlap.isEmpty ? a.bounds.center : overlap.center,
        ),
      );
    }
  }

  // Off the board: a courtyard corner outside the outline. A warning, not
  // an error — a connector overhanging the edge on purpose is common, and
  // is exactly what this should make sure was on purpose.
  final outline = scene.outline;
  for (final courtyard in courtyards) {
    final outside = <Offset>[
      for (final shape in courtyard.outlines)
        for (final p in shape)
          if (!outline.contains(p)) p,
    ];
    if (outside.isEmpty) continue;
    violations.add(
      DrcViolation(
        rule: DrcRule.courtyardOffBoard,
        severity: DrcSeverity.warning,
        message: '${courtyard.reference} hangs over the edge of the board',
        position: outside.first,
      ),
    );
  }
  return violations;
}

/// Anything put inside an area that says it may not be.
///
/// A keepout is drawn to protect something the board cannot see: the gap an
/// antenna needs, the plastic body of a connector that overhangs its pads,
/// the swing of a screw's washer. Nothing stops copper being drawn there —
/// stopping the finger mid-route is worse than saying so afterwards — so
/// this is where it gets said.
List<DrcViolation> _keepoutViolations(BoardScene scene) {
  final areas = [
    for (final zone in scene.zones)
      if (zone.isValid && zone.keepout) zone,
  ];
  if (areas.isEmpty) return const [];
  final violations = <DrcViolation>[];

  void complain(BoardZone area, String what, Offset at, String? netId) {
    violations.add(
      DrcViolation(
        rule: DrcRule.keepout,
        severity: DrcSeverity.error,
        message: '$what is inside a keepout that allows no ${_only(area)}',
        position: at,
        netId: netId,
      ),
    );
  }

  for (final area in areas) {
    if (area.noTracks) {
      for (final track in scene.tracks) {
        if (track.layer.layer != area.layer) continue;
        final a = Offset(track.startX, track.startY);
        final b = Offset(track.endX, track.endY);
        // Sampled along, so a run that crosses a corner of the area is
        // caught as well as one that ends inside it.
        final steps = math.max(2, ((b - a).distance / 0.5).ceil());
        for (var i = 0; i <= steps; i++) {
          final at = Offset.lerp(a, b, i / steps)!;
          if (!area.contains(at)) continue;
          complain(area, 'A track', at, track.netId);
          break;
        }
      }
    }
    if (area.noVias) {
      for (final via in scene.vias) {
        final at = Offset(via.x, via.y);
        if (!area.contains(at)) continue;
        complain(area, 'A via', at, via.netId);
      }
    }
    if (area.noParts) {
      for (final footprint in scene.footprints) {
        if (!footprint.ref.placed) continue;
        if (!area.contains(footprint.bounds.center)) continue;
        complain(
          area,
          footprint.part.reference,
          footprint.bounds.center,
          null,
        );
      }
    }
  }
  return violations;
}

String _only(BoardZone area) {
  final kept = area.keptOut;
  if (kept.isEmpty) return 'nothing in particular';
  if (kept.length == 1) return kept.single;
  return '${kept.take(kept.length - 1).join(', ')} or ${kept.last}';
}

/// Blind and buried vias that cannot be drilled as asked.
List<DrcViolation> _viaSpanViolations(BoardScene scene) => [
  for (final via in scene.vias)
    if (via.problemOn(scene.board) case final problem?)
      DrcViolation(
        rule: DrcRule.viaSpan,
        severity: DrcSeverity.error,
        message: '${via.kind.label} via: $problem',
        position: Offset(via.x, via.y),
        netId: via.netId,
      ),
];

/// Copper of different nets that comes closer than the clearance rule.
///
/// Everything is reduced to a segment with a width: a track is one already,
/// and a pad is treated as a segment through its long axis, inflated to its
/// short one. That approximation is generous on a rectangular pad's corners
/// by at most a fraction of the pad's own radius, and it turns four
/// shape-versus-shape problems into one.
List<DrcViolation> _clearanceViolations(BoardScene scene) {
  final items = copperItems(scene);
  final violations = <DrcViolation>[];
  final reported = <String>{};

  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i];
      final b = items[j];

      // Same net is meant to touch; different layers cannot.
      if (a.netId != null && a.netId == b.netId) continue;
      if (!a.layers.any(b.layers.contains)) continue;

      // Whichever of the two nets asks for more room gets it.
      final clearance = math.max(
        scene.clearanceFor(a.netId),
        scene.clearanceFor(b.netId),
      );
      if (clearance <= 0) continue;

      final gap =
          _segmentDistance(a.a, a.b, b.a, b.b) - (a.width + b.width) / 2;
      if (gap >= clearance - 1e-9) continue;

      // One complaint per pair of things, not one per frame of geometry.
      final key = '${a.what}|${b.what}|${a.a}|${b.a}';
      if (!reported.add(key)) continue;

      violations.add(
        DrcViolation(
          rule: DrcRule.clearance,
          severity: DrcSeverity.error,
          message:
              '${a.what} and ${b.what} are ${_mm(math.max(0, gap))} apart, '
              'closer than the ${_mm(clearance)} clearance',
          position: Offset.lerp(a.a, b.a, 0.5)!,
          netId: a.netId ?? b.netId,
        ),
      );
    }
  }
  return violations;
}

/// Where a track being routed comes too close to another net's copper.
class RouteClash {
  const RouteClash({required this.segment, required this.at});

  /// Which run of the route: between corners segment and segment + 1.
  final int segment;

  /// The spot on the other copper that is too close.
  final Offset at;
}

/// Checks a route while it is still being drawn.
///
/// Reported, not enforced: the route shows red where it is too close and
/// the user decides what to do about it. Refusing the corner would be the
/// board deciding for them, and on a phone that reads as the crosshair
/// having stopped working.
List<RouteClash> routeClashes(
  BoardScene scene, {
  required List<Offset> route,
  required double width,
  required CopperLayer layer,
  String? netId,
}) {
  if (route.length < 2) return const [];
  final token = layer.layer.token;
  final clashes = <RouteClash>[];

  // Only the copper that could possibly be in the way, and each piece's
  // box worked out once rather than once per corner. This runs on every
  // frame of every drag, against every piece of copper on the board, for
  // every corner of a route that may be hundreds of points long if it is
  // meandered — so the cheap rejections have to happen before the
  // segment-to-segment arithmetic, not after it.
  final items = <CopperItem>[];
  final boxes = <Rect>[];
  var widest = 0.0;
  var loosest = 0.0;
  final own = scene.clearanceFor(netId);
  for (final item in copperItems(scene)) {
    if (!item.layers.contains(token)) continue;
    if (netId != null && item.netId == netId) continue;
    items.add(item);
    boxes.add(Rect.fromPoints(item.a, item.b).inflate(item.width / 2));
    widest = math.max(widest, item.width);
    loosest = math.max(loosest, scene.clearanceFor(item.netId));
  }
  final reach = width / 2 + widest / 2 + math.max(own, loosest);

  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    if ((b - a).distance < 1e-9) continue;
    final near = Rect.fromPoints(a, b).inflate(reach);

    for (var k = 0; k < items.length; k++) {
      if (!boxes[k].overlaps(near)) continue;
      final item = items[k];
      // A route not yet on a net starts on copper that is not on one
      // either; that copper is where it came from, not an obstacle.
      if (netId == null &&
          _segmentDistance(item.a, item.b, route.first, route.first) <=
              item.width / 2 + 1e-6) {
        continue;
      }

      final clearance = math.max(
        scene.clearanceFor(netId),
        scene.clearanceFor(item.netId),
      );
      final gap =
          _segmentDistance(a, b, item.a, item.b) - (width + item.width) / 2;
      if (gap >= clearance - 1e-9) continue;

      clashes.add(
        RouteClash(segment: i, at: _nearestOn(item.a, item.b, (a + b) / 2)),
      );
    }
  }
  return clashes;
}

Offset _nearestOn(Offset a, Offset b, Offset p) {
  final d = b - a;
  final length = d.dx * d.dx + d.dy * d.dy;
  if (length < 1e-12) return a;
  final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / length).clamp(0.0, 1.0);
  return a + d * t;
}

/// Every piece of copper on the board as a thick segment.
///
/// A pad is treated as the segment down its long axis, as wide as its short
/// side, which is exact for an oval pad, and close enough for a rectangle
/// that it overstates the pad by at most a fraction of its own radius.
/// Every piece of copper on the board as a segment with a width: what the
/// clearance check measures, and what a route has to keep clear of.
List<CopperItem> copperItems(BoardScene scene) {
  final items = <CopperItem>[];

  for (final track in scene.tracks) {
    items.add(
      CopperItem(
        netId: track.netId,
        layers: {track.layer.layer.token},
        a: Offset(track.startX, track.startY),
        b: Offset(track.endX, track.endY),
        width: track.width,
        what: 'track',
      ),
    );
  }

  for (final via in scene.vias) {
    items.add(
      CopperItem(
        netId: via.netId,
        // Through every layer the board has, inner ones included.
        layers: {
          for (final layer in scene.board.copperLayers) layer.layer.token,
        },
        a: Offset(via.x, via.y),
        b: Offset(via.x, via.y),
        width: via.diameter,
        what: 'via',
      ),
    );
  }

  for (final pad in scene.pads) {
    final long = math.max(pad.pad.sizeX, pad.pad.sizeY);
    final short = math.min(pad.pad.sizeX, pad.pad.sizeY);
    final alongX = pad.pad.sizeX >= pad.pad.sizeY;
    final reach = math.max(0.0, (long - short) / 2);
    final radians = pad.angle * math.pi / 180;
    final direction = alongX
        ? Offset(math.cos(radians), -math.sin(radians))
        : Offset(math.sin(radians), math.cos(radians));

    items.add(
      CopperItem(
        netId: pad.netId,
        layers: {for (final layer in pad.layers) layer.token},
        a: pad.position - direction * reach,
        b: pad.position + direction * reach,
        width: short,
        what: 'pad ${pad.label}',
      ),
    );
  }
  return items;
}

/// One piece of copper, reduced to a segment with a width.
class CopperItem {
  const CopperItem({
    required this.netId,
    required this.layers,
    required this.a,
    required this.b,
    required this.width,
    required this.what,
  });

  final String? netId;
  final Set<String> layers;
  final Offset a;
  final Offset b;
  final double width;
  final String what;
}

String _mm(double value) => '${value.toStringAsFixed(2)} mm';

/// Shortest distance between two segments.
double _segmentDistance(Offset a1, Offset a2, Offset b1, Offset b2) {
  if (_segmentsIntersect(a1, a2, b1, b2)) return 0;
  return math.min(
    math.min(distanceToSegment(a1, b1, b2), distanceToSegment(a2, b1, b2)),
    math.min(distanceToSegment(b1, a1, a2), distanceToSegment(b2, a1, a2)),
  );
}

bool _segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
  double cross(Offset o, Offset p, Offset q) =>
      (p.dx - o.dx) * (q.dy - o.dy) - (p.dy - o.dy) * (q.dx - o.dx);

  final d1 = cross(b1, b2, a1);
  final d2 = cross(b1, b2, a2);
  final d3 = cross(a1, a2, b1);
  final d4 = cross(a1, a2, b2);

  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}
