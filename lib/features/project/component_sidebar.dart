import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/saved_circuit_repository.dart';
import '../libraries/kicad_download_dialog.dart';
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
    this.onSavedCircuit,
    this.width = 340,
  });

  /// Puts a circuit saved from a selection on the sheet. Null hides the tab.
  final void Function(SavedCircuit circuit)? onSavedCircuit;

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

  /// Showing the circuits saved from selections.
  bool _saved = false;

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
            if (_saved)
              Expanded(child: _savedList())
            else
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
                    if (results.isEmpty && libraries.isEmpty) {
                      return _noLibraries();
                    }
                    if (results.isEmpty) {
                      return _message(
                        _starter
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
    if (libraries.isEmpty && widget.onSavedCircuit == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (widget.onSavedCircuit != null)
            _CategoryChip(
              key: const ValueKey('saved-circuits-tab'),
              label: 'Saved circuits',
              selected: _saved,
              onTap: () => setState(() {
                _saved = true;
                _starter = false;
              }),
            ),
          if (widget.onStarter != null)
            _CategoryChip(
              label: 'Starter circuits',
              selected: _starter,
              onTap: () => setState(() {
                _starter = true;
                _saved = false;
              }),
            ),
          _CategoryChip(
            label: 'All',
            selected: !_saved && !_starter && _libraryId == null,
            onTap: () => setState(() {
              _starter = false;
              _saved = false;
              _libraryId = null;
            }),
          ),
          for (final library in libraries)
            _CategoryChip(
              label: library.nickname,
              selected: !_saved && !_starter && _libraryId == library.id,
              onTap: () => setState(() {
                _starter = false;
                _saved = false;
                _libraryId = library.id;
              }),
            ),
        ],
      ),
    );
  }

  /// Circuits saved from a selection — tap one to put it on the sheet.
  Widget _savedList() {
    final saved = ref.watch(savedCircuitsProvider).value;
    if (saved == null) return const SizedBox.shrink();
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final circuit in saved)
        if (query.isEmpty || circuit.name.toLowerCase().contains(query))
          circuit,
    ];
    if (shown.isEmpty) {
      return _message(
        saved.isEmpty
            ? 'Nothing saved yet. Select a circuit on the sheet and press '
                  'Save to keep it here for any project.'
            : 'Nothing matches.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: shown.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: KicadPalette.border),
      itemBuilder: (context, index) => _SavedRow(
        circuit: shown[index],
        onTap: () => widget.onSavedCircuit!(shown[index]),
        onDelete: () => _deleteSaved(shown[index]),
      ),
    );
  }

  Future<void> _deleteSaved(SavedCircuit circuit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${circuit.name}"?'),
        content: const Text(
          'It goes from Saved circuits. Copies already on a sheet stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('saved-circuit-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(savedCircuitRepositoryProvider).delete(circuit.id);
  }

  /// Nothing to search yet: the way to get parts, right here.
  Widget _noLibraries() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No component libraries yet.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KicadPalette.textDisabled),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('sidebar-kicad-download'),
            onPressed: () => showKicadLibraryDownload(context),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('DOWNLOAD FROM KICAD'),
          ),
        ],
      ),
    ),
  );

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
    super.key,
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

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.circuit,
    required this.onTap,
    required this.onDelete,
  });

  final SavedCircuit circuit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('saved-circuit-${circuit.id}'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.fromLTRB(12, 7, 0, 7),
        child: Row(
          children: [
            Icon(Icons.bookmark_outline, size: 18, color: KicadPalette.wire),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    circuit.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: KicadPalette.textPrimary,
                    ),
                  ),
                  Text(
                    circuit.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('saved-circuit-delete-${circuit.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: KicadPalette.textDisabled,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
