import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';

/// A keypad for component values, in place of the phone's keyboard.
///
/// A value is almost always a number and an SI prefix — 10k, 100n, 4u7 — and
/// typing one on a full QWERTY keyboard means hunting for digits behind a
/// modifier, on a keyboard that covers half a landscape screen. Every key
/// that can appear in a value is here, and nothing else.
///
/// The prefix keys are not plain characters: KiCad, and every schematic ever
/// drawn by hand, writes the prefix *in place of* the decimal point, so
/// `4.7` then `u` gives `4u7`. Tapping a prefix when one is already there
/// replaces it rather than appending a second.
class ValueKeypad extends StatelessWidget {
  const ValueKeypad({super.key, required this.controller});

  final TextEditingController controller;

  /// The SI prefixes a passive value can carry, small to large. `u` rather
  /// than `µ`: it is what KiCad writes and what every netlist parser reads.
  static const prefixes = ['p', 'n', 'u', 'm', 'k', 'M', 'G'];

  void _type(String key) {
    final text = controller.text;
    final selection = controller.selection;
    final at = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(at, end, key);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + key.length),
    );
  }

  /// Applies an SI prefix the way values are actually written.
  ///
  /// `4.7` + `u` becomes `4u7`, `10` + `k` becomes `10k`, and `10k` + `n`
  /// becomes `10n` — the prefix is a property of the value, so a second one
  /// replaces the first instead of stacking.
  void _prefix(String prefix) {
    var text = controller.text;
    for (final existing in prefixes) {
      final index = text.indexOf(existing);
      // Only a prefix sitting between digits or at the end is one; the `m`
      // of `1mH` is, the `M` of `MMBT3904` is not.
      if (index > 0 && RegExp(r'^\d').hasMatch(text)) {
        text = text.replaceRange(index, index + 1, '.');
        break;
      }
    }
    final dot = text.indexOf('.');
    final next = dot >= 0
        ? text.replaceRange(dot, dot + 1, prefix)
        : '$text$prefix';
    final trimmed = next.endsWith('.') ? next.substring(0, next.length - 1) : next;
    controller.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
  }

  void _backspace() {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      _type('');
      return;
    }
    final at = selection.isValid ? selection.start : text.length;
    if (at == 0) return;
    final next = text.replaceRange(at - 1, at, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rows, not a tall column of prefixes beside the digits: the phone
        // is in landscape, and there is barely 380 logical pixels of height
        // to spend on the whole dialog.
        for (final row in const [
          ['7', '8', '9'],
          ['4', '5', '6'],
          ['1', '2', '3'],
          ['0', '.', '⌫'],
        ])
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: _Key(
                    label: key,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      key == '⌫' ? _backspace() : _type(key);
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 2),
        // No unit symbols. A schematic writes 10k, not 10kΩ — the symbol
        // already says which it is, which is exactly why KiCad's own
        // libraries ship values like "100n" and "4k7". Leaving them out is
        // what lets the whole keypad fit without scrolling.
        Row(
          children: [
            for (final prefix in prefixes)
              Expanded(
                child: _Key(
                  label: prefix,
                  accent: true,
                  dense: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _prefix(prefix);
                  },
                ),
              ),
            Expanded(
              child: _Key(
                label: 'CLR',
                dense: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.clear();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.accent = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: accent
            ? KicadPalette.current.selectedContainer
            : KicadPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: dense ? 32 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: KicadPalette.border),
            ),
            child: Text(
              label,
              style: (dense ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
                  ?.copyWith(
                    color: accent
                        ? KicadPalette.highlight
                        : KicadPalette.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
