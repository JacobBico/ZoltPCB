import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/fab/gerber_writer.dart';
import 'package:zolt/fab/silk_fonts.dart';
import 'package:zolt/features/board/crosshair.dart';

BoardImage _image(
  List<String> rows, {
  Offset at = const Offset(10, 10),
  double width = 8,
  double rotation = 0,
  bool back = false,
}) => BoardImage(
  id: 'i',
  projectId: 'p',
  name: 'Test',
  position: at,
  width: width,
  rotation: rotation,
  back: back,
  columns: rows.first.length,
  rows: rows.length,
  bits: BoardImage.pack([
    for (final row in rows)
      for (final c in row.split('')) c == '#',
  ]),
);

Board _board({BoardOutlineKind kind = BoardOutlineKind.rectangle}) => Board(
  id: 'b',
  projectId: 'p',
  outlineX: 0,
  outlineY: 0,
  outlineWidth: 40,
  outlineHeight: 30,
  outlineKind: kind,
  rules: const DesignRules(),
  gridMm: 0.5,
  modifiedAt: DateTime(2026),
);

BoardScene _scene({
  List<BoardImage> images = const [],
  List<BoardText> texts = const [],
  List<BoardEdge> edges = const [],
}) => BoardScene(
  board: _board(),
  footprints: const [],
  pads: const [],
  tracks: const [],
  vias: const [],
  ratsnest: const [],
  unplaced: const [],
  images: images,
  texts: texts,
  edges: edges,
);

void main() {
  group('a silkscreen picture', () {
    test('its ink is as few blocks as the runs allow', () {
      final image = _image(['####....', '####....', '....####', '....####']);
      expect(
        image.inkRects,
        unorderedEquals([
          const Rect.fromLTRB(0, 0, 4, 2),
          const Rect.fromLTRB(4, 2, 8, 4),
        ]),
      );
    });

    test('is placed by its centre, and as tall as its pixels say', () {
      final image = _image(['##', '##', '##', '##'], width: 2);
      expect(image.height, 4);
      final corners = image.frame;
      expect(corners.first, const Offset(9, 8));
      expect(corners[2], const Offset(11, 12));
      expect(image.contains(const Offset(10, 10)), isTrue);
      expect(image.contains(const Offset(12, 10)), isFalse);
    });

    test('is turned with its rotation, and mirrored on the back', () {
      // One inked pixel at the left end of a strip.
      final front = _image(['#...'], width: 4);
      final block = front.inkPolygons.single;
      expect(block.map((p) => p.dx).reduce((a, b) => a < b ? a : b), 8);

      final back = _image(['#...'], width: 4, back: true);
      // Read through the board, the left end is on the right.
      expect(
        back.inkPolygons.single
            .map((p) => p.dx)
            .reduce((a, b) => a > b ? a : b),
        12,
      );

      // A quarter turn counter-clockwise puts the left end at the bottom.
      final turned = _image(['#...'], width: 4, rotation: 90);
      expect(
        turned.inkPolygons.single
            .map((p) => p.dy)
            .reduce((a, b) => a > b ? a : b),
        closeTo(12, 1e-9),
      );
    });

    test('goes into the silkscreen Gerber of its side only', () {
      final files = {
        for (final f in FabricationWriter.write(
          _scene(
            images: [
              _image(['##', '##'], width: 2, back: true),
            ],
          ),
          baseName: 'b',
        ))
          f.name: f.content,
      };
      expect(files['b-B_Silkscreen.gbr'], contains('G36*'));
      expect(files['b-F_Silkscreen.gbr'], isNot(contains('G36*')));
    });
  });

  test('text in a font is filled letters in the Gerber, holes and all', () {
    SilkFonts.register(
      'fira-sans',
      File('assets/fonts/FiraSans-Bold.ttf').readAsBytesSync(),
    );
    final gerber = FabricationWriter.write(
      _scene(
        texts: const [
          BoardText(
            id: 't',
            projectId: 'p',
            content: 'OB',
            position: Offset(20, 15),
            size: 2,
            font: 'fira-sans',
          ),
        ],
      ),
      baseName: 'b',
    ).firstWhere((f) => f.name == 'b-F_Silkscreen.gbr').content;
    // One region per letter, each carrying its counters by a cut-in.
    expect(RegExp('G36\\*').allMatches(gerber).length, 2);
  });

  group('soft snaps', () {
    SnapTarget snap(BoardScene scene, Offset at, {CopperLayer? layer}) =>
        resolveSnap(
          at: at,
          scene: scene,
          gridMm: 0.5,
          snapToGrid: true,
          toleranceMm: 1,
          layer: layer,
        );

    test('catch the corners, middles and centre of the outline', () {
      final scene = _scene();
      expect(snap(scene, const Offset(0.4, 0.3)).at, Offset.zero);
      expect(snap(scene, const Offset(20.3, 0.2)).at, const Offset(20, 0));
      expect(snap(scene, const Offset(20.4, 15.3)).at, const Offset(20, 15));
      expect(snap(scene, const Offset(20.4, 15.3)).label, 'board centre');
    });

    test('catch a cutout\'s centre and the edge of a round one', () {
      final scene = _scene(
        edges: const [
          BoardEdge(
            id: 'e',
            projectId: 'p',
            kind: BoardEdgeKind.circle,
            points: [Offset(10, 10), Offset(13, 10)],
          ),
        ],
      );
      expect(snap(scene, const Offset(10.3, 9.8)).at, const Offset(10, 10));
      expect(snap(scene, const Offset(10.2, 13.3)).at, const Offset(10, 13));
    });

    test('leave routing alone', () {
      final scene = _scene();
      // On the grid instead, a quarter of a millimetre off the corner.
      expect(
        snap(scene, const Offset(0.3, 0.3), layer: CopperLayer.front).at,
        const Offset(0.5, 0.5),
      );
    });
  });
}
