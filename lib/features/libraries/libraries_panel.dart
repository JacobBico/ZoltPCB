import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/util/formatting_bytes.dart';
import '../../core/widgets/panel.dart';
import '../../data/repositories/symbol_library_repository.dart';
import '../../domain/symbols/symbols.dart';
import 'footprint_import.dart';
import 'footprint_library_table.dart';

/// Which kind of library is being looked at.
enum LibraryKind {
  symbols('Symbols'),
  footprints('Footprints');

  const LibraryKind(this.label);

  final String label;
}

/// Imported KiCad libraries: symbols for the schematic, footprints for the
/// board.
///
/// HintPCB ships with no CAD data of its own. Everything here is a file the
/// user copied onto the phone — from their own KiCad install, or downloaded
/// — and imported.
class LibrariesPanel extends ConsumerStatefulWidget {
  const LibrariesPanel({super.key});

  /// Imports into whichever kind is on screen. The home screen's import
  /// button calls this, so it has to mean the obvious thing.
  static Future<void> import(BuildContext context, WidgetRef ref) =>
      _importSymbolLibrary(context, ref);

  static Future<void> importFootprints(BuildContext context, WidgetRef ref) =>
      _importFootprintLibrary(context, ref);

  @override
  ConsumerState<LibrariesPanel> createState() => _LibrariesPanelState();
}

class _LibrariesPanelState extends ConsumerState<LibrariesPanel> {
  LibraryKind _kind = LibraryKind.symbols;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              SegmentedButton<LibraryKind>(
                showSelectedIcon: false,
                segments: [
                  for (final kind in LibraryKind.values)
                    ButtonSegment(value: kind, label: Text(kind.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _kind == LibraryKind.symbols
                    ? _importSymbolLibrary(context, ref)
                    : _importFootprintLibrary(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  _kind == LibraryKind.symbols
                      ? 'IMPORT .kicad_sym'
                      : 'IMPORT .pretty',
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: KicadPalette.border),
        Expanded(
          child: _kind == LibraryKind.symbols
              ? _symbols(context, ref)
              : _footprints(context, ref),
        ),
      ],
    );
  }

  Widget _footprints(BuildContext context, WidgetRef ref) {
    final libraries = ref.watch(footprintLibrariesProvider);
    return switch (libraries) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'No footprint libraries yet',
        message:
            'The board needs footprints. Zip a .pretty folder from your '
            'KiCad install, copy it onto this device, and import it here — '
            'or import individual .kicad_mod files.',
        action: FilledButton.icon(
          onPressed: () => _importFootprintLibrary(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('IMPORT FOOTPRINTS'),
        ),
      ),
      AsyncData(:final value) => FootprintLibraryTable(libraries: value),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the footprint index',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _symbols(BuildContext context, WidgetRef ref) {
    final libraries = ref.watch(symbolLibrariesProvider);

    return switch (libraries) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No symbol libraries yet',
        message:
            'Import a .kicad_sym file to get components. KiCad keeps its '
            'stock libraries in its install directory; copy the ones you '
            'want onto this device and import them here.',
        action: FilledButton.icon(
          onPressed: () => _importSymbolLibrary(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('IMPORT LIBRARY'),
        ),
      ),
      AsyncData(:final value) => _LibraryTable(libraries: value),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the library index',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Picks and imports footprint libraries.
Future<void> _importFootprintLibrary(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await FootprintImport.run(
    ref.read(footprintLibraryRepositoryProvider),
    askNickname: (suggestion) =>
        context.mounted ? _askNickname(context, suggestion) : Future.value(),
  );
  if (!context.mounted || result.cancelled) return;
  _report(
    context,
    result.summary,
    isError: result.imported.isEmpty && result.failed.isNotEmpty,
  );
}

/// Loose `.kicad_mod` files carry no library name of their own — the picker
/// hands over the file, not the folder it came from — so it has to be asked
/// for rather than guessed.
Future<String?> _askNickname(BuildContext context, String suggestion) {
  final controller = TextEditingController(text: suggestion);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Name this library'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Library nickname',
          helperText: 'Footprints will be named Nickname:Footprint',
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('IMPORT'),
        ),
      ],
    ),
  );
}

Future<void> _importSymbolLibrary(BuildContext context, WidgetRef ref) async {
  final List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: 'Select .kicad_sym libraries',
      // Android's document picker has no MIME type for .kicad_sym, so
      // filtering by extension would hide the files on many devices.
      type: FileType.any,
    );
  } catch (error) {
    if (context.mounted) {
      _report(context, 'Could not open the picker: $error', isError: true);
    }
    return;
  }
  if (picked.isEmpty) return;

  final repository = ref.read(symbolLibraryRepositoryProvider);
  final imported = <String>[];
  final failed = <String>[];

  for (final file in picked) {
    try {
      // readAsBytes rather than the path: files chosen through Android's
      // Storage Access Framework arrive as content URIs with no readable
      // filesystem path.
      final bytes = await file.readAsBytes();
      final info = await repository.import(fileName: file.name, bytes: bytes);
      imported.add('${info.nickname} (${info.symbolCount})');
    } on LibraryImportException catch (e) {
      failed.add('${file.name}: ${e.message}');
    } catch (e) {
      failed.add('${file.name}: $e');
    }
  }

  if (!context.mounted) return;
  if (failed.isEmpty) {
    _report(context, 'Imported ${imported.join(', ')}');
  } else if (imported.isEmpty) {
    _report(context, failed.first, isError: true);
  } else {
    _report(
      context,
      'Imported ${imported.length}, ${failed.length} failed: '
      '${failed.first}',
      isError: true,
    );
  }
}

void _report(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFF3A1D1D)
            : KicadPalette.surfaceRaised,
      ),
    );
}

abstract final class _Columns {
  static const symbols = 78.0;
  static const size = 72.0;
  static const format = 96.0;
  static const imported = 88.0;
  static const menu = 48.0;
}

class _LibraryTable extends StatelessWidget {
  const _LibraryTable({required this.libraries});

  final List<SymbolLibraryInfo> libraries;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );

    return Column(
      children: [
        Container(
          height: 30,
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: KicadPalette.background,
            border: Border(bottom: BorderSide(color: KicadPalette.border)),
          ),
          child: Row(
            children: [
              Expanded(child: Text('LIBRARY', style: style)),
              SizedBox(
                width: _Columns.symbols,
                child: Text(
                  'SYMBOLS',
                  style: style,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _Columns.size,
                child: Text('SIZE', style: style, textAlign: TextAlign.right),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _Columns.format,
                child: Text('FORMAT', style: style),
              ),
              SizedBox(
                width: _Columns.imported,
                child: Text(
                  'IMPORTED',
                  style: style,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: _Columns.menu),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: libraries.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: KicadPalette.border),
            itemBuilder: (context, index) =>
                _LibraryRow(library: libraries[index]),
          ),
        ),
      ],
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.library});

  final SymbolLibraryInfo library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(library.nickname, style: theme.textTheme.bodyLarge),
                Text(
                  library.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _Columns.symbols,
            child: Text(
              '${library.symbolCount}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: KicadPalette.symbolOutline,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _Columns.size,
            child: Text(
              formatBytes(library.byteSize),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _Columns.format,
            child: Text(
              library.formatVersion == 0 ? '—' : '${library.formatVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: _Columns.imported,
            child: Text(
              formatTimestamp(library.importedAt),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: _Columns.menu,
            child: PopupMenuButton<String>(
              tooltip: 'Library actions',
              icon: const Icon(Icons.more_vert, size: 18),
              color: KicadPalette.surfaceRaised,
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(context, ref);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  height: 44,
                  child: Text(
                    'Remove',
                    style: TextStyle(color: KicadPalette.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${library.nickname}"?'),
        content: const Text(
          'Its symbols will no longer be searchable. Components already '
          'added to a project keep their pins and are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KicadPalette.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(symbolLibraryRepositoryProvider).deleteLibrary(library.id);
  }
}
