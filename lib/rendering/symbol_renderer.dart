import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../core/theme/kicad_palette.dart';
import '../domain/symbols/symbols.dart';
import 'renderable_pin.dart';
import 'resistor_zigzag.dart';
import 'schematic_geometry.dart';
import 'schematic_viewport.dart';

/// Draws symbols from their vector primitives.
///
/// Nothing here knows about projects, nets or persistence — it takes a
/// parsed symbol and a placement and paints it. That keeps the renderer
/// testable against a hand-built [SymbolDefinition] and reusable for symbol
/// previews outside the canvas.
class SymbolRenderer {
  const SymbolRenderer({
    required this.viewport,
    required this.colors,
    this.showPinNames = true,
    this.showPinNumbers = true,
  });

  final SchematicViewport viewport;
  final SchematicColors colors;
  final bool showPinNames;
  final bool showPinNumbers;

  /// KiCad's default line width for library graphics, used wherever a
  /// symbol says width 0 — which nearly all of them do.
  static const defaultLineWidthMm = 0.1524;

  /// Length of a pin's connection dot, in millimetres.
  static const connectionDotRadiusMm = 0.4;

  /// Draws a symbol's body: everything except its pins.
  ///
  /// With [rectanglesAsZigzag], a rectangle is drawn as the ANSI zigzag
  /// along its long axis instead. That is the whole difference between the
  /// IEC and US resistor, so it is done at draw time rather than by keeping
  /// a second copy of every resistor symbol.
  void paintGraphics(
    Canvas canvas, {
    required SymbolDefinition symbol,
    required int unit,
    required Placement placement,
    int bodyStyle = 1,
    bool selected = false,
    bool rectanglesAsZigzag = false,
  }) {
    final outline = selected ? colors.highlight : colors.symbolOutline;
    for (final graphic in symbol.graphicsForUnit(unit, bodyStyle: bodyStyle)) {
      if (rectanglesAsZigzag && graphic is SymbolRectangle) {
        _paintZigzag(canvas, graphic, placement, outline);
        continue;
      }
      _paintGraphic(canvas, graphic, placement, outline);
    }
  }

  /// A rectangle's long axis, drawn as a zigzag as wide as the rectangle.
  void _paintZigzag(
    Canvas canvas,
    SymbolRectangle rectangle,
    Placement placement,
    Color outline,
  ) {
    final left = math.min(rectangle.start.x, rectangle.end.x);
    final right = math.max(rectangle.start.x, rectangle.end.x);
    final bottom = math.min(rectangle.start.y, rectangle.end.y);
    final top = math.max(rectangle.start.y, rectangle.end.y);
    final width = right - left;
    final height = top - bottom;
    final vertical = height >= width;

    // End points in the middle of the two short sides, in symbol space, so
    // rotation and mirroring come for free through the placement.
    final from = vertical
        ? placement.apply((left + right) / 2, top)
        : placement.apply(left, (top + bottom) / 2);
    final to = vertical
        ? placement.apply((left + right) / 2, bottom)
        : placement.apply(right, (top + bottom) / 2);

    final length = vertical ? height : width;
    final across = vertical ? width : height;
    final path = resistorZigzag(
      viewport.toScreen(from),
      viewport.toScreen(to),
      // Half the rectangle's width either side of the axis, so the zigzag
      // fills exactly the space the box did.
      widthFraction: length <= 0 ? 0.2 : (across / 2) / length,
    );
    canvas.drawPath(
      path,
      _strokePaint(rectangle.stroke, outline)..strokeJoin = StrokeJoin.miter,
    );
  }

  /// Draws pins and their names and numbers.
  void paintPins(
    Canvas canvas, {
    required Iterable<RenderablePin> pins,
    required Placement placement,
    bool pinNamesHidden = false,
    double pinNamesOffset = 0.508,
    bool pinNumbersHidden = false,
    Set<String> highlightedPinIds = const {},
    bool selected = false,
    bool showHiddenPins = false,
  }) {
    for (final pin in pins) {
      if (pin.hidden && !showHiddenPins) continue;
      _paintPin(
        canvas,
        pin,
        placement,
        pinNamesHidden: pinNamesHidden,
        pinNamesOffset: pinNamesOffset,
        pinNumbersHidden: pinNumbersHidden,
        highlighted: highlightedPinIds.contains(pin.id),
        selected: selected,
      );
    }
  }

  /// Draws a whole symbol, body and pins, straight from a library
  /// definition. Used for previews, where there is no placed part.
  void paintUnit(
    Canvas canvas, {
    required SymbolDefinition symbol,
    required int unit,
    required Placement placement,
    int bodyStyle = 1,
    bool selected = false,
  }) {
    paintGraphics(
      canvas,
      symbol: symbol,
      unit: unit,
      placement: placement,
      bodyStyle: bodyStyle,
      selected: selected,
    );
    paintPins(
      canvas,
      pins: symbol
          .pinsForUnit(unit, bodyStyle: bodyStyle)
          .map((p) => RenderablePin.fromSymbol(p, unit: unit)),
      placement: placement,
      pinNamesHidden: symbol.pinNamesHidden,
      pinNamesOffset: symbol.pinNamesOffset,
      pinNumbersHidden: symbol.pinNumbersHidden,
      selected: selected,
    );
  }

  // --- graphics --------------------------------------------------------

  void _paintGraphic(
    Canvas canvas,
    SymbolGraphic graphic,
    Placement placement,
    Color outline,
  ) {
    final path = _pathFor(graphic, placement);
    if (path == null) {
      if (graphic is SymbolText) _paintText(canvas, graphic, placement);
      if (graphic is SymbolTextBox) _paintTextBox(canvas, graphic, placement);
      return;
    }

    final fill = _fillPaint(graphic.fill, outline);
    if (fill != null) canvas.drawPath(path, fill);
    canvas.drawPath(path, _strokePaint(graphic.stroke, outline));
  }

  Path? _pathFor(SymbolGraphic graphic, Placement placement) {
    Offset screen(SymbolPoint p) => viewport.toScreen(placement.applyPoint(p));

    switch (graphic) {
      case SymbolPolyline(:final points):
        if (points.isEmpty) return null;
        final path = Path()
          ..moveTo(screen(points.first).dx, screen(points.first).dy);
        for (final point in points.skip(1)) {
          final o = screen(point);
          path.lineTo(o.dx, o.dy);
        }
        return path;

      case SymbolRectangle(:final start, :final end):
        // The rectangle's corners rotate with the symbol, so it is drawn as
        // a four-sided path rather than a Rect.
        final corners = [
          screen(start),
          screen(SymbolPoint(end.x, start.y)),
          screen(end),
          screen(SymbolPoint(start.x, end.y)),
        ];
        return Path()
          ..moveTo(corners[0].dx, corners[0].dy)
          ..lineTo(corners[1].dx, corners[1].dy)
          ..lineTo(corners[2].dx, corners[2].dy)
          ..lineTo(corners[3].dx, corners[3].dy)
          ..close();

      case SymbolCircle(:final center, :final radius):
        return Path()..addOval(
          Rect.fromCircle(
            center: screen(center),
            radius: viewport.lengthToScreen(radius),
          ),
        );

      case SymbolArc(:final start, :final mid, :final end):
        final arc = arcThroughPoints(screen(start), screen(mid), screen(end));
        if (arc == null) {
          final a = screen(start);
          final b = screen(end);
          return Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy);
        }
        return Path()..addArc(arc.bounds, arc.startAngle, arc.sweepAngle);

      case SymbolBezier(:final points):
        if (points.length < 4) return null;
        final p = points.map(screen).toList();
        return Path()
          ..moveTo(p[0].dx, p[0].dy)
          ..cubicTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy, p[3].dx, p[3].dy);

      case SymbolText():
      case SymbolTextBox():
        return null;
    }
  }

  Paint _strokePaint(StrokeStyle stroke, Color outline) {
    final widthMm = stroke.width <= 0 ? defaultLineWidthMm : stroke.width;
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = stroke.color ?? outline
      // Never thinner than a pixel: at low zoom a hairline symbol would
      // otherwise fade out entirely.
      ..strokeWidth = math.max(1.0, viewport.lengthToScreen(widthMm))
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint? _fillPaint(FillStyle fill, Color outline) => switch (fill.type) {
    FillType.none => null,
    FillType.outline => Paint()..color = outline,
    FillType.background => Paint()..color = colors.symbolFill,
    FillType.color =>
      fill.color == null ? null : (Paint()..color = fill.color!),
  };

  // --- pins ------------------------------------------------------------

  void _paintPin(
    Canvas canvas,
    RenderablePin pin,
    Placement placement, {
    required bool pinNamesHidden,
    required double pinNamesOffset,
    required bool pinNumbersHidden,
    required bool highlighted,
    required bool selected,
  }) {
    final (endX, endY) = pin.bodyEnd;
    final tip = viewport.toScreen(placement.apply(pin.x, pin.y));
    final root = viewport.toScreen(placement.apply(endX, endY));

    final color = highlighted || selected ? colors.highlight : colors.pin;

    canvas.drawLine(
      tip,
      root,
      Paint()
        ..color = color
        ..strokeWidth = math.max(
          1.0,
          viewport.lengthToScreen(defaultLineWidthMm),
        )
        ..strokeCap = StrokeCap.round,
    );

    // A dot on the connection point: it marks where a net attaches and
    // shows the extent of the touch target.
    canvas.drawCircle(
      tip,
      math.max(2.0, viewport.lengthToScreen(connectionDotRadiusMm)),
      Paint()
        ..color = color
        ..style = highlighted ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (pin.noConnect) _paintNoConnect(canvas, tip);

    _paintPinLabels(
      canvas,
      pin,
      placement,
      endX,
      endY,
      pinNamesHidden: pinNamesHidden,
      pinNamesOffset: pinNamesOffset,
      pinNumbersHidden: pinNumbersHidden,
    );
  }

  /// The blue cross KiCad draws on a pin deliberately left unconnected.
  void _paintNoConnect(Canvas canvas, Offset at) {
    final arm = math.max(3.0, viewport.lengthToScreen(0.635));
    final paint = Paint()
      ..color = colors.noConnect
      ..strokeWidth = math.max(1.0, viewport.lengthToScreen(0.152))
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + Offset(-arm, -arm), at + Offset(arm, arm), paint);
    canvas.drawLine(at + Offset(-arm, arm), at + Offset(arm, -arm), paint);
  }

  void _paintPinLabels(
    Canvas canvas,
    RenderablePin pin,
    Placement placement,
    double endX,
    double endY, {
    required bool pinNamesHidden,
    required double pinNamesOffset,
    required bool pinNumbersHidden,
  }) {
    // Below about this zoom the text would be unreadable and just noise.
    if (viewport.pixelsPerMm < 3.2) return;

    final sheetAngle = placement.pinAngle(pin.angle);
    final rotate = sheetAngle == 90 || sheetAngle == 270;

    if (showPinNames && !pinNamesHidden && pin.hasName) {
      final offset = pinNamesOffset <= 0 ? 0.6 : pinNamesOffset;
      final radians = pin.angle * math.pi / 180;
      _drawLabel(
        canvas,
        text: pin.name,
        anchor: viewport.toScreen(
          placement.apply(
            endX + offset * math.cos(radians),
            endY + offset * math.sin(radians),
          ),
        ),
        color: colors.pinName,
        sizeMm: 1.27,
        alignment: _labelAlignmentFor(sheetAngle),
        rotated: rotate,
      );
    }

    if (showPinNumbers && !pinNumbersHidden && pin.number.isNotEmpty) {
      final screenMid = viewport.toScreen(
        placement.apply((pin.x + endX) / 2, (pin.y + endY) / 2),
      );
      _drawLabel(
        canvas,
        text: pin.number,
        // Nudged clear of the stub so the two never overlap.
        anchor: screenMid + (rotate ? const Offset(6, 0) : const Offset(0, -8)),
        color: colors.pinNumber,
        sizeMm: 1.27,
        alignment: Alignment.center,
        rotated: false,
      );
    }
  }

  Alignment _labelAlignmentFor(double sheetAngle) {
    // sheetAngle is the direction from the pin tip towards the body.
    return switch (sheetAngle) {
      0 => Alignment.centerLeft,
      180 => Alignment.centerRight,
      270 => Alignment.centerLeft,
      _ => Alignment.centerRight,
    };
  }

  void _paintText(Canvas canvas, SymbolText text, Placement placement) {
    if (viewport.pixelsPerMm < 3.2) return;
    _drawLabel(
      canvas,
      text: text.text,
      anchor: viewport.toScreen(placement.applyPoint(text.at)),
      color: colors.fieldText,
      sizeMm: text.effects.sizeY,
      alignment: Alignment.center,
      rotated: false,
      bold: text.effects.bold,
      italic: text.effects.italic,
    );
  }

  void _paintTextBox(Canvas canvas, SymbolTextBox box, Placement placement) {
    if (viewport.pixelsPerMm < 3.2) return;
    _drawLabel(
      canvas,
      text: box.text,
      anchor: viewport.toScreen(placement.applyPoint(box.at)),
      color: colors.fieldText,
      sizeMm: box.effects.sizeY,
      alignment: Alignment.topLeft,
      rotated: false,
    );
  }

  /// Draws one piece of text, positioned by [alignment] relative to
  /// [anchor], optionally turned on its side for a vertical pin.
  void _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset anchor,
    required Color color,
    required double sizeMm,
    required Alignment alignment,
    required bool rotated,
    bool bold = false,
    bool italic = false,
  }) {
    final fontSize = viewport.lengthToScreen(sizeMm <= 0 ? 1.27 : sizeMm);
    if (fontSize < 5) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['monospace', 'Roboto Mono', 'Courier'],
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    if (rotated) canvas.rotate(-math.pi / 2);

    final size = painter.size;
    final dx = switch (alignment.x) {
      < 0 => 2.0,
      > 0 => -size.width - 2.0,
      _ => -size.width / 2,
    };
    painter.paint(canvas, Offset(dx, -size.height / 2));
    canvas.restore();
    painter.dispose();
  }
}
