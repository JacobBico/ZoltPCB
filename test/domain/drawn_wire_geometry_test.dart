import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/geometry/drawn_wire_geometry.dart';

bool _square(List<Offset> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    if ((a.dx - b.dx).abs() > 1e-6 && (a.dy - b.dy).abs() > 1e-6) return false;
  }
  return true;
}

void main() {
  group('drawing corner by corner', () {
    test('an off-axis tap gains one bend, never a diagonal', () {
      final path = DrawnWireGeometry.orthogonalPath(const [
        Offset(0, 0),
        Offset(10, 5),
      ]);
      expect(path, const [Offset(0, 0), Offset(10, 0), Offset(10, 5)]);
    });

    test('taps in a line are one run', () {
      final path = DrawnWireGeometry.orthogonalPath(const [
        Offset(0, 0),
        Offset(5, 0),
        Offset(10, 0),
      ]);
      expect(path, const [Offset(0, 0), Offset(10, 0)]);
    });

    test('a chain keeps going the way it was going', () {
      final path = DrawnWireGeometry.orthogonalPath(const [
        Offset(0, 0),
        Offset(0, 10),
        Offset(5, 15),
      ]);
      expect(_square(path), isTrue);
      // Down, then on down to the tap's height, then across.
      expect(path, const [Offset(0, 0), Offset(0, 15), Offset(5, 15)]);
    });
  });

  test('a bend never doubles back over the run before it', () {
    // Up from a pin to a corner, then to a pin level with the first: going
    // on vertically would retrace the run just drawn.
    final path = DrawnWireGeometry.orthogonalPath(const [
      Offset(0, 10),
      Offset(0, 5),
      Offset(20, 10),
    ]);
    expect(path, const [
      Offset(0, 10),
      Offset(0, 5),
      Offset(20, 5),
      Offset(20, 10),
    ]);
  });

  group('following a part that moved', () {
    const drawn = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(20, 10)];

    test('the end run keeps its direction and its far corner follows', () {
      final moved = DrawnWireGeometry.attachEnds(
        drawn,
        start: const Offset(0, 2),
      );
      expect(moved.first, const Offset(0, 2));
      expect(moved[1], const Offset(10, 2));
      expect(_square(moved), isTrue);
    });

    test('both ends at once stay square', () {
      final moved = DrawnWireGeometry.attachEnds(
        drawn,
        start: const Offset(-3, 4),
        end: const Offset(25, 7),
      );
      expect(moved.first, const Offset(-3, 4));
      expect(moved.last, const Offset(25, 7));
      expect(_square(moved), isTrue);
    });

    test('a single straight run pulled sideways gains a corner', () {
      final moved = DrawnWireGeometry.attachEnds(const [
        Offset(0, 0),
        Offset(10, 0),
      ], start: const Offset(0, 3));
      expect(moved.first, const Offset(0, 3));
      expect(moved.last, const Offset(10, 0));
      expect(_square(moved), isTrue);
    });
  });

  group('sliding a run like a track', () {
    const drawn = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(20, 10)];

    test('a middle run slides sideways and its neighbours stretch', () {
      final slid = DrawnWireGeometry.slideRun(drawn, 1, const Offset(4, 99));
      // Vertical run: only the sideways part of the push counts.
      expect(slid, const [
        Offset(0, 0),
        Offset(14, 0),
        Offset(14, 10),
        Offset(20, 10),
      ]);
    });

    test('an end run keeps its end on the pin with a new stub', () {
      final slid = DrawnWireGeometry.slideRun(drawn, 0, const Offset(0, -3));
      expect(slid.first, const Offset(0, 0));
      expect(slid.last, const Offset(20, 10));
      expect(_square(slid), isTrue);
      expect(slid, contains(const Offset(10, -3)));
    });

    test('pushing along a run moves nothing', () {
      final slid = DrawnWireGeometry.slideRun(drawn, 0, const Offset(5, 0));
      expect(slid, drawn);
    });
  });

  // "it should only have a dot if it is a JUNCTION not when its just curving
  // around, like you just go straight and take a left, that isnt a junction,
  // thats just a turn"
  group('junction dots', () {
    test('a corner is a turn, not a junction', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
        ]),
        isEmpty,
      );
    });

    test('one wire carrying on where another stops needs no dot', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 0), Offset(10, 0)],
          const [Offset(10, 0), Offset(10, 10)],
        ]),
        isEmpty,
      );
    });

    test('a wire ending on the middle of another is a junction', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 0), Offset(20, 0)],
          const [Offset(10, 0), Offset(10, 10)],
        ]),
        [const Offset(10, 0)],
      );
    });

    test('three ends meeting at a point is a junction', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 0), Offset(10, 0)],
          const [Offset(10, 0), Offset(20, 0)],
          const [Offset(10, 0), Offset(10, 10)],
        ]),
        [const Offset(10, 0)],
      );
    });

    test('one wire reaching a pin is not a junction, two are', () {
      expect(
        DrawnWireGeometry.junctions(
          [
            const [Offset(0, 0), Offset(10, 0)],
          ],
          pins: [const Offset(10, 0)],
        ),
        isEmpty,
      );
      expect(
        DrawnWireGeometry.junctions(
          [
            const [Offset(0, 0), Offset(10, 0)],
            const [Offset(10, 0), Offset(10, 10)],
          ],
          pins: [const Offset(10, 0)],
        ),
        [const Offset(10, 0)],
      );
    });

    // "the lower junction is incorrect because the wires once again
    // intersect and it treats it as a junction"
    test('a wire ending inside another it lies along is not a junction', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(10, 0), Offset(10, 20)],
          // Along the same line, ending part-way inside it.
          const [Offset(10, 5), Offset(10, -10)],
        ]),
        isEmpty,
      );
    });

    // Wires of one net that cross are joined, so the crossing is a junction
    // and says so; wires of different nets never reach this, and hop over
    // one another instead.
    test('two wires of a net crossing are dotted', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 10), Offset(20, 10)],
          const [Offset(10, 0), Offset(10, 20)],
        ]),
        [const Offset(10, 10)],
      );
    });

    test('a loose end on its own is not a junction', () {
      expect(
        DrawnWireGeometry.junctions([
          const [Offset(0, 0), Offset(10, 0)],
        ]),
        isEmpty,
      );
    });
  });

  // "it must drag a wire along side it like in KiCAD" — the corner of the
  // wire left behind has to come too.
  group('moving a corner', () {
    test('both runs bend to keep up with it', () {
      final moved = DrawnWireGeometry.moveVertex(
        const [Offset(0, 10), Offset(10, 10), Offset(10, 20)],
        1,
        const Offset(10, 5),
      );
      expect(moved.first, const Offset(0, 10), reason: 'the far end stays');
      expect(moved.last, const Offset(10, 20), reason: 'and so does the other');
      expect(moved, contains(const Offset(10, 5)));
      for (var i = 0; i < moved.length - 1; i++) {
        final run = moved[i + 1] - moved[i];
        expect(
          run.dx.abs() < 1e-9 || run.dy.abs() < 1e-9,
          isTrue,
          reason: 'every run stays square: $moved',
        );
      }
    });

    test('an end is moved the way an end always was', () {
      expect(
        DrawnWireGeometry.moveVertex(
          const [Offset(0, 0), Offset(10, 0)],
          1,
          const Offset(10, 4),
        ).last,
        const Offset(10, 4),
      );
    });

    test('a corner can be put in where another wire meets a run', () {
      expect(
        DrawnWireGeometry.splitAt(const [
          Offset(0, 0),
          Offset(20, 0),
        ], const Offset(8, 0)),
        [const Offset(0, 0), const Offset(8, 0), const Offset(20, 0)],
      );
    });
  });

  // "when a wire goes over another wire ... I'd rather have you replace that
  // overlap section with a little semi-circle, how they draw it in papers"
  group('wires that cross', () {
    test('a proper crossing has a point', () {
      expect(
        DrawnWireGeometry.crossing(
          const Offset(0, 5),
          const Offset(10, 5),
          const Offset(5, 0),
          const Offset(5, 10),
        ),
        const Offset(5, 5),
      );
    });

    test('a wire ending on another is not a crossing', () {
      expect(
        DrawnWireGeometry.crossing(
          const Offset(0, 5),
          const Offset(10, 5),
          const Offset(5, 5),
          const Offset(5, 10),
        ),
        isNull,
      );
    });

    test('parallel wires never cross', () {
      expect(
        DrawnWireGeometry.crossing(
          const Offset(0, 5),
          const Offset(10, 5),
          const Offset(0, 8),
          const Offset(10, 8),
        ),
        isNull,
      );
    });

    test('segments that miss each other do not count', () {
      expect(
        DrawnWireGeometry.crossing(
          const Offset(0, 5),
          const Offset(4, 5),
          const Offset(8, 0),
          const Offset(8, 10),
        ),
        isNull,
      );
    });
  });

  group('looseEnds', () {
    test('an end on a pin or on another wire is not loose', () {
      final ends = DrawnWireGeometry.looseEnds(
        [
          [const Offset(0, 0), const Offset(10, 0)],
          // Ends part-way along the first wire.
          [const Offset(5, 0), const Offset(5, 8)],
        ],
        anchors: const [Offset(0, 0), Offset(10, 0)],
      );
      expect(ends, [const Offset(5, 8)]);
    });

    test('a wire that stops short of a pin is loose at that end', () {
      final ends = DrawnWireGeometry.looseEnds(
        [
          [const Offset(0, 0), const Offset(0, 5), const Offset(9.9, 5)],
        ],
        anchors: const [Offset(0, 0), Offset(10, 5)],
      );
      expect(ends, [const Offset(9.9, 5)]);
    });

    test('a wire ending on its own corner is not loose', () {
      final ends = DrawnWireGeometry.looseEnds(
        [
          [
            const Offset(0, 0),
            const Offset(10, 0),
            const Offset(10, 10),
            const Offset(5, 10),
            const Offset(5, 0),
          ],
        ],
        anchors: const [Offset(0, 0)],
      );
      expect(ends, isEmpty);
    });
  });
}
