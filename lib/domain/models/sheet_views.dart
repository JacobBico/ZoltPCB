import 'dart:math' as math;
import 'dart:ui';

import 'schematic_sheet.dart';

/// A sub-sheet as its parent draws it: a box, its name, and a pin for
/// every net crossing its edge, down the left side in name order.
class SheetBoxView {
  SheetBoxView({required this.sheet, required List<String> pins})
    : pins = [...pins]..sort();

  static const pitch = 2.54;

  final SchematicSheet sheet;
  final List<String> pins;

  /// The box, tall enough for every pin.
  Rect get box {
    final needed = (pins.length + 1) * pitch;
    return Rect.fromLTWH(
      sheet.box.left,
      sheet.box.top,
      sheet.box.width,
      math.max(sheet.box.height, needed),
    );
  }

  /// Where pin [index] joins the box, on its left edge.
  Offset pinAt(int index) => Offset(box.left, box.top + pitch * (index + 1));

  Offset? pinNamed(String name) {
    final i = pins.indexOf(name);
    return i < 0 ? null : pinAt(i);
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
