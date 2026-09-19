import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';

/// A setting picked from a few built-in values and the ones a project has
/// added of its own — the way net classes work: set up once, a tap away
/// from then on.
class PresetValues {
  const PresetValues({
    required this.settingsKey,
    required this.keyPrefix,
    required this.title,
    required this.description,
    required this.icon,
    required this.builtIns,
    required this.label,
    required this.fieldLabel,
    this.maxValue = 50,
    this.chipIcon,
  });

  /// Where the project keeps its own values, as space-separated
  /// millimetres.
  final String settingsKey;

  /// Prefix of the keys the sheet's widgets carry.
  final String keyPrefix;
  final String title;
  final String description;
  final IconData icon;

  /// Always offered, never removable. Zero may stand for "none".
  final List<double> builtIns;

  /// How a value reads on its chip.
  final String Function(double value) label;
  final String fieldLabel;
  final double maxValue;

  /// A small drawing on each chip showing what the value does.
  final Widget Function(double value, Color colour)? chipIcon;

  /// The values offered: the built-ins and the project's own, smallest
  /// first.
  List<double> from(Map<String, String> settings) =>
      {...builtIns, ...own(settings)}.toList()..sort();

  /// The project's own values alone.
  List<double> own(Map<String, String> settings) => [
    for (final part in (settings[settingsKey] ?? '').split(' '))
      ?double.tryParse(part),
  ].where((v) => v > 0 && !builtIns.contains(v)).toList()..sort();
}

/// Where a board's own corner radii are kept.
const cornerRadii = PresetValues(
  settingsKey: 'board.cornerRadii',
  keyPrefix: 'corner-radius',
  title: 'Corner rounding',
  description: 'How far each corner of a routed track is rounded',
  icon: Icons.rounded_corner,
  builtIns: [0.0, 1.0],
  label: _cornerLabel,
  fieldLabel: 'Your own radius',
  chipIcon: _cornerIcon,
);

String _cornerLabel(double r) => r == 0 ? 'Sharp' : '${presetMm(r)} mm';

Widget _cornerIcon(double r, Color colour) => CustomPaint(
  size: const Size(18, 18),
  painter: _CornerIcon(radius: r, colour: colour),
);

/// Where a board's own grids are kept. Zero is no grid: points go exactly
/// where the crosshair is.
const boardGrids = PresetValues(
  settingsKey: 'board.grids',
  keyPrefix: 'grid',
  title: 'Grid',
  description: 'What points snap to as they are placed',
  icon: Icons.grid_4x4,
  builtIns: [0.0, 0.5],
  label: _gridLabel,
  fieldLabel: 'Your own grid',
  maxValue: 10,
  chipIcon: _gridIcon,
);

String _gridLabel(double g) => switch (g) {
  0 => 'Free',
  0.5 => '0.5 mm · default',
  1.27 => '1.27 mm · 0.05 in',
  2.54 => '2.54 mm · 0.1 in',
  _ => '${presetMm(g)} mm',
};

Widget _gridIcon(double g, Color colour) =>
    Icon(g == 0 ? Icons.grid_off : Icons.grid_4x4, size: 16, color: colour);

String presetMm(double value) {
  final text = value.toStringAsFixed(3);
  return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// Picks a value of [kind] for [projectId]. Returns the value chosen, or
/// null if the sheet was dismissed.
Future<double?> showPresetValueSheet(
  BuildContext context, {
  required PresetValues kind,
  required String projectId,
  required double current,
}) => showModalBottomSheet<double>(
  context: context,
  backgroundColor: KicadPalette.surface,
  isScrollControlled: true,
  builder: (_) =>
      _PresetSheet(kind: kind, projectId: projectId, current: current),
);

class _PresetSheet extends ConsumerStatefulWidget {
  const _PresetSheet({
    required this.kind,
    required this.projectId,
    required this.current,
  });

  final PresetValues kind;
  final String projectId;
  final double current;

  @override
  ConsumerState<_PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends ConsumerState<_PresetSheet> {
  final _field = TextEditingController();

  PresetValues get _kind => widget.kind;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  double? get _typed {
    final value = double.tryParse(_field.text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 || value > _kind.maxValue ? null : value;
  }

  Future<void> _save(List<double> own) =>
      ref.read(projectSettingsRepositoryProvider).setAll(widget.projectId, {
        _kind.settingsKey: own.isEmpty ? null : own.map(presetMm).join(' '),
      });

  Future<void> _add(Map<String, String> settings) async {
    final value = _typed;
    if (value == null) return;
    final own = _kind.own(settings);
    if (!own.contains(value) && !_kind.builtIns.contains(value)) {
      await _save([...own, value]..sort());
    }
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(projectSettingsProvider(widget.projectId)).value ??
        const <String, String>{};
    final values = _kind.from(settings);
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(_kind.icon, size: 18, color: KicadPalette.highlight),
                    const SizedBox(width: 8),
                    Text(_kind.title, style: theme.textTheme.titleSmall),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _kind.description,
                        style: secondary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in values)
                      InputChip(
                        key: ValueKey('${_kind.keyPrefix}-${presetMm(value)}'),
                        avatar: _kind.chipIcon?.call(
                          value,
                          value == widget.current
                              ? KicadPalette.highlight
                              : KicadPalette.textSecondary,
                        ),
                        label: Text(_kind.label(value)),
                        selected: value == widget.current,
                        showCheckmark: false,
                        onSelected: (_) => Navigator.of(context).pop(value),
                        // Only the ones added here can be taken away.
                        onDeleted: _kind.builtIns.contains(value)
                            ? null
                            : () => _save([
                                for (final v in _kind.own(settings))
                                  if (v != value) v,
                              ]),
                        deleteButtonTooltipMessage:
                            'Remove ${presetMm(value)} mm',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextField(
                        key: ValueKey('${_kind.keyPrefix}-field'),
                        controller: _field,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: _kind.fieldLabel,
                          suffixText: 'mm',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _add(settings),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      key: ValueKey('${_kind.keyPrefix}-add'),
                      onPressed: _typed == null ? null : () => _add(settings),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('ADD AND USE'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kept with this project, like net classes',
                        style: secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A corner drawn at a radius, so each choice shows what it does.
class _CornerIcon extends CustomPainter {
  _CornerIcon({required this.radius, required this.colour});

  final double radius;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius == 0 ? 0.0 : (size.width * 0.25 * radius).clamp(3.0, 12.0);
    final path = Path()
      ..moveTo(2, size.height - 2)
      ..lineTo(2, 2 + r)
      ..arcToPoint(Offset(2 + r, 2), radius: Radius.circular(r))
      ..lineTo(size.width - 2, 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CornerIcon old) =>
      old.radius != radius || old.colour != colour;
}
