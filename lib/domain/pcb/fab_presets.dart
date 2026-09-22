import 'dart:math' as math;
import 'dart:ui';

import 'board.dart';
import 'board_outline.dart';
import 'board_scene.dart';
import 'drc.dart';
import 'footprint.dart';
import 'pour_fill.dart';

/// What one board house can make, and the rules worth drawing to for it.
///
/// Two sets of numbers, kept apart on purpose. The limits are the
/// capability page: below them the order is refused or the board comes
/// back wrong. The rules are what the board is drawn to by default —
/// comfortably above the limits, because a board drawn at the limit of
/// every rule is a board with no margin for a fab's bad day.
class FabPreset {
  const FabPreset({
    required this.id,
    required this.name,
    required this.note,
    required this.minTrack,
    required this.minClearance,
    required this.minViaDrill,
    required this.minViaDiameter,
    required this.minPthRing,
    required this.minPthDrill,
    required this.minNpthDrill,
    required this.minHoleSpacing,
    required this.copperToEdge,
    required this.minSilkWidth,
    required this.minSilkHeight,
    required this.silkToPad,
    required this.maxSize,
    required this.minSize,
    required this.rules,
  });

  /// Stable, stored in the project's settings.
  final String id;
  final String name;

  /// Where the numbers come from, and what they assume.
  final String note;

  final double minTrack;
  final double minClearance;
  final double minViaDrill;
  final double minViaDiameter;

  /// Copper round a component hole, measured one side.
  final double minPthRing;
  final double minPthDrill;
  final double minNpthDrill;

  /// Edge to edge between two holes.
  final double minHoleSpacing;
  final double copperToEdge;
  final double minSilkWidth;
  final double minSilkHeight;
  final double silkToPad;

  /// Largest and smallest board, width by height, in millimetres.
  final Size maxSize;
  final Size minSize;

  /// The rules a board for this house is drawn to by default.
  final DesignRules rules;

  /// The copper a via of this house's smallest size leaves round its hole.
  double get minViaRing => (minViaDiameter - minViaDrill) / 2;
}

/// The presets offered, from each house's published capability page
/// (checked September 2026). Standard FR-4, no paid extras.
abstract final class FabPresets {
  static const jlcpcb2 = FabPreset(
    id: 'jlcpcb-2',
    name: 'JLCPCB 1–2 layer',
    note: '1 oz copper. jlcpcb.com/capabilities/pcb-capabilities',
    minTrack: 0.10,
    minClearance: 0.10,
    minViaDrill: 0.15,
    minViaDiameter: 0.25,
    minPthRing: 0.20,
    minPthDrill: 0.15,
    minNpthDrill: 0.50,
    minHoleSpacing: 0.20,
    copperToEdge: 0.20,
    minSilkWidth: 0.15,
    minSilkHeight: 1.0,
    silkToPad: 0.15,
    maxSize: Size(1020, 600),
    minSize: Size(3, 3),
    rules: DesignRules(
      trackWidth: 0.2,
      clearance: 0.15,
      viaDiameter: 0.6,
      viaDrill: 0.3,
    ),
  );

  static const jlcpcb2Heavy = FabPreset(
    id: 'jlcpcb-2-2oz',
    name: 'JLCPCB 1–2 layer, 2 oz',
    note: '2 oz copper needs wider gaps. jlcpcb.com/capabilities',
    minTrack: 0.16,
    minClearance: 0.16,
    minViaDrill: 0.15,
    minViaDiameter: 0.25,
    minPthRing: 0.20,
    minPthDrill: 0.15,
    minNpthDrill: 0.50,
    minHoleSpacing: 0.20,
    copperToEdge: 0.20,
    minSilkWidth: 0.15,
    minSilkHeight: 1.0,
    silkToPad: 0.15,
    maxSize: Size(1020, 600),
    minSize: Size(3, 3),
    rules: DesignRules(
      trackWidth: 0.25,
      clearance: 0.2,
      viaDiameter: 0.6,
      viaDrill: 0.3,
    ),
  );

  static const jlcpcbMulti = FabPreset(
    id: 'jlcpcb-multi',
    name: 'JLCPCB 4–6 layer',
    note: '1 oz outer, 0.5 oz inner. jlcpcb.com/capabilities',
    minTrack: 0.09,
    minClearance: 0.09,
    minViaDrill: 0.15,
    minViaDiameter: 0.25,
    minPthRing: 0.20,
    minPthDrill: 0.15,
    minNpthDrill: 0.50,
    minHoleSpacing: 0.20,
    copperToEdge: 0.20,
    minSilkWidth: 0.15,
    minSilkHeight: 1.0,
    silkToPad: 0.15,
    maxSize: Size(1020, 600),
    minSize: Size(3, 3),
    rules: DesignRules(
      trackWidth: 0.15,
      clearance: 0.12,
      viaDiameter: 0.45,
      viaDrill: 0.2,
    ),
  );

  static const pcbway = FabPreset(
    id: 'pcbway',
    name: 'PCBWay standard',
    note: 'FR-4, 1 oz. pcbway.com/capabilities.html',
    minTrack: 0.10,
    minClearance: 0.10,
    minViaDrill: 0.15,
    minViaDiameter: 0.45,
    minPthRing: 0.15,
    minPthDrill: 0.15,
    minNpthDrill: 0.15,
    minHoleSpacing: 0.40,
    copperToEdge: 0.25,
    minSilkWidth: 0.15,
    minSilkHeight: 0.8,
    silkToPad: 0.15,
    maxSize: Size(1200, 600),
    minSize: Size(3, 3),
    rules: DesignRules(
      trackWidth: 0.2,
      clearance: 0.15,
      viaDiameter: 0.6,
      viaDrill: 0.3,
    ),
  );

  static const all = [jlcpcb2, jlcpcb2Heavy, jlcpcbMulti, pcbway];

  /// The key a project's chosen house is kept under.
  static const settingsKey = 'fab.preset';

  static FabPreset? byId(String? id) =>
      all.where((p) => p.id == id).firstOrNull;
}

/// What a board house would refuse, or make wrong, for [preset].
///
/// Complements the design rule check: that asks whether the board keeps
/// to its own rules, this asks whether those rules — and the things they
/// do not cover, like holes and silkscreen — are within what the house
/// can make.
List<DrcViolation> fabViolations(BoardScene scene, FabPreset preset) {
  final out = <DrcViolation>[];
  void add(
    DrcRule rule,
    String message,
    Offset at, {
    DrcSeverity severity = DrcSeverity.error,
    String? netId,
  }) => out.add(
    DrcViolation(
      rule: rule,
      severity: severity,
      message: message,
      position: at,
      netId: netId,
    ),
  );
  String mm(double v) => '${v.toStringAsFixed(2)} mm';
  final house = preset.name;

  // The rules themselves.
  final rules = scene.board.rules;
  final centre = scene.outlineBounds.center;
  if (rules.clearance < preset.minClearance - 1e-9) {
    add(
      DrcRule.fabLimit,
      'The ${mm(rules.clearance)} clearance rule is below $house\'s '
      '${mm(preset.minClearance)}',
      centre,
    );
  }

  // Board size.
  final size = scene.outlineBounds.size;
  final long = math.max(size.width, size.height);
  final short = math.min(size.width, size.height);
  if (long > preset.maxSize.width || short > preset.maxSize.height) {
    add(
      DrcRule.boardSize,
      'At ${size.width.toStringAsFixed(0)} × '
      '${size.height.toStringAsFixed(0)} mm the board is larger than '
      '$house makes',
      centre,
    );
  }
  if (short < preset.minSize.height || long < preset.minSize.width) {
    add(DrcRule.boardSize, 'The board is smaller than $house makes', centre);
  }

  // Copper.
  for (final track in scene.tracks) {
    if (track.width < preset.minTrack - 1e-9) {
      add(
        DrcRule.fabLimit,
        'A ${mm(track.width)} track is narrower than $house\'s '
        '${mm(preset.minTrack)}',
        Offset(track.startX, track.startY),
        netId: track.netId,
      );
    }
  }

  // Holes: size, the copper round them, and the gap between them.
  final holes = <(Offset, double, String)>[];
  for (final via in scene.vias) {
    final at = Offset(via.x, via.y);
    holes.add((at, via.drill, 'A via'));
    if (via.drill < preset.minViaDrill - 1e-9) {
      add(
        DrcRule.drillSize,
        'A via drilled ${mm(via.drill)} is below $house\'s '
        '${mm(preset.minViaDrill)}',
        at,
        netId: via.netId,
      );
    }
    final ring = (via.diameter - via.drill) / 2;
    if (ring < preset.minViaRing - 1e-9) {
      add(
        DrcRule.annularRing,
        'A via leaves ${mm(ring)} of copper round its hole; $house needs '
        '${mm(preset.minViaRing)}',
        at,
        netId: via.netId,
      );
    }
  }
  for (final footprint in scene.footprints) {
    for (final pad in footprint.pads) {
      final drill = pad.pad.drill;
      if (drill <= 0) continue;
      final plated = pad.pad.type == PadType.thruHole;
      holes.add((pad.position, drill, pad.label));
      final minimum = plated ? preset.minPthDrill : preset.minNpthDrill;
      if (drill < minimum - 1e-9) {
        add(
          DrcRule.drillSize,
          '${pad.label} is drilled ${mm(drill)}, below $house\'s '
          '${mm(minimum)} for ${plated ? 'plated' : 'unplated'} holes',
          pad.position,
          netId: pad.netId,
        );
      }
      if (plated) {
        final ring = (math.min(pad.pad.sizeX, pad.pad.sizeY) - drill) / 2;
        if (ring < preset.minPthRing - 1e-9) {
          add(
            DrcRule.annularRing,
            '${pad.label} leaves ${mm(ring)} of copper round its hole; '
            '$house asks for ${mm(preset.minPthRing)}',
            pad.position,
            severity: DrcSeverity.warning,
            netId: pad.netId,
          );
        }
      }
    }
  }
  for (var i = 0; i < holes.length; i++) {
    for (var j = i + 1; j < holes.length; j++) {
      final (a, da, na) = holes[i];
      final (b, db, nb) = holes[j];
      final gap = (a - b).distance - (da + db) / 2;
      // Holes on top of each other are one hole drawn twice, not a gap.
      if ((a - b).distance < 1e-6) continue;
      if (gap < preset.minHoleSpacing - 1e-9) {
        add(
          DrcRule.holeSpacing,
          '$na and $nb are ${mm(math.max(0, gap))} apart, hole to hole; '
          '$house needs ${mm(preset.minHoleSpacing)}',
          Offset.lerp(a, b, 0.5)!,
        );
      }
    }
  }

  // Copper near the milled edge.
  final outline = scene.outline.kind == BoardOutlineKind.circle
      ? null
      : scene.outline.path;
  double toEdge(Offset p) {
    if (outline == null) {
      return (scene.outline.radius - (p - scene.outline.center).distance).abs();
    }
    var best = double.infinity;
    for (var i = 0; i < outline.length; i++) {
      best = math.min(
        best,
        _distanceToSegment(p, outline[i], outline[(i + 1) % outline.length]),
      );
    }
    return best;
  }

  for (final track in scene.tracks) {
    for (final end in [
      Offset(track.startX, track.startY),
      Offset(track.endX, track.endY),
    ]) {
      final gap = toEdge(end) - track.width / 2;
      if (gap < preset.copperToEdge - 1e-9) {
        add(
          DrcRule.edgeClearance,
          'A track comes within ${mm(math.max(0, gap))} of the board edge; '
          '$house needs ${mm(preset.copperToEdge)}',
          end,
          netId: track.netId,
        );
        break;
      }
    }
  }
  for (final footprint in scene.footprints) {
    for (final pad in footprint.pads) {
      final reach = math.max(pad.pad.sizeX, pad.pad.sizeY) / 2;
      final gap = toEdge(pad.position) - reach;
      if (gap < preset.copperToEdge - 1e-9) {
        add(
          DrcRule.edgeClearance,
          '${pad.label} comes within ${mm(math.max(0, gap))} of the board '
          'edge; $house needs ${mm(preset.copperToEdge)}',
          pad.position,
          severity: DrcSeverity.warning,
          netId: pad.netId,
        );
      }
    }
  }

  // Silkscreen too small to print, or printed onto pads.
  for (final text in scene.texts) {
    if (text.size < preset.minSilkHeight - 1e-9) {
      add(
        DrcRule.silkscreen,
        '"${text.content}" is ${mm(text.size)} tall; $house prints '
        '${mm(preset.minSilkHeight)} and up',
        text.position,
        severity: DrcSeverity.warning,
      );
    }
  }
  for (final footprint in scene.footprints) {
    if (footprint.ref.labelHidden) continue;
    final height = footprint.ref.labelSize;
    if (height < preset.minSilkHeight - 1e-9) {
      add(
        DrcRule.silkscreen,
        '${footprint.part.reference}\'s label is ${mm(height)} tall; '
        '$house prints ${mm(preset.minSilkHeight)} and up',
        footprint.labelPosition,
        severity: DrcSeverity.warning,
      );
    }
    // The label's box, roughly: stroke-font characters run about 0.8 of
    // their height wide.
    final label = Rect.fromCenter(
      center: footprint.labelPosition,
      width: footprint.part.reference.length * height * 0.8,
      height: height,
    );
    final onPad = scene.footprints
        .expand((f) => f.pads)
        .where(
          (pad) =>
              pad.layers.any((l) => l.isCopper) &&
              label
                  .inflate(preset.silkToPad)
                  .overlaps(
                    Rect.fromCenter(
                      center: pad.position,
                      width: pad.pad.sizeX,
                      height: pad.pad.sizeY,
                    ),
                  ),
        )
        .firstOrNull;
    if (onPad != null) {
      add(
        DrcRule.silkscreen,
        '${footprint.part.reference}\'s label sits on ${onPad.label}; the '
        'house will clip it off the pad',
        footprint.labelPosition,
        severity: DrcSeverity.warning,
      );
    }
  }

  return out;
}

/// Pads a pour surrounds but cannot join, from every copper layer.
List<DrcViolation> pourViolations(BoardScene scene) => [
  for (final layer in scene.board.copperLayers)
    for (final warning in PourFill.plan(scene, layer).warnings)
      DrcViolation(
        rule: DrcRule.pourConnection,
        severity: DrcSeverity.warning,
        message: warning,
        position: scene.outlineBounds.center,
      ),
];

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (length2 < 1e-12) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}
