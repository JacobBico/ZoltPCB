import 'dart:math' as math;
import 'dart:ui';

import 'board.dart';
import 'track_angles.dart';

/// What sliding part of a route does to the copper around it.
class TrackSlide {
  const TrackSlide({
    this.moved = const [],
    this.removed = const [],
    this.added = const [],
  });

  /// Segments that travelled, in their new places. The ends of the run may
  /// also have been trimmed or extended to meet what they reconnect to.
  final List<Track> moved;

  /// Segments replaced by the reconnection, by id.
  final List<String> removed;

  /// The copper laid to join the moved run back on, on legal angles.
  final List<({Offset from, Offset to})> added;

  bool get isEmpty => moved.isEmpty && added.isEmpty;
}

/// Slides the run containing [track] sideways, keeping the route intact and
/// every angle legal.
///
/// The part that makes this behave like KiCad rather than like dragging a
/// line about is what happens at the ends. The obvious thing — translate
/// the segment and draw something from the old corner to the new one — puts
/// a bare perpendicular off the pad, because the moved end is still
/// directly above where it started. KiCad does not do that: it lets the run
/// get *shorter*, and joins the pad to it with a single 45.
///
/// So each end is reconnected by choosing where on the run's own line to
/// meet, out of the directions the lock allows, preferring the one that
/// cuts the corner. A straight run and a 45 into the pad, slid upwards,
/// comes back as a 45 out of the pad, a shorter straight run, and a 45 into
/// the far pad — which is what it looks like when you do it by hand.
TrackSlide slideTrack({
  required Track track,
  required List<Track> others,
  required Offset delta,
  Iterable<Offset> anchors = const [],
  TrackAngleLock lock = TrackAngleLock.deg45,
}) {
  final a = Offset(track.startX, track.startY);
  final b = Offset(track.endX, track.endY);
  final along = b - a;
  if (along.distance < 1e-9) return const TrackSlide();

  final direction = along / along.distance;
  final normal = Offset(-direction.dy, direction.dx);

  // Only the sideways part of the drag counts. Pushing a run along its own
  // length moves nothing and would only stretch what it joins.
  final requested = delta.dx * normal.dx + delta.dy * normal.dy;
  if (requested.abs() < 1e-9) return const TrackSlide();

  final chain = _runContaining(track, others);

  TrackSlide attempt(double shift) =>
      _slideChain(chain, others, normal * shift, anchors, lock);

  // How far it can go. Pushed far enough, the run shrinks to nothing and
  // the joins at each end meet in a point; any further and they cross over
  // each other and the copper folds back on itself. That point is where a
  // drag stops, however much further the finger goes.
  if (_isIntact(chain, attempt(requested))) return attempt(requested);

  var good = 0.0;
  var bad = requested;
  for (var i = 0; i < 40; i++) {
    final middle = (good + bad) / 2;
    if (_isIntact(chain, attempt(middle))) {
      good = middle;
    } else {
      bad = middle;
    }
  }
  return good.abs() < 1e-9 ? const TrackSlide() : attempt(good);
}

/// Whether a slide left every piece of the run pointing the way it did.
///
/// A segment whose direction has reversed has been pushed past the point
/// where its two ends met, which is exactly the fold-over that has to be
/// refused.
bool _isIntact(List<Track> chain, TrackSlide slide) {
  final after = {for (final t in slide.moved) t.id: t};
  for (final original in chain) {
    final moved = after[original.id];
    // Taken out for having no length left: at the limit, not past it.
    if (moved == null) continue;
    final was = Offset(original.endX - original.startX,
        original.endY - original.startY);
    final now = Offset(moved.endX - moved.startX, moved.endY - moved.startY);
    if (was.dx * now.dx + was.dy * now.dy < -1e-9) return false;
  }
  return true;
}

/// A run shorter than this after a slide is gone rather than kept.
const _minimumRun = 1e-3;

TrackSlide _slideChain(
  List<Track> chain,
  List<Track> others,
  Offset offset,
  Iterable<Offset> anchors,
  TrackAngleLock lock,
) {

  final chainIds = {for (final segment in chain) segment.id};

  final ends = _endsOf(chain);
  if (ends == null) return const TrackSlide();

  // Keyed by id so an end can be trimmed after it has been translated.
  final moved = {
    for (final segment in chain)
      segment.id: segment.copyWith(
        startX: segment.startX + offset.dx,
        startY: segment.startY + offset.dy,
        endX: segment.endX + offset.dx,
        endY: segment.endY + offset.dy,
      ),
  };

  final removed = <String>[];
  final added = <({Offset from, Offset to})>[];

  for (var i = 0; i < ends.length; i++) {
    final end = ends[i];
    final landing = end + offset;
    final opposite = ends[1 - i] + offset;

    // Whatever the run was joined to here, other than itself.
    final connector = others
        .where((other) => !chainIds.contains(other.id))
        .where(
          (other) =>
              _same(Offset(other.startX, other.startY), end) ||
              _same(Offset(other.endX, other.endY), end),
        )
        .firstOrNull;

    Offset? fixed;
    if (connector != null) {
      fixed = _same(Offset(connector.startX, connector.startY), end)
          ? Offset(connector.endX, connector.endY)
          : Offset(connector.startX, connector.startY);
      removed.add(connector.id);
    } else if (anchors.any((anchor) => _same(anchor, end))) {
      // Nothing beyond, but the end was sitting on a pad and has to stay
      // on it.
      fixed = end;
    }
    if (fixed == null) continue;

    // The segment at this end of the run, and the way it runs.
    final endSegment = chain.firstWhere(
      (segment) =>
          _same(Offset(segment.startX, segment.startY), end) ||
          _same(Offset(segment.endX, segment.endY), end),
    );
    final atStart = _same(
      Offset(endSegment.startX, endSegment.startY),
      end,
    );
    final far = atStart
        ? Offset(endSegment.endX, endSegment.endY)
        : Offset(endSegment.startX, endSegment.startY);
    final lineDirection = _unit((far + offset) - landing);
    if (lineDirection == null) continue;

    final junction = _joinOnto(
      from: fixed,
      linePoint: landing,
      lineDirection: lineDirection,
      lock: lock,
      towards: opposite,
    );

    if (junction == null) {
      // Nothing legal meets the line; fall back to a two-segment path to
      // where the end actually landed.
      _appendPath(added, fixed, landing, lock);
      continue;
    }

    // Trim the run to where it is now joined.
    final current = moved[endSegment.id]!;
    moved[endSegment.id] = atStart
        ? current.copyWith(startX: junction.dx, startY: junction.dy)
        : current.copyWith(endX: junction.dx, endY: junction.dy);

    if (!_same(fixed, junction)) added.add((from: fixed, to: junction));
  }

  // A run pushed until it has no length left has become a point where the
  // two joins meet — the triangle. It is taken out rather than left behind
  // as a zero-length scrap of copper.
  final kept = <Track>[];
  for (final segment in moved.values) {
    if (_lengthOf(segment) < _minimumRun) {
      removed.add(segment.id);
    } else {
      kept.add(segment);
    }
  }

  return TrackSlide(moved: kept, removed: removed, added: added);
}


/// Where [from] can meet the line through [linePoint] along
/// [lineDirection], travelling on a bearing [lock] allows.
///
/// Of the directions available, the one whose meeting point is nearest the
/// far end of the run wins. That is what picks the 45 that cuts the corner
/// over the perpendicular that does not: both are legal, and only one of
/// them is what anybody draws.
Offset? _joinOnto({
  required Offset from,
  required Offset linePoint,
  required Offset lineDirection,
  required TrackAngleLock lock,
  required Offset towards,
}) {
  Offset? best;
  var bestScore = double.infinity;

  for (final bearing in _bearings(lock)) {
    final cross =
        bearing.dx * lineDirection.dy - bearing.dy * lineDirection.dx;
    // Parallel to the run: it never meets it.
    if (cross.abs() < 1e-9) continue;
    // Square onto the run is the bare stub KiCad never draws when a 45 is
    // allowed — and letting it win past the triangle is what let a drag
    // carry on for ever instead of stopping there.
    if (lock != TrackAngleLock.deg90 && (cross.abs() - 1).abs() < 1e-6) {
      continue;
    }

    final d = linePoint - from;
    final t = (d.dx * lineDirection.dy - d.dy * lineDirection.dx) / cross;
    // Behind the fixed point, or absurdly far: not a join anyone wants.
    if (t < 1e-6 || t > 1e5) continue;

    final junction = from + bearing * t;
    final score = (junction - towards).distance;
    if (score < bestScore) {
      bestScore = score;
      best = junction;
    }
  }
  return best;
}

/// The unit directions copper may travel in under [lock].
List<Offset> _bearings(TrackAngleLock lock) {
  const square = [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ];
  if (lock == TrackAngleLock.deg90) return square;

  final diagonal = math.sqrt1_2;
  final diagonals = [
    Offset(diagonal, diagonal),
    Offset(-diagonal, diagonal),
    Offset(diagonal, -diagonal),
    Offset(-diagonal, -diagonal),
  ];
  // Any-angle still reconnects on 45s: a drag is not the place to start
  // inventing bearings nothing else on the board uses.
  return [...square, ...diagonals];
}

/// The run of segments that should travel together.
///
/// A segment grabbed out of a rounded corner takes the whole curve with it,
/// because a curve with one piece moved out of it is not a curve any more.
/// A segment grabbed on a straight takes only what is dead straight with
/// it, so the bend at the end stays behind to be redrawn — otherwise
/// sliding a run drags its curve along unchanged, which is what made one
/// look like a ramp followed by a waterfall.
List<Track> _runContaining(Track track, List<Track> others) {
  // Inside a curve means bending at *both* ends. A long straight that
  // happens to meet a rounded corner bends at one end only, and dragging
  // the curve along with it is what left the route looking like a ramp
  // followed by a waterfall.
  final joints = _joints(track, others);
  final inCurve =
      joints.length == 2 &&
      joints.every(
        (turn) => turn > _straightEnough && turn < _gentleTurn,
      );
  final limit = inCurve ? _gentleTurn : _straightEnough;

  // The pieces of a curve are all about as short as each other, so a
  // segment many times longer is the straight the curve runs into, not
  // more of the curve.
  final longest = inCurve
      ? _lengthOf(track) * 3
      : double.infinity;

  final run = <Track>[track];
  final taken = {track.id};

  for (var side = 0; side < 2; side++) {
    var tip = side == 0
        ? Offset(track.startX, track.startY)
        : Offset(track.endX, track.endY);
    var current = track;

    while (true) {
      final joined = others
          .where((other) => other.id != current.id)
          .where(
            (other) =>
                _same(Offset(other.startX, other.startY), tip) ||
                _same(Offset(other.endX, other.endY), tip),
          )
          .toList();

      // A branch is a decision the app should not make on its own, and a
      // loose end has nothing beyond it.
      if (joined.length != 1) break;
      final next = joined.first;
      if (taken.contains(next.id)) break;
      if (_turnAt(current, next, tip) >= limit) break;
      if (_lengthOf(next) > longest) break;

      taken.add(next.id);
      run.add(next);
      tip = _same(Offset(next.startX, next.startY), tip)
          ? Offset(next.endX, next.endY)
          : Offset(next.startX, next.startY);
      current = next;
    }
  }

  return run;
}

/// How much the route bends at each end of [track].
List<double> _joints(Track track, List<Track> others) {
  final turns = <double>[];
  for (final tip in [
    Offset(track.startX, track.startY),
    Offset(track.endX, track.endY),
  ]) {
    final joined = others
        .where((other) => other.id != track.id)
        .where(
          (other) =>
              _same(Offset(other.startX, other.startY), tip) ||
              _same(Offset(other.endX, other.endY), tip),
        )
        .toList();
    if (joined.length == 1) turns.add(_turnAt(track, joined.first, tip));
  }
  return turns;
}

/// The angle, in radians, by which the route changes direction where two
/// segments meet at [joint]. Zero is dead straight.
double _turnAt(Track first, Track second, Offset joint) {
  Offset? away(Track track) {
    final start = Offset(track.startX, track.startY);
    final end = Offset(track.endX, track.endY);
    return _unit((_same(start, joint) ? end : start) - joint);
  }

  final u = away(first);
  final v = away(second);
  if (u == null || v == null) return math.pi;

  final dot = (u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0);
  // They point away from the joint in opposite directions when straight.
  return math.pi - math.acos(dot);
}

/// Near enough to straight to be the same run.
const _straightEnough = 3 * math.pi / 180;

/// How far a joint may bend and still be part of the same curve. Rounded
/// corners are drawn in six pieces across the bend, so their joints turn by
/// well under this; a 45° corner is well over it.
const _gentleTurn = 30 * math.pi / 180;

/// The two ends of a chain — the points touched by only one segment.
List<Offset>? _endsOf(List<Track> chain) {
  final points = <Offset>[];
  for (final segment in chain) {
    points
      ..add(Offset(segment.startX, segment.startY))
      ..add(Offset(segment.endX, segment.endY));
  }

  final ends = <Offset>[];
  for (final point in points) {
    final touching = points.where((other) => _same(other, point)).length;
    if (touching == 1 && !ends.any((end) => _same(end, point))) {
      ends.add(point);
    }
  }
  // A chain that loops has no ends and nothing sensible to slide.
  return ends.length == 2 ? ends : null;
}

void _appendPath(
  List<({Offset from, Offset to})> into,
  Offset from,
  Offset to,
  TrackAngleLock lock,
) {
  if (_same(from, to)) return;
  var at = from;
  for (final corner in legalCorners(from, to, lock)) {
    if (!_same(at, corner)) into.add((from: at, to: corner));
    at = corner;
  }
}

double _lengthOf(Track track) =>
    (Offset(track.endX, track.endY) - Offset(track.startX, track.startY))
        .distance;

Offset? _unit(Offset v) => v.distance < 1e-9 ? null : v / v.distance;

/// Board geometry is in millimetres and nothing is meaningfully finer than
/// a tenth of a micron; float arithmetic needs the slack.
bool _same(Offset a, Offset b) => (a - b).distance < 1e-4;
