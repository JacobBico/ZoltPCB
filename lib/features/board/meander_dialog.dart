import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// What the loops are sized to reach.
enum TuneTarget {
  add('Add', Icons.add),
  total('Total', Icons.straighten),
  match('Match', Icons.compare_arrows),
  delay('Delay', Icons.timer_outlined);

  const TuneTarget(this.label, this.icon);

  final String label;
  final IconData icon;
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
  MeanderSide _side = MeanderSide.both;
  MeanderCorner _corner = MeanderCorner.chamfered;
  String? _matchNetId;

  late final double _minSpacing =
      widget.track.width + widget.scene.clearanceFor(widget.track.netId);
  late double _spacing = Meander.defaultSpacing(
    widget.track.width,
    widget.scene.clearanceFor(widget.track.netId),
  );
  late double _amplitude = math.max(1.0, _spacing * 2);

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
    return [
      for (final id in ids)
        (id, names[id] ?? 'Net', NetLength.of(widget.scene, id)),
    ]..sort((a, b) => b.$3.length.compareTo(a.$3.length));
  }();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  static String _fmt(double value, [int places = 2]) {
    final text = value.toStringAsFixed(places);
    return text.contains('.')
        ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : text;
  }

  double? get _typed =>
      double.tryParse(_value.text.trim().replaceAll(',', '.'));

  /// How much longer the net has to get, in millimetres.
  double? get _extra {
    switch (_target) {
      case TuneTarget.add:
        return _typed;
      case TuneTarget.total:
        final total = _typed;
        return total == null ? null : total - _current.length;
      case TuneTarget.match:
        final other = _others.where((o) => o.$1 == _matchNetId).firstOrNull;
        return other == null ? null : other.$3.length - _current.length;
      case TuneTarget.delay:
        final ps = _typed;
        return ps == null ? null : (ps - _current.delayPs) / _speed;
    }
  }

  MeanderPlan? get _plan {
    final extra = _extra;
    if (extra == null) return null;
    return Meander.plan(
      a: Offset(widget.track.startX, widget.track.startY),
      b: Offset(widget.track.endX, widget.track.endY),
      extra: extra,
      maxAmplitude: _amplitude,
      spacing: _spacing,
      side: _side,
      corner: _corner,
    );
  }

  void _pickTarget(TuneTarget target) => setState(() {
    _target = target;
    _value.text = switch (target) {
      TuneTarget.add => '5',
      TuneTarget.total => _fmt(_current.length + 5),
      TuneTarget.delay => _fmt(_current.delayPs + 30, 0),
      TuneTarget.match => _value.text,
    };
    if (target == TuneTarget.match && _matchNetId == null) {
      // The longest other net is almost always the one to match.
      _matchNetId = _others.firstOrNull?.$1;
    }
  });

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
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.waves, size: 20, color: KicadPalette.highlight),
                  const SizedBox(width: 8),
                  Text(
                    'Tune ${widget.netName.isEmpty ? 'track' : widget.netName}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'segment ${_fmt(widget.track.lengthMm)} mm on '
                    '${widget.track.layer.label}',
                    style: secondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KicadPalette.boardCanvas,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: KicadPalette.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _MeanderPreview(
                                    track: widget.track,
                                    plan: plan,
                                    clashes: clashes,
                                    amplitude: _amplitude,
                                    spacing: _spacing,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LengthBar(
                            now: _current.length,
                            extra: extra,
                            added: plan != null && plan.isValid
                                ? plan.added
                                : 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: _controls(context, secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _status(plan, extra, clashes)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    key: const ValueKey('meander-apply'),
                    onPressed: plan != null && plan.isValid
                        ? () => Navigator.of(context).pop(plan)
                        : null,
                    icon: const Icon(Icons.waves, size: 16),
                    label: const Text('ADD LOOPS'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, TextStyle? secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TuneTarget>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final target in TuneTarget.values)
              ButtonSegment(
                value: target,
                icon: Icon(target.icon, size: 16),
                label: Text(target.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
          selected: {_target},
          onSelectionChanged: (value) => _pickTarget(value.first),
        ),
        const SizedBox(height: 10),
        if (_target == TuneTarget.match)
          _others.isEmpty
              ? Text('No other routed nets to match', style: secondary)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (id, name, length) in _others)
                      ChoiceChip(
                        label: Text(
                          '$name ${_fmt(length.length)} mm',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: id == _matchNetId,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _matchNetId = id),
                      ),
                  ],
                )
        else
          TextField(
            key: const ValueKey('meander-value'),
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              labelText: switch (_target) {
                TuneTarget.add => 'Length to add',
                TuneTarget.total => 'Net length wanted',
                _ => 'Net delay wanted',
              },
              suffixText: _target == TuneTarget.delay ? 'ps' : 'mm',
              helperText: switch (_target) {
                TuneTarget.add => null,
                TuneTarget.total => 'now ${_fmt(_current.length)} mm',
                _ => 'now ${_fmt(_current.delayPs, 0)} ps',
              },
            ),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 8),
        _Slider(
          label: 'Loop height',
          value: _amplitude,
          min: math.max(0.2, _spacing / 2),
          max: 10,
          onChanged: (value) => setState(() => _amplitude = value),
        ),
        _Slider(
          label: 'Loop spacing',
          value: _spacing,
          min: _minSpacing,
          max: math.max(_minSpacing + 0.1, 5),
          onChanged: (value) => setState(() => _spacing = value),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<MeanderSide>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: MeanderSide.both,
                    tooltip: 'Both sides',
                    icon: Icon(Icons.unfold_more, size: 18),
                  ),
                  ButtonSegment(
                    value: MeanderSide.left,
                    tooltip: 'Left of the track',
                    icon: Icon(Icons.north, size: 18),
                  ),
                  ButtonSegment(
                    value: MeanderSide.right,
                    tooltip: 'Right of the track',
                    icon: Icon(Icons.south, size: 18),
                  ),
                ],
                selected: {_side},
                onSelectionChanged: (value) =>
                    setState(() => _side = value.first),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<MeanderCorner>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: MeanderCorner.chamfered,
                  label: Text('45°'),
                ),
                ButtonSegment(value: MeanderCorner.square, label: Text('90°')),
              ],
              selected: {_corner},
              onSelectionChanged: (value) =>
                  setState(() => _corner = value.first),
            ),
          ],
        ),
      ],
    );
  }

  /// One line saying whether this will work, and if not, what to change.
  Widget _status(MeanderPlan? plan, double? extra, List<RouteClash> clashes) {
    final (IconData icon, Color colour, String text) = switch (plan) {
      null => (
        Icons.edit_outlined,
        KicadPalette.textSecondary,
        _target == TuneTarget.match
            ? 'Choose a net to match'
            : 'Enter a target',
      ),
      _ when extra != null && extra <= 0 => (
        Icons.check_circle_outline,
        KicadPalette.success,
        'Already long enough — ${_fmt(-extra)} mm over',
      ),
      MeanderPlan(isValid: false) => (
        Icons.warning_amber_rounded,
        KicadPalette.warning,
        plan.problem ?? 'Cannot tune this segment',
      ),
      _ when clashes.isNotEmpty => (
        Icons.error_outline,
        KicadPalette.error,
        'Too close to other copper in ${clashes.length} '
            'place${clashes.length == 1 ? '' : 's'} — lower the loops or '
            'put them on the other side',
      ),
      _ => (
        Icons.check_circle_outline,
        KicadPalette.success,
        '+${_fmt(plan.added)} mm in ${plan.loops} '
            'loop${plan.loops == 1 ? '' : 's'}, ${_fmt(plan.amplitude)} mm '
            'high · net ${_fmt(_current.length + plan.added)} mm, '
            '${_fmt(_current.delayPs + plan.added * _speed, 0)} ps',
      ),
    };
    return Row(
      key: plan != null && plan.isValid
          ? const ValueKey('meander-result')
          : const ValueKey('meander-problem'),
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colour),
          ),
        ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            onChanged: (v) => onChanged((v * 20).roundToDouble() / 20),
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            '${clamped.toStringAsFixed(2)} mm',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// The net's length now, what the loops add, and how far off the target
/// that leaves it — one bar, so the gap is seen rather than worked out.
class _LengthBar extends StatelessWidget {
  const _LengthBar({
    required this.now,
    required this.extra,
    required this.added,
  });

  final double now;
  final double? extra;
  final double added;

  @override
  Widget build(BuildContext context) {
    final target = extra == null ? null : now + extra!;
    final full = math.max(now + math.max(added, 0), target ?? now);
    double part(double mm) => full <= 0 ? 0 : (mm / full).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 12,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: KicadPalette.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: w * part(now),
                    decoration: BoxDecoration(
                      color: KicadPalette.textSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  if (added > 0)
                    Positioned(
                      left: w * part(now),
                      width: w * part(added),
                      top: 0,
                      bottom: 0,
                      child: Container(color: KicadPalette.highlight),
                    ),
                  if (target != null)
                    Positioned(
                      left: (w * part(target) - 1).clamp(0, w - 2),
                      width: 2,
                      top: -2,
                      bottom: -2,
                      child: Container(color: Colors.white),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(
          target == null
              ? 'Net now ${now.toStringAsFixed(2)} mm'
              : 'Net ${now.toStringAsFixed(2)} mm → target '
                    '${target.toStringAsFixed(2)} mm',
          style: TextStyle(fontSize: 11, color: KicadPalette.textSecondary),
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
    required this.amplitude,
    required this.spacing,
  });

  final Track track;
  final MeanderPlan? plan;
  final List<RouteClash> clashes;
  final double amplitude;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(track.startX, track.startY);
    final b = Offset(track.endX, track.endY);
    final valid = plan != null && plan!.isValid;
    final points = valid ? plan!.points : [a, b];

    // Framed along the track, so any track reads left to right.
    final along = (b - a) / math.max((b - a).distance, 1e-9);
    final normal = Offset(-along.dy, along.dx);
    Offset local(Offset p) {
      final d = p - a;
      return Offset(
        d.dx * along.dx + d.dy * along.dy,
        d.dx * normal.dx + d.dy * normal.dy,
      );
    }

    final locals = [for (final p in points) local(p)];
    final length = (b - a).distance;
    final reach = math.max(amplitude, track.width) + track.width;
    final bounds = Rect.fromLTRB(0, -reach, length, reach).inflate(1);
    final scale = math.min(
      (size.width - 24) / bounds.width,
      (size.height - 24) / bounds.height,
    );
    final origin = Offset(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      size.height / 2,
    );
    Offset map(Offset p) => origin + p * scale;

    // The track as it is, ghosted.
    canvas.drawLine(
      map(Offset.zero),
      map(Offset(length, 0)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = math.max(2, track.width * scale)
        ..strokeCap = StrokeCap.round,
    );

    // The loops, in the layer's colour.
    final path = Path()..moveTo(map(locals.first).dx, map(locals.first).dy);
    for (final p in locals.skip(1)) {
      path.lineTo(map(p).dx, map(p).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = valid
            ? BoardPainter.colorFor(track.layer)
            : BoardPainter.colorFor(track.layer).withValues(alpha: 0.5)
        ..strokeWidth = math.max(2, track.width * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // The height the loops may reach, as a pair of dashed limits.
    final limit = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final y in [-amplitude, amplitude]) {
      for (var x = 0.0; x < length; x += 1.2) {
        canvas.drawLine(
          map(Offset(x, y)),
          map(Offset(math.min(x + 0.6, length), y)),
          limit,
        );
      }
    }

    for (final clash in clashes) {
      final at = map(local(clash.at));
      canvas
        ..drawCircle(
          at,
          7,
          Paint()..color = KicadPalette.error.withValues(alpha: 0.35),
        )
        ..drawCircle(at, 3, Paint()..color = KicadPalette.error);
    }

    // Ends of the segment, where it joins the rest of the net.
    for (final end in [Offset.zero, Offset(length, 0)]) {
      canvas.drawCircle(map(end), 4, Paint()..color = Colors.white70);
    }
  }

  @override
  bool shouldRepaint(_MeanderPreview old) =>
      old.plan != plan ||
      old.track != track ||
      old.clashes.length != clashes.length ||
      old.amplitude != amplitude ||
      old.spacing != spacing;
}
