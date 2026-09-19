import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// Works out a track's impedance from the board's build, or the width a
/// target impedance needs.
///
/// Returns a width to route with when the user chooses USE THIS WIDTH, or
/// null otherwise.
Future<double?> showImpedanceCalculator(
  BuildContext context, {
  required Board board,
  CopperLayer? layer,
  double? width,
}) => showDialog<double>(
  context: context,
  builder: (context) => _ImpedanceDialog(
    board: board,
    initialLayer: layer != null && board.hasLayer(layer)
        ? layer
        : CopperLayer.front,
    initialWidth: width ?? board.rules.trackWidth,
  ),
);

/// Which way round the calculator is being used.
enum _Mode {
  /// A target impedance in, the width that gives it out.
  findWidth,

  /// A width in, the impedance it gives out.
  checkWidth,
}

class _ImpedanceDialog extends StatefulWidget {
  const _ImpedanceDialog({
    required this.board,
    required this.initialLayer,
    required this.initialWidth,
  });

  final Board board;
  final CopperLayer initialLayer;
  final double initialWidth;

  @override
  State<_ImpedanceDialog> createState() => _ImpedanceDialogState();
}

class _ImpedanceDialogState extends State<_ImpedanceDialog> {
  late CopperLayer _layer = widget.initialLayer;
  _Mode _mode = _Mode.findWidth;
  bool _pair = false;
  double _target = 50;
  late double _width = widget.initialWidth;
  double _gap = 0.2;

  Stackup get _stackup => widget.board.stackup;

  /// Targets anyone actually routes to: RF and most single-ended logic at
  /// 50, video at 75; USB at 90 and Ethernet or LVDS at 100 as pairs.
  List<double> get _presets =>
      _pair ? const [85, 90, 100, 120] : const [40, 50, 60, 75];

  /// The width the target needs, when finding one.
  double? get _solved => ImpedanceCalculator.widthFor(
    _stackup,
    _layer,
    target: _target,
    gap: _pair ? _gap : null,
  );

  /// The width being shown: the one solved for, or the one typed.
  double? get _shownWidth => _mode == _Mode.findWidth ? _solved : _width;

  LineImpedance? get _result {
    final width = _shownWidth;
    if (width == null || width <= 0) return null;
    return ImpedanceCalculator.of(
      _stackup,
      _layer,
      width: width,
      gap: _pair ? _gap : null,
    );
  }

  static String _fmt(double value, [int places = 3]) {
    final text = value.toStringAsFixed(places);
    return text.contains('.')
        ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : text;
  }

  void _setPair(bool pair) => setState(() {
    _pair = pair;
    _target = pair ? 90 : 50;
  });

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final geometry = _stackup.geometryOf(_layer);
    final width = _shownWidth;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, size: 20, color: KicadPalette.highlight),
                  const SizedBox(width: 8),
                  Text('Impedance', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.board.copperLayerCount} layers · '
                    '${_fmt(_stackup.thickness, 2)} mm board',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.horizontal_rule, size: 16),
                        label: Text('Single'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.drag_handle, size: 16),
                        label: Text('Pair'),
                      ),
                    ],
                    selected: {_pair},
                    onSelectionChanged: (value) => _setPair(value.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // What is being worked out, drawn: the layer's own
                    // cross-section, to scale in height.
                    Expanded(
                      flex: 5,
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
                                  painter: _CrossSection(
                                    geometry: geometry,
                                    width: width ?? 0,
                                    gap: _pair ? _gap : null,
                                    layerColour: BoardPainter.colorFor(_layer),
                                    kind: result?.kind,
                                    stackup: _stackup,
                                    layer: _layer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LayerStrip(
                            layers: widget.board.copperLayers,
                            stackup: _stackup,
                            selected: _layer,
                            onSelected: (layer) =>
                                setState(() => _layer = layer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: _controls(context, result, width),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Closed-form estimate, without solder mask (which '
                      'takes a microstrip 2–3 Ω lower). A fab doing '
                      'controlled impedance fine-tunes the width.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CLOSE'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    key: const ValueKey('impedance-use'),
                    onPressed: width == null || width <= 0
                        ? null
                        : () => Navigator.of(context).pop(width),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(
                      width == null ? 'NO WIDTH' : 'ROUTE AT ${_fmt(width)} mm',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, LineImpedance? result, double? width) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );
    final impedance = result == null
        ? null
        : (_pair ? result.zDiff! : result.z0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Mode>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: _Mode.findWidth, label: Text('Find width')),
            ButtonSegment(
              value: _Mode.checkWidth,
              label: Text('Check a width'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() {
            _mode = value.first;
            // Carry the width over, so checking starts from what was found.
            if (_mode == _Mode.checkWidth && _solved != null) {
              _width = double.parse(_solved!.toStringAsFixed(3));
            }
          }),
        ),
        const SizedBox(height: 10),
        if (_mode == _Mode.findWidth) ...[
          Text(_pair ? 'Target between the pair' : 'Target', style: secondary),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  key: ValueKey('impedance-target-${preset.round()}'),
                  label: Text('${preset.round()} Ω'),
                  selected: _target == preset,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _target = preset),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _Stepper(
            key: const ValueKey('impedance-target'),
            label: 'Other target',
            value: _target,
            unit: 'Ω',
            step: 1,
            min: 10,
            max: 200,
            places: 1,
            onChanged: (value) => setState(() => _target = value),
          ),
        ] else
          _Stepper(
            key: const ValueKey('impedance-width'),
            label: 'Track width',
            value: _width,
            unit: 'mm',
            step: 0.01,
            min: 0.02,
            max: 20,
            places: 3,
            onChanged: (value) => setState(() => _width = value),
          ),
        if (_pair) ...[
          const SizedBox(height: 6),
          _Stepper(
            key: const ValueKey('impedance-gap'),
            label: 'Gap between',
            value: _gap,
            unit: 'mm',
            step: 0.01,
            min: 0.05,
            max: 5,
            places: 3,
            onChanged: (value) => setState(() => _gap = value),
          ),
        ],
        const SizedBox(height: 12),
        // The answer, big.
        if (_mode == _Mode.findWidth)
          width == null
              ? _Warning(
                  text:
                      'No width from 0.02 to 20 mm gives ${_fmt(_target, 1)} Ω '
                      'on ${_layer.label} — try another layer or target',
                )
              : _Answer(
                  key: const ValueKey('impedance-result'),
                  big: '${_fmt(width)} mm',
                  small: _pair
                      ? 'each track, ${_fmt(_gap)} mm apart'
                      : 'track width',
                )
        else if (impedance != null)
          _Answer(
            key: const ValueKey('impedance-result'),
            big: '${impedance.toStringAsFixed(1)} Ω',
            small: _pair
                ? 'between the pair · each ${result!.z0.toStringAsFixed(1)} Ω'
                : 'single-ended',
          ),
        if (impedance != null) ...[
          const SizedBox(height: 8),
          _Gauge(value: impedance, target: _target),
          const SizedBox(height: 8),
          Text(
            '${result!.kind.label} · ${result.delayPsPerMm.toStringAsFixed(2)} '
            'ps/mm · ${(result.velocityFactor * 100).round()}% of c',
            style: secondary,
          ),
        ],
      ],
    );
  }
}

/// A number with − and + either side, and room to type it.
class _Stepper extends StatefulWidget {
  const _Stepper({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.places,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String unit;
  final double step;
  final double min;
  final double max;
  final int places;
  final ValueChanged<double> onChanged;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final _controller = TextEditingController(text: _text(widget.value));
  final _focus = FocusNode();

  String _text(double value) =>
      _ImpedanceDialogState._fmt(value, widget.places);

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    // Follow the value when it changes from outside — a preset chip — but
    // never under a thumb that is typing.
    if (!_focus.hasFocus && old.value != widget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _nudge(int direction) {
    final next = (widget.value + direction * widget.step).clamp(
      widget.min,
      widget.max,
    );
    final rounded = double.parse(next.toStringAsFixed(widget.places));
    _controller.text = _text(rounded);
    widget.onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int direction) => SizedBox(
      width: 40,
      height: 40,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        onPressed: () => _nudge(direction),
      ),
    );
    return Row(
      children: [
        button(Icons.remove, -1),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.unit,
              isDense: true,
            ),
            onChanged: (text) {
              final value = double.tryParse(text.replaceAll(',', '.'));
              if (value != null && value >= widget.min && value <= widget.max) {
                widget.onChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        button(Icons.add, 1),
      ],
    );
  }
}

/// The answer, in large type, with what it is underneath.
class _Answer extends StatelessWidget {
  const _Answer({super.key, required this.big, required this.small});

  final String big;
  final String small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KicadPalette.highlight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: KicadPalette.highlight.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            big,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: KicadPalette.highlight,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            small,
            style: theme.textTheme.bodySmall?.copyWith(
              color: KicadPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: KicadPalette.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: KicadPalette.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

/// How close an impedance is to its target: a bar from 30% under to 30%
/// over, green within 5%, amber within 10%, red beyond.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.value, required this.target});

  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final off = (value - target) / target;
    final colour = off.abs() <= 0.05
        ? KicadPalette.success
        : off.abs() <= 0.10
        ? KicadPalette.warning
        : KicadPalette.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: CustomPaint(
            size: const Size(double.infinity, 14),
            painter: _GaugePainter(off: off, colour: colour),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          off.abs() < 0.005
              ? 'On target'
              : '${off > 0 ? '+' : ''}${(off * 100).toStringAsFixed(1)}% '
                    'against ${target.toStringAsFixed(0)} Ω',
          style: TextStyle(fontSize: 11, color: colour),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.off, required this.colour});

  final double off;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    const range = 0.30;
    double x(double fraction) =>
        (fraction.clamp(-range, range) + range) / (2 * range) * size.width;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.4),
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = KicadPalette.border);
    canvas.drawRect(
      Rect.fromLTRB(x(-0.10), size.height * 0.3, x(0.10), size.height * 0.7),
      Paint()..color = KicadPalette.warning.withValues(alpha: 0.35),
    );
    canvas.drawRect(
      Rect.fromLTRB(x(-0.05), size.height * 0.3, x(0.05), size.height * 0.7),
      Paint()..color = KicadPalette.success.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(x(0), 0),
      Offset(x(0), size.height),
      Paint()
        ..color = KicadPalette.textSecondary
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(x(off), size.height / 2),
      size.height / 2,
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.off != off || old.colour != colour;
}

/// The board's copper, each a chip coloured like its layer, saying what a
/// track there is.
class _LayerStrip extends StatelessWidget {
  const _LayerStrip({
    required this.layers,
    required this.stackup,
    required this.selected,
    required this.onSelected,
  });

  final List<CopperLayer> layers;
  final Stackup stackup;
  final CopperLayer selected;
  final ValueChanged<CopperLayer> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final layer in layers)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('impedance-layer-${layer.shortLabel}'),
                avatar: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: BoardPainter.colorFor(layer),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                label: Text(
                  '${layer.shortLabel} · '
                  '${stackup.geometryOf(layer).isStripline ? 'strip' : 'micro'}',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: layer == selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSelected(layer),
              ),
            ),
        ],
      ),
    );
  }
}

/// A cross-section through the board at the track: the reference copper,
/// the dielectric with its height and permittivity, and the track — or
/// the pair — in its layer's colour with its width and gap marked.
///
/// Heights are to scale with each other; the track's width is scaled on
/// its own so a 0.1 mm track is still something to look at.
class _CrossSection extends CustomPainter {
  _CrossSection({
    required this.geometry,
    required this.width,
    required this.gap,
    required this.layerColour,
    required this.kind,
    required this.stackup,
    required this.layer,
  });

  final LayerGeometry geometry;
  final double width;
  final double? gap;
  final Color layerColour;
  final LineKind? kind;
  final Stackup stackup;
  final CopperLayer layer;

  static const _copper = Color(0xFFC98A3A);
  static const _dielectric = Color(0xFF3B5A33);

  @override
  void paint(Canvas canvas, Size size) {
    final above = geometry.heightAbove;
    final below = geometry.heightBelow;
    final t = geometry.copperThickness;
    final total = (above ?? 0) + t + (below ?? 0);
    final padTop = above == null ? 34.0 : 18.0;
    final padBottom = below == null ? 34.0 : 18.0;
    const planeHeight = 8.0;
    final usable =
        size.height -
        padTop -
        padBottom -
        (above != null ? planeHeight : 0) -
        (below != null ? planeHeight : 0);
    final scale = usable / math.max(total, 1e-6);

    var y = padTop;
    final label = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 11,
    );

    void text(String s, Offset at, {TextStyle? style, bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style ?? label),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, right ? at - Offset(painter.width, 0) : at);
    }

    // Air, above an outer layer.
    if (above == null) {
      text(
        'air',
        Offset(12, y - 22),
        style: label.copyWith(color: Colors.white.withValues(alpha: 0.5)),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, planeHeight),
        Paint()..color = _copper,
      );
      text(
        'reference plane',
        Offset(12, y - 15),
        style: label.copyWith(fontSize: 10),
      );
      y += planeHeight;
    }

    final dielectricTop = y;
    final dielectricHeight = total * scale;
    canvas.drawRect(
      Rect.fromLTWH(0, dielectricTop, size.width, dielectricHeight),
      Paint()..color = _dielectric.withValues(alpha: 0.8),
    );

    // The track (or pair), centred, at its layer's height.
    final trackTop = dielectricTop + (above ?? 0) * scale;
    final trackHeight = math.max(3.0, t * scale);
    final gapMm = gap;
    // The width drawn so the pair fills about half the view.
    final span = gapMm == null ? width : 2 * width + gapMm;
    final widthScale = span <= 0 ? 1.0 : (size.width * 0.45) / span;
    final w = width * widthScale;
    final centre = size.width / 2;
    final tracks = <Rect>[
      if (gapMm == null)
        Rect.fromLTWH(centre - w / 2, trackTop, w, trackHeight)
      else ...[
        Rect.fromLTWH(
          centre - gapMm * widthScale / 2 - w,
          trackTop,
          w,
          trackHeight,
        ),
        Rect.fromLTWH(
          centre + gapMm * widthScale / 2,
          trackTop,
          w,
          trackHeight,
        ),
      ],
    ];
    for (final rect in tracks) {
      canvas.drawRect(rect, Paint()..color = layerColour);
    }

    // Dimensions: width over the first track, gap between the pair.
    final dim = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    final first = tracks.first;
    final dimY = trackTop - 10;
    canvas.drawLine(Offset(first.left, dimY), Offset(first.right, dimY), dim);
    text('W ${_mm(width)}', Offset(first.left, dimY - 15));
    if (gapMm != null) {
      final a = tracks[0].right;
      final b = tracks[1].left;
      canvas.drawLine(
        Offset(a, dimY + 2),
        Offset(b, dimY + 2),
        dim..color = KicadPalette.highlight,
      );
      text(
        'S ${_mm(gapMm)}',
        Offset(tracks[1].left, dimY - 15),
        style: label.copyWith(color: KicadPalette.highlight),
      );
    }

    // Heights, on the right.
    final hx = size.width - 10;
    if (above != null) {
      text(
        'h ${_mm(above)}',
        Offset(hx, dielectricTop + above * scale / 2 - 7),
        right: true,
      );
    }
    if (below != null) {
      text(
        'h ${_mm(below)}',
        Offset(hx, trackTop + trackHeight + below * scale / 2 - 7),
        right: true,
      );
    }
    final er = below != null && above != null
        ? (geometry.epsilonAbove * above + geometry.epsilonBelow * below) /
              (above + below)
        : (below != null ? geometry.epsilonBelow : geometry.epsilonAbove);
    text(
      'εr ${er.toStringAsFixed(2)}',
      Offset(12, dielectricTop + dielectricHeight - 18),
    );

    y = dielectricTop + dielectricHeight;
    if (below != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, planeHeight),
        Paint()..color = _copper,
      );
      text(
        'reference plane',
        Offset(12, y + planeHeight + 2),
        style: label.copyWith(fontSize: 10),
      );
    } else {
      text(
        'air',
        Offset(12, y + 6),
        style: label.copyWith(color: Colors.white.withValues(alpha: 0.5)),
      );
    }

    // What sort of line this is, top right.
    if (kind != null) {
      text(
        '${layer.label} · ${kind!.label}',
        Offset(size.width - 10, 8),
        style: label.copyWith(fontWeight: FontWeight.w600),
        right: true,
      );
    }
  }

  static String _mm(double v) => '${v.toStringAsFixed(3)} mm';

  @override
  bool shouldRepaint(_CrossSection old) =>
      old.width != width ||
      old.gap != gap ||
      old.layer != layer ||
      old.geometry != geometry ||
      old.kind != kind;
}
