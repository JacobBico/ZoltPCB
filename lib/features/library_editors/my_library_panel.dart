import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../data/editors/own_library_store.dart';
import '../../domain/editors/symbol_design.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart';
import '../../kicad/footprint_writer.dart';
import '../../kicad/sexpr/sexpr.dart';
import '../../kicad/sexpr/sexpr_writer.dart';
import '../../kicad/symbol_writer.dart';
import '../home/home_screen.dart';
import 'editor_requests.dart';
import 'footprint_match_dialog.dart';

/// Everything you have made: your symbols and your footprints, side by side,
/// with the one thing that joins them — which footprint each symbol uses.
class MyLibraryPanel extends ConsumerStatefulWidget {
  const MyLibraryPanel({super.key});

  @override
  ConsumerState<MyLibraryPanel> createState() => _MyLibraryPanelState();
}

enum _Showing { symbols, footprints }

class _MyLibraryPanelState extends ConsumerState<MyLibraryPanel> {
  _Showing _showing = _Showing.symbols;
  List<SymbolDefinition> _symbols = const [];
  List<FootprintDefinition> _footprints = const [];
  bool _loaded = false;

  /// Why the library could not be read, when it could not.
  Object? _loadError;

  OwnLibraryStore get _store => ref.read(ownLibraryStoreProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final symbols = await _store.loadSymbols();
      final footprints = await _store.loadFootprints();
      if (!mounted) return;
      setState(() {
        _symbols = symbols;
        _footprints = footprints;
        _loaded = true;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _editSymbol(String? name) {
    ref.read(symbolToEditProvider.notifier).open(name);
    ref.read(homeSectionProvider.notifier).show(HomeSection.symbols);
  }

  void _editFootprint(String? name) {
    ref.read(footprintToEditProvider.notifier).open(name);
    ref.read(homeSectionProvider.notifier).show(HomeSection.footprints);
  }

  Future<void> _match(SymbolDefinition symbol) async {
    final chosen = await showFootprintMatchDialog(
      context,
      pinNumbers: [for (final pin in symbol.pins) pin.number],
      current: symbol.footprint,
    );
    if (chosen == null || !mounted) return;
    final design = SymbolDesign.from(symbol).copyWith(footprint: chosen);
    await _store.saveSymbol(design.build(), previousName: symbol.name);
    await _reload();
  }

  Future<void> _delete(String what, Future<void> Function() delete) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete $what?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await delete();
    await _reload();
  }

  /// Hands your library to another app as KiCad files: a `.kicad_sym` for
  /// the symbols and a `.pretty` folder, zipped, for the footprints.
  Future<void> _share() async {
    final directory = ref.read(exportDirectoryProvider);
    if (!directory.existsSync()) await directory.create(recursive: true);
    final files = <XFile>[];

    if (_symbols.isNotEmpty) {
      final library = SList([
        SAtom('kicad_symbol_lib'),
        S.of('version', [20241209]),
        SList([SAtom('generator'), S.text('zolt')]),
        for (final s in _symbols) SymbolWriter.libSymbol(s, libId: s.name),
      ]);
      final file = File('${directory.path}/My_Symbols.kicad_sym');
      await file.writeAsString(const SExprWriter().write(library));
      files.add(XFile(file.path));
    }
    if (_footprints.isNotEmpty) {
      final archive = Archive();
      for (final f in _footprints) {
        archive.addFile(
          ArchiveFile.bytes(
            'My_Footprints.pretty/${f.name}.kicad_mod',
            utf8.encode(FootprintWriter.write(f)),
          ),
        );
      }
      final file = File('${directory.path}/My_Footprints.pretty.zip');
      await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      files.add(XFile(file.path));
    }
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: files, subject: 'My KiCad library'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'My Library could not be read',
        message: '$_loadError',
        action: OutlinedButton(
          onPressed: () {
            setState(() => _loadError = null);
            _reload();
          },
          child: const Text('TRY AGAIN'),
        ),
      );
    }
    if (!_loaded) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          // Wraps rather than overflowing: a phone in landscape is not wide
          // enough for the switch and both buttons on one line.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_Showing>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Showing.symbols,
                    icon: const Icon(Icons.schema_outlined, size: 16),
                    label: Text('My Symbols (${_symbols.length})'),
                  ),
                  ButtonSegment(
                    value: _Showing.footprints,
                    icon: const Icon(Icons.grid_on_outlined, size: 16),
                    label: Text('My Footprints (${_footprints.length})'),
                  ),
                ],
                selected: {_showing},
                onSelectionChanged: (v) => setState(() => _showing = v.first),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('SHARE AS KICAD'),
                onPressed: _symbols.isEmpty && _footprints.isEmpty
                    ? null
                    : _share,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  _showing == _Showing.symbols ? 'NEW SYMBOL' : 'NEW FOOTPRINT',
                ),
                onPressed: () => _showing == _Showing.symbols
                    ? _editSymbol(null)
                    : _editFootprint(null),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: KicadPalette.border),
        Expanded(
          child: switch (_showing) {
            _Showing.symbols when _symbols.isEmpty => EmptyState(
              icon: Icons.schema_outlined,
              title: 'No symbols of your own yet',
              message:
                  'Make one under Symbols. It appears here, and in Add '
                  'component beside the libraries you imported.',
              action: FilledButton(
                onPressed: () => _editSymbol(null),
                child: const Text('MAKE A SYMBOL'),
              ),
            ),
            _Showing.footprints when _footprints.isEmpty => EmptyState(
              icon: Icons.grid_on_outlined,
              title: 'No footprints of your own yet',
              message:
                  'Make one under Footprints — or, if the package already '
                  'exists in a library you imported, just match your symbol '
                  'to it.',
              action: FilledButton(
                onPressed: () => _editFootprint(null),
                child: const Text('MAKE A FOOTPRINT'),
              ),
            ),
            _Showing.symbols => ListView.separated(
              itemCount: _symbols.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: KicadPalette.border),
              itemBuilder: (context, index) {
                final symbol = _symbols[index];
                final footprint = symbol.footprint;
                return ListTile(
                  leading: const Icon(Icons.schema_outlined),
                  title: Text(symbol.name),
                  subtitle: Text(
                    '${symbol.pinCount} pins · '
                    '${footprint.isEmpty ? 'no footprint matched' : footprint}',
                    style: TextStyle(
                      color: footprint.isEmpty
                          ? KicadPalette.warning
                          : KicadPalette.textSecondary,
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('MATCH'),
                        onPressed: () => _match(symbol),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editSymbol(symbol.name),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: KicadPalette.error,
                        ),
                        onPressed: () => _delete(
                          symbol.name,
                          () => _store.deleteSymbol(symbol.name),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _Showing.footprints => ListView.separated(
              itemCount: _footprints.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: KicadPalette.border),
              itemBuilder: (context, index) {
                final footprint = _footprints[index];
                final users = [
                  for (final s in _symbols)
                    if (s.footprint == footprint.libId) s.name,
                ];
                return ListTile(
                  leading: const Icon(Icons.grid_on_outlined),
                  title: Text(footprint.name),
                  subtitle: Text(
                    '${footprint.padCount} pads · '
                    '${footprint.isSurfaceMount ? 'SMD' : 'through-hole'}'
                    '${users.isEmpty ? '' : ' · used by ${users.join(', ')}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editFootprint(footprint.name),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: KicadPalette.error,
                        ),
                        onPressed: () => _delete(
                          footprint.name,
                          () => _store.deleteFootprint(footprint.name),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}
