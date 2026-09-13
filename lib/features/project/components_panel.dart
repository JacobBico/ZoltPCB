import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../domain/models/models.dart';
import '../components/pin_type_style.dart';
import 'add_component_screen.dart';
import 'part_editor_dialog.dart';

/// The components placed in a project.
class ProjectComponentsPanel extends ConsumerWidget {
  const ProjectComponentsPanel({super.key, required this.project});

  final Project project;

  static Future<void> add(BuildContext context, Project project) =>
      Navigator.of(
        context,
      ).push(AddComponentScreen.route(project.id, project.name));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = ref.watch(projectPartsProvider(project.id));

    return switch (parts) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.memory_outlined,
        title: 'No components yet',
        message:
            'Add components from an imported symbol library. Their pins come '
            'with them, so the project stays complete even if the library is '
            'removed later.',
        action: FilledButton.icon(
          onPressed: () => add(context, project),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('ADD COMPONENT'),
        ),
      ),
      AsyncData(:final value) => _PartTable(project: project, parts: value),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the components',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

abstract final class _Columns {
  static const reference = 78.0;
  static const units = 56.0;
  static const pins = 52.0;
  static const menu = 48.0;
}

class _PartTable extends StatelessWidget {
  const _PartTable({required this.project, required this.parts});

  final Project project;
  final List<PartWithDetails> parts;

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
              SizedBox(
                width: _Columns.reference,
                child: Text('REF', style: style),
              ),
              Expanded(flex: 3, child: Text('VALUE', style: style)),
              Expanded(
                flex: 4,
                child: Text('SYMBOL / FOOTPRINT', style: style),
              ),
              SizedBox(
                width: _Columns.units,
                child: Text('UNITS', style: style, textAlign: TextAlign.right),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _Columns.pins,
                child: Text('PINS', style: style, textAlign: TextAlign.right),
              ),
              const SizedBox(width: _Columns.menu),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: parts.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: KicadPalette.border),
            itemBuilder: (context, index) =>
                _PartRow(project: project, part: parts[index]),
          ),
        ),
      ],
    );
  }
}

class _PartRow extends ConsumerWidget {
  const _PartRow({required this.project, required this.part});

  final Project project;
  final PartWithDetails part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = part.part;
    final powerPins = part.pins.where((x) => x.electricalType.isPower).length;

    return InkWell(
      onTap: () => _edit(context, ref),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: _Columns.reference,
              child: Text(
                p.reference,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: p.dnp
                      ? KicadPalette.textDisabled
                      : KicadPalette.fieldText,
                  decoration: p.dnp ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                p.value,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.libId,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                  if (p.footprint.isNotEmpty)
                    Text(
                      p.footprint,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: _Columns.units,
              child: Text(
                '${p.unitCount}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: p.isMultiUnit
                      ? KicadPalette.warning
                      : KicadPalette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _Columns.pins,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${part.pins.length}'),
                    if (powerPins > 0)
                      TextSpan(
                        text: ' +$powerPins',
                        style: TextStyle(
                          color: PinTypeStyle.color(PinElectricalType.powerIn),
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: _Columns.menu,
              child: PopupMenuButton<String>(
                tooltip: 'Component actions',
                icon: const Icon(Icons.more_vert, size: 18),
                color: KicadPalette.surfaceRaised,
                onSelected: (value) => switch (value) {
                  'edit' => _edit(context, ref),
                  'delete' => _confirmDelete(context, ref),
                  _ => null,
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    height: 44,
                    child: Text('Edit…'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 44,
                    child: Text(
                      'Delete',
                      style: TextStyle(color: KicadPalette.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showPartEditorDialog(context, part: part.part);
    if (result == null) return;
    await ref
        .read(partRepositoryProvider)
        .updatePart(
          part.part.copyWith(
            reference: result.reference,
            value: result.value,
            footprint: result.footprint,
            dnp: result.dnp,
          ),
        );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${part.part.reference}?'),
        content: const Text(
          'Its pins are removed from every net they are on. The other pins '
          'on those nets stay connected to each other.',
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
    await ref.read(partRepositoryProvider).deletePart(part.part.id);
  }
}
