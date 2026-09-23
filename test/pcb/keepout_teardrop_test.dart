
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

PlacedFootprint _part(String reference, Offset at, String? net, double size) {
  final pad = Pad(
    number: '1',
    type: PadType.smd,
    shape: PadShape.circle,
    at: const FootprintPoint(0, 0),
    sizeX: size,
    sizeY: size,
    layers: const [BoardLayer.frontCopper],
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
      value: '',
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
  List<PlacedFootprint> footprints = const [],
  List<Track> tracks = const [],
  List<Via> vias = const [],
  List<BoardZone> zones = const [],
  TeardropRules teardrops = const TeardropRules(),
  int layers = 2,
}) => BoardScene(
  board: Board(
    id: 'b',
    projectId: 'p',
    outlineX: 0,
    outlineY: 0,
    outlineWidth: 40,
    outlineHeight: 30,
    rules: const DesignRules(),
    gridMm: 0.5,
    teardrops: teardrops,
    copperLayerCount: layers,
    modifiedAt: DateTime(2026),
  ),
  footprints: footprints,
  pads: [for (final f in footprints) ...f.pads],
  tracks: tracks,
  vias: vias,
  zones: zones,
  ratsnest: const [],
  unplaced: const [],
);

BoardZone _keepout({
  bool noTracks = true,
  bool noVias = true,
  bool noParts = false,
}) => BoardZone(
  id: 'k',
  projectId: 'p',
  layer: BoardLayer.frontCopper,
  points: const [
    Offset(10, 10),
    Offset(20, 10),
    Offset(20, 20),
    Offset(10, 20),
  ],
  keepout: true,
  noTracks: noTracks,
  noVias: noVias,
  noParts: noParts,
);

Track _track(Offset a, Offset b, {String? net = 'n'}) => Track(
  id: 't',
  projectId: 'p',
  netId: net,
  layer: CopperLayer.front,
  startX: a.dx,
  startY: a.dy,
  endX: b.dx,
  endY: b.dy,
  width: 0.25,
);

List<DrcViolation> _keepouts(BoardScene scene) =>
    checkBoard(scene).where((v) => v.rule == DrcRule.keepout).toList();

void main() {
  group('keepouts', () {
    test('a track that ends inside one is reported', () {
      final found = _keepouts(
        _scene(
          zones: [_keepout()],
          tracks: [_track(const Offset(5, 15), const Offset(15, 15))],
        ),
      );
      expect(found, hasLength(1));
      expect(found.single.message, contains('track'));
      expect(found.single.isError, isTrue);
    });

    test('a track that only crosses a corner is caught too', () {
      // Sampled along its length, not just at its ends: a run straight
      // through the area never ends inside it.
      final found = _keepouts(
        _scene(
          zones: [_keepout()],
          tracks: [_track(const Offset(5, 15), const Offset(35, 15))],
        ),
      );
      expect(found, hasLength(1));
    });

    test('what it allows, it allows', () {
      expect(
        _keepouts(
          _scene(
            zones: [_keepout(noTracks: false)],
            tracks: [_track(const Offset(5, 15), const Offset(15, 15))],
          ),
        ),
        isEmpty,
      );
    });

    test('a via inside one, and a part when it says so', () {
      final scene = _scene(
        zones: [_keepout(noParts: true)],
        vias: const [
          Via(id: 'v', projectId: 'p', x: 15, y: 15, diameter: 0.8, drill: 0.4),
        ],
        footprints: [_part('R1', const Offset(15, 16), 'n', 1)],
      );
      final found = _keepouts(scene);
      expect(found.map((v) => v.message), [contains('via'), contains('R1')]);
    });

    test('a keepout is not poured, and it cuts back what is', () {
      final plan = PourFill.plan(
        _scene(
          zones: [
            BoardZone(
              id: 'gnd',
              projectId: 'p',
              layer: BoardLayer.frontCopper,
              netId: 'n',
              netName: 'GND',
              points: const [
                Offset(0, 0),
                Offset(40, 0),
                Offset(40, 30),
                Offset(0, 30),
              ],
            ),
            _keepout(),
          ],
        ),
        CopperLayer.front,
      );
      // The pour is laid, then the keepout is taken back out of it.
      final laid = plan.steps.indexWhere((s) => !s.clear);
      final cut = plan.steps.indexWhere(
        (s) =>
            s.clear &&
            s.shape is PourRegion &&
            (s.shape as PourRegion).points.first == const Offset(10, 10),
      );
      expect(laid, isNonNegative);
      expect(cut, greaterThan(laid));
    });

    test('a route walks round one, whatever net it is on', () {
      final scene = _scene(zones: [_keepout()]);
      final corners = WalkaroundRouter.route(
        scene,
        from: const Offset(5, 15),
        to: const Offset(35, 15),
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'n',
      );
      expect(corners, isNotNull);
      for (final corner in [const Offset(5, 15), ...corners!]) {
        expect(
          _keepout().contains(corner),
          isFalse,
          reason: '$corner is inside the keepout',
        );
      }
    });
  });

  group('teardrops', () {
    final scene = _scene(
      footprints: [_part('R1', const Offset(10, 15), 'n', 1.6)],
      tracks: [_track(const Offset(10, 15), const Offset(25, 15))],
      teardrops: const TeardropRules(enabled: true),
    );

    test('off by default, and nothing is drawn', () {
      expect(Teardrops.of(_scene(), CopperLayer.front), isEmpty);
    });

    test('a fillet where the track meets the pad', () {
      final drops = Teardrops.of(scene, CopperLayer.front);
      expect(drops, hasLength(1));
      final points = drops.single.points;
      expect(points.length, greaterThan(8));
      // It fills the corner: wider than the track where it meets the pad,
      // and back down to the track by the time it leaves.
      final nearPad = points
          .where((p) => (p.dx - 10).abs() < 0.3)
          .map((p) => (p.dy - 15).abs())
          .reduce((a, b) => a > b ? a : b);
      expect(nearPad, greaterThan(0.25));
      expect(nearPad, lessThan(0.8));
      // And it stays on its own net.
      expect(drops.single.netId, 'n');
    });

    test('nothing where the track is as wide as the pad', () {
      final wide = _scene(
        footprints: [_part('R1', const Offset(10, 15), 'n', 0.3)],
        tracks: [_track(const Offset(10, 15), const Offset(25, 15))],
        teardrops: const TeardropRules(enabled: true),
      );
      expect(Teardrops.of(wide, CopperLayer.front), isEmpty);
    });

    test('on a via too, and only when asked for', () {
      final vias = _scene(
        vias: const [
          Via(
            id: 'v',
            projectId: 'p',
            netId: 'n',
            x: 10,
            y: 15,
            diameter: 1.2,
            drill: 0.4,
          ),
        ],
        tracks: [_track(const Offset(10, 15), const Offset(25, 15))],
        teardrops: const TeardropRules(enabled: true),
      );
      expect(Teardrops.of(vias, CopperLayer.front), hasLength(1));

      final padsOnly = _scene(
        vias: vias.vias,
        tracks: vias.tracks,
        teardrops: const TeardropRules(enabled: true, onVias: false),
      );
      expect(Teardrops.of(padsOnly, CopperLayer.front), isEmpty);
    });
  });

  group('via spans', () {
    Via via(ViaKind kind, CopperLayer from, CopperLayer to) => Via(
      id: 'v',
      projectId: 'p',
      x: 10,
      y: 10,
      diameter: 0.6,
      drill: 0.3,
      kind: kind,
      fromLayer: from,
      toLayer: to,
    );

    test('a through via reaches every layer', () {
      final board = _scene(layers: 4).board;
      final through = via(ViaKind.through, CopperLayer.front, CopperLayer.back);
      expect(through.layersOn(board), hasLength(4));
      expect(through.problemOn(board), isNull);
    });

    test('blind starts outside, buried does not', () {
      final board = _scene(layers: 4).board;
      expect(
        via(
          ViaKind.blind,
          CopperLayer.front,
          CopperLayer.inner1,
        ).problemOn(board),
        isNull,
      );
      expect(
        via(
          ViaKind.blind,
          CopperLayer.inner1,
          CopperLayer.inner2,
        ).problemOn(board),
        contains('top or the bottom'),
      );
      expect(
        via(
          ViaKind.buried,
          CopperLayer.inner1,
          CopperLayer.inner2,
        ).problemOn(board),
        isNull,
      );
      expect(
        via(
          ViaKind.buried,
          CopperLayer.front,
          CopperLayer.inner2,
        ).problemOn(board),
        contains('cannot reach'),
      );
    });

    test('a span this board does not have is a rule violation', () {
      final scene = _scene(
        layers: 2,
        vias: [via(ViaKind.blind, CopperLayer.front, CopperLayer.inner1)],
      );
      final found = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.viaSpan).toList();
      expect(found, hasLength(1));
      expect(found.single.message, contains('Blind'));
    });

    test('a blind via reaches only its own layers', () {
      final board = _scene(layers: 6).board;
      final blind = via(ViaKind.blind, CopperLayer.front, CopperLayer.inner2);
      expect(blind.layersOn(board), [
        CopperLayer.front,
        CopperLayer.inner1,
        CopperLayer.inner2,
      ]);
    });
  });
}
