import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';

/// Changes to make to every selected part. A null field is left as each
/// part has it.
class BulkEdit {
  const BulkEdit({
    this.value,
    this.footprint,
    this.dnp,
    this.fieldsHidden,
    this.inBom,
  });

  final String? value;
  final String? footprint;
  final bool? dnp;
  final bool? fieldsHidden;
  final bool? inBom;

  bool get isEmpty =>
      value == null &&
      footprint == null &&
      dnp == null &&
      fieldsHidden == null &&
      inBom == null;

  Part applyTo(Part part) => part.copyWith(
    value: value,
    footprint: footprint,
    dnp: dnp,
    fieldsHidden: fieldsHidden,
    inBom: inBom,
  );
}

/// One set of fields for several parts at once — a row of decoupling caps
/// all becoming 100n, or a whole block marked do-not-populate.
///
/// A field shows its value when every part agrees on it and is blank when
/// they differ; a blank field is left alone. A switch that is mixed stays
/// mixed until it is touched.
Future<BulkEdit?> showBulkEditDialog(
  BuildContext context, {
  required List<Part> parts,
}) => showDialog<BulkEdit>(
  context: context,
  builder: (_) => _BulkEditDialog(parts: parts),
);

class _BulkEditDialog extends StatefulWidget {
  const _BulkEditDialog({required this.parts});

  final List<Part> parts;

  @override
  State<_BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<_BulkEditDialog> {
  // What the parts share when the dialog opens, taken once, up front:
  // an edit is whatever differs from these.
  late final String? _originalValue;
  late final String? _originalFootprint;
  late final bool? _originalDnp;
  late final bool? _originalHidden;
  late final bool? _originalInBom;

  late final TextEditingController _value;
  late final TextEditingController _footprint;
  late bool? _dnp;
  late bool? _hidden;
  late bool? _inBom;

  @override
  void initState() {
    super.initState();
    _originalValue = _shared((p) => p.value);
    _originalFootprint = _shared((p) => p.footprint);
    _originalDnp = _shared((p) => p.dnp);
    _originalHidden = _shared((p) => p.fieldsHidden);
    _originalInBom = _shared((p) => p.inBom);
    _value = TextEditingController(text: _originalValue ?? '');
    _footprint = TextEditingController(text: _originalFootprint ?? '');
    _dnp = _originalDnp;
    _hidden = _originalHidden;
    _inBom = _originalInBom;
  }

  /// The value every part shares, or null when they differ.
  T? _shared<T>(T Function(Part) of) {
    final values = widget.parts.map(of).toSet();
    return values.length == 1 ? values.single : null;
  }

  @override
  void dispose() {
    _value.dispose();
    _footprint.dispose();
    super.dispose();
  }

  BulkEdit get _edit {
    String? text(TextEditingController c, String? original) {
      final t = c.text.trim();
      if (t.isEmpty && original == null) return null;
      if (t == original) return null;
      return t;
    }

    return BulkEdit(
      value: text(_value, _originalValue),
      footprint: text(_footprint, _originalFootprint),
      dnp: _dnp == _originalDnp ? null : _dnp,
      fieldsHidden: _hidden == _originalHidden ? null : _hidden,
      inBom: _inBom == _originalInBom ? null : _inBom,
    );
  }

  Widget _tristate(
    String title,
    String subtitle,
    bool? value,
    ValueChanged<bool> onChanged,
  ) => Expanded(
    child: CheckboxListTile(
      tristate: value == null,
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: Text(
        value == null ? 'Mixed — left as each part has it' : subtitle,
        style: TextStyle(fontSize: 11, color: KicadPalette.textSecondary),
      ),
      // A tristate box cycles through null; only true and false are ever
      // written, so a mixed one lands on "on" first.
      onChanged: (next) => onChanged(next ?? !(value ?? false)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final refs = [for (final p in widget.parts) p.reference]..sort();
    return AlertDialog(
      title: Text('Edit ${widget.parts.length} parts'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                refs.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: KicadPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('bulk-value'),
                      controller: _value,
                      decoration: InputDecoration(
                        labelText: 'Value',
                        hintText: _originalValue == null ? 'Mixed' : null,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const ValueKey('bulk-footprint'),
                      controller: _footprint,
                      decoration: InputDecoration(
                        labelText: 'Footprint',
                        hintText: _originalFootprint == null
                            ? 'Mixed'
                            : 'Library:Footprint_Name',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tristate(
                    'Do not populate',
                    'Left off the board',
                    _dnp,
                    (v) => setState(() => _dnp = v),
                  ),
                  _tristate(
                    'Hide labels',
                    'Designator and value',
                    _hidden,
                    (v) => setState(() => _hidden = v),
                  ),
                  _tristate(
                    'In BOM',
                    'Listed for ordering',
                    _inBom,
                    (v) => setState(() => _inBom = v),
                  ),
                ],
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
          key: const ValueKey('bulk-save'),
          onPressed: () => Navigator.of(context).pop(_edit),
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}
