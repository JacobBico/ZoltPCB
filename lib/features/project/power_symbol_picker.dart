import 'package:flutter/material.dart';

import '../../domain/symbols/symbols.dart';

/// Asks which supply to attach to a pin.
///
/// Ground gets its own button on the action bar because it is most of what
/// anyone places; everything else comes through here. The list is whatever
/// power symbols the user's own libraries hold, so a project that uses
/// `+3V3` and one that uses `VDD` are equally well served.
Future<SymbolIndexEntry?> showPowerSymbolPicker(
  BuildContext context, {
  required List<SymbolIndexEntry> entries,
  required String pinLabel,
}) {
  return showDialog<SymbolIndexEntry>(
    context: context,
    builder: (context) => _PowerSymbolPicker(
      entries: entries,
      pinLabel: pinLabel,
    ),
  );
}

class _PowerSymbolPicker extends StatefulWidget {
  const _PowerSymbolPicker({required this.entries, required this.pinLabel});

  final List<SymbolIndexEntry> entries;
  final String pinLabel;

  @override
  State<_PowerSymbolPicker> createState() => _PowerSymbolPickerState();
}

class _PowerSymbolPickerState extends State<_PowerSymbolPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = _query.trim().toLowerCase();
    final matches = terms.isEmpty
        ? widget.entries
        : widget.entries
              .where((e) => e.libId.toLowerCase().contains(terms))
              .toList();

    return AlertDialog(
      title: Text('Supply for ${widget.pinLabel}'),
      // Landscape leaves very little height, so the dialog gets a fixed,
      // scrollable body rather than growing with the list.
      content: SizedBox(
        width: 460,
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Filter',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No power symbols match',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in matches)
                            ActionChip(
                              label: Text(entry.name),
                              tooltip: entry.libId,
                              onPressed: () =>
                                  Navigator.of(context).pop(entry),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
