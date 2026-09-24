import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/segment_wiring.dart';

WireSegment _s(String id, Offset a, Offset b, {String? pinA, String? pinB}) =>
    WireSegment(id: id, a: a, b: b, pinA: pinA, pinB: pinB);

/// The segments as plain end pairs, for comparing without caring about ids.
List<(Offset, Offset)> _shape(List<WireSegment> segments) => [
  for (final s in segments) (s.a, s.b),
];

void main() {
  // "at EACH INTERSECTION in the net, there is a separate wire basically"
  group('tidying a net', () {
    test('a tee splits the wire it ends against', () {
      final tidy = SegmentWiring.canonicalise([
        _s('across', const Offset(0, 10), const Offset(20, 10)),
        _s('down', const Offset(10, 10), const Offset(10, 20)),
      ]);

      expect(tidy, hasLength(3));
      expect(
        _shape(tidy),
        containsAll([
          (const Offset(0, 10), const Offset(10, 10)),
          (const Offset(10, 10), const Offset(20, 10)),
          (const Offset(10, 10), const Offset(10, 20)),
        ]),
      );
    });

    test('two pieces in a line with nothing between are one piece', () {
      final tidy = SegmentWiring.canonicalise([
        _s('left', const Offset(0, 0), const Offset(10, 0)),
        _s('right', const Offset(10, 0), const Offset(20, 0)),
      ]);
      expect(_shape(tidy), [(const Offset(0, 0), const Offset(20, 0))]);
    });

    test('a corner stays two pieces: a third wire can start there', () {
      final tidy = SegmentWiring.canonicalise([
        _s('across', const Offset(0, 0), const Offset(10, 0)),
        _s('down', const Offset(10, 0), const Offset(10, 10)),
      ]);
      expect(tidy, hasLength(2));
    });

    // "the wires once again intersect and it treats it as a junction"
    test('a piece lying over another becomes one piece, and no junction', () {
      final tidy = SegmentWiring.canonicalise([
        _s('long', const Offset(10, 0), const Offset(10, 20)),
        _s('over', const Offset(10, 5), const Offset(10, -10)),
      ]);
      expect(_shape(tidy), [(const Offset(10, -10), const Offset(10, 20))]);
      expect(SegmentWiring.junctions(tidy), isEmpty);
    });

    test('a pin holds a straight run apart, so the join is kept', () {
      final tidy = SegmentWiring.canonicalise(
        [
          _s('left', const Offset(0, 0), const Offset(10, 0), pinB: 'p1'),
          _s('right', const Offset(10, 0), const Offset(20, 0), pinA: 'p1'),
        ],
        pins: [const Offset(10, 0)],
      );
      expect(tidy, hasLength(2));
    });
  });

  group('junction dots', () {
    test('three ends meeting get one', () {
      final tidy = SegmentWiring.canonicalise([
        _s('across', const Offset(0, 10), const Offset(20, 10)),
        _s('down', const Offset(10, 10), const Offset(10, 20)),
      ]);
      expect(SegmentWiring.junctions(tidy), [const Offset(10, 10)]);
    });

    test('a corner does not', () {
      final tidy = SegmentWiring.canonicalise([
        _s('across', const Offset(0, 0), const Offset(10, 0)),
        _s('down', const Offset(10, 0), const Offset(10, 10)),
      ]);
      expect(SegmentWiring.junctions(tidy), isEmpty);
    });

    test('two wires on a pin do', () {
      final tidy = SegmentWiring.canonicalise(
        [
          _s('across', const Offset(0, 0), const Offset(10, 0), pinB: 'p'),
          _s('down', const Offset(10, 0), const Offset(10, 10), pinA: 'p'),
        ],
        pins: [const Offset(10, 0)],
      );
      expect(SegmentWiring.junctions(tidy, pins: [const Offset(10, 0)]), [
        const Offset(10, 0),
      ]);
    });
  });

  // "it SHOULD also drag down the wire that its attached to ... Not just the
  // individual wire itself"
  group('dragging', () {
    test('what is joined to it comes with it', () {
      final tidy = SegmentWiring.canonicalise([
        _s('down', const Offset(10, 0), const Offset(10, 10)),
        _s('across', const Offset(10, 10), const Offset(30, 10)),
      ]);
      final across = tidy.firstWhere((s) => s.covers(const Offset(20, 10)));

      final dragged = SegmentWiring.drag(tidy, across.id!, const Offset(0, 10));

      final moved = dragged.firstWhere((s) => s.covers(const Offset(20, 20)));
      expect(moved.a.dy, 20);
      expect(moved.b.dy, 20);
      // The upright piece stretched to reach it instead of being left behind.
      final upright = dragged.firstWhere((s) => s.isVertical);
      expect(upright.a, const Offset(10, 0));
      expect(upright.b, const Offset(10, 20));
    });

    test('a pinned end stays on its pin, and the wire bends', () {
      final tidy = [
        _s('stub', const Offset(10, 0), const Offset(10, 10), pinA: 'p1'),
        _s('across', const Offset(10, 10), const Offset(30, 10)),
      ];
      final dragged = SegmentWiring.drag(
        tidy,
        'across',
        const Offset(5, 0),
        pins: [const Offset(10, 0)],
      );

      expect(
        dragged.any((s) => (s.a - const Offset(10, 0)).distance < 0.01),
        isTrue,
        reason: 'still starts at the pin',
      );
      for (final segment in dragged) {
        expect(
          segment.isHorizontal || segment.isVertical,
          isTrue,
          reason: 'no diagonals: $dragged',
        );
      }
      // Every piece still joins the next: the net is in one piece.
      final ends = <Offset>[];
      for (final segment in dragged) {
        ends
          ..add(segment.a)
          ..add(segment.b);
      }
      for (final segment in dragged) {
        expect(
          ends.where((p) => (p - segment.a).distance < 0.01).length +
              ends.where((p) => (p - segment.b).distance < 0.01).length,
          greaterThanOrEqualTo(3),
          reason: 'each piece meets another somewhere: $dragged',
        );
      }
    });

    test('dragging a middle piece keeps both its neighbours', () {
      final tidy = SegmentWiring.canonicalise([
        _s('a', const Offset(0, 0), const Offset(0, 10)),
        _s('b', const Offset(0, 10), const Offset(20, 10)),
        _s('c', const Offset(20, 10), const Offset(20, 0)),
      ]);
      final middle = tidy.firstWhere((s) => s.isHorizontal);
      final dragged = SegmentWiring.drag(tidy, middle.id!, const Offset(0, 5));

      expect(
        dragged.firstWhere((s) => s.isHorizontal).a.dy,
        15,
        reason: 'the piece moved',
      );
      // Each upright now reaches down to the piece's new height, whichever
      // way round it happens to be stored.
      expect(
        dragged.where((s) => s.isVertical).map((s) => math.max(s.a.dy, s.b.dy)),
        everyElement(15),
        reason: 'both uprights followed it down',
      );
    });
  });
}
