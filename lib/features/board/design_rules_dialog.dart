import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'rule_diagrams.dart';

/// What [showDesignRulesDialog] collects.
class BoardSettingsResult {
  const BoardSettingsResult({
    required this.rules,
    required this.gridMm,
    this.fabPreset,
  });

  final DesignRules rules;
  final double gridMm;

  /// The board house the board is being made by, or null for none.
  final FabPreset? fabPreset;
}

/// The numbers a board is drawn to.
///
/// Track width, clearance and via size are the settings that decide whether
/// a board can be made at all, and they are the ones every fabricator quotes
/// on its capability page — which is why these four, and not the thirty
/// KiCad offers.
Future<BoardSettingsResult?> showDesignRulesDialog(
  BuildContext context, {
  required Board board,
  FabPreset? fabPreset,
}) {
  return showDialog<BoardSettingsResult>(
    context: context,
    builder: (context) =>
        _DesignRulesDialog(board: board, fabPreset: fabPreset),
  );
}

class _DesignRulesDialog extends StatefulWidget {
  const _DesignRulesDialog({required this.board, this.fabPreset});

  final Board board;
  final FabPreset? fabPreset;

  @override
  State<_DesignRulesDialog> createState() => _DesignRulesDialogState();
}

class _DesignRulesDialogState extends State<_DesignRulesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _trackWidth;
  late final TextEditingController _clearance;
  late final TextEditingController _viaDiameter;
  late final TextEditingController _viaDrill;
  late final TextEditingController _thermalGap;
  late final TextEditingController _thermalSpoke;
  late PadConnection _padConnection;
  late PadConnection _viaConnection;
  late double _grid;
  FabPreset? _fab;

  /// Grids anyone actually lays out on. 0.5 mm for general work, 0.1 mm for
  /// fine-pitch, 1.27 mm for through-hole on a 0.1 inch pitch.
  static const _grids = [0.1, 0.25, 0.5, 1.0, 1.27];

  @override
  void initState() {
    super.initState();
    final rules = widget.board.rules;
    _trackWidth = TextEditingController(text: _format(rules.trackWidth));
    _clearance = TextEditingController(text: _format(rules.clearance));
    _viaDiameter = TextEditingController(text: _format(rules.viaDiameter));
    _viaDrill = TextEditingController(text: _format(rules.viaDrill));
    _thermalGap = TextEditingController(text: _format(rules.thermalGap));
    _thermalSpoke = TextEditingController(text: _format(rules.thermalSpoke));
    _padConnection = rules.padConnection;
    _viaConnection = rules.viaConnection;
    _grid = _grids.contains(widget.board.gridMm) ? widget.board.gridMm : 0.5;
    _fab = widget.fabPreset;
  }

  /// Choosing a house draws the board to its recommended rules — the
  /// numbers are all still editable afterwards.
  void _chooseFab(FabPreset? preset) => setState(() {
    _fab = preset;
    if (preset == null) return;
    _trackWidth.text = _format(preset.rules.trackWidth);
    _clearance.text = _format(preset.rules.clearance);
    _viaDiameter.text = _format(preset.rules.viaDiameter);
    _viaDrill.text = _format(preset.rules.viaDrill);
  });

  @override
  void dispose() {
    _trackWidth.dispose();
    _clearance.dispose();
    _viaDiameter.dispose();
    _viaDrill.dispose();
    _thermalGap.dispose();
    _thermalSpoke.dispose();
    super.dispose();
  }

  static String _format(double value) {
    final text = value.toStringAsFixed(3);
    return text.contains('.')
        ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : text;
  }

  double? _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    // A landscape phone is about 360dp tall, and an AlertDialog's own
    // padding plus a title plus an action row leaves very little for the
    // content. Left to itself the content box overflows its allowance and
    // the first row of labels is clipped behind the title — which is
    // exactly what happened to "Track width".
    final available = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: const Text('Design rules'),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      content: SizedBox(
        // Landscape has width to spare and almost no height, so the fields
        // go in two columns rather than one long scroll.
        width: 620,
        height: math.max(140, available - 160),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(
                        _trackWidth,
                        'Track width',
                        const TrackWidthFigure(),
                      ),
                      _field(_clearance, 'Clearance', const ClearanceFigure()),
                      _field(_viaDiameter, 'Via diameter', const ViaFigure()),
                      _field(
                        _viaDrill,
                        'Via drill',
                        const ViaFigure(drill: true),
                      ),
                      const SizedBox(height: 4),
                      _heading(context, 'IN A POUR, ON ITS OWN NET'),
                      const SizedBox(height: 6),
                      Text(
                        'Pads',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      ConnectionPicker(
                        value: _padConnection,
                        onChanged: (value) =>
                            setState(() => _padConnection = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vias and plated holes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      ConnectionPicker(
                        via: true,
                        value: _viaConnection,
                        onChanged: (value) =>
                            setState(() => _viaConnection = value),
                      ),
                      if (_padConnection == PadConnection.thermal ||
                          _viaConnection == PadConnection.thermal) ...[
                        const SizedBox(height: 10),
                        _field(
                          _thermalGap,
                          'Thermal gap',
                          const ThermalFigure(),
                        ),
                        _field(
                          _thermalSpoke,
                          'Thermal spoke',
                          const ThermalFigure(spoke: true),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The board's size and shape have their own editor
                      // under Shape, which knows about circles and
                      // polygons; a width and height here could only ever
                      // describe a rectangle.
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('fab-preset'),
                        initialValue: _fab?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Board house',
                          isDense: true,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        items: [
                          const DropdownMenuItem(
                            child: Text('None — my own rules'),
                          ),
                          for (final preset in FabPresets.all)
                            DropdownMenuItem(
                              value: preset.id,
                              child: Text(preset.name),
                            ),
                        ],
                        onChanged: (id) => _chooseFab(FabPresets.byId(id)),
                      ),
                      if (_fab case final fab?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text(
                            'Makes down to ${_format(fab.minTrack)} mm '
                            'tracks and gaps, ${_format(fab.minViaDrill)} mm '
                            'drills, ${_format(fab.copperToEdge)} mm copper '
                            'to edge. Check flags anything past that. '
                            '${fab.note}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      DropdownButtonFormField<double>(
                        initialValue: _grid,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Grid',
                          isDense: true,
                        ),
                        items: [
                          for (final grid in _grids)
                            DropdownMenuItem(
                              value: grid,
                              child: Text('${_format(grid)} mm'),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _grid = value ?? _grid),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _submit, child: const Text('SAVE')),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    ),
  );

  /// A number, with a picture of what it measures beside it.
  ///
  /// "Clearance" and "Thermal gap" are both a gap in millimetres, and which
  /// gap is the whole question. A drawing answers it before the label is
  /// read.
  Widget _field(
    TextEditingController controller,
    String label,
    RuleFigure figure,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RulePicture(figure),
        const SizedBox(width: 10),
        Expanded(child: _numberField(controller, label)),
      ],
    ),
  );

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      suffixText: 'mm',
      isDense: true,
      // A floating label needs room above the field to float into, and
      // `isDense` does not leave it any. Keeping the label always up is
      // what stops it being clipped by whatever is above the field.
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    validator: (value) {
      final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
      if (parsed == null) return 'A number, please';
      if (parsed <= 0) return 'Must be greater than zero';
      return null;
    },
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rules = DesignRules(
      trackWidth: _value(_trackWidth)!,
      clearance: _value(_clearance)!,
      viaDiameter: _value(_viaDiameter)!,
      viaDrill: _value(_viaDrill)!,
      padConnection: _padConnection,
      viaConnection: _viaConnection,
      thermalGap: _value(_thermalGap) ?? 0.5,
      thermalSpoke: _value(_thermalSpoke) ?? 0.5,
    );

    // Caught here rather than at draw time: a via with no copper round its
    // hole is not a board anyone can make, and finding out after routing
    // fifty of them is too late.
    final problem = rules.problem;
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    Navigator.of(
      context,
    ).pop(BoardSettingsResult(rules: rules, gridMm: _grid, fabPreset: _fab));
  }
}
