import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/fab/gerber_reader.dart';
import 'package:zolt/fab/gerber_writer.dart';

BoardScene _scene({
  List<Track> tracks = const [],
  List<Via> vias = const [],
  List<BoardZone> zones = const [],
  List<BoardEdge> edges = const [],
  BoardOutlineKind outline = BoardOutlineKind.rectangle,
}) => BoardScene(
  board: Board(
    id: 'b',
    projectId: 'p',
    outlineKind: outline,
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
  edges: edges,
);

String _file(BoardScene scene, String suffix) => FabricationWriter.write(
  scene,
  baseName: 'b',
).firstWhere((f) => f.name.endsWith(suffix)).content;

/// Whether the image leaves copper at [p], drawing its shapes in order.
bool _copperAt(GerberImage image, Offset p) {
  var copper = false;
  for (final shape in image.shapes) {
    final covers = switch (shape) {
      GerberRegion(:final points) => _inside(points, p),
      GerberStroke(:final points, :final width) => [
        for (var i = 0; i + 1 < points.length; i++)
          _distance(p, points[i], points[i + 1]),
      ].any((d) => d <= width / 2),
      GerberFlash(:final at, :final aperture) =>
        (p - at).distance <= aperture.width / 2,
    };
    if (covers) copper = !shape.clear;
  }
  return copper;
}

bool _inside(List<Offset> polygon, Offset p) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _distance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (length2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

void main() {
  test('a piece of pour cut off from its net is not in the Gerber', () {
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
      // Another net cuts the board in two, top to bottom...
      tracks: const [
        Track(
          id: 's',
          projectId: 'p',
          netId: 'sig',
          layer: CopperLayer.front,
          startX: 20,
          startY: -1,
          endX: 20,
          endY: 31,
          width: 0.25,
        ),
      ],
      // ...and ground reaches only the left half.
      vias: const [
        Via(
          id: 'v',
          projectId: 'p',
          x: 10,
          y: 15,
          diameter: 0.8,
          drill: 0.4,
          netId: 'gnd',
        ),
      ],
    );
    final image = GerberReader.parse(_file(scene, '-F_Cu.gbr'));

    expect(_copperAt(image, const Offset(5, 5)), isTrue);
    expect(_copperAt(image, const Offset(19, 15)), isTrue);
    expect(_copperAt(image, const Offset(20, 15)), isTrue, reason: 'track');
    for (final p in const [
      Offset(21, 15),
      Offset(30, 5),
      Offset(39, 29),
      Offset(25, 0.5),
    ]) {
      expect(_copperAt(image, p), isFalse, reason: '$p');
    }
  });

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
    // The pour itself; the other region clears everything off the board.
    final region = image.shapes
        .whereType<GerberRegion>()
        .where((r) => !r.clear)
        .single;
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

  test('a round board and a curved cut go out as true arcs', () {
    final text = _file(
      _scene(
        outline: BoardOutlineKind.circle,
        edges: const [
          // A quarter arc from (30,15) through the top-right to (20,5),
          // round the centre (20,15).
          BoardEdge(
            id: 'e',
            projectId: 'p',
            kind: BoardEdgeKind.arc,
            points: [
              Offset(30, 15),
              Offset(27.0710678, 7.9289322),
              Offset(20, 5),
            ],
          ),
        ],
      ),
      '-Edge_Cuts.gbr',
    );
    // Arcs, not flats: the file says G02/G03 with a centre offset.
    expect(text, contains('G75*'));
    expect(RegExp(r'I-?\d+J-?\d+D01\*').allMatches(text), hasLength(2));

    final strokes = GerberReader.parse(
      text,
    ).shapes.whereType<GerberStroke>().toList();
    expect(strokes, hasLength(2));
    // The outline: a 30 mm circle in the 40 x 30 box, every point on it.
    for (final p in strokes[0].points) {
      expect((p - const Offset(20, 15)).distance, closeTo(15, 1e-4));
    }
    expect(strokes[0].points.first, strokes[0].points.last);
    // The cut: every point radius 10 from its centre, and on the side the
    // middle point said — up and to the right, not the long way round.
    for (final p in strokes[1].points) {
      expect((p - const Offset(20, 15)).distance, closeTo(10, 1e-4));
      expect(p.dx, greaterThanOrEqualTo(20 - 1e-6));
      expect(p.dy, lessThanOrEqualTo(15 + 1e-6));
    }
    expect(strokes[1].points.last, const Offset(20, 5));
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
