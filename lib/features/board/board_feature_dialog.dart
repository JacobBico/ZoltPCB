import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';

/// What to put on the board: the settings a mounting hole, fiducial or test
/// point is placed with.
class BoardFeatureSpec {
  const BoardFeatureSpec({
    this.kind = BoardFeatureKind.mountingHole,
    this.size = 3.2,
    this.plated = false,
    this.netId,
    this.netName = '',
  });

  final BoardFeatureKind kind;
  final double size;
  final bool plated;
  final String? netId;
  final String netName;

  /// A short name for the place button and the tool chip.
  String get shortLabel => switch (kind) {
    BoardFeatureKind.mountingHole =>
      '${_holeName(size)} ${plated ? 'plated ' : ''}hole',
    BoardFeatureKind.fiducial => 'Fiducial',
    BoardFeatureKind.testPoint =>
      netName.isEmpty ? 'Test point' : 'Test point $netName',
  };

  static String _holeName(double size) {
    for (final entry in BoardFeature.holeSizes.entries) {
      if ((entry.value - size).abs() < 1e-6) return entry.key;
    }
    return '${size.toStringAsFixed(1)} mm';
  }

  static BoardFeatureSpec of(BoardFeature f) => BoardFeatureSpec(
    kind: f.kind,
    size: f.size,
    plated: f.plated,
    netId: f.netId,
    netName: f.netName,
  );

  /// [feature] changed to these settings.
  BoardFeature applyTo(BoardFeature feature) => feature.copyWith(
    size: size,
    plated: plated,
    netId: netId,
    clearNet: netId == null,
    netName: netName,
  );
}

/// Chooses what a mounting hole, fiducial or test point is. Returns null
/// when cancelled.
Future<BoardFeatureSpec?> showBoardFeatureDialog(
  BuildContext context, {
  required List<NetWithEndpoints> nets,
  BoardFeatureSpec initial = const BoardFeatureSpec(),

  /// Editing one already on the board: its kind stays what it is.
  bool fixedKind = false,
}) => showDialog<BoardFeatureSpec>(
  context: context,
  builder: (_) =>
      _FeatureDialog(nets: nets, initial: initial, fixedKind: fixedKind),
);

class _FeatureDialog extends StatefulWidget {
  const _FeatureDialog({
    required this.nets,
    required this.initial,
    required this.fixedKind,
  });

  final List<NetWithEndpoints> nets;
  final BoardFeatureSpec initial;
  final bool fixedKind;

  @override
  State<_FeatureDialog> createState() => _FeatureDialogState();
}

class _FeatureDialogState extends State<_FeatureDialog> {
  late BoardFeatureKind _kind = widget.initial.kind;
  late bool _plated = widget.initial.plated;
  late String? _netId = widget.initial.netId;
  late final _size = TextEditingController(text: _format(widget.initial.size));

  static String _format(double v) =>
      v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  double? get _sizeValue =>
      double.tryParse(_size.text.trim().replaceAll(',', '.'));

  bool get _needsNet =>
      _kind == BoardFeatureKind.testPoint ||
      (_kind == BoardFeatureKind.mountingHole && _plated);

  String? get _problem {
    final size = _sizeValue;
    if (size == null || size <= 0) return 'A size greater than zero';
    if (_kind == BoardFeatureKind.testPoint && _netId == null) {
      return 'A test point needs a net to test';
    }
    return null;
  }

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  void _pickKind(BoardFeatureKind kind) => setState(() {
    if (kind == _kind) return;
    _kind = kind;
    _size.text = _format(BoardFeature.defaultSize(kind));
  });

  /// A plated hole goes to ground unless told otherwise: that is what a
  /// grounded mounting hole is for.
  String? _likelyGround() {
    for (final name in ['GND', 'GNDA', 'AGND', 'DGND', 'VSS']) {
      final net = widget.nets
          .where((n) => n.displayName.toUpperCase() == name)
          .firstOrNull;
      if (net != null) return net.net.id;
    }
    return null;
  }

  void _submit() {
    if (_problem != null) return;
    final net = _needsNet
        ? widget.nets.where((n) => n.net.id == _netId).firstOrNull
        : null;
    Navigator.of(context).pop(
      BoardFeatureSpec(
        kind: _kind,
        size: _sizeValue!,
        plated: _kind == BoardFeatureKind.mountingHole && _plated,
        netId: net?.net.id,
        netName: net?.displayName ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _problem;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );
    return AlertDialog(
      title: Text(widget.fixedKind ? _kind.label : 'Add to the board'),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.fixedKind) ...[
                SegmentedButton<BoardFeatureKind>(
                  key: const ValueKey('feature-kind'),
                  showSelectedIcon: false,
                  segments: [
                    for (final kind in BoardFeatureKind.values)
                      ButtonSegment(value: kind, label: Text(kind.label)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (value) => _pickKind(value.first),
                ),
                const SizedBox(height: 12),
              ],
              if (_kind == BoardFeatureKind.mountingHole)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final entry in BoardFeature.holeSizes.entries)
                      ChoiceChip(
                        key: ValueKey('hole-${entry.key}'),
                        label: Text(entry.key),
                        selected: _sizeValue == entry.value,
                        onSelected: (_) =>
                            setState(() => _size.text = _format(entry.value)),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('feature-size'),
                controller: _size,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: _kind == BoardFeatureKind.mountingHole
                      ? 'Hole diameter'
                      : 'Copper diameter',
                  suffixText: 'mm',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_kind == BoardFeatureKind.mountingHole)
                SwitchListTile(
                  key: const ValueKey('feature-plated'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _plated,
                  title: const Text('Plated, with a copper ring'),
                  subtitle: Text(
                    'For a screw that grounds the board to its case',
                    style: caption,
                  ),
                  onChanged: (on) => setState(() {
                    _plated = on;
                    if (on) _netId ??= _likelyGround();
                  }),
                ),
              if (_kind == BoardFeatureKind.fiducial)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Bare copper with a mask opening twice as wide. Put '
                    'three near the corners, not in a line.',
                    style: caption,
                  ),
                ),
              if (_needsNet) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('feature-net'),
                  initialValue: _netId,
                  isExpanded: true,
                  dropdownColor: KicadPalette.surfaceRaised,
                  decoration: const InputDecoration(
                    labelText: 'Net',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('No net')),
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
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
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
          key: const ValueKey('feature-ok'),
          onPressed: problem == null ? _submit : null,
          child: Text(widget.fixedKind ? 'SAVE' : 'PLACE'),
        ),
      ],
    );
  }
}
