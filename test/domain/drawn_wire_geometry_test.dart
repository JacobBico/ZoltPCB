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
}
