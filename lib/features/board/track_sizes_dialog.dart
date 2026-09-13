import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// A width picked from the list, or a request to edit the list.
class TrackWidthChoice {
  const TrackWidthChoice({this.width = 0, this.edit = false});

  final double width;
  final bool edit;
}

class ViaSizeChoice {
  const ViaSizeChoice({this.size = const ViaSize(0.8, 0.4), this.edit = false});

  final ViaSize size;
  final bool edit;
}

/// Picks the width new track is drawn at, from the board's own list.
Future<TrackWidthChoice?> showTrackWidthPicker(
  BuildContext context, {
  required List<double> widths,
  required double selected,
  required double rule,
}) => showModalBottomSheet<TrackWidthChoice>(
  context: context,
  backgroundColor: KicadPalette.surface,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Track width',
              style: Theme.of(sheet).textTheme.titleSmall,
            ),
          ),
          for (final width in widths)
            ListTile(
              dense: true,
              leading: Icon(
                width == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: width == selected
                    ? KicadPalette.highlight
                    : KicadPalette.textSecondary,
              ),
              title: Text('${_mm(width)} mm'),
              subtitle: width == rule ? const Text('The design rule') : null,
              onTap: () =>
                  Navigator.of(sheet).pop(TrackWidthChoice(width: width)),
            ),
          Divider(height: 1, color: KicadPalette.border),
          ListTile(
            dense: true,
            leading: const Icon(Icons.edit_outlined, size: 18),
            title: const Text('Edit the list'),
            onTap: () =>
                Navigator.of(sheet).pop(const TrackWidthChoice(edit: true)),
          ),
        ],
      ),
    ),
  ),
);

Future<ViaSizeChoice?> showViaSizePicker(
  BuildContext context, {
  required List<ViaSize> sizes,
  required ViaSize selected,
}) => showModalBottomSheet<ViaSizeChoice>(
  context: context,
  backgroundColor: KicadPalette.surface,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Via size',
              style: Theme.of(sheet).textTheme.titleSmall,
            ),
          ),
          for (final size in sizes)
            ListTile(
              dense: true,
              leading: Icon(
                size == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: size == selected
                    ? KicadPalette.highlight
                    : KicadPalette.textSecondary,
              ),
              title: Text('${_mm(size.diameter)} / ${_mm(size.drill)} mm'),
              subtitle: const Text('pad / drill'),
              onTap: () => Navigator.of(sheet).pop(ViaSizeChoice(size: size)),
            ),
          Divider(height: 1, color: KicadPalette.border),
          ListTile(
            dense: true,
            leading: const Icon(Icons.edit_outlined, size: 18),
            title: const Text('Edit the list'),
            onTap: () =>
                Navigator.of(sheet).pop(const ViaSizeChoice(edit: true)),
          ),
        ],
      ),
    ),
  ),
);

/// The lists themselves.
class TrackSizesResult {
  const TrackSizesResult({required this.widths, required this.viaSizes});

  final List<double> widths;
  final List<ViaSize> viaSizes;
}

/// Sets up the widths and via sizes a board is laid out with.
///
/// KiCad keeps this in Board Setup and it is one of the things that makes
/// routing feel like a craft rather than a form: you decide beforehand that
/// this board has a 0.25 signal, a 0.5 power and a 1.0 supply track, and
/// then you just pick.
Future<TrackSizesResult?> showTrackSizesDialog(
  BuildContext context, {
  required List<double> widths,
  required List<ViaSize> viaSizes,
}) => showDialog<TrackSizesResult>(
  context: context,
  builder: (context) => _TrackSizesDialog(widths: widths, viaSizes: viaSizes),
);

class _TrackSizesDialog extends StatefulWidget {
  const _TrackSizesDialog({required this.widths, required this.viaSizes});

  final List<double> widths;
  final List<ViaSize> viaSizes;

  @override
  State<_TrackSizesDialog> createState() => _TrackSizesDialogState();
}

class _TrackSizesDialogState extends State<_TrackSizesDialog> {
  late List<double> _widths;
  late List<ViaSize> _viaSizes;

  final _width = TextEditingController();
  final _diameter = TextEditingController();
  final _drill = TextEditingController();

  @override
  void initState() {
    super.initState();
    _widths = [...widget.widths];
    _viaSizes = [...widget.viaSizes];
  }

  @override
  void dispose() {
    for (final c in [_width, _diameter, _drill]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addWidth() {
    final value = double.tryParse(_width.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    setState(() {
      if (!_widths.contains(value)) _widths.add(value);
      _widths.sort();
      _width.clear();
    });
  }

  void _addVia() {
    final diameter = double.tryParse(
      _diameter.text.trim().replaceAll(',', '.'),
    );
    final drill = double.tryParse(_drill.text.trim().replaceAll(',', '.'));
    if (diameter == null || drill == null) return;
    final size = ViaSize(diameter, drill);
    // A hole wider than its pad is not a via.
    if (!size.isValid) return;
    setState(() {
      if (!_viaSizes.contains(size)) _viaSizes.add(size);
      _viaSizes.sort((a, b) => a.diameter.compareTo(b.diameter));
      _diameter.clear();
      _drill.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Track and via sizes'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TRACK WIDTHS', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final width in _widths)
                          InputChip(
                            label: Text(_mm(width)),
                            onDeleted: () =>
                                setState(() => _widths.remove(width)),
                          ),
                        if (_widths.isEmpty)
                          Text(
                            'Just the design rule',
                            style: TextStyle(
                              color: KicadPalette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _Number(
                            controller: _width,
                            label: 'Width mm',
                            onSubmitted: _addWidth,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _addWidth,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('VIA SIZES', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final size in _viaSizes)
                          InputChip(
                            label: Text(
                              '${_mm(size.diameter)}/${_mm(size.drill)}',
                            ),
                            onDeleted: () =>
                                setState(() => _viaSizes.remove(size)),
                          ),
                        if (_viaSizes.isEmpty)
                          Text(
                            'Just the design rule',
                            style: TextStyle(
                              color: KicadPalette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _Number(
                            controller: _diameter,
                            label: 'Pad mm',
                            onSubmitted: _addVia,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Number(
                            controller: _drill,
                            label: 'Drill mm',
                            onSubmitted: _addVia,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _addVia,
                        ),
                      ],
                    ),
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
          onPressed: () => Navigator.of(context).pop(
            TrackSizesResult(widths: _widths, viaSizes: _viaSizes),
          ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
    required this.controller,
    required this.label,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, isDense: true),
    onSubmitted: (_) => onSubmitted(),
  );
}

String _mm(double value) {
  final text = value.toStringAsFixed(3);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}
