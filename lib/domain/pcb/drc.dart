import 'dart:math' as math;
import 'dart:ui';

import 'board_scene.dart';

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
  orphanCopper('Copper on no net');

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
List<DrcViolation> checkBoard(BoardScene scene) {
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

  violations.addAll(_clearanceViolations(scene));
  return violations;
}

/// Copper of different nets that comes closer than the clearance rule.
///
/// Everything is reduced to a segment with a width: a track is one already,
/// and a pad is treated as a segment through its long axis, inflated to its
/// short one. That approximation is generous on a rectangular pad's corners
/// by at most a fraction of the pad's own radius, and it turns four
/// shape-versus-shape problems into one.
List<DrcViolation> _clearanceViolations(BoardScene scene) {
  final clearance = scene.board.rules.clearance;
  if (clearance <= 0) return const [];

  final items = <_CopperItem>[];

  for (final track in scene.tracks) {
    items.add(
      _CopperItem(
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
      _CopperItem(
        netId: via.netId,
        layers: const {'F.Cu', 'B.Cu'},
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
      _CopperItem(
        netId: pad.netId,
        layers: {for (final layer in pad.layers) layer.token},
        a: pad.position - direction * reach,
        b: pad.position + direction * reach,
        width: short,
        what: 'pad ${pad.label}',
      ),
    );
  }

  final violations = <DrcViolation>[];
  final reported = <String>{};

  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i];
      final b = items[j];

      // Same net is meant to touch; different layers cannot.
      if (a.netId != null && a.netId == b.netId) continue;
      if (!a.layers.any(b.layers.contains)) continue;

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

class _CopperItem {
  const _CopperItem({
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
    math.min(
      distanceToSegment(a1, b1, b2),
      distanceToSegment(a2, b1, b2),
    ),
    math.min(
      distanceToSegment(b1, a1, a2),
      distanceToSegment(b2, a1, a2),
    ),
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
