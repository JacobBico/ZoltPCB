import 'dart:ui';

import '../domain/models/models.dart';
import 'schematic_scene.dart';

/// What one sheet draws of the hierarchy: the boxes of the sheets on it,
/// and a name at each pin whose net carries on to another sheet. Shared by
/// the canvas and the PDF, so the printout says what the screen does.
(List<SheetBoxView>, List<OffSheetLabel>) sheetOverlays({
  required SheetConnections links,
  required SchematicScene scene,
  required String? sheetId,
  SchematicSheet? moving,
  Offset? movedTo,
}) {
  final boxes = [
    for (final child in links.tree.childrenOf(sheetId))
      SheetBoxView(
        sheet: moving != null && movedTo != null && child.id == moving.id
            ? child.copyWith(box: movedTo & child.box.size)
            : child,
        pins: [for (final net in links.crossing(child.id)) net.displayName],
      ),
  ];
  final inside = sheetId == null ? null : links.tree.subtree(sheetId);
  final pinAt = {for (final pin in scene.pins) pin.id: pin.sheetPosition};
  final labels = [
    for (final net in links.leaving(sheetId))
      if (net.endpoints.map((e) => pinAt[e.pin.id]).nonNulls.firstOrNull
          case final at?)
        OffSheetLabel(
          at: at,
          name: net.displayName,
          // Leaving this sheet for its parent: KiCad's hierarchical label.
          // Only going down into a box on it: a plain one.
          hierarchical:
              inside != null &&
              links.sheetsOf(net).any((s) => !inside.contains(s)),
        ),
  ];
  return (boxes, labels);
}
