import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

void main() {
  const rect = Rect.fromLTWH(10, 10, 40, 20);

  group('rectangle', () {
    test('dragging a corner keeps the opposite one fixed', () {
      final outline = BoardOutline.rectangle(rect);
      // Corner 1 is the top right, so the bottom left must not move.
      final resized = outline.withHandleAt(1, const Offset(70, 5));

      expect(resized.bounds.bottomLeft, rect.bottomLeft);
      expect(resized.bounds.right, 70);
      expect(resized.bounds.top, 5);
    });

    test('a board cannot be dragged down to nothing', () {
      final outline = BoardOutline.rectangle(rect);
      final collapsed = outline.withHandleAt(0, rect.bottomRight, minimum: 2);

      expect(collapsed.bounds.width, greaterThanOrEqualTo(2));
      expect(collapsed.bounds.height, greaterThanOrEqualTo(2));
    });

    test('four corners, four handles', () {
      expect(BoardOutline.rectangle(rect).handles, hasLength(4));
    });
  });

  group('circle', () {
    test('the centre handle moves it and the edge handle resizes it', () {
      final outline = BoardOutline.circle(const Rect.fromLTWH(0, 0, 20, 20));
      expect(outline.radius, 10);
      expect(outline.center, const Offset(10, 10));

      final moved = outline.withHandleAt(0, const Offset(50, 50));
      expect(moved.center, const Offset(50, 50));
      expect(moved.radius, 10);

      final grown = outline.withHandleAt(1, const Offset(30, 10));
      expect(grown.center, const Offset(10, 10));
      expect(grown.radius, 20);
    });

    test('it knows what is on the board', () {
      final outline = BoardOutline.circle(const Rect.fromLTWH(0, 0, 20, 20));
      expect(outline.contains(const Offset(10, 10)), isTrue);
      expect(outline.contains(const Offset(14, 14)), isTrue);
      // Inside the bounding box, outside the circle.
      expect(outline.contains(const Offset(1, 1)), isFalse);
    });
  });

  group('polygon', () {
    final triangle = BoardOutline.polygon(const [
      Offset(0, 0),
      Offset(20, 0),
      Offset(10, 20),
    ]);

    test('a vertex moves on its own', () {
      final moved = triangle.withHandleAt(2, const Offset(10, 40));
      expect(moved.points[0], const Offset(0, 0));
      expect(moved.points[1], const Offset(20, 0));
      expect(moved.points[2], const Offset(10, 40));
    });

    test('a corner can be added halfway along an edge', () {
      final grown = triangle.withPointAfter(0);
      expect(grown.points, hasLength(4));
      expect(grown.points[1], const Offset(10, 0));
    });

    test('a triangle cannot lose a corner', () {
      expect(triangle.withoutPoint(0).points, hasLength(3));

      final quad = triangle.withPointAfter(0);
      expect(quad.withoutPoint(1).points, hasLength(3));
    });

    test('containment follows the shape, not the box', () {
      // Just inside the bounding box's top-left, outside the triangle.
      expect(triangle.contains(const Offset(1, 18)), isFalse);
      expect(triangle.contains(const Offset(10, 5)), isTrue);
    });

    test('a concave shape is handled too', () {
      // An L, which is what cutting a corner off a board produces.
      final ell = BoardOutline.polygon(const [
        Offset(0, 0),
        Offset(30, 0),
        Offset(30, 10),
        Offset(10, 10),
        Offset(10, 30),
        Offset(0, 30),
      ]);
      expect(ell.contains(const Offset(5, 25)), isTrue);
      expect(ell.contains(const Offset(25, 5)), isTrue);
      // The bite taken out of the corner.
      expect(ell.contains(const Offset(25, 25)), isFalse);
    });
  });

  group('changing kind', () {
    test('a rectangle becomes a circle of the same extent', () {
      final circle = BoardOutline.rectangle(rect).as(BoardOutlineKind.circle);
      expect(circle.kind, BoardOutlineKind.circle);
      expect(circle.center, rect.center);
    });

    test('a rectangle becomes a four-cornered polygon', () {
      final polygon = BoardOutline.rectangle(rect).as(BoardOutlineKind.polygon);
      expect(polygon.kind, BoardOutlineKind.polygon);
      expect(polygon.points, hasLength(4));
      expect(polygon.bounds, rect);
    });

    test('a circle becomes a polygon anyone could actually drag', () {
      // Sixty-four handles is not an editable shape.
      final polygon = BoardOutline.circle(rect).as(BoardOutlineKind.polygon);
      expect(polygon.points.length, lessThanOrEqualTo(8));
      expect(polygon.points.length, greaterThanOrEqualTo(3));
    });

    test('converting to the same kind changes nothing', () {
      final outline = BoardOutline.rectangle(rect);
      expect(outline.as(BoardOutlineKind.rectangle), outline);
    });
  });
}
