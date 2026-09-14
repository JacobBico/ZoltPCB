import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/features/board/crosshair.dart';

void main() {
  const board = Rect.fromLTWH(10, 20, 40, 30); // centre (30, 35)

  test('near the middle of the board, it lands on the middle', () {
    final snap = boardGuideSnap(
      at: const Offset(30.4, 34.7),
      board: board,
      toleranceMm: 1,
    )!;
    expect(snap.at, const Offset(30, 35));
    expect(snap.label, 'board centre');
  });

  test('by the part\'s middle, not its origin', () {
    // The part's centre sits 2 mm right of its origin.
    final snap = boardGuideSnap(
      at: const Offset(28.3, 35.2),
      board: board,
      toleranceMm: 1,
      reference: const Offset(2, 0),
    )!;
    expect(snap.at, const Offset(28, 35));
  });

  test('each axis lines up on its own, the other stays on the grid', () {
    // x close to the left edge, y nowhere in particular.
    final snap = boardGuideSnap(
      at: const Offset(10.3, 27.3),
      board: board,
      toleranceMm: 1,
      gridMm: 0.5,
    )!;
    expect(snap.at, const Offset(10, 27.5));
    expect(snap.label, 'left edge');
  });

  test('both centre lines at once is the centre', () {
    final snap = boardGuideSnap(
      at: const Offset(30.9, 35.9),
      board: board,
      toleranceMm: 1,
    )!;
    expect(snap.at, const Offset(30, 35));
  });

  test('away from every guide, nothing', () {
    expect(
      boardGuideSnap(at: const Offset(20, 27), board: board, toleranceMm: 1),
      isNull,
    );
  });
}
