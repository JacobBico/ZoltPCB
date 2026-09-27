import '../domain/pcb/pcb.dart';
import '../domain/symbols/symbols.dart' show FillType, StrokeStyle, StrokeType;
import 'sexpr/sexpr.dart';

/// Thrown when a node parses as an s-expression but is not a footprint.
class FootprintParseException implements Exception {
  const FootprintParseException(this.message);

  final String message;

  @override
  String toString() => 'FootprintParseException: $message';
}

/// Turns parsed s-expressions into [FootprintDefinition]s.
///
/// Tolerant in the same way [SymbolParser] is, and for the same reason: the
/// user's own library may have been written by any KiCad since version 5.
/// Unknown nodes are skipped rather than refused, and both the old
/// `(fp_line ... (layer "F.SilkS"))` spelling and newer variants parse.
abstract final class FootprintParser {
  /// Parses one `(footprint "NAME" ...)` node.
  ///
  /// [libraryNickname] comes from the containing `.pretty` directory, not
  /// from the file: a `.kicad_mod` never states which library it belongs to.
  static FootprintDefinition parse(SList node, String libraryNickname) {
    // KiCad 5 called the node `module`. Files that old still open on the
    // desktop, so they have to open here.
    if (node.head != 'footprint' && node.head != 'module') {
      throw FootprintParseException(
        'Expected a footprint node, got ${node.head}',
      );
    }
    final name = node.atom(1);
    if (name == null || name.isEmpty) {
      throw const FootprintParseException('Footprint has no name');
    }

    final properties = <String, String>{};
    for (final property in node.children('property')) {
      final key = property.atom(1);
      if (key != null) properties[key] = property.atom(2) ?? '';
    }

    return FootprintDefinition(
      libraryNickname: libraryNickname,
      // A name written as `Library:Footprint` keeps only its second half:
      // the nickname is decided by where the file lives.
      name: name.contains(':') ? name.split(':').last : name,
      description: node.childAtom('descr') ?? properties['Description'] ?? '',
      keywords: node.childAtom('tags') ?? '',
      pads: [for (final pad in node.children('pad')) ?_parsePad(pad)],
      graphics: _parseGraphics(node),
      attributes: _parseAttributes(node),
      formatVersion: node.childInteger('version') ?? 0,
      generator: node.childAtom('generator') ?? '',
    );
  }

  static List<String> _parseAttributes(SList node) {
    final attr = node.child('attr');
    if (attr == null) return const [];
    return [for (var i = 1; i < attr.items.length; i++) ?attr.atom(i)];
  }

  static Pad? _parsePad(SList node) {
    final number = node.atom(1);
    final type = node.atom(2);
    final shape = node.atom(3);
    if (number == null || type == null || shape == null) return null;

    final at = node.child('at');
    final size = node.child('size');
    final drill = node.child('drill');
    final rawLayers = _layerTokens(node.child('layers'));

    return Pad(
      number: number,
      type: PadType.fromToken(type),
      shape: PadShape.fromToken(shape),
      at: FootprintPoint(at?.number(1) ?? 0, at?.number(2) ?? 0),
      // A `(at x y angle)` third value is the pad's own rotation.
      angle: at?.number(3) ?? 0,
      sizeX: size?.number(1) ?? 0,
      sizeY: size?.number(2) ?? size?.number(1) ?? 0,
      drill: _drillDiameter(drill),
      drillY: _drillSecondary(drill),
      roundrectRatio: node.childNumber('roundrect_rratio') ?? 0,
      maskMargin: node.childNumber('solder_mask_margin') ?? 0,
      layers: _resolveLayers(rawLayers),
      rawLayers: rawLayers,
    );
  }

  /// `(drill 0.8)`, `(drill oval 1.6 0.8)`, or `(drill (offset ...))`.
  static double _drillDiameter(SList? node) {
    if (node == null) return 0;
    if (node.atom(1) == 'oval') return node.number(2) ?? 0;
    return node.number(1) ?? 0;
  }

  static double _drillSecondary(SList? node) {
    if (node == null || node.atom(1) != 'oval') return 0;
    return node.number(3) ?? 0;
  }

  static List<String> _layerTokens(SList? node) {
    if (node == null) return const [];
    return [for (var i = 1; i < node.items.length; i++) ?node.atom(i)];
  }

  /// Expands KiCad's layer wildcards into the layers we actually draw.
  ///
  /// A through-hole pad says `*.Cu`, meaning every copper layer. On a
  /// two-layer board that is front and back, which is exactly what routing
  /// needs to know.
  static List<BoardLayer> _resolveLayers(List<String> tokens) {
    final resolved = <BoardLayer>{};
    for (final token in tokens) {
      if (token.startsWith('*.')) {
        final suffix = token.substring(2);
        for (final layer in BoardLayer.values) {
          if (layer.token.endsWith('.$suffix')) resolved.add(layer);
        }
        continue;
      }
      final layer = BoardLayer.fromToken(token);
      if (layer != null) resolved.add(layer);
    }
    return resolved.toList();
  }

  static List<FootprintGraphic> _parseGraphics(SList node) {
    final graphics = <FootprintGraphic>[];

    for (final item in node.lists) {
      final layer = BoardLayer.fromToken(item.childAtom('layer') ?? '');
      final stroke = _parseStroke(item);
      final fill = _parseFill(item);

      switch (item.head) {
        case 'fp_line':
          graphics.add(
            FootprintLine(
              start: _point(item.child('start')),
              end: _point(item.child('end')),
              layer: layer,
              stroke: stroke,
            ),
          );
        case 'fp_rect':
          graphics.add(
            FootprintRect(
              start: _point(item.child('start')),
              end: _point(item.child('end')),
              layer: layer,
              stroke: stroke,
              fill: fill,
            ),
          );
        case 'fp_circle':
          graphics.add(
            FootprintCircle(
              center: _point(item.child('center')),
              end: _point(item.child('end')),
              layer: layer,
              stroke: stroke,
              fill: fill,
            ),
          );
        case 'fp_arc':
          graphics.add(
            FootprintArc(
              start: _point(item.child('start')),
              mid: _point(item.child('mid')),
              end: _point(item.child('end')),
              layer: layer,
              stroke: stroke,
            ),
          );
        case 'fp_poly':
          graphics.add(
            FootprintPolygon(
              points: _points(item),
              layer: layer,
              stroke: stroke,
              fill: fill,
            ),
          );
        // Only text the footprint prints itself; its reference and value
        // are the part's, placed on the board.
        case 'fp_text' when item.atom(1) == 'user':
          final effects = item.child('effects');
          if (item.flag('hide') || (effects?.flag('hide') ?? false)) break;
          final at = item.child('at');
          graphics.add(
            FootprintText(
              text: item.atom(2) ?? '',
              at: _point(at),
              angle: at?.number(3) ?? 0,
              size: effects?.child('font')?.child('size')?.number(1) ?? 1.0,
              layer: layer,
              stroke: StrokeStyle(
                width:
                    effects?.child('font')?.child('thickness')?.number(1) ??
                    0.15,
                type: StrokeType.fromToken('solid'),
              ),
            ),
          );
      }
    }
    return graphics;
  }

  static FootprintPoint _point(SList? node) =>
      FootprintPoint(node?.number(1) ?? 0, node?.number(2) ?? 0);

  static List<FootprintPoint> _points(SList node) {
    final pts = node.child('pts');
    if (pts == null) return const [];
    return [
      for (final xy in pts.children('xy'))
        FootprintPoint(xy.number(1) ?? 0, xy.number(2) ?? 0),
    ];
  }

  static StrokeStyle _parseStroke(SList node) {
    final stroke = node.child('stroke');
    if (stroke != null) {
      return StrokeStyle(
        width: stroke.childNumber('width') ?? 0,
        type: StrokeType.fromToken(stroke.childAtom('type') ?? 'default'),
      );
    }
    // KiCad 6 and earlier wrote the width straight on the graphic.
    final width = node.childNumber('width');
    if (width == null) return StrokeStyle.defaultStroke;
    return StrokeStyle(width: width, type: StrokeType.solid);
  }

  static FillType _parseFill(SList node) {
    final fill = node.child('fill');
    if (fill == null) return FillType.none;
    // `(fill yes)` and `(fill solid)` both mean filled; `(fill none)` and
    // `(fill no)` both mean not.
    return switch (fill.atom(1)) {
      'yes' || 'solid' || 'true' => FillType.outline,
      _ => FillType.none,
    };
  }
}
