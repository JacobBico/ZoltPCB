import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/geometry/polyline_wiring.dart';

/// A net to drag about, with a name for the failure message.
class _Case {
  _Case(this.name, List<PolylineWire> wires)
    : wires = PolylineWiring.splitAtJunctions(wires);
  final String name;

  /// Split at its junctions, the way the app keeps every net: a wire ends
  /// wherever another meets its middle.
  final List<PolylineWire> wires;
}

PolylineWire _w(String id, List<Offset> points, {String? pinA, String? pinB}) =>
    PolylineWire(id: id, points: points, pinA: pinA, pinB: pinB);

/// The nets these tests drag around: the shapes a schematic actually ends
/// up in, including the ones from the bug reports.
List<_Case> _cases() => [
  _Case('a stub off a pin, with a branch at its loose end', [
    _w('down', const [Offset(50, 40), Offset(50, 60)], pinA: 'p1'),
    _w('across', const [Offset(50, 60), Offset(70, 60)]),
  ]),
  _Case('an L off a pin, with a wire up from its corner', [
    _w('ell', const [
      Offset(50, 40),
      Offset(50, 60),
      Offset(70, 60),
    ], pinA: 'p1'),
    _w('up', const [Offset(50, 60), Offset(50, 50)]),
  ]),
  _Case('a tee: a wire ending part-way along another', [
    _w('spine', const [Offset(40, 50), Offset(80, 50)], pinA: 'p1'),
    _w('stub', const [Offset(60, 50), Offset(60, 70)]),
  ]),
  _Case('three wires meeting at a point', [
    _w('left', const [Offset(40, 50), Offset(60, 50)], pinA: 'p1'),
    _w('right', const [Offset(60, 50), Offset(80, 50)]),
    _w('down', const [Offset(60, 50), Offset(60, 70)]),
  ]),
  _Case('two pins joined, with a stub off the middle', [
    _w(
      'main',
      const [Offset(40, 50), Offset(60, 50), Offset(60, 70), Offset(80, 70)],
      pinA: 'p1',
      pinB: 'p2',
    ),
    _w('stub', const [Offset(60, 60), Offset(75, 60)]),
  ]),
  _Case('a comb: a spine with three teeth', [
    _w('spine', const [Offset(40, 50), Offset(100, 50)], pinA: 'p1'),
    _w('tooth1', const [Offset(50, 50), Offset(50, 65)]),
    _w('tooth2', const [Offset(70, 50), Offset(70, 65)]),
    _w('tooth3', const [Offset(90, 50), Offset(90, 65)]),
  ]),
  _Case('a chain of corners with a branch half way', [
    _w('chain', const [
      Offset(40, 40),
      Offset(40, 60),
      Offset(60, 60),
      Offset(60, 80),
    ], pinA: 'p1'),
    _w('branch', const [Offset(60, 60), Offset(80, 60)]),
  ]),
  _Case('two branches off the same point', [
    _w('spine', const [Offset(40, 50), Offset(80, 50)], pinA: 'p1'),
    _w('up', const [Offset(60, 50), Offset(60, 35)]),
    _w('down', const [Offset(60, 50), Offset(60, 65)]),
  ]),
  _Case('wires of one net crossing', [
    _w('across', const [Offset(40, 50), Offset(90, 50)], pinA: 'p1'),
    _w('down', const [Offset(60, 30), Offset(60, 70)]),
  ]),
  _Case('a zigzag with a branch at a middle corner', [
    _w('zig', const [
      Offset(40, 40),
      Offset(60, 40),
      Offset(60, 55),
      Offset(80, 55),
      Offset(80, 70),
    ], pinA: 'p1'),
    _w('branch', const [Offset(60, 55), Offset(45, 55)]),
  ]),
  _Case('both ends pinned, with a branch off the middle', [
    _w(
      'main',
      const [Offset(40, 50), Offset(70, 50), Offset(70, 80)],
      pinA: 'p1',
      pinB: 'p2',
    ),
    _w('branch', const [Offset(55, 50), Offset(55, 30)]),
  ]),
  _Case('a branch off a branch', [
    _w('spine', const [Offset(40, 50), Offset(90, 50)], pinA: 'p1'),
    _w('first', const [Offset(60, 50), Offset(60, 70)]),
    _w('second', const [Offset(60, 70), Offset(80, 70)]),
  ]),
  _Case('branches on both sides of a spine', [
    _w('spine', const [Offset(40, 50), Offset(100, 50)], pinA: 'p1'),
    _w('above', const [Offset(55, 50), Offset(55, 35)]),
    _w('below', const [Offset(75, 50), Offset(75, 65)]),
    _w('far', const [Offset(90, 50), Offset(90, 30)]),
  ]),
  _Case('a loop back on itself', [
    _w('out', const [
      Offset(40, 40),
      Offset(80, 40),
      Offset(80, 60),
    ], pinA: 'p1'),
    _w('back', const [Offset(80, 60), Offset(40, 60), Offset(40, 40)]),
  ]),
];

const _deltas = [
  Offset(0, 5),
  Offset(0, -5),
  Offset(5, 0),
  Offset(-5, 0),
  Offset(0, 15),
  Offset(-15, 0),
  // A finger does not move along one axis: the drag arrives with both.
  Offset(5, 5),
  Offset(-10, 5),
  Offset(10, -20),
];

/// The net as plain point chains, with the drag applied.
List<List<Offset>> _after(
  List<PolylineWire> net,
  String id,
  int run,
  Offset delta,
) {
  final result = PolylineWiring.drag(net, id, run, delta);
  return [
    for (final wire in net)
      if (wire.id == id)
        result.dragged
      else
        result.followers[wire.id] ?? wire.points,
  ];
}

void main() {
  // "it SHOULD also drag down the wire that its attached to ... it is like
  // directly disconnecting from the circuit". Every wire of every net,
  // dragged every way: the drawing must never come apart.
  group('dragging never breaks the net', () {
    for (final test in _cases()) {
      for (final wire in test.wires) {
        for (var run = 0; run < wire.points.length - 1; run++) {
          for (final delta in _deltas) {
            final what = '${test.name} · ${wire.id} run $run by $delta';

            it(what, () {
              final net = test.wires;
              final before = [for (final w in net) w.points];
              expect(
                PolylineWiring.allJoined(before),
                isTrue,
                reason: 'the net starts in one piece',
              );

              final after = _after(net, wire.id, run, delta);

              expect(
                PolylineWiring.allJoined(after),
                isTrue,
                reason: 'left behind: $after',
              );
              for (final shape in after) {
                expect(
                  PolylineWiring.square(shape),
                  isTrue,
                  reason: 'a run went diagonal: $shape',
                );
              }

              // A pinned end never moves: the part is where it is.
              for (var i = 0; i < net.length; i++) {
                if (net[i].startPinned) {
                  expect(
                    after[i].first,
                    net[i].points.first,
                    reason: 'a pinned end moved',
                  );
                }
                if (net[i].endPinned) {
                  expect(
                    after[i].last,
                    net[i].points.last,
                    reason: 'a pinned end moved',
                  );
                }
              }
            });
          }
        }
      }
    }
  });

  group('junctions stay where they are', _slidingJunctions);

  // Whatever else it does, a drag has to move the wire that was dragged.
  group('the wire dragged actually moves', () {
    for (final test in _cases()) {
      for (final wire in test.wires) {
        for (var run = 0; run < wire.points.length - 1; run++) {
          final a = wire.points[run];
          final b = wire.points[run + 1];
          final across = (a.dy - b.dy).abs() < 0.01
              ? const Offset(0, 5)
              : const Offset(5, 0);

          it('${test.name} · ${wire.id} run $run', () {
            final result = PolylineWiring.drag(
              test.wires,
              wire.id,
              run,
              across,
            );
            final moved = result.dragged;
            final midBefore = (a + b) / 2;
            expect(
              PolylineWiring.covers(moved, midBefore),
              isFalse,
              reason: 'the run stayed where it was: $moved',
            );
          });
        }
      }
    }
  });
}

/// `test`, but the name is allowed to repeat across groups.
void it(String name, dynamic Function() body) => test(name, body);

/// Cases where a wire is joined along the way the drag is going, so the
/// place they meet slides along it and nothing else need move.
void _slidingJunctions() {
  // "if there is a junction between two wires, the junction should NOT
  // move when one wire on either side is being moved up or down, left or
  // right, so basically, two wires should NOT be one long wire if they are
  // connected by a junction"
  test('a wire through a junction is two wires', () {
    final net = PolylineWiring.splitAtJunctions([
      _w('spine', const [Offset(40, 50), Offset(100, 50)], pinA: 'p1'),
      _w('tooth', const [Offset(70, 50), Offset(70, 65)]),
    ]);
    expect(net, hasLength(3));
    expect(net.first.points, const [Offset(40, 50), Offset(70, 50)]);
    expect(net.first.pinA, 'p1');
    expect(net[1].points, const [Offset(70, 50), Offset(100, 50)]);
    expect(net[1].pinA, isNull);
  });

  test('a piece of spine dragged between its teeth leaves them alone', () {
    final net = PolylineWiring.splitAtJunctions([
      _w('spine', const [Offset(40, 50), Offset(100, 50)], pinA: 'p1'),
      _w('tooth1', const [Offset(50, 50), Offset(50, 65)]),
      _w('tooth2', const [Offset(70, 50), Offset(70, 65)]),
      _w('tooth3', const [Offset(90, 50), Offset(90, 65)]),
    ]);
    final between = net.firstWhere(
      (w) => w.points.first == const Offset(50, 50),
    );

    // Up, away from the teeth: it keeps hold of both junctions by a corner
    // at each.
    final up = PolylineWiring.drag(net, between.id, 0, const Offset(0, -10));
    expect(up.dragged.first, const Offset(50, 50));
    expect(up.dragged.last, const Offset(70, 50));
    expect(PolylineWiring.covers(up.dragged, const Offset(60, 40)), isTrue);
    expect(up.followers, isEmpty, reason: 'nothing else moved');

    // Down, along the teeth: a corner there would lie on top of each tooth,
    // so it slides down them instead — and still nothing else moves.
    final down = PolylineWiring.drag(net, between.id, 0, const Offset(0, 10));
    expect(down.dragged, const [Offset(50, 60), Offset(70, 60)]);
    expect(down.followers, isEmpty, reason: 'nothing else moved');
  });

  test('either side of a junction moves on its own', () {
    for (final id in ['left', 'right', 'down']) {
      final net = [
        _w('left', const [Offset(40, 50), Offset(60, 50)]),
        _w('right', const [Offset(60, 50), Offset(80, 50)]),
        _w('down', const [Offset(60, 50), Offset(60, 70)]),
      ];
      for (final delta in _deltas) {
        final result = PolylineWiring.drag(net, id, 0, delta);
        expect(
          result.followers,
          isEmpty,
          reason: '$id by $delta moved another wire',
        );
        if (result.dragged.isEmpty) continue;
        final after = [
          for (final wire in net) wire.id == id ? result.dragged : wire.points,
        ];
        expect(
          PolylineWiring.allJoined(after),
          isTrue,
          reason: '$id by $delta came away from the others',
        );
      }
    }
  });

  // "moving the vertical wire along this horizontal wire ended up creating
  // a new wire ... nothing should be drawn when dragging from the
  // component"
  test('a wire slid along another off the same pin draws nothing new', () {
    final net = [
      _w('across', const [Offset(50, 60), Offset(90, 60)], pinA: 'c1'),
      _w('up', const [Offset(50, 60), Offset(50, 40)], pinA: 'c1'),
    ];
    final result = PolylineWiring.drag(net, 'up', 0, const Offset(10, 0));
    expect(result.dragged, const [Offset(60, 60), Offset(60, 40)]);
    expect(result.followers, isEmpty);
  });

  test('but not off a pin the other wire does not hold', () {
    final net = [
      _w('across', const [Offset(50, 60), Offset(90, 60)]),
      _w('up', const [Offset(50, 60), Offset(50, 40)], pinA: 'c1'),
    ];
    final result = PolylineWiring.drag(net, 'up', 0, const Offset(10, 0));
    expect(result.dragged.first, const Offset(50, 60), reason: 'on its pin');
  });

  test('a free end away from the junction goes with the drag', () {
    final net = PolylineWiring.splitAtJunctions([
      _w('spine', const [Offset(40, 50), Offset(100, 50)]),
      _w('tooth', const [Offset(70, 50), Offset(70, 65)]),
    ]);
    final result = PolylineWiring.drag(net, 'spine', 0, const Offset(0, -10));
    expect(result.dragged.first, const Offset(40, 40));
    expect(result.dragged.last, const Offset(70, 50));
    expect(result.followers, isEmpty);
  });

  // "if I drag this vertical wire to the right, it then extends our
  // original floating wire (as expected). However! If I drag the same wire
  // back, our original wire that we have just extended does not move back"
  //
  // Two wires meeting at a plain corner are not a junction: they still
  // move together.
  test('a wire on the end of another shortens it when dragged back', () {
    final net = [
      _w('across', const [Offset(40, 50), Offset(80, 50)], pinA: 'p1'),
      _w('up', const [Offset(80, 50), Offset(80, 35)]),
    ];

    final back = PolylineWiring.drag(net, 'up', 0, const Offset(-20, 0));

    expect(back.dragged.first.dx, 60, reason: 'the upright moved back');
    expect(
      back.followers['across']!.last,
      const Offset(60, 50),
      reason: 'and the wire it sits on the end of came back with it',
    );
  });

  // Nothing about a net that is already in two pieces should stop it
  // being dragged — the wires stuck fast when one was.
  test('a net already in pieces can still be dragged', () {
    final net = [
      _w('a', const [Offset(40, 50), Offset(60, 50)], pinA: 'p1'),
      _w('b', const [Offset(80, 70), Offset(100, 70)]),
    ];
    final result = PolylineWiring.drag(net, 'b', 0, const Offset(0, 5));
    expect(result.dragged, isNotEmpty);
    expect(result.dragged.first, const Offset(80, 75));
  });
}
