import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/geometry/net_routing.dart';
import 'package:hintpcb/domain/models/models.dart';

RoutablePin _pin(String id, double x, double y) => RoutablePin(
  id: id,
  position: Offset(x, y),
  exitDirection: const Offset(1, 0),
);

SchematicWire _wire(String id, String a, String b, List<Offset> points) =>
    SchematicWire(
      id: id,
      projectId: 'p',
      netId: 'n',
      pinAId: a,
      pinBId: b,
      points: points,
    );

void main() {
  final pins = [_pin('a', 0, 0), _pin('b', 20, 10), _pin('c', 40, 0)];

  test('a net drawn completely by hand shows only what was drawn', () {
    final wires = NetRouting.routeNetWithDrawn(
      'n',
      pins,
      drawn: [
        _wire('w1', 'a', 'b', const [
          Offset(0, 0),
          Offset(20, 0),
          Offset(20, 10),
        ]),
        _wire('w2', 'b', 'c', const [
          Offset(20, 10),
          Offset(40, 10),
          Offset(40, 0),
        ]),
      ],
    );
    expect(wires, hasLength(2));
    expect(wires.every((w) => w.isDrawn), isTrue);
  });

  test('what the drawn wires leave unjoined is routed, once', () {
    final wires = NetRouting.routeNetWithDrawn(
      'n',
      pins,
      drawn: [
        _wire('w1', 'a', 'b', const [
          Offset(0, 0),
          Offset(20, 0),
          Offset(20, 10),
        ]),
      ],
    );
    expect(wires.where((w) => w.isDrawn), hasLength(1));
    final automatic = wires.where((w) => !w.isDrawn).toList();
    expect(automatic, hasLength(1));
    // Joining pin c to the drawn piece, not re-joining a to b.
    expect({automatic.single.pinAId, automatic.single.pinBId}, contains('c'));
  });

  test('a drawn wire follows its pins to where they are now', () {
    final moved = [_pin('a', 0, 5), _pin('b', 20, 10)];
    final wires = NetRouting.routeNetWithDrawn(
      'n',
      moved,
      drawn: [
        _wire('w1', 'a', 'b', const [
          Offset(0, 0),
          Offset(20, 0),
          Offset(20, 10),
        ]),
      ],
    );
    expect(wires.single.points.first, const Offset(0, 5));
    expect(wires.single.points.last, const Offset(20, 10));
  });
}
