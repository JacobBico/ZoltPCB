import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../fab/silk_fonts.dart';
import '../../fab/truetype.dart';

/// What a silkscreen text dialog came back with.
class SilkscreenTextResult {
  const SilkscreenTextResult({
    required this.content,
    required this.size,
    required this.rotation,
    required this.back,
    this.font = '',
    this.deleted = false,
  });

  const SilkscreenTextResult.deleted()
    : content = '',
      size = 0,
      rotation = 0,
      back = false,
      font = '',
      deleted = true;

  final String content;
  final double size;
  final double rotation;
  final bool back;

  /// The font's id; empty for the stroke font. See [SilkFonts].
  final String font;
  final bool deleted;
}

/// Adds or edits a piece of free silkscreen text.
Future<SilkscreenTextResult?> showSilkscreenTextDialog(
  BuildContext context, {
  String content = '',
  double size = 1.0,
  double rotation = 0,
  bool back = false,
  bool existing = false,
  String font = '',
  Future<SilkFontInfo?> Function()? onAddFont,
}) => showDialog<SilkscreenTextResult>(
  context: context,
  builder: (context) => _SilkscreenTextDialog(
    content: content,
    size: size,
    rotation: rotation,
    back: back,
    existing: existing,
    font: font,
    onAddFont: onAddFont,
  ),
);

class _SilkscreenTextDialog extends StatefulWidget {
  const _SilkscreenTextDialog({
    required this.content,
    required this.size,
    required this.rotation,
    required this.back,
    required this.existing,
    required this.font,
    this.onAddFont,
  });

  /// Adds a font from the phone, returning it, or null if none was added.
  final Future<SilkFontInfo?> Function()? onAddFont;
  final String font;

  final String content;
  final double size;
  final double rotation;
  final bool back;
  final bool existing;

  @override
  State<_SilkscreenTextDialog> createState() => _SilkscreenTextDialogState();
}

class _SilkscreenTextDialogState extends State<_SilkscreenTextDialog> {
  late final TextEditingController _content;
  late final TextEditingController _size;
  late double _rotation;
  late bool _back;
  late String _font;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.content);
    _size = TextEditingController(text: _mm(widget.size));
    _rotation = widget.rotation;
    _back = widget.back;
    _font = widget.font;
  }

  static const _addFontValue = '\u0000add';

  Future<void> _pickFont(String? value) async {
    if (value == null) return;
    if (value != _addFontValue) {
      setState(() => _font = value);
      return;
    }
    final added = await widget.onAddFont?.call();
    if (added != null && mounted) setState(() => _font = added.id);
  }

  @override
  void dispose() {
    _content.dispose();
    _size.dispose();
    super.dispose();
  }

  double? get _sizeValue =>
      double.tryParse(_size.text.trim().replaceAll(',', '.'));

  String? get _problem {
    if (_content.text.trim().isEmpty) return 'Type something to print';
    final size = _sizeValue;
    // Below about 0.6 mm most board houses cannot print legibly at all.
    if (size == null || size < 0.4) return 'At least 0.4 mm tall';
    if (size > 10) return 'At most 10 mm tall';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      title: Text(widget.existing ? 'Silkscreen text' : 'Add silkscreen text'),
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _content,
                autofocus: !widget.existing,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  hintText: 'e.g. Zolt v1.0',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _size,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Height mm',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Front')),
                        ButtonSegment(value: true, label: Text('Back')),
                      ],
                      selected: {_back},
                      onSelectionChanged: (value) =>
                          setState(() => _back = value.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('silk-font'),
                initialValue: SilkFonts.available.any((f) => f.id == _font)
                    ? _font
                    : '',
                isDense: true,
                decoration: const InputDecoration(labelText: 'Font'),
                items: [
                  for (final font in SilkFonts.available)
                    DropdownMenuItem(value: font.id, child: Text(font.name)),
                  if (widget.onAddFont != null)
                    const DropdownMenuItem(
                      value: _addFontValue,
                      child: Text('Add a font from the phone…'),
                    ),
                ],
                onChanged: _pickFont,
              ),
              // The text as it will print, in the font picked.
              if (SilkFonts.byId(_font) case final font?)
                Container(
                  height: 44,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: _FontPreview(
                      _content.text.trim().isEmpty
                          ? 'Zolt'
                          : _content.text.trim(),
                      font,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final angle in const [0, 90, 180, 270])
                    ChoiceChip(
                      label: Text('$angle°'),
                      selected: _rotation == angle,
                      onSelected: (_) =>
                          setState(() => _rotation = angle.toDouble()),
                    ),
                ],
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem,
                    style: TextStyle(color: KicadPalette.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const SilkscreenTextResult.deleted()),
            child: Text('DELETE', style: TextStyle(color: KicadPalette.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(
                  SilkscreenTextResult(
                    content: _content.text.trim(),
                    size: _sizeValue!,
                    rotation: _rotation,
                    back: _back,
                    font: _font,
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

/// A line of text drawn in a silkscreen font, fitted to the box.
class _FontPreview extends CustomPainter {
  _FontPreview(this.text, this.font);

  final String text;
  final TrueTypeFont font;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height * 0.5;
    final width = SilkText.widthOf(text, font, height);
    final fit = width > size.width * 0.9 ? size.width * 0.9 / width : 1.0;
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final contour in SilkText.contours(
      text,
      font,
      centre: size.center(Offset.zero),
      height: height * fit,
    )) {
      path.addPolygon(contour, true);
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFFF4F4F0));
  }

  @override
  bool shouldRepaint(_FontPreview old) =>
      old.text != text || !identical(old.font, font);
}

/// What the designator dialog came back with.
class DesignatorResult {
  const DesignatorResult({
    required this.size,
    required this.hidden,
    this.resetPosition = false,
  });

  final double size;
  final bool hidden;
  final bool resetPosition;
}

/// A part's designator: how big it is printed, and whether it is at all.
Future<DesignatorResult?> showDesignatorDialog(
  BuildContext context, {
  required String reference,
  required double size,
  required bool hidden,
  required bool moved,
}) => showDialog<DesignatorResult>(
  context: context,
  builder: (context) => _DesignatorDialog(
    reference: reference,
    size: size,
    hidden: hidden,
    moved: moved,
  ),
);

class _DesignatorDialog extends StatefulWidget {
  const _DesignatorDialog({
    required this.reference,
    required this.size,
    required this.hidden,
    required this.moved,
  });

  final String reference;
  final double size;
  final bool hidden;
  final bool moved;

  @override
  State<_DesignatorDialog> createState() => _DesignatorDialogState();
}

class _DesignatorDialogState extends State<_DesignatorDialog> {
  late double _size;
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _size = widget.size;
    _hidden = widget.hidden;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.reference} on the silkscreen'),
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: !_hidden,
              onChanged: (value) => setState(() => _hidden = !value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Print the designator'),
              subtitle: const Text(
                'Off leaves it off the board; the part keeps its reference',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Height ${_mm(_size)} mm',
              style: TextStyle(color: KicadPalette.textSecondary, fontSize: 12),
            ),
            Slider(
              value: _size.clamp(0.4, 3.0),
              min: 0.4,
              max: 3.0,
              divisions: 26,
              label: '${_mm(_size)} mm',
              onChanged: _hidden
                  ? null
                  : (value) => setState(
                      () => _size = double.parse(value.toStringAsFixed(1)),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.moved)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              DesignatorResult(
                size: _size,
                hidden: _hidden,
                resetPosition: true,
              ),
            ),
            child: const Text('PUT BACK'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DesignatorResult(size: _size, hidden: _hidden)),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

String _mm(double value) {
  final text = value.toStringAsFixed(2);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}
