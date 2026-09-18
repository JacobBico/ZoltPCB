import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/models.dart';

/// What [showNoteDialog] collects.
class NoteResult {
  const NoteResult({
    required this.kind,
    required this.content,
    required this.size,
    required this.textSize,
  });

  final NoteKind kind;
  final String content;
  final Size size;
  final double textSize;
}

/// Writes a note on the sheet, or draws a box round a section.
Future<NoteResult?> showNoteDialog(
  BuildContext context, {
  SchematicNote? existing,
}) => showDialog<NoteResult>(
  context: context,
  builder: (_) => _NoteDialog(existing: existing),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.existing});

  final SchematicNote? existing;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late NoteKind _kind = widget.existing?.kind ?? NoteKind.text;
  late final _content = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  late final _width = TextEditingController(
    text: _fmt(
      (widget.existing?.size.width ?? 0) > 0
          ? widget.existing!.size.width
          : 50.8,
    ),
  );
  late final _height = TextEditingController(
    text: _fmt(
      (widget.existing?.size.height ?? 0) > 0
          ? widget.existing!.size.height
          : 30.48,
    ),
  );
  late double _textSize =
      widget.existing?.textSize ?? SchematicNote.defaultTextSize;

  static String _fmt(double v) {
    final t = v.toStringAsFixed(2);
    return t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  void dispose() {
    _content.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? get _problem {
    if (_kind == NoteKind.text && _content.text.trim().isEmpty) {
      return 'A note needs some words';
    }
    if (_kind == NoteKind.box) {
      final w = _parse(_width);
      final h = _parse(_height);
      if (w == null || h == null || w <= 0 || h <= 0) {
        return 'A box needs a width and a height';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add to the sheet' : 'Edit'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<NoteKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: NoteKind.text,
                    label: Text('Text'),
                    icon: Icon(Icons.notes, size: 16),
                  ),
                  ButtonSegment(
                    value: NoteKind.box,
                    label: Text('Box'),
                    icon: Icon(Icons.crop_din, size: 16),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('note-content'),
                controller: _content,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _kind == NoteKind.box ? 'Caption' : 'Text',
                  hintText: _kind == NoteKind.box
                      ? 'e.g. Power supply'
                      : 'e.g. 5 V rail, 500 mA max',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_kind == NoteKind.box) ...[
                    Expanded(
                      child: TextField(
                        controller: _width,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: numbers,
                        decoration: const InputDecoration(
                          labelText: 'Width',
                          suffixText: 'mm',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: numbers,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'mm',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  const Text('Size'),
                  const SizedBox(width: 6),
                  for (final size in const [1.27, 1.905, 2.54])
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(
                          size == 1.27
                              ? 'S'
                              : size == 1.905
                              ? 'M'
                              : 'L',
                        ),
                        selected: _textSize == size,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _textSize = size),
                      ),
                    ),
                ],
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
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
          key: const ValueKey('note-save'),
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(
                  NoteResult(
                    kind: _kind,
                    content: _content.text.trim(),
                    size: _kind == NoteKind.box
                        ? Size(_parse(_width)!, _parse(_height)!)
                        : Size.zero,
                    textSize: _textSize,
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
