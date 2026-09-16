import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/footprint_library_repository.dart';
import '../../domain/pcb/pcb.dart';

/// How a symbol's pins line up with a footprint's pads.
class PinPadMatch {
  const PinPadMatch({required this.missingPads, required this.unusedPads});

  /// Pin numbers the footprint has no pad for.
  final List<String> missingPads;

  /// Pads no pin will connect to.
  final List<String> unusedPads;

  bool get isExact => missingPads.isEmpty && unusedPads.isEmpty;

  static PinPadMatch of(
    Iterable<String> pinNumbers,
    FootprintDefinition footprint,
  ) {
    final pins = pinNumbers.toSet();
    final pads = {for (final pad in footprint.connectablePads) pad.number};
    return PinPadMatch(
      missingPads: [
        for (final n in pins)
          if (!pads.contains(n)) n,
      ]..sort(),
      unusedPads: [
        for (final n in pads)
          if (!pins.contains(n)) n,
      ]..sort(),
    );
  }

  String describe() {
    if (isExact) return 'Every pin has its pad';
    return [
      if (missingPads.isNotEmpty) 'no pad for pin ${missingPads.join(', ')}',
      if (unusedPads.isNotEmpty) 'pad ${unusedPads.join(', ')} unused',
    ].join(' · ');
  }
}

/// Picks a footprint for a symbol from every footprint on the phone —
/// your own and the ones imported from KiCad — and says whether its pads
/// match the symbol's pins before you commit to it.
Future<String?> showFootprintMatchDialog(
  BuildContext context, {
  required List<String> pinNumbers,
  String current = '',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _FootprintMatchDialog(pinNumbers: pinNumbers, current: current),
);

class _FootprintMatchDialog extends ConsumerStatefulWidget {
  const _FootprintMatchDialog({
    required this.pinNumbers,
    required this.current,
  });

  final List<String> pinNumbers;
  final String current;

  @override
  ConsumerState<_FootprintMatchDialog> createState() =>
      _FootprintMatchDialogState();
}

class _FootprintMatchDialogState extends ConsumerState<_FootprintMatchDialog> {
  late final _query = TextEditingController(
    text: widget.current.split(':').last,
  );
  bool _samePadCount = true;
  String? _chosen;
  FootprintDefinition? _preview;

  int get _padCount => widget.pinNumbers.toSet().length;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pick(FootprintIndexEntry entry) async {
    setState(() => _chosen = entry.libId);
    final loaded = await ref
        .read(footprintLibraryRepositoryProvider)
        .loadFootprint(entry.libId);
    if (mounted && _chosen == entry.libId) setState(() => _preview = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(footprintLibraryRepositoryProvider);
    final theme = Theme.of(context);
    final match = _preview == null
        ? null
        : PinPadMatch.of(widget.pinNumbers, _preview!);

    return AlertDialog(
      title: const Text('Match a footprint'),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      content: SizedBox(
        width: 620,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    decoration: const InputDecoration(
                      hintText: 'Search — SOT-23, 0603, SOIC-8…',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('$_padCount pads'),
                  selected: _samePadCount,
                  onSelected: (v) => setState(() => _samePadCount = v),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<FootprintIndexEntry>>(
                key: ValueKey('${_query.text}|$_samePadCount'),
                future: repository.search(
                  _query.text,
                  padCount: _samePadCount ? _padCount : null,
                  limit: 150,
                ),
                builder: (context, snapshot) {
                  final results = snapshot.data;
                  if (results == null) return const SizedBox.shrink();
                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        _samePadCount
                            ? 'No footprint with $_padCount pads matches. '
                                  'Turn the pad filter off, or make one under '
                                  'Footprints.'
                            : 'Nothing matches. Import a footprint library '
                                  'under Libraries, or make one under '
                                  'Footprints.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      return ListTile(
                        dense: true,
                        selected: entry.libId == _chosen,
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.libraryNickname} · ${entry.padCount} pads',
                        ),
                        onTap: () => _pick(entry),
                      );
                    },
                  );
                },
              ),
            ),
            if (match != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      match.isExact
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: match.isExact
                          ? KicadPalette.success
                          : KicadPalette.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        match.describe(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('CLEAR'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _chosen == null
              ? null
              : () => Navigator.of(context).pop(_chosen),
          child: const Text('USE'),
        ),
      ],
    );
  }
}
