import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/util/formatting_bytes.dart';
import '../../data/repositories/footprint_library_repository.dart';

/// The imported footprint libraries, one row each.
class FootprintLibraryTable extends StatelessWidget {
  const FootprintLibraryTable({super.key, required this.libraries});

  final List<FootprintLibraryInfo> libraries;

  static const _countWidth = 96.0;
  static const _sizeWidth = 72.0;
  static const _importedWidth = 88.0;
  static const _menuWidth = 48.0;

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
                width: _countWidth,
                child: Text(
                  'FOOTPRINTS',
                  style: style,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _sizeWidth,
                child: Text('SIZE', style: style, textAlign: TextAlign.right),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _importedWidth,
                child: Text(
                  'IMPORTED',
                  style: style,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: _menuWidth),
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
                _FootprintLibraryRow(library: libraries[index]),
          ),
        ),
      ],
    );
  }
}

class _FootprintLibraryRow extends ConsumerWidget {
  const _FootprintLibraryRow({required this.library});

  final FootprintLibraryInfo library;

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
            width: FootprintLibraryTable._countWidth,
            child: Text(
              '${library.footprintCount}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: KicadPalette.padThroughHole,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: FootprintLibraryTable._sizeWidth,
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
            width: FootprintLibraryTable._importedWidth,
            child: Text(
              formatTimestamp(library.importedAt),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: FootprintLibraryTable._menuWidth,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove',
              onPressed: () => _confirmRemove(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${library.nickname}?'),
        // Worth saying plainly: unlike a symbol, a footprint is never
        // snapshotted into a project, so removing its library leaves any
        // board that used it with a hole in it.
        content: const Text(
          'Boards using footprints from this library will show them as '
          'missing until it is imported again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(footprintLibraryRepositoryProvider)
        .deleteLibrary(library.id);
  }
}
