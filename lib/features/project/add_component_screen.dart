import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../domain/symbols/symbols.dart';
import '../components/component_browser_panel.dart';

/// Picks components out of the imported libraries and adds them to a
/// project.
///
/// Stays open after each add so several parts can go in without navigating
/// back and forth — placing a handful of components is the common case, and
/// a round trip per part would make it tedious on a phone.
class AddComponentScreen extends ConsumerStatefulWidget {
  const AddComponentScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  static Route<void> route(String projectId, String projectName) =>
      MaterialPageRoute(
        builder: (_) =>
            AddComponentScreen(projectId: projectId, projectName: projectName),
      );

  @override
  ConsumerState<AddComponentScreen> createState() => _AddComponentScreenState();
}

class _AddComponentScreenState extends ConsumerState<AddComponentScreen> {
  final _added = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Add component',
            subtitle: widget.projectName,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Back to the project',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              if (_added.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'added ${_added.join(', ')}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: KicadPalette.wire),
                  ),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('DONE'),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(top: false, child: _ComponentPicker(onAdd: _add)),
          ),
        ],
      ),
    );
  }

  Future<void> _add(SymbolIndexEntry entry) async {
    final libraries = ref.read(symbolLibraryRepositoryProvider);
    final parts = ref.read(partRepositoryProvider);

    final symbol = await libraries.loadSymbol(entry.libId);
    if (symbol == null) {
      if (mounted) _report('${entry.libId} could not be read');
      return;
    }

    try {
      final added = await parts.addPart(
        widget.projectId,
        symbol.toNewPartSpec(),
      );
      if (!mounted) return;
      setState(() => _added.add(added.part.reference));
      _report(
        '${added.part.reference} · ${added.part.value} added'
        '${added.part.isMultiUnit ? " (${added.part.unitCount} units)" : ""}',
      );
    } catch (error) {
      if (mounted) _report('Could not add ${entry.name}: $error');
    }
  }

  void _report(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

/// Indirection so the picker's import stays local to this file.
class _ComponentPicker extends StatelessWidget {
  const _ComponentPicker({required this.onAdd});

  final void Function(SymbolIndexEntry entry) onAdd;

  @override
  Widget build(BuildContext context) =>
      ComponentBrowserPanel(onAdd: onAdd, addLabel: 'ADD TO PROJECT');
}
