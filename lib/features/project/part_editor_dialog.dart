import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import 'value_keypad.dart';

/// Values collected by [showPartEditorDialog].
class PartEditorResult {
  const PartEditorResult({
    required this.reference,
    required this.value,
    required this.footprint,
    required this.dnp,
  });

  final String reference;
  final String value;
  final String footprint;
  final bool dnp;
}

/// Edits the fields of a placed component that end up in the BOM and the
/// exported schematic.
Future<PartEditorResult?> showPartEditorDialog(
  BuildContext context, {
  required Part part,
}) {
  return showDialog<PartEditorResult>(
    context: context,
    builder: (context) => _PartEditorDialog(part: part),
  );
}

class _PartEditorDialog extends StatefulWidget {
  const _PartEditorDialog({required this.part});

  final Part part;

  @override
  State<_PartEditorDialog> createState() => _PartEditorDialogState();
}

class _PartEditorDialogState extends State<_PartEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reference;
  late final TextEditingController _value;
  late final TextEditingController _footprint;
  late bool _dnp;

  /// Whether the value is being typed on the keypad rather than on the
  /// phone's keyboard.
  late bool _keypad;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.part.reference);
    _value = TextEditingController(text: widget.part.value);
    _footprint = TextEditingController(text: widget.part.footprint);
    _dnp = widget.part.dnp;
    _keypad = isNumericValuePart(widget.part.reference);
  }

  /// Whether this part's value is the kind the keypad is for.
  ///
  /// A resistor, capacitor or inductor has a number and a prefix for a
  /// value. A microcontroller has `STM32F103C8Tx`, which no keypad should
  /// try to help with — those open on the ordinary keyboard, and either can
  /// be switched to by hand.
  static bool isNumericValuePart(String reference) {
    final prefix = reference.replaceFirst(RegExp(r'[0-9?]+$'), '');
    return const {
      'R',
      'RV',
      'RT',
      'RN',
      'C',
      'CP',
      'L',
      'FB',
      'Y',
    }.contains(prefix);
  }

  @override
  void dispose() {
    _reference.dispose();
    _value.dispose();
    _footprint.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PartEditorResult(
        reference: _reference.text.trim(),
        value: _value.text.trim(),
        footprint: _footprint.text.trim(),
        dnp: _dnp,
      ),
    );
  }

  Widget _fields() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: _reference,
              decoration: const InputDecoration(labelText: 'Reference'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _value,
              // On the keypad the field is a display, not an input: an OS
              // keyboard opening over the keys would defeat the point.
              readOnly: _keypad,
              showCursor: true,
              autofocus: _keypad,
              decoration: InputDecoration(
                labelText: 'Value',
                suffixIcon: IconButton(
                  tooltip: _keypad ? 'Use the keyboard' : 'Use the keypad',
                  icon: Icon(
                    _keypad ? Icons.keyboard_alt_outlined : Icons.dialpad,
                    size: 18,
                  ),
                  color: KicadPalette.textSecondary,
                  onPressed: () => setState(() => _keypad = !_keypad),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _footprint,
        decoration: const InputDecoration(
          labelText: 'Footprint',
          hintText: 'Library:Footprint_Name',
        ),
      ),
      const SizedBox(height: 4),
      CheckboxListTile(
        value: _dnp,
        onChanged: (value) => setState(() => _dnp = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Do not populate'),
        subtitle: const Text(
          'Kept in the schematic, left off the assembled board',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.part.libId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Room for the floating labels. A TextFormField draws "Reference"
      // and "Value" above its own box, and at the old 12 they sat right
      // under the title and read as cut off by it.
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: _keypad ? 700 : 560,
        child: SingleChildScrollView(
          // Still scrollable for the keyboard case, where the OS keyboard
          // takes half the screen; the keypad itself now fits.
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _fields()),
                if (_keypad) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 300,
                    // Rebuilt as the controller changes so the field above
                    // shows what the keys are typing.
                    child: ValueKeypad(controller: _value),
                  ),
                ],
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
}
