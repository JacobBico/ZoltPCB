import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';

/// Names the widths a board is routed with, and says which nets use them.
///
/// Edits apply as they are made. It is setup, not a drawing operation, and
/// every change shows up at once on the list behind it.
Future<void> showNetClassesDialog(
  BuildContext context, {
  required String projectId,
  required DesignRules rules,
}) => showDialog<void>(
  context: context,
  builder: (_) => _NetClassesDialog(projectId: projectId, rules: rules),
);

class _NetClassesDialog extends ConsumerWidget {
  const _NetClassesDialog({required this.projectId, required this.rules});

  final String projectId;
  final DesignRules rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final classes = ref.watch(netClassesProvider(projectId)).value ?? const [];
    final nets = ref.watch(projectNetsProvider(projectId)).value ?? const [];
    final repository = ref.read(boardRepositoryProvider);

    return AlertDialog(
      title: const Text('Net classes'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A net in a class routes at the class width, and keeps the '
                'class clearance from other nets. Everything else uses the '
                'design rules: ${_mm(rules.trackWidth)} mm track, '
                '${_mm(rules.clearance)} mm clearance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (classes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No classes yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textDisabled,
                    ),
                  ),
                ),
              for (final netClass in classes)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(netClass.label),
                  subtitle: Text(
                    '${netClass.clearance == null ? 'design-rule clearance' : '${_mm(netClass.clearance!)} mm clearance'}'
                    ' · ${nets.where((n) => n.net.netClassId == netClass.id).length} nets',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Nets in ${netClass.name}',
                        icon: const Icon(Icons.hub_outlined, size: 18),
                        onPressed: () => _chooseNets(context, ref, netClass),
                      ),
                      IconButton(
                        tooltip: 'Edit ${netClass.name}',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          final edited = await _editClass(
                            context,
                            existing: netClass,
                          );
                          if (edited != null) {
                            await repository.updateNetClass(edited);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete ${netClass.name}',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: KicadPalette.error,
                        ),
                        onPressed: () => repository.deleteNetClass(netClass.id),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('ADD CLASS'),
          onPressed: () async {
            final created = await _editClass(context, projectId: projectId);
            if (created == null) return;
            await repository.addNetClass(
              projectId: projectId,
              name: created.name,
              trackWidth: created.trackWidth,
              clearance: created.clearance,
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('DONE'),
        ),
      ],
    );
  }

  Future<void> _chooseNets(
    BuildContext context,
    WidgetRef ref,
    NetClass netClass,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _NetPicker(projectId: projectId, netClass: netClass),
  );
}

/// Ticks nets in or out of one class.
class _NetPicker extends ConsumerWidget {
  const _NetPicker({required this.projectId, required this.netClass});

  final String projectId;
  final NetClass netClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nets = [...?ref.watch(projectNetsProvider(projectId)).value]
      ..sort(_namedFirst);
    final classes = ref.watch(netClassesProvider(projectId)).value ?? const [];
    final repository = ref.read(boardRepositoryProvider);

    return AlertDialog(
      title: Text('Nets in ${netClass.name}'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 460,
        height: 320,
        child: nets.isEmpty
            ? const Center(child: Text('No nets yet'))
            : ListView(
                children: [
                  for (final net in nets)
                    CheckboxListTile(
                      dense: true,
                      value: net.net.netClassId == netClass.id,
                      title: Text(net.displayName),
                      subtitle: switch (classes
                          .where((c) => c.id == net.net.netClassId)
                          .firstOrNull) {
                        final other? when other.id != netClass.id => Text(
                          'In ${other.name}',
                        ),
                        _ => null,
                      },
                      onChanged: (value) => repository.setNetClass(
                        net.net.id,
                        value == true ? netClass.id : null,
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

  static int _namedFirst(NetWithEndpoints a, NetWithEndpoints b) {
    if (a.net.isNamed != b.net.isNamed) return a.net.isNamed ? -1 : 1;
    return a.displayName.compareTo(b.displayName);
  }
}

Future<NetClass?> _editClass(
  BuildContext context, {
  NetClass? existing,
  String? projectId,
}) => showDialog<NetClass>(
  context: context,
  builder: (_) => _NetClassEditor(
    existing: existing,
    projectId: projectId ?? existing!.projectId,
  ),
);

class _NetClassEditor extends StatefulWidget {
  const _NetClassEditor({required this.existing, required this.projectId});

  final NetClass? existing;
  final String projectId;

  @override
  State<_NetClassEditor> createState() => _NetClassEditorState();
}

class _NetClassEditorState extends State<_NetClassEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _width = TextEditingController(
    text: widget.existing == null ? '' : _mm(widget.existing!.trackWidth),
  );
  late final _clearance = TextEditingController(
    text: widget.existing?.clearance == null
        ? ''
        : _mm(widget.existing!.clearance!),
  );

  @override
  void dispose() {
    for (final c in [_name, _width, _clearance]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? get _problem {
    if (_name.text.trim().isEmpty) return 'Give the class a name';
    final width = _parse(_width);
    if (width == null || width <= 0) return 'Width must be above zero';
    if (_clearance.text.trim().isNotEmpty) {
      final clearance = _parse(_clearance);
      if (clearance == null || clearance < 0) {
        return 'Clearance must be a number, or blank for the design rule';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    InputDecoration field(String label, {String? hint}) =>
        InputDecoration(labelText: label, hintText: hint, isDense: true);
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AlertDialog(
      title: Text(widget.existing == null ? 'New net class' : 'Net class'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: field('Name', hint: 'e.g. Power traces'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numbers,
                      decoration: field('Track width mm'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _clearance,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numbers,
                      decoration: field(
                        'Clearance mm',
                        hint: 'blank = design rule',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem,
                    style: TextStyle(color: KicadPalette.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () {
                  final clearance = _clearance.text.trim().isEmpty
                      ? null
                      : _parse(_clearance);
                  final existing = widget.existing;
                  Navigator.of(context).pop(
                    existing == null
                        ? NetClass(
                            id: '',
                            projectId: widget.projectId,
                            name: _name.text.trim(),
                            trackWidth: _parse(_width)!,
                            clearance: clearance,
                          )
                        : existing.copyWith(
                            name: _name.text.trim(),
                            trackWidth: _parse(_width),
                            clearance: clearance,
                            clearClearance: clearance == null,
                          ),
                  );
                },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

String _mm(double value) {
  final fixed = value.toStringAsFixed(3);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
