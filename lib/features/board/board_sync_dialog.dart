import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/board_sync.dart';

/// Shows what the board is missing from the schematic, and brings it up to
/// date on UPDATE. Returns a line to tell the user what happened, or null
/// if nothing was done.
Future<String?> showBoardSyncDialog(
  BuildContext context, {
  required String projectId,
}) => showDialog<String>(
  context: context,
  builder: (_) => _BoardSyncDialog(projectId: projectId),
);

class _BoardSyncDialog extends ConsumerStatefulWidget {
  const _BoardSyncDialog({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_BoardSyncDialog> createState() => _BoardSyncDialogState();
}

class _BoardSyncDialogState extends ConsumerState<_BoardSyncDialog> {
  bool _place = true;
  bool _deleteOrphans = true;
  bool _working = false;

  Future<void> _apply(BoardSyncPlan plan) async {
    setState(() => _working = true);
    final sync = ref.read(boardSyncProvider);
    final undo = await sync.apply(
      widget.projectId,
      plan,
      place: _place,
      deleteOrphans: _deleteOrphans,
    );
    ref
        .read(editHistoryProvider.notifier)
        .push(
          widget.projectId,
          EditAction(
            label: 'Update board from schematic',
            undo: () => sync.undo(undo),
            redo: () => sync.redo(undo),
          ),
        );
    if (!mounted) return;
    final parts = <String>[
      if (plan.of(BoardSyncKind.add).isNotEmpty)
        '${plan.of(BoardSyncKind.add).length} added',
      if (plan.of(BoardSyncKind.swap).isNotEmpty)
        '${plan.of(BoardSyncKind.swap).length} swapped',
      if (plan.of(BoardSyncKind.remove).isNotEmpty)
        '${plan.of(BoardSyncKind.remove).length} removed',
      if (_deleteOrphans && plan.orphanTracks > 0)
        '${plan.orphanTracks} stray tracks cleared',
    ];
    Navigator.of(context).pop(
      parts.isEmpty
          ? 'Board is up to date'
          : 'Board updated: ${parts.join(', ')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(boardSyncPlanProvider(widget.projectId));
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Update board from schematic'),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: 560,
        child: switch (plan) {
          AsyncData(:final value) => _body(value, theme),
          AsyncError(:final error) => Text('Could not compare: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          key: const ValueKey('board-sync-apply'),
          onPressed: _working || !(plan.value?.hasWork ?? false)
              ? null
              : () => _apply(plan.value!),
          child: const Text('UPDATE'),
        ),
      ],
    );
  }

  Widget _body(BoardSyncPlan plan, ThemeData theme) {
    if (plan.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'The board matches the schematic. Values, designators and '
          'connections follow on their own; nothing here needs a decision.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: KicadPalette.textSecondary,
          ),
        ),
      );
    }
    final groups = <BoardSyncKind, List<BoardSyncChange>>{};
    for (final change in plan.changes) {
      (groups[change.kind] ??= []).add(change);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                entry.key.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      entry.key.isAction ||
                          entry.key == BoardSyncKind.orphanCopper
                      ? KicadPalette.highlight
                      : KicadPalette.warning,
                ),
              ),
            ),
            for (final change in entry.value)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 2),
                child: Text(
                  change.description,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (plan.of(BoardSyncKind.add).isNotEmpty)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _place,
              title: const Text('Place new parts in free spots'),
              subtitle: const Text('Otherwise they wait in the parts list'),
              onChanged: (value) => setState(() => _place = value ?? true),
            ),
          if (plan.orphanTracks > 0)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _deleteOrphans,
              title: Text(
                'Delete ${plan.orphanTracks} track'
                '${plan.orphanTracks == 1 ? '' : 's'} on no net',
              ),
              subtitle: const Text(
                'Drawn for connections the schematic no longer has',
              ),
              onChanged: (value) =>
                  setState(() => _deleteOrphans = value ?? true),
            ),
        ],
      ),
    );
  }
}
