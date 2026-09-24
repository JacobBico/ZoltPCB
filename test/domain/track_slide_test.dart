import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

Track _track(String id, double x1, double y1, double x2, double y2) => Track(
  id: id,
  projectId: 'p',
  layer: CopperLayer.front,
  startX: x1,
  startY: y1,
  endX: x2,
  endY: y2,
  width: 0.25,
);

/// Every segment the slide leaves behind, as bare endpoint pairs.
List<(Offset, Offset)> _resulting(List<Track> before, TrackSlide slide) {
  final moved = {for (final t in slide.moved) t.id: t};
  return [
    for (final track in before)
      if (!slide.removed.contains(track.id))
        () {
          final t = moved[track.id] ?? track;
          return (Offset(t.startX, t.startY), Offset(t.endX, t.endY));
        }(),
    for (final added in slide.added) (added.from, added.to),
  ];
}

void _expectAllLegal(List<(Offset, Offset)> segments) {
  for (final (from, to) in segments) {
    final d = to - from;
    if (d.distance < 1e-6) continue;
    expect(
      isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45),
      isTrue,
      reason: 'a segment came out at a stray angle: $from → $to',
    );
  }
}

/// Whether the segments form one unbroken chain — no piece left dangling.
void _expectJoinedUp(List<(Offset, Offset)> segments) {
  bool same(Offset a, Offset b) => (a - b).distance < 1e-4;
  for (final (from, to) in segments) {
    for (final end in [from, to]) {
      final touching = segments
          .where((s) => same(s.$1, end) || same(s.$2, end))
          .length;
      expect(
        touching,
        greaterThanOrEqualTo(1),
        reason: 'the end $end is joined to nothing',
      );
    }
  }
}

double _lengthOf(Track t) =>
    (Offset(t.endX, t.endY) - Offset(t.startX, t.startY)).distance;

/// The points of a chain touched by only one of its segments.
List<Offset> _looseEnds(List<Track> chain) {
  final points = [
    for (final t in chain) ...[
      Offset(t.startX, t.startY),
      Offset(t.endX, t.endY),
    ],
  ];
  return [
    for (final point in points)
      if (points.where((o) => (o - point).distance < 1e-4).length == 1) point,
  ];
}

void main() {
  group('reported: a straight run and a 45 into the pad', () {
    // "I have it traced as a straight line and then 45 degree angle to the
    // pad... I move it upwards and we get a really sharp bend like 5-10
    // degree angle, and the other pad keeps a 90 degree angle of trace at
    // all times, while it should be like 45 degrees instead."
    final run = _track('run', 10, 20, 24, 20);
    final diagonal = _track('diag', 24, 20, 30, 26);
    final tracks = [run, diagonal];
    const padA = Offset(10, 20);
    const padB = Offset(30, 26);

    test('every segment is still on a legal angle afterwards', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );
      _expectAllLegal(_resulting(tracks, slide));
    });

    test('the end on the pad is joined by a 45, not a perpendicular stub', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );

      // Something leaves the pad, and it is not a bare vertical.
      final fromPad = _resulting(
        tracks,
        slide,
      ).where((s) => (s.$1 - padA).distance < 1e-4).toList();
      expect(fromPad, isNotEmpty, reason: 'the run came off its pad');
      for (final (from, to) in fromPad) {
        final d = to - from;
        expect(isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45), isTrue);
      }
    });

    test('both pads are still connected to something', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );
      final segments = _resulting(tracks, slide);

      for (final pad in [padA, padB]) {
        expect(
          segments.any(
            (s) => (s.$1 - pad).distance < 1e-4 || (s.$2 - pad).distance < 1e-4,
          ),
          isTrue,
          reason: 'nothing reaches $pad any more',
        );
      }
    });

    test('the run itself actually moved, and stayed straight', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );
      final moved = slide.moved.single;
      expect(moved.startY, closeTo(16, 1e-9));
      expect(moved.endY, closeTo(16, 1e-9));
    });

    test('the run is trimmed so a 45 can reach it from each pad', () {
      // The shape a hand would draw: 45 out of the pad, a shorter straight
      // run, 45 into the far pad. The run getting *shorter* is the whole
      // trick — pinning its ends where they started is what forced a
      // perpendicular off the pad.
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );

      final moved = slide.moved.single;
      expect(moved.startX, closeTo(14, 1e-9));
      expect(moved.endX, closeTo(20, 1e-9));

      // One segment off each pad, not two, and both at 45.
      expect(slide.added, hasLength(2));
      for (final segment in slide.added) {
        final d = segment.to - segment.from;
        expect(d.dx.abs(), closeTo(d.dy.abs(), 1e-9));
      }
    });

    test('pushing it along its own length does nothing at all', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(5, 0),
        anchors: const [padA, padB],
      );
      expect(slide.isEmpty, isTrue);
    });
  });

  group('reported: sliding a trace with an arc in it', () {
    // "trying to move a trace with an arc completely breaks the wire, like
    // it jumps all over the screen." A rounded corner is a chain of short
    // segments a few degrees apart; moving one out of the middle of it,
    // and patching the neighbours by intersecting near-parallel lines,
    // sends the corner off to infinity.
    List<Track> arcRoute() {
      // A real route: a straight run into a rounded corner and a 45 out.
      final skeleton = [
        const Offset(10, 20),
        ...legalCorners(
          const Offset(10, 20),
          const Offset(30, 26),
          TrackAngleLock.deg45,
        ),
      ];
      final points = roundCorners(skeleton, radius: 2);
      return [
        for (var i = 0; i < points.length - 1; i++)
          _track(
            's$i',
            points[i].dx,
            points[i].dy,
            points[i + 1].dx,
            points[i + 1].dy,
          ),
      ];
    }

    test('the whole curve travels as one piece', () {
      final tracks = arcRoute();
      // A segment from the middle of the bend.
      final inTheBend = tracks[tracks.length ~/ 2];
      final slide = slideTrack(
        track: inTheBend,
        others: tracks,
        delta: const Offset(3, 3),
      );

      // Everything smooth moved together rather than one piece being torn
      // out of the curve.
      expect(slide.moved.length, greaterThan(1));
    });

    test('nothing is flung off the board', () {
      final tracks = arcRoute();
      final inTheBend = tracks[tracks.length ~/ 2];
      final before = tracks.expand(
        (t) => [Offset(t.startX, t.startY), Offset(t.endX, t.endY)],
      );
      final extent = before
          .map((p) => math.max(p.dx.abs(), p.dy.abs()))
          .reduce(math.max);

      final slide = slideTrack(
        track: inTheBend,
        others: tracks,
        delta: const Offset(2, 2),
      );

      for (final (from, to) in _resulting(tracks, slide)) {
        for (final point in [from, to]) {
          expect(
            math.max(point.dx.abs(), point.dy.abs()),
            lessThan(extent + 50),
            reason: 'a point ended up at $point, far off the board',
          );
        }
      }
    });

    test('the curve keeps its shape', () {
      final tracks = arcRoute();
      final inTheBend = tracks[tracks.length ~/ 2];
      final slide = slideTrack(
        track: inTheBend,
        others: tracks,
        delta: const Offset(2, 2),
      );

      // The pieces in the middle of the curve are translated, not
      // stretched, so each keeps its length exactly and the bend is not
      // flattened. The two at the ends are trimmed to meet whatever the
      // curve reconnects to, which is the point of the reconnection.
      final before = {for (final t in tracks) t.id: t};
      final movedIds = {for (final t in slide.moved) t.id};
      final ends = _looseEnds(slide.moved);

      var interior = 0;
      for (final after in slide.moved) {
        final touchesEnd = ends.any(
          (end) =>
              (Offset(after.startX, after.startY) - end).distance < 1e-4 ||
              (Offset(after.endX, after.endY) - end).distance < 1e-4,
        );
        if (touchesEnd) continue;
        interior++;

        final original = before[after.id]!;
        expect(
          _lengthOf(after),
          closeTo(_lengthOf(original), 1e-9),
          reason: '${after.id} was stretched rather than moved',
        );
      }
      expect(movedIds.length, greaterThan(1));
      expect(interior, greaterThan(0), reason: 'nothing to check');
    });

    test('a straight running into a curve does not drag the curve along', () {
      // "when you slide the trace upwards on the arced version, the arc
      // stays in the same direction it was, so it looks like a ramp and
      // then a waterfall." It was dragging the whole curve with the run
      // and then joining the result to the pads with stubs.
      final tracks = arcRoute();
      final straight = tracks.first;
      final slide = slideTrack(
        track: straight,
        others: tracks,
        delta: const Offset(0, -3),
        anchors: const [Offset(10, 20), Offset(30, 26)],
      );

      // Only the straight moved; the bend stayed where it was.
      expect(slide.moved.map((t) => t.id), [straight.id]);

      // And what joins them is legal copper, not a stub at a stray angle.
      for (final segment in slide.added) {
        final d = segment.to - segment.from;
        expect(
          isLegalBearing(d.dx, d.dy, TrackAngleLock.deg45),
          isTrue,
          reason: 'joined the curve at a stray angle',
        );
      }
    });

    test('the route is still one unbroken chain', () {
      final tracks = arcRoute();
      final slide = slideTrack(
        track: tracks[tracks.length ~/ 2],
        others: tracks,
        delta: const Offset(2, 2),
      );
      _expectJoinedUp(_resulting(tracks, slide));
    });
  });

  group('what counts as one run', () {
    test('a real corner stops it', () {
      // A 45 corner is a corner, not a curve: sliding the run must not drag
      // the diagonal along with it.
      final run = _track('run', 10, 20, 24, 20);
      final diagonal = _track('diag', 24, 20, 30, 26);
      final slide = slideTrack(
        track: run,
        others: [run, diagonal],
        delta: const Offset(0, -3),
      );
      expect(slide.moved.map((t) => t.id), ['run']);
    });

    test('collinear pieces come along', () {
      final first = _track('a', 0, 0, 10, 0);
      final second = _track('b', 10, 0, 20, 0);
      final slide = slideTrack(
        track: first,
        others: [first, second],
        delta: const Offset(0, 2),
      );
      expect(slide.moved.map((t) => t.id).toSet(), {'a', 'b'});
    });

    test('a branch stops it, because which way to go is not ours to pick', () {
      final run = _track('run', 0, 0, 10, 0);
      final onward = _track('on', 10, 0, 20, 0);
      final branch = _track('br', 10, 0, 10, 10);
      final slide = slideTrack(
        track: run,
        others: [run, onward, branch],
        delta: const Offset(0, 2),
      );
      expect(slide.moved.map((t) => t.id), ['run']);
    });
  });

  test('a lone segment on two pads stays on them', () {
    final only = _track('o', 0, 0, 10, 0);
    final slide = slideTrack(
      track: only,
      others: [only],
      delta: const Offset(0, 3),
      anchors: const [Offset(0, 0), Offset(10, 0)],
    );

    final segments = _resulting([only], slide);
    _expectAllLegal(segments);
    for (final pad in const [Offset(0, 0), Offset(10, 0)]) {
      expect(
        segments.any(
          (s) => (s.$1 - pad).distance < 1e-4 || (s.$2 - pad).distance < 1e-4,
        ),
        isTrue,
      );
    }
  });

  test('a zero-length segment is left alone', () {
    final degenerate = _track('d', 5, 5, 5, 5);
    expect(
      slideTrack(
        track: degenerate,
        others: [degenerate],
        delta: const Offset(2, 2),
      ).isEmpty,
      isTrue,
    );
  });

  group('reported: dragging on past the triangle', () {
    // "if you keep dragging, it lets you drag infinitely, like when it just
    // becomes a triangular looking trace, that's when it should stop."
    final run = _track('run', 10, 20, 24, 20);
    final diagonal = _track('diag', 24, 20, 30, 26);
    final tracks = [run, diagonal];
    const padA = Offset(10, 20);
    const padB = Offset(30, 26);

    TrackSlide far() => slideTrack(
      track: run,
      others: tracks,
      delta: const Offset(0, -100),
      anchors: const [padA, padB],
    );

    test('it stops where the run has shrunk to nothing', () {
      // The joins from each pad meet once the run has gone: a 45 up from
      // (10,20) and a 45 up from (30,26) cross at (17,13).
      final slide = far();
      expect(slide.added, hasLength(2));
      for (final segment in slide.added) {
        expect((segment.to - const Offset(17, 13)).distance, lessThan(1e-3));
      }
    });

    test('the run is gone rather than left as a scrap of copper', () {
      final slide = far();
      expect(slide.moved, isEmpty);
      expect(slide.removed, contains('run'));
    });

    test('nothing folds back over itself', () {
      final segments = _resulting(tracks, far());
      _expectAllLegal(segments);
      // Nothing beyond the meeting point: going further is exactly the
      // crossed-over shape that has to be refused.
      for (final (from, to) in segments) {
        expect(from.dy, greaterThanOrEqualTo(13 - 1e-3));
        expect(to.dy, greaterThanOrEqualTo(13 - 1e-3));
      }
    });

    test('a slide short of the limit is not clamped', () {
      final slide = slideTrack(
        track: run,
        others: tracks,
        delta: const Offset(0, -4),
        anchors: const [padA, padB],
      );
      expect(slide.moved.single.startY, closeTo(16, 1e-9));
    });
  });
}
