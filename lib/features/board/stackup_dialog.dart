import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// Sets up how the board is built: how many copper layers, how thick,
/// what weight of copper, and what lies between the layers.
///
/// Returns the board carrying the new build, or null if cancelled.
/// [usedLayers] are the layers something is already drawn on; a layer
/// count that would take one of them away is offered but refused, with
/// the reason, rather than quietly dropping copper.
Future<Board?> showStackupDialog(
  BuildContext context, {
  required Board board,
  Set<CopperLayer> usedLayers = const {},
}) => showDialog<Board>(
  context: context,
  builder: (context) => _StackupDialog(board: board, usedLayers: usedLayers),
);

class _StackupDialog extends StatefulWidget {
  const _StackupDialog({required this.board, required this.usedLayers});

  final Board board;
  final Set<CopperLayer> usedLayers;

  @override
  State<_StackupDialog> createState() => _StackupDialogState();
}

class _StackupDialogState extends State<_StackupDialog> {
  late Stackup _stackup = widget.board.stackup;
  late final _thickness = TextEditingController(
    text: _mm(widget.board.stackup.thickness),
  );

  /// The row being edited: a copper layer's index, or a dielectric's as
  /// `1000 + index`. Null when nothing is open.
  int? _editing;

  static const _thicknesses = [0.8, 1.0, 1.2, 1.6, 2.0];

  @override
  void dispose() {
    _thickness.dispose();
    super.dispose();
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(4);
    return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  CopperWeight get _outer => _stackup.copper.first.weight;
  CopperWeight get _inner => _stackup.copper.length > 2
      ? _stackup.copper[1].weight
      : CopperWeight.half;

  /// What a smaller layer count would take away, if anything.
  String? _whyNot(int count) {
    final keep = CopperLayer.stack(count).toSet();
    final lost = widget.usedLayers.where((l) => !keep.contains(l)).toList();
    if (lost.isEmpty) return null;
    return 'Copper is drawn on ${lost.map((l) => l.shortLabel).join(', ')}';
  }

  void _setCount(int count) {
    final reason = _whyNot(count);
    if (reason != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$reason — move or delete it first')),
      );
      return;
    }
    setState(() {
      _stackup = Stackup.standard(
        layerCount: count,
        thickness: _stackup.thickness,
        outer: _outer,
        inner: _inner,
      );
      _editing = null;
    });
  }

  void _setThickness(double thickness) {
    if (thickness <= 0.2 || thickness > 6) return;
    setState(() => _stackup = _stackup.withThickness(thickness));
    final shown = _mm(_stackup.thickness);
    if (_thickness.text != shown) _thickness.text = shown;
  }

  void _setWeight({required bool outer, required CopperWeight weight}) {
    final total = _stackup.thickness;
    setState(() {
      _stackup = _stackup
          .copyWith(
            copper: [
              for (final c in _stackup.copper)
                c.layer.isInner != outer
                    ? c.copyWith(thickness: weight.thickness)
                    : c,
            ],
          )
          .withThickness(total);
    });
  }

  void _updateCopper(int index, StackupCopper copper) => setState(() {
    _stackup = _stackup.copyWith(
      copper: [
        for (var i = 0; i < _stackup.copper.length; i++)
          i == index ? copper : _stackup.copper[i],
      ],
    );
    _thickness.text = _mm(_stackup.thickness);
  });

  void _updateDielectric(int index, StackupDielectric dielectric) =>
      setState(() {
        _stackup = _stackup.copyWith(
          dielectrics: [
            for (var i = 0; i < _stackup.dielectrics.length; i++)
              i == index ? dielectric : _stackup.dielectrics[i],
          ],
        );
        _thickness.text = _mm(_stackup.thickness);
      });

  void _save() {
    final problem = _stackup.problem;
    if (problem != null) return;
    Navigator.of(context).pop(
      widget.board.copyWith(
        copperLayerCount: _stackup.layerCount,
        thickness: _stackup.thickness,
        stackup: _stackup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _stackup.problem;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Board build',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 290, child: _controls()),
                    const SizedBox(width: 16),
                    Expanded(child: _crossSection()),
                  ],
                ),
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    problem,
                    style: TextStyle(color: KicadPalette.error, fontSize: 12),
                  ),
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _stackup = Stackup.standard(
                        layerCount: _stackup.layerCount,
                        thickness: _stackup.thickness,
                        outer: _outer,
                        inner: _inner,
                      );
                      _editing = null;
                    }),
                    child: const Text('STANDARD BUILD'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: problem == null ? _save : null,
                    child: const Text('SAVE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 3),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: KicadPalette.textSecondary),
    ),
  );

  Widget _controls() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Copper layers'),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final count in CopperLayer.layerCounts)
              ButtonSegment(
                value: count,
                label: Text(
                  '$count',
                  style: TextStyle(
                    color: _whyNot(count) == null
                        ? null
                        : KicadPalette.textSecondary,
                  ),
                ),
                tooltip: _whyNot(count),
              ),
          ],
          selected: {_stackup.layerCount},
          onSelectionChanged: (value) => _setCount(value.first),
        ),
        _label('Thickness'),
        Row(
          children: [
            SizedBox(
              width: 88,
              child: TextField(
                key: const ValueKey('stackup-thickness'),
                controller: _thickness,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: 'mm',
                ),
                onSubmitted: (text) {
                  final value = double.tryParse(text);
                  if (value != null) _setThickness(value);
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final t in _thicknesses)
                    _Chip(
                      label: '$t',
                      selected: (_stackup.thickness - t).abs() < 0.005,
                      onTap: () => _setThickness(t),
                    ),
                ],
              ),
            ),
          ],
        ),
        _label('Outer copper'),
        Wrap(
          spacing: 4,
          children: [
            for (final weight in CopperWeight.values)
              _Chip(
                label: weight.label,
                selected: weight == _outer,
                onTap: () => _setWeight(outer: true, weight: weight),
              ),
          ],
        ),
        if (_stackup.layerCount > 2) ...[
          _label('Inner copper'),
          Wrap(
            spacing: 4,
            children: [
              for (final weight in CopperWeight.values)
                _Chip(
                  label: weight.label,
                  selected: weight == _inner,
                  onTap: () => _setWeight(outer: false, weight: weight),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tap a layer to change it. Planes are what impedance is measured '
          'to; a signal layer between two is stripline.',
          style: TextStyle(fontSize: 11, color: KicadPalette.textSecondary),
        ),
      ],
    ),
  );

  Widget _crossSection() {
    final rows = <Widget>[];
    for (var i = 0; i < _stackup.copper.length; i++) {
      rows.add(_copperRow(i));
      if (i < _stackup.dielectrics.length) rows.add(_dielectricRow(i));
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: KicadPalette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: rows,
      ),
    );
  }

  Widget _copperRow(int index) {
    final copper = _stackup.copper[index];
    final open = _editing == index;
    // 50 Ω on this layer, as a feel for what the build means.
    final width = ImpedanceCalculator.widthFor(
      _stackup,
      copper.layer,
      target: 50,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('stackup-copper-${copper.layer.shortLabel}'),
          onTap: () => setState(() => _editing = open ? null : index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 10,
                  color: BoardPainter.colorFor(copper.layer),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    copper.layer.shortLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${copper.role.label} · ${copper.weight.label} '
                    '(${(copper.thickness * 1000).toStringAsFixed(1)} µm)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  width == null ? '' : '50 Ω ≈ ${_mm(width)} mm',
                  style: TextStyle(
                    fontSize: 11,
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 0, 10, 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final role in LayerRole.values)
                  _Chip(
                    label: role.label,
                    selected: role == copper.role,
                    onTap: () =>
                        _updateCopper(index, copper.copyWith(role: role)),
                  ),
                const SizedBox(width: 10),
                for (final weight in CopperWeight.values)
                  _Chip(
                    label: weight.label,
                    selected: weight == copper.weight,
                    onTap: () => _updateCopper(
                      index,
                      copper.copyWith(thickness: weight.thickness),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dielectricRow(int index) {
    final dielectric = _stackup.dielectrics[index];
    final open = _editing == 1000 + index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('stackup-dielectric-$index'),
          onTap: () => setState(() => _editing = open ? null : 1000 + index),
          child: Container(
            color: const Color(0x2A7A6A3A),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 86),
                Expanded(
                  child: Text(
                    '${dielectric.kind.label} · ${_mm(dielectric.thickness)} mm '
                    '· ${dielectric.material} εr ${dielectric.epsilonR}',
                    style: TextStyle(
                      fontSize: 12,
                      color: KicadPalette.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          _DielectricEditor(
            key: ValueKey('dielectric-editor-$index'),
            dielectric: dielectric,
            onChanged: (value) => _updateDielectric(index, value),
          ),
      ],
    );
  }
}

class _DielectricEditor extends StatefulWidget {
  const _DielectricEditor({
    super.key,
    required this.dielectric,
    required this.onChanged,
  });

  final StackupDielectric dielectric;
  final ValueChanged<StackupDielectric> onChanged;

  @override
  State<_DielectricEditor> createState() => _DielectricEditorState();
}

class _DielectricEditorState extends State<_DielectricEditor> {
  late final _thickness = TextEditingController(
    text: _StackupDialogState._mm(widget.dielectric.thickness),
  );
  late final _er = TextEditingController(text: '${widget.dielectric.epsilonR}');
  late final _material = TextEditingController(
    text: widget.dielectric.material,
  );

  @override
  void dispose() {
    _thickness.dispose();
    _er.dispose();
    _material.dispose();
    super.dispose();
  }

  void _commit() {
    final thickness = double.tryParse(_thickness.text);
    final er = double.tryParse(_er.text);
    widget.onChanged(
      widget.dielectric.copyWith(
        thickness: thickness != null && thickness > 0 ? thickness : null,
        epsilonR: er != null && er >= 1 ? er : null,
        material: _material.text.trim().isEmpty ? null : _material.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, [String? suffix]) =>
        InputDecoration(isDense: true, labelText: label, suffixText: suffix);
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 4, 10, 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: TextField(
              key: const ValueKey('dielectric-thickness'),
              controller: _thickness,
              decoration: decoration('Height', 'mm'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numbers,
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              key: const ValueKey('dielectric-er'),
              controller: _er,
              decoration: decoration('εr'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numbers,
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _material,
              decoration: decoration('Material'),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          for (final kind in DielectricKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _Chip(
                label: kind.label,
                selected: kind == widget.dielectric.kind,
                onTap: () =>
                    widget.onChanged(widget.dielectric.copyWith(kind: kind)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: selected,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    showCheckmark: false,
  );
}
