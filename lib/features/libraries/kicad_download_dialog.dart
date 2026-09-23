import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/libraries/kicad_library_source.dart';
import '../../data/repositories/footprint_library_repository.dart';
import '../../domain/symbols/symbols.dart';
import 'kicad_library_downloader.dart';

/// Opens the KiCad library download: pick libraries, fetch them.
Future<void> showKicadLibraryDownload(BuildContext context) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => const Dialog.fullscreen(child: KicadDownloadPanel()),
);

/// Choose which of KiCad's own libraries to download, then download them.
///
/// The app ships with none; this fetches the same libraries a desktop
/// KiCad install comes with, straight from KiCad's repositories, and only
/// the ones picked.
class KicadDownloadPanel extends ConsumerStatefulWidget {
  const KicadDownloadPanel({super.key});

  @override
  ConsumerState<KicadDownloadPanel> createState() => _KicadDownloadPanelState();
}

enum _Stage { loading, failed, choosing, downloading, finished }

class _KicadDownloadPanelState extends ConsumerState<KicadDownloadPanel> {
  _Stage _stage = _Stage.loading;
  Object? _error;
  var _catalog = <RemoteLibraryKind, List<RemoteLibrary>>{};
  final _selected = <RemoteLibrary>{};
  RemoteLibraryKind _showing = RemoteLibraryKind.symbols;
  String _query = '';

  LibraryDownloadProgress? _progress;
  LibraryDownloadResult? _result;
  bool _cancelled = false;

  KicadLibraryDownloader get _downloader =>
      ref.read(kicadLibraryDownloaderProvider);

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      final lists = await Future.wait([
        _downloader.catalog(RemoteLibraryKind.symbols),
        _downloader.catalog(RemoteLibraryKind.footprints),
      ]);
      if (!mounted) return;
      final installed = _installed();
      setState(() {
        _catalog = {
          RemoteLibraryKind.symbols: lists[0],
          RemoteLibraryKind.footprints: lists[1],
        };
        // Start from the essentials not already here.
        _selected
          ..clear()
          ..addAll([
            for (final library in [...lists[0], ...lists[1]])
              if (KicadLibrarySource.essentials[library.kind]!.contains(
                    library.name,
                  ) &&
                  !installed.contains(library))
                library,
          ]);
        _stage = _Stage.choosing;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _stage = _Stage.failed;
      });
    }
  }

  /// What is already imported, as the libraries KiCad would call it.
  Set<RemoteLibrary> _installed() => {
    for (final info
        in ref.read(symbolLibrariesProvider).value ??
            const <SymbolLibraryInfo>[])
      RemoteLibrary(kind: RemoteLibraryKind.symbols, name: info.nickname),
    for (final info
        in ref.read(footprintLibrariesProvider).value ??
            const <FootprintLibraryInfo>[])
      RemoteLibrary(kind: RemoteLibraryKind.footprints, name: info.nickname),
  };

  Future<void> _download() async {
    // Symbols first: they are what the schematic needs to start.
    final picked = [
      for (final kind in RemoteLibraryKind.values)
        for (final library in _catalog[kind] ?? const <RemoteLibrary>[])
          if (_selected.contains(library)) library,
    ];
    if (picked.isEmpty) return;
    setState(() {
      _stage = _Stage.downloading;
      _cancelled = false;
      _progress = LibraryDownloadProgress(done: 0, total: picked.length);
    });
    final result = await _downloader.download(
      picked,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      isCancelled: () => _cancelled,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _stage = _Stage.finished;
      _selected.removeAll(result.installed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.downloading;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: KicadPalette.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, busy),
              Divider(height: 1, color: KicadPalette.border),
              Expanded(
                child: switch (_stage) {
                  _Stage.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  _Stage.failed => _failed(context),
                  _Stage.choosing => _chooser(context),
                  _Stage.downloading => _downloading(context),
                  _Stage.finished => _finished(context),
                },
              ),
              _licence(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool busy) {
    final theme = Theme.of(context);
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 20),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Download KiCad libraries',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'The official KiCad ${KicadLibrarySource.version} symbols '
                  'and footprints, from gitlab.com/kicad',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_stage == _Stage.choosing)
            FilledButton.icon(
              key: const ValueKey('kicad-download-start'),
              onPressed: count == 0 ? null : _download,
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                count == 0
                    ? 'DOWNLOAD'
                    : 'DOWNLOAD $count ${count == 1 ? 'LIBRARY' : 'LIBRARIES'}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _chooser(BuildContext context) {
    final installed = _installed();
    final all = _catalog[_showing] ?? const <RemoteLibrary>[];
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final library in all)
        if (query.isEmpty ||
            library.name.toLowerCase().contains(query) ||
            library.description.toLowerCase().contains(query))
          library,
    ];
    int picked(RemoteLibraryKind kind) =>
        _selected.where((l) => l.kind == kind).length;

    void select(Iterable<RemoteLibrary> libraries, bool on) => setState(() {
      on ? _selected.addAll(libraries) : _selected.removeAll(libraries);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              SegmentedButton<RemoteLibraryKind>(
                showSelectedIcon: false,
                segments: [
                  for (final kind in RemoteLibraryKind.values)
                    ButtonSegment(
                      value: kind,
                      label: Text(
                        '${kind == RemoteLibraryKind.symbols ? 'Symbols' : 'Footprints'}'
                        ' ${picked(kind)}/${_catalog[kind]?.length ?? 0}',
                      ),
                    ),
                ],
                selected: {_showing},
                onSelectionChanged: (value) =>
                    setState(() => _showing = value.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('kicad-download-search'),
                  decoration: const InputDecoration(
                    hintText: 'Search libraries…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('kicad-download-essentials'),
                onPressed: () => setState(() {
                  _selected
                    ..removeWhere((l) => l.kind == _showing)
                    ..addAll([
                      for (final library in all)
                        if (KicadLibrarySource.essentials[_showing]!.contains(
                          library.name,
                        ))
                          library,
                    ]);
                }),
                child: const Text('ESSENTIALS'),
              ),
              TextButton(
                key: const ValueKey('kicad-download-all'),
                onPressed: () => select(shown, true),
                child: const Text('ALL'),
              ),
              TextButton(
                key: const ValueKey('kicad-download-none'),
                onPressed: () => select(shown, false),
                child: const Text('NONE'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: KicadPalette.border),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'Nothing matches.',
                    style: TextStyle(color: KicadPalette.textDisabled),
                  ),
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final library = shown[index];
                    final here = installed.contains(library);
                    return CheckboxListTile(
                      key: ValueKey(
                        'kicad-lib-${library.kind.name}-${library.name}',
                      ),
                      dense: true,
                      value: _selected.contains(library),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (on) => select([library], on ?? false),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              library.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (here) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: KicadPalette.success,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Installed — tick to update',
                              style: TextStyle(
                                fontSize: 11,
                                color: KicadPalette.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: library.description.isEmpty
                          ? null
                          : Text(
                              library.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: KicadPalette.textSecondary,
                              ),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _downloading(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    final current = progress?.current;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                current == null ? 'Finishing…' : 'Downloading ${current.name}',
                key: const ValueKey('kicad-download-current'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                progress == null
                    ? ''
                    : '${progress.done} of ${progress.total} libraries',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 16),
              Align(
                child: OutlinedButton(
                  key: const ValueKey('kicad-download-cancel'),
                  onPressed: _cancelled
                      ? null
                      : () => setState(() => _cancelled = true),
                  child: Text(
                    _cancelled ? 'STOPPING AFTER THIS ONE…' : 'CANCEL',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finished(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                result.failed.isEmpty ? Icons.check_circle : Icons.info_outline,
                size: 32,
                color: result.failed.isEmpty
                    ? KicadPalette.success
                    : KicadPalette.warning,
              ),
              const SizedBox(height: 8),
              Text(
                '${result.installed.length} '
                '${result.installed.length == 1 ? 'library' : 'libraries'} '
                'installed${result.cancelled ? ' before stopping' : ''}',
                key: const ValueKey('kicad-download-summary'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              if (result.failed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Could not install: '
                  '${[for (final e in result.failed.entries) '${e.key.name} (${e.value})'].join('; ')}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _stage = _Stage.choosing),
                    child: const Text('PICK MORE'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('kicad-download-done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _failed(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 28, color: KicadPalette.textDisabled),
          const SizedBox(height: 10),
          Text(
            'Could not reach KiCad\'s library list',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Check the phone is online, then try again. ($_error)',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: KicadPalette.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadCatalog,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    ),
  );

  Widget _licence(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: KicadPalette.border)),
    ),
    child: Text(
      'KiCad libraries © the KiCad Library Team, CC-BY-SA 4.0 — with an '
      'exception: designs you make with them are yours, under any licence.',
      style: TextStyle(fontSize: 11, color: KicadPalette.textDisabled),
    ),
  );
}
