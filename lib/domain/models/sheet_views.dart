import 'dart:math' as math;
import 'dart:ui';

import 'net.dart';
import 'schematic_sheet.dart';

/// One pin on a sheet's box: where it joins the edge, which edge, its
/// KiCad shape, and the net it carries when one crosses there.
class SheetBoxPin {
  const SheetBoxPin({
    required this.name,
    required this.at,
    required this.side,
    this.shape = 'bidirectional',
    this.net,
  });

  final String name;
  final Offset at;
  final SheetSide side;
  final String shape;
  final NetWithEndpoints? net;
}

/// A sub-sheet as its parent draws it: a box, its name, and its pins.
///
/// Pins the sheet came with (from a KiCad file) stay where they were drawn.
/// Any other net crossing the edge gets a pin too, down the left side below
/// them in name order, which is how a sheet made here gets all of its pins.
class SheetBoxView {
  SheetBoxView._(this.sheet, this.pins, this.box);

  /// [crossing] are the nets crossing the box's edge; [nets], every net,
  /// for the pins it came with — a supply's pin still carries its supply,
  /// though a supply joins by name and never needs a pin of its own.
  factory SheetBoxView.of(
    SchematicSheet sheet, {
    required List<NetWithEndpoints> crossing,
    List<NetWithEndpoints>? nets,
  }) {
    final pins = <SheetBoxPin>[];
    final carried = <String>{};
    for (final pin in sheet.pins) {
      final net = netOfPin(pin, nets ?? crossing);
      if (net != null) carried.add(net.id);
      pins.add(
        SheetBoxPin(
          name: pin.name,
          at: pin.at(sheet.box),
          side: pin.side,
          shape: pin.shape,
          net: net,
        ),
      );
    }
    final rest = [
      for (final net in crossing)
        if (!carried.contains(net.id)) net,
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
    // Below the lowest pin already on the left, one pitch apart.
    var below = 0.0;
    for (final pin in sheet.pins) {
      if (pin.side == SheetSide.left && pin.offset > below) below = pin.offset;
    }
    for (var i = 0; i < rest.length; i++) {
      pins.add(
        SheetBoxPin(
          name: rest[i].displayName,
          at: Offset(sheet.box.left, sheet.box.top + below + pitch * (i + 1)),
          side: SheetSide.left,
          net: rest[i],
        ),
      );
    }
    final needed = below + (rest.length + 1) * pitch;
    final box = Rect.fromLTWH(
      sheet.box.left,
      sheet.box.top,
      sheet.box.width,
      rest.isEmpty ? sheet.box.height : math.max(sheet.box.height, needed),
    );
    return SheetBoxView._(sheet, pins, box);
  }

  static const pitch = 2.54;

  final SchematicSheet sheet;
  final List<SheetBoxPin> pins;

  /// The box, tall enough for every pin.
  final Rect box;

  SheetBoxPin? pinNamed(String name) =>
      pins.where((p) => p.name == name).firstOrNull;

  /// The net among [nets] that [pin] carries: the one it came in with, or
  /// failing that one named after it — `USB1_N`, or `/connectors/USB1_N` as
  /// the import names a sheet's net.
  static NetWithEndpoints? netOfPin(
    SheetPin pin,
    Iterable<NetWithEndpoints> nets,
  ) {
    final id = pin.netId;
    if (id != null) {
      for (final net in nets) {
        if (net.id == id) return net;
      }
    }
    for (final net in nets) {
      final name = net.displayName;
      if (name == pin.name || name.endsWith('/${pin.name}')) return net;
    }
    return null;
  }

  /// The name [net] goes by where it leaves [sheet] for its parent: the
  /// sheet's own pin for it, when it has one, else the net's name.
  static String upwardName(SchematicSheet? sheet, NetWithEndpoints net) {
    if (sheet != null) {
      for (final pin in sheet.pins) {
        if (netOfPin(pin, [net]) != null) return pin.name;
      }
    }
    return net.displayName;
  }
}

/// A pin whose net goes on to another sheet, with the net's name drawn at
/// it: KiCad's hierarchical label inside a sub-sheet, a plain net label on
/// the top sheet.
class OffSheetLabel {
  const OffSheetLabel({
    required this.at,
    required this.name,
    required this.hierarchical,
  });

  final Offset at;
  final String name;
  final bool hierarchical;
}
