import 'package:flutter/painting.dart';

/// Draws a single line of text on a canvas, positioned by its anchor.
///
/// Shared by the painters so text metrics and the monospace stack are
/// defined once.
void drawCanvasText(
  Canvas canvas, {
  required String text,
  required Offset anchor,
  required Color color,
  required double fontSize,
  TextAlign align = TextAlign.center,
  bool anchorAtBottom = false,
}) {
  if (text.isEmpty) return;

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace', 'Roboto Mono', 'Courier'],
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout();

  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => -painter.width,
    _ => -painter.width / 2,
  };
  painter.paint(
    canvas,
    Offset(anchor.dx + dx, anchorAtBottom ? anchor.dy - painter.height : anchor.dy),
  );
  painter.dispose();
}
