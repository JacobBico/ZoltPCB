import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'board_layer.dart';
import 'board_outline.dart';
import 'board_scene.dart';
import 'drc.dart';
import 'track_angles.dart';

/// Routes a run of track round whatever is in the way.
///
/// KiCad calls this "walk around": the track being drawn goes past other
/// nets' copper at the clearance instead of through it, and nothing already
/// on the board is moved. That last part is the point — shoving other
/// tracks aside is a different, much bigger tool, and not one a phone
/// needs to be surprised by.
///
/// The search is a small maze route over a grid laid over the board, on 45°
/// and 90° steps with a price on every bend, so the answer comes back as a
/// few straight runs rather than a staircase. The runs are then pulled
/// taut: any two corners that can be joined by a straight run and a 45°
/// without hitting anything are.
///
/// The map of where copper may go is the expensive half, and it does not
/// change while a finger is moving — so it lives in a [WalkaroundField]
/// that the caller keeps for as long as the board, layer, net and width
/// stay the same. Rebuilding it per frame is what made this unusable.
abstract final class WalkaroundRouter {
  /// The corners from [from] to [to], ending at [to] and not including
  /// [from], that keep a track of [width] clear of every other net on
  /// [layer]. Null when there is no way round — the caller then draws
  /// straight and lets the clash show.
  static List<Offset>? route(
    BoardScene scene, {
    required Offset from,
    required Offset to,
    required double width,
    required CopperLayer layer,
    String? netId,
  }) => routeOn(
    WalkaroundField.of(scene, layer: layer, width: width, netId: netId),
    from: from,
    to: to,
  );

  /// The same, over a map already built.
  static List<Offset>? routeOn(
    WalkaroundField field, {
    required Offset from,
    required Offset to,
  }) {
    if ((to - from).distance < 1e-6) return const [];

    // Already clear the simple way: nothing to walk round, and no search.
    final direct = legalCorners(from, to, TrackAngleLock.deg45);
    if (field.clear([from, ...direct], from: from, to: to)) return direct;

    field.reachFrom(from);
    final cells = field.pathTo(to);
    if (cells == null) return null;

    // Cells to corners. The grid is laid out on the board, not on the
    // corner the run leaves from, so the first cell is up to half a cell
    // away from it in some arbitrary direction — and left in, that is a
    // tenth of a millimetre of track going nowhere before the route
    // starts. It is dropped.
    final corners = <Offset>[from];
    for (final cell in cells) {
      if ((cell - from).distance < field.step * 1.01) continue;
      if ((cell - corners.last).distance > 1e-6) corners.add(cell);
    }
    corners.addAll(legalCorners(corners.last, to, TrackAngleLock.deg45));

    return _pullTaut(
      field,
      _dedupe(corners),
      from: from,
      to: to,
    ).skip(1).toList();
  }

  /// Joins corners that can see each other, from the start forwards.
  ///
  /// A shortcut is only taken if it is no longer than the stretch of route
  /// it replaces. Without that test the pull grabs the furthest corner it
  /// can see, and on 45s the straight-and-a-diagonal to a far corner can
  /// be far longer than following the corridor — which reads as the track
  /// swerving out to one side for no reason and coming back.
  static List<Offset> _pullTaut(
    WalkaroundField field,
    List<Offset> corners, {
    required Offset from,
    required Offset to,
  }) {
    if (corners.length <= 2) return corners;
    final along = <double>[0];
    for (var i = 1; i < corners.length; i++) {
      along.add(along[i - 1] + (corners[i] - corners[i - 1]).distance);
    }

    final out = <Offset>[corners.first];
    var i = 0;
    while (i < corners.length - 1) {
      var reached = i + 1;
      // Even the step to the very next corner goes through the angle
      // machinery: the run starts at a pad, which is nowhere near a cell
      // centre, so the first hop off it is at whatever angle it happens
      // to be unless it is made legal here.
      List<Offset> bridge = legalCorners(
        corners[i],
        corners[i + 1],
        TrackAngleLock.deg45,
      );
      for (var j = corners.length - 1; j > i + 1; j--) {
        final legs = legalCorners(corners[i], corners[j], TrackAngleLock.deg45);
        var length = 0.0;
        var at = corners[i];
        for (final leg in legs) {
          length += (leg - at).distance;
          at = leg;
        }
        if (length > along[j] - along[i] + 1e-6) continue;
        if (field.clear([corners[i], ...legs], from: from, to: to)) {
          reached = j;
          bridge = legs;
          break;
        }
      }
      out.addAll(bridge);
      i = reached;
    }
    return _dedupe(out);
  }

  static List<Offset> _dedupe(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      // A nanometre is not a distance on a board; two corners that close
      // are one corner and a zero-length piece of copper.
      if (out.isNotEmpty && (out.last - p).distance < 1e-6) continue;
      // Three in a line are two.
      if (out.length >= 2) {
        final a = out[out.length - 2];
        final b = out.last;
        final cross =
            (b.dx - a.dx) * (p.dy - b.dy) - (b.dy - a.dy) * (p.dx - b.dx);
        final dot =
            (b.dx - a.dx) * (p.dx - b.dx) + (b.dy - a.dy) * (p.dy - b.dy);
        if (cross.abs() < 1e-9 && dot > 0) {
          out[out.length - 1] = p;
          continue;
        }
      }
      out.add(p);
    }
    return out;
  }
}

/// Where a track of one width, on one layer, on one net may put its centre.
///
/// Built once for a board and kept: every cell of it is the answer to
/// "would copper here be too close to another net, or too near the edge",
/// which does not change as the crosshair moves.
class WalkaroundField {
  WalkaroundField._({
    required this.scene,
    required this.layer,
    required this.width,
    required this.netId,
    required this.origin,
    required this.step,
    required this.columns,
    required this.rows,
    required Uint8List blocked,
  }) : _blocked = blocked;

  /// The board this was built from, compared by identity: a new scene
  /// object means the board changed under it.
  final BoardScene scene;
  final CopperLayer layer;
  final double width;
  final String? netId;

  final Offset origin;
  final double step;
  final int columns;
  final int rows;
  final Uint8List _blocked;

  /// Whether this map still answers for [scene] and the rest.
  bool matches(
    BoardScene scene,
    CopperLayer layer,
    double width,
    String? netId,
  ) =>
      identical(this.scene, scene) &&
      this.layer == layer &&
      this.width == width &&
      this.netId == netId;

  /// A grid fine enough to route on, coarse enough to hold. There is no
  /// point resolving the board finer than half the gap a track has to keep
  /// from other copper — nothing thinner than that is a way through — and
  /// no point going coarser than a tenth of a millimetre, which is already
  /// finer than any board this draws.
  static const _maxCells = 1200000;

  static WalkaroundField of(
    BoardScene scene, {
    required CopperLayer layer,
    required double width,
    String? netId,
  }) {
    final board = scene.outline.bounds.inflate(1);
    var step = math.min(
      0.25,
      math.max(0.1, (width / 2 + scene.board.rules.clearance) / 2),
    );
    while ((board.width / step) * (board.height / step) > _maxCells) {
      step *= 1.25;
    }
    final columns = (board.width / step).ceil() + 1;
    final rows = (board.height / step).ceil() + 1;
    final origin = board.topLeft;
    final blocked = Uint8List(columns * rows);

    _blockOffBoard(
      scene,
      blocked,
      origin: origin,
      step: step,
      columns: columns,
      rows: rows,
      reach: width / 2 + scene.board.rules.clearance,
    );
    _blockCopper(
      scene,
      blocked,
      origin: origin,
      step: step,
      columns: columns,
      rows: rows,
      layer: layer,
      width: width,
      netId: netId,
    );

    return WalkaroundField._(
      scene: scene,
      layer: layer,
      width: width,
      netId: netId,
      origin: origin,
      step: step,
      columns: columns,
      rows: rows,
      blocked: blocked,
    );
  }

  /// Off the board, or nearer its edge than a track may go.
  ///
  /// Worked out as a bitmap of what is on the board at all, then probed
  /// four ways across that bitmap — the shape is asked about once per cell
  /// rather than five times, which on a polygon outline is the difference
  /// between a blink and a stall.
  static void _blockOffBoard(
    BoardScene scene,
    Uint8List blocked, {
    required Offset origin,
    required double step,
    required int columns,
    required int rows,
    required double reach,
  }) {
    final outline = scene.outline;
    final on = Uint8List(columns * rows);

    switch (outline.kind) {
      case BoardOutlineKind.rectangle:
        final rect = outline.rect;
        for (var r = 0; r < rows; r++) {
          final y = origin.dy + r * step;
          if (y < rect.top || y > rect.bottom) continue;
          for (var c = 0; c < columns; c++) {
            final x = origin.dx + c * step;
            if (x >= rect.left && x <= rect.right) on[r * columns + c] = 1;
          }
        }
      case BoardOutlineKind.circle:
        final centre = outline.center;
        final radius = outline.radius;
        for (var r = 0; r < rows; r++) {
          final dy = origin.dy + r * step - centre.dy;
          if (dy.abs() > radius) continue;
          final half = math.sqrt(radius * radius - dy * dy);
          final c0 = math.max(
            0,
            ((centre.dx - half - origin.dx) / step).ceil(),
          );
          final c1 = math.min(
            columns - 1,
            ((centre.dx + half - origin.dx) / step).floor(),
          );
          for (var c = c0; c <= c1; c++) {
            on[r * columns + c] = 1;
          }
        }
      case BoardOutlineKind.polygon:
        // One scanline per row, rather than one ray cast per cell.
        final points = outline.points;
        if (points.length >= 3) {
          final crossings = <double>[];
          for (var r = 0; r < rows; r++) {
            final y = origin.dy + r * step;
            crossings.clear();
            for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
              final a = points[i];
              final b = points[j];
              if ((a.dy > y) == (b.dy > y)) continue;
              crossings.add((b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy) + a.dx);
            }
            if (crossings.length < 2) continue;
            crossings.sort();
            for (var k = 0; k + 1 < crossings.length; k += 2) {
              final c0 = math.max(
                0,
                ((crossings[k] - origin.dx) / step).ceil(),
              );
              final c1 = math.min(
                columns - 1,
                ((crossings[k + 1] - origin.dx) / step).floor(),
              );
              for (var c = c0; c <= c1; c++) {
                on[r * columns + c] = 1;
              }
            }
          }
        }
    }

    final k = math.max(1, (reach / step).round());
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final i = r * columns + c;
        if (on[i] == 0) {
          blocked[i] = 1;
          continue;
        }
        if (c - k < 0 ||
            c + k >= columns ||
            r - k < 0 ||
            r + k >= rows ||
            on[i - k] == 0 ||
            on[i + k] == 0 ||
            on[i - k * columns] == 0 ||
            on[i + k * columns] == 0) {
          blocked[i] = 1;
        }
      }
    }
  }

  /// Other nets' copper, each grown by the gap it needs plus half the
  /// track. Copper on the route's own net is a place to go, not avoid.
  static void _blockCopper(
    BoardScene scene,
    Uint8List blocked, {
    required Offset origin,
    required double step,
    required int columns,
    required int rows,
    required CopperLayer layer,
    required double width,
    required String? netId,
  }) {
    final token = layer.layer.token;
    final ownClearance = scene.clearanceFor(netId);
    for (final item in copperItems(scene)) {
      if (!item.layers.contains(token)) continue;
      if (netId != null && item.netId == netId) continue;
      final reach =
          math.max(ownClearance, scene.clearanceFor(item.netId)) +
          (width + item.width) / 2;
      final box = Rect.fromPoints(item.a, item.b).inflate(reach);
      final c0 = math.max(0, ((box.left - origin.dx) / step).floor());
      final c1 = math.min(columns - 1, ((box.right - origin.dx) / step).ceil());
      final r0 = math.max(0, ((box.top - origin.dy) / step).floor());
      final r1 = math.min(rows - 1, ((box.bottom - origin.dy) / step).ceil());
      for (var r = r0; r <= r1; r++) {
        final y = origin.dy + r * step;
        for (var c = c0; c <= c1; c++) {
          final i = r * columns + c;
          if (blocked[i] != 0) continue;
          if (distanceToSegment(
                Offset(origin.dx + c * step, y),
                item.a,
                item.b,
              ) <
              reach - 1e-9) {
            blocked[i] = 1;
          }
        }
      }
    }
  }

  Offset centre(int cell) => Offset(
    origin.dx + (cell % columns) * step,
    origin.dy + (cell ~/ columns) * step,
  );

  int cellOf(Offset p) {
    final c = ((p.dx - origin.dx) / step).round().clamp(0, columns - 1);
    final r = ((p.dy - origin.dy) / step).round().clamp(0, rows - 1);
    return r * columns + c;
  }

  /// Whether a run through [points] keeps to free cells, sampled finer than
  /// the grid so a diagonal cannot slip between two blocked cells. The two
  /// ends of the route being drawn are always allowed: a pad on the same
  /// net often sits right beside another net's.
  bool clear(List<Offset> points, {required Offset from, required Offset to}) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final samples = math.max(1, ((b - a).distance / (step * 0.5)).ceil());
      for (var k = 0; k <= samples; k++) {
        final p = Offset.lerp(a, b, k / samples)!;
        if (!_freeAt(p, from, to)) return false;
      }
    }
    return true;
  }

  /// How close to an end a cell may sit and still be walked through
  /// whatever else is there: just enough to get off the pad.
  double get _escape => step * 1.5;

  bool _freeAt(Offset p, Offset from, Offset to) {
    final c = ((p.dx - origin.dx) / step).round();
    final r = ((p.dy - origin.dy) / step).round();
    if (c < 0 || r < 0 || c >= columns || r >= rows) return false;
    if (_blocked[r * columns + c] == 0) return true;
    return (p - from).distance <= _escape || (p - to).distance <= _escape;
  }

  static const _moves = [
    (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), //
  ];

  /// How many cells a flood may reach before the answer stops being worth
  /// waiting for.
  static const _floodBudget = 400000;

  /// What a step costs, as whole numbers: five across, seven cornerwise.
  ///
  /// Seven fifths is 1.4, within a per cent of the square root of two, and
  /// whole numbers are what let the flood be sorted into a handful of
  /// buckets instead of a heap. Counting every step as one — which is what
  /// a plain flood does — makes a diagonal free, and a route that gets its
  /// diagonals for nothing wanders off sideways early and comes back
  /// later. That is the swerve.
  static const _straight = 5;
  static const _diagonal = 7;

  Offset? _grown;
  int _grownCell = -1;
  Uint16List? _reach;

  /// How far every cell is from the corner the run is leaving, and zero
  /// where it cannot be got to at all.
  ///
  /// This is the expensive half of the search and it is done once per
  /// corner placed, not once per frame: the end being dragged moves, the
  /// end being left does not. Everything the crosshair does after this is
  /// a walk back down the slope, which costs about as much as drawing the
  /// line does.
  void reachFrom(Offset from) {
    if (_grown == from && _reach != null) return;
    final reach = _reach ??= Uint16List(columns * rows);
    reach.fillRange(0, reach.length, 0);
    _grown = from;

    final start = _grownCell = cellOf(from);
    // Dial's buckets: every step costs five or seven, so eight rings of
    // cells are enough to hold the whole frontier in order.
    final buckets = List.generate(_diagonal + 1, (_) => <int>[]);
    reach[start] = 1;
    buckets[0].add(start);
    var spent = 0;
    for (var distance = 0; distance < 65000 - _diagonal; distance++) {
      final bucket = buckets[distance % (_diagonal + 1)];
      if (bucket.isEmpty) {
        // Nothing left anywhere: the frontier has run out.
        if (buckets.every((b) => b.isEmpty)) break;
        continue;
      }
      for (final here in bucket) {
        // Reached again since, by a shorter way: that one did the work.
        if (reach[here] != distance + 1) continue;
        if (++spent > _floodBudget) return;
        final c = here % columns;
        final r = here ~/ columns;
        for (var h = 0; h < 8; h++) {
          final (dc, dr) = _moves[h];
          final nc = c + dc;
          final nr = r + dr;
          if (nc < 0 || nc >= columns || nr < 0 || nr >= rows) continue;
          final next = nr * columns + nc;
          if (!_freeCell(next, start)) continue;
          // A diagonal that squeezes between two blocked cells is a
          // diagonal through the corner of both.
          if (dc != 0 &&
              dr != 0 &&
              (!_freeCell(r * columns + nc, start) ||
                  !_freeCell(nr * columns + c, start))) {
            continue;
          }
          final step = (dc != 0 && dr != 0) ? _diagonal : _straight;
          final through = distance + step;
          final already = reach[next];
          if (already != 0 && already - 1 <= through) continue;
          reach[next] = through + 1;
          buckets[through % (_diagonal + 1)].add(next);
        }
      }
      bucket.clear();
    }
  }

  /// A ring of one cell round the corner being left, so a run can get off a
  /// pad another net's copper is pressed against.
  bool _freeCell(int cell, int escape) {
    if (_blocked[cell] == 0) return true;
    final dc = (cell % columns) - (escape % columns);
    final dr = (cell ~/ columns) - (escape ~/ columns);
    return dc.abs() <= 1 && dr.abs() <= 1;
  }

  /// The cell centres from the corner [reachFrom] grew from to [to], or
  /// null when there is no way there.
  ///
  /// Walked back down the slope the flood left, taking the straight-on
  /// neighbour wherever one is exactly a step nearer home. Every path this
  /// finds is a shortest one; the preference for carrying straight on only
  /// decides which of the shortest paths comes back, and it is what turns
  /// a staircase into a few long runs.
  List<Offset>? pathTo(Offset to) {
    final reach = _reach;
    if (reach == null) return null;
    var here = cellOf(to);
    if (reach[here] == 0) {
      // Walled in where it was aimed: start from the nearest cell that
      // is not, and let the last leg cover the rest.
      final c = here % columns;
      final r = here ~/ columns;
      var best = -1;
      var bestDistance = 0;
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          final nc = c + dc;
          final nr = r + dr;
          if (nc < 0 || nc >= columns || nr < 0 || nr >= rows) continue;
          final cell = nr * columns + nc;
          final at = reach[cell];
          if (at == 0) continue;
          if (best == -1 || at < bestDistance) {
            best = cell;
            bestDistance = at;
          }
        }
      }
      if (best == -1) return null;
      here = best;
    }

    final back = <Offset>[centre(here)];
    var heading = -1;
    while (reach[here] > 1) {
      final at = reach[here];
      final c = here % columns;
      final r = here ~/ columns;
      var taken = -1;
      var takenHeading = -1;
      for (var turn = 0; turn < 8 && taken == -1; turn++) {
        // Straight on first, then the gentlest turn away from it.
        final order = heading == -1
            ? turn
            : (heading + ((turn.isEven ? 1 : -1) * ((turn + 1) ~/ 2))) % 8;
        final h = (order + 8) % 8;
        final (dc, dr) = _moves[h];
        final nc = c + dc;
        final nr = r + dr;
        if (nc < 0 || nc >= columns || nr < 0 || nr >= rows) continue;
        final cell = nr * columns + nc;
        final step = (dc != 0 && dr != 0) ? _diagonal : _straight;
        if (reach[cell] == 0 || reach[cell] + step != at) continue;
        if (dc != 0 &&
            dr != 0 &&
            (!_freeCell(r * columns + nc, _grownCell) ||
                !_freeCell(nr * columns + c, _grownCell))) {
          continue;
        }
        taken = cell;
        takenHeading = h;
      }
      if (taken == -1) return null;
      here = taken;
      heading = takenHeading;
      back.add(centre(here));
    }
    return back.reversed.toList();
  }
}
