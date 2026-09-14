import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/mcu_essentials.dart';
import '../../domain/symbols/symbols.dart';
import 'starter_circuit.dart';

/// Shows what was found on a microcontroller and asks what to add round it.
Future<StarterOptions?> showStarterCircuitDialog(
  BuildContext context, {
  required String mcuName,
  required McuEssentials essentials,
  required List<SymbolIndexEntry> supplies,
  required String crystalValue,
}) => showDialog<StarterOptions>(
  context: context,
  builder: (context) => _StarterCircuitDialog(
    mcuName: mcuName,
    essentials: essentials,
    supplies: supplies,
    crystalValue: crystalValue,
  ),
);

class _StarterCircuitDialog extends StatefulWidget {
  const _StarterCircuitDialog({
    required this.mcuName,
    required this.essentials,
    required this.supplies,
    required this.crystalValue,
  });

  final String mcuName;
  final McuEssentials essentials;
  final List<SymbolIndexEntry> supplies;
  final String crystalValue;

  @override
  State<_StarterCircuitDialog> createState() => _StarterCircuitDialogState();
}

class _StarterCircuitDialogState extends State<_StarterCircuitDialog> {
  late bool _decoupling =
      widget.essentials.decoupledPins.isNotEmpty ||
      widget.essentials.groundPins.isNotEmpty;
  late bool _crystal = widget.essentials.hasCrystal;
  late bool _reset = widget.essentials.reset != null;
  late bool _boot = widget.essentials.boot != null;
  late final _crystalValue = TextEditingController(text: widget.crystalValue);
  late SymbolIndexEntry? _supply = _defaultSupply();

  SymbolIndexEntry? _defaultSupply() {
    final supplies = widget.supplies;
    return supplies.where((e) => e.name == '+3V3').firstOrNull ??
        supplies.where((e) => e.name == '+3.3V').firstOrNull ??
        supplies.where((e) => e.name == 'VCC').firstOrNull ??
        supplies.firstOrNull;
  }

  @override
  void dispose() {
    _crystalValue.dispose();
    super.dispose();
  }

  String _pins(Iterable<String> numbers) {
    final names = [for (final n in numbers) widget.essentials.names[n] ?? n];
    if (names.isEmpty) return 'none found';
    // VDD ×3 reads better than VDD, VDD, VDD.
    final counts = <String, int>{};
    for (final name in names) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return [
      for (final entry in counts.entries)
        entry.value > 1 ? '${entry.key} ×${entry.value}' : entry.key,
    ].join(', ');
  }

  String _pin(String? number) =>
      number == null ? '' : (widget.essentials.names[number] ?? number);

  @override
  Widget build(BuildContext context) {
    final e = widget.essentials;
    final theme = Theme.of(context);
    final noted = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );

    return AlertDialog(
      title: Text('${widget.mcuName} starter circuit'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (e.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No supply, oscillator, reset or boot pins were '
                    'recognised by name. The chip will be added on its own.',
                    style: noted,
                  ),
                ),
              CheckboxListTile(
                value: _decoupling,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _decoupling = v ?? false),
                title: const Text('Power pins and decoupling'),
                subtitle: Text(
                  '100nF on ${_pins(e.decoupledPins)}'
                  '${e.vcapPins.isEmpty ? '' : ' · 2.2uF on ${_pins(e.vcapPins)}'}'
                  ' · 10uF bulk · ground: ${_pins(e.groundPins)}'
                  '${e.corePins.isEmpty ? '' : ' · ${_pins(e.corePins)} decoupled only, not tied to the rail'}',
                ),
              ),
              CheckboxListTile(
                value: _crystal,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: e.hasCrystal
                    ? (v) => setState(() => _crystal = v ?? false)
                    : null,
                title: const Text('Crystal with load capacitors'),
                subtitle: Text(
                  e.hasCrystal
                      ? '${_pin(e.oscIn)} / ${_pin(e.oscOut)} · 20pF each'
                      : 'No oscillator pins found',
                ),
              ),
              if (e.hasCrystal && _crystal)
                Padding(
                  padding: const EdgeInsets.only(left: 56, bottom: 6),
                  child: SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _crystalValue,
                      decoration: const InputDecoration(
                        labelText: 'Crystal',
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              CheckboxListTile(
                value: _reset,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: e.reset != null
                    ? (v) => setState(() => _reset = v ?? false)
                    : null,
                title: const Text('Reset button'),
                subtitle: Text(
                  e.reset != null
                      ? '${_pin(e.reset)} · 10k pull-up and 100nF'
                      : 'No reset pin found',
                ),
              ),
              CheckboxListTile(
                value: _boot,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: e.boot != null
                    ? (v) => setState(() => _boot = v ?? false)
                    : null,
                title: const Text('Boot button'),
                subtitle: Text(switch (e.boot) {
                  null => 'No boot pin found',
                  _ when e.bootPolarity == BootPolarity.activeHigh =>
                    '${_pin(e.boot)} · to the rail, 10k pull-down',
                  _ =>
                    '${_pin(e.boot)} · to ground'
                        '${e.bootNeedsPullUp ? ', 10k pull-up' : ''}',
                }),
              ),
              const SizedBox(height: 8),
              if (widget.supplies.isEmpty)
                Text(
                  'No power symbols — import KiCad\'s power library for the '
                  'supply and ground.',
                  style: noted?.copyWith(color: KicadPalette.error),
                )
              else
                DropdownButtonFormField<SymbolIndexEntry>(
                  initialValue: _supply,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Supply rail',
                    isDense: true,
                  ),
                  items: [
                    for (final entry in widget.supplies)
                      DropdownMenuItem(value: entry, child: Text(entry.name)),
                  ],
                  onChanged: (entry) => setState(() => _supply = entry),
                ),
              const SizedBox(height: 8),
              Text(
                'Capacitors, resistors, crystal and buttons come from your '
                'own Device and Switch libraries.',
                style: noted,
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
          onPressed: _supply == null
              ? null
              : () => Navigator.of(context).pop(
                  StarterOptions(
                    supplyLibId: _supply!.libId,
                    decoupling: _decoupling,
                    crystal: _crystal,
                    reset: _reset,
                    boot: _boot,
                    crystalValue: _crystalValue.text.trim().isEmpty
                        ? widget.crystalValue
                        : _crystalValue.text.trim(),
                  ),
                ),
          child: const Text('ADD'),
        ),
      ],
    );
  }
}
