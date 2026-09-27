import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/placement.dart';

void main() {
  // A resistor's pins, in its own space: pin 1 above, pin 2 below.
  const pin1 = Offset(0, 3.81);
  const pin2 = Offset(0, -3.81);

  Offset at(Placement p, Offset pin) => p.apply(pin.dx, pin.dy);
  Matcher near(Offset o) => isA<Offset>()
      .having((v) => v.dx, 'dx', closeTo(o.dx, 1e-9))
      .having((v) => v.dy, 'dy', closeTo(o.dy, 1e-9));

  test('turned a quarter, then mirrored, the way KiCad does it', () {
    // KiCad's file says (at 100 50 90) (mirror x): R104 in its own
    // kit-dev-coldfire demo, whose netlist puts pin 1 on the left.
    const turned = Placement(x: 100, y: 50, rotation: 90, mirrorX: true);
    expect(at(turned, pin1), near(const Offset(96.19, 50)));
    expect(at(turned, pin2), near(const Offset(103.81, 50)));
    // Pin 1 points down into the body in its own space; here, from the
    // left end, that is to the right.
    expect(turned.pinAngle(270), 0);

    // Mirrored the other way: the same turn, then left for right.
    const other = Placement(x: 100, y: 50, rotation: 90, mirrorY: true);
    expect(at(other, pin1), near(const Offset(103.81, 50)));
  });

  test('unturned, or turned a half, the order makes no difference', () {
    for (final rotation in [0, 180]) {
      final p = Placement(x: 0, y: 0, rotation: rotation, mirrorX: true);
      final flip = rotation == 0 ? 1 : -1;
      expect(at(p, pin1), near(Offset(0, 3.81 * flip)));
    }
  });
}
