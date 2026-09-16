import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/widgets/panel.dart';
import '../../data/import/kicad_project_importer.dart';
import '../../domain/models/models.dart';
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

  /// Opens a project made in desktop KiCad: its schematic, and its board
  /// and project file when they are picked with it.
  static Future<void> openKicad(BuildContext context, WidgetRef ref) async {
    void report(String message) => ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Pick the .kicad_sch, with the .kicad_pcb and .kicad_pro',
        // No MIME type exists for KiCad files, so filtering by extension
        // would hide them on most phones.
        type: FileType.any,
      );
    } catch (error) {
      if (context.mounted) report('Could not open the picker: $error');
      return;
    }
    if (picked.isEmpty || !context.mounted) return;

    PlatformFile? withExtension(String extension) => picked
        .where((f) => f.name.toLowerCase().endsWith(extension))
        .firstOrNull;
    final schematic = withExtension('.kicad_sch');
    if (schematic == null) {
      report('Pick the .kicad_sch — the board and project files come with it');
      return;
    }
    Future<String?> read(PlatformFile? file) async => file == null
        ? null
        : utf8.decode(await file.readAsBytes(), allowMalformed: true);

    report('Opening ${schematic.name}…');
    final KicadImportResult result;
    try {
      result = await ref
          .read(kicadImporterProvider)
          .import(
            name: schematic.name.replaceFirst(
              RegExp(r'\.kicad_sch$', caseSensitive: false),
              '',
            ),
            schematic: (await read(schematic))!,
            board: await read(withExtension('.kicad_pcb')),
            projectFile: await read(withExtension('.kicad_pro')),
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
        'delete' => _confirmDelete(context, ref),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', height: 44, child: Text('Properties…')),
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
