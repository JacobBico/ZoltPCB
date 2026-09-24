import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/geometry/pin_attachment.dart';

void main() {
  group('attachmentFor', () {
    test('lands the symbol on the side the wire leaves the pin', () {
      const pin = Offset(50, 40);

      // A pin whose wire leaves downwards — the bottom of a resistor.
      final below = attachmentFor(
        targetPosition: pin,
        targetExit: const Offset(0, 1),
        symbolPin: Offset.zero,
        symbolBodyEnd: Offset.zero,
      );
      expect(below.position.dx, closeTo(50, 1e-9));
      expect(below.position.dy, greaterThan(40));

      // A pin whose wire leaves to the left — an opamp input.
      final left = attachmentFor(
        targetPosition: pin,
        targetExit: const Offset(-1, 0),
        symbolPin: Offset.zero,
        symbolBodyEnd: Offset.zero,
      );
      expect(left.position.dx, lessThan(50));
      expect(left.position.dy, closeTo(40, 1e-9));
    });

    test('leaves a gap for the wire rather than stacking on the pin', () {
      final attachment = attachmentFor(
        targetPosition: const Offset(10, 10),
        targetExit: const Offset(0, 1),
        symbolPin: Offset.zero,
        symbolBodyEnd: Offset.zero,
        gapMm: 5.08,
      );
      expect(attachment.position, const Offset(10, 15.08));
    });

    test('a power symbol is never turned on its head', () {
      // Stock power symbols carry a zero-length pin, so nothing about them
      // says which way they face — and a ground drawn pointing up is not a
      // ground any more.
      for (final exit in const [
        Offset(0, 1),
        Offset(0, -1),
        Offset(1, 0),
        Offset(-1, 0),
      ]) {
        final attachment = attachmentFor(
          targetPosition: Offset.zero,
          targetExit: exit,
          symbolPin: Offset.zero,
          symbolBodyEnd: Offset.zero,
        );
        expect(attachment.rotation, 0, reason: 'exit $exit');
      }
    });

    test('a symbol with a real pin is turned to face the target', () {
      // A pin at the symbol's origin whose stub runs left, so the wire
      // leaves to the right.
      const symbolPin = Offset.zero;
      const symbolBodyEnd = Offset(-2.54, 0);

      // Facing a pin whose own wire leaves to the right: the attached
      // symbol must send its wire left, which is half a turn.
      final facing = attachmentFor(
        targetPosition: const Offset(20, 20),
        targetExit: const Offset(1, 0),
        symbolPin: symbolPin,
        symbolBodyEnd: symbolBodyEnd,
      );
      expect(facing.rotation, 180);

      // Facing a pin whose wire leaves downwards, the attached symbol has
      // to send its own wire up.
      final vertical = attachmentFor(
        targetPosition: const Offset(20, 20),
        targetExit: const Offset(0, 1),
        symbolPin: symbolPin,
        symbolBodyEnd: symbolBodyEnd,
      );
      expect(vertical.rotation, anyOf(90, 270));
    });

    test('an off-origin pin still ends up where it was asked for', () {
      // The unit's origin is placed so that the pin, not the origin, lands
      // at the gap. Otherwise a symbol whose pin sits away from its origin
      // attaches somewhere near the pin rather than on it.
      const symbolPin = Offset(0, 3.81);
      final attachment = attachmentFor(
        targetPosition: const Offset(30, 30),
        targetExit: const Offset(0, 1),
        symbolPin: symbolPin,
        symbolBodyEnd: symbolPin,
        gapMm: 2.54,
      );
      // Symbol space is Y-up, so the pin at +3.81 draws 3.81 above the
      // origin on the sheet; the origin therefore sits that much lower.
      expect(attachment.position.dy, closeTo(30 + 2.54 + 3.81, 1e-9));
    });
  });
}
