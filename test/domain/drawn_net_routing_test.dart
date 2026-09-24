import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/net_routing.dart';
import 'package:zolt/domain/models/models.dart';

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
  _powerAnchorTests();

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

void _powerAnchorTests() {
  group('a power symbol is a label, not a wire', () {
    // "When adding a new power label, it automatically connects all the same
    // power labels, shouldn't happen. Should be all connected without the
    // wires automatically connected."
    test('two supplies on the same net are never bridged', () {
      final pins = [
        _pin('r1', 0, 0),
        _pin('pwr1', 0, -10),
        _pin('r2', 100, 0),
        _pin('pwr2', 100, -10),
      ];
      final wires = NetRouting.routeNetWithDrawn(
        'n',
        pins,
        powerPins: {'pwr1', 'pwr2'},
      );

      bool joins(String a, String b) => wires.any(
        (w) =>
            (w.pinAId == a && w.pinBId == b) ||
            (w.pinAId == b && w.pinBId == a),
      );
      expect(
        joins('pwr1', 'pwr2'),
        isFalse,
        reason: 'a wire was run between the two supplies',
      );
      // Each real pin still reaches the supply beside it, so the sheet
      // shows how it is connected.
      expect(joins('r1', 'pwr1') || joins('pwr1', 'r1'), isTrue);
      expect(joins('r2', 'pwr2') || joins('pwr2', 'r2'), isTrue);
      // And nothing runs the length of the sheet.
      for (final wire in wires) {
        final span = (wire.points.first - wire.points.last).distance;
        expect(span, lessThan(50), reason: 'a wire crossed the sheet');
      }
    });

    test('with no supplies it routes as it always did', () {
      final wires = NetRouting.routeNetWithDrawn('n', [
        _pin('a', 0, 0),
        _pin('b', 100, 0),
      ]);
      expect(wires, hasLength(1));
    });

    test('a labelled pin and a supply anchor the same way', () {
      final pins = [_pin('a', 0, 0), _pin('pwr', 100, 0)];
      expect(
        NetRouting.routeNetWithDrawn('n', pins, powerPins: {'pwr'}),
        hasLength(1),
        reason: 'one hop from the unanchored pin to the supply',
      );
      expect(
        NetRouting.routeNetWithDrawn(
          'n',
          pins,
          powerPins: {'pwr'},
          labelledPins: {'a'},
        ),
        isEmpty,
        reason: 'both ends carry their own name',
      );
    });
  });
}
