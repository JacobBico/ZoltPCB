import 'dart:math' as math;

import 'symbol_definition.dart';
import 'symbol_pin.dart';

/// Which edge of the drawn package a pin comes out of.
enum PackageSide { left, right, top, bottom }

/// One pin, placed on an edge of the package.
class PackagePin {
  const PackagePin({
    required this.pin,
    required this.side,
    required this.along,
  });

  final SymbolPin pin;
  final PackageSide side;

  /// Position along the edge, already in reading order: top to bottom on
  /// the sides, left to right on the top and bottom.
  final double along;

  String get number => pin.number;
  String get name => pin.hasName ? pin.name : pin.number;
}

/// A symbol's pins arranged the way the chip is drawn — one edge at a time.
///
/// This is what makes a package diagram possible without any footprint or
/// datasheet: a KiCad MCU symbol is already drawn as a rectangle with pins
/// on its four sides, so the symbol's own geometry says which side each pin
/// belongs to and in what order. The diagram is then the symbol, redrawn
/// large enough to touch.
class PackageLayout {
  const PackageLayout(this.pins);

  final List<PackagePin> pins;

  bool get isEmpty => pins.isEmpty;

  List<PackagePin> onSide(PackageSide side) => [
    for (final pin in pins)
      if (pin.side == side) pin,
  ]..sort((a, b) => a.along.compareTo(b.along));

  /// The pins of [symbol], sorted onto edges.
  ///
  /// Multi-unit symbols are read one unit at a time — drawing every gate of
  /// a quad op-amp on one outline would be a picture of nothing real. Pins
  /// common to all units (unit 0) join whichever unit is asked for, which is
  /// how a shared supply pin appears on the diagram at all.
  static PackageLayout of(SymbolDefinition symbol, {int unit = 1}) {
    final placed = <PackagePin>[];
    final seen = <String>{};

    for (final drawing in symbol.unitDrawings) {
      if (drawing.bodyStyle > 1) continue;
      if (drawing.unit != unit && !drawing.isCommonToAllUnits) continue;

      for (final pin in drawing.pins) {
        if (pin.hidden) continue;
        if (!seen.add(pin.number)) continue;

        // The stub runs from the connection point towards the body, so the
        // direction it points names the side the pin sits on: a pin whose
        // body lies to its right is on the package's left edge.
        final radians = pin.angle * math.pi / 180;
        final towardsBodyX = math.cos(radians);
        final towardsBodyY = math.sin(radians);

        final horizontal = towardsBodyX.abs() >= towardsBodyY.abs();
        final side = horizontal
            ? (towardsBodyX > 0 ? PackageSide.left : PackageSide.right)
            // KiCad symbol space has +y upwards; the drawn package does not.
            : (towardsBodyY > 0 ? PackageSide.bottom : PackageSide.top);

        placed.add(
          PackagePin(
            pin: pin,
            side: side,
            // Down the page on the left and right edges, across it on the
            // top and bottom — the order the eye reads them in.
            along: horizontal ? -pin.at.y : pin.at.x,
          ),
        );
      }
    }

    return PackageLayout(placed);
  }
}
