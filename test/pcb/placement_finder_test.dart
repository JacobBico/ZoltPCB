import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

void main() {
  final board = BoardOutline.rectangle(const Rect.fromLTWH(0, 0, 40, 30));
  // A footprint about the size of an 0805: 3.4 x 1.9 mm around its origin.
  const part = Rect.fromLTRB(-1.7, -0.95, 1.7, 0.95);

  test('the first part goes in the middle', () {
    final spot = PlacementFinder.findSpot(outline: board, footprint: part);
    expect(spot, isNotNull);
    expect((spot! - board.bounds.center).distance, lessThan(1.0));
  });

  test('the second part does not land on the first', () {
    // Reported: placing two parts put them exactly on top of each other.
    final first = PlacementFinder.findSpot(outline: board, footprint: part)!;
    final second = PlacementFinder.findSpot(
      outline: board,
      footprint: part,
      occupied: [part.shift(first)],
    )!;

    expect(part.shift(second).overlaps(part.shift(first)), isFalse);
    // Nearby, not flung to a corner.
    expect((second - first).distance, lessThan(10));
  });

  test('ten parts all find their own place', () {
    final placed = <Rect>[];
    for (var i = 0; i < 10; i++) {
      final spot = PlacementFinder.findSpot(
        outline: board,
        footprint: part,
        occupied: placed,
      );
      expect(spot, isNotNull, reason: 'part $i found no room');
      final rect = part.shift(spot!);
      for (final other in placed) {
        expect(rect.overlaps(other), isFalse, reason: 'part $i overlaps');
      }
      placed.add(rect);
    }
  });

  test('a part always lands inside the board edge', () {
    final spot = PlacementFinder.findSpot(outline: board, footprint: part)!;
    final rect = part.shift(spot);
    expect(board.bounds.contains(rect.topLeft), isTrue);
    expect(board.bounds.contains(rect.bottomRight), isTrue);
  });

  test('a round board is respected, corners and all', () {
    final round = BoardOutline.circle(const Rect.fromLTWH(0, 0, 20, 20));
    // Fill it until it refuses: every placement has to be inside the circle,
    // not merely inside its bounding square.
    final placed = <Rect>[];
    for (var i = 0; i < 30; i++) {
      final spot = PlacementFinder.findSpot(
        outline: round,
        footprint: part,
        occupied: placed,
      );
      if (spot == null) break;
      final rect = part.shift(spot);
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        expect(round.contains(corner), isTrue, reason: 'corner $corner');
      }
      placed.add(rect);
    }
    expect(placed, isNotEmpty);
  });

  test('a full board says so rather than stacking', () {
    final tiny = BoardOutline.rectangle(const Rect.fromLTWH(0, 0, 5, 5));
    final first = PlacementFinder.findSpot(outline: tiny, footprint: part);
    expect(first, isNotNull);

    final second = PlacementFinder.findSpot(
      outline: tiny,
      footprint: part,
      occupied: [part.shift(first!)],
    );
    expect(second, isNull);
  });

  test('when the board is full, parts wait beside it, not on each other', () {
    final a = PlacementFinder.besideBoard(outline: board, footprint: part);
    final b = PlacementFinder.besideBoard(
      outline: board,
      footprint: part,
      occupied: [part.shift(a)],
    );

    expect(part.shift(a).left, greaterThan(board.bounds.right));
    expect(part.shift(a).overlaps(part.shift(b)), isFalse);
  });
}
