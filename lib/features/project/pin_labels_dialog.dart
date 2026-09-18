import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';

/// Labels many pins of one part at once — `D[0..7]` across a data bus, or
/// every pin by its own name.
///
/// Two chips labelled the same way are wired: a name is a connection. That
/// is how a bus is drawn here, without eight wires or eight trips to a
/// rename dialog. Returns the label for each chosen pin, in pin order.
Future<Map<String, String>?> showPinLabelsDialog(
  BuildContext context, {
  required PartWithDetails part,
  required Map<String, String> netNameByPin,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _PinLabelsDialog(part: part, netNameByPin: netNameByPin),
);

enum _Source { pattern, pinNames }

class _PinLabelsDialog extends StatefulWidget {
  const _PinLabelsDialog({required this.part, required this.netNameByPin});

  final PartWithDetails part;

  /// The name of the net each pin is on now, for the pins on a named one.
  final Map<String, String> netNameByPin;

  @override
  State<_PinLabelsDialog> createState() => _PinLabelsDialogState();
}

class _PinLabelsDialogState extends State<_PinLabelsDialog> {
  final _pattern = TextEditingController(text: 'D[0..7]');
  _Source _source = _Source.pattern;

  late final List<PartPin> _pins = [...widget.part.pins]
    ..sort((a, b) => _natural(a.number, b.number));

  /// Unwired pins to begin with — the ones a label is for. Power and
  /// no-connect pins are left out; they can be ticked by hand.
  late final Set<String> _chosen = {
    for (final pin in _pins)
      if (!widget.netNameByPin.containsKey(pin.id) &&
          !pin.noConnect &&
          pin.electricalType != PinElectricalType.noConnect &&
          pin.electricalType != PinElectricalType.powerIn &&
          pin.electricalType != PinElectricalType.powerOut)
        pin.id,
  };

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  static int _natural(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  static bool _named(PartPin pin) => pin.name.isNotEmpty && pin.name != '~';

  /// Label per chosen pin, in pin order.
  Map<String, String> get _assignment {
    final chosen = [
      for (final p in _pins)
        if (_chosen.contains(p.id)) p,
    ];
    if (_source == _Source.pinNames) {
      return {
        for (final pin in chosen)
          if (_named(pin)) pin.id: pin.name,
      };
    }
    final names = LabelPattern.expand(_pattern.text);
    return {
      for (var i = 0; i < chosen.length && i < names.length; i++)
        chosen[i].id: names[i],
    };
  }

  String? get _mismatch {
    if (_source == _Source.pinNames) return null;
    final names = LabelPattern.expand(_pattern.text).length;
    final pins = _chosen.length;
    if (names == pins || names == 0) return null;
    return names > pins
        ? '$names names for $pins pins — the last ${names - pins} are unused'
        : '$names names for $pins pins — ${pins - names} pins left unlabelled';
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _assignment;
    final mismatch = _mismatch;
    final secondary = TextStyle(
      fontSize: 12,
      color: KicadPalette.textSecondary,
    );

    return AlertDialog(
      title: Text('Label ${widget.part.part.reference} pins'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: 720,
        height: 300,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 250,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Pattern'),
                          selected: _source == _Source.pattern,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _source = _Source.pattern),
                        ),
                        ChoiceChip(
                          key: const ValueKey('pin-labels-names'),
                          label: const Text('Pin names'),
                          selected: _source == _Source.pinNames,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _source = _Source.pinNames),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_source == _Source.pattern) ...[
                      TextField(
                        key: const ValueKey('pin-labels-pattern'),
                        controller: _pattern,
                        decoration: const InputDecoration(
                          labelText: 'Names',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'D[0..7] counts, A[3..0] counts down, '
                        'SPI_{MOSI MISO SCK} shares a prefix, and commas '
                        'list. Given to the ticked pins in order.',
                        style: secondary,
                      ),
                    ] else
                      Text(
                        'Each ticked pin is labelled with its own name — '
                        'PA0, SDA, RESET — so another chip labelled the '
                        'same way is wired to it.',
                        style: secondary,
                      ),
                    if (mismatch != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          mismatch,
                          style: TextStyle(
                            fontSize: 12,
                            color: KicadPalette.warning,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(
                            () => _chosen.addAll(_pins.map((p) => p.id)),
                          ),
                          child: const Text('ALL'),
                        ),
                        TextButton(
                          onPressed: () => setState(_chosen.clear),
                          child: const Text('NONE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: KicadPalette.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView(
                  children: [
                    for (final pin in _pins)
                      CheckboxListTile(
                        key: ValueKey('pin-label-${pin.number}'),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _chosen.contains(pin.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _chosen.add(pin.id);
                          } else {
                            _chosen.remove(pin.id);
                          }
                        }),
                        title: Text(pin.label),
                        subtitle: widget.netNameByPin[pin.id] == null
                            ? null
                            : Text(
                                'On ${widget.netNameByPin[pin.id]}',
                                style: secondary,
                              ),
                        secondary: assignment[pin.id] == null
                            ? null
                            : Text(
                                assignment[pin.id]!,
                                style: TextStyle(
                                  color: KicadPalette.label,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          key: const ValueKey('pin-labels-apply'),
          onPressed: assignment.isEmpty
              ? null
              : () => Navigator.of(context).pop(assignment),
          child: Text('LABEL ${assignment.length}'),
        ),
      ],
    );
  }
}
