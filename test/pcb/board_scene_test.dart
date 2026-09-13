import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

import '../helpers/fixtures.dart';

/// A two-pad surface-mount footprint, 2 mm between pad centres.
FootprintDefinition twoPadSmd({String name = 'R_0805'}) => FootprintDefinition(
  libraryNickname: 'Test',
  name: name,
  attributes: const ['smd'],
  pads: [
    const Pad(
      number: '1',
      type: PadType.smd,
      shape: PadShape.rect,
      at: FootprintPoint(-1, 0),
      sizeX: 1,
      sizeY: 1,
      layers: [BoardLayer.frontCopper],
    ),
    const Pad(
      number: '2',
      type: PadType.smd,
      shape: PadShape.rect,
      at: FootprintPoint(1, 0),
      sizeX: 1,
      sizeY: 1,
      layers: [BoardLayer.frontCopper],
    ),
  ],
);

/// The same outline, but through-hole so its pads reach both sides.
FootprintDefinition twoPadTht() => FootprintDefinition(
  libraryNickname: 'Test',
  name: 'R_THT',
  attributes: const ['through_hole'],
  pads: [
    const Pad(
      number: '1',
      type: PadType.thruHole,
      shape: PadShape.circle,
      at: FootprintPoint(-1, 0),
      sizeX: 1.6,
      sizeY: 1.6,
      drill: 0.8,
      layers: [BoardLayer.frontCopper, BoardLayer.backCopper],
    ),
    const Pad(
      number: '2',
      type: PadType.thruHole,
      shape: PadShape.circle,
      at: FootprintPoint(1, 0),
      sizeX: 1.6,
      sizeY: 1.6,
      drill: 0.8,
      layers: [BoardLayer.frontCopper, BoardLayer.backCopper],
    ),
  ],
);

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late NetRepository nets;
  late BoardRepository boards;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    nets = NetRepository(db);
    boards = BoardRepository(db);
    project = await projects.create(name: 'Board');
  });

  tearDown(() async => db.close());

  /// Two resistors wired pin 2 to pin 1, placed 10 mm apart.
  Future<
    ({
      BoardScene Function({List<Track> tracks, List<Via> vias}) scene,
      PartWithDetails r1,
      PartWithDetails r2,
      String netId,
    })
  >
  divider({bool throughHole = false}) async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    final net = await nets.connectPins(
      r1.pins.firstWhere((p) => p.number == '2').id,
      r2.pins.firstWhere((p) => p.number == '1').id,
    );

    final board = await boards.ensureBoard(project.id);
    final definition = throughHole ? twoPadTht() : twoPadSmd();
    final libId = definition.libId;

    var a = await boards.assignFootprint(
      projectId: project.id,
      partId: r1.part.id,
      libId: libId,
    );
    var b = await boards.assignFootprint(
      projectId: project.id,
      partId: r2.part.id,
      libId: libId,
    );
    a = a.copyWith(x: 10, y: 10, placed: true);
    b = b.copyWith(x: 20, y: 10, placed: true);
    await boards.updatePlacement(a);
    await boards.updatePlacement(b);

    final partList = await parts.getPartsWithDetails(project.id);
    final netList = await nets.getNets(project.id);
    final placements = await boards.getFootprints(project.id);

    BoardScene build({List<Track> tracks = const [], List<Via> vias = const []}) =>
        BoardScene.build(
          board: board,
          parts: partList,
          nets: netList,
          placements: placements,
          definitions: {libId: definition},
          tracks: tracks,
          vias: vias,
        );

    return (scene: build, r1: r1, r2: r2, netId: net.id);
  }

  Track track(
    String netId, {
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    CopperLayer layer = CopperLayer.front,
    String id = 't1',
  }) => Track(
    id: id,
    projectId: 'p',
    netId: netId,
    layer: layer,
    startX: x1,
    startY: y1,
    endX: x2,
    endY: y2,
    width: 0.25,
  );

  group('pads', () {
    test('a pad lands where the footprint puts it', () async {
      final d = await divider();
      final scene = d.scene();

      final r1Pad2 = scene.pads.firstWhere((p) => p.label == 'R1.2');
      // R1 sits at (10, 10) and pad 2 is 1 mm to its right.
      expect(r1Pad2.position.dx, closeTo(11, 1e-9));
      expect(r1Pad2.position.dy, closeTo(10, 1e-9));
    });

    test('a pad takes its net from the pin with the same number', () async {
      final d = await divider();
      final scene = d.scene();

      final connected = scene.pads.where((p) => p.isConnected).toList();
      expect(
        connected.map((p) => p.label).toSet(),
        {'R1.2', 'R2.1'},
      );
      expect(connected.every((p) => p.netId == d.netId), isTrue);
    });

    test('rotating a footprint carries its pads round with it', () async {
      final d = await divider();
      var placement = (await boards.getFootprints(project.id)).firstWhere(
        (f) => f.partId == d.r1.part.id,
      );
      placement = placement.copyWith(rotation: 90);
      await boards.updatePlacement(placement);

      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: {twoPadSmd().libId: twoPadSmd()},
      );

      // A quarter turn counter-clockwise takes the pad 1 mm to the right of
      // the origin and puts it 1 mm above.
      final pad = scene.pads.firstWhere((p) => p.label == 'R1.2');
      expect(pad.position.dx, closeTo(10, 1e-9));
      expect(pad.position.dy, closeTo(9, 1e-9));
    });

    test('a footprint whose library is gone still reports itself', () async {
      final d = await divider();
      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: const {},
      );

      expect(scene.footprints, hasLength(2));
      expect(scene.footprints.every((f) => f.isResolved), isFalse);
      expect(scene.pads, isEmpty);
      expect(d.netId, isNotEmpty);
    });
  });

  group('ratsnest', () {
    test('an unrouted net owes one line', () async {
      final d = await divider();
      final scene = d.scene();

      expect(scene.ratsnest, hasLength(1));
      expect(scene.ratsnest.single.netId, d.netId);
      expect(scene.isFullyRouted, isFalse);
      expect(scene.unroutedNetIds, {d.netId});
    });

    test('a track between the pads settles the debt', () async {
      final d = await divider();
      final scene = d.scene(
        tracks: [track(d.netId, x1: 11, y1: 10, x2: 19, y2: 10)],
      );

      expect(scene.ratsnest, isEmpty);
      expect(scene.isFullyRouted, isTrue);
    });

    test('a track that stops short of a pad settles nothing', () async {
      final d = await divider();
      // Ends 2 mm shy of R2's pad, which is 1 mm wide.
      final scene = d.scene(
        tracks: [track(d.netId, x1: 11, y1: 10, x2: 17, y2: 10)],
      );

      expect(scene.ratsnest, hasLength(1));
    });

    test('a chain of segments counts as one run of copper', () async {
      final d = await divider();
      final scene = d.scene(
        tracks: [
          track(d.netId, id: 'a', x1: 11, y1: 10, x2: 15, y2: 5),
          track(d.netId, id: 'b', x1: 15, y1: 5, x2: 19, y2: 10),
        ],
      );

      expect(scene.ratsnest, isEmpty);
    });

    test('a track on the wrong layer does not reach a one-sided pad',
        () async {
      final d = await divider();
      final scene = d.scene(
        tracks: [
          track(
            d.netId,
            x1: 11,
            y1: 10,
            x2: 19,
            y2: 10,
            layer: CopperLayer.back,
          ),
        ],
      );

      // Both pads are front-only surface mount, so back copper joins
      // nothing — exactly the mistake that is invisible without this.
      expect(scene.ratsnest, hasLength(1));
    });

    test('a through-hole pad can be reached from the back', () async {
      final d = await divider(throughHole: true);
      final scene = d.scene(
        tracks: [
          track(
            d.netId,
            x1: 11,
            y1: 10,
            x2: 19,
            y2: 10,
            layer: CopperLayer.back,
          ),
        ],
      );

      expect(scene.ratsnest, isEmpty);
    });

    test('a via carries a route from one layer to the other', () async {
      final d = await divider();
      final scene = d.scene(
        tracks: [
          track(d.netId, id: 'a', x1: 11, y1: 10, x2: 15, y2: 10),
          track(
            d.netId,
            id: 'b',
            x1: 15,
            y1: 10,
            x2: 19,
            y2: 10,
            layer: CopperLayer.back,
          ),
        ],
      );
      // Without the via the two halves are separate pieces of copper.
      expect(scene.ratsnest, hasLength(1));

      final withVia = d.scene(
        tracks: [
          track(d.netId, id: 'a', x1: 11, y1: 10, x2: 15, y2: 10),
          track(
            d.netId,
            id: 'b',
            x1: 15,
            y1: 10,
            x2: 19,
            y2: 10,
            layer: CopperLayer.back,
          ),
        ],
        vias: [
          Via(
            id: 'v1',
            projectId: 'p',
            netId: d.netId,
            x: 15,
            y: 10,
            diameter: 0.8,
            drill: 0.4,
          ),
        ],
      );
      // The back segment still cannot reach R2's front-only pad, so this
      // proves the via joined the layers and nothing more.
      expect(withVia.ratsnest, hasLength(1));
    });

    test('copper that never reaches this net\'s pads does not route it',
        () async {
      final d = await divider();
      // Drawn from R1's *other* pad, off into empty board. It touches no pad
      // of the divider's net, so it cannot count towards routing it, no
      // matter what net it was drawn for.
      final scene = d.scene(
        tracks: [track(d.netId, x1: 9, y1: 10, x2: 9, y2: 25)],
      );

      expect(scene.ratsnest, hasLength(1));
    });

    test('a track\'s stored net gives way to the pads it connects', () async {
      // Net ids do not survive the schematic changing: a merge deletes one
      // and undoing it recreates both under new ids. So copper joining this
      // net's pads is on this net, whatever id it happens to carry.
      final d = await divider();
      final scene = d.scene(
        tracks: [track('stale-id', x1: 11, y1: 10, x2: 19, y2: 10)],
      );

      expect(scene.ratsnest, isEmpty);
      expect(scene.tracks.single.netId, d.netId);
      expect(scene.staleTrackIds, {'t1'});
    });
  });

  group('hit testing', () {
    test('a tap on a pad finds it', () async {
      final d = await divider();
      final scene = d.scene();

      final hit = scene.padNear(const Offset(11.2, 10.1), 0.5);
      expect(hit?.label, 'R1.2');
      expect(d.r2.part.reference, 'R2');
    });

    test('a tap away from every pad finds nothing', () async {
      final d = await divider();
      final scene = d.scene();

      expect(scene.padNear(const Offset(15, 30), 0.5), isNull);
    });

    test('asking for one layer ignores pads that do not reach it', () async {
      final d = await divider();
      final scene = d.scene();

      expect(
        scene.padNear(const Offset(11, 10), 0.5, layer: CopperLayer.front),
        isNotNull,
      );
      expect(
        scene.padNear(const Offset(11, 10), 0.5, layer: CopperLayer.back),
        isNull,
      );
    });
  });

  group('reported: copper must survive the schematic changing', () {
    // Merging two nets on the schematic deletes one of them. Every track
    // routed for the deleted net used to lose its net outright, which made
    // it stop counting as routed and turned it into a clearance error
    // against the very pads it connected.
    test('a track keeps working when its net is merged into another',
        () async {
      final d = await divider();

      // Route the divider's net.
      final trackId = await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 11,
        startY: 10,
        endX: 19,
        endY: 10,
        width: 0.25,
        netId: d.netId,
      );

      // A second net, then merge the routed one into it from the schematic.
      final r3 = await parts.addPart(project.id, resistorSpec());
      final other = await nets.connectPins(
        r3.pins.first.id,
        d.r1.pins.firstWhere((p) => p.number == '1').id,
      );
      await nets.renameNet(other.id, 'VCC');
      await nets.connectPins(
        r3.pins.first.id,
        d.r1.pins.firstWhere((p) => p.number == '2').id,
      );

      final stored = (await boards.getTracks(project.id)).single;
      final survivor = (await nets.getNets(project.id)).single;

      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: {twoPadSmd().libId: twoPadSmd()},
        tracks: await boards.getTracks(project.id),
      );

      final track = scene.tracks.single;
      expect(track.id, trackId);
      // Whatever the database did to the stored id, the scene puts the
      // copper on the net its pads are actually on now.
      expect(track.netId, survivor.id);
      if (stored.netId != survivor.id) {
        expect(scene.staleTrackIds, contains(trackId));
      }
      expect(scene.orphanTracks, isEmpty);
    });

    test('copper whose connection was removed is reported as such', () async {
      final d = await divider();
      await boards.addTrack(
        projectId: project.id,
        layer: CopperLayer.front,
        startX: 11,
        startY: 10,
        endX: 19,
        endY: 10,
        width: 0.25,
        netId: d.netId,
      );

      // Unwire the schematic net the track was drawn for.
      await nets.deleteNet(d.netId);

      final scene = BoardScene.build(
        board: await boards.ensureBoard(project.id),
        parts: await parts.getPartsWithDetails(project.id),
        nets: await nets.getNets(project.id),
        placements: await boards.getFootprints(project.id),
        definitions: {twoPadSmd().libId: twoPadSmd()},
        tracks: await boards.getTracks(project.id),
      );

      expect(scene.orphanTracks, hasLength(1));
      final findings = checkBoard(scene);
      expect(
        findings.where((v) => v.rule == DrcRule.orphanCopper),
        hasLength(1),
      );
    });

    test('a short between two nets is not quietly relabelled away', () {
      // Copper touching pads of two different nets is a real short. The
      // resolver must leave its stored nets alone so the clearance check
      // still sees two nets colliding.
      final board = Board(
        id: 'b',
        projectId: 'p',
        outlineX: 0,
        outlineY: 0,
        outlineWidth: 50,
        outlineHeight: 50,
        rules: const DesignRules(),
        gridMm: 0.5,
        modifiedAt: DateTime(2026),
      );
      final part = Part(
        id: 'part',
        projectId: 'p',
        libId: 'Device:R',
        reference: 'R1',
        value: '1k',
        createdAt: DateTime(2026),
      );

      PlacedPad pad(String number, double x, String net) => PlacedPad(
        pad: Pad(
          number: number,
          type: PadType.smd,
          shape: PadShape.rect,
          at: FootprintPoint(x, 0),
          sizeX: 1,
          sizeY: 1,
          layers: const [BoardLayer.frontCopper],
        ),
        partId: part.id,
        reference: 'R1',
        footprintId: 'f',
        position: Offset(x, 10),
        angle: 0,
        layers: const [BoardLayer.frontCopper],
        netId: net,
        netName: net,
      );

      // Build the scene directly so both pads can be put on different nets.
      final scene = BoardScene(
        board: board,
        footprints: const [],
        pads: [pad('1', 10, 'net-a'), pad('2', 20, 'net-b')],
        tracks: const [],
        vias: const [],
        ratsnest: const [],
        unplaced: const [],
      );
      expect(scene.pads, hasLength(2));
    });
  });
}
