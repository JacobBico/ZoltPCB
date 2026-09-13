import 'symbol_definition.dart';
import 'symbol_pin.dart';

/// One pin that can carry a given signal.
class PinOption {
  const PinOption({required this.number, required this.name});

  /// Pad number, e.g. `"21"`.
  final String number;

  /// The pin's own name, e.g. `"PA5"`.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PinOption && other.number == number && other.name == name;

  @override
  int get hashCode => Object.hash(number, name);

  @override
  String toString() => '$name ($number)';
}

/// A peripheral instance — `SPI1`, `USART2`, `I2C1` — and, for each of its
/// signals, the pins that can carry it.
class Peripheral {
  const Peripheral({
    required this.name,
    required this.kind,
    required this.signals,
  });

  /// `SPI1`.
  final String name;

  /// `SPI` — the name with its instance number taken off, used to group
  /// SPI1, SPI2 and SPI3 together.
  final String kind;

  /// Signal name to the pins that can carry it, e.g. `SCK` → PA5, PB3.
  /// Ordered by signal name so the same peripheral always reads the same.
  final Map<String, List<PinOption>> signals;

  /// Every pin this peripheral could touch, for highlighting.
  Set<String> get pinNumbers => {
    for (final options in signals.values)
      for (final option in options) option.number,
  };

  @override
  String toString() => 'Peripheral($name, ${signals.keys.join(',')})';
}

/// Which pins of a microcontroller can do what.
///
/// The question a CubeMX-style tool answers — "which pins can be SPI2?" —
/// asked of data the user already has. KiCad's STM32 symbols list every
/// alternate function each pin supports (`SPI1_SCK`, `USART2_TX`,
/// `TIM3_CH1`), tens of thousands of them per library, and the parser keeps
/// them; this turns that per-pin list round into a per-peripheral one.
///
/// Only as good as the library. KiCad's ATmega, ESP32, RP2040 and nRF
/// symbols carry no alternates at all, and for those [of] returns nothing
/// rather than guessing from pin names.
abstract final class PinFunctions {
  /// The peripherals the symbol's pins can be switched to, grouped and
  /// sorted — by kind, then instance number.
  static List<Peripheral> of(SymbolDefinition symbol) {
    final byPeripheral = <String, Map<String, Set<PinOption>>>{};

    final seen = <String>{};
    for (final drawing in symbol.unitDrawings) {
      if (drawing.bodyStyle > 1) continue;
      for (final pin in drawing.pins) {
        // A pin stacked across units appears once per unit; count it once.
        if (!seen.add('${pin.number}/${pin.name}')) continue;
        for (final alternate in pin.alternates) {
          final split = splitFunction(alternate.name);
          if (split == null) continue;
          final signals = byPeripheral[split.peripheral] ??= {};
          (signals[split.signal] ??= {}).add(
            PinOption(number: pin.number, name: pin.name),
          );
        }
      }
    }

    final peripherals = [
      for (final entry in byPeripheral.entries)
        Peripheral(
          name: entry.key,
          kind: kindOf(entry.key),
          signals: {
            for (final signal in (entry.value.keys.toList()..sort(_natural)))
              signal: (entry.value[signal]!.toList()
                ..sort((a, b) => _natural(a.name, b.name))),
          },
        ),
    ];
    peripherals.sort((a, b) {
      final byKind = a.kind.compareTo(b.kind);
      return byKind != 0 ? byKind : _natural(a.name, b.name);
    });
    return peripherals;
  }

  /// Whether a symbol has anything to show.
  static bool hasAny(SymbolDefinition symbol) => symbol.unitDrawings.any(
    (drawing) => drawing.pins.any((pin) => pin.alternates.isNotEmpty),
  );

  /// `SPI1_SCK` → (`SPI1`, `SCK`).
  ///
  /// Split at the last underscore, not the first: `USB_OTG_FS_DP` has to
  /// group with the rest of `USB_OTG_FS`, and splitting early would file it
  /// under a peripheral called `USB` with a signal called `OTG_FS_DP`.
  static ({String peripheral, String signal})? splitFunction(String name) {
    final index = name.lastIndexOf('_');
    if (index <= 0 || index == name.length - 1) return null;
    return (
      peripheral: name.substring(0, index),
      signal: name.substring(index + 1),
    );
  }

  /// `SPI1` → `SPI`, `I2C3` → `I2C`, `USB_OTG_FS` → `USB_OTG_FS`.
  ///
  /// Only trailing digits come off. `I2C` and `I2S` have a digit in the
  /// middle of the name itself, and stripping every digit would file both
  /// under `IC` and `IS`.
  static String kindOf(String peripheral) =>
      peripheral.replaceFirst(RegExp(r'\d+$'), '');

  /// Orders `PA2` before `PA10` and `SPI2` before `SPI10`.
  static int _natural(String a, String b) {
    final pattern = RegExp(r'(\d+)|(\D+)');
    final partsA = pattern.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = pattern.allMatches(b).map((m) => m.group(0)!).toList();
    for (var i = 0; i < partsA.length && i < partsB.length; i++) {
      final na = int.tryParse(partsA[i]);
      final nb = int.tryParse(partsB[i]);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : partsA[i].compareTo(partsB[i]);
      if (c != 0) return c;
    }
    return partsA.length.compareTo(partsB.length);
  }
}

/// Convenience for pins, mirroring [PinFunctions.splitFunction].
extension PinAlternateFunctions on SymbolPin {
  /// This pin's alternate functions, grouped by peripheral.
  Map<String, List<String>> get functionsByPeripheral {
    final result = <String, List<String>>{};
    for (final alternate in alternates) {
      final split = PinFunctions.splitFunction(alternate.name);
      if (split == null) continue;
      (result[split.peripheral] ??= []).add(split.signal);
    }
    return result;
  }
}
