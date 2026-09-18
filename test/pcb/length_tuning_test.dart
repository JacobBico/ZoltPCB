import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';

double pathLength(List<Offset> points) {
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += (points[i + 1] - points[i]).distance;
  }
  return total;
}

/// Whether every bend is a multiple of 45°, which is all a meander should
/// ever turn by.
bool only45(List<Offset> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final d = points[i + 1] - points[i];
    final angle = (d.direction * 180 / 3.141592653589793) % 45;
    if (angle > 1e-6 && 45 - angle > 1e-6) return false;
  }
  return true;
}

void main() {
  group('a meander adds exactly what was asked', () {
    for (final side in MeanderSide.values) {
      for (final corner in MeanderCorner.values) {
        for (final extra in [0.4, 3.0, 7.3, 12.0]) {
          test('${side.label}, ${corner.label}, +$extra mm', () {
            const a = Offset(10, 10);
            const b = Offset(50, 10);
            final plan = Meander.plan(
              a: a,
              b: b,
              extra: extra,
              maxAmplitude: 1.5,
              spacing: 0.75,
              side: side,
              corner: corner,
            );
            expect(plan.problem, isNull);
            expect(plan.points.first, a);
            expect(plan.points.last, b);
            expect(pathLength(plan.points) - 40, closeTo(extra, 1e-6));
            expect(plan.added, closeTo(extra, 1e-6));
            expect(plan.amplitude, lessThanOrEqualTo(1.5 + 1e-9));
            expect(only45(plan.points), isTrue);
          });
        }
      }
    }
  });

  test('loops stay on the side asked for', () {
    // Travelling +x on a y-down board, left of travel is -y.
    for (final (side, check) in [
      (MeanderSide.left, (double y) => y <= 10 + 1e-9),
      (MeanderSide.right, (double y) => y >= 10 - 1e-9),
    ]) {
      final plan = Meander.plan(
        a: const Offset(0, 10),
        b: const Offset(40, 10),
        extra: 5,
        maxAmplitude: 1,
        spacing: 0.6,
        side: side,
      );
      expect(plan.points.every((p) => check(p.dy)), isTrue, reason: side.label);
    }
    final both = Meander.plan(
      a: const Offset(0, 10),
      b: const Offset(40, 10),
      extra: 5,
      maxAmplitude: 1,
      spacing: 0.6,
    );
    expect(both.points.any((p) => p.dy < 10), isTrue);
    expect(both.points.any((p) => p.dy > 10), isTrue);
  });

  test('a diagonal track gets its loops turned with it', () {
    const a = Offset(0, 0);
    const b = Offset(30, 30);
    final plan = Meander.plan(
      a: a,
      b: b,
      extra: 6,
      maxAmplitude: 1,
      spacing: 0.6,
      corner: MeanderCorner.square,
    );
    expect(plan.problem, isNull);
    expect(pathLength(plan.points) - (b - a).distance, closeTo(6, 1e-6));
    // Every point stays within the amplitude of the original line.
    for (final p in plan.points) {
      expect(distanceToSegment(p, a, b), lessThanOrEqualTo(1 + 1e-6));
    }
  });

  test('no room: says how much straight track it needs', () {
    final plan = Meander.plan(
      a: Offset.zero,
      b: const Offset(4, 0),
      extra: 20,
      maxAmplitude: 0.5,
      spacing: 0.6,
    );
    expect(plan.isValid, isFalse);
    expect(plan.problem, contains('Needs'));
  });

  test('nothing to add is not a meander', () {
    final plan = Meander.plan(
      a: Offset.zero,
      b: const Offset(40, 0),
      extra: 0,
      maxAmplitude: 1,
      spacing: 0.6,
    );
    expect(plan.isValid, isFalse);
  });

  test('legs are at least a clearance apart, edge to edge', () {
    final spacing = Meander.defaultSpacing(0.2, 0.2);
    expect(spacing - 0.2, greaterThanOrEqualTo(0.2));
    expect(Meander.defaultSpacing(0.3, 0.1), closeTo(0.9, 1e-9));
  });

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
