import '../domain/pcb/pcb.dart';
import '../domain/symbols/symbols.dart' show FillType, StrokeStyle;
import 'sexpr/sexpr.dart';
import 'sexpr/sexpr_writer.dart';

/// Writes a footprint as a standalone `.kicad_mod` file.
///
/// What the footprint editor saves, and what the board export later places:
/// the board writer copies these nodes into a board as they are, so every
/// field KiCad insists on — the Reference and Value properties, an `attr` —
/// has to be here.
abstract final class FootprintWriter {
  static const formatVersion = 20241229;

  static String write(FootprintDefinition footprint) =>
      const SExprWriter().write(node(footprint));

  static SList node(FootprintDefinition footprint) {
    final court = footprint.graphics
        .whereType<FootprintRect>()
        .where((r) => r.layer == BoardLayer.frontCourtyard)
        .firstOrNull;
    final top = court == null ? -2.0 : court.start.y - 1.0;
    final bottom = court == null ? 2.0 : court.end.y + 1.0;

    SList font(double size) => S.list('effects', [
      S.list('font', [
        S.of('size', [size, size]),
        S.of('thickness', [size * 0.15]),
      ]),
    ]);

    SList property(String key, String value, double y, String layer) => SList([
      SAtom('property'),
      S.text(key),
      S.text(value),
      S.of('at', [0, y, 0]),
      SList([SAtom('layer'), S.text(layer)]),
      font(1),
    ]);

    return SList([
      SAtom('footprint'),
      S.text(footprint.name),
      S.of('version', [formatVersion]),
      SList([SAtom('generator'), S.text('hintpcb')]),
      SList([SAtom('layer'), S.text('F.Cu')]),
      if (footprint.description.isNotEmpty)
        SList([SAtom('descr'), S.text(footprint.description)]),
      if (footprint.keywords.isNotEmpty)
        SList([SAtom('tags'), S.text(footprint.keywords)]),
      property('Reference', 'REF**', top, 'F.SilkS'),
      property('Value', footprint.name, bottom, 'F.Fab'),
      SList([
        SAtom('attr'),
        for (final attribute in footprint.attributes) SAtom(attribute),
      ]),
      for (final graphic in footprint.graphics) ?_graphic(graphic),
      for (final pad in footprint.pads) _pad(pad),
      S.flag('embedded_fonts', false),
    ]);
  }

  static SList _stroke(StrokeStyle stroke) => S.list('stroke', [
    S.of('width', [stroke.width]),
    S.of('type', [SAtom('solid')]),
  ]);

  static SList _layer(BoardLayer? layer) =>
      SList([SAtom('layer'), S.text(layer?.token ?? 'F.SilkS')]);

  static SList _xy(String head, FootprintPoint p) => S.of(head, [p.x, p.y]);

  static SList? _graphic(FootprintGraphic graphic) => switch (graphic) {
    FootprintLine(:final start, :final end) => S.list('fp_line', [
      _xy('start', start),
      _xy('end', end),
      _stroke(graphic.stroke),
      _layer(graphic.layer),
    ]),
    FootprintRect(:final start, :final end, :final fill) => S.list('fp_rect', [
      _xy('start', start),
      _xy('end', end),
      _stroke(graphic.stroke),
      S.of('fill', [SAtom(fill == FillType.none ? 'no' : 'yes')]),
      _layer(graphic.layer),
    ]),
    FootprintCircle(:final center, :final end, :final fill) => S.list(
      'fp_circle',
      [
        _xy('center', center),
        _xy('end', end),
        _stroke(graphic.stroke),
        S.of('fill', [SAtom(fill == FillType.none ? 'no' : 'yes')]),
        _layer(graphic.layer),
      ],
    ),
    FootprintArc(:final start, :final mid, :final end) => S.list('fp_arc', [
      _xy('start', start),
      _xy('mid', mid),
      _xy('end', end),
      _stroke(graphic.stroke),
      _layer(graphic.layer),
    ]),
    FootprintPolygon(:final points, :final fill) => S.list('fp_poly', [
      S.list('pts', [for (final point in points) _xy('xy', point)]),
      _stroke(graphic.stroke),
      S.of('fill', [SAtom(fill == FillType.none ? 'no' : 'yes')]),
      _layer(graphic.layer),
    ]),
  };

  static SList _pad(Pad pad) => SList([
    SAtom('pad'),
    S.text(pad.number),
    SAtom(pad.type.token),
    SAtom(pad.shape.token),
    S.of('at', [pad.at.x, pad.at.y, if (pad.angle != 0) pad.angle]),
    S.of('size', [pad.sizeX, pad.sizeY]),
    if (pad.drill > 0)
      pad.drillY > 0
          ? S.of('drill', [SAtom('oval'), pad.drill, pad.drillY])
          : S.of('drill', [pad.drill]),
    SList([
      SAtom('layers'),
      for (final layer
          in pad.rawLayers.isNotEmpty
              ? pad.rawLayers
              : [for (final l in pad.layers) l.token])
        S.text(layer),
    ]),
    if (pad.shape == PadShape.roundrect)
      S.of('roundrect_rratio', [pad.roundrectRatio]),
    if (pad.maskMargin != 0) S.of('solder_mask_margin', [pad.maskMargin]),
  ]);
}
