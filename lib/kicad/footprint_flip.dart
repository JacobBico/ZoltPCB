import 'sexpr/sexpr.dart';
import 'sexpr/sexpr_writer.dart';

/// A footprint's contents turned over the way KiCad turns a footprint to
/// the back of a board: mirrored top to bottom about its own origin, with
/// every angle reversed. Layers are left to the caller, which swaps each
/// for its twin on the other side.
///
/// KiCad stores a back-side footprint's pads and drawings already turned
/// like this, and draws them with no further mirroring. The app keeps a
/// footprint as its library has it and mirrors it left to right when it
/// is on the back, turned half a turn more — the same place on the board,
/// by a different route. This is the step between the two, and it undoes
/// itself: applied twice, it gives back what it was given.
SExpr flipFootprintGeometry(SExpr node) {
  if (node is! SList) return node;
  switch (node.head) {
    // Three-dimensional models keep their own frame.
    case 'model':
      return node;
    case 'at':
      return SList([
        node.items.first,
        if (node.items.length > 1) node.items[1],
        if (node.items.length > 2) _negated(node.items[2]),
        if (node.items.length > 3) _negated(node.items[3]),
        ...node.items.skip(4),
      ]);
    case 'start' || 'end' || 'mid' || 'center' || 'xy' || 'offset':
      return SList([
        node.items.first,
        if (node.items.length > 1) node.items[1],
        if (node.items.length > 2) _negated(node.items[2]),
        ...node.items.skip(3),
      ]);
  }
  return SList([
    node.items.first,
    for (final item in node.items.skip(1)) flipFootprintGeometry(item),
  ]);
}

SExpr _negated(SExpr item) {
  if (item is! SAtom) return item;
  final value = double.tryParse(item.value);
  if (value == null) return item;
  final negated = value == 0 ? 0.0 : -value;
  return S.number(negated);
}

/// [angle] brought into 0 up to 360.
double normalisedDegrees(double angle) {
  final a = angle % 360;
  return a < 0 ? a + 360 : a;
}
