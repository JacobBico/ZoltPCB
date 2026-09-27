import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/widgets/panel.dart';
import '../../data/import/kicad_picked_files.dart';
import '../../data/import/kicad_project_importer.dart';
import '../../domain/models/models.dart';
import '../project/backup_actions.dart';
import '../project/project_screen.dart';
import 'project_editor_dialog.dart';

/// Every design stored on the device.
class ProjectsPanel extends ConsumerWidget {
  const ProjectsPanel({super.key});

  /// Opens the new-project dialog and, if confirmed, creates the project and
  /// goes straight into it. Exposed so the home screen's toolbar button and
  /// the empty state can share one path.
  static Future<void> create(BuildContext context, WidgetRef ref) =>
      _createProject(context, ref);

  /// Which of several schematics is the top sheet: the one named like the
  /// project file, or else the one no other names as its sub-sheet.
  static String _topSheet(Map<String, String> schematics, {String? project}) {
    if (project != null) {
      final named = '${project.substring(0, project.length - 10)}.kicad_sch';
      if (schematics.containsKey(named)) return named;
    }
    final referenced = <String>{
      for (final text in schematics.values)
        for (final m in RegExp(
          r'\(property\s+"Sheetfile"\s+"([^"]+)"',
        ).allMatches(text))
          m.group(1)!,
    };
    return schematics.keys.firstWhere(
      (name) => !referenced.contains(name),
      orElse: () => schematics.keys.first,
    );
  }

  /// Opens a project made in desktop KiCad: its schematics, board and
  /// project file, picked together or as a `.zip` of the project folder.
  static Future<void> openKicad(BuildContext context, WidgetRef ref) async {
    void report(String message) => ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    final picked = KicadPickedFiles();
    Future<bool> pick(String title) async {
      final List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          dialogTitle: title,
          // No MIME type exists for KiCad files, so filtering by extension
          // would hide them on most phones.
          type: FileType.any,
        );
      } catch (error) {
        if (context.mounted) report('Could not open the picker: $error');
        return false;
      }
      for (final file in files) {
        picked.add(file.name, await file.readAsBytes());
      }
      return files.isNotEmpty;
    }

    if (!await pick(
      'Pick the .kicad_sch files with the .kicad_pcb and .kicad_pro, '
      'or a .zip of the project folder',
    )) {
      return;
    }
    if (!context.mounted) return;
    if (picked.schematics.isEmpty) {
      report('Pick the .kicad_sch files, or a .zip of the project folder');
      return;
    }

    // Each sub-sheet is a file of its own. One not picked would come in
    // empty, and its footprints would drop off the board, so say which.
    while (picked.missingSheets.isNotEmpty) {
      final missing = picked.missingSheets;
      final again = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            missing.length == 1
                ? 'A sheet was not picked'
                : '${missing.length} sheets were not picked',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(
                '${missing.map((m) => '• $m').join('\n')}\n\n'
                'Without them, their parts are left out, and their '
                'footprints with them. A .zip of the project folder brings '
                'everything at once.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('OPEN WITHOUT THEM'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('PICK THEM'),
            ),
          ],
        ),
      );
      if (!context.mounted || again == null) return;
      if (!again) break;
      await pick('Pick ${missing.join(', ')}');
      if (!context.mounted) return;
    }

    final projectFile = picked.withExtension('.kicad_pro');
    final schematics = picked.schematics;
    final topName = _topSheet(schematics, project: projectFile?.key);
    final baseName = topName.replaceFirst(
      RegExp(r'\.kicad_sch$', caseSensitive: false),
      '',
    );

    report('Opening $topName…');
    final KicadImportResult result;
    try {
      result = await ref
          .read(kicadImporterProvider)
          .import(
            name: baseName,
            schematic: schematics[topName]!,
            board: picked.withExtension('.kicad_pcb', project: baseName)?.value,
            projectFile: projectFile?.value,
            sheetFiles: {
              for (final entry in schematics.entries)
                if (entry.key != topName) entry.key: entry.value,
            },
          );
    } on KicadImportException catch (error) {
      if (context.mounted) report(error.message);
      return;
    } catch (error) {
      if (context.mounted) report('Could not open that project: $error');
      return;
    }
    if (!context.mounted) return;

    report(
      '${result.partCount} parts, ${result.netCount} nets'
      '${result.footprintCount > 0 ? ', ${result.footprintCount} footprints, ${result.trackCount} tracks' : ''}',
    );
    if (result.warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Opened, with notes'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(result.warnings.map((w) => '• $w').join('\n')),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      ProjectScreen.route(
        result.project.id,
        initialSection: ProjectSection.schematic,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(projectSummariesProvider);

    return switch (summaries) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.developer_board_outlined,
        title: 'No projects yet',
        message:
            'A project holds components, their pins and the nets between '
            'them. Everything stays on this device until you export it.',
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _createProject(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NEW PROJECT'),
            ),
            OutlinedButton.icon(
              onPressed: () => openKicad(context, ref),
              icon: const Icon(Icons.file_open_outlined, size: 16),
              label: const Text('OPEN KICAD'),
            ),
            OutlinedButton.icon(
              onPressed: () => restoreBackup(context, ref),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('RESTORE BACKUP'),
            ),
          ],
        ),
      ),
      AsyncData(:final value) => _ProjectTable(summaries: value),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not open the project database',
        message: '$error',
      ),
      // Opening a local database is effectively instantaneous, so
      // the loading frame shows nothing rather than flashing a
      // spinner that would never stop animating if the stream
      // stalled.
      _ => const SizedBox.shrink(),
    };
  }

  static Future<void> _createProject(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showProjectEditorDialog(context);
    if (result == null) return;

    final created = await ref
        .read(projectRepositoryProvider)
        .create(
          name: result.name,
          description: result.description,
          paper: result.paper,
          company: result.company,
          revision: result.revision,
        );

    if (!context.mounted) return;
    // An empty sheet has exactly one sensible first move, so the component
    // list is already open when it appears. Closing it keeps it closed.
    ref.read(componentPickerOpenProvider.notifier).set(true);
    await Navigator.of(context).push(
      ProjectScreen.route(created.id, initialSection: ProjectSection.schematic),
    );
  }
}

class _ProjectTable extends StatelessWidget {
  const _ProjectTable({required this.summaries});

  final List<ProjectSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ProjectTableHeader(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: summaries.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: KicadPalette.border),
            itemBuilder: (context, index) =>
                _ProjectRow(summary: summaries[index]),
          ),
        ),
      ],
    );
  }
}

/// Column widths shared by the header and the rows so they line up.
abstract final class _Columns {
  static const paper = 62.0;
  static const parts = 62.0;
  static const nets = 62.0;
  static const modified = 88.0;
  static const menu = 48.0;
}

class _ProjectTableHeader extends StatelessWidget {
  const _ProjectTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: KicadPalette.background,
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('NAME', style: style)),
          SizedBox(
            width: _Columns.paper,
            child: Text('PAPER', style: style),
          ),
          SizedBox(
            width: _Columns.parts,
            child: Text('PARTS', style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _Columns.nets,
            child: Text('NETS', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _Columns.modified,
            child: Text('MODIFIED', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: _Columns.menu),
        ],
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final project = summary.project;

    return InkWell(
      onTap: () => Navigator.of(context).push(ProjectScreen.route(project.id)),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (project.description.isNotEmpty)
                    Text(
                      project.description,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: _Columns.paper,
              child: Text(
                project.paper.kicadName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: _Columns.parts,
              child: Text(
                '${summary.partCount}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summary.partCount == 0
                      ? KicadPalette.textDisabled
                      : KicadPalette.symbolOutline,
                ),
              ),
            ),
            SizedBox(
              width: _Columns.nets,
              child: Text(
                '${summary.netCount}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summary.netCount == 0
                      ? KicadPalette.textDisabled
                      : KicadPalette.wire,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _Columns.modified,
              child: Text(
                formatTimestamp(project.modifiedAt),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: _Columns.menu,
              child: _ProjectMenu(project: project),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectMenu extends ConsumerWidget {
  const _ProjectMenu({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Project actions',
      icon: const Icon(Icons.more_vert, size: 18),
      color: KicadPalette.surfaceRaised,
      onSelected: (value) => switch (value) {
        'edit' => _edit(context, ref),
        'backup' => backUpProject(context, ref, project),
        'share-backup' => backUpProject(context, ref, project, share: true),
        'delete' => _confirmDelete(context, ref),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', height: 44, child: Text('Properties…')),
        PopupMenuItem(
          value: 'backup',
          height: 44,
          child: Text('Back up to a folder…'),
        ),
        PopupMenuItem(
          value: 'share-backup',
          height: 44,
          child: Text('Share a backup…'),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 44,
          child: Text('Delete', style: TextStyle(color: KicadPalette.error)),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showProjectEditorDialog(context, project: project);
    if (result == null) return;
    await ref
        .read(projectRepositoryProvider)
        .update(
          project.copyWith(
            name: result.name,
            description: result.description,
            paper: result.paper,
            company: result.company,
            revision: result.revision,
          ),
        );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: const Text(
          'Its components, pins and nets are deleted with it. Exported files '
          'already written to storage are not affected. This cannot be '
          'undone.',
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(projectRepositoryProvider).delete(project.id);
  }
}
