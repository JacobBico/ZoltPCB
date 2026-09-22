import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

BoardScene _scene({
  List<Track> tracks = const [],
  List<Via> vias = const [],
  List<BoardText> texts = const [],
  Rect outline = const Rect.fromLTWH(0, 0, 40, 30),
  DesignRules rules = const DesignRules(),
}) => BoardScene(
  board: Board(
    id: 'b',
    projectId: 'p',
    outlineX: outline.left,
    outlineY: outline.top,
    outlineWidth: outline.width,
    outlineHeight: outline.height,
    rules: rules,
    gridMm: 0.5,
    modifiedAt: DateTime(2026),
  ),
  footprints: const [],
  pads: const [],
  tracks: tracks,
  vias: vias,
  ratsnest: const [],
  unplaced: const [],
  texts: texts,
);

Track _track(double y, {double width = 0.2, double x1 = 10, double x2 = 30}) =>
    Track(
      id: 't$y',
      projectId: 'p',
      netId: 'n',
      layer: CopperLayer.front,
      startX: x1,
      startY: y,
      endX: x2,
      endY: y,
      width: width,
    );

Via _via(double x, double y, {double diameter = 0.6, double drill = 0.3}) =>
    Via(
      id: 'v$x,$y',
      projectId: 'p',
      netId: 'n',
      x: x,
      y: y,
      diameter: diameter,
      drill: drill,
    );

Set<DrcRule> _rules(BoardScene scene, FabPreset preset) => {
  for (final v in fabViolations(scene, preset)) v.rule,
};

void main() {
  const jlc = FabPresets.jlcpcb2;

  test('each preset draws comfortably inside its own limits', () {
    for (final preset in FabPresets.all) {
      expect(preset.rules.trackWidth, greaterThan(preset.minTrack));
      expect(preset.rules.clearance, greaterThan(preset.minClearance));
      expect(preset.rules.viaDrill, greaterThan(preset.minViaDrill));
      expect(
        (preset.rules.viaDiameter - preset.rules.viaDrill) / 2,
        greaterThanOrEqualTo(preset.minViaRing - 1e-9),
        reason: preset.name,
      );
      expect(preset.rules.problem, isNull, reason: preset.name);
      expect(FabPresets.byId(preset.id), same(preset));
    }
  });

  test('a board drawn to the preset\'s rules passes', () {
    final scene = _scene(
      rules: jlc.rules,
      tracks: [_track(15)],
      vias: [_via(20, 20)],
    );
    expect(fabViolations(scene, jlc), isEmpty);
  });

  test('copper and holes below the house\'s limits are flagged', () {
    final scene = _scene(
      rules: const DesignRules(clearance: 0.05),
      tracks: [_track(15, width: 0.08)],
      // A 0.1 mm hole with 0.04 mm of copper round it.
      vias: [_via(20, 20, diameter: 0.18, drill: 0.1)],
    );
    expect(
      _rules(scene, jlc),
      containsAll([DrcRule.fabLimit, DrcRule.drillSize, DrcRule.annularRing]),
    );
  });

  test('holes too close together, hole to hole', () {
    final scene = _scene(vias: [_via(10, 10), _via(10.4, 10)]);
    final spacing = fabViolations(
      scene,
      jlc,
    ).where((v) => v.rule == DrcRule.holeSpacing);
    expect(spacing, hasLength(1));
    expect(spacing.single.message, contains('0.10 mm apart'));
  });

  test('copper at the milled edge', () {
    final scene = _scene(tracks: [_track(0.15, x1: 5, x2: 20)]);
    expect(_rules(scene, jlc), contains(DrcRule.edgeClearance));
    expect(
      _rules(_scene(tracks: [_track(1)]), jlc),
      isNot(contains(DrcRule.edgeClearance)),
    );
  });

  test('silkscreen too small to print is a warning', () {
    final scene = _scene(
      texts: const [
        BoardText(
          id: 'x',
          projectId: 'p',
          content: 'REV A',
          position: Offset(20, 15),
          size: 0.6,
        ),
      ],
    );
    final silk = fabViolations(
      scene,
      jlc,
    ).where((v) => v.rule == DrcRule.silkscreen).single;
    expect(silk.isError, isFalse);
    // PCBWay prints smaller, so the same text is fine at 0.8 but not 0.6.
    expect(
      fabViolations(scene, FabPresets.pcbway).map((v) => v.rule),
      contains(DrcRule.silkscreen),
    );
  });

  test('a board too big for the house', () {
    final scene = _scene(outline: const Rect.fromLTWH(0, 0, 1100, 700));
    expect(_rules(scene, jlc), contains(DrcRule.boardSize));
  });

  test('the design rule check runs them when a house is chosen', () {
    final scene = _scene(tracks: [_track(15, width: 0.08)]);
    expect(
      checkBoard(scene).map((v) => v.rule),
      isNot(contains(DrcRule.fabLimit)),
    );
    expect(
      checkBoard(scene, fab: jlc).map((v) => v.rule),
      contains(DrcRule.fabLimit),
    );
  });
}
