import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/net_routing.dart';
import 'package:zolt/rendering/schematic_painter.dart';

RoutedWire _wire(String net, List<Offset> points) => RoutedWire(
  netId: net,
  pinAId: '',
  pinBId: '',
  points: points,
  drawnId: net,
);

void main() {
  // "when a wire goes over another wire ... I'd rather have you replace that
  // overlap section with a little semi-circle"
  test('the horizontal wire hops where nets cross', () {
    final hops = SchematicPainter.hopPoints([
      _wire('a', const [Offset(0, 10), Offset(20, 10)]),
      _wire('b', const [Offset(10, 0), Offset(10, 20)]),
    ]);

    expect(hops[0][0], [const Offset(10, 10)], reason: 'the horizontal hops');
    expect(hops[1][0], isEmpty, reason: 'and the vertical is hopped over');
  });

  test('wires of one net cross without a hop: they are connected', () {
    final hops = SchematicPainter.hopPoints([
      _wire('a', const [Offset(0, 10), Offset(20, 10)]),
      _wire('a', const [Offset(10, 0), Offset(10, 20)]),
    ]);
    expect(hops[0][0], isEmpty);
  });

  test('a wire that only reaches another does not hop', () {
    final hops = SchematicPainter.hopPoints([
      _wire('a', const [Offset(0, 10), Offset(20, 10)]),
      _wire('b', const [Offset(10, 10), Offset(10, 20)]),
    ]);
    expect(hops[0][0], isEmpty);
  });

  test('the wire arches over a crossing it is given', () {
    const line = [Offset(0, 100), Offset(200, 100)];
    final plain = SchematicPainter.hoppedPath(line, [const []], 8);
    expect(plain.getBounds().top, 100, reason: 'a straight line stays flat');

    final hopped = SchematicPainter.hoppedPath(line, [
      const [Offset(100, 100)],
    ], 8);
    expect(
      hopped.getBounds().top,
      closeTo(92, 0.5),
      reason: 'the arch rises a radius above the line',
    );
    expect(hopped.getBounds().bottom, closeTo(100, 0.5));
  });

  test('a crossing too near a corner is left flat', () {
    final hugging = SchematicPainter.hoppedPath(
      const [Offset(0, 100), Offset(200, 100)],
      [
        const [Offset(4, 100)],
      ],
      8,
    );
    expect(hugging.getBounds().top, 100);
  });
}
