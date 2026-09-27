import 'net.dart';
import 'part.dart';
import 'schematic_sheet.dart';

/// How nets cross between the sheets of a hierarchical schematic.
///
/// Nothing here is stored. A net is a set of pins, project-wide, and each
/// pin sits on whichever sheet its unit is drawn on; which nets cross which
/// sheet's edge follows from that, so it can never go stale.
class SheetConnections {
  SheetConnections._(this.tree, this._sheetOfPin, this._nets);

  factory SheetConnections.of({
    required List<PartWithDetails> parts,
    required List<NetWithEndpoints> nets,
    required List<SchematicSheet> sheets,
  }) {
    final sheetOfPin = <String, String?>{};
    for (final part in parts) {
      final placed = [
        for (final u in part.units)
          if (u.placed) u,
      ]..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
      if (placed.isEmpty) continue;
      for (final pin in part.pins) {
        // A package's shared pins go with its first unit, the way the file
        // writes them.
        final unit = pin.unit == 0
            ? placed.first
            : placed.where((u) => u.unitNumber == pin.unit).firstOrNull;
        if (unit == null) continue;
        sheetOfPin[pin.id] = unit.sheetId;
      }
    }
    return SheetConnections._(SheetTree(sheets), sheetOfPin, nets);
  }

  final SheetTree tree;
  final Map<String, String?> _sheetOfPin;
  final List<NetWithEndpoints> _nets;

  /// Every net of the project.
  List<NetWithEndpoints> get nets => _nets;

  /// A supply is joined by its symbol on every sheet, as in KiCad: it
  /// never needs a sheet pin.
  static bool isPower(NetWithEndpoints net) =>
      net.endpoints.any((e) => e.part.reference.startsWith('#PWR'));

  /// The sheets [net]'s placed pins are on.
  Set<String?> sheetsOf(NetWithEndpoints net) => {
    for (final e in net.endpoints)
      if (_sheetOfPin.containsKey(e.pin.id)) _sheetOfPin[e.pin.id],
  };

  /// The sheet a pin is drawn on, or null for the top sheet. Pins of
  /// units not placed anywhere are not on any sheet.
  String? sheetOfPin(String pinId) => _sheetOfPin[pinId];
  bool isPlaced(String pinId) => _sheetOfPin.containsKey(pinId);

  /// The nets crossing the edge of [sheetId]: with pins inside it or the
  /// sheets beneath it, and pins outside. Each is a pin on its box, and a
  /// hierarchical label inside it.
  List<NetWithEndpoints> crossing(String sheetId) {
    final inside = tree.subtree(sheetId);
    return [
      for (final net in _nets)
        if (!isPower(net))
          if (sheetsOf(net) case final on
              when on.any(inside.contains) &&
                  on.any((s) => !inside.contains(s)))
            net,
    ];
  }

  /// The nets with a pin on [sheetId] that go on somewhere else — the ones
  /// the sheet shows with a label saying where.
  List<NetWithEndpoints> leaving(String? sheetId) => [
    for (final net in _nets)
      if (!isPower(net))
        if (sheetsOf(net) case final on
            when on.contains(sheetId) && on.length > 1)
          net,
  ];

  /// The sheets directly on [sheetId] that [net] reaches into: where on
  /// this sheet it joins a sheet's box.
  List<SchematicSheet> childrenReached(String? sheetId, NetWithEndpoints net) =>
      [
        for (final child in tree.childrenOf(sheetId))
          if (sheetsOf(net).any(tree.subtree(child.id).contains)) child,
      ];
}
