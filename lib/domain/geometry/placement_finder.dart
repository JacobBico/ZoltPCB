import 'dart:math' as math;
import 'dart:ui';

import '../pcb/board_outline.dart';

/// Finds somewhere free to put a new part.
///
/// Shared by the schematic and the board, which had the same bug in two
/// forms: the board dropped every part on its centre, stacked, and the
/// schematic dealt them into a grid that put the second one off the edge of
/// the screen. Both want the same answer — the nearest free spot to where
/// the user is looking.
abstract final class PlacementFinder {
  /// [findSpot] for a plain rectangular region, such as the part of the
  /// schematic sheet currently on screen.
  static Offset? findSpotIn({
    required Rect region,
    required Rect footprint,
    Offset? near,
    List<Rect> occupied = const [],
    double gridMm = 0.5,
    double margin = 1.0,
  }) => findSpot(
    outline: BoardOutline.rectangle(region),
    footprint: footprint,
    near: near,
    occupied: occupied,
    gridMm: gridMm,
    margin: margin,
  );

  /// The origin for a footprint whose own extent is [footprint] (in its own
  /// space, so the origin sits at [Offset.zero]), or null if the board has
  /// no room left.
  ///
  /// [occupied] are the extents of what is already placed. [margin] keeps a
  /// little air between parts, because two courtyards that touch are a DRC
  /// warning waiting to happen and a finger cannot pick either of them out.
  static Offset? findSpot({
    required BoardOutline outline,
    required Rect footprint,
    Offset? near,
    List<Rect> occupied = const [],
    double gridMm = 0.5,
    double margin = 1.0,
  }) {
    final bounds = outline.bounds;
    if (bounds.isEmpty || footprint.isEmpty && footprint != Rect.zero) {
      return null;
    }

    // Candidates on a coarser grid than the board's own: a 0.1 mm grid over
    // a 100 mm board is a million places to try, and nobody needs a part
    // dropped with that precision — they will drag it where they want it.
    final step = math.max(gridMm, 1.0);
    // Where to search out from: somewhere the user chose if they did, the
    // middle of the region if not.
    final centre = near ?? bounds.center;

    final candidates = <Offset>[];
    for (var x = bounds.left; x <= bounds.right; x += step) {
      for (var y = bounds.top; y <= bounds.bottom; y += step) {
        candidates.add(_snap(Offset(x, y), gridMm));
      }
    }
    // Nearest the centre first, so the board fills from the middle out the
    // way a person would lay it out.
    candidates.sort(
      (a, b) =>
          (a - centre).distanceSquared.compareTo((b - centre).distanceSquared),
    );

    final blocked = [for (final rect in occupied) rect.inflate(margin)];

    for (final origin in candidates) {
      final placed = footprint.shift(origin);
      if (!_fitsInside(outline, placed)) continue;
      if (blocked.any(placed.overlaps)) continue;
      return origin;
    }
    return null;
  }

  /// Somewhere to put a part when the board is full: just beyond its right
  /// edge, where it is at least visible and can be dragged in, rather than
  /// piled on top of something already placed.
  static Offset besideBoard({
    required BoardOutline outline,
    required Rect footprint,
    List<Rect> occupied = const [],
    double margin = 2.0,
  }) {
    final bounds = outline.bounds;
    var x = bounds.right + margin - footprint.left;
    var y = bounds.top - footprint.top;

    // Stack downwards past anything else already parked out here.
    for (final rect in occupied) {
      final placed = footprint.shift(Offset(x, y));
      if (placed.overlaps(rect.inflate(margin))) {
        y = rect.bottom + margin - footprint.top;
      }
    }
    return Offset(x, y);
  }

  static bool _fitsInside(BoardOutline outline, Rect rect) =>
      outline.contains(rect.topLeft) &&
      outline.contains(rect.topRight) &&
      outline.contains(rect.bottomLeft) &&
      outline.contains(rect.bottomRight) &&
      outline.contains(rect.center);

  static Offset _snap(Offset point, double grid) {
    if (grid <= 0) return point;
    return Offset(
      (point.dx / grid).round() * grid,
      (point.dy / grid).round() * grid,
    );
  }
}
