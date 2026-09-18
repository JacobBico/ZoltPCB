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
  late final _width = TextEditingController(text: _fmt(widget.initialWidth));
  final _gap = TextEditingController(text: '0.2');
  final _target = TextEditingController(text: '50');
  bool _pair = false;
  String? _note;

  Stackup get _stackup => widget.board.stackup;

  @override
  void dispose() {
    _width.dispose();
    _gap.dispose();
    _target.dispose();
    super.dispose();
  }

  static String _fmt(double value, [int places = 3]) {
    final text = value.toStringAsFixed(places);
    return text.contains('.')
        ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : text;
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  LineImpedance? get _result {
    final width = _parse(_width);
    final gap = _pair ? _parse(_gap) : null;
    if (width == null || width <= 0) return null;
    if (_pair && (gap == null || gap <= 0)) return null;
    return ImpedanceCalculator.of(_stackup, _layer, width: width, gap: gap);
  }

  void _solve() {
    final target = _parse(_target);
    if (target == null || target <= 0) return;
    final width = ImpedanceCalculator.widthFor(
      _stackup,
      _layer,
      target: target,
      gap: _pair ? _parse(_gap) : null,
    );
    setState(() {
      if (width == null) {
        _note =
            'No width between 0.02 and 20 mm gives ${_fmt(target, 1)} Ω on '
            '${_layer.label}';
      } else {
        _width.text = _fmt(width);
        _note = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final geometry = _stackup.geometryOf(_layer);
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    InputDecoration field(String label, String suffix) =>
        InputDecoration(labelText: label, suffixText: suffix, isDense: true);

    return AlertDialog(
      title: Text(
        'Impedance · ${widget.board.copperLayerCount} layers, '
        '${_fmt(_stackup.thickness, 2)} mm',
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final layer in widget.board.copperLayers)
                          ChoiceChip(
                            key: ValueKey(
                              'impedance-layer-${layer.shortLabel}',
                            ),
                            avatar: CircleAvatar(
                              radius: 5,
                              backgroundColor: BoardPainter.colorFor(layer),
                            ),
                            label: Text(layer.shortLabel),
                            selected: layer == _layer,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _layer = layer),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('impedance-width'),
                            controller: _width,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            decoration: field('Track width', 'mm'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('impedance-gap'),
                            controller: _gap,
                            enabled: _pair,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            decoration: field('Pair gap', 'mm'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: _pair,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Differential pair'),
                      onChanged: (value) =>
                          setState(() => _pair = value ?? false),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextField(
                            key: const ValueKey('impedance-target'),
                            controller: _target,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: numbers,
                            decoration: field(
                              _pair ? 'Target Zdiff' : 'Target Z₀',
                              'Ω',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const ValueKey('impedance-solve'),
                          onPressed: _solve,
                          child: const Text('FIND WIDTH'),
                        ),
                      ],
                    ),
                    if (_note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _note!,
                          style: TextStyle(
                            color: KicadPalette.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 250,
                child: _Readout(
                  result: result,
                  geometry: geometry,
                  pair: _pair,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
        FilledButton(
          onPressed: result == null
              ? null
              : () => Navigator.of(context).pop(_parse(_width)),
          child: const Text('USE THIS WIDTH'),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.result,
    required this.geometry,
    required this.pair,
  });

  final LineImpedance? result;
  final LayerGeometry geometry;
  final bool pair;

  static String _fmt(double value, int places) => value.toStringAsFixed(places);

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );
    if (result == null) {
      return Text('Enter a width to see its impedance', style: secondary);
    }
    final main = pair ? result.zDiff! : result.z0;
    String height(double? h) => h == null ? 'air' : '${_fmt(h, 3)} mm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(result.kind.label, style: secondary),
        Text(
          '${_fmt(main, 1)} Ω',
          key: const ValueKey('impedance-result'),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: KicadPalette.highlight,
          ),
        ),
        Text(
          pair
              ? 'differential · each track ${_fmt(result.z0, 1)} Ω'
              : 'single-ended',
          style: secondary,
        ),
        const SizedBox(height: 10),
        Text(
          '${_fmt(result.delayPsPerMm, 2)} ps/mm · '
          '${_fmt(result.delayPsPerMm * 25.4, 0)} ps/inch',
        ),
        Text(
          'εeff ${_fmt(result.epsilonEffective, 2)} · '
          '${_fmt(result.velocityFactor * 100, 0)}% of c',
          style: secondary,
        ),
        const SizedBox(height: 10),
        Text(
          'Above: ${height(geometry.heightAbove)} · '
          'below: ${height(geometry.heightBelow)}',
          style: secondary,
        ),
        Text(
          'Copper ${_fmt(geometry.copperThickness * 1000, 1)} µm',
          style: secondary,
        ),
        const SizedBox(height: 8),
        Text(
          'Closed-form estimate, uncoated. Solder mask lowers a microstrip '
          'by 2–3 Ω; a fab offering controlled impedance will fine-tune the '
          'width with its own laminate data.',
          style: secondary?.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}
