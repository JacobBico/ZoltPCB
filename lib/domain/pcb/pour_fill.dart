import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'board_layer.dart';
import 'board_outline.dart';
import 'board_edge.dart';
import 'board_scene.dart';
import 'board_zone.dart';
import 'footprint.dart';
import 'pour_copper.dart';

/// One shape a pour is built from.
sealed class PourShape {
  const PourShape();
}

/// A filled polygon, with an optional hole cut in it.
class PourRegion extends PourShape {
  const PourRegion(this.points, {this.hole});

  final List<Offset> points;

  /// A polygon inside [points] left unfilled. Used once: the board, cut out
  /// of a frame round it, so everything off the board can be cleared.
  final List<Offset>? hole;
}

/// A line of a given width, round-ended, through [points].
class PourStroke extends PourShape {
  const PourStroke(this.points, this.width, {this.closed = false});

  final List<Offset> points;
  final double width;
  final bool closed;
}

/// A pad's copper, grown by [grow] on every side.
class PourPad extends PourShape {
  const PourPad(this.pad, this.grow);

  final PlacedPad pad;
  final double grow;
}

/// A round dot: a via, grown or not.
class PourDisc extends PourShape {
  const PourDisc(this.centre, this.diameter);

  final Offset centre;
  final double diameter;
}

/// A shape, and whether it adds copper or takes it away.
class PourStep {
  const PourStep.dark(this.shape, {this.netId}) : clear = false;
  const PourStep.clear(this.shape) : clear = true, netId = null;

  final PourShape shape;
  final bool clear;

  /// The net copper laid by a dark step is on; null for a net-less pour.
  final String? netId;
}

/// Something about a layer's pours worth telling the user, and where.
class PourWarning {
  const PourWarning(this.message, this.position, {this.island = false});

  final String message;
  final Offset position;

  /// Fill taken away because it reached none of its net's copper, rather
  /// than a pad or via the pour could not join.
  final bool island;

  @override
  String toString() => message;
}

/// What a layer's pours come to: the steps that draw them, in order, and
/// anything worth telling the user.
class PourPlan {
  const PourPlan(
    this.steps,
    this.warnings, {
    this.joins = const [],
    this.islandClears = const [],
  });

  static const empty = PourPlan([], []);

  final List<PourStep> steps;
  final List<PourWarning> warnings;

  /// The pads, tracks and vias each connected piece of fill joins: what
  /// lets a pour count as routing.
  final List<PourJoin> joins;

  /// The steps at the end of [steps] that take the islands away.
  final List<PourStep> islandClears;

  bool get isEmpty => steps.isEmpty;
}

/// Fills a layer's copper pours, the way a board house will see them.
///
/// Worked out as an order of drawing rather than as polygon arithmetic,
/// because both places a pour ends up can draw in that order: a Gerber has
/// dark and clear polarity, and the canvas can clear inside a layer. So the
/// pour on screen and the pour in the fab files are the same steps.
///
/// In order:
///  1. each pour, lowest priority first; before a pour is laid, any other
///     net's pour under it is cut back by the clearance, so two nets never
///     touch;
///  2. everything off the board, a margin inside its edge, and any cutout,
///     cleared — no copper at the milled edge;
///  3. every other net's pad, track and via cut out with its clearance;
///  4. each same-net pad on a thermal pour ringed with its thermal gap, and
///  5. joined back by spokes that land inside the pour;
///  6. any piece of fill left touching none of its own net's copper —
///     cut off by a track, say — cleared, as KiCad removes islands.
///
/// The pads, tracks and vias themselves are drawn after, by the caller.
abstract final class PourFill {
  /// The smallest copper-to-edge gap, whatever the rules say: routers mill
  /// a little wide, and copper at the edge is copper shorted to the next
  /// board in the panel.
  static const minEdgeClearance = 0.3;

  /// Plans already made, per scene: the canvas, the design check and the
  /// Gerbers all ask for the same ones, and a plan is not cheap.
  static final _plans = Expando<Map<CopperLayer, PourPlan>>();

  static PourPlan plan(BoardScene scene, CopperLayer layer) =>
      (_plans[scene] ??= {}).putIfAbsent(layer, () => _plan(scene, layer));

  /// Hands the plans made for [from] to [to], a scene that differs from it
  /// only in what a plan does not read.
  static void carry(BoardScene from, BoardScene to) {
    final plans = _plans[from];
    if (plans != null) _plans[to] = {...?_plans[to], ...plans};
  }

  static PourPlan _plan(BoardScene scene, CopperLayer layer) {
    final indexed = [
      for (final (i, zone) in scene.zones.indexed)
        if (zone.isValid && zone.layer == layer.layer && !zone.keepout)
          (i, zone),
    ];
    // Areas that keep copper out of themselves. Not filled — a keepout is
    // ground claimed, not ground poured — but they do cut back whatever is
    // poured over them.
    final keepouts = [
      for (final zone in scene.zones)
        if (zone.isValid && zone.keepout && zone.noPours) zone,
    ];
    if (indexed.isEmpty) return PourPlan.empty;
    // Lowest priority first, so the higher one is laid last and wins;
    // equal priorities keep the order they were drawn in.
    indexed.sort(
      (a, b) => a.$2.priority != b.$2.priority
          ? a.$2.priority.compareTo(b.$2.priority)
          : a.$1.compareTo(b.$1),
    );
    final zones = [for (final (_, zone) in indexed) zone];

    final steps = <PourStep>[];
    final warnings = <PourWarning>[];
    // Nothing is poured past the board's bounding box, so the clear round
    // the outline never has to reach further than that — which is what
    // lets copies of the board sit side by side in a panel.
    final box = scene.outline.bounds;

    // 1. The pours.
    for (var i = 0; i < zones.length; i++) {
      final zone = zones[i];
      final points = clipToRect(zone.points, box);
      if (points.length < 3) continue;
      final under = [
        for (final earlier in zones.take(i))
          if (earlier.netId != zone.netId &&
              earlier.bounds
                  .inflate(earlier.clearance)
                  .overlaps(zone.bounds.inflate(zone.clearance)))
            earlier,
      ];
      if (under.isNotEmpty) {
        final gap = [
          zone.clearance,
          for (final z in under) z.clearance,
        ].reduce(math.max);
        steps
          ..add(PourStep.clear(PourRegion(points)))
          ..add(PourStep.clear(PourStroke(points, gap * 2, closed: true)));
      }
      steps.add(PourStep.dark(PourRegion(points), netId: zone.netId));
    }

    // 1b. Keepouts, cut out of everything poured so far.
    for (final keepout in keepouts) {
      final points = clipToRect(keepout.points, box);
      if (points.length < 3) continue;
      steps
        ..add(PourStep.clear(PourRegion(points)))
        ..add(
          PourStep.clear(
            PourStroke(points, keepout.clearance * 2, closed: true),
          ),
        );
    }

    // 2. The board's edge.
    final edgeGap = math.max(minEdgeClearance, scene.board.rules.clearance);
    final outline = _outlinePoints(scene.outline);
    // Just round the box: less than the edge margin, so a copy of the board
    // butted up against this one keeps its own copper.
    final frame = box.inflate(0.05);
    steps
      ..add(
        PourStep.clear(
          PourRegion([
            frame.topLeft,
            frame.topRight,
            frame.bottomRight,
            frame.bottomLeft,
          ], hole: outline),
        ),
      )
      ..add(PourStep.clear(PourStroke(outline, edgeGap * 2, closed: true)));
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      final shape = _edgePoints(edge);
      final closed = switch (edge.kind) {
        BoardEdgeKind.rectangle ||
        BoardEdgeKind.circle ||
        BoardEdgeKind.polygon => true,
        BoardEdgeKind.line || BoardEdgeKind.arc => false,
      };
      // A closed shape inside the board is a cutout: nothing in it.
      if (closed && _inside(scene.outline.bounds, edge.bounds)) {
        steps.add(PourStep.clear(PourRegion(shape)));
      }
      steps.add(PourStep.clear(PourStroke(shape, edgeGap * 2, closed: closed)));
    }

    // 3. Every other net, cut out.
    List<BoardZone> over(Rect box) => [
      for (final zone in zones)
        if (zone.bounds.overlaps(box)) zone,
    ];
    (bool, double) clearFor(String? netId, Rect box) {
      final near = over(box);
      if (near.isEmpty) return (false, 0);
      final foreign = netId == null || near.any((z) => z.netId != netId);
      final gap = [
        scene.clearanceFor(netId),
        for (final zone in near) zone.clearance,
      ].reduce(math.max);
      return (foreign, gap);
    }

    for (final track in scene.tracks) {
      if (track.layer != layer) continue;
      final a = Offset(track.startX, track.startY);
      final b = Offset(track.endX, track.endY);
      final (foreign, gap) = clearFor(
        track.netId,
        Rect.fromPoints(a, b).inflate(track.width + 1),
      );
      if (foreign) {
        steps.add(PourStep.clear(PourStroke([a, b], track.width + gap * 2)));
      }
    }
    // A via on the pour's own net joins it however the pour says: poured
    // solid, relieved by a ring and four spokes, or kept clear like anyone
    // else's. Solid is the default, and the reason is worth keeping in
    // mind: a via is never soldered, so it has nothing a thermal relief
    // protects — but a via under a part that is reworked with hot air is a
    // different matter, and a plane poured solid onto a grid of them is
    // very hard to get heat into.
    final thermalVias = <(Offset, double, BoardZone)>[];
    for (final via in scene.vias) {
      final at = Offset(via.x, via.y);
      final box = Rect.fromCircle(center: at, radius: via.diameter + 1);
      final own = zones
          .where(
            (z) => via.netId != null && z.netId == via.netId && z.contains(at),
          )
          .lastOrNull;
      final (foreign, gap) = clearFor(via.netId, box);
      if (foreign || own?.viaConnection == PadConnection.none) {
        steps.add(
          PourStep.clear(
            PourDisc(at, via.diameter + math.max(gap, own?.clearance ?? 0) * 2),
          ),
        );
      } else if (own != null && own.viaConnection == PadConnection.thermal) {
        thermalVias.add((at, via.diameter, own));
      }
    }

    final pads = [
      for (final footprint in scene.footprints)
        for (final pad in footprint.pads)
          if (pad.reaches(layer)) pad,
    ];
    final thermal = <(PlacedPad, BoardZone)>[];
    for (final pad in pads) {
      final reach = math.max(pad.pad.sizeX, pad.pad.sizeY);
      final box = Rect.fromCircle(center: pad.position, radius: reach + 1);
      // Its own pour, when it sits in one.
      final own = zones
          .where(
            (z) =>
                pad.netId != null &&
                z.netId == pad.netId &&
                z.contains(pad.position),
          )
          .lastOrNull;
      final (foreign, gap) = clearFor(pad.netId, box);
      if (foreign || own?.padConnection == PadConnection.none) {
        steps.add(
          PourStep.clear(PourPad(pad, math.max(gap, own?.clearance ?? 0))),
        );
      } else if (own != null && own.padConnection == PadConnection.thermal) {
        thermal.add((pad, own));
      }
    }

    // 4 and 5. Thermal reliefs: a ring, then spokes across it.
    for (final (pad, zone) in thermal) {
      steps.add(PourStep.clear(PourPad(pad, zone.thermalGap)));
    }
    for (final (at, diameter, zone) in thermalVias) {
      steps.add(PourStep.clear(PourDisc(at, diameter + zone.thermalGap * 2)));
    }
    for (final (at, diameter, zone) in thermalVias) {
      final half = diameter / 2;
      var landed = 0;
      for (final direction in const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
      ]) {
        final end =
            at + direction * (half + zone.thermalGap + zone.thermalSpoke);
        if (!zone.contains(end) ||
            !_insidePolygon(outline, end) ||
            _nearPolygon(outline, end, edgeGap + zone.thermalSpoke)) {
          continue;
        }
        steps.add(
          PourStep.dark(
            PourStroke([at, end], zone.thermalSpoke),
            netId: zone.netId,
          ),
        );
        landed++;
      }
      if (landed == 0) {
        warnings.add(
          PourWarning(
            'A via at ${at.dx.toStringAsFixed(1)}, '
            '${at.dy.toStringAsFixed(1)} is inside the ${zone.label} pour '
            'but no thermal spoke reaches it, so it is not connected',
            at,
          ),
        );
      }
    }
    for (final (pad, zone) in thermal) {
      final radians = pad.angle * math.pi / 180;
      final ux = Offset(math.cos(radians), -math.sin(radians));
      final uy = Offset(math.sin(radians), math.cos(radians));
      var landed = 0;
      for (final (direction, half) in [
        (ux, pad.pad.sizeX / 2),
        (-ux, pad.pad.sizeX / 2),
        (uy, pad.pad.sizeY / 2),
        (-uy, pad.pad.sizeY / 2),
      ]) {
        final end =
            pad.position +
            direction * (half + zone.thermalGap + zone.thermalSpoke);
        // A spoke only helps if it lands in copper: inside the pour and
        // clear of the board's edge margin.
        if (!zone.contains(end) ||
            !_insidePolygon(outline, end) ||
            _nearPolygon(outline, end, edgeGap + zone.thermalSpoke)) {
          continue;
        }
        steps.add(
          PourStep.dark(
            PourStroke([pad.position, end], zone.thermalSpoke),
            netId: zone.netId,
          ),
        );
        landed++;
      }
      if (landed == 0) {
        warnings.add(
          PourWarning(
            '${pad.label} is inside the ${zone.label} pour but no thermal '
            'spoke reaches it, so it is not connected',
            pad.position,
          ),
        );
      }
    }

    if (scene.previewOf case final saved?) {
      final islands = plan(saved, layer).islandClears;
      return PourPlan([...steps, ...islands], warnings, islandClears: islands);
    }

    // 6. Islands. The narrowest gap or spoke anything above could have
    // made sets how finely the fill is examined.
    final narrowest = [
      scene.board.rules.clearance,
      edgeGap,
      for (final zone in zones) ...[
        zone.clearance,
        if (zone.padConnection == PadConnection.thermal ||
            zone.viaConnection == PadConnection.thermal) ...[
          zone.thermalGap,
          zone.thermalSpoke,
        ],
      ],
      for (final keepout in keepouts) keepout.clearance,
      for (final netClass in scene.netClasses) ?netClass.clearance,
    ].where((gap) => gap > 0).fold(double.infinity, math.min);
    final copper = PourAnalysis.analyse(
      scene: scene,
      layer: layer,
      steps: steps,
      narrowest: narrowest.isFinite ? narrowest : 0.2,
    );
    final byNet = <String, List<PourIsland>>{};
    final islandClears = <PourStep>[];
    for (final island in copper.islands) {
      islandClears.addAll(island.clears);
      (byNet[island.netId] ??= []).add(island);
    }
    steps.addAll(islandClears);
    for (final MapEntry(key: netId, value: islands) in byNet.entries) {
      final name =
          zones.where((z) => z.netId == netId).firstOrNull?.label ?? netId;
      warnings.add(
        PourWarning(
          islands.length == 1
              ? 'A piece of the $name pour on ${layer.label} reaches none of '
                    'its net\'s copper, so it is left unfilled'
              : '${islands.length} pieces of the $name pour on '
                    '${layer.label} reach none of its net\'s copper, so they '
                    'are left unfilled',
          islands.first.position,
          island: true,
        ),
      );
    }

    return PourPlan(
      steps,
      warnings,
      joins: copper.joins,
      islandClears: islandClears,
    );
  }

  /// A pad's outline grown by [grow], for drawing a pad-shaped cut on a
  /// canvas. Matches the shapes the Gerber writer flashes.
  static Path padPath(PlacedPad pad, double grow) {
    final w = pad.pad.sizeX + grow * 2;
    final h = pad.pad.sizeY + grow * 2;
    final local = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final radius = switch (pad.pad.shape) {
      PadShape.circle || PadShape.oval => math.min(w, h) / 2,
      PadShape.roundrect =>
        math.min(pad.pad.sizeX, pad.pad.sizeY) * pad.pad.roundrectRatio + grow,
      _ => grow,
    };
    final shape = Path()
      ..addRRect(RRect.fromRectAndRadius(local, Radius.circular(radius)));
    final radians = -pad.angle * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return shape.transform(
      Float64List.fromList([
        cos, sin, 0, 0, //
        -sin, cos, 0, 0,
        0, 0, 1, 0,
        pad.position.dx, pad.position.dy, 0, 1,
      ]),
    );
  }

  /// The board outline as a closed run of points, a circle finely enough
  /// that the edge margin covers the difference.
  static List<Offset> _outlinePoints(BoardOutline outline) =>
      outline.kind == BoardOutlineKind.circle
      ? _circle(outline.center, outline.radius)
      : outline.path;

  static List<Offset> _edgePoints(BoardEdge edge) => switch (edge.kind) {
    BoardEdgeKind.circle => _circle(edge.center, edge.radius),
    BoardEdgeKind.rectangle => () {
      final r = Rect.fromPoints(edge.points[0], edge.points[1]);
      return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    }(),
    BoardEdgeKind.polygon => edge.points,
    BoardEdgeKind.line => [edge.start, edge.end],
    BoardEdgeKind.arc => _flatten(edge.arcPath),
  };

  static List<Offset> _circle(Offset centre, double radius) => [
    for (var i = 0; i < 256; i++)
      centre +
          Offset(
            radius * math.cos(i * math.pi * 2 / 256),
            radius * math.sin(i * math.pi * 2 / 256),
          ),
  ];

  static List<Offset> _flatten(Path path) {
    final points = <Offset>[];
    for (final metric in path.computeMetrics()) {
      final steps = math.max(2, (metric.length / 0.1).ceil());
      for (var i = 0; i <= steps; i++) {
        points.add(
          metric.getTangentForOffset(metric.length * i / steps)!.position,
        );
      }
    }
    return points;
  }

  /// [polygon] cut down to what lies inside [rect] (Sutherland–Hodgman).
  static List<Offset> clipToRect(List<Offset> polygon, Rect rect) {
    var out = polygon;
    for (final (inside, cross)
        in <(bool Function(Offset), Offset Function(Offset, Offset))>[
          ((p) => p.dx >= rect.left, (a, b) => _atX(a, b, rect.left)),
          ((p) => p.dx <= rect.right, (a, b) => _atX(a, b, rect.right)),
          ((p) => p.dy >= rect.top, (a, b) => _atY(a, b, rect.top)),
          ((p) => p.dy <= rect.bottom, (a, b) => _atY(a, b, rect.bottom)),
        ]) {
      if (out.isEmpty) break;
      final input = out;
      out = [];
      for (var i = 0; i < input.length; i++) {
        final a = input[(i + input.length - 1) % input.length];
        final b = input[i];
        if (inside(b)) {
          if (!inside(a)) out.add(cross(a, b));
          out.add(b);
        } else if (inside(a)) {
          out.add(cross(a, b));
        }
      }
    }
    return out;
  }

  static Offset _atX(Offset a, Offset b, double x) =>
      Offset(x, a.dy + (b.dy - a.dy) * (x - a.dx) / (b.dx - a.dx));

  static Offset _atY(Offset a, Offset b, double y) =>
      Offset(a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy), y);

  static bool _inside(Rect outer, Rect inner) =>
      inner.left >= outer.left - 1e-6 &&
      inner.top >= outer.top - 1e-6 &&
      inner.right <= outer.right + 1e-6 &&
      inner.bottom <= outer.bottom + 1e-6;

  static bool _insidePolygon(List<Offset> polygon, Offset point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _nearPolygon(List<Offset> polygon, Offset point, double reach) {
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (_distanceToSegment(point, a, b) < reach) return true;
    }
    return false;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 < 1e-12) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}
