import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// What the loops are sized to reach.
enum TuneTarget {
  add('Add'),
  total('Total length'),
  match('Match a net'),
  delay('Delay');

  const TuneTarget(this.label);

  final String label;
}

/// Folds one straight track into loops until its net reaches a length.
///
/// Returns the plan to lay, or null if cancelled. The meander is always
/// worked out for the one segment chosen, and checked against the copper
/// around it before it is offered.
Future<MeanderPlan?> showMeanderDialog(
  BuildContext context, {
  required BoardScene scene,
  required Track track,
  required String netName,
}) => showDialog<MeanderPlan>(
  context: context,
  builder: (context) =>
      _MeanderDialog(scene: scene, track: track, netName: netName),
);

class _MeanderDialog extends StatefulWidget {
  const _MeanderDialog({
    required this.scene,
    required this.track,
    required this.netName,
  });

  final BoardScene scene;
  final Track track;
  final String netName;

  @override
  State<_MeanderDialog> createState() => _MeanderDialogState();
}

class _MeanderDialogState extends State<_MeanderDialog> {
  TuneTarget _target = TuneTarget.add;
  final _value = TextEditingController(text: '5');
  late final _amplitude = TextEditingController(
    text: _fmt(math.max(1.0, _spacing0 * 2)),
  );
  late final _spacing = TextEditingController(text: _fmt(_spacing0));
  MeanderSide _side = MeanderSide.both;
  MeanderCorner _corner = MeanderCorner.chamfered;
  String? _matchNetId;

  late final double _spacing0 = Meander.defaultSpacing(
    widget.track.width,
    widget.scene.clearanceFor(widget.track.netId),
  );

  late final NetLength _current = NetLength.of(
    widget.scene,
    widget.track.netId ?? '',
  );

  /// Picoseconds per millimetre on this track's layer at its width.
  late final double _speed = NetLength.delayPerMm(
    widget.scene.board.stackup,
    widget.track.layer,
    widget.track.width,
  );

  /// Other routed nets, longest first — the ones worth matching to.
  late final List<(String, String, NetLength)> _others = () {
    final names = <String, String>{
      for (final pad in widget.scene.pads)
        if (pad.netId != null) pad.netId!: pad.netName ?? '',
    };
    final ids = {
      for (final t in widget.scene.tracks)
        if (t.netId != null && t.netId != widget.track.netId) t.netId!,
    };
    final list = [
      for (final id in ids)
        (id, names[id] ?? 'Net', NetLength.of(widget.scene, id)),
    ]..sort((a, b) => b.$3.length.compareTo(a.$3.length));
    return list;
  }();

  @override
  void dispose() {
    _value.dispose();
    _amplitude.dispose();
    _spacing.dispose();
    super.dispose();
  }

  static String _fmt(double value, [int places = 2]) {
    final text = value.toStringAsFixed(places);
    return text.contains('.')
        ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : text;
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// How much longer the net has to get, in millimetres.
  double? get _extra {
    switch (_target) {
      case TuneTarget.add:
        return _parse(_value);
      case TuneTarget.total:
        final total = _parse(_value);
        return total == null ? null : total - _current.length;
      case TuneTarget.match:
        final other = _others.where((o) => o.$1 == _matchNetId).firstOrNull;
        return other == null ? null : other.$3.length - _current.length;
      case TuneTarget.delay:
        final ps = _parse(_value);
        return ps == null ? null : (ps - _current.delayPs) / _speed;
    }
  }

  MeanderPlan? get _plan {
    final extra = _extra;
    final amplitude = _parse(_amplitude);
    final spacing = _parse(_spacing);
    if (extra == null || amplitude == null || spacing == null) return null;
    return Meander.plan(
      a: Offset(widget.track.startX, widget.track.startY),
      b: Offset(widget.track.endX, widget.track.endY),
      extra: extra,
      maxAmplitude: amplitude,
      spacing: spacing,
      side: _side,
      corner: _corner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final extra = _extra;
    final clashes = plan != null && plan.isValid
        ? routeClashes(
            widget.scene,
            route: plan.points,
            width: widget.track.width,
            layer: widget.track.layer,
            netId: widget.track.netId,
          )
        : const <RouteClash>[];
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))];
    InputDecoration field(String label, String suffix) =>
        InputDecoration(labelText: label, suffixText: suffix, isDense: true);
    final secondary = TextStyle(
      fontSize: 12,
      color: KicadPalette.textSecondary,
    );

    return AlertDialog(
      title: Text('Tune ${widget.netName.isEmpty ? 'track' : widget.netName}'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Now ${_fmt(_current.length)} mm · '
                      '${_fmt(_current.delayPs, 0)} ps · this segment '
                      '${_fmt(widget.track.lengthMm)} mm',
                      style: secondary,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final target in TuneTarget.values)
                          ChoiceChip(
                            label: Text(target.label),
                            selected: target == _target,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() {
                              _target = target;
                              if (target == TuneTarget.total) {
                                _value.text = _fmt(_current.length + 5);
                              } else if (target == TuneTarget.delay) {
                                _value.text = _fmt(_current.delayPs + 30, 0);
                              } else if (target == TuneTarget.add) {
                                _value.text = '5';
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_target == TuneTarget.match)
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _matchNetId,
                        hint: Text(
                          _others.isEmpty
                              ? 'No other routed nets'
                              : 'Choose a net to match',
                        ),
                        items: [
                          for (final (id, name, length) in _others)
                            DropdownMenuItem(
                              value: id,
                              child: Text('$name · ${_fmt(length.length)} mm'),
                            ),
                        ],
                        onChanged: (id) => setState(() => _matchNetId = id),
                      )
                    else
                      TextField(
                        key: const ValueKey('meander-value'),
                        controller: _value,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: numbers,
                        decoration: field(switch (_target) {
                          TuneTarget.add => 'Extra length',
                          TuneTarget.total => 'Net length',
                          _ => 'Net delay',
                        }, _target == TuneTarget.delay ? 'ps' : 'mm'),
                        onChanged: (_) => setState(() {}),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('meander-amplitude'),
                            controller: _amplitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            decoration: field('Max height', 'mm'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('meander-spacing'),
                            controller: _spacing,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            decoration: field('Spacing', 'mm'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final side in MeanderSide.values)
                          ChoiceChip(
                            label: Text(side.label),
                            selected: side == _side,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _side = side),
                          ),
                        const SizedBox(width: 8),
                        for (final corner in MeanderCorner.values)
                          ChoiceChip(
                            label: Text(corner.label),
                            selected: corner == _corner,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _corner = corner),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: KicadPalette.boardCanvas,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _MeanderPreview(
                          track: widget.track,
                          plan: plan,
                          clashes: clashes,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (plan == null || extra == null)
                      Text('Enter a target', style: secondary)
                    else if (!plan.isValid)
                      Text(
                        plan.problem ?? 'Cannot tune this segment',
                        key: const ValueKey('meander-problem'),
                        style: TextStyle(
                          color: KicadPalette.warning,
                          fontSize: 12,
                        ),
                      )
                    else ...[
                      Text(
                        '+${_fmt(plan.added)} mm → '
                        '${_fmt(_current.length + plan.added)} mm',
                        key: const ValueKey('meander-result'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${plan.loops} loop${plan.loops == 1 ? '' : 's'}, '
                        '${_fmt(plan.amplitude)} mm high · '
                        '${_fmt(_current.delayPs + plan.added * _speed, 0)} ps',
                        style: secondary,
                      ),
                      if (clashes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Too close to other copper in '
                            '${clashes.length} place${clashes.length == 1 ? '' : 's'} '
                            '— try the other side or a lower height',
                            style: TextStyle(
                              color: KicadPalette.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          key: const ValueKey('meander-apply'),
          onPressed: plan != null && plan.isValid
              ? () => Navigator.of(context).pop(plan)
              : null,
          child: const Text('ADD LOOPS'),
        ),
      ],
    );
  }
}

class _MeanderPreview extends CustomPainter {
  _MeanderPreview({
    required this.track,
    required this.plan,
    required this.clashes,
  });

  final Track track;
  final MeanderPlan? plan;
  final List<RouteClash> clashes;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(track.startX, track.startY);
    final b = Offset(track.endX, track.endY);
    final points = plan != null && plan!.isValid ? plan!.points : [a, b];
    var bounds = Rect.fromPoints(a, b);
    for (final p in points) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    bounds = bounds.inflate(math.max(track.width * 2, 0.5));
    final scale = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );
    final offset = Offset(
      (size.width - bounds.width * scale) / 2,
      (size.height - bounds.height * scale) / 2,
    );
    Offset map(Offset p) => (p - bounds.topLeft) * scale + offset;

    final paint = Paint()
      ..color = BoardPainter.colorFor(track.layer)
      ..strokeWidth = math.max(1.5, track.width * scale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(map(points.first).dx, map(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(map(p).dx, map(p).dy);
    }
    canvas.drawPath(path, paint);
    for (final clash in clashes) {
      canvas.drawCircle(map(clash.at), 4, Paint()..color = KicadPalette.error);
    }
  }

  @override
  bool shouldRepaint(_MeanderPreview old) =>
      old.plan != plan || old.track != track || old.clashes != clashes;
}
