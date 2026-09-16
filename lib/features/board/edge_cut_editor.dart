import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// What the editor came back with.
sealed class EdgeCutResult {
  const EdgeCutResult();
}

/// Save these points, as this kind of shape.
class EdgeCutSaved extends EdgeCutResult {
  const EdgeCutSaved({
    required this.kind,
    required this.points,
    required this.width,
  });

  final BoardEdgeKind kind;
  final List<ui.Offset> points;
  final double width;
}

/// Take this edge cut off the board.
class EdgeCutDeleted extends EdgeCutResult {
  const EdgeCutDeleted();
}

/// Adds or edits one shape on the Edge.Cuts layer, by typing its numbers.
///
/// Every coordinate is entered, not dragged. Dragging is how you get a slot
/// that is 5.87 mm long when the connector needs 6.00, and on a phone the
/// finger covers the thing being placed. The preview shows the board so the
/// numbers can be checked against the shape they make.
Future<EdgeCutResult?> showEdgeCutEditor(
  BuildContext context, {
  required BoardOutline outline,
  BoardEdge? edge,
}) => showDialog<EdgeCutResult>(
  context: context,
  builder: (context) => _EdgeCutEditor(outline: outline, edge: edge),
);

class _EdgeCutEditor extends StatefulWidget {
  const _EdgeCutEditor({required this.outline, this.edge});

  final BoardOutline outline;
  final BoardEdge? edge;

  @override
  State<_EdgeCutEditor> createState() => _EdgeCutEditorState();
}

class _EdgeCutEditorState extends State<_EdgeCutEditor> {
  late BoardEdgeKind _kind;
  late List<TextEditingController> _xs;
  late List<TextEditingController> _ys;

  /// Circles are stated as a centre and a radius here, even though they are
  /// stored as two points: nobody measures a mounting hole by the
  /// coordinates of a point on its rim.
  late final TextEditingController _radius;

  @override
  void initState() {
    super.initState();
    final edge = widget.edge;
    _kind = edge?.kind ?? BoardEdgeKind.line;
    _radius = TextEditingController(
      text: _mm(edge?.kind == BoardEdgeKind.circle ? edge!.radius : 3),
    );
    _xs = [];
    _ys = [];
    _seed(edge?.points ?? _defaultPoints(_kind));
  }

  @override
  void dispose() {
    for (final c in [..._xs, ..._ys, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Somewhere on the board, so a new shape is never off the edge of the
  /// world where it cannot be found.
  List<ui.Offset> _defaultPoints(BoardEdgeKind kind) {
    final centre = widget.outline.bounds.center;
    final span = math.min(widget.outline.bounds.width, 20) / 3;
    return switch (kind) {
      BoardEdgeKind.line => [
        centre - ui.Offset(span, 0),
        centre + ui.Offset(span, 0),
      ],
      BoardEdgeKind.arc => [
        centre - ui.Offset(span, 0),
        centre - ui.Offset(0, span),
        centre + ui.Offset(span, 0),
      ],
      BoardEdgeKind.rectangle => [
        centre - ui.Offset(span, span / 2),
        centre + ui.Offset(span, span / 2),
      ],
      BoardEdgeKind.circle => [centre, centre + ui.Offset(span, 0)],
      BoardEdgeKind.polygon => [
        centre - ui.Offset(span, span),
        centre + ui.Offset(span, -span),
        centre + ui.Offset(0, span),
      ],
    };
  }

  void _seed(List<ui.Offset> points) {
    for (final c in [..._xs, ..._ys]) {
      c.dispose();
    }
    _xs = [for (final p in points) TextEditingController(text: _mm(p.dx))];
    _ys = [for (final p in points) TextEditingController(text: _mm(p.dy))];
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(3);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  static double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// The points as typed, or null when a field does not read as a number.
  List<ui.Offset>? get _points {
    final points = <ui.Offset>[];
    for (var i = 0; i < _xs.length; i++) {
      final x = _parse(_xs[i]);
      final y = _parse(_ys[i]);
      if (x == null || y == null) return null;
      points.add(ui.Offset(x, y));
    }

    if (_kind == BoardEdgeKind.circle) {
      final r = _parse(_radius);
      if (r == null || r <= 0) return null;
      // Stored as centre plus a point on the rim, which is also how KiCad
      // states one.
      return [points.first, points.first + ui.Offset(r, 0)];
    }
    return points;
  }

  BoardEdge? get _preview {
    final points = _points;
    if (points == null) return null;
    final edge = BoardEdge(
      id: widget.edge?.id ?? 'preview',
      projectId: widget.edge?.projectId ?? '',
      kind: _kind,
      points: points,
      width: widget.edge?.width ?? 0.1,
    );
    return edge.isValid ? edge : null;
  }

  /// What is wrong with the numbers, in the user's terms.
  String? get _problem {
    if (_points == null) return 'Every box needs a number';
    final edge = _preview;
    if (edge == null) {
      return '${_kind.label} needs ${_kind.minimumPoints} points';
    }
    if (_kind == BoardEdgeKind.circle && edge.radius <= 0) {
      return 'A radius has to be greater than zero';
    }
    if (_kind == BoardEdgeKind.line &&
        (edge.start - edge.end).distance < 1e-6) {
      return 'A line needs two different points';
    }
    if (_kind == BoardEdgeKind.rectangle) {
      if (edge.bounds.width < 1e-6 || edge.bounds.height < 1e-6) {
        return 'A rectangle needs a width and a height';
      }
    }
    return null;
  }

  void _changeKind(BoardEdgeKind kind) {
    setState(() {
      final existing = _points;
      _kind = kind;
      // Keep what fits and fill in the rest, so switching from a line to an
      // arc keeps the two ends you already typed.
      if (existing != null && existing.length >= kind.minimumPoints) {
        _seed(existing.take(math.max(kind.minimumPoints, 2)).toList());
      } else if (existing != null && existing.length >= 2) {
        final filled = [...existing];
        while (filled.length < kind.minimumPoints) {
          filled.insert(
            1,
            ui.Offset(
              (filled.first.dx + filled.last.dx) / 2,
              (filled.first.dy + filled.last.dy) / 2 -
                  (filled.last - filled.first).distance / 4,
            ),
          );
        }
        _seed(filled);
      } else {
        _seed(_defaultPoints(kind));
      }
    });
  }

  void _addPoint() => setState(() {
    final points = _points ?? _defaultPoints(_kind);
    final last = points.last;
    final first = points.first;
    _seed([
      ...points,
      ui.Offset((last.dx + first.dx) / 2, (last.dy + first.dy) / 2),
    ]);
  });

  void _removePoint(int index) => setState(() {
    final points = _points ?? _defaultPoints(_kind);
    if (points.length <= _kind.minimumPoints) return;
    _seed([...points]..removeAt(index));
  });

  void _submit() {
    final points = _points;
    if (points == null || _problem != null) return;
    Navigator.of(context).pop(
      EdgeCutSaved(
        kind: _kind,
        points: points,
        width: widget.edge?.width ?? 0.1,
      ),
    );
  }

  /// Labels for the rows, which differ by shape: a rectangle has corners,
  /// an arc has a start, a point it passes through and an end.
  List<String> get _rowLabels => switch (_kind) {
    BoardEdgeKind.line => const ['From', 'To'],
    BoardEdgeKind.arc => const ['Start', 'Through', 'End'],
    BoardEdgeKind.rectangle => const ['Corner', 'Corner'],
    BoardEdgeKind.circle => const ['Centre'],
    BoardEdgeKind.polygon => const [],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _problem;
    final rows = _kind == BoardEdgeKind.circle ? 1 : _xs.length;

    return AlertDialog(
      title: Text(widget.edge == null ? 'Add an edge cut' : 'Edge cut'),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: SizedBox(
        width: 720,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final kind in BoardEdgeKind.values)
                          ChoiceChip(
                            label: Text(kind.label),
                            selected: kind == _kind,
                            onSelected: (_) => _changeKind(kind),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < rows; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                i < _rowLabels.length
                                    ? _rowLabels[i]
                                    : 'Point ${i + 1}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: KicadPalette.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(child: _number(_xs[i], 'X mm')),
                            const SizedBox(width: 8),
                            Expanded(child: _number(_ys[i], 'Y mm')),
                            if (_kind == BoardEdgeKind.polygon)
                              IconButton(
                                tooltip: 'Remove point',
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                onPressed: _xs.length > 3
                                    ? () => _removePoint(i)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    if (_kind == BoardEdgeKind.circle)
                      Row(
                        children: [
                          const SizedBox(width: 72),
                          Expanded(child: _number(_radius, 'Radius mm')),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    if (_kind == BoardEdgeKind.polygon)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addPoint,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('ADD POINT'),
                        ),
                      ),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          problem,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 45,
              child: AspectRatio(
                aspectRatio: 1.25,
                child: Container(
                  decoration: BoxDecoration(
                    color: KicadPalette.boardCanvas,
                    border: Border.all(color: KicadPalette.border),
                  ),
                  child: CustomPaint(
                    painter: _EdgePreviewPainter(
                      outline: widget.outline,
                      edge: _preview,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.edge != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const EdgeCutDeleted()),
            child: Text('DELETE', style: TextStyle(color: KicadPalette.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem == null ? _submit : null,
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  Widget _number(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (_) => setState(() {}),
  );
}

/// The board with the shape being typed drawn on it, so the numbers can be
/// checked against what they make.
class _EdgePreviewPainter extends CustomPainter {
  _EdgePreviewPainter({required this.outline, required this.edge});

  final BoardOutline outline;
  final BoardEdge? edge;

  @override
  void paint(Canvas canvas, Size size) {
    var extent = outline.bounds;
    final shape = edge;
    if (shape != null) extent = extent.expandToInclude(shape.bounds);
    if (extent.width <= 0 || extent.height <= 0) return;

    final scale = math.min(
      (size.width - 24) / extent.width,
      (size.height - 24) / extent.height,
    );
    final origin = Offset(
      (size.width - extent.width * scale) / 2 - extent.left * scale,
      (size.height - extent.height * scale) / 2 - extent.top * scale,
    );
    final matrix = Matrix4.identity().storage
      ..[0] = scale
      ..[5] = scale
      ..[12] = origin.dx
      ..[13] = origin.dy;

    // The board, faint: it is context for the shape, not the subject.
    final board = Path();
    if (outline.kind == BoardOutlineKind.circle) {
      board.addOval(
        Rect.fromCircle(center: outline.center, radius: outline.radius),
      );
    } else {
      final corners = outline.path;
      if (corners.length >= 2) {
        board.moveTo(corners.first.dx, corners.first.dy);
        for (final corner in corners.skip(1)) {
          board.lineTo(corner.dx, corner.dy);
        }
        board.close();
      }
    }
    canvas.drawPath(
      board.transform(matrix),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = KicadPalette.edgeCuts.withValues(alpha: 0.4),
    );

    if (shape == null) return;
    canvas.drawPath(
      shape.path.transform(matrix),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = KicadPalette.highlight,
    );
    for (final point in shape.points) {
      canvas.drawCircle(
        Offset(point.dx * scale + origin.dx, point.dy * scale + origin.dy),
        3,
        Paint()..color = KicadPalette.highlight,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePreviewPainter old) =>
      old.outline != outline ||
      old.edge?.points != edge?.points ||
      old.edge?.kind != edge?.kind;
}
