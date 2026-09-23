import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../domain/symbols/symbols.dart';
import '../home/home_screen.dart';
import '../pinout/pinout_panel.dart';
import 'pinout_view.dart';

/// The symbol currently shown in the detail pane, as a `lib_id`.
final selectedSymbolProvider = NotifierProvider<SelectedSymbol, String?>(
  SelectedSymbol.new,
);

class SelectedSymbol extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? libId) => state = libId;
}

/// The chip highlighted in the microcontroller picker. Separate from
/// [selectedSymbolProvider]: sharing it meant the picker opened showing
/// whatever was last looked at under Components — a diode, as often as not.
final selectedMcuProvider = NotifierProvider<SelectedSymbol, String?>(
  SelectedSymbol.new,
);

/// Whether a library holds microcontrollers, by KiCad's naming.
bool isMcuLibrary(String nickname) =>
    nickname.startsWith('MCU') || nickname.startsWith('CPU');

/// Search components and inspect their pinouts.
///
/// Used in two modes: on its own for browsing, and with [onAdd] set when a
/// project is picking a component to place, so the same search and the same
/// pinout serve both.
class ComponentBrowserPanel extends ConsumerWidget {
  const ComponentBrowserPanel({
    super.key,
    this.onAdd,
    this.addLabel = 'ADD',
    this.microcontrollersOnly = false,
  });

  final void Function(SymbolIndexEntry entry)? onAdd;
  final String addLabel;

  /// Narrows the search to microcontrollers, for the pinout explorer.
  final bool microcontrollersOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraries = ref.watch(symbolLibrariesProvider).value ?? const [];
    if (libraries.isEmpty) {
      return const EmptyState(
        icon: Icons.memory_outlined,
        title: 'No components to search',
        message:
            'Components come from KiCad symbol libraries. Import a '
            '.kicad_sym file under Libraries and they will appear here.',
      );
    }

    return Column(
      children: [
        _SearchBar(microcontrollersOnly: microcontrollersOnly),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 42,
                child: _ResultList(
                  onAdd: onAdd,
                  addLabel: addLabel,
                  microcontrollersOnly: microcontrollersOnly,
                ),
              ),
              VerticalDivider(width: 1, color: KicadPalette.border),
              Expanded(
                flex: 58,
                child: _SymbolDetail(
                  onAdd: onAdd,
                  addLabel: addLabel,
                  microcontrollersOnly: microcontrollersOnly,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.microcontrollersOnly});

  final bool microcontrollersOnly;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(symbolSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mcu = widget.microcontrollersOnly;
    final libraries = [
      for (final library
          in ref.watch(symbolLibrariesProvider).value ??
              const <SymbolLibraryInfo>[])
        if (!mcu || isMcuLibrary(library.nickname)) library,
    ];
    final filterProvider = mcu
        ? mcuLibraryFilterProvider
        : symbolLibraryFilterProvider;
    final chosen = ref.watch(filterProvider);
    final filter = libraries.any((l) => l.id == chosen) ? chosen : null;
    final results = ref.watch(symbolSearchProvider(mcu));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.microcontrollersOnly
                    ? 'Search microcontrollers — STM32F103, ATmega328'
                    : 'Search components — name, description, keywords',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _controller.clear();
                          ref.read(symbolSearchQueryProvider.notifier).set('');
                        },
                      ),
              ),
              onChanged: (value) =>
                  ref.read(symbolSearchQueryProvider.notifier).set(value),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              initialValue: filter,
              isExpanded: true,
              dropdownColor: KicadPalette.surfaceRaised,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(
                  child: Text(
                    mcu ? 'All MCU libraries' : 'All libraries',
                    maxLines: 1,
                  ),
                ),
                for (final library in libraries)
                  DropdownMenuItem(
                    value: library.id,
                    child: Text(
                      library.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  ref.read(filterProvider.notifier).set(value),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 74,
            child: Text(
              switch (results) {
                AsyncData(:final value) =>
                  value.length >= 200 ? '200+' : '${value.length}',
                _ => '…',
              },
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultList extends ConsumerWidget {
  const _ResultList({
    this.onAdd,
    required this.addLabel,
    this.microcontrollersOnly = false,
  });

  final void Function(SymbolIndexEntry entry)? onAdd;
  final String addLabel;
  final bool microcontrollersOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(symbolSearchProvider(microcontrollersOnly));
    final selection = microcontrollersOnly
        ? selectedMcuProvider
        : selectedSymbolProvider;
    final selected = ref.watch(selection);

    return switch (results) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.search_off,
        title: 'Nothing matches',
        message: microcontrollersOnly
            ? 'Only microcontrollers are listed here — KiCad keeps them in '
                  'its MCU_ libraries. Import one under Libraries if the '
                  'part you want is missing.'
            : 'Try fewer words, or a different library.',
      ),
      AsyncData(:final value) => ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: value.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: KicadPalette.border),
        itemBuilder: (context, index) {
          final entry = value[index];
          return _ResultRow(
            entry: entry,
            selected: entry.libId == selected,
            onTap: () => ref.read(selection.notifier).select(entry.libId),
            onAdd: onAdd == null ? null : () => onAdd!(entry),
            addLabel: addLabel,
          );
        },
      ),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Search failed',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.addLabel,
    this.onAdd,
  });

  final SymbolIndexEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 12),
        color: selected ? KicadPalette.surfaceRaised : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: entry.isPower
                                ? KicadPalette.symbolOutline
                                : KicadPalette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.libraryNickname,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  if (entry.description.isNotEmpty)
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.pinCount}p',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
            if (entry.isMultiUnit) ...[
              const SizedBox(width: 6),
              Text(
                '×${entry.unitCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.warning,
                ),
              ),
            ],
            if (onAdd != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: IconButton(
                  tooltip: addLabel,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: KicadPalette.wire,
                  onPressed: onAdd,
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _SymbolDetail extends ConsumerWidget {
  const _SymbolDetail({
    this.onAdd,
    required this.addLabel,
    this.microcontrollersOnly = false,
  });

  final void Function(SymbolIndexEntry entry)? onAdd;
  final String addLabel;
  final bool microcontrollersOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libId = ref.watch(
      microcontrollersOnly ? selectedMcuProvider : selectedSymbolProvider,
    );
    if (libId == null) {
      return const EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Select a component',
        message: 'Its pinout and properties appear here.',
      );
    }

    final symbol = ref.watch(symbolDefinitionProvider(libId));
    return switch (symbol) {
      AsyncData(value: final value?) => _SymbolDetailBody(
        symbol: value,
        onAdd: onAdd,
        addLabel: addLabel,
      ),
      AsyncData() => const EmptyState(
        icon: Icons.help_outline,
        title: 'That symbol is no longer available',
        message: 'Its library may have been removed.',
      ),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the symbol',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SymbolDetailBody extends ConsumerStatefulWidget {
  const _SymbolDetailBody({
    required this.symbol,
    required this.addLabel,
    this.onAdd,
  });

  final SymbolDefinition symbol;
  final void Function(SymbolIndexEntry entry)? onAdd;
  final String addLabel;

  @override
  ConsumerState<_SymbolDetailBody> createState() => _SymbolDetailBodyState();
}

class _SymbolDetailBodyState extends ConsumerState<_SymbolDetailBody> {
  SymbolDefinition get symbol => widget.symbol;
  void Function(SymbolIndexEntry entry)? get onAdd => widget.onAdd;
  String get addLabel => widget.addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only offered where there is something behind it. Sending a resistor
    // to the pinout explorer would be a promise the app cannot keep.
    final hasFunctions = PinFunctions.hasAny(symbol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol.libId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (symbol.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          symbol.description,
                          // Capped at two lines. A KiCad description can run
                          // to a paragraph, and on a phone in landscape it
                          // pushed the pin table off the bottom of the
                          // screen — the one thing the page is for.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 2,
                      children: [
                        _Fact(label: 'ref', value: '${symbol.reference}?'),
                        _Fact(label: 'units', value: '${symbol.unitCount}'),
                        _Fact(label: 'pins', value: '${symbol.pinCount}'),
                        if (symbol.isPower)
                          const _Fact(label: 'power', value: 'yes'),
                        if (symbol.isDerived)
                          _Fact(
                            label: 'extends',
                            value: symbol.extendsSymbol ?? '',
                          ),
                        if (symbol.footprint.isNotEmpty)
                          _Fact(label: 'fp', value: symbol.footprint),
                        // Says the pinout explorer has something to show
                        // for this part; the button beside it goes there.
                        if (hasFunctions)
                          _Fact(
                            label: 'peripherals',
                            value: '${PinFunctions.of(symbol).length}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // The pin functions used to be a second tab squeezed in
              // below this header, where a long description left them two
              // rows of screen to live in. They have a section of their own
              // now, with the package drawn beside them; this is the door.
              if (hasFunctions && onAdd == null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(pinoutSymbolProvider.notifier)
                          .select(symbol.libId);
                      ref
                          .read(homeSectionProvider.notifier)
                          .show(HomeSection.pinout);
                    },
                    icon: const Icon(
                      Icons.settings_input_component_outlined,
                      size: 16,
                    ),
                    label: const Text('PINOUT'),
                  ),
                ),
              if (onAdd != null)
                FilledButton.icon(
                  onPressed: () async {
                    final entry = await ref
                        .read(symbolLibraryRepositoryProvider)
                        .findByLibId(symbol.libId);
                    if (entry != null) onAdd!(entry);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(addLabel),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: KicadPalette.border),
        Expanded(child: PinoutView(symbol: symbol)),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: KicadPalette.textDisabled,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: KicadPalette.textPrimary,
          ),
        ),
      ],
    );
  }
}
