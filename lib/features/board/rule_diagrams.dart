import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// Little pictures of what each design rule means.
///
/// A column of numbered fields called "Clearance", "Thermal gap" and
/// "Spoke" tells you what they are called, not what they do — and the
/// difference between a solid, a thermal and no connection is entirely a
/// matter of shape. KiCad draws them, and it draws them because a diagram
/// half a centimetre across answers the question that a paragraph does not.
///
/// Everything here is drawn in a unit box and scaled, so the same painter
/// serves a 40 dp thumbnail beside a field and a 64 dp tile in a picker.
sealed class RuleFigure {
  const RuleFigure();

  void paint(Canvas canvas, Size size);
}

/// The copper colour things are drawn in, and the board behind them.
class _Ink {
  _Ink(this.copper)
    : board = KicadPalette.surface,
      hole = KicadPalette.background,
      guide = KicadPalette.textSecondary;

  final Color copper;
  final Color board;
  final Color hole;
  final Color guide;

  Paint get fill => Paint()..color = copper;
  Paint get cut => Paint()..color = board;
  Paint get drill => Paint()..color = hole;
  Paint line(double width) => Paint()
    ..color = guide
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;
}

/// Two tracks with the gap between them called out: the clearance.
class ClearanceFigure extends RuleFigure {
  const ClearanceFigure();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final h = size.height;
    final w = size.width;
    final thick = h * 0.16;
    final gap = h * 0.22;
    final middle = h / 2;
    for (final offset in [-(gap + thick) / 2, (gap + thick) / 2]) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.08, middle + offset - thick / 2, w * 0.84, thick),
        ink.fill,
      );
    }
    _arrow(
      canvas,
      Offset(w / 2, middle - gap / 2),
      Offset(w / 2, middle + gap / 2),
      ink,
    );
  }
}

/// One track, with its width called out.
class TrackWidthFigure extends RuleFigure {
  const TrackWidthFigure();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final thick = size.height * 0.34;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.08,
        (size.height - thick) / 2,
        size.width * 0.84,
        thick,
      ),
      ink.fill,
    );
    _arrow(
      canvas,
      Offset(size.width / 2, (size.height - thick) / 2),
      Offset(size.width / 2, (size.height + thick) / 2),
      ink,
    );
  }
}

/// A via in section: the ring of copper, and the hole through it.
class ViaFigure extends RuleFigure {
  const ViaFigure({this.drill = false});

  /// Whether the arrow measures the hole or the outside of the ring.
  final bool drill;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final centre = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) * 0.36;
    final inner = outer * 0.5;
    canvas
      ..drawCircle(centre, outer, ink.fill)
      ..drawCircle(centre, inner, ink.drill);
    final reach = drill ? inner : outer;
    _arrow(
      canvas,
      centre - Offset(reach, 0),
      centre + Offset(reach, 0),
      ink,
      above: true,
    );
  }
}

/// A pad or a via sitting in a pour, joined the way [connection] says.
class ConnectionFigure extends RuleFigure {
  const ConnectionFigure(this.connection, {this.via = false});

  final PadConnection connection;

  /// A via is drawn round with a hole; a pad is drawn as a rounded square.
  final bool via;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final centre = Offset(size.width / 2, size.height / 2);
    final unit = math.min(size.width, size.height);
    final half = unit * 0.17;
    final gap = unit * 0.11;
    final spoke = unit * 0.11;

    // The pour, everywhere.
    canvas.drawRect(Offset.zero & size, ink.fill);

    Path shape(double grow) {
      if (via) {
        return Path()
          ..addOval(Rect.fromCircle(center: centre, radius: half + grow));
      }
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre,
            width: (half + grow) * 2,
            height: (half + grow) * 2,
          ),
          Radius.circular(unit * 0.05),
        ),
      );
    }

    switch (connection) {
      case PadConnection.solid:
        break;
      case PadConnection.none:
        canvas.drawPath(shape(gap * 1.6), ink.cut);
      case PadConnection.thermal:
        canvas.drawPath(shape(gap), ink.cut);
        for (final direction in const [
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(0, -1),
        ]) {
          canvas.drawLine(
            centre,
            centre + direction * (half + gap * 2),
            Paint()
              ..color = ink.copper
              ..strokeWidth = spoke,
          );
        }
    }

    // The pad or via itself, on top of whatever the pour did round it.
    canvas.drawPath(shape(0), ink.fill);
    if (via) canvas.drawCircle(centre, half * 0.5, ink.drill);
    canvas.drawPath(
      shape(0),
      Paint()
        ..color = ink.board.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// A thermal relief with its two numbers called out: the gap round the
/// copper, and the width of the spokes that bridge it.
class ThermalFigure extends RuleFigure {
  const ThermalFigure({this.spoke = false});

  /// Which of the two the arrow measures.
  final bool spoke;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final centre = Offset(size.width / 2, size.height / 2);
    final unit = math.min(size.width, size.height);
    final half = unit * 0.16;
    final gap = unit * 0.13;
    final width = unit * 0.12;

    canvas
      ..drawRect(Offset.zero & size, ink.fill)
      ..drawCircle(centre, half + gap, ink.cut);
    for (final direction in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(
        centre,
        centre + direction * (half + gap * 1.4),
        Paint()
          ..color = ink.copper
          ..strokeWidth = width,
      );
    }
    canvas.drawCircle(centre, half, ink.fill);

    if (spoke) {
      _arrow(
        canvas,
        centre + Offset(-width / 2, -(half + gap) - unit * 0.06),
        centre + Offset(width / 2, -(half + gap) - unit * 0.06),
        ink,
      );
    } else {
      _arrow(
        canvas,
        centre + Offset(half, unit * 0.26),
        centre + Offset(half + gap, unit * 0.26),
        ink,
      );
    }
  }
}

/// A track meeting a round pad, with and without the fillet that fills
/// the corner in.
class TeardropFigure extends RuleFigure {
  const TeardropFigure({this.filled = true});

  /// Whether the fillet is drawn, or only the bare corner it fills.
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(BoardPainter.colorFor(CopperLayer.front));
    final unit = math.min(size.width, size.height);
    final centre = Offset(size.width * 0.32, size.height / 2);
    final radius = unit * 0.26;
    final half = unit * 0.06;
    final end = Offset(size.width * 0.95, size.height / 2);

    if (filled) {
      final path = Path()..moveTo(centre.dx - radius, centre.dy);
      final reach = (end.dx - centre.dx) * 0.55;
      for (final side in [-1.0, 1.0]) {
        path.moveTo(centre.dx - radius * 0.9, centre.dy);
        for (var i = 0; i <= 8; i++) {
          final t = i / 8;
          final w = half + (radius * 0.92 - half) * (1 - t) * (1 - t);
          path.lineTo(centre.dx + reach * t, centre.dy + side * w);
        }
        path.lineTo(centre.dx + reach, centre.dy);
        path.close();
      }
      canvas.drawPath(path, ink.fill);
    }

    canvas
      ..drawCircle(centre, radius, ink.fill)
      ..drawCircle(centre, radius * 0.45, ink.drill)
      ..drawLine(
        centre,
        end,
        Paint()
          ..color = ink.copper
          ..strokeWidth = half * 2,
      );
  }
}

/// A double-headed arrow between two points, the way a drawing dimensions
/// anything.
void _arrow(Canvas canvas, Offset a, Offset b, _Ink ink, {bool above = false}) {
  final paint = ink.line(1.2);
  canvas.drawLine(a, b, paint);
  final along = (b - a);
  final length = along.distance;
  if (length < 1) return;
  final u = along / length;
  final n = Offset(-u.dy, u.dx) * 2.4;
  for (final (at, sense) in [(a, 1.0), (b, -1.0)]) {
    canvas
      ..drawLine(at, at + u * 3.2 * sense + n, paint)
      ..drawLine(at, at + u * 3.2 * sense - n, paint);
  }
  if (above) return;
}

/// A [RuleFigure] as a widget.
class RulePicture extends StatelessWidget {
  const RulePicture(
    this.figure, {
    super.key,
    this.width = 44,
    this.height = 32,
  });

  final RuleFigure figure;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      width: width,
      height: height,
      color: KicadPalette.background,
      child: CustomPaint(painter: _FigurePainter(figure)),
    ),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.figure);

  final RuleFigure figure;

  @override
  void paint(Canvas canvas, Size size) => figure.paint(canvas, size);

  @override
  bool shouldRepaint(_FigurePainter old) => old.figure != figure;
}

/// Solid, thermal or none, chosen by picture rather than by word.
class ConnectionPicker extends StatelessWidget {
  const ConnectionPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.via = false,
  });

  final PadConnection value;
  final ValueChanged<PadConnection> onChanged;
  final bool via;

  static const _why = {
    PadConnection.solid: 'Poured right up to it',
    PadConnection.thermal: 'Four spokes across a gap',
    PadConnection.none: 'Left clear, like another net',
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final choice in PadConnection.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              key: ValueKey('${via ? 'via' : 'pad'}-connection-${choice.name}'),
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(choice),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: choice == value
                        ? KicadPalette.highlight
                        : KicadPalette.textSecondary.withValues(alpha: 0.3),
                    width: choice == value ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RulePicture(
                      ConnectionFigure(choice, via: via),
                      width: double.infinity,
                      height: 34,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: choice == value ? KicadPalette.highlight : null,
                      ),
                    ),
                    Text(
                      _why[choice]!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.15,
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
