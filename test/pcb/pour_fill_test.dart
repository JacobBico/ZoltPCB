import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';

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
    expect(plan.warnings.single.message, contains('R1.1'));
    expect(plan.warnings.single.message, contains('GND'));
    // Pointed at the pad, not at the middle of the board.
    expect(plan.warnings.single.position, const Offset(20, 15));
  });

  _islandTests();
}

Track _track(
  String id,
  String net,
  Offset a,
  Offset b, {
  double width = 0.25,
}) => Track(
  id: id,
  projectId: 'p',
  netId: net,
  layer: CopperLayer.front,
  startX: a.dx,
  startY: a.dy,
  endX: b.dx,
  endY: b.dy,
  width: width,
);

void _islandTests() {
  group('connectivity and islands', () {
    test('two pads in one pour are joined by it', () {
      final plan = _plan(
        _scene(
          zones: [_zone('gnd', net: 'gnd')],
          footprints: [
            _pad(const Offset(8, 8), 'gnd'),
            _pad(const Offset(32, 22), 'gnd', reference: 'R2'),
          ],
        ),
      );
      expect(plan.joins, hasLength(1));
      expect(plan.joins.single.pads.map((p) => p.reference).toSet(), {
        'R1',
        'R2',
      });
      expect(plan.warnings, isEmpty);
    });

    test('a pour split by another net joins each side on its own', () {
      final plan = _plan(
        _scene(
          zones: [_zone('gnd', net: 'gnd')],
          footprints: [
            _pad(const Offset(8, 15), 'gnd'),
            _pad(const Offset(32, 15), 'gnd', reference: 'R2'),
          ],
          // Top to bottom, clean through the pour.
          tracks: [
            _track('t', 'sig', const Offset(20, -1), const Offset(20, 31)),
          ],
        ),
      );
      final gnd = [
        for (final join in plan.joins)
          if (join.netId == 'gnd') join,
      ];
      // Each half touches one pad only, so neither joins anything.
      expect(gnd, isEmpty);
      expect(plan.warnings, isEmpty);
    });

    // A capacitor across a battery's terminals, each pad in its own net's
    // pour where the two meet: cut out of both, it joined neither.
    test('a part where two pours meet joins each pad to its own', () {
      List<Offset> half(double from, double to) => [
        Offset(from, 0),
        Offset(to, 0),
        Offset(to, 30),
        Offset(from, 30),
      ];
      final plan = _plan(
        _scene(
          zones: [
            _zone(
              'bat',
              net: 'bat',
              points: half(0, 20),
              connection: PadConnection.solid,
            ),
            _zone(
              'gnd',
              net: 'gnd',
              points: half(20, 40),
              connection: PadConnection.solid,
            ),
          ],
          footprints: [
            _pad(const Offset(5, 15), 'bat', reference: 'BT1'),
            _pad(const Offset(35, 15), 'gnd', reference: 'BT2'),
            // Each a millimetre from the other net's pour.
            _pad(const Offset(18.5, 15), 'bat', reference: 'C1'),
            _pad(const Offset(21.5, 15), 'gnd', reference: 'C2'),
          ],
        ),
      );
      Set<String> joined(String net) => {
        for (final join in plan.joins)
          if (join.netId == net)
            for (final pad in join.pads) pad.reference,
      };
      expect(joined('bat'), {'BT1', 'C1'});
      expect(joined('gnd'), {'BT2', 'C2'});
      expect(plan.warnings, isEmpty);
    });

    test('a same-net track through the pour joins it too', () {
      final plan = _plan(
        _scene(
          zones: [
            _zone(
              'gnd',
              net: 'gnd',
              points: const [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 30),
                Offset(0, 30),
              ],
            ),
          ],
          footprints: [_pad(const Offset(5, 15), 'gnd')],
          tracks: [
            _track('t', 'gnd', const Offset(15, 15), const Offset(35, 15)),
          ],
        ),
      );
      expect(plan.joins.single.pads.single.reference, 'R1');
      expect(plan.joins.single.tracks.single.id, 't');
    });

    test('fill that reaches none of its net is cleared and reported', () {
      final scene = _scene(
        zones: [_zone('gnd', net: 'gnd')],
        footprints: [_pad(const Offset(8, 15), 'gnd')],
        tracks: [
          _track('t', 'sig', const Offset(20, -1), const Offset(20, 31)),
        ],
      );
      final plan = _plan(scene);

      // The right half has no ground on it: one island, reported where it
      // is rather than in the middle of the board.
      final island = plan.warnings.single;
      expect(island.island, isTrue);
      expect(island.message, contains('GND'));
      expect(island.position.dx, greaterThan(20));

      // Drawing the plan leaves no island behind...
      final again = PourAnalysis.analyse(
        scene: scene,
        layer: CopperLayer.front,
        steps: plan.steps,
        narrowest: 0.2,
      );
      expect(again.islands, isEmpty);

      // ...and the clears never reach the track's own copper: its right
      // edge is at 20.125, and the pour kept 0.5 mm off it.
      final firstIsland = plan.steps.indexWhere(
        (s) =>
            s.clear &&
            s.shape is PourRegion &&
            (s.shape as PourRegion).hole == null &&
            (s.shape as PourRegion).points.first.dx > 20,
      );
      expect(firstIsland, greaterThan(0));
      for (final step in plan.steps.skip(firstIsland)) {
        final points = (step.shape as PourRegion).points;
        for (final p in points) {
          expect(p.dx, greaterThan(20.125));
        }
      }
    });

    test('a pour with nothing of its net on it is left unfilled', () {
      final plan = _plan(_scene(zones: [_zone('gnd', net: 'gnd')]));
      expect(plan.warnings.single.island, isTrue);
      expect(plan.joins, isEmpty);
    });

    test('thermal spokes are what join a pad to its pour', () {
      final plan = _plan(
        _scene(
          zones: [_zone('gnd', net: 'gnd')],
          footprints: [
            _pad(const Offset(8, 8), 'gnd'),
            _pad(const Offset(30, 20), 'gnd', reference: 'R2'),
          ],
        ),
      );
      // The default connection is thermal: a ring and spokes.
      expect(plan.steps.any((s) => s.clear && s.shape is PourPad), isTrue);
      expect(plan.joins.single.pads, hasLength(2));
    });

    test('a pad the spokes miss is not counted as joined', () {
      final plan = _plan(
        _scene(
          zones: [_zone('gnd', net: 'gnd')],
          footprints: [
            _pad(const Offset(8, 8), 'gnd'),
            // Right against the board's edge: no spoke lands inside it,
            // since every one would end in the edge margin or off the
            // board.
            _pad(const Offset(0.2, 0.2), 'gnd', reference: 'R2'),
          ],
        ),
      );
      final joined = {
        for (final join in plan.joins)
          for (final pad in join.pads) pad.reference,
      };
      expect(joined, isNot(contains('R2')));
    });
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
