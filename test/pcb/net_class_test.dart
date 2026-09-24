import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/export/board_document.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/kicad/board_project_writer.dart';

import '../helpers/fixtures.dart';

Board _board() => Board(
  id: 'b',
  projectId: 'p',
  outlineX: 0,
  outlineY: 0,
  outlineWidth: 40,
  outlineHeight: 30,
  rules: const DesignRules(),
  gridMm: 0.5,
  modifiedAt: DateTime(2026),
);

Track _track(String id, double y, String net, {double width = 0.25}) => Track(
  id: id,
  projectId: 'p',
  netId: net,
  layer: CopperLayer.front,
  startX: 5,
  startY: y,
  endX: 20,
  endY: y,
  width: width,
);

const _power = NetClass(
  id: 'power',
  projectId: 'p',
  name: 'Power traces',
  trackWidth: 0.5,
  clearance: 0.6,
);

BoardScene _scene({List<Track> tracks = const [], bool classed = false}) =>
    BoardScene(
      board: _board(),
      footprints: const [],
      pads: const [],
      tracks: tracks,
      vias: const [],
      ratsnest: const [],
      unplaced: const [],
      netClasses: classed ? const [_power] : const [],
      netClassByNet: classed ? const {'vbus': _power} : const {},
    );

void main() {
  group('while routing', () {
    test('the run too close to another net is flagged, and only that run', () {
      // The other net's track stops at x = 12, so only the first run of the
      // route, which passes along it, is too close; the turn at x = 15 is
      // clear of it.
      final short = Track(
        id: 'other',
        projectId: 'p',
        netId: 'net-b',
        layer: CopperLayer.front,
        startX: 5,
        startY: 10,
        endX: 12,
        endY: 10,
        width: 0.25,
      );
      final scene = _scene(tracks: [short]);
      final clashes = routeClashes(
        scene,
        // Along y = 10.3 (too close), then down and away.
        route: const [Offset(8, 10.3), Offset(15, 10.3), Offset(15, 20)],
        width: 0.25,
        layer: CopperLayer.front,
        netId: 'net-a',
      );
      expect(clashes, isNotEmpty);
      expect(clashes.map((c) => c.segment).toSet(), {0});
    });

    test('its own net is never in the way', () {
      final scene = _scene(tracks: [_track('same', 10, 'net-a')]);
      expect(
        routeClashes(
          scene,
          route: const [Offset(8, 10.3), Offset(15, 10.3)],
          width: 0.25,
          layer: CopperLayer.front,
          netId: 'net-a',
        ),
        isEmpty,
      );
    });

    test('the other layer is never in the way', () {
      final scene = _scene(tracks: [_track('other', 10, 'net-b')]);
      expect(
        routeClashes(
          scene,
          route: const [Offset(8, 10.3), Offset(15, 10.3)],
          width: 0.25,
          layer: CopperLayer.back,
          netId: 'net-a',
        ),
        isEmpty,
      );
    });

    test('a class that asks for more room gets it', () {
      // 0.5 mm between edges: fine for the 0.2 mm rule, not for 0.6 mm.
      final route = const [Offset(8, 10.75), Offset(15, 10.75)];
      expect(
        routeClashes(
          _scene(tracks: [_track('other', 10, 'net-b')]),
          route: route,
          width: 0.25,
          layer: CopperLayer.front,
          netId: 'vbus',
        ),
        isEmpty,
      );
      expect(
        routeClashes(
          _scene(tracks: [_track('other', 10, 'net-b')], classed: true),
          route: route,
          width: 0.25,
          layer: CopperLayer.front,
          netId: 'vbus',
        ),
        isNotEmpty,
      );
    });
  });

  test('DRC holds a classed net to its class clearance', () {
    final tracks = [_track('a', 10, 'vbus'), _track('b', 10.75, 'net-b')];
    bool clashes(BoardScene scene) =>
        checkBoard(scene).any((v) => v.rule == DrcRule.clearance);
    expect(clashes(_scene(tracks: tracks)), isFalse);
    expect(clashes(_scene(tracks: tracks, classed: true)), isTrue);
  });

  group('stored and exported', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() async => db.close());

    test('a class is kept, given nets, and let go of', () async {
      final project = await ProjectRepository(db).create(name: 'Classes');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final boards = BoardRepository(db);

      final net = await nets.connectPins(
        (await parts.addPart(project.id, resistorSpec())).pins.first.id,
        (await parts.addPart(project.id, resistorSpec())).pins.first.id,
      );
      await nets.renameNet(net.net.id, 'VBUS');

      final power = await boards.addNetClass(
        projectId: project.id,
        name: 'Power traces',
        trackWidth: 0.5,
      );
      await boards.setNetClass(net.net.id, power.id);

      final stored = (await nets.getNets(project.id)).single;
      expect(stored.net.netClassId, power.id);

      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: const [],
        definitions: const {},
        netClasses: await boards.getNetClasses(project.id),
      );
      expect(scene.classOf(net.net.id)?.trackWidth, 0.5);
      // No clearance of its own: the board's rule.
      expect(scene.clearanceFor(net.net.id), scene.board.rules.clearance);

      final json =
          jsonDecode(
                BoardProjectWriter.write(
                  BoardDocument(
                    project: project,
                    scene: scene,
                    nets: await nets.getNets(project.id),
                  ),
                  fileName: 'x.kicad_pro',
                ),
              )
              as Map;
      final settings = json['net_settings'] as Map;
      final classes = settings['classes'] as List;
      expect(classes.map((c) => (c as Map)['name']), [
        'Default',
        'Power traces',
      ]);
      expect((classes[1] as Map)['track_width'], 0.5);
      expect(settings['netclass_patterns'], [
        {'netclass': 'Power traces', 'pattern': 'VBUS'},
      ]);

      await boards.deleteNetClass(power.id);
      expect(await boards.getNetClasses(project.id), isEmpty);
      expect((await nets.getNets(project.id)).single.net.netClassId, isNull);
    });
  });
}
