import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/symbols.dart';

/// The chip, drawn as a package with its pins on four sides.
///
/// The picture CubeMX shows and a datasheet's first page shows: one outline,
/// every pin in its place, and the ones that can do the job you are asking
/// about lit up. Built entirely from the symbol's own geometry — see
/// [PackageLayout] — so it works for any part whose library draws it as a
/// rectangle, which is every microcontroller KiCad ships.
class PackageDiagram extends StatelessWidget {
  const PackageDiagram({
    super.key,
    required this.layout,
    required this.title,
    this.highlighted = const {},
    this.assigned = const {},
    this.used = const {},
    this.selected,
    this.onPinTap,
  });

  final PackageLayout layout;

  /// Shown inside the outline, the way a part number is printed on a chip.
  final String title;

  /// Pin numbers that can carry the signal being asked about.
  final Set<String> highlighted;

  /// Pin number to the function it has been given, drawn beside the pin.
  final Map<String, String> assigned;

  /// Pin numbers already wired up in the project, dimmed.
  final Set<String> used;

  final String? selected;
  final ValueChanged<PackagePin>? onPinTap;

  @override
  Widget build(BuildContext context) {
    if (layout.isEmpty) {
      return Center(
        child: Text(
          'This part has no pins to draw.',
          style: TextStyle(color: KicadPalette.textSecondary),
        ),
      );
    }

    // Drawn at its own natural size and then scaled to fit, rather than
    // squeezed into the space available. A 48-pin package is a metre tall at
    // a readable pitch; shrinking the pitch instead just produced a drawing
    // that overflowed the screen and was clipped at both ends. Fitted, the
    // whole chip is visible at once — which is the point, since the answer
    // being looked for is a shape — and a pinch reads the names.
    final geometry = _DiagramGeometry.natural(layout);

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 9,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: geometry.size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final pin = geometry.pinAt(details.localPosition);
              if (pin == null) return;
              HapticFeedback.selectionClick();
              onPinTap?.call(pin);
            },
            child: CustomPaint(
              size: geometry.size,
              painter: _PackagePainter(
                geometry: geometry,
                title: title,
                highlighted: highlighted,
                assigned: assigned,
                used: used,
                selected: selected,
                palette: KicadPalette.current,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where every part of the drawing goes, computed once and shared by the
/// painter and the hit test so a pin is tappable exactly where it is drawn.
class _DiagramGeometry {
  _DiagramGeometry._({
    required this.body,
    required this.pitch,
    required this.stub,
    required this.size,
    required this.positions,
  });

  final Rect body;
  final double pitch;
  final double stub;

  /// The drawing's own size, outermost label to outermost label.
  final Size size;

  /// Each pin with the point its stub ends at, outside the body.
  final List<(PackagePin, Offset)> positions;

  /// One pin every [pitch] logical pixels, however many there are.
  static const pitchPx = 30.0;

  /// Room outside the body for a stub and the name beyond it. A KiCad pin
  /// name runs to about a dozen characters (`USB_OTG_FS_DP`), and a label
  /// clipped at the edge of the drawing is worse than no label.
  ///
  /// Less above and below: the drawing is fitted to a landscape screen, so
  /// height is what it is short of, and the pins that come out of the top
  /// and bottom of an MCU symbol are supplies with names like VBAT.
  static const gutter = 140.0;
  static const gutterY = 78.0;

  static const _stub = 22.0;

  static _DiagramGeometry natural(PackageLayout layout) {
    final left = layout.onSide(PackageSide.left);
    final right = layout.onSide(PackageSide.right);
    final top = layout.onSide(PackageSide.top);
    final bottom = layout.onSide(PackageSide.bottom);

    final rows = math.max(left.length, right.length);
    final columns = math.max(top.length, bottom.length);

    const pitch = pitchPx;
    const stub = _stub;

    final bodyHeight = math.max(rows + 1, 6) * pitch;
    // Width from the pins on the top and bottom — but never a ribbon. A
    // KiCad MCU symbol puts forty pins down its two sides and two across
    // the top, which sized honestly is a body one finger wide and a foot
    // tall: nothing like the chip, and no room for the part number across
    // the middle. The floor keeps it the shape of a package.
    final bodyWidth = math.max(
      math.max(columns + 1, 6) * pitch,
      bodyHeight * 0.62,
    );

    final size = Size(
      bodyWidth + gutter * 2,
      bodyHeight + gutterY * 2,
    );
    final body = Rect.fromLTWH(gutter, gutterY, bodyWidth, bodyHeight);

    final positions = <(PackagePin, Offset)>[];
    void place(List<PackagePin> pins, Offset Function(int index) at) {
      for (var i = 0; i < pins.length; i++) {
        positions.add((pins[i], at(i)));
      }
    }

    // Evenly spread along the edge rather than on the symbol's own pitch:
    // the drawing has to answer "which pin is next to which", and a gap in
    // the middle of a row only ever reads as a mistake.
    double span(int index, int count, double start, double length) =>
        start + length * (index + 1) / (count + 1);

    place(
      left,
      (i) => Offset(
        body.left - stub,
        span(i, left.length, body.top, body.height),
      ),
    );
    place(
      right,
      (i) => Offset(
        body.right + stub,
        span(i, right.length, body.top, body.height),
      ),
    );
    place(
      top,
      (i) => Offset(
        span(i, top.length, body.left, body.width),
        body.top - stub,
      ),
    );
    place(
      bottom,
      (i) => Offset(
        span(i, bottom.length, body.left, body.width),
        body.bottom + stub,
      ),
    );

    return _DiagramGeometry._(
      body: body,
      pitch: pitch,
      stub: stub,
      size: size,
      positions: positions,
    );
  }

  /// The pin whose stub or label is under [point].
  PackagePin? pinAt(Offset point) {
    PackagePin? best;
    var bestDistance = double.infinity;
    for (final (pin, at) in positions) {
      final distance = (at - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = pin;
      }
    }
    // A generous target: the stub is a hairline, and the label beside it is
    // what the eye is actually aiming at.
    return bestDistance <= math.max(24.0, pitch * 0.8) ? best : null;
  }
}

class _PackagePainter extends CustomPainter {
  _PackagePainter({
    required this.geometry,
    required this.title,
    required this.highlighted,
    required this.assigned,
    required this.used,
    required this.selected,
    required this.palette,
  });

  final _DiagramGeometry geometry;
  final String title;
  final Set<String> highlighted;
  final Map<String, String> assigned;
  final Set<String> used;
  final String? selected;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final body = geometry.body;

    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()..color = palette.symbolFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = palette.symbolOutline,
    );

    // The pin-1 dot, in the corner every package marks.
    canvas.drawCircle(
      body.topLeft + const Offset(16, 16),
      5,
      Paint()..color = palette.symbolOutline,
    );

    _text(
      canvas,
      title,
      at: body.center,
      color: palette.textPrimary,
      size: math.min(17.0, body.width / math.max(title.length, 8) * 1.4),
      align: _Anchor.centre,
    );

    for (final (pin, at) in geometry.positions) {
      _paintPin(canvas, pin, at);
    }
  }

  void _paintPin(Canvas canvas, PackagePin pin, Offset at) {
    final isHighlighted = highlighted.contains(pin.number);
    final isSelected = pin.number == selected;
    final isAssigned = assigned.containsKey(pin.number);
    final isUsed = used.contains(pin.number);

    final color = isSelected
        ? palette.highlight
        : isAssigned
        ? palette.success
        : isHighlighted
        ? palette.wire
        : isUsed
        ? palette.textDisabled
        : palette.pin;

    final body = geometry.body;
    final inner = switch (pin.side) {
      PackageSide.left => Offset(body.left, at.dy),
      PackageSide.right => Offset(body.right, at.dy),
      PackageSide.top => Offset(at.dx, body.top),
      PackageSide.bottom => Offset(at.dx, body.bottom),
    };

    canvas.drawLine(
      inner,
      at,
      Paint()
        ..strokeWidth = isHighlighted || isSelected || isAssigned ? 3.0 : 1.4
        ..color = color,
    );

    // A filled cap makes a lit pin readable at a glance across the whole
    // package, which a line weight alone does not.
    if (isHighlighted || isSelected || isAssigned) {
      canvas.drawCircle(at, 4.5, Paint()..color = color);
    }

    final label = assigned[pin.number] ?? pin.name;
    final size = math.max(9.0, math.min(13.0, geometry.pitch * 0.42));
    final numberSize = math.max(8.0, size - 2);

    switch (pin.side) {
      case PackageSide.left:
      case PackageSide.right:
        final outward = pin.side == PackageSide.left ? -1.0 : 1.0;
        _text(
          canvas,
          label,
          at: Offset(at.dx + outward * 8, at.dy),
          color: color,
          size: size,
          align: pin.side == PackageSide.left ? _Anchor.right : _Anchor.left,
        );
        _text(
          canvas,
          pin.number,
          at: Offset(inner.dx - outward * 8, at.dy),
          color: palette.pinNumber,
          size: numberSize,
          align: pin.side == PackageSide.left ? _Anchor.left : _Anchor.right,
        );
      case PackageSide.top:
      case PackageSide.bottom:
        // Turned on its side, as every package drawing does, so long names
        // do not collide with their neighbours two pins away.
        final outward = pin.side == PackageSide.top ? -1.0 : 1.0;
        canvas.save();
        canvas.translate(at.dx, at.dy + outward * 8);
        canvas.rotate(-math.pi / 2);
        _text(
          canvas,
          label,
          at: Offset.zero,
          color: color,
          size: size,
          align: pin.side == PackageSide.top ? _Anchor.left : _Anchor.right,
        );
        canvas.restore();

        canvas.save();
        canvas.translate(inner.dx, inner.dy - outward * 8);
        canvas.rotate(-math.pi / 2);
        _text(
          canvas,
          pin.number,
          at: Offset.zero,
          color: palette.pinNumber,
          size: numberSize,
          align: pin.side == PackageSide.top ? _Anchor.right : _Anchor.left,
        );
        canvas.restore();
    }
  }

  void _text(
    Canvas canvas,
    String text, {
    required Offset at,
    required Color color,
    required double size,
    required _Anchor align,
  }) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['monospace', 'Roboto Mono', 'Courier'],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = switch (align) {
      _Anchor.left => 0.0,
      _Anchor.right => -painter.width,
      _Anchor.centre => -painter.width / 2,
    };
    painter.paint(canvas, Offset(at.dx + dx, at.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_PackagePainter old) =>
      old.geometry != geometry ||
      old.title != title ||
      old.selected != selected ||
      old.palette != palette ||
      !setEquals(old.highlighted, highlighted) ||
      !setEquals(old.used, used) ||
      !mapEquals(old.assigned, assigned);
}

enum _Anchor { left, right, centre }
