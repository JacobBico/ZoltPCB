import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

const _board = Rect.fromLTWH(0, 0, 40, 30);

BoardZone _zone(
  String id, {
  required String net,
  List<Offset> points = const [
    Offset(0, 0),
    Offset(40, 0),
    Offset(40, 30),
    Offset(0, 30),
  ],
  int priority = 0,
  PadConnection connection = PadConnection.thermal,
  PadConnection viaConnection = PadConnection.solid,
}) => BoardZone(
  id: id,
  projectId: 'p',
  layer: BoardLayer.frontCopper,
  points: points,
  netId: net,
  netName: net.toUpperCase(),
  priority: priority,
  padConnection: connection,
  viaConnection: viaConnection,
);

/// A 1 x 1 mm SMD pad at [at] on [net].
PlacedFootprint _pad(Offset at, String? net, {String reference = 'R1'}) {
  const pad = Pad(
    number: '1',
    type: PadType.smd,
    shape: PadShape.rect,
    at: FootprintPoint(0, 0),
    sizeX: 1,
    sizeY: 1,
    layers: [BoardLayer.frontCopper],
  );
  return PlacedFootprint(
    ref: PlacedFootprintRef(
      id: reference,
      projectId: 'p',
      partId: reference,
      libId: 'Test:Pad',
      x: at.dx,
      y: at.dy,
      placed: true,
    ),
    part: Part(
      id: reference,
      projectId: 'p',
      libId: 'Device:R',
      reference: reference,
      value: '10k',
      createdAt: DateTime(2026),
    ),
    placement: FootprintPlacement(x: at.dx, y: at.dy),
    pads: [
      PlacedPad(
        pad: pad,
        partId: reference,
        reference: reference,
        footprintId: reference,
        position: at,
        angle: 0,
        layers: const [BoardLayer.frontCopper],
        netId: net,
        netName: net,
      ),
    ],
  );
}

BoardScene _scene({
  List<BoardZone> zones = const [],
  List<PlacedFootprint> footprints = const [],
  List<Track> tracks = const [],
  List<Via> vias = const [],
}) => BoardScene(
  board: Board(
    id: 'b',
    projectId: 'p',
    outlineX: _board.left,
    outlineY: _board.top,
    outlineWidth: _board.width,
    outlineHeight: _board.height,
    rules: const DesignRules(),
    gridMm: 0.5,
    modifiedAt: DateTime(2026),
  ),
  footprints: footprints,
  pads: [for (final f in footprints) ...f.pads],
  tracks: tracks,
  vias: vias,
  ratsnest: const [],
  unplaced: const [],
  zones: zones,
);

PourPlan _plan(BoardScene scene) => PourFill.plan(scene, CopperLayer.front);

void main() {
  _viaConnectionTests();

  test('no pours, nothing to draw', () {
    expect(_plan(_scene()).isEmpty, isTrue);
  });

  test('a higher-priority pour cuts the other net back before it is laid', () {
    final plan = _plan(
      _scene(
        zones: [
          _zone('gnd', net: 'gnd'),
          _zone(
            'vcc',
            net: 'vcc',
            priority: 1,
            points: const [
              Offset(5, 5),
              Offset(15, 5),
              Offset(15, 15),
              Offset(5, 15),
            ],
          ),
        ],
      ),
    );
    final steps = plan.steps;
    // GND laid, VCC's area and a clearance ring cleared, then VCC laid.
    expect(steps[0].clear, isFalse);
    expect((steps[0].shape as PourRegion).points.first, Offset.zero);
    expect(steps[1].clear, isTrue);
    expect((steps[1].shape as PourRegion).points.first, const Offset(5, 5));
    expect(steps[2].clear, isTrue);
    expect((steps[2].shape as PourStroke).width, closeTo(1.0, 1e-9));
    expect(steps[3].clear, isFalse);
    expect((steps[3].shape as PourRegion).points.first, const Offset(5, 5));
  });

  test('priority, not drawing order, decides which pour wins', () {
    final plan = _plan(
      _scene(
        zones: [
          _zone('high', net: 'vcc', priority: 2),
          _zone('low', net: 'gnd'),
        ],
      ),
    );
    final laid = [
      for (final step in plan.steps)
        if (!step.clear && step.shape is PourRegion) step,
    ];
    // The low one first; the high one last, so it wins.
    expect(laid, hasLength(2));
    expect(plan.steps.first.clear, isFalse);
    expect(
      plan.steps.indexOf(laid.last),
      greaterThan(plan.steps.indexOf(laid.first)),
    );
  });

  test('nothing is left off the board or at its edge', () {
    final plan = _plan(_scene(zones: [_zone('gnd', net: 'gnd')]));
    final offBoard = plan.steps
        .map((s) => s.shape)
        .whereType<PourRegion>()
        .where((r) => r.hole != null)
        .single;
    expect(offBoard.hole, hasLength(4));
    final edge = plan.steps.firstWhere(
      (s) =>
          s.clear &&
          s.shape is PourStroke &&
          (s.shape as PourStroke).closed &&
          (s.shape as PourStroke).points.length == 4,
    );
    expect(
      (edge.shape as PourStroke).width,
      closeTo(PourFill.minEdgeClearance * 2, 1e-9),
    );
  });

  test('a same-net pad gets a thermal gap and four spokes', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd')],
        footprints: [_pad(const Offset(20, 15), 'gnd')],
      ),
    );
    final ring = plan.steps.where((s) => s.clear && s.shape is PourPad);
    expect(ring, hasLength(1));
    expect((ring.single.shape as PourPad).grow, 0.5);
    final spokes = [
      for (final s in plan.steps)
        if (!s.clear && s.shape is PourStroke) s.shape as PourStroke,
    ];
    expect(spokes, hasLength(4));
    for (final spoke in spokes) {
      expect(spoke.points.first, const Offset(20, 15));
      // Half the pad, the gap, and the spoke's own width: into the pour.
      expect((spoke.points.last - spoke.points.first).distance, 1.5);
    }
    expect(plan.warnings, isEmpty);
  });

  test('a solid pour runs straight to the pad; a "none" pour avoids it', () {
    final solid = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd', connection: PadConnection.solid)],
        footprints: [_pad(const Offset(20, 15), 'gnd')],
      ),
    );
    expect(solid.steps.where((s) => s.shape is PourPad), isEmpty);

    final none = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd', connection: PadConnection.none)],
        footprints: [_pad(const Offset(20, 15), 'gnd')],
      ),
    );
    final cut = none.steps.where((s) => s.clear && s.shape is PourPad).single;
    expect((cut.shape as PourPad).grow, 0.5);
    expect(none.steps.where((s) => !s.clear && s.shape is PourStroke), isEmpty);
  });

  test('another net is cut out with the wider of the two clearances', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd')],
        footprints: [_pad(const Offset(20, 15), 'sig', reference: 'R2')],
        tracks: const [
          Track(
            id: 't',
            projectId: 'p',
            netId: 'sig',
            layer: CopperLayer.front,
            startX: 5,
            startY: 10,
            endX: 30,
            endY: 10,
            width: 0.25,
          ),
        ],
      ),
    );
    final pad = plan.steps.where((s) => s.clear && s.shape is PourPad).single;
    expect((pad.shape as PourPad).grow, 0.5);
    final track = plan.steps
        .where(
          (s) =>
              s.clear &&
              s.shape is PourStroke &&
              (s.shape as PourStroke).points.length == 2,
        )
        .single;
    // Track width plus the pour's 0.5 mm clearance each side.
    expect((track.shape as PourStroke).width, closeTo(1.25, 1e-9));
  });

  test('a pad the spokes cannot reach is reported, not silently cut off', () {
    // The pour stops just past the pad on every side.
    final plan = _plan(
      _scene(
        zones: [
          _zone(
            'gnd',
            net: 'gnd',
            points: const [
              Offset(19, 14),
              Offset(21, 14),
              Offset(21, 16),
              Offset(19, 16),
            ],
          ),
        ],
        footprints: [_pad(const Offset(20, 15), 'gnd')],
      ),
    );
    expect(plan.warnings.single, contains('R1.1'));
    expect(plan.warnings.single, contains('GND'));
  });
}

/// A via on [net] at [at].
Via _via(Offset at, String? net) => Via(
  id: 'v',
  projectId: 'p',
  x: at.dx,
  y: at.dy,
  diameter: 0.8,
  drill: 0.4,
  netId: net,
);

void _viaConnectionTests() {
  test('a via on the pour\'s own net is poured solid by default', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd')],
        vias: [_via(const Offset(20, 15), 'gnd')],
      ),
    );
    // Nothing at all is drawn for it: the pour simply covers it.
    final discs = [
      for (final step in plan.steps)
        if (step.shape case final PourDisc disc) disc,
    ];
    expect(discs, isEmpty);
  });

  test('set to thermal, the via gets a ring and four spokes', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd', viaConnection: PadConnection.thermal)],
        vias: [_via(const Offset(20, 15), 'gnd')],
      ),
    );
    final ring = [
      for (final step in plan.steps)
        if (step.clear && step.shape is PourDisc) step.shape as PourDisc,
    ].single;
    expect(ring.centre, const Offset(20, 15));
    // The via plus the thermal gap either side.
    expect(ring.diameter, closeTo(0.8 + 0.5 * 2, 1e-9));

    final spokes = [
      for (final step in plan.steps)
        if (!step.clear)
          if (step.shape case final PourStroke stroke)
            if (stroke.points.first == const Offset(20, 15)) stroke,
    ];
    expect(spokes, hasLength(4));
    expect(plan.warnings, isEmpty);
  });

  test('set to none, the via is kept clear like anyone else\'s', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd', viaConnection: PadConnection.none)],
        vias: [_via(const Offset(20, 15), 'gnd')],
      ),
    );
    final cut = [
      for (final step in plan.steps)
        if (step.clear && step.shape is PourDisc) step.shape as PourDisc,
    ].single;
    expect(cut.diameter, greaterThan(0.8));
    // And no spokes back to it.
    expect([
      for (final step in plan.steps)
        if (!step.clear)
          if (step.shape case final PourStroke stroke)
            if (stroke.points.first == const Offset(20, 15)) stroke,
    ], isEmpty);
  });

  test('another net\'s via is cut out of the pour whatever the setting', () {
    final plan = _plan(
      _scene(
        zones: [_zone('gnd', net: 'gnd', viaConnection: PadConnection.thermal)],
        vias: [_via(const Offset(20, 15), 'vcc')],
      ),
    );
    expect([
      for (final step in plan.steps)
        if (step.clear && step.shape is PourDisc) step.shape as PourDisc,
    ], hasLength(1));
  });
}
