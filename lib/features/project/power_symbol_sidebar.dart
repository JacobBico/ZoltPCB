import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/symbols.dart';

/// Chooses a supply for a pin, from a panel down the right of the sheet.
///
/// It used to be a dialog whose filter field took focus the moment it
/// opened, so asking for +3V3 threw the keyboard up over half a landscape
/// screen before there was anything to type. The list is short enough to
/// tap straight from; the search is there for the libraries that are not,
/// and only brings the keyboard up when it is touched.
class PowerSymbolSidebar extends StatefulWidget {
  const PowerSymbolSidebar({
    super.key,
    required this.entries,
    required this.pinLabel,
    required this.onPick,
    required this.onClose,
    this.width = 300,
  });

  /// Null while the symbols are still being looked up.
  final List<SymbolIndexEntry>? entries;
  final String pinLabel;
  final void Function(SymbolIndexEntry entry) onPick;
  final VoidCallback onClose;
  final double width;

  @override
  State<PowerSymbolSidebar> createState() => _PowerSymbolSidebarState();
}

class _PowerSymbolSidebarState extends State<PowerSymbolSidebar> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries;
    final terms = _query.trim().toLowerCase();
    final matches = entries == null
        ? const <SymbolIndexEntry>[]
        : terms.isEmpty
        ? entries
        : entries.where((e) => e.libId.toLowerCase().contains(terms)).toList();

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: KicadPalette.surface,
        border: Border(left: BorderSide(color: KicadPalette.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'SUPPLY FOR ${widget.pinLabel}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: KicadPalette.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: TextField(
                controller: _controller,
                // Deliberately not autofocused: see the class comment.
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search supplies…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Divider(height: 1, color: KicadPalette.border),
            Expanded(
              child: entries == null
                  ? const SizedBox.shrink()
                  : matches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          entries.isEmpty
                              ? 'No power symbols. Import KiCad\'s power '
                                    'library.'
                              : 'Nothing matches.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.textDisabled,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: KicadPalette.border),
                      itemBuilder: (context, index) {
                        final entry = matches[index];
                        return InkWell(
                          onTap: () => widget.onPick(entry),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 46),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt_outlined,
                                  size: 16,
                                  color: KicadPalette.symbolOutline,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  entry.libraryNickname,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: KicadPalette.textDisabled,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
