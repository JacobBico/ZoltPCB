import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/symbols/symbols.dart';
import 'pin_type_style.dart';

/// The pin table for a symbol: number, name, electrical type and unit.
///
/// This is the view the whole app exists to make available away from a
/// workstation, so it shows everything a decision needs — including the
/// alternate functions a pin can be switched to, which is the difference
/// between "PA5" and "PA5 can be SPI1_SCK".
class PinoutView extends StatelessWidget {
  const PinoutView({
    super.key,
    required this.symbol,
    this.unitFilter,
    this.highlightPinNumbers = const {},
    this.onPinTap,
  });

  final SymbolDefinition symbol;

  /// Show only this unit (plus pins common to all units), or null for all.
  final int? unitFilter;

  final Set<String> highlightPinNumbers;
  final void Function(SymbolPin pin)? onPinTap;

  List<(SymbolPin, int)> get _rows {
    final rows = <(SymbolPin, int)>[];
    for (final drawing in symbol.unitDrawings) {
      if (drawing.bodyStyle > 1) continue;
      if (unitFilter != null &&
          drawing.unit != unitFilter &&
          !drawing.isCommonToAllUnits) {
        continue;
      }
      for (final pin in drawing.pins) {
        rows.add((pin, drawing.unit));
      }
    }
    rows.sort((a, b) {
      final byUnit = a.$2.compareTo(b.$2);
      if (byUnit != 0) return byUnit;
      final na = int.tryParse(a.$1.number);
      final nb = int.tryParse(b.$1.number);
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.$1.number.compareTo(b.$1.number);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This symbol has no pins.',
          style: TextStyle(color: KicadPalette.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PinHeaderRow(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final (pin, unit) = rows[index];
              return _PinRow(
                pin: pin,
                unit: unit,
                multiUnit: symbol.isMultiUnit,
                highlighted: highlightPinNumbers.contains(pin.number),
                onTap: onPinTap == null ? null : () => onPinTap!(pin),
              );
            },
          ),
        ),
      ],
    );
  }
}

abstract final class _PinColumns {
  static const number = 56.0;
  static const type = 74.0;
  static const unit = 44.0;
}

class _PinHeaderRow extends StatelessWidget {
  const _PinHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );
    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _PinColumns.number,
            child: Text('PIN', style: style),
          ),
          Expanded(child: Text('NAME', style: style)),
          SizedBox(
            width: _PinColumns.type,
            child: Text('TYPE', style: style),
          ),
          SizedBox(
            width: _PinColumns.unit,
            child: Text('UNIT', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.pin,
    required this.unit,
    required this.multiUnit,
    required this.highlighted,
    this.onTap,
  });

  final SymbolPin pin;
  final int unit;
  final bool multiUnit;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alternates = pin.alternates;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? KicadPalette.highlight.withValues(alpha: 0.10)
              : null,
          border: Border(bottom: BorderSide(color: KicadPalette.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _PinColumns.number,
              child: Text(
                pin.number,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: KicadPalette.pinNumber,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.hasName ? pin.name : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pin.hasName
                          ? KicadPalette.pinName
                          : KicadPalette.textDisabled,
                      decoration: pin.hidden
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (alternates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Text(
                        alternates.map((a) => a.name).join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: _PinColumns.type,
              child: Text(
                PinTypeStyle.label(pin.electricalType),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PinTypeStyle.color(pin.electricalType),
                ),
              ),
            ),
            SizedBox(
              width: _PinColumns.unit,
              child: Text(
                !multiUnit ? '—' : (unit == 0 ? 'all' : '$unit'),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: unit == 0
                      ? KicadPalette.warning
                      : KicadPalette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
