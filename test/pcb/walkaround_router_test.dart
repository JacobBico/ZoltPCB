import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';

/// A 2 x 2 mm pad on [net] at [at].
PlacedFootprint _part(String reference, Offset at, String net) {
  const pad = Pad(
    number: '1',
    type: PadType.smd,
    shape: PadShape.rect,
    at: FootprintPoint(0, 0),
    sizeX: 2,
    sizeY: 2,
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

BoardScene _scene(
  List<PlacedFootprint> parts, {
  List<Track> tracks = const [],
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
    modifiedAt: DateTime(2026),
  ),
  footprints: parts,
  pads: [for (final p in parts) ...p.pads],
  tracks: tracks,
  vias: const [],
  ratsnest: const [],
  unplaced: const [],
);

void main() {
  const from = Offset(5, 15);
  const to = Offset(35, 15);

  List<Offset>? route(BoardScene scene) => WalkaroundRouter.route(
    scene,
    from: from,
    to: to,
    width: 0.25,
    layer: CopperLayer.front,
    netId: 'a',
  );

  test('with nothing in the way, it is the plain route', () {
    expect(route(_scene([])), [to]);
  });

  test('another net\'s pad in the way is walked round, at the clearance', () {
    final scene = _scene([_part('R9', const Offset(20, 15), 'b')]);
    final corners = route(scene)!;
    final path = [from, ...corners];
    expect(path.last, to);
    expect(path.length, greaterThan(2), reason: 'it had to turn');

    // Every run on a legal angle.
    for (var i = 0; i < path.length - 1; i++) {
      final dx = (path[i + 1].dx - path[i].dx).abs();
      final dy = (path[i + 1].dy - path[i].dy).abs();
      final legal = dx < 1e-6 || dy < 1e-6 || (dx - dy).abs() < 1e-6;
      expect(legal, isTrue, reason: 'run $i is not 0, 45 or 90°');
    }
    // And nowhere too close to the pad it went round.
    expect(
      routeClashes(
        scene,
        route: path,
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'a',
      ),
      isEmpty,
    );
    // A few runs, not a staircase.
    expect(path.length, lessThanOrEqualTo(7));
  });

  test('copper on its own net is not in its way', () {
    final scene = _scene([_part('R9', const Offset(20, 15), 'a')]);
    expect(route(scene), [to]);
  });

  test('a wall with no gap: no way round, and it says so', () {
    final wall = [
      for (var y = 1.0; y < 30; y += 2) _part('W$y', Offset(20, y), 'b'),
    ];
    expect(route(_scene(wall)), isNull);
  });

  test('one map, many targets: the way round is worked out from it', () {
    // The map is the expensive half and it does not change while a finger
    // moves, so it is built once and asked over and over — which is the
    // difference between a route that follows the crosshair and one that
    // arrives a second and a half later.
    final scene = _scene([_part('R9', const Offset(20, 15), 'b')]);
    final field = WalkaroundField.of(
      scene,
      layer: CopperLayer.front,
      width: 0.25,
      netId: 'a',
    );
    expect(field.matches(scene, CopperLayer.front, 0.25, 'a'), isTrue);
    expect(field.matches(scene, CopperLayer.back, 0.25, 'a'), isFalse);
    expect(field.matches(scene, CopperLayer.front, 0.3, 'a'), isFalse);
    expect(field.matches(scene, CopperLayer.front, 0.25, 'b'), isFalse);

    for (var i = 0; i < 40; i++) {
      final to = Offset(30 + i * 0.1, 12 + i * 0.15);
      final corners = WalkaroundRouter.routeOn(field, from: from, to: to);
      expect(corners, isNotNull, reason: 'no way to $to');
      expect(corners!.last, to);
      expect(
        routeClashes(
          scene,
          route: [from, ...corners],
          width: 0.25,
          layer: CopperLayer.front,
          netId: 'a',
        ),
        isEmpty,
        reason: 'the way round to $to is not clear',
      );
    }
  });

  test('a component in the way is gone round, not through', () {
    // Two pads a couple of millimetres apart, which is what a part looks
    // like to a router: the copper, not the outline.
    final scene = _scene([
      _part('U1a', const Offset(20, 14), 'b'),
      _part('U1b', const Offset(20, 17), 'b'),
    ]);
    final path = [
      from,
      ...WalkaroundRouter.route(
        scene,
        from: from,
        to: to,
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'a',
      )!,
    ];
    expect(path.last, to);
    expect(
      routeClashes(
        scene,
        route: path,
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'a',
      ),
      isEmpty,
    );
  });

  test('a track in the way is gone round too', () {
    final scene = _scene(
      [],
      tracks: const [
        Track(
          id: 't',
          projectId: 'p',
          netId: 'b',
          layer: CopperLayer.front,
          startX: 20,
          startY: 8,
          endX: 20,
          endY: 22,
          width: 0.25,
        ),
      ],
    );
    final path = [from, ...route(scene)!];
    expect(
      routeClashes(
        scene,
        route: path,
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'a',
      ),
      isEmpty,
    );
  });
}
