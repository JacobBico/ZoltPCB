import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pcb/pcb.dart';

/// What [showDesignRulesDialog] collects.
class BoardSettingsResult {
  const BoardSettingsResult({required this.rules, required this.gridMm});

  final DesignRules rules;
  final double gridMm;
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
}) {
  return showDialog<BoardSettingsResult>(
    context: context,
    builder: (context) => _DesignRulesDialog(board: board),
  );
}

class _DesignRulesDialog extends StatefulWidget {
  const _DesignRulesDialog({required this.board});

  final Board board;

  @override
  State<_DesignRulesDialog> createState() => _DesignRulesDialogState();
}

class _DesignRulesDialogState extends State<_DesignRulesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _trackWidth;
  late final TextEditingController _clearance;
  late final TextEditingController _viaDiameter;
  late final TextEditingController _viaDrill;
  late double _grid;

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
    _grid = _grids.contains(widget.board.gridMm) ? widget.board.gridMm : 0.5;
  }

  @override
  void dispose() {
    _trackWidth.dispose();
    _clearance.dispose();
    _viaDiameter.dispose();
    _viaDrill.dispose();
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
                      _field(_trackWidth, 'Track width'),
                      _field(_clearance, 'Clearance'),
                      _field(_viaDiameter, 'Via diameter'),
                      _field(_viaDrill, 'Via drill'),
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

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
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
        final parsed = double.tryParse(
          (value ?? '').trim().replaceAll(',', '.'),
        );
        if (parsed == null) return 'A number, please';
        if (parsed <= 0) return 'Must be greater than zero';
        return null;
      },
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rules = DesignRules(
      trackWidth: _value(_trackWidth)!,
      clearance: _value(_clearance)!,
      viaDiameter: _value(_viaDiameter)!,
      viaDrill: _value(_viaDrill)!,
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

    Navigator.of(context).pop(
      BoardSettingsResult(rules: rules, gridMm: _grid),
    );
  }
}
