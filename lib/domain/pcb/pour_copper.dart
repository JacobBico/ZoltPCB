import 'dart:math' as math;
import 'dart:ui';

import 'board.dart';
import 'board_layer.dart';
import 'board_scene.dart';
import 'footprint.dart';
import 'pour_fill.dart';

/// Copper a pour joins together on one layer: the pads, tracks and vias one
/// connected piece of its fill touches.
class PourJoin {
  const PourJoin({
    required this.netId,
    required this.layer,
    this.pads = const [],
    this.tracks = const [],
    this.vias = const [],
  });

  final String netId;
  final CopperLayer layer;
  final List<PlacedPad> pads;
  final List<Track> tracks;
  final List<Via> vias;

  int get size => pads.length + tracks.length + vias.length;
}

/// A piece of a pour's fill that touches none of its own net's copper, and
/// the clears that take it away.
class PourIsland {
  const PourIsland({
    required this.netId,
    required this.position,
    required this.clears,
  });

  final String netId;

  /// Somewhere inside it, to point the user at.
  final Offset position;

  final List<PourStep> clears;
}

/// What the fill of one layer comes to as copper.
class PourCopper {
  const PourCopper({required this.joins, required this.islands});

  static const empty = PourCopper(joins: [], islands: []);

  final List<PourJoin> joins;
  final List<PourIsland> islands;
}

/// Works out the copper a list of pour steps actually leaves, and what is
/// connected to what.
///
/// The steps are drawn one horizontal line at a time. Along a line every
/// shape is worked out exactly, as the spans of x it covers, and each step
/// paints or clears those spans in order — so what survives on the line is
/// the fill, labelled with its net. Spans on neighbouring lines that
/// overlap are the same piece of copper. The lines are spaced well inside
/// the narrowest gap and the narrowest spoke on the layer, so a gap can
/// never be stepped over and a spoke can never be missed.
///
/// This is the same fill the canvas and the Gerbers draw, not a second
/// opinion on it: it reads the very steps they do.
abstract final class PourAnalysis {
  /// Finer than this and a big board costs more than it tells; coarser and
  /// thin necks start to be guessed at.
  static const _minPitch = 0.005;
  static const _maxPitch = 0.1;

  /// A line count no real board reaches. Past it the analysis is skipped
  /// rather than made coarse enough to be wrong.
  static const _maxRows = 60000;

  static const _eps = 1e-9;

  /// Analyses [steps], whose dark steps carry their net in [PourStep.netId].
  ///
  /// [narrowest] is the smallest gap or spoke the steps contain: every
  /// clearance, thermal gap and spoke width on the layer. Returns
  /// [PourCopper.empty] when there is nothing poured.
  static PourCopper analyse({
    required BoardScene scene,
    required CopperLayer layer,
    required List<PourStep> steps,
    required double narrowest,
  }) {
    if (!steps.any((s) => !s.clear)) return PourCopper.empty;

    final bounds = _boundsOf(steps.where((s) => !s.clear).map((s) => s.shape));
    if (bounds == null || bounds.isEmpty) return PourCopper.empty;

    final pitch = (narrowest / 3).clamp(_minPitch, _maxPitch);
    // Gaps finer than the finest spacing cannot be promised to be seen, so
    // nothing is taken away as an island on the strength of them.
    final canRemoveIslands = narrowest / 3 >= _minPitch;
    final rowCount = (bounds.height / pitch).ceil() + 1;
    if (rowCount > _maxRows) return PourCopper.empty;
    final top = bounds.top;
    double rowY(int i) => top + i * pitch;

    // Labels: 1.. for nets. Each net-less pour gets a label of its own and
    // is never treated as an island — it has nothing to be joined to.
    final labels = <String, int>{};
    final netOfLabel = <int, String?>{};
    int labelFor(PourStep step, int index) {
      final net = step.netId;
      if (net == null) {
        final label = -(index + 1);
        netOfLabel[label] = null;
        return label;
      }
      return labels.putIfAbsent(net, () {
        final label = labels.length + 1;
        netOfLabel[label] = net;
        return label;
      });
    }

    final rows = List<List<_Span>>.generate(rowCount, (_) => <_Span>[]);
    final scratch = <double>[];
    for (final (index, step) in steps.indexed) {
      final label = step.clear ? 0 : labelFor(step, index);
      final box = _boundsOf([step.shape]);
      if (box == null) continue;
      final first = math.max(0, ((box.top - top) / pitch).ceil());
      final last = math.min(rowCount - 1, ((box.bottom - top) / pitch).floor());
      for (var i = first; i <= last; i++) {
        scratch.clear();
        _spansOf(step.shape, rowY(i), scratch);
        for (var k = 0; k + 1 < scratch.length; k += 2) {
          _paint(rows[i], scratch[k], scratch[k + 1], label);
        }
      }
    }

    // Number every span, then join overlapping spans of one label on
    // neighbouring lines.
    final offsets = List<int>.filled(rowCount + 1, 0);
    for (var i = 0; i < rowCount; i++) {
      offsets[i + 1] = offsets[i] + rows[i].length;
    }
    final parent = List<int>.generate(offsets[rowCount], (i) => i);
    int find(int node) {
      while (parent[node] != node) {
        parent[node] = parent[parent[node]];
        node = parent[node];
      }
      return node;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    for (var i = 0; i + 1 < rowCount; i++) {
      final a = rows[i];
      final b = rows[i + 1];
      var p = 0;
      var q = 0;
      while (p < a.length && q < b.length) {
        final sa = a[p];
        final sb = b[q];
        if (sa.label == sb.label &&
            math.min(sa.x1, sb.x1) - math.max(sa.x0, sb.x0) > _eps) {
          union(offsets[i] + p, offsets[i + 1] + q);
        }
        if (sa.x1 < sb.x1) {
          p++;
        } else {
          q++;
        }
      }
    }

    // What each piece of fill touches.
    final padsOf = <int, List<PlacedPad>>{};
    final tracksOf = <int, List<Track>>{};
    final viasOf = <int, List<Via>>{};
    final touched = <int>{};

    Set<int> piecesUnder(PourShape shape, String netId) {
      final label = labels[netId];
      if (label == null) return const {};
      final box = _boundsOf([shape]);
      if (box == null) return const {};
      var first = math.max(0, ((box.top - top) / pitch).ceil());
      var last = math.min(rowCount - 1, ((box.bottom - top) / pitch).floor());
      final thin = first > last;
      if (thin) {
        // Thinner than a line spacing: test the line nearest its middle.
        final nearest = ((box.center.dy - top) / pitch).round();
        if (nearest < 0 || nearest >= rowCount) return const {};
        first = last = nearest;
      }
      final found = <int>{};
      final spans = <double>[];
      for (var i = first; i <= last; i++) {
        spans.clear();
        _spansOf(shape, rowY(i), spans);
        if (spans.isEmpty && thin) {
          // The nearest line can miss a sliver of a shape; its middle is
          // on the shape by construction.
          final centre = box.center;
          spans
            ..add(centre.dx - _eps)
            ..add(centre.dx + _eps);
        }
        final row = rows[i];
        for (var k = 0; k + 1 < spans.length; k += 2) {
          for (var s = _firstEndingAfter(row, spans[k] - _eps);
              s < row.length && row[s].x0 <= spans[k + 1] + _eps;
              s++) {
            if (row[s].label == label) found.add(find(offsets[i] + s));
          }
        }
      }
      return found;
    }

    for (final footprint in scene.footprints) {
      for (final pad in footprint.pads) {
        final net = pad.netId;
        if (net == null || !pad.reaches(layer)) continue;
        for (final piece in piecesUnder(PourPad(pad, 0), net)) {
          (padsOf[piece] ??= []).add(pad);
          touched.add(piece);
        }
      }
    }
    for (final track in scene.tracks) {
      final net = track.netId;
      if (net == null || track.layer != layer) continue;
      final shape = PourStroke([
        Offset(track.startX, track.startY),
        Offset(track.endX, track.endY),
      ], track.width);
      for (final piece in piecesUnder(shape, net)) {
        (tracksOf[piece] ??= []).add(track);
        touched.add(piece);
      }
    }
    for (final via in scene.vias) {
      final net = via.netId;
      if (net == null || !via.layersOn(scene.board).contains(layer)) continue;
      final shape = PourDisc(Offset(via.x, via.y), via.diameter);
      for (final piece in piecesUnder(shape, net)) {
        (viasOf[piece] ??= []).add(via);
        touched.add(piece);
      }
    }

    final labelOfPiece = <int, int>{};
    for (var i = 0; i < rowCount; i++) {
      for (var s = 0; s < rows[i].length; s++) {
        labelOfPiece.putIfAbsent(find(offsets[i] + s), () => rows[i][s].label);
      }
    }

    final joins = <PourJoin>[];
    for (final piece in touched) {
      final net = netOfLabel[labelOfPiece[piece]];
      if (net == null) continue;
      final join = PourJoin(
        netId: net,
        layer: layer,
        pads: padsOf[piece] ?? const [],
        tracks: tracksOf[piece] ?? const [],
        vias: viasOf[piece] ?? const [],
      );
      if (join.size > 1) joins.add(join);
    }

    // Everything else of a net is an island: gathered by piece, as
    // rectangles reaching a full line spacing up and down and half of one
    // sideways. That covers the copper between two lines and at the top
    // and bottom of the piece, and stays well inside the gap round it,
    // which is three line spacings at the least.
    final islandSpans = <int, List<(int, _Span)>>{};
    for (var i = 0; canRemoveIslands && i < rowCount; i++) {
      final row = rows[i];
      for (var s = 0; s < row.length; s++) {
        final span = row[s];
        if (span.label <= 0) continue;
        final piece = find(offsets[i] + s);
        if (touched.contains(piece)) continue;
        (islandSpans[piece] ??= []).add((i, span));
      }
    }
    final islands = <PourIsland>[];
    for (final spans in islandSpans.values) {
      final clears = <PourStep>[];
      // Runs of lines with the same span are merged into one rectangle.
      (int, int, double, double)? run;
      void flush() {
        final r = run;
        if (r == null) return;
        final rect = Rect.fromLTRB(
          r.$3 - pitch / 2,
          rowY(r.$1) - pitch,
          r.$4 + pitch / 2,
          rowY(r.$2) + pitch,
        );
        clears.add(
          PourStep.clear(
            PourRegion([
              rect.topLeft,
              rect.topRight,
              rect.bottomRight,
              rect.bottomLeft,
            ]),
          ),
        );
        run = null;
      }

      spans.sort((a, b) {
        final byX = a.$2.x0.compareTo(b.$2.x0);
        return byX != 0 ? byX : a.$1.compareTo(b.$1);
      });
      for (final (i, span) in spans) {
        final r = run;
        if (r != null &&
            r.$2 == i - 1 &&
            (r.$3 - span.x0).abs() < 1e-6 &&
            (r.$4 - span.x1).abs() < 1e-6) {
          run = (r.$1, i, r.$3, r.$4);
        } else {
          flush();
          run = (i, i, span.x0, span.x1);
        }
      }
      flush();

      final (row, first) = spans.first;
      islands.add(
        PourIsland(
          netId: netOfLabel[first.label]!,
          position: Offset((first.x0 + first.x1) / 2, rowY(row)),
          clears: clears,
        ),
      );
    }

    return PourCopper(joins: joins, islands: islands);
  }

  /// Paints [x0]..[x1] on [row] with [label], or clears it for label 0,
  /// keeping the row sorted, non-overlapping, and with touching spans of
  /// one label merged.
  static void _paint(List<_Span> row, double x0, double x1, int label) {
    if (x1 - x0 <= _eps) return;
    // The spans the new one touches: [from, to).
    final from = _firstEndingAfter(row, x0 - _eps);
    var to = from;
    while (to < row.length && row[to].x0 <= x1 + _eps) {
      to++;
    }

    final replacement = <_Span>[];
    var start = x0;
    var end = x1;
    for (var k = from; k < to; k++) {
      final span = row[k];
      if (span.label == label) {
        // The same copper: swallowed into the new span.
        start = math.min(start, span.x0);
        end = math.max(end, span.x1);
      } else {
        if (span.x0 < x0) replacement.add(_Span(span.x0, x0, span.label));
      }
    }
    if (label != 0) replacement.add(_Span(start, end, label));
    for (var k = from; k < to; k++) {
      final span = row[k];
      if (span.label != label && span.x1 > x1) {
        replacement.add(_Span(x1, span.x1, span.label));
      }
    }
    row.replaceRange(from, to, replacement);
  }

  /// The first span in [row] ending after [x].
  static int _firstEndingAfter(List<_Span> row, double x) {
    var lo = 0;
    var hi = row.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (row[mid].x1 <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  // --- shapes on a line ---------------------------------------------------

  /// The spans of x [shape] covers on the line at [y], appended to [out]
  /// as start, end pairs.
  static void _spansOf(PourShape shape, double y, List<double> out) {
    switch (shape) {
      case PourRegion(:final points, :final hole):
        _polygonSpans(points, hole, y, out);
      case PourStroke(:final points, :final width, :final closed):
        final r = width / 2;
        if (points.length == 1) {
          _hull(_discSpan(points.first, r, y), out);
        }
        final count = closed ? points.length : points.length - 1;
        for (var i = 0; i < count; i++) {
          _hull(
            _capsuleSpan(points[i], points[(i + 1) % points.length], r, y),
            out,
          );
        }
      case PourPad(:final pad, :final grow):
        _hull(_padSpan(pad, grow, y), out);
      case PourDisc(:final centre, :final diameter):
        _hull(_discSpan(centre, diameter / 2, y), out);
    }
  }

  static void _hull((double, double)? span, List<double> out) {
    if (span == null) return;
    out
      ..add(span.$1)
      ..add(span.$2);
  }

  /// Even-odd spans of a polygon, and of a hole cut in it.
  static void _polygonSpans(
    List<Offset> points,
    List<Offset>? hole,
    double y,
    List<double> out,
  ) {
    final xs = <double>[];
    void crossings(List<Offset> ring) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final a = ring[i];
        final b = ring[j];
        if ((a.dy > y) != (b.dy > y)) {
          xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
        }
      }
    }

    crossings(points);
    if (hole != null) crossings(hole);
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      out
        ..add(xs[k])
        ..add(xs[k + 1]);
    }
  }

  static (double, double)? _discSpan(Offset c, double r, double y) {
    final dy = y - c.dy;
    if (dy.abs() > r) return null;
    final half = math.sqrt(r * r - dy * dy);
    return (c.dx - half, c.dx + half);
  }

  /// The span of a convex polygon.
  static (double, double)? _convexSpan(List<Offset> ring, double y) {
    double? lo;
    double? hi;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      if ((a.dy > y) != (b.dy > y)) {
        final x = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
        lo = lo == null ? x : math.min(lo, x);
        hi = hi == null ? x : math.max(hi, x);
      }
    }
    return lo == null ? null : (lo, hi!);
  }

  static (double, double)? _merge(Iterable<(double, double)?> spans) {
    double? lo;
    double? hi;
    for (final span in spans) {
      if (span == null) continue;
      lo = lo == null ? span.$1 : math.min(lo, span.$1);
      hi = hi == null ? span.$2 : math.max(hi, span.$2);
    }
    return lo == null ? null : (lo, hi!);
  }

  /// A round-ended line: two discs and the band between them. The three
  /// together are convex, so the span is the hull of theirs.
  static (double, double)? _capsuleSpan(
    Offset a,
    Offset b,
    double r,
    double y,
  ) {
    final d = b - a;
    final length = d.distance;
    if (length < 1e-12) return _discSpan(a, r, y);
    final n = Offset(-d.dy, d.dx) / length * r;
    return _merge([
      _discSpan(a, r, y),
      _discSpan(b, r, y),
      _convexSpan([a + n, b + n, b - n, a - n], y),
    ]);
  }

  /// A pad grown by [grow], in the shape the Gerber writer flashes it.
  static (double, double)? _padSpan(PlacedPad pad, double grow, double y) {
    final w = pad.pad.sizeX + grow * 2;
    final h = pad.pad.sizeY + grow * 2;
    final radians = pad.angle * math.pi / 180;
    final ux = Offset(math.cos(radians), -math.sin(radians));
    final uy = Offset(math.sin(radians), math.cos(radians));
    final c = pad.position;
    Offset at(double lx, double ly) => c + ux * lx + uy * ly;

    final radius = switch (pad.pad.shape) {
      PadShape.circle || PadShape.oval => math.min(w, h) / 2,
      PadShape.roundrect => math.min(
        math.min(pad.pad.sizeX, pad.pad.sizeY) * pad.pad.roundrectRatio + grow,
        math.min(w, h) / 2,
      ),
      _ => 0.0,
    };
    if (pad.pad.shape == PadShape.circle) {
      return _discSpan(c, w / 2, y);
    }
    final hx = w / 2 - radius;
    final hy = h / 2 - radius;
    List<Offset> box(double x, double yy) => [
      at(-x, -yy),
      at(x, -yy),
      at(x, yy),
      at(-x, yy),
    ];
    if (radius < 1e-9) return _convexSpan(box(w / 2, h / 2), y);
    return _merge([
      _convexSpan(box(w / 2, hy), y),
      _convexSpan(box(hx, h / 2), y),
      _discSpan(at(-hx, -hy), radius, y),
      _discSpan(at(hx, -hy), radius, y),
      _discSpan(at(hx, hy), radius, y),
      _discSpan(at(-hx, hy), radius, y),
    ]);
  }

  static Rect? _boundsOf(Iterable<PourShape> shapes) {
    Rect? all;
    for (final shape in shapes) {
      final box = switch (shape) {
        PourRegion(:final points) => _pointsBounds(points),
        PourStroke(:final points, :final width) => _pointsBounds(
          points,
        )?.inflate(width / 2),
        PourPad(:final pad, :final grow) => Rect.fromCircle(
          center: pad.position,
          radius:
              math.sqrt(
                    pad.pad.sizeX * pad.pad.sizeX +
                        pad.pad.sizeY * pad.pad.sizeY,
                  ) /
                  2 +
              grow,
        ),
        PourDisc(:final centre, :final diameter) => Rect.fromCircle(
          center: centre,
          radius: diameter / 2,
        ),
      };
      if (box == null) continue;
      all = all == null ? box : all.expandToInclude(box);
    }
    return all;
  }

  static Rect? _pointsBounds(List<Offset> points) {
    if (points.isEmpty) return null;
    var left = points.first.dx;
    var right = left;
    var top = points.first.dy;
    var bottom = top;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class _Span {
  _Span(this.x0, this.x1, this.label);

  double x0;
  double x1;

  /// The net the copper is on; 0 is never stored.
  final int label;
}
