import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/geometry/polyline_wiring.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/features/project/schematic_panel.dart';
import 'package:zolt/rendering/schematic_painter.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

/// One wire to lay down before the drag: its shape, and which part pin each
/// end sits on, named as `part.pin`.
class _Wire {
  const _Wire(this.points, {this.a, this.b, this.net = 0});
  final List<Offset> points;
  final String? a;
  final String? b;

  /// Which net it belongs to, so a sheet can have more than one.
  final int net;
}

/// A sheet to drag things around on.
class _Sheet {
  const _Sheet(this.name, this.wires);
  final String name;
  final List<_Wire> wires;
}

SchematicPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<SchematicPainter>()
    .single;

/// Parts sit at fixed places, so the pins are at known points:
/// R1 pin 1 (50.8, 46.99) pin 2 (50.8, 54.61)
/// R2 pin 1 (76.2, 46.99) pin 2 (76.2, 54.61)
/// R3 is out of the way, to keep the view from zooming in on the wires.

List<_Sheet> _sheets() => [
  const _Sheet('a stub off a pin with a branch', [
    _Wire([Offset(50.8, 54.61), Offset(50.8, 68.58)], a: 'R1.2'),
    _Wire([Offset(50.8, 68.58), Offset(66.04, 68.58)]),
  ]),
  const _Sheet('an L off a pin, with a wire off its corner', [
    _Wire([
      Offset(50.8, 54.61),
      Offset(50.8, 68.58),
      Offset(66.04, 68.58),
    ], a: 'R1.2'),
    _Wire([Offset(50.8, 68.58), Offset(50.8, 60.96)]),
  ]),
  const _Sheet('pin to pin, with a stub off the middle', [
    _Wire(
      [
        Offset(50.8, 54.61),
        Offset(50.8, 66.04),
        Offset(76.2, 66.04),
        Offset(76.2, 54.61),
      ],
      a: 'R1.2',
      b: 'R2.2',
    ),
    _Wire([Offset(63.5, 66.04), Offset(63.5, 78.74)]),
  ]),
  const _Sheet('a comb: a spine with teeth', [
    _Wire([Offset(50.8, 54.61), Offset(50.8, 60.96)], a: 'R1.2'),
    _Wire([Offset(50.8, 60.96), Offset(88.9, 60.96)]),
    _Wire([Offset(60.96, 60.96), Offset(60.96, 73.66)]),
    _Wire([Offset(73.66, 60.96), Offset(73.66, 73.66)]),
  ]),
  const _Sheet('two wires a few squares apart, joined at one end', [
    _Wire([Offset(50.8, 54.61), Offset(50.8, 60.96)], a: 'R1.2'),
    _Wire([Offset(50.8, 60.96), Offset(83.82, 60.96)]),
    _Wire([Offset(50.8, 71.12), Offset(83.82, 71.12)]),
    _Wire([Offset(83.82, 60.96), Offset(83.82, 71.12)]),
  ]),
  const _Sheet('two nets, one crossing the other', [
    _Wire([Offset(50.8, 54.61), Offset(50.8, 66.04)], a: 'R1.2'),
    _Wire([Offset(50.8, 66.04), Offset(88.9, 66.04)]),
    _Wire([Offset(76.2, 54.61), Offset(76.2, 78.74)], a: 'R2.2', net: 1),
  ]),
];

void main() {
  for (final sheet in _sheets()) {
    _runSheet(_splitAtJunctions(sheet));
  }
}

/// [sheet] with every wire that runs through a junction split there — the
/// shape the app keeps every net in, so the runs dragged are the wires the
/// sheet actually holds.
_Sheet _splitAtJunctions(_Sheet sheet) {
  final wires = <_Wire>[];
  for (final net in {for (final w in sheet.wires) w.net}) {
    final split = PolylineWiring.splitAtJunctions([
      for (final (i, w) in sheet.wires.indexed)
        if (w.net == net)
          PolylineWire(id: '$i', points: w.points, pinA: w.a, pinB: w.b),
    ]);
    wires.addAll([
      for (final piece in split)
        _Wire(piece.points, a: piece.pinA, b: piece.pinB, net: net),
    ]);
  }
  return _Sheet(sheet.name, wires);
}

void _runSheet(_Sheet sheet) {
  // Every run of every wire, dragged each way across itself. After each
  // one: the right wire moved, nothing else did that should not have, the
  // net is in one piece, nothing was duplicated, and no pin came unwired.
  for (var w = 0; w < sheet.wires.length; w++) {
    final wire = sheet.wires[w];
    for (var run = 0; run < wire.points.length - 1; run++) {
      final a = wire.points[run];
      final b = wire.points[run + 1];
      if ((a - b).distance < 7) continue; // too short to grab safely
      final horizontal = (a.dy - b.dy).abs() < 0.01;

      for (final push in const [5.08, -5.08, 12.7]) {
        final delta = horizontal ? Offset(0, push) : Offset(push, 0);
        final grab = (a + b) / 2;

        testAppWithStorage('${sheet.name}: wire $w run $run by $delta', (
          tester,
          db,
          storage,
        ) async {
          await _drag(tester, db, storage, sheet, grab, grab + delta, w);
        });
      }

      // Right at the end of the run, a drag pulls a new wire out of that
      // point instead: the wire itself must not budge, and exactly one
      // wire may appear.
      for (final end in [a, b]) {
        final inwards = (end - (end == a ? b : a));
        final at = end - inwards / inwards.distance * 1.0;
        final away = horizontal
            ? const Offset(0, 10.16)
            : const Offset(10.16, 0);

        testAppWithStorage(
          '${sheet.name}: wire $w run $run branch at ${end.dx.round()},'
          '${end.dy.round()}',
          (tester, db, storage) async {
            await _drag(
              tester,
              db,
              storage,
              sheet,
              at,
              at + away,
              w,
              expectBranch: true,
            );
          },
        );
      }
    }
  }
}

Future<void> _drag(
  WidgetTester tester,
  AppDatabase db,
  LibraryFileStorage storage,
  _Sheet sheet,
  Offset grab,
  Offset to,
  int dragged, {
  bool expectBranch = false,
}) async {
  final project = await ProjectRepository(db).create(name: sheet.name);
  final parts = PartRepository(db);
  final nets = NetRepository(db);

  final r1 = await parts.addPart(project.id, resistorSpec());
  await parts.updateUnitPlacement(
    r1.units.first.copyWith(x: 50.8, y: 50.8, placed: true),
  );
  final r2 = await parts.addPart(project.id, resistorSpec());
  await parts.updateUnitPlacement(
    r2.units.first.copyWith(x: 76.2, y: 50.8, placed: true),
  );
  final r3 = await parts.addPart(project.id, resistorSpec());
  await parts.updateUnitPlacement(
    r3.units.first.copyWith(x: 101.6, y: 88.9, placed: true),
  );

  String pinOf(String name) {
    final part = name.startsWith('R1') ? r1 : r2;
    final number = name.split('.').last;
    return part.pins.firstWhere((p) => p.number == number).id;
  }

  // The nets, one per group used by the sheet.
  final netIds = <int, String>{};
  for (final wire in sheet.wires) {
    if (netIds.containsKey(wire.net)) continue;
    final anchor = sheet.wires.firstWhere(
      (w) => w.net == wire.net && (w.a != null || w.b != null),
      orElse: () => wire,
    );
    final pin = anchor.a ?? anchor.b;
    netIds[wire.net] = pin == null
        ? (await nets.getNets(project.id)).first.net.id
        : await nets.netForPin(project.id, pinOf(pin));
  }

  for (final wire in sheet.wires) {
    await nets.addWire(
      projectId: project.id,
      points: wire.points,
      pinAId: wire.a == null ? null : pinOf(wire.a!),
      pinBId: wire.b == null ? null : pinOf(wire.b!),
      netId: netIds[wire.net]!,
    );
  }

  await pumpApp(
    tester,
    Scaffold(body: SchematicPanel(project: project)),
    database: db,
    storage: storage,
  );

  Offset screen(Offset at) =>
      tester.getRect(find.byType(SchematicPanel)).topLeft +
      _painter(tester).viewport.toScreen(at);

  List<SchematicWire> wiresNow() => _painter(tester).scene.wires
      .map(
        (w) => SchematicWire(
          id: w.drawnId ?? w.key,
          projectId: project.id,
          netId: w.netId,
          points: w.points,
          pinAId: w.pinAId.isEmpty ? null : w.pinAId,
          pinBId: w.pinBId.isEmpty ? null : w.pinBId,
        ),
      )
      .toList();

  String shapeOf(SchematicWire w) =>
      w.points.map((p) => '${p.dx.round()},${p.dy.round()}').join('→');

  /// The ground the drawing covers, as the longest runs it draws.
  ///
  /// Where the wires are cut does not change what is drawn — a wire cut in
  /// two at a junction covers exactly what it covered — so runs lying along
  /// each other are rolled together before comparing. That is what "the
  /// drawing did not change" actually means.
  List<String> coverageOf(List<SchematicWire> wires) {
    // axis and fixed coordinate → the spans covered along it
    final spans = <String, List<List<double>>>{};
    for (final wire in wires) {
      for (var i = 0; i < wire.points.length - 1; i++) {
        final a = wire.points[i];
        final b = wire.points[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final key = horizontal
            ? 'H${a.dy.toStringAsFixed(1)}'
            : 'V${a.dx.toStringAsFixed(1)}';
        final from = horizontal ? a.dx : a.dy;
        final to = horizontal ? b.dx : b.dy;
        (spans[key] ??= []).add([from < to ? from : to, from < to ? to : from]);
      }
    }

    final covered = <String>[];
    for (final entry in spans.entries) {
      final ranges = entry.value..sort((x, y) => x[0].compareTo(y[0]));
      var low = ranges.first[0];
      var high = ranges.first[1];
      for (final range in ranges.skip(1)) {
        if (range[0] <= high + 0.01) {
          if (range[1] > high) high = range[1];
        } else {
          covered.add(
            '${entry.key}:${low.toStringAsFixed(1)}'
            '-${high.toStringAsFixed(1)}',
          );
          low = range[0];
          high = range[1];
        }
      }
      covered.add(
        '${entry.key}:${low.toStringAsFixed(1)}-${high.toStringAsFixed(1)}',
      );
    }
    return covered..sort();
  }

  final before = wiresNow();
  final pinsBefore = await nets.pinToNetMap(project.id);

  final from = screen(grab);
  final target = screen(to);
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= 12; i++) {
    await gesture.moveTo(Offset.lerp(from, target, i / 12)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  final during = coverageOf(wiresNow());
  await gesture.up();
  await settleApp(tester);

  final after = wiresNow();
  final shapes = [for (final w in after) shapeOf(w)]..sort();
  final what =
      '\n  before: ${[for (final w in before) shapeOf(w)]}'
      '\n  after:  $shapes';

  // What the finger was showing is what the sheet keeps — as a set, since
  // a wire dragged exactly onto another is two wires while the finger is
  // down and the one wire they draw once it lifts.
  if (!expectBranch) {
    expect(
      coverageOf(after),
      during,
      reason: 'the drawing changed on release$what',
    );
  }

  // Nothing is drawn twice.
  expect(
    shapes.toSet().length,
    shapes.length,
    reason: 'a wire was duplicated$what',
  );

  // At the end of a run several things can rightly happen — a new wire
  // pulled out, a wire drawn from the pin sitting there, or the run itself
  // sliding — so those cases are held to the checks that apply whatever
  // happened: nothing duplicated, nothing unwired, nothing left behind,
  // nothing diagonal.

  // Each net is still drawn in one piece.
  for (final netId in netIds.values) {
    final shapesOfNet = [
      for (final w in after)
        if (w.netId == netId) w.points,
    ];
    expect(
      PolylineWiring.allJoined(shapesOfNet),
      isTrue,
      reason: 'a net came apart$what',
    );
  }

  // Nothing shrunk to nothing: a wire with its ends in the same place is
  // invisible, and it keeps the wires either side of it from reading as
  // the one wire they draw.
  for (final wire in after) {
    var length = 0.0;
    for (var i = 0; i < wire.points.length - 1; i++) {
      length += (wire.points[i + 1] - wire.points[i]).distance;
    }
    expect(
      length,
      greaterThan(0.01),
      reason: 'a wire shrunk to nothing was left lying there$what',
    );
  }

  // Every run still square.
  for (final wire in after) {
    expect(
      PolylineWiring.square(wire.points),
      isTrue,
      reason: 'a run went diagonal$what',
    );
  }

  // No pin quietly came off its net, and none changed nets.
  final pinsAfter = await nets.pinToNetMap(project.id);
  for (final entry in pinsBefore.entries) {
    expect(
      pinsAfter.containsKey(entry.key),
      isTrue,
      reason: 'a pin came unwired$what',
    );
  }

  // Whatever moved, the wire under the finger is among it: the drawing
  // never rearranges itself around a wire that stayed put. (Pulling a new
  // wire out moves nothing, which the branch check above covers.)
  if (expectBranch) return;

  final draggedShape = sheet.wires[dragged].points
      .map((p) => '${p.dx.round()},${p.dy.round()}')
      .join('→');
  final movedIds = <String>[];
  for (final was in before) {
    final still = after.where((w) => w.id == was.id).firstOrNull;
    if (still == null || shapeOf(still) != shapeOf(was)) movedIds.add(was.id);
  }
  if (movedIds.isNotEmpty) {
    final draggedId = before
        .where((w) => shapeOf(w) == draggedShape)
        .map((w) => w.id)
        .firstOrNull;
    expect(
      draggedId == null || movedIds.contains(draggedId),
      isTrue,
      reason: 'another wire moved while the one dragged stayed put$what',
    );
  }

  // The wire under the finger moved, and wires of other nets did not.
  final draggedNet = netIds[sheet.wires[dragged].net]!;
  for (var i = 0; i < before.length; i++) {
    if (before[i].netId == draggedNet) continue;
    final still = after.where((w) => w.id == before[i].id).firstOrNull;
    expect(
      still == null ? null : shapeOf(still),
      shapeOf(before[i]),
      reason: 'a wire on another net moved$what',
    );
  }
}
