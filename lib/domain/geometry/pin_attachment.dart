import 'dart:ui';

import 'placement.dart';

/// Where to put a symbol so that one of its pins meets another pin.
///
/// Used to drop a power symbol onto the pin the user is looking at. The app
/// connects by net rather than by geometry, so this decides nothing
/// electrical — but a ground symbol that lands sideways above the pin it
/// grounds is wrong in the way that matters to whoever reads the sheet.
class PinAttachment {
  const PinAttachment({required this.position, required this.rotation});

  /// Where the unit's origin goes, in sheet millimetres.
  final Offset position;

  /// Degrees counter-clockwise, one of 0, 90, 180 or 270.
  final int rotation;

  @override
  String toString() => 'PinAttachment($position, $rotation°)';
}

/// Faces [symbolPin] back towards a pin at [targetPosition].
///
/// [targetExit] is the direction a wire leaves the target pin. The attached
/// symbol is turned so its own pin leaves the opposite way — the two face
/// each other — and placed [gapMm] along that direction, leaving room for
/// the wire between them.
PinAttachment attachmentFor({
  required Offset targetPosition,
  required Offset targetExit,
  required Offset symbolPin,
  required Offset symbolBodyEnd,
  double gapMm = 2.54,
}) {
  // A zero-length pin — which every stock power symbol has — says nothing
  // about which way it faces. Those symbols are drawn the right way up
  // already: a ground points down, a supply points up, and turning one to
  // chase a pin would only make it unrecognisable.
  if ((symbolPin - symbolBodyEnd).distance < 1e-6) {
    // Still through the placement, not straight off the symbol
    // coordinates: symbol space is Y-up and the sheet is Y-down, so a pin
    // above the origin has to move the origin down, not up.
    const upright = Placement(x: 0, y: 0);
    return PinAttachment(
      position:
          targetPosition +
          targetExit * gapMm -
          upright.apply(symbolPin.dx, symbolPin.dy),
      rotation: 0,
    );
  }

  final wanted = -targetExit;

  var bestRotation = 0;
  var bestScore = double.negativeInfinity;
  for (final rotation in const [0, 90, 180, 270]) {
    final placement = Placement(x: 0, y: 0, rotation: rotation);
    final pin = placement.apply(symbolPin.dx, symbolPin.dy);
    final body = placement.apply(symbolBodyEnd.dx, symbolBodyEnd.dy);
    final away = pin - body;
    final exit = away / away.distance;
    final score = exit.dx * wanted.dx + exit.dy * wanted.dy;
    if (score > bestScore) {
      bestScore = score;
      bestRotation = rotation;
    }
  }

  final placement = Placement(x: 0, y: 0, rotation: bestRotation);
  final pinOffset = placement.apply(symbolPin.dx, symbolPin.dy);
  return PinAttachment(
    position: targetPosition + targetExit * gapMm - pinOffset,
    rotation: bestRotation,
  );
}
