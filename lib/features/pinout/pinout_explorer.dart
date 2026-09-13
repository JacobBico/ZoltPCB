import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/symbols.dart';
import 'package_diagram.dart';

/// Peripherals on the left, the package on the right.
///
/// The CubeMX arrangement, and for the same reason: "where can I put I2C1"
/// is a question about the whole chip at once, and the answer is a shape —
/// two pins on opposite corners, or four in a row — which a list of numbers
/// does not show. Picking a signal lights the pins; tapping a pin says what
/// else it could be, and jumps the list to it.
///
/// Used both on its own in the Pinout section and over a schematic, where
/// [usedPins] marks the pins already wired so the question becomes the one
/// that matters: not which pins can be SPI, but which pins can still be.
class PinoutExplorer extends StatefulWidget {
  const PinoutExplorer({
    super.key,
    required this.symbol,
    this.unit = 1,
    this.usedPins = const {},
  });

  final SymbolDefinition symbol;
  final int unit;

  /// Pad numbers already on a net.
  final Set<String> usedPins;

  @override
  State<PinoutExplorer> createState() => _PinoutExplorerState();
}

class _PinoutExplorerState extends State<PinoutExplorer> {
  String? _kind;
  String? _instance;
  String? _signal;
  String? _selectedPin;
  String _filter = '';

  @override
  void didUpdateWidget(PinoutExplorer old) {
    super.didUpdateWidget(old);
    if (old.symbol.libId != widget.symbol.libId) {
      _kind = null;
      _instance = null;
      _signal = null;
      _selectedPin = null;
      _filter = '';
    }
  }

  SymbolDefinition get symbol => widget.symbol;

  @override
  Widget build(BuildContext context) {
    final peripherals = PinFunctions.of(symbol);
    final layout = PackageLayout.of(symbol, unit: widget.unit);
    // Resolved once, here, and handed to both halves. Working it out
    // separately in each meant the chips showed SPI1 selected while the
    // package lit nothing up, because only one of the two fell back to the
    // first instance when nothing had been tapped yet.
    final instance = _resolve(peripherals);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 300, child: _peripherals(peripherals, instance)),
        VerticalDivider(width: 1, color: KicadPalette.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PackageDiagram(
              layout: layout,
              title: symbol.name,
              highlighted: _highlightedPins(instance),
              assigned: _assignedLabels(instance),
              used: widget.usedPins,
              selected: _selectedPin,
              onPinTap: _showPin,
            ),
          ),
        ),
      ],
    );
  }

  /// The peripheral in force: the one tapped, or the first of the selected
  /// kind when nothing has been tapped yet.
  Peripheral? _resolve(List<Peripheral> peripherals) {
    final byName = peripherals.where((p) => p.name == _instance).firstOrNull;
    if (byName != null) return byName;
    final kind = _kind ?? _kindsOf(peripherals).firstOrNull;
    return peripherals.where((p) => p.kind == kind).firstOrNull;
  }

  /// The pins to light up: the chosen signal's, or the whole peripheral's
  /// when no one signal is picked out.
  Set<String> _highlightedPins(Peripheral? instance) {
    if (instance == null) return const {};
    final signal = _signal;
    if (signal == null) return instance.pinNumbers;
    return {
      for (final option in instance.signals[signal] ?? const <PinOption>[])
        option.number,
    };
  }

  /// What to write beside a lit pin: the signal it would carry, so the
  /// drawing says `PA5 SCK` rather than leaving you to count rows.
  Map<String, String> _assignedLabels(Peripheral? instance) {
    if (instance == null) return const {};

    final labels = <String, String>{};
    for (final entry in instance.signals.entries) {
      if (_signal != null && entry.key != _signal) continue;
      for (final option in entry.value) {
        // A pin that can serve two signals of the same peripheral is rare
        // but real; both are worth seeing.
        labels[option.number] = labels.containsKey(option.number)
            ? '${labels[option.number]}/${entry.key}'
            : '${option.name} ${entry.key}';
      }
    }
    return labels;
  }

  Widget _peripherals(List<Peripheral> peripherals, Peripheral? instance) {
    if (peripherals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'This library lists no alternate pin functions, so there is '
          'nothing to choose between — the package beside is still drawn '
          'from the symbol, with every pin in its place.\n\n'
          "KiCad's STM32 symbols carry alternate functions; its ATmega, "
          'ESP32, RP2040 and nRF symbols do not.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: KicadPalette.textSecondary),
        ),
      );
    }

    final kinds = _kindsOf(peripherals);
    final kind = instance?.kind ?? _kind ?? kinds.firstOrNull;
    final instances = [
      for (final p in peripherals)
        if (p.kind == kind) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Filter — SPI, TIM, ADC',
              prefixIcon: Icon(Icons.search, size: 16),
            ),
            onChanged: (value) => setState(() => _filter = value.trim()),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final candidate in kinds)
                    if (_matchesFilter(candidate))
                      ChoiceChip(
                        label: Text(
                          '$candidate  '
                          '${peripherals.where((p) => p.kind == candidate).length}',
                        ),
                        selected: candidate == kind,
                        onSelected: (_) => setState(() {
                          _kind = candidate;
                          _instance = peripherals
                              .where((p) => p.kind == candidate)
                              .firstOrNull
                              ?.name;
                          _signal = null;
                        }),
                      ),
                ],
              ),
              if (instances.length > 1) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final candidate in instances)
                      ChoiceChip(
                        label: Text(candidate.name),
                        selected: candidate.name == instance?.name,
                        onSelected: (_) => setState(() {
                          _instance = candidate.name;
                          _signal = null;
                        }),
                      ),
                  ],
                ),
              ],
              if (instance != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: KicadPalette.border),
                const SizedBox(height: 6),
                _signalRow(
                  label: 'All of ${instance.name}',
                  count: instance.pinNumbers.length,
                  used: instance.pinNumbers
                      .where(widget.usedPins.contains)
                      .length,
                  selected: _signal == null,
                  onTap: () => setState(() {
                    _instance = instance.name;
                    _signal = null;
                  }),
                ),
                for (final entry in instance.signals.entries)
                  _signalRow(
                    label: entry.key,
                    count: entry.value.length,
                    used: entry.value
                        .where((o) => widget.usedPins.contains(o.number))
                        .length,
                    selected: _signal == entry.key,
                    onTap: () => setState(() {
                      _instance = instance.name;
                      _signal = entry.key;
                    }),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(String text) =>
      _filter.isEmpty || text.toLowerCase().contains(_filter.toLowerCase());

  Widget _signalRow({
    required String label,
    required int count,
    required int used,
    required bool selected,
    required VoidCallback onTap,
  }) {
    // Every pin that could carry this signal is already wired to something
    // else — the one thing worth shouting about, since it means the answer
    // to "can I still have it here" is no.
    final exhausted = used >= count && count > 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? KicadPalette.current.selectedContainer : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: exhausted
                      ? KicadPalette.warning
                      : selected
                      ? KicadPalette.highlight
                      : KicadPalette.textPrimary,
                ),
              ),
            ),
            Text(
              used > 0 ? '$used/$count used' : '$count pin${count == 1 ? "" : "s"}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: KicadPalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// The kinds anyone reaches for first, in this order; everything else
  /// follows alphabetically.
  static List<String> _kindsOf(List<Peripheral> peripherals) {
    const preferred = [
      'SPI',
      'I2C',
      'USART',
      'UART',
      'CAN',
      'USB',
      'I2S',
      'TIM',
      'ADC',
      'DAC',
    ];
    final present = {for (final p in peripherals) p.kind};
    return [
      for (final kind in preferred)
        if (present.contains(kind)) kind,
      ...(present.where((k) => !preferred.contains(k)).toList()..sort()),
    ];
  }

  /// What one pin can be, asked from the package rather than from the list.
  ///
  /// The other half of the question: not "where can SPI1 go" but "what else
  /// could this pin do". Tapping a function jumps the left panel to it, so
  /// the two directions meet.
  void _showPin(PackagePin pin) {
    setState(() => _selectedPin = pin.number);

    final functions = pin.pin.functionsByPeripheral;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pin ${pin.number}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    pin.pin.hasName ? pin.pin.name : '',
                    style: TextStyle(color: KicadPalette.pinName),
                  ),
                  const Spacer(),
                  if (widget.usedPins.contains(pin.number))
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        'already wired',
                        style: TextStyle(color: KicadPalette.warning),
                      ),
                    ),
                  Text(
                    pin.pin.electricalType.token,
                    style: TextStyle(color: KicadPalette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (functions.isEmpty)
                Text(
                  'No alternate functions listed for this pin.',
                  style: TextStyle(color: KicadPalette.textSecondary),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      320,
                      MediaQuery.sizeOf(context).height * 0.5,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in functions.entries)
                          for (final signal in entry.value)
                            ActionChip(
                              label: Text('${entry.key}_$signal'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  _kind = PinFunctions.kindOf(entry.key);
                                  _instance = entry.key;
                                  _signal = signal;
                                });
                              },
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
