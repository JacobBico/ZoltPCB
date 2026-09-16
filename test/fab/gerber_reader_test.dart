import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/fab/gerber_reader.dart';
import 'package:hintpcb/fab/gerber_writer.dart';

BoardScene _scene({
  List<Track> tracks = const [],
  List<Via> vias = const [],
  List<BoardZone> zones = const [],
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
  footprints: const [],
  pads: const [],
  tracks: tracks,
  vias: vias,
  ratsnest: const [],
  unplaced: const [],
  zones: zones,
);

String _file(BoardScene scene, String suffix) => FabricationWriter.write(
  scene,
  baseName: 'b',
).firstWhere((f) => f.name.endsWith(suffix)).content;

void main() {
  test('what is written reads back as the same shapes', () {
    final scene = _scene(
      tracks: const [
        Track(
          id: 't',
          projectId: 'p',
          layer: CopperLayer.front,
          startX: 5,
          startY: 5,
          endX: 15,
          endY: 8,
          width: 0.3,
        ),
      ],
      vias: const [
        Via(id: 'v', projectId: 'p', x: 15, y: 8, diameter: 0.8, drill: 0.4),
      ],
    );
    final image = GerberReader.parse(_file(scene, '-F_Cu.gbr'));

    final stroke = image.shapes.whereType<GerberStroke>().single;
    expect(stroke.width, closeTo(0.3, 1e-9));
    expect(stroke.points.first, const Offset(5, 5));
    expect(stroke.points.last, const Offset(15, 8));
    expect(stroke.clear, isFalse);

    final flash = image.shapes.whereType<GerberFlash>().single;
    expect(flash.at, const Offset(15, 8));
    expect(flash.aperture.width, closeTo(0.8, 1e-9));
  });

  test('a pour reads back as a region, with its clearances cut out', () {
    final scene = _scene(
      zones: const [
        BoardZone(
          id: 'z',
          projectId: 'p',
          layer: BoardLayer.frontCopper,
          points: [Offset(0, 0), Offset(40, 0), Offset(40, 30), Offset(0, 30)],
          netId: 'gnd',
          netName: 'GND',
        ),
      ],
      tracks: const [
        Track(
          id: 's',
          projectId: 'p',
          netId: 'sig',
          layer: CopperLayer.front,
          startX: 5,
          startY: 10,
          endX: 30,
          endY: 10,
          width: 0.25,
        ),
      ],
    );
    final image = GerberReader.parse(_file(scene, '-F_Cu.gbr'));
    final region = image.shapes.whereType<GerberRegion>().single;
    expect(region.points, hasLength(4));
    expect(region.points[2], const Offset(40, 30));
    expect(image.shapes.where((s) => s.clear), isNotEmpty);
    // The track is drawn again, dark, after the clearing.
    expect(image.shapes.last.clear, isFalse);
  });

  test('the outline reads back as the board', () {
    final bounds = GerberReader.parse(
      _file(_scene(), '-Edge_Cuts.gbr'),
    ).bounds!;
    expect(bounds.left, closeTo(0, 0.05));
    expect(bounds.right, closeTo(40, 0.05));
    expect(bounds.bottom, closeTo(30, 0.05));
  });

  test('drill holes read back where they were', () {
    final holes = GerberReader.parseDrill(
      _file(
        _scene(
          vias: const [
            Via(
              id: 'v',
              projectId: 'p',
              x: 12.5,
              y: 7,
              diameter: 0.8,
              drill: 0.4,
            ),
          ],
        ),
        '-PTH.drl',
      ),
    );
    expect(holes, hasLength(1));
    expect(holes.single.at, const Offset(12.5, 7));
    expect(holes.single.diameter, 0.4);
  });

  test('the position file has the columns an assembly house asks for', () {
    final csv = FabricationWriter.positions(_scene(), baseName: 'b');
    expect(csv.name, 'b-pos.csv');
    expect(
      csv.content.split('\n').first,
      'Designator,Val,Package,Mid X,Mid Y,Rotation,Layer',
    );
  });
}
