import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/cross_probe.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/panel.dart';
import '../../core/widgets/section_rail.dart';
import '../../domain/models/models.dart';
import '../board/board_panel.dart';
import '../board/precision_board_panel.dart';
import '../panelize/panelize_panel.dart';
import '../production/production_panel.dart';
import '../projects/project_editor_dialog.dart';
import 'backup_actions.dart';
import 'components_panel.dart';
import 'export_panel.dart';
import 'nets_panel.dart';
import 'schematic_panel.dart';

/// Sections of the project workspace.
enum ProjectSection {
  overview('Overview', Icons.description_outlined),
  components('Components', Icons.memory_outlined),
  nets('Nets', Icons.account_tree_outlined),
  schematic('Schematic', Icons.grid_on_outlined),
  board('Board', Icons.developer_board_outlined),
  panel('Panelization', Icons.grid_view_outlined),
  production('Production', Icons.precision_manufacturing_outlined),
  export('Export', Icons.ios_share_outlined);

  const ProjectSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The workspace for one project.
class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({
    super.key,
    required this.projectId,
    this.initialSection = ProjectSection.overview,
  });

  final String projectId;

  /// Where the project opens. A brand-new project goes straight to the
  /// schematic: its overview would be a page of zeros with nothing to do on
  /// it, one more tap between the user and their first component.
  final ProjectSection initialSection;

  static Route<void> route(
    String projectId, {
    ProjectSection initialSection = ProjectSection.overview,
  }) => MaterialPageRoute(
    builder: (_) =>
        ProjectScreen(projectId: projectId, initialSection: initialSection),
  );

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  late ProjectSection _section = widget.initialSection;

  /// The rail is a sidebar, not furniture: it opens on demand and closes as
  /// soon as a section is chosen, so the section fills the screen.
  bool _railOpen = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));
    final loaded = project.value;
    final parts = ref.watch(projectPartsProvider(widget.projectId)).value;
    final nets = ref.watch(projectNetsProvider(widget.projectId)).value;

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: loaded?.name ?? 'Project',
            subtitle: _section.label,
            // No permanent back arrow: leaving the project is navigation,
            // and navigation lives in the sidebar. The system back gesture
            // still works.
            leading: IconButton(
              icon: Icon(_railOpen ? Icons.close : Icons.menu, size: 20),
              tooltip: _railOpen ? 'Close sections' : 'Sections',
              onPressed: () => setState(() => _railOpen = !_railOpen),
            ),
            actions: [
              // Snapshots belong to the whole project, so they are on the
              // bar every section shares rather than in any one of them.
              // Cross-probing: a live view of the other half, on the two
              // sections that have another half to show.
              if (loaded != null &&
                  (_section == ProjectSection.schematic ||
                      _section == ProjectSection.board))
                IconButton(
                  key: const ValueKey('cross-probe-toggle'),
                  tooltip: ref.watch(crossProbeOnProvider)
                      ? 'Hide the live view'
                      : (_section == ProjectSection.schematic
                            ? 'Show the board alongside'
                            : 'Show the schematic alongside'),
                  isSelected: ref.watch(crossProbeOnProvider),
                  icon: const Icon(
                    Icons.picture_in_picture_alt_outlined,
                    size: 20,
                  ),
                  selectedIcon: Icon(
                    Icons.picture_in_picture_alt,
                    size: 20,
                    color: KicadPalette.highlight,
                  ),
                  onPressed: () =>
                      ref.read(crossProbeOnProvider.notifier).toggle(),
                ),
              if (loaded != null)
                IconButton(
                  key: const ValueKey('snapshots-button'),
                  tooltip: 'Snapshots',
                  icon: const Icon(Icons.history, size: 20),
                  onPressed: () => showSnapshotsDialog(context, loaded),
                ),
              if (loaded != null) _action(loaded),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: switch (project) {
                AsyncData(value: final value?) => OverlayRail(
                  open: _railOpen,
                  header: RailLeaveItem(
                    label: 'All projects',
                    icon: Icons.arrow_back,
                    onTap: () {
                      setState(() => _railOpen = false);
                      Navigator.of(context).maybePop();
                    },
                  ),
                  selectedIndex: _section.index,
                  onDismiss: () => setState(() => _railOpen = false),
                  onSelect: (index) => setState(() {
                    _section = ProjectSection.values[index];
                    _railOpen = false;
                  }),
                  entries: [
                    for (final section in ProjectSection.values)
                      RailEntry(
                        label: section.label,
                        icon: section.icon,
                        badge: switch (section) {
                          ProjectSection.components =>
                            parts == null ? null : '${parts.length}',
                          ProjectSection.nets =>
                            nets == null ? null : '${nets.length}',
                          _ => null,
                        },
                        children: section == ProjectSection.schematic
                            ? _sheetEntries(value)
                            : const [],
                      ),
                  ],
                  child: _panel(value),
                ),
                AsyncData() => const EmptyState(
                  icon: Icons.delete_outline,
                  title: 'This project no longer exists',
                ),
                AsyncError(:final error) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load the project',
                  message: '$error',
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The schematic's sheets, for the side menu: once there are any, the
  /// Schematic entry drops down to show them all.
  List<RailSubEntry> _sheetEntries(Project project) {
    final sheets =
        ref.watch(projectSheetsProvider(project.id)).value ??
        const <SchematicSheet>[];
    final open = ref.watch(openSheetProvider(project.id));
    final tree = SheetTree(sheets);
    void go(String? sheetId) {
      ref.read(openSheetProvider(project.id).notifier).open(sheetId);
      setState(() {
        _section = ProjectSection.schematic;
        _railOpen = false;
      });
    }

    return [
      if (sheets.isNotEmpty) ...[
        RailSubEntry(
          label: 'Top sheet',
          icon: Icons.description_outlined,
          selected: open == null && _section == ProjectSection.schematic,
          onTap: () => go(null),
        ),
        for (final sheet in tree.inPageOrder())
          RailSubEntry(
            label: sheet.name,
            depth: tree.depthOf(sheet.id),
            selected: open == sheet.id && _section == ProjectSection.schematic,
            onTap: () => go(sheet.id),
          ),
      ],
      RailSubEntry(
        label: 'New sheet…',
        icon: Icons.add,
        onTap: () => _addSheet(project),
      ),
    ];
  }

  Future<void> _addSheet(Project project) async {
    setState(() => _railOpen = false);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('New sheet'),
        content: TextField(
          key: const ValueKey('rail-sheet-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sheet name',
            hintText: 'e.g. Power',
            isDense: true,
          ),
          onSubmitted: (text) => Navigator.of(dialog).pop(text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('rail-sheet-ok'),
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    // On whichever sheet is open, so a sheet made while looking at one
    // goes inside it.
    final parent = ref.read(openSheetProvider(project.id));
    final siblings = SheetTree(
      ref.read(projectSheetsProvider(project.id)).value ?? const [],
    ).childrenOf(parent).length;
    await ref
        .read(sheetRepositoryProvider)
        .add(
          projectId: project.id,
          name: name,
          parentId: parent,
          at: Offset(
            25.4 + 38.1 * (siblings % 5),
            25.4 + 30.48 * (siblings ~/ 5),
          ),
        );
    if (!mounted) return;
    setState(() => _section = ProjectSection.schematic);
  }

  Widget _action(Project project) => switch (_section) {
    // Adding a component is the main verb in all three of these sections.
    // Making the schematic send the user off to another tab to find a part
    // put a navigation step in the middle of the one task they are doing.
    // On the sheet the picker slides in beside the drawing rather than
    // pushing a full-screen browser, so the schematic stays in view.
    // Styled quietly to match the rest of the chrome: a filled accent
    // button was the loudest thing on screen, competing with the drawing.
    ProjectSection.schematic => OutlinedButton.icon(
      onPressed: () => ref.read(componentPickerOpenProvider.notifier).toggle(),
      icon: const Icon(Icons.add, size: 15),
      label: const Text('ADD'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: KicadPalette.textSecondary,
        side: BorderSide(color: KicadPalette.border),
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 0.4),
      ),
    ),
    // The board has no add button: everything on it comes from the
    // schematic, and its own verbs live on the canvas action bar.
    ProjectSection.board ||
    ProjectSection.panel ||
    ProjectSection.production => const SizedBox.shrink(),
    ProjectSection.components || ProjectSection.nets => FilledButton.icon(
      onPressed: () => ProjectComponentsPanel.add(context, project),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('ADD COMPONENT'),
    ),
    _ => OutlinedButton.icon(
      onPressed: () => _editProperties(project),
      icon: const Icon(Icons.tune, size: 16),
      label: const Text('PROPERTIES'),
    ),
  };

  Widget _panel(Project project) => switch (_section) {
    ProjectSection.overview => _OverviewPanel(project: project),
    ProjectSection.components => ProjectComponentsPanel(project: project),
    ProjectSection.nets => NetsPanel(project: project),
    ProjectSection.schematic => SchematicPanel(
      project: project,
      onShowBoard: () => setState(() => _section = ProjectSection.board),
    ),
    // Two board editors, chosen in Settings. See [BoardEditorStyle].
    ProjectSection.board => switch (ref.watch(appearanceProvider).boardEditor) {
      BoardEditorStyle.precision => PrecisionBoardPanel(
        project: project,
        onShowSchematic: () =>
            setState(() => _section = ProjectSection.schematic),
      ),
      BoardEditorStyle.classic => BoardPanel(
        project: project,
        onShowSchematic: () =>
            setState(() => _section = ProjectSection.schematic),
      ),
    },
    ProjectSection.panel => PanelizePanel(project: project),
    ProjectSection.production => ProductionPanel(project: project),
    ProjectSection.export => ExportPanel(project: project),
  };

  Future<void> _editProperties(Project project) async {
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
}

class _OverviewPanel extends ConsumerWidget {
  const _OverviewPanel({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = ref.watch(projectPartsProvider(project.id));
    final nets = ref.watch(projectNetsProvider(project.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PanelHeading('Sheet'),
                  const SizedBox(height: 4),
                  if (project.description.isNotEmpty)
                    FieldRow(label: 'Description', value: project.description),
                  FieldRow(
                    label: 'Size',
                    value:
                        '${project.paper.kicadName}  '
                        '${project.paper.widthMm.toStringAsFixed(0)} × '
                        '${project.paper.heightMm.toStringAsFixed(0)} mm',
                  ),
                  FieldRow(
                    label: 'Company',
                    value: project.company.isEmpty ? '—' : project.company,
                  ),
                  FieldRow(
                    label: 'Revision',
                    value: project.revision.isEmpty ? '—' : project.revision,
                  ),
                  FieldRow(
                    label: 'Created',
                    value: formatTimestamp(project.createdAt),
                  ),
                  FieldRow(
                    label: 'Modified',
                    value: formatTimestamp(project.modifiedAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PanelHeading('Contents'),
                  const SizedBox(height: 8),
                  _Counters(
                    parts: parts.value ?? const [],
                    nets: nets.value ?? const [],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.parts, required this.nets});

  final List<PartWithDetails> parts;
  final List<NetWithEndpoints> nets;

  @override
  Widget build(BuildContext context) {
    final pinCount = parts.fold<int>(0, (sum, p) => sum + p.pins.length);
    final connectedPins = nets.fold<int>(
      0,
      (sum, n) => sum + n.endpoints.length,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Counter(
            value: parts.length,
            label: 'components',
            color: KicadPalette.symbolOutline,
          ),
        ),
        Expanded(
          child: _Counter(
            value: nets.length,
            label: 'nets',
            color: KicadPalette.wire,
          ),
        ),
        Expanded(
          child: _Counter(
            value: pinCount == 0 ? 0 : pinCount - connectedPins,
            label: 'unconnected pins',
            color: pinCount > connectedPins
                ? KicadPalette.warning
                : KicadPalette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: theme.textTheme.displaySmall?.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: KicadPalette.textSecondary,
          ),
        ),
      ],
    );
  }
}
