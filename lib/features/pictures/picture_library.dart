import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/picture_repository.dart';
import '../board/silk_picture.dart';

/// The pictures that can go in a board's silkscreen: the app's own logo
/// and mark, and every picture imported from the phone.
///
/// The same grid is a page in the main menu, where pictures are added and
/// removed, and a pop-up on the board, where one is picked to place.
class PictureLibrary extends ConsumerWidget {
  const PictureLibrary({super.key, this.onPick});

  /// Called with the picture tapped. Null on the main menu's page, where a
  /// tap does nothing and the imported pictures can be deleted instead.
  final void Function(PreparedPicture picture)? onPick;

  /// Reads a picture from the phone, lets it be adjusted, and keeps it.
  static Future<PreparedPicture?> importFromPhone(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final PreparedPicture? prepared;
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Pick a picture',
        type: FileType.image,
      );
      if (picked.isEmpty || !context.mounted) return null;
      final file = picked.first;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return null;
      final name = file.name.replaceFirst(RegExp(r'\.[^.]*$'), '');
      prepared = await preparePicture(context, bytes, name);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
    if (prepared == null) return null;
    await ref
        .read(pictureRepositoryProvider)
        .add(
          name: prepared.name,
          width: prepared.width,
          columns: prepared.columns,
          rows: prepared.rows,
          bits: prepared.bits,
        );
    return prepared;
  }

  static Future<List<SilkPicture>>? _builtIns;

  /// The built-in pictures once drawn, so the library shows them at once
  /// every time after the first.
  static List<SilkPicture>? _builtInsReady;

  /// The app's own pictures, drawn once.
  static Future<List<SilkPicture>> builtIns() => _builtIns ??= () async {
    return _builtInsReady = [
      for (final which in BuiltInPicture.values)
        await builtInPicture(which).then(
          (p) => SilkPicture(
            id: 'builtin:${which.name}',
            name: p.name,
            width: p.width,
            columns: p.columns,
            rows: p.rows,
            bits: p.bits,
            builtIn: true,
          ),
        ),
    ];
  }();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(silkPicturesProvider).value ?? const [];
    return FutureBuilder<List<SilkPicture>>(
      future: builtIns(),
      initialData: _builtInsReady,
      builder: (context, snapshot) {
        final pictures = [...?snapshot.data, ...saved];
        return GridView.extent(
          padding: const EdgeInsets.all(12),
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _ImportTile(
              onTap: () async {
                final added = await importFromPhone(context, ref);
                if (added != null) onPick?.call(added);
              },
            ),
            for (final picture in pictures)
              _PictureTile(
                picture: picture,
                onTap: onPick == null
                    ? null
                    : () => onPick!(
                        PreparedPicture(
                          name: picture.name,
                          columns: picture.columns,
                          rows: picture.rows,
                          bits: picture.bits,
                          width: picture.width,
                        ),
                      ),
                onDelete: picture.builtIn || onPick != null
                    ? null
                    : () => ref
                          .read(pictureRepositoryProvider)
                          .delete(picture.id),
              ),
          ],
        );
      },
    );
  }
}

/// Opens the library over the board and returns the picture picked.
Future<PreparedPicture?> showPictureLibrary(BuildContext context) =>
    showDialog<PreparedPicture>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        child: SizedBox(
          width: 720,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pick a picture',
                        style: Theme.of(dialog).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(dialog).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PictureLibrary(
                  onPick: (picture) => Navigator.of(dialog).pop(picture),
                ),
              ),
            ],
          ),
        ),
      ),
    );

class _ImportTile extends StatelessWidget {
  const _ImportTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KicadPalette.surfaceRaised,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      key: const ValueKey('picture-import'),
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: KicadPalette.wire),
          const SizedBox(height: 6),
          Text(
            'Import from phone',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({required this.picture, this.onTap, this.onDelete});

  final SilkPicture picture;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: KicadPalette.surfaceRaised,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      key: ValueKey('picture-${picture.id}'),
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PictureThumbnail(
                columns: picture.columns,
                rows: picture.rows,
                bits: picture.bits,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    picture.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (picture.builtIn)
                  Text(
                    'built in',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: KicadPalette.textDisabled,
                    ),
                  ),
                if (onDelete != null)
                  IconButton(
                    key: ValueKey('picture-delete-${picture.id}'),
                    tooltip: 'Delete ${picture.name}',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: KicadPalette.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
