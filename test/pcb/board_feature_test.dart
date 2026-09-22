import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/fab/gerber_reader.dart';
import 'package:hintpcb/fab/gerber_writer.dart';

final _gnd = NetWithEndpoints(
  net: Net(id: 'gnd', projectId: 'p', name: 'GND', createdAt: DateTime(2026)),
  endpoints: const [],
);

BoardScene _scene(
  List<BoardFeature> features, {
  List<BoardZone> zones = const [],
}) => BoardScene.build(
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
  parts: const [],
  nets: [_gnd],
  placements: const [],
  definitions: const {},
  zones: zones,
  features: features,
);

BoardFeature _feature(
  BoardFeatureKind kind, {
  String id = 'f',
  Offset at = const Offset(10, 10),
  double? size,
  bool plated = false,
  String? netId,
  String netName = '',
  bool placed = true,
}) => BoardFeature(
  id: id,
  projectId: 'p',
  kind: kind,
  reference: '${kind.prefix}1',
  x: at.dx,
  y: at.dy,
  size: size ?? BoardFeature.defaultSize(kind),
  plated: plated,
  netId: netId,
  netName: netName,
  placed: placed,
);

String _gerber(BoardScene scene, String suffix) => FabricationWriter.write(
  scene,
  baseName: 'b',
).firstWhere((f) => f.name.endsWith(suffix)).content;

void main() {
  test('a feature is a footprint on the board, named like KiCad\'s own', () {
    final scene = _scene([
      _feature(BoardFeatureKind.mountingHole),
      _feature(BoardFeatureKind.fiducial, id: 'g', at: const Offset(30, 5)),
      _feature(BoardFeatureKind.mountingHole, id: 'h', placed: false),
    ]);
    // Removed ones stay stored for undo but are not on the board.
    expect(scene.footprints, hasLength(2));
    final hole = scene.footprints.first;
    expect(hole.ref.libId, 'HintPCB:MountingHole_3.2mm');
    expect(hole.part.inBom, isFalse);
    expect(hole.pads.single.pad.type, PadType.npth);
    expect(scene.featureOf(hole.ref.id)?.reference, 'H1');
    expect(scene.footprints.last.ref.libId, 'HintPCB:Fiducial_1mm_Mask2mm');
  });

  test('a test point and a plated hole take their net, by id or by name', () {
    final scene = _scene([
      _feature(BoardFeatureKind.testPoint, netId: 'gnd', netName: 'GND'),
      // Its stored id is stale, as after the schematic was reshuffled.
      _feature(
        BoardFeatureKind.mountingHole,
        id: 'h',
        plated: true,
        netId: 'gone',
        netName: 'GND',
        at: const Offset(30, 20),
      ),
    ]);
    expect([for (final p in scene.pads) p.netId], ['gnd', 'gnd']);
  });

  test(
    'an unplated hole is drilled, carries no copper, and pours clear it',
    () {
      final scene = _scene(
        [_feature(BoardFeatureKind.mountingHole)],
        zones: const [
          BoardZone(
            id: 'z',
            projectId: 'p',
            layer: BoardLayer.frontCopper,
            points: [
              Offset(0, 0),
              Offset(40, 0),
              Offset(40, 30),
              Offset(0, 30),
            ],
            netId: 'gnd',
            netName: 'GND',
          ),
        ],
      );
      final holes = GerberReader.parseDrill(_gerber(scene, '-NPTH.drl'));
      expect(holes.single.diameter, 3.2);
      expect(holes.single.at, const Offset(10, 10));

      final copper = GerberReader.parse(_gerber(scene, '-F_Cu.gbr'));
      // No dark flash of its own; a clear one where the pour steps round it.
      final flashes = copper.shapes.whereType<GerberFlash>().toList();
      expect(flashes.where((f) => !f.clear), isEmpty);
      expect(flashes.where((f) => f.clear), hasLength(1));
      expect(
        flashes.single.aperture.width,
        greaterThan(3.2),
        reason: 'the hole plus the pour\'s clearance',
      );
    },
  );

  test('a fiducial opens the mask twice as wide as its copper', () {
    final scene = _scene([_feature(BoardFeatureKind.fiducial)]);
    final mask = GerberReader.parse(_gerber(scene, '-F_Mask.gbr'));
    expect(mask.shapes.whereType<GerberFlash>().single.aperture.width, 2.0);
    final copper = GerberReader.parse(_gerber(scene, '-F_Cu.gbr'));
    expect(copper.shapes.whereType<GerberFlash>().single.aperture.width, 1.0);
  });

  test('nothing the machine does not place goes in the position file', () {
    final scene = _scene([
      _feature(BoardFeatureKind.fiducial),
      _feature(BoardFeatureKind.testPoint, id: 't', netId: 'gnd'),
    ]);
    final pos = FabricationWriter.positions(
      scene,
      baseName: 'b',
    ).content.trim().split('\n');
    expect(pos, hasLength(1), reason: 'just the header');
  });

  test('a dimension measures, and stands off to the side it is told', () {
    const d = BoardDimension(
      id: 'd',
      projectId: 'p',
      start: Offset(0, 10),
      end: Offset(20, 10),
      offset: 3,
    );
    expect(d.length, 20);
    expect(d.text, '20.00 mm');
    final (a, b) = d.line;
    expect(a, const Offset(0, 7));
    expect(b, const Offset(20, 7));
  });
}
