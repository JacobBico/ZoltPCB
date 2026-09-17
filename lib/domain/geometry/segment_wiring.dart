import 'dart:math' as math;
import 'dart:ui';

/// One straight piece of wire: the whole of a wire in the segment model.
///
/// Wires are joined by sharing an end point, so there is nothing to work out
/// about whether two of them are connected — either they end at the same
/// place or they do not. [id] is the stored row it came from, or null for a
/// piece that has just come into being.
class WireSegment {
  const WireSegment({
    required this.a,
    required this.b,
    this.id,
    this.pinA,
    this.pinB,
  });

  final Offset a;
  final Offset b;
  final String? id;

  /// The pin each end sits on, when it sits on one. A pinned end is fixed:
  /// the pin is where the part says it is.
  final String? pinA;
  final String? pinB;

  bool get isZero => (a - b).distance < SegmentWiring.tolerance;
  bool get isHorizontal => (a.dy - b.dy).abs() < SegmentWiring.tolerance;
  bool get isVertical => (a.dx - b.dx).abs() < SegmentWiring.tolerance;

  WireSegment copyWith({
    Offset? a,
    Offset? b,
    String? id,
    String? pinA,
    String? pinB,
  }) => WireSegment(
    a: a ?? this.a,
    b: b ?? this.b,
    id: id ?? this.id,
    pinA: pinA ?? this.pinA,
    pinB: pinB ?? this.pinB,
  );

  /// The same segment the other way round, pins and all.
  WireSegment get reversed =>
      WireSegment(a: b, b: a, id: id, pinA: pinB, pinB: pinA);

  bool touches(Offset at) =>
      (a - at).distance < SegmentWiring.tolerance ||
      (b - at).distance < SegmentWiring.tolerance;

  /// Whether [at] lies on this segment, ends included.
  bool covers(Offset at) =>
      SegmentWiring.distanceToSegment(at, a, b) < SegmentWiring.tolerance;

  @override
  String toString() => 'WireSegment($a → $b)';
}

/// Wiring as KiCad has it: a net's drawing is straight segments that meet at
/// shared points.
///
/// Everything here keeps one invariant — segments that share a point go on
/// sharing it — which is what makes dragging behave. There is no rule about
/// corners, tees or overlaps because none of those are special: a corner is
/// two segments at a point, a tee is three, and an overlap is not allowed to
/// exist, being tidied into one segment as soon as it appears.
class SegmentWiring {
  const SegmentWiring._();

  /// How close two points have to be to count as the same place, in sheet
  /// millimetres. Well under the 1.27 mm grid everything lands on.
  static const double tolerance = 0.01;

  /// The wiring tidied into its canonical shape: no zero-length pieces, no
  /// two pieces lying over each other, a piece split wherever another ends
  /// against its middle, and pieces that carry straight on through a point
  /// where nothing else happens joined into one.
  static List<WireSegment> canonicalise(
    List<WireSegment> segments, {
    Iterable<Offset> pins = const [],
  }) {
    var result = [
      for (final segment in segments)
        if (!segment.isZero) segment,
    ];
    result = _union(result);
    result = _splitAtEnds(result);
    result = _joinStraightRuns(result, pins);
    return result;
  }

  /// A segment dragged by [shift], with everything joined to it following.
  ///
  /// The segments that shared its ends still share them afterwards, which is
  /// the whole of the rule. One that would be left slanting gains a corner
  /// rather than a diagonal, and a pinned end stays on its pin — the wire
  /// bends to reach it.
  static List<WireSegment> drag(
    List<WireSegment> segments,
    String id,
    Offset shift, {
    Iterable<Offset> pins = const [],
    double grid = 1.27,
  }) {
    // A drag that would tear the drawing apart is held at the last place
    // where everything is still joined, rather than letting a piece come
    // away from the rest of the net.
    var tried = shift;
    for (var attempt = 0; attempt < 40; attempt++) {
      final result = _dragOnce(segments, id, tried, pins);
      if (joined(result)) return result;
      final length = tried.distance;
      if (length <= grid) break;
      tried = tried * ((length - grid) / length);
    }
    return segments;
  }

  /// Whether every piece is reachable from every other.
  static bool joined(List<WireSegment> segments) {
    if (segments.length < 2) return true;
    bool meet(WireSegment a, WireSegment b) =>
        b.covers(a.a) || b.covers(a.b) || a.covers(b.a) || a.covers(b.b);

    final reached = <int>{0};
    var grew = true;
    while (grew) {
      grew = false;
      for (var i = 0; i < segments.length; i++) {
        if (reached.contains(i)) continue;
        if (reached.any((j) => meet(segments[j], segments[i]))) {
          reached.add(i);
          grew = true;
        }
      }
    }
    return reached.length == segments.length;
  }

  static List<WireSegment> _dragOnce(
    List<WireSegment> segments,
    String id,
    Offset shift,
    Iterable<Offset> pins,
  ) {
    final dragged = segments.where((s) => s.id == id).firstOrNull;
    if (dragged == null || shift.distance < tolerance) return segments;

    // A pinned end of the piece being dragged does not travel either: the
    // piece comes away from the pin and a stub is left joining the two, the
    // way a wire stretches in KiCad rather than letting go of a part.
    final movedA = dragged.a + shift;
    final movedB = dragged.b + shift;
    final stitches = <WireSegment>[
      if (dragged.pinA case final pin?) ..._stitch(dragged.a, movedA, pin),
      if (dragged.pinB case final pin?) ..._stitch(dragged.b, movedB, pin),
    ];

    // Only the ends that actually move take their neighbours with them.
    final from = [
      if (dragged.pinA == null) dragged.a,
      if (dragged.pinB == null) dragged.b,
    ];
    final to = [
      if (dragged.pinA == null) movedA,
      if (dragged.pinB == null) movedB,
    ];

    final moved = <WireSegment>[...stitches];
    for (final segment in segments) {
      if (segment.id == id) {
        moved.add(WireSegment(id: segment.id, a: movedA, b: movedB));
        continue;
      }
      var piece = segment;
      final extra = <WireSegment>[];
      for (var end = 0; end < from.length; end++) {
        // A pinned end cannot travel: the pin is where the part puts it.
        if ((piece.a - from[end]).distance < tolerance && piece.pinA == null) {
          final (bent, joint) = _bend(piece, to[end], atA: true);
          piece = bent;
          if (joint != null) extra.add(joint);
        } else if ((piece.b - from[end]).distance < tolerance &&
            piece.pinB == null) {
          final (bent, joint) = _bend(piece, to[end], atA: false);
          piece = bent;
          if (joint != null) extra.add(joint);
        }
      }
      moved.add(piece);
      moved.addAll(extra);
    }
    return canonicalise(moved, pins: pins);
  }

  /// [segment] with one end taken to [to], squarely.
  ///
  /// A segment pulled sideways would be left slanting, so it keeps its own
  /// direction and a new piece carries the end the rest of the way.
  static (WireSegment, WireSegment?) _bend(
    WireSegment segment,
    Offset to, {
    required bool atA,
  }) {
    final fixed = atA ? segment.b : segment.a;
    final square =
        (to.dx - fixed.dx).abs() < tolerance ||
        (to.dy - fixed.dy).abs() < tolerance;
    if (square) {
      return (atA ? segment.copyWith(a: to) : segment.copyWith(b: to), null);
    }

    // Along its own line as far as it can go, then across to the new place.
    final corner = segment.isHorizontal
        ? Offset(to.dx, fixed.dy)
        : Offset(fixed.dx, to.dy);
    final shortened = atA
        ? segment.copyWith(a: corner, pinA: null)
        : segment.copyWith(b: corner, pinB: null);
    final joint = WireSegment(
      a: corner,
      b: to,
      pinB: atA ? segment.pinA : segment.pinB,
    );
    return (shortened, joint);
  }

  /// An orthogonal run of wire from a pin to where the wire has gone.
  static List<WireSegment> _stitch(Offset from, Offset to, String pin) {
    if ((from - to).distance < tolerance) return const [];
    if ((from.dx - to.dx).abs() < tolerance ||
        (from.dy - to.dy).abs() < tolerance) {
      return [WireSegment(a: from, b: to, pinA: pin)];
    }
    final corner = Offset(to.dx, from.dy);
    return [
      WireSegment(a: from, b: corner, pinA: pin),
      WireSegment(a: corner, b: to),
    ];
  }

  /// Segments lying over one another, of which there should never be two,
  /// rolled into the one piece they are drawing.
  static List<WireSegment> _union(List<WireSegment> segments) {
    final result = [...segments];
    var joined = true;
    while (joined) {
      joined = false;
      outer:
      for (var i = 0; i < result.length; i++) {
        for (var j = i + 1; j < result.length; j++) {
          final union = _overlap(result[i], result[j]);
          if (union == null) continue;
          result[i] = union;
          result.removeAt(j);
          joined = true;
          break outer;
        }
      }
    }
    return result;
  }

  /// The single segment [a] and [b] draw between them when they lie along
  /// the same line and touch, or null when they do not.
  static WireSegment? _overlap(WireSegment a, WireSegment b) {
    if (!_collinear(a, b)) return null;

    // Along the line they share, as distances from a.a.
    final axis = a.isZero ? (b.b - b.a) : (a.b - a.a);
    final unit = axis / axis.distance;
    double at(Offset p) => (p - a.a).dx * unit.dx + (p - a.a).dy * unit.dy;

    final ends = [
      (at(a.a), a.a, a.pinA),
      (at(a.b), a.b, a.pinB),
      (at(b.a), b.a, b.pinA),
      (at(b.b), b.b, b.pinB),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    final lowA = math.min(at(a.a), at(a.b));
    final highA = math.max(at(a.a), at(a.b));
    final lowB = math.min(at(b.a), at(b.b));
    final highB = math.max(at(b.a), at(b.b));
    // Touching at a single point is a join, not an overlap: that is for
    // [_joinStraightRuns] to decide, which knows what else meets there.
    if (math.min(highA, highB) - math.max(lowA, lowB) <= tolerance) {
      return null;
    }

    return WireSegment(
      a: ends.first.$2,
      b: ends.last.$2,
      id: a.id ?? b.id,
      pinA: ends.first.$3,
      pinB: ends.last.$3,
    );
  }

  static bool _collinear(WireSegment a, WireSegment b) {
    if (a.isZero || b.isZero) return false;
    if (a.isHorizontal && b.isHorizontal) {
      return (a.a.dy - b.a.dy).abs() < tolerance;
    }
    if (a.isVertical && b.isVertical) {
      return (a.a.dx - b.a.dx).abs() < tolerance;
    }
    return false;
  }

  /// Every segment cut where another segment ends against its middle, so
  /// that a tee is three segments meeting at a point like any other join.
  static List<WireSegment> _splitAtEnds(List<WireSegment> segments) {
    var result = [...segments];
    var split = true;
    while (split) {
      split = false;
      outer:
      for (var i = 0; i < result.length; i++) {
        final segment = result[i];
        for (final other in result) {
          if (identical(other, segment)) continue;
          for (final end in [other.a, other.b]) {
            if (segment.touches(end) || !segment.covers(end)) continue;
            result
              ..removeAt(i)
              ..insertAll(i, [
                WireSegment(
                  a: segment.a,
                  b: end,
                  id: segment.id,
                  pinA: segment.pinA,
                ),
                WireSegment(a: end, b: segment.b, pinB: segment.pinB),
              ]);
            split = true;
            break outer;
          }
        }
      }
    }
    return result;
  }

  /// Segments carrying straight on through a point where nothing else meets
  /// joined into one, so a straight piece of wire is a straight piece of
  /// wire however it was drawn.
  static List<WireSegment> _joinStraightRuns(
    List<WireSegment> segments,
    Iterable<Offset> pins,
  ) {
    final result = [...segments];
    var joined = true;
    while (joined) {
      joined = false;
      outer:
      for (var i = 0; i < result.length; i++) {
        for (var j = i + 1; j < result.length; j++) {
          final meeting = _meetingPoint(result[i], result[j]);
          if (meeting == null) continue;
          if (!_collinear(result[i], result[j])) continue;
          // Only where the two of them are all there is: a pin, or a third
          // segment, makes the point a junction worth keeping.
          if (pins.any((pin) => (pin - meeting).distance < tolerance)) {
            continue;
          }
          if (result.any(
            (other) =>
                !identical(other, result[i]) &&
                !identical(other, result[j]) &&
                other.covers(meeting),
          )) {
            continue;
          }

          final a = (result[i].b - meeting).distance < tolerance
              ? result[i]
              : result[i].reversed;
          final b = (result[j].a - meeting).distance < tolerance
              ? result[j]
              : result[j].reversed;
          result[i] = WireSegment(
            a: a.a,
            b: b.b,
            id: a.id ?? b.id,
            pinA: a.pinA,
            pinB: b.pinB,
          );
          result.removeAt(j);
          joined = true;
          break outer;
        }
      }
    }
    return result;
  }

  /// Where two segments meet end to end, if they do.
  static Offset? _meetingPoint(WireSegment a, WireSegment b) {
    for (final point in [a.a, a.b]) {
      if ((b.a - point).distance < tolerance ||
          (b.b - point).distance < tolerance) {
        return point;
      }
    }
    return null;
  }

  /// The points that need a junction dot: where three or more segment ends
  /// meet, or two meet on a pin.
  static List<Offset> junctions(
    List<WireSegment> segments, {
    Iterable<Offset> pins = const [],
  }) {
    final points = <Offset>[];
    for (final segment in segments) {
      for (final point in [segment.a, segment.b]) {
        if (!points.any((p) => (p - point).distance < tolerance)) {
          points.add(point);
        }
      }
    }

    return [
      for (final point in points)
        if (_endsAt(segments, point) >= 3 ||
            (pins.any((pin) => (pin - point).distance < tolerance) &&
                _endsAt(segments, point) >= 2))
          point,
    ];
  }

  static int _endsAt(List<WireSegment> segments, Offset point) {
    var ends = 0;
    for (final segment in segments) {
      if ((segment.a - point).distance < tolerance) ends++;
      if ((segment.b - point).distance < tolerance) ends++;
    }
    return ends;
  }

  /// Shortest distance from [p] to the segment [a]–[b].
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final d = b - a;
    final lengthSquared = d.dx * d.dx + d.dy * d.dy;
    if (lengthSquared < 1e-12) return (p - a).distance;
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return (p - (a + d * t)).distance;
  }
}
