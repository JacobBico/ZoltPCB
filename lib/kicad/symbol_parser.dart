import 'dart:ui' show Color;

import '../domain/models/pin.dart';
import '../domain/symbols/symbols.dart';
import 'sexpr/sexpr.dart';

/// Thrown when a node is syntactically valid s-expression but is not a
/// well-formed symbol.
class SymbolParseException implements Exception {
  const SymbolParseException(this.message);

  final String message;

  @override
  String toString() => 'SymbolParseException: $message';
}

/// Turns parsed s-expressions into [SymbolDefinition]s.
///
/// Tolerant by design. KiCad has written five schema versions of this format
/// and a user may import a library from any of them, so unknown nodes are
/// ignored and flags are read in both the old bare-token form (`hide`) and
/// the current wrapped form (`(hide yes)`).
abstract final class SymbolParser {
  /// Parses one `(symbol "NAME" ...)` node.
  static SymbolDefinition parseSymbol(SList node, String libraryNickname) {
    if (node.head != 'symbol') {
      throw SymbolParseException('Expected a symbol node, got ${node.head}');
    }
    final name = node.atom(1);
    if (name == null) {
      throw const SymbolParseException('Symbol has no name');
    }

    final properties = <String, String>{};
    for (final property in node.children('property')) {
      final key = property.atom(1);
      final value = property.atom(2);
      if (key != null) properties[key] = value ?? '';
    }

    final pinNames = node.child('pin_names');
    final pinNumbers = node.child('pin_numbers');

    final drawings = <SymbolUnitDrawing>[];
    var hasDeMorgan = false;
    for (final child in node.children('symbol')) {
      final childName = child.atom(1);
      if (childName == null) continue;
      final indices = _parseUnitSuffix(childName);
      if (indices == null) continue;
      final drawing = _parseUnitDrawing(child, indices.$1, indices.$2);
      if (indices.$2 > 1) hasDeMorgan = true;
      drawings.add(drawing);
    }
    drawings.sort((a, b) {
      final byUnit = a.unit.compareTo(b.unit);
      return byUnit != 0 ? byUnit : a.bodyStyle.compareTo(b.bodyStyle);
    });

    return SymbolDefinition(
      libraryNickname: libraryNickname,
      name: name,
      extendsSymbol: node.child('extends')?.atom(1),
      properties: properties,
      unitDrawings: drawings,
      pinNamesHidden: pinNames?.flag('hide') ?? false,
      pinNamesOffset: pinNames?.childNumber('offset') ?? 0.508,
      pinNumbersHidden: pinNumbers?.flag('hide') ?? false,
      // KiCad 9 and earlier write a bare `(power)`; version 10 writes
      // `(power global)` or `(power local)`.
      isPower: node.child('power') != null,
      excludeFromSim: node.child('exclude_from_sim')?.atom(1) == 'yes',
      inBom: node.child('in_bom')?.atom(1) != 'no',
      onBoard: node.child('on_board')?.atom(1) != 'no',
      hasDeMorganAlternate:
          hasDeMorgan || node.child('body_styles')?.atom(1) == 'demorgan',
    );
  }

  /// Splits `74LS00_1_1` into unit 1, body style 1.
  ///
  /// Read from the right, because the symbol's own name may itself contain
  /// underscores — and frequently does.
  static (int, int)? _parseUnitSuffix(String childName) {
    final lastUnderscore = childName.lastIndexOf('_');
    if (lastUnderscore <= 0) return null;
    final secondLast = childName.lastIndexOf('_', lastUnderscore - 1);
    if (secondLast < 0) return null;

    final unit = int.tryParse(
      childName.substring(secondLast + 1, lastUnderscore),
    );
    final bodyStyle = int.tryParse(childName.substring(lastUnderscore + 1));
    if (unit == null || bodyStyle == null) return null;
    return (unit, bodyStyle);
  }

  static SymbolUnitDrawing _parseUnitDrawing(
    SList node,
    int unit,
    int bodyStyle,
  ) {
    final graphics = <SymbolGraphic>[];
    final pins = <SymbolPin>[];

    for (final item in node.lists) {
      switch (item.head) {
        case 'polyline':
          graphics.add(
            SymbolPolyline(
              points: _parsePoints(item),
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'rectangle':
          graphics.add(
            SymbolRectangle(
              start: _parseXy(item.child('start')),
              end: _parseXy(item.child('end')),
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'circle':
          graphics.add(
            SymbolCircle(
              center: _parseXy(item.child('center')),
              radius: item.childNumber('radius') ?? 0,
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'arc':
          graphics.add(
            SymbolArc(
              start: _parseXy(item.child('start')),
              mid: _parseXy(item.child('mid')),
              end: _parseXy(item.child('end')),
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'bezier':
          graphics.add(
            SymbolBezier(
              points: _parsePoints(item),
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'text':
          final at = item.child('at');
          graphics.add(
            SymbolText(
              text: item.atom(1) ?? '',
              at: _parseXy(at),
              angle: at?.number(3) ?? 0,
              effects: _parseEffects(item.child('effects')),
            ),
          );
        case 'text_box':
          final at = item.child('at');
          graphics.add(
            SymbolTextBox(
              text: item.atom(1) ?? '',
              at: _parseXy(at),
              size: _parseXy(item.child('size')),
              angle: at?.number(3) ?? 0,
              effects: _parseEffects(item.child('effects')),
              stroke: _parseStroke(item),
              fill: _parseFill(item),
            ),
          );
        case 'pin':
          pins.add(_parsePin(item));
      }
    }

    return SymbolUnitDrawing(
      unit: unit,
      bodyStyle: bodyStyle,
      graphics: graphics,
      pins: pins,
    );
  }

  static SymbolPin _parsePin(SList node) {
    final at = node.child('at');
    final nameNode = node.child('name');
    final numberNode = node.child('number');

    return SymbolPin(
      // `(pin passive line ...)` — type and style are positional.
      electricalType: PinElectricalType.fromToken(node.atom(1) ?? 'unspecified'),
      graphicStyle: PinGraphicStyle.fromToken(node.atom(2) ?? 'line'),
      at: _parseXy(at),
      angle: at?.number(3) ?? 0,
      length: node.childNumber('length') ?? 2.54,
      name: nameNode?.atom(1) ?? '',
      number: numberNode?.atom(1) ?? '',
      hidden: node.flag('hide'),
      nameEffects: _parseEffects(nameNode?.child('effects')),
      numberEffects: _parseEffects(numberNode?.child('effects')),
      alternates: [
        for (final alt in node.children('alternate'))
          PinAlternate(
            name: alt.atom(1) ?? '',
            electricalType: PinElectricalType.fromToken(
              alt.atom(2) ?? 'unspecified',
            ),
            graphicStyle: PinGraphicStyle.fromToken(alt.atom(3) ?? 'line'),
          ),
      ],
    );
  }

  static SymbolPoint _parseXy(SList? node) {
    if (node == null) return const SymbolPoint(0, 0);
    return SymbolPoint(node.number(1) ?? 0, node.number(2) ?? 0);
  }

  static List<SymbolPoint> _parsePoints(SList node) {
    final pts = node.child('pts');
    if (pts == null) return const [];
    return [for (final xy in pts.children('xy')) _parseXy(xy)];
  }

  static StrokeStyle _parseStroke(SList node) {
    final stroke = node.child('stroke');
    if (stroke == null) return StrokeStyle.defaultStroke;
    return StrokeStyle(
      width: stroke.childNumber('width') ?? 0,
      type: StrokeType.fromToken(stroke.childAtom('type') ?? 'default'),
      color: _parseColor(stroke.child('color')),
    );
  }

  static FillStyle _parseFill(SList node) {
    final fill = node.child('fill');
    if (fill == null) return FillStyle.none;
    return FillStyle(
      type: FillType.fromToken(fill.childAtom('type') ?? 'none'),
      color: _parseColor(fill.child('color')),
    );
  }

  /// `(color 255 0 0 1)` — channels are 0-255 but alpha is 0-1.
  static Color? _parseColor(SList? node) {
    if (node == null) return null;
    final r = node.integer(1);
    final g = node.integer(2);
    final b = node.integer(3);
    final a = node.number(4) ?? 1;
    if (r == null || g == null || b == null) return null;
    if (r == 0 && g == 0 && b == 0 && a == 0) return null; // "unset"
    return Color.fromARGB((a * 255).round().clamp(0, 255), r, g, b);
  }

  static TextEffects _parseEffects(SList? node) {
    if (node == null) return TextEffects.standard;
    final font = node.child('font');
    final size = font?.child('size');
    final justify = node.child('justify');

    var horizontal = TextHorizontalAlign.center;
    var vertical = TextVerticalAlign.middle;
    var mirrored = false;
    if (justify != null) {
      for (var i = 1; i < justify.items.length; i++) {
        switch (justify.atom(i)) {
          case 'left':
            horizontal = TextHorizontalAlign.left;
          case 'right':
            horizontal = TextHorizontalAlign.right;
          case 'top':
            vertical = TextVerticalAlign.top;
          case 'bottom':
            vertical = TextVerticalAlign.bottom;
          case 'mirror':
            mirrored = true;
        }
      }
    }

    return TextEffects(
      sizeX: size?.number(1) ?? 1.27,
      sizeY: size?.number(2) ?? 1.27,
      bold: font?.flag('bold') ?? false,
      italic: font?.flag('italic') ?? false,
      hidden: node.flag('hide'),
      horizontal: horizontal,
      vertical: vertical,
      mirrored: mirrored,
    );
  }
}
