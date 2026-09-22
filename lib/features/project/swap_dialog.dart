import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/pin_swap.dart';
import '../../domain/models/models.dart';

/// What the user chose to swap.
sealed class SwapChoice {
  const SwapChoice();
}

class PinSwapChoice extends SwapChoice {
  const PinSwapChoice(this.a, this.b);

  final PartPin a;
  final PartPin b;
}

class GateSwapChoice extends SwapChoice {
  const GateSwapChoice(this.a, this.b);

  final int a;
  final int b;
}

/// Chooses two pins, or two gates, of [part] to swap.
Future<SwapChoice?> showSwapDialog(
  BuildContext context, {
  required PartWithDetails part,
  required List<NetWithEndpoints> nets,
}) => showDialog<SwapChoice>(
  context: context,
  builder: (_) => _SwapDialog(part: part, nets: nets),
);

class _SwapDialog extends StatefulWidget {
  const _SwapDialog({required this.part, required this.nets});

  final PartWithDetails part;
  final List<NetWithEndpoints> nets;

  @override
  State<_SwapDialog> createState() => _SwapDialogState();
}

enum _Kind { pins, gates }

class _SwapDialogState extends State<_SwapDialog> {
  late final bool _gatesPossible = PinSwapper.hasSwappableGates(widget.part);
  late _Kind _kind = _gatesPossible ? _Kind.gates : _Kind.pins;

  /// Every pin the symbol shows, in number order.
  late final List<PartPin> _pins = [
    for (final pin in widget.part.pins)
      if (!pin.hidden) pin,
  ]..sort((a, b) => _natural(a.number, b.number));

  PartPin? _pinA;
  PartPin? _pinB;
  int? _gateA;
  int? _gateB;

  @override
  void initState() {
    super.initState();
    final gates = [for (final u in widget.part.units) u.unitNumber]..sort();
    if (_gatesPossible) {
      _gateA = gates.firstWhere(
        (g) => PinSwapper.swappableWith(widget.part, g).isNotEmpty,
      );
      _gateB = PinSwapper.swappableWith(widget.part, _gateA!).first;
    }
  }

  static int _natural(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  String _netOf(PartPin pin) {
    for (final net in widget.nets) {
      if (net.endpoints.any((e) => e.pin.id == pin.id)) return net.displayName;
    }
    return 'not connected';
  }

  String _gateName(int unit) =>
      '${widget.part.part.reference}'
      '${String.fromCharCode(64 + unit)}';

  SwapChoice? get _choice => switch (_kind) {
    _Kind.pins when _pinA != null && _pinB != null && _pinA != _pinB =>
      PinSwapChoice(_pinA!, _pinB!),
    _Kind.gates when _gateA != null && _gateB != null && _gateA != _gateB =>
      GateSwapChoice(_gateA!, _gateB!),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: KicadPalette.textSecondary,
    );
    final choice = _choice;
    return AlertDialog(
      title: Text('Swap on ${widget.part.part.reference}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_gatesPossible) ...[
                SegmentedButton<_Kind>(
                  key: const ValueKey('swap-kind'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Kind.gates, label: Text('Gates')),
                    ButtonSegment(value: _Kind.pins, label: Text('Pins')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (v) => setState(() => _kind = v.first),
                ),
                const SizedBox(height: 12),
              ],
              if (_kind == _Kind.gates) ...[
                Row(
                  children: [
                    Expanded(
                      child: _gateMenu(
                        'gate-a',
                        _gateA,
                        [for (final u in widget.part.units) u.unitNumber],
                        (v) => setState(() {
                          _gateA = v;
                          final options = PinSwapper.swappableWith(
                            widget.part,
                            v!,
                          );
                          if (!options.contains(_gateB)) {
                            _gateB = options.firstOrNull;
                          }
                        }),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.swap_horiz),
                    ),
                    Expanded(
                      child: _gateMenu(
                        'gate-b',
                        _gateB,
                        _gateA == null
                            ? const []
                            : PinSwapper.swappableWith(widget.part, _gateA!),
                        (v) => setState(() => _gateB = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The two gates trade places on the sheet and on the board '
                  'pads, so the drawing stays as it is and the copper '
                  'untangles.',
                  style: caption,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _pinMenu(
                        'pin-a',
                        _pinA,
                        (v) => setState(() => _pinA = v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.swap_horiz),
                    ),
                    Expanded(
                      child: _pinMenu(
                        'pin-b',
                        _pinB,
                        (v) => setState(() => _pinB = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Only for pins that do the same job — two GPIOs, the two '
                  'ends of a resistor. Each pin takes the other\'s net, shown '
                  'as a label on the sheet.',
                  style: caption,
                ),
              ],
              const SizedBox(height: 8),
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
          key: const ValueKey('swap-ok'),
          onPressed: choice == null
              ? null
              : () => Navigator.of(context).pop(choice),
          child: const Text('SWAP'),
        ),
      ],
    );
  }

  Widget _gateMenu(
    String key,
    int? value,
    List<int> options,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    key: ValueKey(key),
    initialValue: options.contains(value) ? value : null,
    isExpanded: true,
    dropdownColor: KicadPalette.surfaceRaised,
    decoration: const InputDecoration(isDense: true),
    items: [
      for (final unit in options..sort())
        DropdownMenuItem(value: unit, child: Text(_gateName(unit))),
    ],
    onChanged: onChanged,
  );

  Widget _pinMenu(
    String key,
    PartPin? value,
    ValueChanged<PartPin?> onChanged,
  ) => DropdownButtonFormField<PartPin>(
    key: ValueKey(key),
    initialValue: value,
    isExpanded: true,
    dropdownColor: KicadPalette.surfaceRaised,
    decoration: const InputDecoration(isDense: true, hintText: 'Pin'),
    items: [
      for (final pin in _pins)
        DropdownMenuItem(
          value: pin,
          child: Text(
            '${pin.label} · ${_netOf(pin)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

/// Asks what to swap on [partId], does it, and records it for undo. Shared
/// by the schematic and the board, which both offer it on a selected part.
Future<void> runPartSwap(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String partId,
  required void Function(
    String label, {
    required Future<void> Function() undo,
    required Future<void> Function() redo,
  })
  record,
  required void Function(String message) notify,
}) async {
  final parts = ref.read(projectPartsProvider(projectId)).value;
  final nets = ref.read(projectNetsProvider(projectId)).value;
  final part = parts?.where((p) => p.part.id == partId).firstOrNull;
  if (part == null || nets == null) return;
  final choice = await showSwapDialog(context, part: part, nets: nets);
  if (choice == null || !context.mounted) return;

  final swapper = ref.read(pinSwapperProvider);
  Future<SwapUndo> apply() async {
    // Read afresh: undo and redo run against whatever is there by then.
    final current = (await ref
        .read(partRepositoryProvider)
        .getPartWithDetails(partId))!;
    return switch (choice) {
      PinSwapChoice(:final a, :final b) => swapper.swapPins(
        projectId,
        current,
        a,
        b,
      ),
      GateSwapChoice(:final a, :final b) => swapper.swapGates(
        projectId,
        current,
        a,
        b,
      ),
    };
  }

  var undo = await apply();
  final label = switch (choice) {
    PinSwapChoice(:final a, :final b) =>
      'Swap ${part.part.reference} pins ${a.number} and ${b.number}',
    GateSwapChoice(:final a, :final b) =>
      'Swap ${part.part.reference} gates '
          '${String.fromCharCode(64 + a)} and ${String.fromCharCode(64 + b)}',
  };
  record(
    label,
    undo: () => swapper.undo(undo),
    redo: () async => undo = await apply(),
  );
  notify(label);
}
