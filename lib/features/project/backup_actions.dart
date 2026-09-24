import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/edit_history.dart';
import '../../app/file_saver.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../data/archive/project_archive.dart';
import '../../data/export/project_exporter.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/snapshot_repository.dart';
import '../../domain/models/models.dart';
import 'project_screen.dart';

void _say(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

/// The file name a project's backup is saved under.
String backupFileName(Project project) =>
    '${ProjectExporter.fileNameFor(project.name)}.${ProjectArchive.extension}';

/// Saves the whole project as one backup file, in a folder the user picks
/// — or hands it to another app when [share] is set.
Future<void> backUpProject(
  BuildContext context,
  WidgetRef ref,
  Project project, {
  bool share = false,
}) async {
  try {
    final archive = await ref.read(projectArchiverProvider).capture(project.id);
    final bytes = archive.toBytes();
    final name = backupFileName(project);
    if (share) {
      final directory = Directory('${Directory.systemTemp.path}/zolt_share');
      if (!directory.existsSync()) await directory.create(recursive: true);
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: '${project.name} — Zolt backup',
        ),
      );
      return;
    }
    final saved = await ref
        .read(fileSaverProvider)
        .save(
          fileName: name,
          bytes: bytes,
          mimeType: 'application/octet-stream',
        );
    if (context.mounted && saved) _say(context, 'Backed up to $name');
  } catch (error) {
    if (context.mounted) _say(context, 'Could not back up: $error');
  }
}

/// Opens a backup file as a new project beside the others, and goes into
/// it. Nothing already on the phone is touched.
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: 'Pick a .${ProjectArchive.extension} backup',
      type: FileType.any,
    );
  } catch (error) {
    if (context.mounted) _say(context, 'Could not open the picker: $error');
    return;
  }
  if (picked.isEmpty || !context.mounted) return;
  final String projectId;
  try {
    projectId = await restoreBackupBytes(
      projects: ref.read(projectRepositoryProvider),
      archiver: ref.read(projectArchiverProvider),
      bytes: await picked.first.readAsBytes(),
    );
  } on FormatException catch (error) {
    if (context.mounted) _say(context, error.message);
    return;
  } catch (error) {
    if (context.mounted) _say(context, 'Could not restore: $error');
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(ProjectScreen.route(projectId));
}

/// The restore itself, apart from picking the file. A project already
/// called the same keeps its name; the restored one says what it is.
Future<String> restoreBackupBytes({
  required ProjectRepository projects,
  required ProjectArchiver archiver,
  required List<int> bytes,
}) async {
  final archive = ProjectArchive.fromBytes(bytes);
  final existing = await projects.getAll();
  final taken = existing.map((p) => p.name).toSet();
  var name = archive.projectName;
  if (taken.contains(name)) name = '$name (restored)';
  var n = 2;
  while (taken.contains(name)) {
    name = '${archive.projectName} (restored $n)';
    n++;
  }
  return archiver.restoreAsNew(archive, name: name);
}

/// Named save points for a project: take one, go back to one, tidy up.
Future<void> showSnapshotsDialog(BuildContext context, Project project) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SnapshotsDialog(project: project),
    );

class _SnapshotsDialog extends ConsumerStatefulWidget {
  const _SnapshotsDialog({required this.project});

  final Project project;

  @override
  ConsumerState<_SnapshotsDialog> createState() => _SnapshotsDialogState();
}

class _SnapshotsDialogState extends ConsumerState<_SnapshotsDialog> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    setState(() => _busy = true);
    final name = _name.text.trim().isEmpty
        ? 'Snapshot ${formatTimestamp(DateTime.now())}'
        : _name.text.trim();
    try {
      await ref.read(snapshotRepositoryProvider).take(widget.project.id, name);
      _name.clear();
    } catch (error) {
      if (mounted) _say(context, 'Could not take the snapshot: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A snapshot is the only way back to that version, so it goes only
  /// when the user says so.
  Future<void> _delete(ProjectSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${snapshot.name}"?'),
        content: const Text(
          'The project cannot be taken back to this version afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('snapshot-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: KicadPalette.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(snapshotRepositoryProvider).delete(snapshot.id);
  }

  Future<void> _restore(ProjectSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Go back to "${snapshot.name}"?'),
        content: const Text(
          'The project as it is now is saved as a snapshot first, so this '
          'can be undone by restoring that one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await ref.read(snapshotRepositoryProvider).restore(snapshot.id);
    // Undo history refers to ids and states that are now gone.
    ref.read(editHistoryProvider.notifier).clear();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    _say(context, 'Back to "${snapshot.name}"');
  }

  @override
  Widget build(BuildContext context) {
    final snapshots =
        ref.watch(projectSnapshotsProvider(widget.project.id)).value ??
        const <ProjectSnapshot>[];
    final secondary = TextStyle(
      fontSize: 12,
      color: KicadPalette.textSecondary,
    );
    return AlertDialog(
      title: const Text('Snapshots'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: 580,
        height: 300,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('snapshot-name'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name this point',
                      hintText: 'e.g. before rerouting the power',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _take(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('snapshot-take'),
                  onPressed: _busy ? null : _take,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('SAVE'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: snapshots.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing saved yet. A snapshot keeps the whole '
                        'project — schematic and board — to come back to.',
                        textAlign: TextAlign.center,
                        style: secondary,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final snapshot in snapshots)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              snapshot.automatic
                                  ? Icons.history
                                  : Icons.bookmark_outline,
                              size: 18,
                            ),
                            title: Text(snapshot.name),
                            subtitle: Text(
                              '${formatTimestamp(snapshot.createdAt)} · '
                              '${snapshot.partCount} parts · '
                              '${snapshot.trackCount} tracks',
                              style: secondary,
                            ),
                            trailing: Wrap(
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _restore(snapshot),
                                  child: const Text('RESTORE'),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: KicadPalette.error,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _delete(snapshot),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('DONE'),
        ),
      ],
    );
  }
}
