import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// Edits the board edge by the numbers.
///
/// Dragging corners is fine for roughing a shape out and hopeless for
/// hitting 50.0 × 30.0 mm, which is what a board is actually ordered at.
/// Here every dimension is typed: width and height, a diameter, or the
/// corners of a polygon one by one — with a live preview, and presets for
/// the shapes people reach for.
Future<BoardOutline?> showBoardShapeEditor(
  BuildContext context, {
  required BoardOutline outline,
}) {
  return showDialog<BoardOutline>(
    context: context,
    builder: (context) => _BoardShapeEditor(outline: outline),
  );
}

class _BoardShapeEditor extends StatefulWidget {
  const _BoardShapeEditor({required this.outline});

  final BoardOutline outline;

  @override
  State<_BoardShapeEditor> createState() => _BoardShapeEditorState();
}

class _BoardShapeEditorState extends State<_BoardShapeEditor> {
  late BoardOutlineKind _kind;

  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _diameter;

  /// Polygon corners, relative to the shape's top-left corner — board
  /// coordinates would mean nothing to anyone typing them.
  final _xs = <TextEditingController>[];
  final _ys = <TextEditingController>[];

  /// Where the shape sits on the board, kept through every edit so a new
  /// size does not also move the board.
  late Offset _origin;

  @override
  void initState() {
    super.initState();
    final outline = widget.outline;
    _kind = outline.kind;
    final bounds = outline.bounds;
    _origin = bounds.topLeft;

    _width = TextEditingController(text: _mm(bounds.width));
    _height = TextEditingController(text: _mm(bounds.height));
    _diameter = TextEditingController(
      text: _mm(
        outline.kind == BoardOutlineKind.circle
            ? outline.radius * 2
            : math.min(bounds.width, bounds.height),
      ),
    );
    _setCorners(
      outline.kind == BoardOutlineKind.polygon
          ? outline.points
          : outline.as(BoardOutlineKind.polygon).points,
    );
  }

  @override
  void dispose() {
    for (final c in [_width, _height, _diameter, ..._xs, ..._ys]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(2);
    return text
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _setCorners(List<Offset> absolute) {
    for (final c in [..._xs, ..._ys]) {
      c.dispose();
    }
    _xs.clear();
    _ys.clear();
    for (final point in absolute) {
      _xs.add(TextEditingController(text: _mm(point.dx - _origin.dx)));
      _ys.add(TextEditingController(text: _mm(point.dy - _origin.dy)));
    }
  }

  /// The shape as currently typed, or null with a reason when it cannot be
  /// made.
  (BoardOutline?, String?) _build() {
    switch (_kind) {
      case BoardOutlineKind.rectangle:
        final w = _parse(_width);
        final h = _parse(_height);
        if (w == null || h == null) return (null, 'Width and height, in mm');
        if (w <= 0 || h <= 0) return (null, 'A board needs some area');
        return (
          BoardOutline.rectangle(Rect.fromLTWH(_origin.dx, _origin.dy, w, h)),
          null,
        );

      case BoardOutlineKind.circle:
        final d = _parse(_diameter);
        if (d == null) return (null, 'The diameter, in mm');
        if (d <= 0) return (null, 'A board needs some area');
        return (
          BoardOutline.circle(Rect.fromLTWH(_origin.dx, _origin.dy, d, d)),
          null,
        );

      case BoardOutlineKind.polygon:
        final points = <Offset>[];
        for (var i = 0; i < _xs.length; i++) {
          final x = _parse(_xs[i]);
          final y = _parse(_ys[i]);
          if (x == null || y == null) {
            return (null, 'Corner ${i + 1} needs both an X and a Y');
          }
          points.add(Offset(_origin.dx + x, _origin.dy + y));
        }
        if (points.length < 3) return (null, 'A shape needs three corners');
        if (_selfIntersects(points)) {
          return (null, 'The edges cross each other — reorder the corners');
        }
        return (BoardOutline.polygon(points), null);
    }
  }

  /// Whether any two non-adjacent edges cross. A board edge that crosses
  /// itself cannot be milled, and KiCad refuses to fill such an outline.
  static bool _selfIntersects(List<Offset> points) {
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    bool intersects(Offset a1, Offset a2, Offset b1, Offset b2) {
      final d1 = cross(b1, b2, a1);
      final d2 = cross(b1, b2, a2);
      final d3 = cross(a1, a2, b1);
      final d4 = cross(a1, a2, b2);
      return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
    }

    final n = points.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        // Neighbouring edges share a corner and always "touch".
        if (j == i + 1 || (i == 0 && j == n - 1)) continue;
        if (intersects(
          points[i],
          points[(i + 1) % n],
          points[j],
          points[(j + 1) % n],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Presets, sized to the board as it is now so picking one does not
  /// throw away the dimensions already chosen.
  void _preset(String name) {
    final w = _parse(_width) ?? 50;
    final h = _parse(_height) ?? 30;
    final o = _origin;
    final List<Offset> corners = switch (name) {
      'Triangle' => [
        Offset(o.dx + w / 2, o.dy),
        Offset(o.dx + w, o.dy + h),
        Offset(o.dx, o.dy + h),
      ],
      'Hexagon' => [
        for (var i = 0; i < 6; i++)
          Offset(
            o.dx + w / 2 + w / 2 * math.cos(i * math.pi / 3),
            o.dy + h / 2 + h / 2 * math.sin(i * math.pi / 3),
          ),
      ],
      'L-shape' => [
        o,
        Offset(o.dx + w, o.dy),
        Offset(o.dx + w, o.dy + h / 2),
        Offset(o.dx + w / 2, o.dy + h / 2),
        Offset(o.dx + w / 2, o.dy + h),
        Offset(o.dx, o.dy + h),
      ],
      _ => [
        o,
        Offset(o.dx + w, o.dy),
        Offset(o.dx + w, o.dy + h),
        Offset(o.dx, o.dy + h),
      ],
    };
    setState(() => _setCorners(corners));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (outline, problem) = _build();
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SizedBox(
        width: math.min(760, size.width - 48),
        height: size.height - 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Board shape', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  SegmentedButton<BoardOutlineKind>(
                    showSelectedIcon: false,
                    segments: [
                      for (final kind in BoardOutlineKind.values)
                        ButtonSegment(value: kind, label: Text(kind.label)),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (value) =>
                        setState(() => _kind = value.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _fields(theme)),
                    const SizedBox(width: 16),
                    // The shape as typed, redrawn on every keystroke — the
                    // quickest way to notice a corner in the wrong place.
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KicadPalette.boardCanvas,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: KicadPalette.border),
                        ),
                        child: CustomPaint(
                          painter: _OutlinePreviewPainter(outline),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      problem ??
                          (outline == null
                              ? ''
                              : '${_mm(outline.bounds.width)} × '
                                    '${_mm(outline.bounds.height)} mm'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: problem == null
                            ? KicadPalette.textSecondary
                            : KicadPalette.warning,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: outline == null
                        ? null
                        : () => Navigator.of(context).pop(outline),
                    child: const Text('APPLY'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fields(ThemeData theme) {
    switch (_kind) {
      case BoardOutlineKind.rectangle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _field(_width, 'Width')),
                const SizedBox(width: 12),
                Expanded(child: _field(_height, 'Height')),
              ],
            ),
          ],
        );

      case BoardOutlineKind.circle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_field(_diameter, 'Diameter')],
        );

      case BoardOutlineKind.polygon:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in const [
                  'Rectangle',
                  'Triangle',
                  'Hexagon',
                  'L-shape',
                ])
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => _preset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Corners in mm, from the top-left of the shape, in order '
              'round the edge.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: _xs.length + 1,
                itemBuilder: (context, i) {
                  if (i == _xs.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          // A new corner halfway back to the first, so the
                          // shape stays closed and nothing jumps.
                          final last = Offset(
                            _parse(_xs.last) ?? 0,
                            _parse(_ys.last) ?? 0,
                          );
                          final first = Offset(
                            _parse(_xs.first) ?? 0,
                            _parse(_ys.first) ?? 0,
                          );
                          final mid = Offset.lerp(last, first, 0.5)!;
                          _xs.add(TextEditingController(text: _mm(mid.dx)));
                          _ys.add(TextEditingController(text: _mm(mid.dy)));
                        }),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add corner'),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: KicadPalette.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(child: _field(_xs[i], 'X')),
                        const SizedBox(width: 8),
                        Expanded(child: _field(_ys[i], 'Y')),
                        IconButton(
                          tooltip: 'Remove corner',
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: _xs.length <= 3
                              ? null
                              : () => setState(() {
                                  _xs.removeAt(i).dispose();
                                  _ys.removeAt(i).dispose();
                                }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _field(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'mm',
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        onChanged: (_) => setState(() {}),
      );
}

/// The outline being typed, fitted to the preview box.
class _OutlinePreviewPainter extends CustomPainter {
  _OutlinePreviewPainter(this.outline) : palette = KicadPalette.current;

  final BoardOutline? outline;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline;
    if (shape == null) return;
    final bounds = shape.bounds;
    if (bounds.width <= 0 || bounds.height <= 0) return;

    const margin = 16.0;
    final scale = math.min(
      (size.width - margin * 2) / bounds.width,
      (size.height - margin * 2) / bounds.height,
    );
    Offset map(Offset p) => Offset(
      margin + (p.dx - bounds.left) * scale +
          (size.width - margin * 2 - bounds.width * scale) / 2,
      margin + (p.dy - bounds.top) * scale +
          (size.height - margin * 2 - bounds.height * scale) / 2,
    );

    final paint = Paint()
      ..color = palette.edgeCuts
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = palette.edgeCuts.withValues(alpha: 0.08);

    if (shape.kind == BoardOutlineKind.circle) {
      final centre = map(shape.center);
      canvas
        ..drawCircle(centre, shape.radius * scale, fill)
        ..drawCircle(centre, shape.radius * scale, paint);
      return;
    }

    final corners = shape.path;
    final path = Path()..moveTo(map(corners.first).dx, map(corners.first).dy);
    for (final c in corners.skip(1)) {
      path.lineTo(map(c).dx, map(c).dy);
    }
    path.close();
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, paint);

    // Corner numbers, matching the list, so "corner 4" can be found.
    if (shape.kind == BoardOutlineKind.polygon) {
      for (var i = 0; i < corners.length; i++) {
        final p = map(corners[i]);
        canvas.drawCircle(p, 3, Paint()..color = palette.highlight);
        final label = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(color: palette.textPrimary, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, p + const Offset(5, -12));
      }
    }
  }

  @override
  bool shouldRepaint(_OutlinePreviewPainter old) =>
      old.outline != outline || old.palette != palette;
}
