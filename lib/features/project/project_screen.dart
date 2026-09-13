import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/panel.dart';
import '../../core/widgets/section_rail.dart';
import '../../domain/models/models.dart';
import '../board/board_panel.dart';
import '../board/precision_board_panel.dart';
import '../projects/project_editor_dialog.dart';
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
            actions: [if (loaded != null) _action(loaded)],
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
    ProjectSection.board => const SizedBox.shrink(),
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
    ProjectSection.schematic => SchematicPanel(project: project),
    // Two board editors, chosen in Settings. See [BoardEditorStyle].
    ProjectSection.board => switch (
      ref.watch(appearanceProvider).boardEditor
    ) {
      BoardEditorStyle.precision => PrecisionBoardPanel(project: project),
      BoardEditorStyle.classic => BoardPanel(project: project),
    },
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
