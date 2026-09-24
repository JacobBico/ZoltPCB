import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';

// The meander itself is tested in meander_engine_test.dart.
void main() {
  group('net length', () {
    BoardScene scene(List<Track> tracks, {int layers = 4}) => BoardScene(
      board: Board(
        id: 'b',
        projectId: 'p',
        outlineX: 0,
        outlineY: 0,
        outlineWidth: 50,
        outlineHeight: 50,
        rules: const DesignRules(),
        gridMm: 0.5,
        modifiedAt: DateTime(2026),
        copperLayerCount: layers,
      ),
      footprints: const [],
      pads: const [],
      tracks: tracks,
      vias: const [],
      ratsnest: const [],
      unplaced: const [],
    );

    Track track(
      double length, {
      CopperLayer layer = CopperLayer.front,
      String net = 'n',
    }) => Track(
      id: '$length-$layer',
      projectId: 'p',
      netId: net,
      layer: layer,
      startX: 0,
      startY: 0,
      endX: length,
      endY: 0,
      width: 0.2,
    );

    test('adds up every track on the net and nothing else', () {
      final result = NetLength.of(
        scene([track(10), track(5.5), track(99, net: 'other')]),
        'n',
      );
      expect(result.length, closeTo(15.5, 1e-9));
      expect(result.trackCount, 2);
    });

    test('a buried track is slower than one on the surface', () {
      final outer = NetLength.of(scene([track(100)]), 'n');
      final inner = NetLength.of(
        scene([track(100, layer: CopperLayer.inner1)], layers: 4),
        'n',
      );
      expect(inner.delayPs, greaterThan(outer.delayPs));
      // Around 6 ps/mm on the surface of FR-4, 7 inside it.
      expect(outer.delayPs / 100, closeTo(5.9, 0.5));
      expect(inner.delayPs / 100, closeTo(7.1, 0.4));
    });
  });
}
