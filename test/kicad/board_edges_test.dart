import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/export/board_document.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/kicad/board_writer.dart';

BoardEdge _edge(
  BoardEdgeKind kind,
  List<Offset> points, {
  double width = 0.1,
}) => BoardEdge(
  id: 'e-${kind.name}',
  projectId: 'p',
  kind: kind,
  points: points,
  width: width,
);

Board _board() => Board(
  id: 'b',
  projectId: 'p',
  outlineX: 0,
  outlineY: 0,
  outlineWidth: 40,
  outlineHeight: 30,
  rules: DesignRules.conservative,
  gridMm: 0.5,
  modifiedAt: DateTime(2026, 1, 1),
);

String _write({
  List<BoardEdge> edges = const [],
  List<BoardZone> zones = const [],
  List<BoardText> texts = const [],
}) {
  final scene = BoardScene(
    board: _board(),
    footprints: const [],
    pads: const [],
    tracks: const [],
    vias: const [],
    ratsnest: const [],
    unplaced: const [],
    edges: edges,
    zones: zones,
    texts: texts,
  );
  return const BoardWriter().write(
    BoardDocument(
      project: Project(
        id: 'p',
        name: 'Edges',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 1),
      ),
      scene: scene,
      nets: const [],
    ),
  );
}

void main() {
  group('edge cuts reach the file as the shape they are', () {
    test('a line is a gr_line between its two points', () {
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.line, const [Offset(5, 6), Offset(11, 6)]),
        ],
      );
      // Four for the board outline, one for the cut.
      expect(RegExp(r'\(gr_line\b').allMatches(text).length, 5);
      expect(text, contains('(start 5 6)'));
      expect(text, contains('(end 11 6)'));
    });

    test('an arc keeps its middle point', () {
      // The one shape that cannot survive being flattened: a router bit
      // follows an arc, and three points is exactly how KiCad states one.
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.arc, const [
            Offset(10, 20),
            Offset(11.5, 21.5),
            Offset(13, 20),
          ]),
        ],
      );
      expect(RegExp(r'\(gr_arc\b').allMatches(text).length, 1);
      expect(text, contains('(start 10 20)'));
      expect(text, contains('(mid 11.5 21.5)'));
      expect(text, contains('(end 13 20)'));
    });

    test('a circle is a gr_circle stated by a point on its edge', () {
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.circle, const [Offset(20, 15), Offset(23, 15)]),
        ],
      );
      expect(text, contains('(center 20 15)'));
      expect(text, contains('(end 23 15)'));
    });

    test('a rectangle is a gr_rect on its two corners', () {
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.rectangle, const [Offset(4, 4), Offset(9, 7)]),
        ],
      );
      expect(RegExp(r'\(gr_rect\b').allMatches(text).length, 1);
      expect(text, contains('(start 4 4)'));
      expect(text, contains('(end 9 7)'));
    });

    test('a polygon closes, so its last point joins its first', () {
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.polygon, const [
            Offset(1, 1),
            Offset(6, 1),
            Offset(6, 5),
          ]),
        ],
      );
      // Four outline lines plus three sides.
      expect(RegExp(r'\(gr_line\b').allMatches(text).length, 7);
      expect(text, contains('(start 6 5)'));
    });

    test('an incomplete shape is left out rather than half-written', () {
      final text = _write(
        edges: [
          _edge(BoardEdgeKind.line, const [Offset(1, 1)]),
          _edge(BoardEdgeKind.arc, const [Offset(1, 1), Offset(2, 2)]),
        ],
      );
      expect(RegExp(r'\(gr_line\b').allMatches(text).length, 4);
      expect(text, isNot(contains('(gr_arc')));
    });
  });

  group('copper pours', () {
    test('a zone carries its net, layer and outline', () {
      final text = _write(
        zones: [
          const BoardZone(
            id: 'z1',
            projectId: 'p',
            layer: BoardLayer.backCopper,
            netName: 'GND',
            points: [
              Offset(1, 1),
              Offset(20, 1),
              Offset(20, 14),
              Offset(1, 14),
            ],
          ),
        ],
      );
      expect(text, contains('(zone'));
      expect(text, contains('(layer "B.Cu")'));
      expect(text, contains('(xy 20 14)'));
    });

    test('a pour with no net is written as net 0', () {
      final text = _write(
        zones: [
          const BoardZone(
            id: 'z1',
            projectId: 'p',
            layer: BoardLayer.frontCopper,
            points: [Offset(1, 1), Offset(5, 1), Offset(5, 5)],
          ),
        ],
      );
      expect(text, contains('(net 0)'));
      expect(text, contains('(net_name "")'));
    });

    test('a pour needing three points to exist is left out below that', () {
      final text = _write(
        zones: [
          const BoardZone(
            id: 'z1',
            projectId: 'p',
            layer: BoardLayer.frontCopper,
            points: [Offset(1, 1), Offset(5, 1)],
          ),
        ],
      );
      expect(text, isNot(contains('(zone')));
    });
  });

  group('arc geometry', () {
    test('three points on a circle recover their centre', () {
      final centre = BoardEdge.circumcentre(
        const Offset(0, -5),
        const Offset(5, 0),
        const Offset(0, 5),
      );
      expect(centre!.dx, closeTo(0, 1e-9));
      expect(centre.dy, closeTo(0, 1e-9));
    });

    test('three points in a line have no circle', () {
      expect(
        BoardEdge.circumcentre(
          const Offset(0, 0),
          const Offset(1, 1),
          const Offset(2, 2),
        ),
        isNull,
      );
    });

    test('the drawn arc passes through the middle point', () {
      // The trap is sweeping the short way round every time, which turns a
      // three-quarter arc inside out and draws the piece the user removed.
      final edge = _edge(BoardEdgeKind.arc, const [
        Offset(5, 0),
        Offset(-5, 0),
        Offset(0, -5),
      ]);
      final bounds = edge.arcPath.getBounds();
      // Going the long way keeps y = +5 on the path; the short way would
      // never leave the top half.
      expect(bounds.bottom, closeTo(5, 0.1));
    });

    test('a collinear arc degenerates to the chord it is', () {
      final edge = _edge(BoardEdgeKind.arc, const [
        Offset(0, 0),
        Offset(5, 0),
        Offset(10, 0),
      ]);
      final bounds = edge.arcPath.getBounds();
      expect(bounds.width, closeTo(10, 1e-6));
      expect(bounds.height, closeTo(0, 1e-6));
    });

    test('a circle knows its own radius', () {
      final edge = _edge(BoardEdgeKind.circle, const [
        Offset(10, 10),
        Offset(13, 14),
      ]);
      expect(edge.radius, closeTo(5, 1e-9));
      expect(edge.bounds.width, closeTo(10, 1e-9));
    });

    test('a tap lands on the shape it looks like it lands on', () {
      final line = _edge(BoardEdgeKind.line, const [
        Offset(0, 0),
        Offset(10, 0),
      ]);
      expect(line.distanceTo(const Offset(5, 2)), closeTo(2, 1e-9));

      final circle = _edge(BoardEdgeKind.circle, const [
        Offset(0, 0),
        Offset(5, 0),
      ]);
      // On the rim, not in the middle: a circle is a cut line, and its
      // centre is as far from it as anywhere else.
      expect(circle.distanceTo(const Offset(5, 0)), closeTo(0, 1e-9));
      expect(circle.distanceTo(Offset.zero), closeTo(5, 1e-9));
      expect(
        circle.distanceTo(Offset(5 * math.cos(0.7), 5 * math.sin(0.7))),
        closeTo(0, 1e-9),
      );
    });
  });

  group('silkscreen text', () {
    test('front text is a gr_text on F.SilkS at its size', () {
      final text = _write(
        texts: const [
          BoardText(
            id: 't1',
            projectId: 'p',
            content: 'HINTPCB',
            position: Offset(12, 8),
            size: 1.5,
          ),
        ],
      );
      expect(text, contains('(gr_text "HINTPCB"'));
      expect(text, contains('(at 12 8 0)'));
      expect(text, contains('(layer "F.SilkS")'));
      expect(text, contains('(size 1.5 1.5)'));
      expect(text, isNot(contains('mirror')));
    });

    test('back text is mirrored, because it is read through the board', () {
      final text = _write(
        texts: const [
          BoardText(
            id: 't1',
            projectId: 'p',
            content: 'REV A',
            position: Offset(12, 8),
            back: true,
          ),
        ],
      );
      expect(text, contains('(layer "B.SilkS")'));
      expect(text, contains('(justify mirror)'));
    });

    test('blank text is left out rather than written empty', () {
      final text = _write(
        texts: const [
          BoardText(
            id: 't1',
            projectId: 'p',
            content: '   ',
            position: Offset(1, 1),
          ),
        ],
      );
      expect(text, isNot(contains('(gr_text')));
    });
  });
}
