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
    FabricationFile('$baseName-F_Cu.gbr', _copper(scene, CopperLayer.front)),
    FabricationFile('$baseName-B_Cu.gbr', _copper(scene, CopperLayer.back)),
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
        if (!footprint.part.dnp)
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

  static String _copper(BoardScene scene, CopperLayer layer) {
    final g = _Gerber(
      layer == CopperLayer.front ? 'Copper,L1,Top' : 'Copper,L2,Bot',
    );
    final pads = [
      for (final footprint in scene.footprints)
        for (final pad in footprint.pads)
          if (pad.reaches(layer)) pad,
    ];
    final tracks = [
      for (final track in scene.tracks)
        if (track.layer == layer) track,
    ];
    final zones = [
      for (final zone in scene.zones)
        if (zone.isValid && zone.layer == layer.layer) zone,
    ];

    if (zones.isNotEmpty) {
      for (final zone in zones) {
        g.region(zone.points);
      }

      g.clear();
      // The zones an item sits in, and whether any of them is another net.
      (bool, double) clearFor(String? netId, Rect box) {
        final over = [
          for (final zone in zones)
            if (zone.bounds.overlaps(box)) zone,
        ];
        if (over.isEmpty) return (false, 0);
        final foreign = netId == null || over.any((z) => z.netId != netId);
        final gap = [
          scene.clearanceFor(netId),
          for (final zone in over) zone.clearance,
        ].reduce(math.max);
        return (foreign, gap);
      }

      for (final track in tracks) {
        final a = Offset(track.startX, track.startY);
        final b = Offset(track.endX, track.endY);
        final (foreign, gap) = clearFor(
          track.netId,
          Rect.fromPoints(a, b).inflate(track.width),
        );
        if (foreign) g.stroke([a, b], track.width + gap * 2);
      }
      for (final via in scene.vias) {
        final at = Offset(via.x, via.y);
        final (foreign, gap) = clearFor(
          via.netId,
          Rect.fromCircle(center: at, radius: via.diameter),
        );
        if (foreign) g.flashCircle(at, via.diameter + gap * 2);
      }
      for (final pad in pads) {
        final (foreign, gap) = clearFor(
          pad.netId,
          Rect.fromCircle(
            center: pad.position,
            radius: math.max(pad.pad.sizeX, pad.pad.sizeY),
          ),
        );
        if (foreign) _pad(g, pad, gap);
      }
      g.dark();
    }

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
      g.flashCircle(Offset(via.x, via.y), via.diameter);
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

  static String _mask(BoardScene scene, {required bool front}) {
    final g = _Gerber(front ? 'Soldermask,Top' : 'Soldermask,Bot');
    final side = front ? CopperLayer.front : CopperLayer.back;
    final mask = front ? BoardLayer.frontMask : BoardLayer.backMask;
    for (final footprint in scene.footprints) {
      for (final pad in footprint.pads) {
        final layers = [
          for (final layer in pad.pad.layers)
            footprint.placement.layerOf(layer),
        ];
        final opens =
            layers.contains(mask) ||
            (pad.pad.type.spansLayers && pad.reaches(side));
        if (opens) _pad(g, pad, 0);
      }
    }
    return g.build();
  }

  static String _paste(BoardScene scene, {required bool front}) {
    final g = _Gerber(front ? 'Paste,Top' : 'Paste,Bot');
    final paste = front ? BoardLayer.frontPaste : BoardLayer.backPaste;
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
    return g.build();
  }

  // --- silkscreen ------------------------------------------------------

  static String _silk(BoardScene scene, {required bool front}) {
    final g = _Gerber(front ? 'Legend,Top' : 'Legend,Bot');
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
    return g.build();
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

  static String _edges(BoardScene scene) {
    final g = _Gerber('Profile,NP');
    const width = 0.05;
    g.stroke(scene.outline.path, width, close: true);
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      for (final metric in edge.path.computeMetrics()) {
        final steps = math.max(1, (metric.length / 0.2).ceil());
        final points = [
          for (var i = 0; i <= steps; i++)
            metric.getTangentForOffset(metric.length * i / steps)!.position,
        ];
        g.stroke(points, width, close: metric.isClosed);
      }
    }
    return g.build();
  }

  // --- drill -----------------------------------------------------------

  static String _drill(BoardScene scene, {required bool plated}) {
    final holes = <(Offset, double)>[
      if (plated)
        for (final via in scene.vias)
          if (via.drill > 0) (Offset(via.x, via.y), via.drill),
      for (final footprint in scene.footprints)
        for (final pad in footprint.pads)
          if (pad.pad.drill > 0 &&
              (plated
                  ? pad.pad.type == PadType.thruHole
                  : pad.pad.type == PadType.npth))
            (pad.position, pad.pad.drill),
    ];

    double tool(double d) => (d * 1000).round() / 1000;
    final sizes = {for (final hole in holes) tool(hole.$2)}.toList()..sort();

    final out = StringBuffer()
      ..writeln('M48')
      ..writeln(
        '; DRILL file {HintPCB} ${plated ? 'plated' : 'non-plated'} holes',
      )
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
      for (final hole in holes) {
        if (tool(hole.$2) != sizes[i]) continue;
        out.writeln(
          'X${hole.$1.dx.toStringAsFixed(3)}'
          'Y${(-hole.$1.dy).toStringAsFixed(3)}',
        );
      }
    }
    out
      ..writeln('T0')
      ..writeln('M30');
    return out.toString();
  }
}

/// One Gerber layer being written.
class _Gerber {
  _Gerber(this.function);

  final String function;
  final _apertures = <String, int>{};
  final _body = StringBuffer();
  int? _selected;

  static String _mm(double value) => value.toStringAsFixed(6);

  /// Board millimetres, y down, to Gerber's micrometre integers, y up.
  static String _xy(Offset p) =>
      'X${(p.dx * 1e6).round()}Y${(-p.dy * 1e6).round()}';

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
      ..writeln('%TF.GenerationSoftware,HintPCB,HintPCB,1.0*%')
      ..writeln('%TF.FileFunction,$function*%')
      ..writeln('%FSLAX46Y46*%')
      ..writeln('%MOMM*%')
      ..writeln('%LPD*%')
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
