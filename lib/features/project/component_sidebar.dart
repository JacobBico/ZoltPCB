import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/symbols.dart';

/// The component picker that slides in over the schematic.
///
/// Adding a part used to push a full-screen browser, which took the user off
/// the drawing they were working on and back again for every component. This
/// keeps the sheet visible: pick a category, tap a part, it lands on the
/// sheet, and the list stays open for the next one.
class ComponentSidebar extends ConsumerStatefulWidget {
  const ComponentSidebar({
    super.key,
    required this.onAdd,
    required this.onClose,
    this.onStarter,
    this.width = 340,
  });

  /// Adds a microcontroller with its supporting parts. Null hides the tab.
  final void Function(SymbolIndexEntry entry)? onStarter;

  final void Function(SymbolIndexEntry entry) onAdd;
  final VoidCallback onClose;
  final double width;

  @override
  ConsumerState<ComponentSidebar> createState() => _ComponentSidebarState();
}

class _ComponentSidebarState extends ConsumerState<ComponentSidebar> {
  final _controller = TextEditingController();
  String _query = '';
  String? _libraryId;

  /// Showing microcontrollers to build a starter circuit round.
  bool _starter = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraries = ref.watch(symbolLibrariesProvider).value ?? const [];
    final repository = ref.watch(symbolLibraryRepositoryProvider);

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
            _header(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: TextField(
                controller: _controller,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search components…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            _categories(libraries),
            Divider(height: 1, color: KicadPalette.border),
            Expanded(
              child: FutureBuilder<List<SymbolIndexEntry>>(
                // Keyed by query and category so a change re-runs the search.
                key: ValueKey(
                  '$_query|$_libraryId|$_starter|${libraries.length}',
                ),
                future: _starter
                    ? repository.search(_query, microcontrollersOnly: true)
                    : repository.search(_query, libraryId: _libraryId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _message('Search failed: ${snapshot.error}');
                  }
                  final results = snapshot.data;
                  if (results == null) return const SizedBox.shrink();
                  if (results.isEmpty) {
                    return _message(
                      libraries.isEmpty
                          ? 'Import a .kicad_sym library first.'
                          : _starter
                          ? 'No microcontrollers. Import one of KiCad\'s '
                                'MCU_ libraries.'
                          : 'Nothing matches.',
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: KicadPalette.border),
                    itemBuilder: (context, index) => _ResultRow(
                      entry: results[index],
                      onTap: () => _starter
                          ? widget.onStarter!(results[index])
                          : widget.onAdd(results[index]),
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

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'ADD COMPONENT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
  );

  /// Libraries double as categories: `Amplifier_Operational`, `power`,
  /// `Device` and so on are already the groupings an engineer thinks in.
  Widget _categories(List<SymbolLibraryInfo> libraries) {
    if (libraries.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (widget.onStarter != null)
            _CategoryChip(
              label: 'Starter circuits',
              selected: _starter,
              onTap: () => setState(() => _starter = true),
            ),
          _CategoryChip(
            label: 'All',
            selected: !_starter && _libraryId == null,
            onTap: () => setState(() {
              _starter = false;
              _libraryId = null;
            }),
          ),
          for (final library in libraries)
            _CategoryChip(
              label: library.nickname,
              selected: !_starter && _libraryId == library.id,
              onTap: () => setState(() {
                _starter = false;
                _libraryId = library.id;
              }),
            ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: KicadPalette.textDisabled),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? KicadPalette.wire.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: selected ? KicadPalette.wire : KicadPalette.border,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? KicadPalette.wire : KicadPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.entry, required this.onTap});

  final SymbolIndexEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: entry.isPower
                                ? KicadPalette.symbolOutline
                                : KicadPalette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.libraryNickname,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  if (entry.description.isNotEmpty)
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.pinCount}p',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textDisabled,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.add, size: 18, color: KicadPalette.wire),
          ],
        ),
      ),
    );
  }
}
