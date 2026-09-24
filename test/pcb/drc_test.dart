import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';

/// A board with two front-copper pads 4 mm apart on one net, and nothing
/// else, so a rule can be tested one at a time.
BoardScene sceneWith({
  DesignRules rules = const DesignRules(),
  List<Track> tracks = const [],
  List<Via> vias = const [],
  Rect outline = const Rect.fromLTWH(0, 0, 40, 30),
}) {
  final board = Board(
    id: 'b',
    projectId: 'p',
    outlineX: outline.left,
    outlineY: outline.top,
    outlineWidth: outline.width,
    outlineHeight: outline.height,
    rules: rules,
    gridMm: 0.5,
    modifiedAt: DateTime(2026),
  );

  return BoardScene(
    board: board,
    footprints: const [],
    pads: const [],
    tracks: tracks,
    vias: vias,
    ratsnest: const [],
    unplaced: const [],
  );
}

Track track({
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  String? netId = 'net-a',
  CopperLayer layer = CopperLayer.front,
  double width = 0.25,
  String id = 't',
}) => Track(
  id: id,
  projectId: 'p',
  netId: netId,
  layer: layer,
  startX: x1,
  startY: y1,
  endX: x2,
  endY: y2,
  width: width,
);

void main() {
  group('clearance', () {
    test('two nets running side by side too close is an error', () {
      // Centres 0.3 mm apart, tracks 0.25 wide: the gap is 0.05 mm, well
      // inside a 0.2 mm rule.
      final scene = sceneWith(
        tracks: [
          track(id: 'a', x1: 5, y1: 5, x2: 20, y2: 5, netId: 'net-a'),
          track(id: 'b', x1: 5, y1: 5.3, x2: 20, y2: 5.3, netId: 'net-b'),
        ],
      );

      final clearance = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.clearance);
      expect(clearance, hasLength(1));
      expect(clearance.single.isError, isTrue);
    });

    test('the same two tracks far enough apart pass', () {
      final scene = sceneWith(
        tracks: [
          track(id: 'a', x1: 5, y1: 5, x2: 20, y2: 5, netId: 'net-a'),
          track(id: 'b', x1: 5, y1: 6, x2: 20, y2: 6, netId: 'net-b'),
        ],
      );

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.clearance),
        isEmpty,
      );
    });

    test('copper of one net may touch itself', () {
      final scene = sceneWith(
        tracks: [
          track(id: 'a', x1: 5, y1: 5, x2: 20, y2: 5),
          track(id: 'b', x1: 5, y1: 5.05, x2: 20, y2: 5.05),
        ],
      );

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.clearance),
        isEmpty,
      );
    });

    test('copper on opposite layers cannot clash', () {
      final scene = sceneWith(
        tracks: [
          track(id: 'a', x1: 5, y1: 5, x2: 20, y2: 5, netId: 'net-a'),
          track(
            id: 'b',
            x1: 5,
            y1: 5.05,
            x2: 20,
            y2: 5.05,
            netId: 'net-b',
            layer: CopperLayer.back,
          ),
        ],
      );

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.clearance),
        isEmpty,
      );
    });

    test('crossing tracks of different nets are a short, not a near miss', () {
      final scene = sceneWith(
        tracks: [
          track(id: 'a', x1: 5, y1: 5, x2: 20, y2: 5, netId: 'net-a'),
          track(id: 'b', x1: 12, y1: 2, x2: 12, y2: 12, netId: 'net-b'),
        ],
      );

      final clearance = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.clearance);
      expect(clearance, hasLength(1));
      expect(clearance.single.message, contains('0.00 mm'));
    });

    test('a via clashes with copper of another net on either layer', () {
      final scene = sceneWith(
        tracks: [
          track(
            id: 'a',
            x1: 5,
            y1: 5,
            x2: 20,
            y2: 5,
            netId: 'net-a',
            layer: CopperLayer.back,
          ),
        ],
        vias: [
          const Via(
            id: 'v',
            projectId: 'p',
            netId: 'net-b',
            x: 12,
            y: 5.3,
            diameter: 0.8,
            drill: 0.4,
          ),
        ],
      );

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.clearance),
        hasLength(1),
      );
    });
  });

  group('other rules', () {
    test('a track narrower than the rule is reported', () {
      final scene = sceneWith(
        rules: const DesignRules(trackWidth: 0.25),
        tracks: [track(x1: 5, y1: 5, x2: 20, y2: 5, width: 0.15)],
      );

      final narrow = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.trackWidth);
      expect(narrow, hasLength(1));
      expect(narrow.single.message, contains('0.15 mm'));
    });

    test('a track that leaves the board is reported once', () {
      final scene = sceneWith(tracks: [track(x1: 5, y1: 5, x2: 60, y2: 5)]);

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.offBoard),
        hasLength(1),
      );
    });

    test('a via with no annular ring is reported', () {
      final scene = sceneWith(
        vias: [
          const Via(
            id: 'v',
            projectId: 'p',
            x: 10,
            y: 10,
            diameter: 0.4,
            drill: 0.6,
          ),
        ],
      );

      expect(
        checkBoard(scene).where((v) => v.rule == DrcRule.viaSize),
        hasLength(1),
      );
    });

    test('an unrouted net is a warning, not an error', () {
      final base = sceneWith();
      final scene = BoardScene(
        board: base.board,
        footprints: const [],
        pads: const [],
        tracks: const [],
        vias: const [],
        ratsnest: const [
          RatsnestLine(
            netId: 'net-a',
            netName: 'VCC',
            from: Offset(5, 5),
            to: Offset(20, 5),
          ),
        ],
        unplaced: const [],
      );

      final unrouted = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.unrouted);
      expect(unrouted, hasLength(1));
      expect(unrouted.single.isError, isFalse);
      expect(unrouted.single.message, contains('VCC'));
    });

    test('a footprint whose library is gone is an error', () {
      final base = sceneWith();
      final scene = BoardScene(
        board: base.board,
        footprints: [
          PlacedFootprint(
            ref: const PlacedFootprintRef(
              id: 'f',
              projectId: 'p',
              partId: 'part',
              libId: 'Gone:Nothing',
              x: 10,
              y: 10,
              placed: true,
            ),
            part: Part(
              id: 'part',
              projectId: 'p',
              libId: 'Device:R',
              reference: 'R1',
              value: '10k',
              createdAt: DateTime(2026),
            ),
            placement: const FootprintPlacement(x: 10, y: 10),
            pads: const [],
          ),
        ],
        pads: const [],
        tracks: const [],
        vias: const [],
        ratsnest: const [],
        unplaced: const [],
      );

      final missing = checkBoard(
        scene,
      ).where((v) => v.rule == DrcRule.missingFootprint);
      expect(missing, hasLength(1));
      expect(missing.single.message, contains('R1'));
      expect(missing.single.isError, isTrue);
    });

    test('a clean board reports nothing at all', () {
      expect(checkBoard(sceneWith()), isEmpty);
    });
  });
}
