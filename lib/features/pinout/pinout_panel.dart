import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../domain/symbols/symbols.dart';
import '../components/component_browser_panel.dart';
import 'pinout_explorer.dart';

/// The chip the pinout explorer is showing, as a `lib_id`.
///
/// Kept outside the widget so switching to Components and back — or being
/// sent here from a part in the browser — lands on the same chip, and
/// written to settings so that closing the app does not lose it either.
final pinoutSymbolProvider = NotifierProvider<PinoutSymbol, String?>(
  PinoutSymbol.new,
);

class PinoutSymbol extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final stored = await ref
        .read(settingsRepositoryProvider)
        .get(SettingsRepository.pinoutSymbolKey);
    if (stored != null && stored.isNotEmpty && state == null) state = stored;
  }

  void select(String? libId) {
    state = libId;
    if (libId != null) {
      ref
          .read(settingsRepositoryProvider)
          .set(SettingsRepository.pinoutSymbolKey, libId);
    }
  }
}

/// The Pinout section: pick a chip, then explore it.
class PinoutPanel extends ConsumerStatefulWidget {
  const PinoutPanel({super.key});

  @override
  ConsumerState<PinoutPanel> createState() => _PinoutPanelState();
}

class _PinoutPanelState extends ConsumerState<PinoutPanel> {
  int _unit = 1;

  /// Picks the chip, reusing the component search rather than growing a
  /// second one that would drift from it.
  Future<void> _chooseSymbol() async {
    final libId = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a microcontroller',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ComponentBrowserPanel(
                addLabel: 'PINOUT',
                // Microcontrollers only. The pin functions this section is
                // built on exist on nothing else — a diode's "pinout" is
                // two pins and no question worth asking.
                microcontrollersOnly: true,
                onAdd: (entry) => Navigator.of(context).pop(entry.libId),
              ),
            ),
          ],
        ),
      ),
    );
    if (libId == null || !mounted) return;
    ref.read(pinoutSymbolProvider.notifier).select(libId);
    setState(() => _unit = 1);
  }

  @override
  Widget build(BuildContext context) {
    final libraries = ref.watch(symbolLibrariesProvider).value ?? const [];
    if (libraries.isEmpty) {
      return const EmptyState(
        icon: Icons.settings_input_component_outlined,
        title: 'No chips to explore',
        message:
            'Import a KiCad symbol library under Libraries. STM32 libraries '
            'carry the alternate functions this view is built on.',
      );
    }

    final libId = ref.watch(pinoutSymbolProvider);
    if (libId == null) {
      return EmptyState(
        icon: Icons.settings_input_component_outlined,
        title: 'Pick a chip',
        message:
            'Its package is drawn here with every pin in place, and choosing '
            'a peripheral lights up the pins that can carry it.',
        action: FilledButton.icon(
          onPressed: _chooseSymbol,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('CHOOSE A CHIP'),
        ),
      );
    }

    final symbol = ref.watch(symbolDefinitionProvider(libId));
    return switch (symbol) {
      AsyncData(value: final value?) => Column(
        children: [
          _header(value),
          Expanded(
            child: PinoutExplorer(
              symbol: value,
              unit: _unit.clamp(1, value.unitCount),
            ),
          ),
        ],
      ),
      AsyncData() => EmptyState(
        icon: Icons.help_outline,
        title: '$libId is no longer available',
        message: 'Its library may have been removed.',
        action: FilledButton(
          onPressed: _chooseSymbol,
          child: const Text('CHOOSE ANOTHER'),
        ),
      ),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the symbol',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _header(SymbolDefinition symbol) {
    final theme = Theme.of(context);
    final peripherals = PinFunctions.of(symbol).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  symbol.libId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  peripherals == 0
                      ? '${symbol.pinCount} pins · no alternate functions in '
                            'this library'
                      : '${symbol.pinCount} pins · $peripherals peripherals',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (symbol.isMultiUnit) ...[
            const SizedBox(width: 10),
            DropdownButton<int>(
              value: _unit.clamp(1, symbol.unitCount),
              dropdownColor: KicadPalette.surfaceRaised,
              underline: const SizedBox.shrink(),
              items: [
                for (var unit = 1; unit <= symbol.unitCount; unit++)
                  DropdownMenuItem(value: unit, child: Text('Unit $unit')),
              ],
              onChanged: (value) => setState(() => _unit = value ?? _unit),
            ),
          ],
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _chooseSymbol,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('CHANGE'),
          ),
        ],
      ),
    );
  }
}
