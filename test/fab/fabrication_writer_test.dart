import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/export/pdf_writer.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/fab/gerber_reader.dart';
import 'package:zolt/fab/gerber_writer.dart';
import 'package:zolt/fab/stroke_font.dart';

Board _board() => Board(
  id: 'b',
  projectId: 'p',
  outlineX: 0,
  outlineY: 0,
  outlineWidth: 40,
  outlineHeight: 30,
  rules: const DesignRules(),
  gridMm: 0.5,
  modifiedAt: DateTime(2026),
);

/// A connector leg with an oval hole — the kind a USB-C shell or a DC jack
/// has — at [at], turned by [angle] degrees.
PlacedFootprint _slotted(Offset at, double angle, {bool plated = true}) {
  final pad = Pad(
    number: '1',
    type: plated ? PadType.thruHole : PadType.npth,
    shape: PadShape.oval,
    at: const FootprintPoint(0, 0),
    sizeX: 2.4,
    sizeY: 1.2,
    drill: 1.8,
    drillY: 0.6,
    layers: const [BoardLayer.frontCopper, BoardLayer.backCopper],
  );
  return PlacedFootprint(
    ref: PlacedFootprintRef(
      id: 'J1',
      projectId: 'p',
      partId: 'J1',
      libId: 'Test:Jack',
      x: at.dx,
      y: at.dy,
      rotation: angle,
      placed: true,
    ),
    part: Part(
      id: 'J1',
      projectId: 'p',
      libId: 'Connector:Jack',
      reference: 'J1',
      value: '',
      createdAt: DateTime(2026),
    ),
    placement: FootprintPlacement(x: at.dx, y: at.dy, rotation: angle),
    pads: [
      PlacedPad(
        pad: pad,
        partId: 'J1',
        reference: 'J1',
        footprintId: 'J1',
        position: at,
        angle: angle,
        layers: const [BoardLayer.frontCopper, BoardLayer.backCopper],
      ),
    ],
  );
}

BoardScene _scene({
  List<PlacedFootprint> footprints = const [],
  List<Track> tracks = const [],
  List<Via> vias = const [],
  List<BoardZone> zones = const [],
  List<BoardText> texts = const [],
}) => BoardScene(
  board: _board(),
  footprints: footprints,
  pads: const [],
  tracks: tracks,
  vias: vias,
  ratsnest: const [],
  unplaced: const [],
  zones: zones,
  texts: texts,
);

Map<String, String> _files(BoardScene scene) => {
  for (final f in FabricationWriter.write(scene, baseName: 'board'))
    f.name.replaceFirst('board-', ''): f.content,
};

void main() {
  test('every layer a fab expects is there, named the way KiCad names it', () {
    expect(_files(_scene()).keys, [
      'F_Cu.gbr',
      'B_Cu.gbr',
      'F_Mask.gbr',
      'B_Mask.gbr',
      'F_Paste.gbr',
      'B_Paste.gbr',
      'F_Silkscreen.gbr',
      'B_Silkscreen.gbr',
      'Edge_Cuts.gbr',
      'PTH.drl',
      'NPTH.drl',
    ]);
  });

  test('a four-layer board gets its inner copper, numbered from the top', () {
    final scene = BoardScene(
      board: _board().copyWith(copperLayerCount: 4),
      footprints: const [],
      pads: const [],
      tracks: const [
        Track(
          id: 't',
          projectId: 'p',
          layer: CopperLayer.inner1,
          startX: 5,
          startY: 5,
          endX: 15,
          endY: 5,
          width: 0.2,
        ),
      ],
      vias: const [],
      ratsnest: const [],
      unplaced: const [],
    );
    final files = _files(scene);
    expect(files.keys.take(4), [
      'F_Cu.gbr',
      'In1_Cu.gbr',
      'In2_Cu.gbr',
      'B_Cu.gbr',
    ]);
    expect(files['In1_Cu.gbr'], contains('%TF.FileFunction,Copper,L2,Inr*%'));
    expect(files['B_Cu.gbr'], contains('%TF.FileFunction,Copper,L4,Bot*%'));
    expect(files['In1_Cu.gbr'], contains('D01*'));
    expect(files['In2_Cu.gbr'], isNot(contains('D01*')));
    expect(files['F_Cu.gbr'], isNot(contains('D01*')));
  });

  test('a Gerber is well formed: header, apertures before use, end', () {
    final copper = _files(
      _scene(
        tracks: const [
          Track(
            id: 't',
            projectId: 'p',
            layer: CopperLayer.front,
            startX: 5,
            startY: 5,
            endX: 15,
            endY: 5,
            width: 0.25,
          ),
        ],
      ),
    )['F_Cu.gbr']!;
    expect(copper, contains('%FSLAX46Y46*%'));
    expect(copper, contains('%MOMM*%'));
    expect(copper, contains('%TF.FileFunction,Copper,L1,Top*%'));
    expect(copper.trimRight(), endsWith('M02*'));
    // The track: an aperture as wide as it, a move and a draw, y flipped up.
    expect(copper, contains('%ADD10C,0.250000*%'));
    expect(copper, contains('X5000000Y-5000000D02*'));
    expect(copper, contains('X15000000Y-5000000D01*'));
    expect(copper.indexOf('%ADD10'), lessThan(copper.indexOf('D10*')));
    // Only on its own layer.
    expect(_files(_scene())['B_Cu.gbr'], isNot(contains('D01*')));
  });

  test('a pour is filled, then cleared round other nets, then redrawn', () {
    final copper = _files(
      _scene(
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
            clearance: 0.3,
          ),
        ],
        tracks: const [
          Track(
            id: 'signal',
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
      ),
    )['F_Cu.gbr']!;

    final region = copper.indexOf('G36*');
    final clear = copper.indexOf('%LPC*%');
    final dark = copper.lastIndexOf('%LPD*%');
    expect(region, greaterThan(0));
    expect(clear, greaterThan(region));
    expect(dark, greaterThan(clear));
    // Cleared at the track's width plus the pour's 0.3 mm clearance on both
    // sides, the wider of it and the board's 0.2 mm rule.
    final gap = copper.substring(clear, dark);
    expect(gap, contains('X5000000Y-10000000D02*'));
    expect(copper, contains('C,0.850000'));
  });

  test('vias go in the plated drill file, in millimetres', () {
    final drill = _files(
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
    )['PTH.drl']!;
    expect(drill, startsWith('M48'));
    expect(drill, contains('METRIC'));
    expect(drill, contains('T1C0.400'));
    expect(drill, contains('X12.500Y-7.000'));
    expect(drill.trimRight(), endsWith('M30'));
    expect(_files(_scene())['NPTH.drl'], isNot(contains('X')));
  });

  group('an oval hole is routed as a slot, not drilled round', () {
    test('along its long side, with a tool its short side wide', () {
      final drill = _files(
        _scene(footprints: [_slotted(const Offset(10, 5), 0)]),
      )['PTH.drl']!;
      // 1.8 × 0.6: a 0.6 mm tool routed 1.2 mm, centred on the pad.
      expect(drill, contains('T1C0.600'));
      expect(drill, contains('X9.400Y-5.000G85X10.600Y-5.000'));
      expect(drill, isNot(contains('C1.800')));

      // And it reads back as a slot, for the preview.
      final holes = GerberReader.parseDrill(drill);
      expect(holes.single.isSlot, isTrue);
      expect(holes.single.at.dx, closeTo(9.4, 1e-9));
      expect(holes.single.to!.dx, closeTo(10.6, 1e-9));
      expect(holes.single.diameter, closeTo(0.6, 1e-9));
    });

    test('turned with its part', () {
      final drill = _files(
        _scene(footprints: [_slotted(const Offset(10, 5), 90)]),
      )['PTH.drl']!;
      // Turned a quarter, the slot runs up and down the board.
      expect(drill, contains('X10.000Y-5.600G85X10.000Y-4.400'));
    });

    test('an unplated slot goes in the unplated file', () {
      final files = _files(
        _scene(footprints: [_slotted(const Offset(10, 5), 0, plated: false)]),
      );
      expect(files['NPTH.drl'], contains('G85'));
      expect(files['PTH.drl'], isNot(contains('G85')));
    });
  });

  test('text lands on the side it was written on', () {
    final files = _files(
      _scene(
        texts: const [
          BoardText(
            id: 'f',
            projectId: 'p',
            content: 'REV A',
            position: Offset(20, 25),
          ),
        ],
      ),
    );
    expect(files['F_Silkscreen.gbr'], contains('D01*'));
    expect(files['B_Silkscreen.gbr'], isNot(contains('D01*')));
  });

  test('the board outline is a closed profile', () {
    final edge = _files(_scene())['Edge_Cuts.gbr']!;
    final draws = RegExp(r'X(-?\d+)Y(-?\d+)D0[12]\*').allMatches(edge).toList();
    expect(draws.length, greaterThanOrEqualTo(5));
    expect(
      draws.first.group(0)!.replaceFirst('D02', 'D01'),
      draws.last.group(0),
    );
  });

  group('stroke font', () {
    test('text is centred on its position and scales with its height', () {
      final strokes = StrokeFont.strokes(
        'R1',
        centre: const Offset(10, 10),
        height: 1.2,
      );
      final all = [for (final s in strokes) ...s];
      final minX = all.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = all.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = all.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = all.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      expect((minX + maxX) / 2, closeTo(10, 0.15));
      expect(maxY - minY, closeTo(1.2, 1e-6));
    });

    test('mirrored text for the back reads backwards', () {
      final front = StrokeFont.strokes('L', centre: Offset.zero, height: 6);
      final back = StrokeFont.strokes(
        'L',
        centre: Offset.zero,
        height: 6,
        mirror: true,
      );
      expect(back.first.last.dx, closeTo(-front.first.last.dx, 1e-9));
    });
  });

  test('a raster PDF has a valid cross-reference table', () {
    final pdf = RasterPdf.single(
      pixelWidth: 2,
      pixelHeight: 2,
      rgb: Uint8List.fromList(List.filled(12, 255)),
      widthPt: 842,
      heightPt: 595,
      title: 'Test (A)',
    );
    final text = latin1.decode(pdf);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/Subtype /Image'));
    expect(text.trimRight(), endsWith('%%EOF'));

    final startxref = int.parse(
      RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!,
    );
    expect(text.substring(startxref, startxref + 4), 'xref');
    // Each object offset in the table really is where that object starts.
    final offsets = RegExp(r'(\d{10}) 00000 n').allMatches(text).toList();
    expect(offsets, hasLength(6));
    for (var i = 0; i < offsets.length; i++) {
      final at = int.parse(offsets[i].group(1)!);
      expect(
        text.substring(at, at + '${i + 1} 0 obj'.length),
        '${i + 1} 0 obj',
      );
    }
  });
}
