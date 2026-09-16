import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/footprint_library_repository.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';

/// Picks the footprint for one part, beside the board rather than instead
/// of it.
///
/// Opens filtered to footprints with the right number of pads, because that
/// is the one thing that makes a footprint wrong in a way no amount of
/// nudging fixes. The filter can be turned off — plenty of real parts have
/// a pad the symbol does not show.
class FootprintSidebar extends ConsumerStatefulWidget {
  const FootprintSidebar({
    super.key,
    required this.part,
    required this.currentLibId,
    required this.onChoose,
    required this.onClose,
    this.width = 360,
  });

  final PartWithDetails part;
  final String? currentLibId;
  final void Function(FootprintIndexEntry entry) onChoose;
  final VoidCallback onClose;
  final double width;

  @override
  ConsumerState<FootprintSidebar> createState() => _FootprintSidebarState();
}

class _FootprintSidebarState extends ConsumerState<FootprintSidebar> {
  final _controller = TextEditingController();
  String _query = '';
  String? _libraryId;
  late bool _matchPads;

  /// The symbol's own footprint filters, once looked up. Null until then,
  /// and empty for a symbol that states none.
  FootprintFilter? _filter;
  bool _matchFilter = true;

  /// How many pads the part needs: one per distinct pin number, which is
  /// how KiCad matches a symbol to a footprint.
  int get _padCount => widget.part.pins.map((p) => p.number).toSet().length;

  @override
  void initState() {
    super.initState();
    _matchPads = true;
    // A part whose symbol already names a footprint starts there, which is
    // usually the right answer straight out of the library.
    final suggested = widget.currentLibId ?? widget.part.part.footprint;
    if (suggested.isNotEmpty) {
      final name = suggested.split(':').last;
      _controller.text = name;
      _query = name;
    }
    _loadFilter();
  }

  /// Fetches the filters from the symbol the part came from.
  ///
  /// Looked up rather than stored on the part, because they are a property
  /// of the library symbol and a later version of the library may refine
  /// them.
  Future<void> _loadFilter() async {
    final entry = await ref
        .read(symbolLibraryRepositoryProvider)
        .findByLibId(widget.part.part.libId);
    if (!mounted) return;
    setState(() => _filter = FootprintFilter(entry?.footprintFilters ?? ''));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraries = ref.watch(footprintLibrariesProvider).value ?? const [];
    final repository = ref.watch(footprintLibraryRepositoryProvider);

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
            _header(theme),
            if (libraries.isEmpty)
              Expanded(child: _noLibraries(theme))
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Search footprints…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              _filters(libraries, theme),
              Divider(height: 1, color: KicadPalette.border),
              Expanded(
                child: FutureBuilder<List<FootprintIndexEntry>>(
                  key: ValueKey(
                    '$_query|$_libraryId|$_matchPads|$_matchFilter|'
                    '${_filter?.patterns.join(',')}|${libraries.length}',
                  ),
                  future: _search(repository),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _message(theme, '${snapshot.error}');
                    }
                    final results = snapshot.data;
                    if (results == null) {
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (results.isEmpty) {
                      return _message(
                        theme,
                        _matchFilter && !(_filter?.isEmpty ?? true)
                            ? 'Nothing suits this symbol in the installed '
                                  'libraries. Turn off "Suits" to see every '
                                  'footprint.'
                            : _matchPads
                            ? 'No footprint with $_padCount pads matches. '
                                  'Turn off the pad filter to see the rest.'
                            : 'Nothing matches',
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _row(theme, results[index]),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<List<FootprintIndexEntry>> _search(
    FootprintLibraryRepository repository,
  ) async {
    final filter = _filter;
    final filtering = _matchFilter && filter != null && !filter.isEmpty;

    final results = await repository.search(
      _query,
      libraryId: _libraryId,
      padCount: _matchPads ? _padCount : null,
      // The glob match happens here rather than in SQL: KiCad's globs lean
      // on `_`, which LIKE treats as a wildcard. Fetching wider and
      // filtering precisely is simpler than escaping every pattern.
      limit: filtering ? 3000 : 200,
    );
    if (!filtering) return results;
    return [
      for (final entry in results)
        if (filter.matches(entry.name)) entry,
    ].take(200).toList();
  }

  Widget _header(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Footprint for ${widget.part.part.reference}',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                '${widget.part.part.value} · $_padCount pads',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ],
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

  Widget _filters(
    List<FootprintLibraryInfo> libraries,
    ThemeData theme,
  ) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        if (_filter != null && !_filter!.isEmpty) ...[
          FilterChip(
            label: Text(
              'Suits ${_filter!.patterns.first}'
              '${_filter!.patterns.length > 1 ? ' +${_filter!.patterns.length - 1}' : ''}',
            ),
            tooltip: _filter!.patterns.join('  '),
            selected: _matchFilter,
            onSelected: (value) => setState(() => _matchFilter = value),
          ),
          const SizedBox(width: 8),
        ],
        FilterChip(
          label: Text('$_padCount pads'),
          selected: _matchPads,
          onSelected: (value) => setState(() => _matchPads = value),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('All'),
          selected: _libraryId == null,
          onSelected: (_) => setState(() => _libraryId = null),
        ),
        for (final library in libraries) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(library.nickname),
            selected: _libraryId == library.id,
            onSelected: (_) => setState(() => _libraryId = library.id),
          ),
        ],
      ],
    ),
  );

  Widget _row(ThemeData theme, FootprintIndexEntry entry) {
    final selected = entry.libId == widget.currentLibId;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: selected,
      title: Text(entry.name, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        '${entry.libraryNickname} · ${entry.padCount} pads'
        '${entry.isSurfaceMount ? ' · SMD' : ''}'
        '${entry.isThroughHole ? ' · THT' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: KicadPalette.textSecondary,
        ),
      ),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.add_circle_outline,
        size: 18,
        color: selected ? KicadPalette.success : KicadPalette.textSecondary,
      ),
      onTap: () => widget.onChoose(entry),
    );
  }

  Widget _noLibraries(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.dashboard_customize_outlined,
          size: 32,
          color: KicadPalette.textDisabled,
        ),
        const SizedBox(height: 10),
        Text(
          'No footprint libraries yet',
          style: theme.textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Import a .pretty folder — as a zip, or the .kicad_mod files '
          'themselves — from the Libraries screen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: KicadPalette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _message(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: KicadPalette.textSecondary,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
