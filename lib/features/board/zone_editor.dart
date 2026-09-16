import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';

/// What the zone editor came back with.
sealed class ZoneResult {
  const ZoneResult();
}

class ZoneSaved extends ZoneResult {
  const ZoneSaved({
    required this.layer,
    required this.points,
    required this.netId,
    required this.netName,
    required this.clearance,
    required this.minThickness,
  });

  final BoardLayer layer;
  final List<ui.Offset> points;
  final String? netId;
  final String netName;
  final double clearance;
  final double minThickness;
}

class ZoneDeleted extends ZoneResult {
  const ZoneDeleted();
}

/// Adds or edits a copper pour.
///
/// The common case is one tap: a ground plane filling the board. That is
/// what the dialog opens on — the board outline, inset by the clearance,
/// on the back, tied to whichever net looks most like a ground — and
/// everything else is there to be changed when the design needs it.
Future<ZoneResult?> showZoneEditor(
  BuildContext context, {
  required BoardOutline outline,
  required List<NetWithEndpoints> nets,
  required double defaultClearance,
  BoardZone? zone,
}) => showDialog<ZoneResult>(
  context: context,
  builder: (context) => _ZoneEditor(
    outline: outline,
    nets: nets,
    defaultClearance: defaultClearance,
    zone: zone,
  ),
);

class _ZoneEditor extends StatefulWidget {
  const _ZoneEditor({
    required this.outline,
    required this.nets,
    required this.defaultClearance,
    this.zone,
  });

  final BoardOutline outline;
  final List<NetWithEndpoints> nets;
  final double defaultClearance;
  final BoardZone? zone;

  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  late BoardLayer _layer;
  late String? _netId;
  late List<ui.Offset> _points;
  late final TextEditingController _clearance;
  late final TextEditingController _minThickness;

  /// Whether the pour follows the board edge. Kept as a mode rather than as
  /// a one-off action: a board that is resized afterwards should take its
  /// ground plane with it, and this is what remembers to.
  late bool _followsBoard;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _layer = zone?.layer ?? BoardLayer.backCopper;
    _netId = zone?.netId ?? _likeliestGround()?.net.id;
    _clearance = TextEditingController(
      text: _mm(zone?.clearance ?? math.max(widget.defaultClearance * 2, 0.4)),
    );
    _minThickness = TextEditingController(
      text: _mm(zone?.minThickness ?? 0.25),
    );
    _points = zone?.points ?? _boardShaped();
    _followsBoard = zone == null;
  }

  @override
  void dispose() {
    _clearance.dispose();
    _minThickness.dispose();
    super.dispose();
  }

  /// The net a pour is most likely meant for. Ground, overwhelmingly: it is
  /// the reason planes exist.
  NetWithEndpoints? _likeliestGround() {
    for (final wanted in ['GND', 'GNDA', 'AGND', 'DGND', 'VSS']) {
      for (final net in widget.nets) {
        if ((net.net.name ?? '').toUpperCase() == wanted) return net;
      }
    }
    return null;
  }

  /// The board outline pulled in by the clearance, which is what a plane
  /// almost always wants to be.
  List<ui.Offset> _boardShaped() {
    final inset = double.tryParse(_clearance.text.trim()) ?? 0.5;
    final outline = widget.outline;

    if (outline.kind == BoardOutlineKind.circle) {
      // A circle has to become a polygon to be a zone at all; 48 sides is
      // past the point where anyone can see the difference in copper.
      final r = math.max(outline.radius - inset, 0.1);
      return [
        for (var i = 0; i < 48; i++)
          outline.center +
              ui.Offset(
                r * math.cos(i * 2 * math.pi / 48),
                r * math.sin(i * 2 * math.pi / 48),
              ),
      ];
    }

    final corners = outline.path;
    if (corners.length < 3) {
      final rect = outline.bounds.deflate(inset);
      return [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
    }

    // Pulled towards the middle rather than properly offset. A true polygon
    // offset is a different problem — it can drop corners and split the
    // shape — and for a board edge this is within a hair of it.
    final centre = outline.bounds.center;
    return [
      for (final corner in corners)
        () {
          final away = corner - centre;
          final length = away.distance;
          if (length <= inset) return corner;
          return centre + away * ((length - inset) / length);
        }(),
    ];
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(3);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  double get _clearanceValue =>
      double.tryParse(_clearance.text.trim().replaceAll(',', '.')) ?? 0.5;

  double get _minThicknessValue =>
      double.tryParse(_minThickness.text.trim().replaceAll(',', '.')) ?? 0.25;

  String? get _problem {
    if (_points.length < 3) return 'A pour needs at least three corners';
    if (_clearanceValue <= 0) return 'Clearance has to be greater than zero';
    if (_minThicknessValue <= 0) {
      return 'Minimum width has to be greater than zero';
    }
    return null;
  }

  NetWithEndpoints? get _net =>
      widget.nets.where((n) => n.net.id == _netId).firstOrNull;

  void _submit() {
    if (_problem != null) return;
    Navigator.of(context).pop(
      ZoneSaved(
        layer: _layer,
        points: _points,
        netId: _netId,
        netName: _net?.displayName ?? '',
        clearance: _clearanceValue,
        minThickness: _minThicknessValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _problem;

    return AlertDialog(
      title: Text(widget.zone == null ? 'Add a copper pour' : 'Copper pour'),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: SizedBox(
        width: 720,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 58,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NET',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: KicadPalette.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: _netId,
                      isExpanded: true,
                      dropdownColor: KicadPalette.surfaceRaised,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        const DropdownMenuItem(
                          child: Text('No net — unconnected copper'),
                        ),
                        for (final net in widget.nets)
                          DropdownMenuItem(
                            value: net.net.id,
                            child: Text(
                              net.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _netId = value),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'LAYER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: KicadPalette.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<BoardLayer>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: BoardLayer.frontCopper,
                          label: Text('Front'),
                        ),
                        ButtonSegment(
                          value: BoardLayer.backCopper,
                          label: Text('Back'),
                        ),
                      ],
                      selected: {_layer},
                      onSelectionChanged: (value) =>
                          setState(() => _layer = value.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _number(_clearance, 'Clearance mm', () {
                            if (_followsBoard) _points = _boardShaped();
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _number(_minThickness, 'Min width mm', () {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: _followsBoard,
                      onChanged: (value) => setState(() {
                        _followsBoard = value ?? false;
                        if (_followsBoard) _points = _boardShaped();
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Fill the whole board'),
                      subtitle: Text(
                        'The board edge, pulled in by the clearance — '
                        '${_points.length} corners',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textSecondary,
                        ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        'KiCad works out the actual copper when it opens '
                        'the board — this is the region to pour into, not '
                        'the fill itself.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 42,
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Container(
                  decoration: BoxDecoration(
                    color: KicadPalette.boardCanvas,
                    border: Border.all(color: KicadPalette.border),
                  ),
                  child: CustomPaint(
                    painter: _ZonePreviewPainter(
                      outline: widget.outline,
                      points: _points,
                      layer: _layer,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.zone != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const ZoneDeleted()),
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

  Widget _number(
    TextEditingController controller,
    String label,
    VoidCallback onChanged,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (_) => setState(onChanged),
  );
}

class _ZonePreviewPainter extends CustomPainter {
  _ZonePreviewPainter({
    required this.outline,
    required this.points,
    required this.layer,
  });

  final BoardOutline outline;
  final List<ui.Offset> points;
  final BoardLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = outline.bounds;
    if (extent.width <= 0 || extent.height <= 0) return;

    final scale = math.min(
      (size.width - 20) / extent.width,
      (size.height - 20) / extent.height,
    );
    Offset at(ui.Offset point) => Offset(
      (point.dx - extent.left) * scale +
          (size.width - extent.width * scale) / 2,
      (point.dy - extent.top) * scale +
          (size.height - extent.height * scale) / 2,
    );

    final board = Path();
    final corners = outline.kind == BoardOutlineKind.circle
        ? [
            for (var i = 0; i < 48; i++)
              outline.center +
                  ui.Offset(
                    outline.radius * math.cos(i * 2 * math.pi / 48),
                    outline.radius * math.sin(i * 2 * math.pi / 48),
                  ),
          ]
        : outline.path;
    if (corners.length >= 2) {
      board.moveTo(at(corners.first).dx, at(corners.first).dy);
      for (final corner in corners.skip(1)) {
        board.lineTo(at(corner).dx, at(corner).dy);
      }
      board.close();
    }
    canvas.drawPath(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = KicadPalette.edgeCuts.withValues(alpha: 0.5),
    );

    if (points.length < 3) return;
    final pour = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      pour.lineTo(at(point).dx, at(point).dy);
    }
    pour.close();

    final colour = layer == BoardLayer.frontCopper
        ? KicadPalette.frontCopper
        : KicadPalette.backCopper;
    canvas.drawPath(pour, Paint()..color = colour.withValues(alpha: 0.25));
    canvas.drawPath(
      pour,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_ZonePreviewPainter old) =>
      old.points != points || old.layer != layer || old.outline != outline;
}
