import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/fab/gerber_reader.dart';
import 'package:hintpcb/fab/gerber_writer.dart';

BoardScene _scene({
  double width = 20,
  double height = 10,
  BoardOutlineKind kind = BoardOutlineKind.rectangle,
  List<Via> vias = const [],
  List<BoardZone> zones = const [],
}) => BoardScene(
  board: Board(
    id: 'b',
    projectId: 'p',
    outlineX: 0,
    outlineY: 0,
    outlineWidth: width,
    outlineHeight: height,
    outlineKind: kind,
    rules: const DesignRules(),
    gridMm: 0.5,
    modifiedAt: DateTime(2026),
  ),
  footprints: const [],
  pads: const [],
  tracks: const [],
  vias: vias,
  ratsnest: const [],
  unplaced: const [],
  zones: zones,
);

/// Every end of every milled run meets the end of another, or its own
/// start: the milled edge is closed all round.
void _expectClosed(List<List<Offset>> runs) {
  final ends = [
    for (final run in runs)
      if ((run.first - run.last).distance > 1e-6) ...[run.first, run.last],
  ];
  for (final end in ends) {
    final meeting = ends.where((e) => (e - end).distance < 1e-6).length;
    expect(meeting, greaterThanOrEqualTo(2), reason: 'loose end at $end');
  }
}

void main() {
  test('a 2 × 2 panel with rails: size, copies, tabs and perforation', () {
    final layout = PanelLayout.of(_scene(), const PanelSettings());
    // 2 × 20 + 2 mm gap wide; 2 × 10 + 2 plus a 5 mm rail and a 2 mm gap
    // at top and bottom high.
    expect(layout.panel.size, const Size(42, 36));
    expect(layout.copies, hasLength(4));
    expect(layout.copies.first, const Offset(0, 7));
    // Two between columns, two between rows, two to each rail.
    expect(layout.tabs, hasLength(8));
    // Six holes where each tab meets a board: both ends between boards,
    // the board end only at a rail.
    expect(layout.biteHoles, hasLength(4 * 12 + 4 * 6));
    for (final hole in layout.biteHoles) {
      // Set in from the edge: inside some copy.
      expect(
        layout.boardBounds.any((b) => b.contains(hole)),
        isTrue,
        reason: '$hole',
      );
    }
    expect(layout.fiducials, hasLength(3));
    expect(layout.toolingHoles, hasLength(4));
    expect(layout.vScores, isEmpty);
    expect(layout.warnings, isEmpty);
    _expectClosed(layout.edgeCuts);
    // Nothing is milled across a tab.
    for (final run in layout.edgeCuts) {
      for (var i = 0; i + 1 < run.length; i++) {
        final mid = (run[i] + run[i + 1]) / 2;
        for (final tab in layout.tabs) {
          expect(tab.deflate(1e-6).contains(mid), isFalse);
        }
      }
    }
  });

  test('V-score butts the copies together and grooves every seam', () {
    final layout = PanelLayout.of(
      _scene(),
      const PanelSettings(rows: 3, columns: 1, join: PanelJoin.vScore),
    );
    expect(layout.panel.size, const Size(20, 40));
    expect(layout.tabs, isEmpty);
    expect(layout.biteHoles, isEmpty);
    // Rail to board, board to board twice, board to rail: all across.
    expect([for (final (a, _) in layout.vScores) a.dy], [5, 15, 25, 35]);
    for (final (a, b) in layout.vScores) {
      expect(a.dx, 0);
      expect(b.dx, 20);
    }
    expect(layout.edgeCuts, hasLength(1));
  });

  test('a round board cannot be V-scored, and its tabs meet the curve', () {
    final layout = PanelLayout.of(
      _scene(width: 20, height: 20, kind: BoardOutlineKind.circle),
      const PanelSettings(join: PanelJoin.vScore, rails: PanelRails.frame),
    );
    expect(layout.join, PanelJoin.mouseBites);
    expect(layout.warnings.single, contains('V-score'));
    expect(layout.tabs, isNotEmpty);
    _expectClosed(layout.edgeCuts);
    // Every perforation hole is inside its circle, a quarter mm in.
    for (final hole in layout.biteHoles) {
      final box = layout.boardBounds.firstWhere(
        (b) => b.inflate(1).contains(hole),
      );
      expect((hole - box.center).distance, lessThan(10));
      expect((hole - box.center).distance, greaterThan(9.5));
    }
  });

  test('the panel files carry every copy, and what the panel adds', () {
    final scene = _scene(
      vias: const [
        Via(id: 'v', projectId: 'p', x: 10, y: 5, diameter: 0.6, drill: 0.3),
      ],
    );
    final layout = PanelLayout.of(scene, const PanelSettings());
    final files = {
      for (final f in FabricationWriter.writePanel(
        scene,
        layout,
        baseName: 'p',
        title: 'Demo',
      ))
        f.name: f.content,
    };
    expect(files.keys, containsAll(['p-F_Cu.gbr', 'p-panel.txt']));
    expect(files.keys, isNot(contains('p-V_Score.gbr')));

    final copper = GerberReader.parse(files['p-F_Cu.gbr']!);
    final flashes = copper.shapes.whereType<GerberFlash>().toList();
    // Four vias, one per copy, and three fiducials.
    expect(flashes, hasLength(7));
    expect(
      flashes.map((f) => f.at),
      containsAll([
        for (final copy in layout.copies) const Offset(10, 5) + copy,
      ]),
    );

    final plated = GerberReader.parseDrill(files['p-PTH.drl']!);
    expect(plated, hasLength(4));
    final unplated = GerberReader.parseDrill(files['p-NPTH.drl']!);
    expect(unplated, hasLength(4 + layout.biteHoles.length));

    final mask = GerberReader.parse(files['p-F_Mask.gbr']!);
    expect(mask.shapes.whereType<GerberFlash>(), hasLength(3));

    // The name on the top rail.
    expect(GerberReader.parse(files['p-F_Silkscreen.gbr']!).shapes, isNotEmpty);
    expect(files['p-panel.txt'], contains('42.00 x 36.00 mm'));
  });

  test('a V-scored panel ships its score lines in their own file', () {
    final scene = _scene();
    final layout = PanelLayout.of(
      scene,
      const PanelSettings(join: PanelJoin.vScore),
    );
    final files = {
      for (final f in FabricationWriter.writePanel(
        scene,
        layout,
        baseName: 'p',
      ))
        f.name: f.content,
    };
    final scores = GerberReader.parse(files['p-V_Score.gbr']!);
    expect(scores.shapes, hasLength(layout.vScores.length));
    expect(files['p-panel.txt'], contains('V-score lines'));
  });

  test('a pour stays in its own copy, so the next copy keeps its copper', () {
    final scene = _scene(
      zones: [
        BoardZone(
          id: 'z',
          projectId: 'p',
          netId: null,
          layer: BoardLayer.frontCopper,
          points: const [
            Offset(-5, -5),
            Offset(25, -5),
            Offset(25, 15),
            Offset(-5, 15),
          ],
        ),
      ],
    );
    final plan = PourFill.plan(scene, CopperLayer.front);
    for (final step in plan.steps) {
      final shape = step.shape;
      if (shape is PourRegion && !step.clear) {
        for (final p in shape.points) {
          expect(scene.outline.bounds.inflate(1e-6).contains(p), isTrue);
        }
      }
      if (shape is PourRegion && step.clear && shape.hole != null) {
        // The off-board clear hugs the board: less than the edge margin.
        for (final p in shape.points) {
          expect(
            scene.outline.bounds.inflate(PourFill.minEdgeClearance).contains(p),
            isTrue,
          );
        }
      }
    }
  });

  test('settings survive a round trip, and junk reads as the defaults', () {
    const settings = PanelSettings(
      rows: 3,
      columns: 4,
      join: PanelJoin.vScore,
      rails: PanelRails.frame,
      tabsPerEdge: 2,
      fiducials: false,
    );
    final back = PanelSettings.decode(settings.encode());
    expect(back.rows, 3);
    expect(back.columns, 4);
    expect(back.join, PanelJoin.vScore);
    expect(back.rails, PanelRails.frame);
    expect(back.tabsPerEdge, 2);
    expect(back.fiducials, isFalse);
    expect(PanelSettings.decode('{not json').rows, 2);
    expect(PanelSettings.decode(null).join, PanelJoin.mouseBites);
  });
}
