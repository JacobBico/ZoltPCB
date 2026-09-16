import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';
import 'package:hintpcb/rendering/schematic_scene.dart';

import '../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late PartRepository parts;
  late NetRepository nets;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    nets = NetRepository(db);
    project = await ProjectRepository(db).create(name: 'Labels');
  });

  tearDown(() async => db.close());

  Future<SchematicScene> buildScene() async => SchematicScene.build(
    paper: project.paper,
    parts: await parts.getPartsWithDetails(project.id),
    nets: await nets.getNets(project.id),
    symbols: const {},
  );

  /// Two resistors, their far pins joined, on a net called [name].
  Future<String> lowPass({String name = 'OUTPUT'}) async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 40, y: 40, placed: true),
    );
    final net = await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
    await nets.renameNet(net.id, name);
    return net.id;
  }

  test('a named net is labelled once, not once per pin', () async {
    await lowPass();
    final scene = await buildScene();

    // Two pins are on the net; one label between them. Drawing it at every
    // endpoint is what made a filter unreadable.
    expect(scene.labels, hasLength(1));
    expect(scene.labels.single.text, 'OUTPUT');
    expect(scene.labels.single.pinned, isFalse);
  });

  test('an unnamed net has no label at all', () async {
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await parts.updateUnitPlacement(
      r2.units.first.copyWith(x: 40, y: 40, placed: true),
    );
    await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

    expect((await buildScene()).labels, isEmpty);
  });

  test(
    'a ground net draws no text, because the symbol already says so',
    () async {
      final resistor = await parts.addPart(project.id, resistorSpec());
      final ground = await parts.addPart(project.id, groundSpec());
      await parts.updateUnitPlacement(
        ground.units.first.copyWith(x: 25.4, y: 45, placed: true),
      );
      // Connecting to a power symbol names the net after it — GND.
      await nets.connectPins(resistor.pins.last.id, ground.pins.first.id);

      final scene = await buildScene();
      expect(scene.nets.single.net.name, 'GND');
      expect(scene.labels, isEmpty);
    },
  );

  test('the label sits on the corner of the wire, not on a pin', () async {
    await lowPass();
    final scene = await buildScene();

    final wire = scene.wires.single;
    final label = scene.labels.single;
    // Never on an endpoint: those are the pins, where the old drawing put
    // it and where it collided with everything else.
    for (final end in [wire.points.first, wire.points.last]) {
      expect((label.position - end).distance, greaterThan(1.0));
    }
    // On one of the wire's own corners, lifted clear of the copper.
    final corners = wire.points.sublist(1, wire.points.length - 1);
    expect(corners, isNotEmpty);
    expect(
      corners.any((c) => (Offset(c.dx, c.dy) - label.position).distance < 3.0),
      isTrue,
    );
  });

  test('a stored position wins, and says it was pinned', () async {
    final netId = await lowPass();
    await nets.setNetLabelPosition(netId, const Offset(60, 70));

    final label = (await buildScene()).labels.single;
    expect(label.position, const Offset(60, 70));
    expect(label.pinned, isTrue);

    // And clearing it puts the label back on the wire.
    await nets.setNetLabelPosition(netId, null);
    expect((await buildScene()).labels.single.pinned, isFalse);
  });

  test('a label is grabbable over the box it is drawn in', () async {
    final netId = await lowPass();
    await nets.setNetLabelPosition(netId, const Offset(60, 70));
    final scene = await buildScene();

    NetLabel? at(Offset point) => scene.labelNear(
      point,
      halfHeightMm: SchematicPainter.labelHeightMm,
      halfWidthMm: (label) => SchematicPainter.labelHalfWidthMm(label.text),
    );

    expect(at(const Offset(60, 70))?.netId, netId);
    // Just inside the right-hand end of the text.
    final halfWidth = SchematicPainter.labelHalfWidthMm('OUTPUT');
    expect(at(Offset(60 + halfWidth - 0.1, 70))?.netId, netId);
    // Well clear of it.
    expect(at(Offset(60 + halfWidth + 5, 70)), isNull);
  });
}
