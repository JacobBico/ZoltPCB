import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/domain/symbols/symbols.dart' show StrokeStyle;

/// A 3.4 × 1.8 mm courtyard, like an 0805's, drawn in one of the ways
/// footprint authors actually draw them.
FootprintDefinition part({String name = 'R', bool lines = false}) {
  const stroke = StrokeStyle(width: 0.05);
  const layer = BoardLayer.frontCourtyard;
  const corners = [
    FootprintPoint(-1.7, -0.9),
    FootprintPoint(1.7, -0.9),
    FootprintPoint(1.7, 0.9),
    FootprintPoint(-1.7, 0.9),
  ];
  return FootprintDefinition(
    libraryNickname: 'Test',
    name: name,
    graphics: lines
        ? [
            for (var i = 0; i < 4; i++)
              FootprintLine(
                start: corners[i],
                end: corners[(i + 1) % 4],
                layer: layer,
                stroke: stroke,
              ),
          ]
        : const [
            FootprintRect(
              start: FootprintPoint(-1.7, -0.9),
              end: FootprintPoint(1.7, 0.9),
              layer: layer,
              stroke: stroke,
            ),
          ],
  );
}

PlacedFootprint placed(
  String reference,
  double x,
  double y, {
  double rotation = 0,
  bool flipped = false,
  bool lines = false,
}) {
  final ref = PlacedFootprintRef(
    id: 'fp-$reference',
    projectId: 'p',
    partId: 'part-$reference',
    libId: 'Test:R',
    x: x,
    y: y,
    rotation: rotation,
    flipped: flipped,
    placed: true,
  );
  return PlacedFootprint(
    ref: ref,
    part: Part(
      id: 'part-$reference',
      projectId: 'p',
      libId: 'Device:R',
      reference: reference,
      value: '10k',
      createdAt: DateTime(2026),
    ),
    placement: FootprintPlacement.of(ref),
    pads: const [],
    definition: part(lines: lines),
  );
}

BoardScene boardWith(List<PlacedFootprint> footprints) => BoardScene(
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
  footprints: footprints,
  pads: const [],
  tracks: const [],
  vias: const [],
  ratsnest: const [],
  unplaced: const [],
);

List<DrcViolation> overlaps(List<PlacedFootprint> footprints) =>
    courtyardViolations(
      boardWith(footprints),
    ).where((v) => v.rule == DrcRule.courtyardOverlap).toList();

void main() {
  test('two parts on top of one another cannot both be fitted', () {
    final found = overlaps([placed('R1', 10, 10), placed('R2', 11, 10)]);
    expect(found, hasLength(1));
    expect(found.single.message, contains('R1'));
    expect(found.single.message, contains('R2'));
    expect(found.single.isError, isTrue);
  });

  test(
    'parts butted edge to edge are fine — that is what courtyards are for',
    () {
      // 3.4 mm wide, 3.4 mm apart: the courtyards share an edge exactly.
      expect(overlaps([placed('R1', 10, 10), placed('R2', 13.4, 10)]), isEmpty);
    },
  );

  test('a hair apart is fine, a hair over is not', () {
    expect(overlaps([placed('R1', 10, 10), placed('R2', 13.45, 10)]), isEmpty);
    expect(
      overlaps([placed('R1', 10, 10), placed('R2', 13.35, 10)]),
      hasLength(1),
    );
  });

  test('the same spot exactly is an overlap', () {
    expect(
      overlaps([placed('R1', 10, 10), placed('R2', 10, 10)]),
      hasLength(1),
    );
  });

  test('one inside another is an overlap even with no edges crossing', () {
    // A small courtyard wholly inside a big one has no crossing edges.
    final big = PlacedFootprint(
      ref: const PlacedFootprintRef(
        id: 'fp-U1',
        projectId: 'p',
        partId: 'part-U1',
        libId: 'Test:U',
        x: 10,
        y: 10,
        placed: true,
      ),
      part: Part(
        id: 'part-U1',
        projectId: 'p',
        libId: 'x',
        reference: 'U1',
        value: '',
        createdAt: DateTime(2026),
      ),
      placement: const FootprintPlacement(x: 10, y: 10),
      pads: const [],
      definition: const FootprintDefinition(
        libraryNickname: 'Test',
        name: 'U',
        graphics: [
          FootprintRect(
            start: FootprintPoint(-6, -6),
            end: FootprintPoint(6, 6),
            layer: BoardLayer.frontCourtyard,
            stroke: StrokeStyle(width: 0.05),
          ),
        ],
      ),
    );
    expect(overlaps([big, placed('R1', 10, 10)]), hasLength(1));
  });

  test('a part on the back can sit under one on the front', () {
    expect(
      overlaps([placed('R1', 10, 10), placed('R2', 10, 10, flipped: true)]),
      isEmpty,
    );
    // …but two on the back collide as much as two on the front.
    expect(
      overlaps([
        placed('R1', 10, 10, flipped: true),
        placed('R2', 10, 10, flipped: true),
      ]),
      hasLength(1),
    );
  });

  test('turned 90°, a part is judged by its turned courtyard', () {
    // Upright, R2 is 1.8 wide; 2 mm away along x clears R1's 1.7 half.
    // R1 lies along x (half 1.7), R2 turned (half 0.9): 2.6 needed.
    expect(
      overlaps([placed('R1', 10, 10), placed('R2', 12.7, 10, rotation: 90)]),
      isEmpty,
    );
    expect(
      overlaps([placed('R1', 10, 10), placed('R2', 12.5, 10, rotation: 90)]),
      hasLength(1),
    );
  });

  test('a courtyard drawn as four lines counts the same as a rectangle', () {
    expect(
      overlaps([
        placed('R1', 10, 10, lines: true),
        placed('R2', 11, 10, lines: true),
      ]),
      hasLength(1),
    );
    expect(
      overlaps([
        placed('R1', 10, 10, lines: true),
        placed('R2', 20, 10, lines: true),
      ]),
      isEmpty,
    );
  });

  test('a part hanging off the edge is a warning, not an error', () {
    final found = courtyardViolations(
      boardWith([placed('J1', 0.5, 10)]),
    ).where((v) => v.rule == DrcRule.courtyardOffBoard).toList();
    expect(found, hasLength(1));
    expect(found.single.isError, isFalse);
    expect(courtyardViolations(boardWith([placed('R1', 20, 15)])), isEmpty);
  });

  test('the full check includes it', () {
    final all = checkBoard(
      boardWith([placed('R1', 10, 10), placed('R2', 11, 10)]),
    );
    expect(all.map((v) => v.rule), contains(DrcRule.courtyardOverlap));
  });

  test('polygon overlap: crossing, touching and apart', () {
    const a = [Offset(0, 0), Offset(2, 0), Offset(2, 2), Offset(0, 2)];
    const crossing = [Offset(1, 1), Offset(3, 1), Offset(3, 3), Offset(1, 3)];
    const touching = [Offset(2, 0), Offset(4, 0), Offset(4, 2), Offset(2, 2)];
    const apart = [Offset(5, 5), Offset(6, 5), Offset(6, 6), Offset(5, 6)];
    expect(polygonsOverlap(a, crossing), isTrue);
    expect(polygonsOverlap(a, touching), isFalse);
    expect(polygonsOverlap(a, apart), isFalse);
  });

  test('an L-shaped courtyard leaves its notch free', () {
    const l = [
      Offset(0, 0),
      Offset(4, 0),
      Offset(4, 1),
      Offset(1, 1),
      Offset(1, 4),
      Offset(0, 4),
    ];
    const inNotch = [Offset(2, 2), Offset(3, 2), Offset(3, 3), Offset(2, 3)];
    const onLeg = [Offset(2, 0.5), Offset(3, 0.5), Offset(3, 3), Offset(2, 3)];
    expect(polygonsOverlap(l, inNotch), isFalse);
    expect(polygonsOverlap(inNotch, l), isFalse);
    expect(polygonsOverlap(l, onLeg), isTrue);
  });
}
