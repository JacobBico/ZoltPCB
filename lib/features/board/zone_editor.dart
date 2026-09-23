import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import 'rule_diagrams.dart';

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
    this.priority = 0,
    this.padConnection = PadConnection.thermal,
    this.viaConnection = PadConnection.solid,
    this.thermalGap = 0.5,
    this.thermalSpoke = 0.5,
    this.keepout = false,
    this.noTracks = true,
    this.noVias = true,
    this.noPours = true,
    this.noParts = false,
  });

  final BoardLayer layer;
  final List<ui.Offset> points;
  final String? netId;
  final String netName;
  final double clearance;
  final double minThickness;
  final int priority;
  final PadConnection padConnection;
  final PadConnection viaConnection;
  final double thermalGap;
  final double thermalSpoke;
  final bool keepout;
  final bool noTracks;
  final bool noVias;
  final bool noPours;
  final bool noParts;

  /// [zone] with everything the editor sets.
  BoardZone applyTo(BoardZone zone) => zone.copyWith(
    layer: layer,
    points: points,
    netId: netId,
    clearNet: netId == null,
    netName: netName,
    clearance: clearance,
    minThickness: minThickness,
    priority: priority,
    padConnection: padConnection,
    viaConnection: viaConnection,
    thermalGap: thermalGap,
    thermalSpoke: thermalSpoke,
    keepout: keepout,
    noTracks: noTracks,
    noVias: noVias,
    noPours: noPours,
    noParts: noParts,
  );
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
  List<BoardLayer> layers = const [
    BoardLayer.frontCopper,
    BoardLayer.backCopper,
  ],
  bool keepout = false,
  BoardZone? zone,
}) => showDialog<ZoneResult>(
  context: context,
  builder: (context) => _ZoneEditor(
    outline: outline,
    nets: nets,
    defaultClearance: defaultClearance,
    layers: layers,
    keepout: keepout,
    zone: zone,
  ),
);

class _ZoneEditor extends StatefulWidget {
  const _ZoneEditor({
    required this.outline,
    required this.nets,
    required this.defaultClearance,
    this.layers = const [BoardLayer.frontCopper, BoardLayer.backCopper],
    this.keepout = false,
    this.zone,
  });

  final BoardOutline outline;
  final List<NetWithEndpoints> nets;
  final double defaultClearance;

  /// The copper this board actually has. A four-layer board pours its
  /// ground plane on an inner layer, and the editor that could only say
  /// "front or back" moved that pour to the back the moment it was opened.
  final List<BoardLayer> layers;

  /// Whether a new area starts out as a keepout rather than a pour.
  final bool keepout;

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
  late final TextEditingController _thermalGap;
  late final TextEditingController _thermalSpoke;
  late PadConnection _padConnection;
  late PadConnection _viaConnection;
  late bool _keepout;
  late bool _noTracks;
  late bool _noVias;
  late bool _noPours;
  late bool _noParts;
  late int _priority;

  /// Whether the pour follows the board edge. Kept as a mode rather than as
  /// a one-off action: a board that is resized afterwards should take its
  /// ground plane with it, and this is what remembers to.
  late bool _followsBoard;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _layer = zone?.layer ?? widget.layers.last;
    if (!widget.layers.contains(_layer)) _layer = widget.layers.last;
    _netId = zone?.netId ?? _likeliestGround()?.net.id;
    _clearance = TextEditingController(
      text: _mm(zone?.clearance ?? math.max(widget.defaultClearance * 2, 0.4)),
    );
    _minThickness = TextEditingController(
      text: _mm(zone?.minThickness ?? 0.25),
    );
    _thermalGap = TextEditingController(text: _mm(zone?.thermalGap ?? 0.5));
    _thermalSpoke = TextEditingController(text: _mm(zone?.thermalSpoke ?? 0.5));
    _padConnection = zone?.padConnection ?? PadConnection.thermal;
    _viaConnection = zone?.viaConnection ?? PadConnection.solid;
    _keepout = zone?.keepout ?? widget.keepout;
    _noTracks = zone?.noTracks ?? true;
    _noVias = zone?.noVias ?? true;
    _noPours = zone?.noPours ?? true;
    _noParts = zone?.noParts ?? false;
    _priority = zone?.priority ?? 0;
    _points = zone?.points ?? _boardShaped();
    _followsBoard = zone == null;
  }

  @override
  void dispose() {
    _clearance.dispose();
    _minThickness.dispose();
    _thermalGap.dispose();
    _thermalSpoke.dispose();
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

  double _value(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

  String? get _problem {
    if (_points.length < 3) return 'A pour needs at least three corners';
    if (_clearanceValue <= 0) return 'Clearance has to be greater than zero';
    if (_minThicknessValue <= 0) {
      return 'Minimum width has to be greater than zero';
    }
    if ((_padConnection == PadConnection.thermal ||
            _viaConnection == PadConnection.thermal) &&
        (_value(_thermalGap, 0) <= 0 || _value(_thermalSpoke, 0) <= 0)) {
      return 'Thermal gap and spoke have to be greater than zero';
    }
    return null;
  }

  /// A layer's name as a button can hold it.
  static CopperLayer? _copper(BoardLayer layer) =>
      CopperLayer.fromToken(layer.token);

  static String _short(BoardLayer layer) =>
      _copper(layer)?.shortLabel ?? layer.token;

  static String _long(BoardLayer layer) => _copper(layer)?.label ?? layer.token;

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
        priority: _priority,
        padConnection: _padConnection,
        viaConnection: _viaConnection,
        thermalGap: _value(_thermalGap, 0.5),
        thermalSpoke: _value(_thermalSpoke, 0.5),
        keepout: _keepout,
        noTracks: _noTracks,
        noVias: _noVias,
        noPours: _noPours,
        noParts: _noParts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _problem;

    return AlertDialog(
      title: Text(
        _keepout
            ? (widget.zone == null ? 'Add a keepout' : 'Keepout')
            : (widget.zone == null ? 'Add a copper pour' : 'Copper pour'),
      ),
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
                    SwitchListTile(
                      key: const ValueKey('zone-keepout'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _keepout,
                      title: const Text('Keepout'),
                      subtitle: Text(
                        'Claims the area instead of filling it',
                        style: TextStyle(color: KicadPalette.textSecondary),
                      ),
                      onChanged: (value) => setState(() => _keepout = value),
                    ),
                    if (_keepout) ...[
                      const SizedBox(height: 4),
                      Text(
                        'NOTHING IN HERE MAY BE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: KicadPalette.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      for (final (label, value, set) in [
                        ('A track', _noTracks, (bool v) => _noTracks = v),
                        ('A via', _noVias, (bool v) => _noVias = v),
                        ('A pour', _noPours, (bool v) => _noPours = v),
                        ('A part', _noParts, (bool v) => _noParts = v),
                      ])
                        CheckboxListTile(
                          key: ValueKey('keeps-out-$label'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: value,
                          title: Text(label),
                          onChanged: (v) => setState(() => set(v ?? false)),
                        ),
                    ],
                    if (!_keepout) ...[
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
                    ],
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
                      key: const ValueKey('zone-layer'),
                      showSelectedIcon: false,
                      segments: [
                        for (final layer in widget.layers)
                          ButtonSegment(
                            value: layer,
                            // Six names do not fit across a dialog; six
                            // short ones do.
                            label: Text(
                              widget.layers.length > 2
                                  ? _short(layer)
                                  : _long(layer),
                            ),
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
                    const SizedBox(height: 14),
                    if (!_keepout) ...[
                      Text(
                        'PADS ON THIS NET',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: KicadPalette.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConnectionPicker(
                        key: const ValueKey('zone-pad-connection'),
                        value: _padConnection,
                        onChanged: (value) =>
                            setState(() => _padConnection = value),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VIAS AND PLATED HOLES ON THIS NET',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: KicadPalette.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConnectionPicker(
                        key: const ValueKey('zone-via-connection'),
                        via: true,
                        value: _viaConnection,
                        onChanged: (value) =>
                            setState(() => _viaConnection = value),
                      ),
                      if (_padConnection == PadConnection.thermal ||
                          _viaConnection == PadConnection.thermal) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                _thermalGap,
                                'Thermal gap mm',
                                () {},
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _number(_thermalSpoke, 'Spoke mm', () {}),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (!_keepout) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Priority $_priority — where pours overlap, the '
                              'higher one is filled',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: KicadPalette.textSecondary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lower priority',
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _priority == 0
                                ? null
                                : () => setState(() => _priority--),
                          ),
                          IconButton(
                            key: const ValueKey('zone-priority-up'),
                            tooltip: 'Higher priority',
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => setState(() => _priority++),
                          ),
                        ],
                      ),
                    ],
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
                      title: Text(
                        _keepout
                            ? 'Cover the whole board'
                            : 'Fill the whole board',
                      ),
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
                        _keepout
                            ? 'Nothing stops a track being drawn through a '
                                  'keepout — the check says so afterwards, '
                                  'because stopping a finger mid-route is '
                                  'worse. KiCad calls this a rule area.'
                            : 'The board shows the pour filled round '
                                  'everything else, exactly as it goes into '
                                  'the Gerbers; KiCad refills it the same '
                                  'way when it opens the board.',
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
