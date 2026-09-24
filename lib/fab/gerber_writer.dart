import 'dart:math' as math;
import 'dart:ui';

import '../domain/pcb/pcb.dart';
import '../domain/symbols/symbols.dart' show FillType;
import 'stroke_font.dart';

/// One file of a fabrication set.
class FabricationFile {
  const FabricationFile(this.name, this.content);

  final String name;
  final String content;
}

/// Writes the Gerber and drill files a board house makes a board from.
///
/// RS-274X with X2 file attributes, one file per layer, named the way KiCad
/// names them so a fab's upload page recognises each without being told.
///
/// Copper pours are filled here rather than left for someone else to fill,
/// using the format's own polarity: the pour is drawn solid, every piece of
/// copper on another net is then cleared out of it grown by the clearance,
/// and all the copper is drawn again on top. That gives a pour with the
/// right gaps without any polygon arithmetic — and without thermal
/// reliefs, which a pour made this way does not have.
abstract final class FabricationWriter {
  static List<FabricationFile> write(
    BoardScene scene, {
    required String baseName,
  }) => [
    // Top to bottom, inner layers included: `In1_Cu` is the name every
    // fab's upload page expects for the first one down.
    for (final layer in scene.board.copperLayers)
      FabricationFile(
        '$baseName-${layer.layer.token.replaceAll('.', '_')}.gbr',
        _copper(scene, layer),
      ),
    FabricationFile('$baseName-F_Mask.gbr', _mask(scene, front: true)),
    FabricationFile('$baseName-B_Mask.gbr', _mask(scene, front: false)),
    FabricationFile('$baseName-F_Paste.gbr', _paste(scene, front: true)),
    FabricationFile('$baseName-B_Paste.gbr', _paste(scene, front: false)),
    FabricationFile('$baseName-F_Silkscreen.gbr', _silk(scene, front: true)),
    FabricationFile('$baseName-B_Silkscreen.gbr', _silk(scene, front: false)),
    FabricationFile('$baseName-Edge_Cuts.gbr', _edges(scene)),
    FabricationFile('$baseName-PTH.drl', _drill(scene, plated: true)),
    FabricationFile('$baseName-NPTH.drl', _drill(scene, plated: false)),
  ];

  /// The same set for a panel of copies of the board: every layer with each
  /// copy in its place, the panel's milled edge, its unplated holes (tooling
  /// holes and the perforation) added to the board's, fiducials on the
  /// outer copper and mask, V-score lines in a file of their own, and a
  /// note that says in words what the files say in coordinates.
  static List<FabricationFile> writePanel(
    BoardScene scene,
    PanelLayout panel, {
    required String baseName,
    String title = '',
  }) {
    final copies = panel.copies;
    return [
      for (final layer in scene.board.copperLayers)
        FabricationFile(
          '$baseName-${layer.layer.token.replaceAll('.', '_')}.gbr',
          _copper(scene, layer, copies: copies, panel: panel),
        ),
      FabricationFile(
        '$baseName-F_Mask.gbr',
        _mask(scene, front: true, copies: copies, panel: panel),
      ),
      FabricationFile(
        '$baseName-B_Mask.gbr',
        _mask(scene, front: false, copies: copies, panel: panel),
      ),
      FabricationFile(
        '$baseName-F_Paste.gbr',
        _paste(scene, front: true, copies: copies),
      ),
      FabricationFile(
        '$baseName-B_Paste.gbr',
        _paste(scene, front: false, copies: copies),
      ),
      FabricationFile(
        '$baseName-F_Silkscreen.gbr',
        _silk(scene, front: true, copies: copies, panel: panel, title: title),
      ),
      FabricationFile(
        '$baseName-B_Silkscreen.gbr',
        _silk(scene, front: false, copies: copies),
      ),
      FabricationFile('$baseName-Edge_Cuts.gbr', _panelEdges(scene, panel)),
      FabricationFile(
        '$baseName-PTH.drl',
        _drill(scene, plated: true, copies: copies),
      ),
      FabricationFile(
        '$baseName-NPTH.drl',
        _drill(scene, plated: false, copies: copies, panel: panel),
      ),
      if (panel.vScores.isNotEmpty)
        FabricationFile('$baseName-V_Score.gbr', _vScores(panel)),
      FabricationFile('$baseName-panel.txt', _panelNotes(panel, title)),
    ];
  }

  static String _vScores(PanelLayout panel) {
    final g = _Gerber('Other,V-Score');
    for (final (a, b) in panel.vScores) {
      g.stroke([a, b], 0.1);
    }
    return g.build();
  }

  static String _panelNotes(PanelLayout panel, String title) {
    String mm(double v) => v.toStringAsFixed(2);
    String at(Offset p) => '(${mm(p.dx)}, ${mm(-p.dy)})';
    final s = panel.settings;
    final rows = panel.copies.isEmpty
        ? 0
        : panel.boardBounds.map((b) => b.top).toSet().length;
    final columns = rows == 0 ? 0 : panel.copies.length ~/ rows;
    final out = StringBuffer()
      ..writeln('Panel${title.isEmpty ? '' : ': $title'}')
      ..writeln('Size: ${mm(panel.panel.width)} x ${mm(panel.panel.height)} mm')
      ..writeln(
        'Boards: ${panel.copies.length} ($rows rows x $columns columns), '
        'each ${mm(panel.boardBounds.first.width)} x '
        '${mm(panel.boardBounds.first.height)} mm',
      )
      ..writeln('Joined by: ${panel.join.label}');
    if (panel.join == PanelJoin.mouseBites) {
      out
        ..writeln(
          'Milled gap: ${mm(math.max(s.spacing, PanelSettings.minSpacing))} mm',
        )
        ..writeln(
          'Tabs: ${panel.tabs.length}, perforated with '
          '${panel.biteHoles.length} holes of '
          '${mm(PanelSettings.biteDiameter)} mm (in the NPTH drill file)',
        );
    } else {
      out.writeln(
        'V-score lines (in the V_Score file; cut both sides, edge to edge):',
      );
      for (final (a, b) in panel.vScores) {
        out.writeln('  ${at(a)} to ${at(b)}');
      }
    }
    out.writeln('Rails: ${s.rails.label}');
    if (panel.fiducials.isNotEmpty) {
      out.writeln(
        'Fiducials (${mm(PanelSettings.fiducialCopper)} mm copper, '
        '${mm(PanelSettings.fiducialMask)} mm mask opening, both sides): '
        '${panel.fiducials.map(at).join(', ')}',
      );
    }
    if (panel.toolingHoles.isNotEmpty) {
      out.writeln(
        'Tooling holes (${mm(panel.toolingDiameter)} mm, unplated): '
        '${panel.toolingHoles.map(at).join(', ')}',
      );
    }
    out.writeln(
      'Coordinates in millimetres from the panel\'s top-left '
      'corner, y up as the Gerbers have it.',
    );
    return out.toString();
  }

  /// Where each part goes, for pick-and-place assembly: the columns an
  /// assembly service asks for, in millimetres, with y up as the Gerbers
  /// have it.
  static FabricationFile positions(
    BoardScene scene, {
    required String baseName,
  }) {
    String cell(String value) => value.contains(',') || value.contains('"')
        ? '"${value.replaceAll('"', '""')}"'
        : value;
    final rows = [
      'Designator,Val,Package,Mid X,Mid Y,Rotation,Layer',
      for (final footprint in scene.footprints)
        // Holes, fiducials and test points are not placed by a machine.
        if (!footprint.part.dnp && !BoardFeature.isFeatureId(footprint.ref.id))
          [
            cell(footprint.part.reference),
            cell(footprint.part.value),
            cell(footprint.ref.libId.split(':').last),
            footprint.ref.x.toStringAsFixed(4),
            (-footprint.ref.y).toStringAsFixed(4),
            footprint.ref.rotation.toStringAsFixed(1),
            footprint.ref.flipped ? 'bottom' : 'top',
          ].join(','),
    ];
    return FabricationFile('$baseName-pos.csv', '${rows.join('\n')}\n');
  }

  // --- copper ----------------------------------------------------------

  static String _copper(
    BoardScene scene,
    CopperLayer layer, {
    List<Offset> copies = const [Offset.zero],
    PanelLayout? panel,
  }) {
    final g = _Gerber(layer.fileFunction(scene.board.copperLayerCount));
    // An unplated hole lists copper layers so pours keep clear of it, and
    // has no copper of its own.
    final pads = [
      for (final footprint in scene.footprints)
        for (final pad in footprint.pads)
          if (pad.reaches(layer) && pad.pad.type != PadType.npth) pad,
    ];
    final tracks = [
      for (final track in scene.tracks)
        if (track.layer == layer) track,
    ];
    // The pours, filled round everything else exactly as the board editor
    // shows them.
    // In a panel, every copy's pour first and all the copper after: a
    // clear at one copy's edge then never eats into the next copy's pads.
    final pour = PourFill.plan(scene, layer);
    for (final copy in copies) {
      g.shift = copy;
      for (final step in pour.steps) {
        step.clear ? g.clear() : g.dark();
        switch (step.shape) {
          case PourRegion(:final points, :final hole):
            hole == null ? g.region(points) : g.regionWithHole(points, hole);
          case PourStroke(:final points, :final width, :final closed):
            g.stroke(points, width, close: closed);
          case PourPad(:final pad, :final grow):
            _pad(g, pad, grow);
          case PourDisc(:final centre, :final diameter):
            g.flashCircle(centre, diameter);
        }
      }
    }
    if (!pour.isEmpty) g.dark();

    for (final copy in copies) {
      g.shift = copy;
      for (final pad in pads) {
        _pad(g, pad, 0);
      }
      for (final track in tracks) {
        g.stroke([
          Offset(track.startX, track.startY),
          Offset(track.endX, track.endY),
        ], track.width);
      }
      for (final via in scene.vias) {
        if (!via.layersOn(scene.board).contains(layer)) continue;
        g.flashCircle(Offset(via.x, via.y), via.diameter);
      }
      // Last, so a fillet is drawn over the track and the pad it joins
      // rather than under either.
      for (final drop in Teardrops.of(scene, layer)) {
        g.region(drop.points);
      }
    }
    g.shift = Offset.zero;
    if (panel != null && !layer.isInner) {
      for (final at in panel.fiducials) {
        g.flashCircle(at, PanelSettings.fiducialCopper);
      }
    }
    return g.build();
  }

  /// A pad's copper, grown by [grow] on every side.
  static void _pad(_Gerber g, PlacedPad pad, double grow) {
    final radians = pad.angle * math.pi / 180;
    // The pad's own axes on the board, y down: the same convention the
    // canvas draws with.
    final ux = Offset(math.cos(radians), -math.sin(radians));
    final uy = Offset(math.sin(radians), math.cos(radians));
    final w = pad.pad.sizeX + grow * 2;
    final h = pad.pad.sizeY + grow * 2;
    final centre = pad.position;
    Offset at(double lx, double ly) => centre + ux * lx + uy * ly;

    switch (pad.pad.shape) {
      case PadShape.circle:
        g.flashCircle(centre, w);
      case PadShape.oval:
        if ((w - h).abs() < 1e-6) {
          g.flashCircle(centre, w);
        } else {
          final short = math.min(w, h);
          final reach = (math.max(w, h) - short) / 2;
          final along = w >= h ? ux : uy;
          g.stroke([centre - along * reach, centre + along * reach], short);
        }
      case PadShape.roundrect:
        final radius =
            math.min(pad.pad.sizeX, pad.pad.sizeY) * pad.pad.roundrectRatio +
            grow;
        g.region(_roundedRect(at, w, h, radius));
      case PadShape.rect || PadShape.trapezoid || PadShape.custom:
        g.region([
          at(-w / 2, -h / 2),
          at(w / 2, -h / 2),
          at(w / 2, h / 2),
          at(-w / 2, h / 2),
        ]);
    }
  }

  static List<Offset> _roundedRect(
    Offset Function(double, double) at,
    double w,
    double h,
    double radius,
  ) {
    final r = radius.clamp(0.0, math.min(w, h) / 2);
    if (r < 1e-6) {
      return [
        at(-w / 2, -h / 2),
        at(w / 2, -h / 2),
        at(w / 2, h / 2),
        at(-w / 2, h / 2),
      ];
    }
    final points = <Offset>[];
    const steps = 6;
    for (final (cx, cy, start) in [
      (w / 2 - r, -h / 2 + r, -math.pi / 2),
      (w / 2 - r, h / 2 - r, 0.0),
      (-w / 2 + r, h / 2 - r, math.pi / 2),
      (-w / 2 + r, -h / 2 + r, math.pi),
    ]) {
      for (var i = 0; i <= steps; i++) {
        final a = start + (math.pi / 2) * i / steps;
        points.add(at(cx + r * math.cos(a), cy + r * math.sin(a)));
      }
    }
    return points;
  }

  // --- mask and paste --------------------------------------------------

  static String _mask(
    BoardScene scene, {
    required bool front,
    List<Offset> copies = const [Offset.zero],
    PanelLayout? panel,
  }) {
    final g = _Gerber(front ? 'Soldermask,Top' : 'Soldermask,Bot');
    final side = front ? CopperLayer.front : CopperLayer.back;
    final mask = front ? BoardLayer.frontMask : BoardLayer.backMask;
    for (final copy in copies) {
      g.shift = copy;
      for (final footprint in scene.footprints) {
        for (final pad in footprint.pads) {
          final layers = [
            for (final layer in pad.pad.layers)
              footprint.placement.layerOf(layer),
          ];
          final opens =
              layers.contains(mask) ||
              (pad.pad.type.spansLayers && pad.reaches(side));
          if (opens) _pad(g, pad, pad.pad.maskMargin);
        }
      }
    }
    g.shift = Offset.zero;
    for (final at in panel?.fiducials ?? const <Offset>[]) {
      g.flashCircle(at, PanelSettings.fiducialMask);
    }
    return g.build();
  }

  static String _paste(
    BoardScene scene, {
    required bool front,
    List<Offset> copies = const [Offset.zero],
  }) {
    final g = _Gerber(front ? 'Paste,Top' : 'Paste,Bot');
    final paste = front ? BoardLayer.frontPaste : BoardLayer.backPaste;
    for (final copy in copies) {
      g.shift = copy;
      for (final footprint in scene.footprints) {
        for (final pad in footprint.pads) {
          if (pad.pad.type != PadType.smd) continue;
          final layers = [
            for (final layer in pad.pad.layers)
              footprint.placement.layerOf(layer),
          ];
          if (layers.contains(paste)) _pad(g, pad, 0);
        }
      }
    }
    return g.build();
  }

  // --- silkscreen ------------------------------------------------------

  static String _silk(
    BoardScene scene, {
    required bool front,
    List<Offset> copies = const [Offset.zero],
    PanelLayout? panel,
    String? title,
  }) {
    final g = _Gerber(front ? 'Legend,Top' : 'Legend,Bot');
    for (final copy in copies) {
      g.shift = copy;
      _silkOf(g, scene, front: front);
    }
    g.shift = Offset.zero;
    final labelAt = panel?.labelAt;
    if (front && labelAt != null && title != null && title.isNotEmpty) {
      // Smaller for a long name, down to what a fab still prints legibly.
      final height = math.min(
        panel!.labelHeight,
        panel.labelRoom / StrokeFont.widthOf(title, 1),
      );
      if (height >= 1.0) {
        for (final stroke in StrokeFont.strokes(
          title,
          centre: labelAt,
          height: height,
        )) {
          g.stroke(stroke, StrokeFont.strokeWidth(height));
        }
      }
    }
    return g.build();
  }

  static void _silkOf(_Gerber g, BoardScene scene, {required bool front}) {
    final silk = front ? BoardLayer.frontSilk : BoardLayer.backSilk;

    for (final footprint in scene.footprints) {
      final definition = footprint.definition;
      if (definition != null) {
        for (final graphic in definition.graphics) {
          if (footprint.placement.layerOf(graphic.layer) != silk) continue;
          final width = graphic.stroke.width <= 0 ? 0.12 : graphic.stroke.width;
          Offset at(FootprintPoint p) => footprint.placement.applyPoint(p);

          switch (graphic) {
            case FootprintLine(:final start, :final end):
              g.stroke([at(start), at(end)], width);
            case FootprintRect(:final start, :final end, :final fill):
              final corners = [
                at(start),
                at(FootprintPoint(end.x, start.y)),
                at(end),
                at(FootprintPoint(start.x, end.y)),
              ];
              if (fill != FillType.none) g.region(corners);
              g.stroke(corners, width, close: true);
            case FootprintCircle(:final center, :final fill):
              final c = at(center);
              final circle = [
                for (var i = 0; i < 36; i++)
                  c +
                      Offset(
                        graphic.radius * math.cos(i * math.pi / 18),
                        graphic.radius * math.sin(i * math.pi / 18),
                      ),
              ];
              if (fill != FillType.none) g.region(circle);
              g.stroke(circle, width, close: true);
            case FootprintArc(:final start, :final mid, :final end):
              g.stroke(_arc(at(start), at(mid), at(end)), width);
            case FootprintPolygon(:final points, :final fill):
              final placed = [for (final p in points) at(p)];
              if (fill != FillType.none) g.region(placed);
              g.stroke(placed, width, close: true);
          }
        }
      }

      final onThisSide = footprint.ref.flipped != front;
      if (onThisSide && !footprint.ref.labelHidden) {
        final height = footprint.ref.labelSize;
        for (final stroke in StrokeFont.strokes(
          footprint.part.reference,
          centre: footprint.labelPosition,
          height: height,
          mirror: !front,
        )) {
          g.stroke(stroke, StrokeFont.strokeWidth(height));
        }
      }
    }

    for (final text in scene.texts) {
      if (text.back == front) continue;
      for (final stroke in StrokeFont.strokes(
        text.content,
        centre: text.position,
        height: text.size,
        rotation: text.rotation,
        mirror: text.back,
      )) {
        g.stroke(stroke, StrokeFont.strokeWidth(text.size));
      }
    }
  }

  /// Corners along the arc from [a] through [m] to [b].
  static List<Offset> _arc(Offset a, Offset m, Offset b) {
    final d =
        2 *
        (a.dx * (m.dy - b.dy) + m.dx * (b.dy - a.dy) + b.dx * (a.dy - m.dy));
    if (d.abs() < 1e-9) return [a, b];
    final a2 = a.dx * a.dx + a.dy * a.dy;
    final m2 = m.dx * m.dx + m.dy * m.dy;
    final b2 = b.dx * b.dx + b.dy * b.dy;
    final centre = Offset(
      (a2 * (m.dy - b.dy) + m2 * (b.dy - a.dy) + b2 * (a.dy - m.dy)) / d,
      (a2 * (b.dx - m.dx) + m2 * (a.dx - b.dx) + b2 * (m.dx - a.dx)) / d,
    );
    final r = (a - centre).distance;
    double angle(Offset p) => math.atan2(p.dy - centre.dy, p.dx - centre.dx);
    final a0 = angle(a);
    var sweep = angle(b) - a0;
    var toMid = angle(m) - a0;
    while (sweep < 0) {
      sweep += math.pi * 2;
    }
    while (toMid < 0) {
      toMid += math.pi * 2;
    }
    // Counter-clockwise from a reaches b before m: the arc goes the other way.
    if (toMid > sweep) sweep -= math.pi * 2;
    final steps = math.max(4, (sweep.abs() * r / 0.2).ceil());
    return [
      for (var i = 0; i <= steps; i++)
        centre +
            Offset(
              r * math.cos(a0 + sweep * i / steps),
              r * math.sin(a0 + sweep * i / steps),
            ),
    ];
  }

  // --- board edge ------------------------------------------------------

  /// The board's profile. Curves go out as real arcs (G02/G03), so a
  /// round board or a rounded corner is milled round, not as the flats
  /// the screen approximates it with.
  static String _edges(BoardScene scene) {
    final g = _Gerber('Profile,NP');
    final outline = scene.outline;
    if (outline.kind == BoardOutlineKind.circle) {
      g.circle(outline.center, outline.radius, _edgeWidth);
    } else {
      g.stroke(outline.path, _edgeWidth, close: true);
    }
    _cutouts(g, scene);
    return g.build();
  }

  static const _edgeWidth = 0.05;

  /// A panel's edge: what the layout mills round and between the copies,
  /// and each copy's own cutouts.
  static String _panelEdges(BoardScene scene, PanelLayout panel) {
    final g = _Gerber('Profile,NP');
    for (final run in panel.edgeCuts) {
      g.stroke(run, _edgeWidth);
    }
    for (final copy in panel.copies) {
      g.shift = copy;
      _cutouts(g, scene);
    }
    return g.build();
  }

  static void _cutouts(_Gerber g, BoardScene scene) {
    const width = _edgeWidth;
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      switch (edge.kind) {
        case BoardEdgeKind.line:
          g.stroke([edge.start, edge.end], width);
        case BoardEdgeKind.rectangle:
          final r = Rect.fromPoints(edge.points[0], edge.points[1]);
          g.stroke(
            [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft],
            width,
            close: true,
          );
        case BoardEdgeKind.polygon:
          g.stroke(edge.points, width, close: true);
        case BoardEdgeKind.circle:
          g.circle(edge.center, edge.radius, width);
        case BoardEdgeKind.arc:
          final centre = BoardEdge.circumcentre(edge.start, edge.mid, edge.end);
          if (centre == null) {
            // Three points in a line: the arc is its chord.
            g.stroke([edge.start, edge.end], width);
          } else {
            g.arc(
              edge.start,
              edge.end,
              centre,
              width,
              clockwise:
                  _sweepThrough(edge.start, edge.mid, edge.end, centre) > 0,
            );
          }
      }
    }
  }

  /// The signed angle from [a] to [b] around [centre], going the way that
  /// passes [m]. Positive is clockwise as the board is seen (y down).
  static double _sweepThrough(Offset a, Offset m, Offset b, Offset centre) {
    double angle(Offset p) => math.atan2(p.dy - centre.dy, p.dx - centre.dx);
    final a0 = angle(a);
    var sweep = angle(b) - a0;
    var toMid = angle(m) - a0;
    while (sweep < 0) {
      sweep += math.pi * 2;
    }
    while (toMid < 0) {
      toMid += math.pi * 2;
    }
    if (toMid > sweep) sweep -= math.pi * 2;
    return sweep;
  }

  // --- drill -----------------------------------------------------------

  static String _drill(
    BoardScene scene, {
    required bool plated,
    List<Offset> copies = const [Offset.zero],
    PanelLayout? panel,
  }) {
    // A hole is drilled at one point; a slot is routed from one point to
    // another with a tool as wide as the slot.
    final holes = <(Offset, double, Offset?)>[
      for (final copy in copies) ...[
        if (plated)
          for (final via in scene.vias)
            if (via.drill > 0) (Offset(via.x, via.y) + copy, via.drill, null),
        for (final footprint in scene.footprints)
          for (final pad in footprint.pads)
            if (pad.pad.drill > 0 &&
                (plated
                    ? pad.pad.type == PadType.thruHole
                    : pad.pad.type == PadType.npth))
              _hole(pad, copy),
      ],
      if (!plated && panel != null) ...[
        for (final at in panel.toolingHoles) (at, panel.toolingDiameter, null),
        for (final at in panel.biteHoles)
          (at, PanelSettings.biteDiameter, null),
      ],
    ];

    double tool(double d) => (d * 1000).round() / 1000;
    final sizes = {for (final hole in holes) tool(hole.$2)}.toList()..sort();

    final out = StringBuffer()
      ..writeln('M48')
      ..writeln('; DRILL file {Zolt} ${plated ? 'plated' : 'non-plated'} holes')
      ..writeln('; FORMAT={-:-/ absolute / metric / decimal}')
      ..writeln(
        '; #@! TF.FileFunction,${plated ? 'Plated' : 'NonPlated'},1,2,'
        '${plated ? 'PTH' : 'NPTH'}',
      )
      ..writeln('FMAT,2')
      ..writeln('METRIC');
    for (var i = 0; i < sizes.length; i++) {
      out.writeln('T${i + 1}C${sizes[i].toStringAsFixed(3)}');
    }
    out
      ..writeln('%')
      ..writeln('G90')
      ..writeln('G05');
    for (var i = 0; i < sizes.length; i++) {
      out.writeln('T${i + 1}');
      for (final (at, size, to) in holes) {
        if (tool(size) != sizes[i]) continue;
        String xy(Offset p) =>
            'X${p.dx.toStringAsFixed(3)}Y${(-p.dy).toStringAsFixed(3)}';
        // G85 is the routed slot every board house reads, and what KiCad
        // writes: the tool plunges at the first point and routes to the
        // second.
        out.writeln(to == null ? xy(at) : '${xy(at)}G85${xy(to)}');
      }
    }
    out
      ..writeln('T0')
      ..writeln('M30');
    return out.toString();
  }

  /// A pad's hole: a plain drill, or — for an oval hole, the kind USB-C
  /// shells and DC jacks have — a slot along the hole's long side, routed
  /// with a tool as wide as its short side.
  static (Offset, double, Offset?) _hole(PlacedPad pad, Offset copy) {
    final centre = pad.position + copy;
    final dx = pad.pad.drill;
    final dy = pad.pad.drillY > 0 ? pad.pad.drillY : dx;
    if ((dx - dy).abs() < 1e-6) return (centre, dx, null);

    // The pad's own axes on the board, as its copper is drawn.
    final radians = pad.angle * math.pi / 180;
    final along = dx > dy
        ? Offset(math.cos(radians), -math.sin(radians))
        : Offset(math.sin(radians), math.cos(radians));
    final width = math.min(dx, dy);
    final reach = (math.max(dx, dy) - width) / 2;
    return (centre - along * reach, width, centre + along * reach);
  }
}

/// One Gerber layer being written.
class _Gerber {
  _Gerber(this.function);

  final String function;
  final _apertures = <String, int>{};
  final _body = StringBuffer();
  int? _selected;

  /// Added to everything drawn: where the copy being written sits in a
  /// panel.
  Offset shift = Offset.zero;

  static String _mm(double value) => value.toStringAsFixed(6);

  /// Board millimetres, y down, to Gerber's micrometre integers, y up.
  String _xy(Offset p) =>
      'X${((p.dx + shift.dx) * 1e6).round()}Y${(-(p.dy + shift.dy) * 1e6).round()}';

  void _use(String definition) {
    final code = _apertures.putIfAbsent(
      definition,
      () => 10 + _apertures.length,
    );
    if (_selected != code) {
      _body.writeln('D$code*');
      _selected = code;
    }
  }

  void dark() => _body.writeln('%LPD*%');
  void clear() => _body.writeln('%LPC*%');

  void flashCircle(Offset at, double diameter) {
    if (diameter <= 0) return;
    _use('C,${_mm(diameter)}');
    _body.writeln('${_xy(at)}D03*');
  }

  void stroke(List<Offset> points, double width, {bool close = false}) {
    if (points.length < 2) return;
    _use('C,${_mm(math.max(width, 0.01))}');
    _body.writeln('${_xy(points.first)}D02*');
    for (final point in points.skip(1)) {
      _body.writeln('${_xy(point)}D01*');
    }
    if (close) _body.writeln('${_xy(points.first)}D01*');
  }

  /// An arc from [start] to [end] around [centre]. [clockwise] as the
  /// board is seen; Gerber's y runs up, which keeps what looks clockwise
  /// clockwise (G02).
  void arc(
    Offset start,
    Offset end,
    Offset centre,
    double width, {
    required bool clockwise,
  }) {
    _use('C,${_mm(math.max(width, 0.01))}');
    final i = ((centre.dx - start.dx) * 1e6).round();
    final j = (-(centre.dy - start.dy) * 1e6).round();
    _body
      ..writeln('${_xy(start)}D02*')
      ..writeln('${clockwise ? 'G02' : 'G03'}*')
      ..writeln('${_xy(end)}I${i}J${j}D01*')
      ..writeln('G01*');
  }

  /// A whole circle: an arc that ends where it starts.
  void circle(Offset centre, double radius, double width) {
    if (radius <= 0) return;
    final start = centre + Offset(radius, 0);
    arc(start, start, centre, width, clockwise: true);
  }

  /// A region with a hole in it, joined by a cut-in: round the outside,
  /// in to the hole, round the hole the other way, and back out along the
  /// same line. Gerber's own way of saying "this, but not that".
  void regionWithHole(List<Offset> outer, List<Offset> hole) {
    if (outer.length < 3 || hole.length < 3) return region(outer);
    double area(List<Offset> p) {
      var sum = 0.0;
      for (var i = 0; i < p.length; i++) {
        final a = p[i];
        final b = p[(i + 1) % p.length];
        sum += a.dx * b.dy - b.dx * a.dy;
      }
      return sum;
    }

    // The hole turns the other way round from the outside.
    final inner = (area(outer) > 0) == (area(hole) > 0)
        ? hole.reversed.toList()
        : hole;
    region([...outer, outer.first, ...inner, inner.first]);
  }

  void region(List<Offset> points) {
    if (points.length < 3) return;
    _body
      ..writeln('G36*')
      ..writeln('${_xy(points.first)}D02*');
    for (final point in points.skip(1)) {
      _body.writeln('${_xy(point)}D01*');
    }
    _body
      ..writeln('${_xy(points.first)}D01*')
      ..writeln('G37*');
  }

  String build() {
    final out = StringBuffer()
      ..writeln('%TF.GenerationSoftware,Zolt,Zolt,1.0*%')
      ..writeln('%TF.FileFunction,$function*%')
      ..writeln('%FSLAX46Y46*%')
      ..writeln('%MOMM*%')
      ..writeln('%LPD*%')
      // Multi-quadrant arcs: an arc may sweep any angle, a whole circle
      // included.
      ..writeln('G75*')
      ..writeln('G01*');
    for (final entry in _apertures.entries) {
      out.writeln('%ADD${entry.value}${entry.key}*%');
    }
    out
      ..write(_body)
      ..writeln('M02*');
    return out.toString();
  }
}
