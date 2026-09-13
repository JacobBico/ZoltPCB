import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/pin.dart';

/// Colour and short label for a pin's electrical type.
///
/// The colours follow the meaning rather than KiCad's own ERC palette: what
/// matters on a phone is telling supply pins from signal pins at a glance.
abstract final class PinTypeStyle {
  static Color color(PinElectricalType type) => switch (type) {
    PinElectricalType.powerIn ||
    PinElectricalType.powerOut => KicadPalette.symbolOutline,
    PinElectricalType.input => KicadPalette.pinName,
    PinElectricalType.output => KicadPalette.wire,
    PinElectricalType.bidirectional ||
    PinElectricalType.triState => KicadPalette.sheet,
    PinElectricalType.noConnect => KicadPalette.textDisabled,
    _ => KicadPalette.textSecondary,
  };

  /// Compact label that fits a narrow column: `pwr_in`, `bidi`.
  static String label(PinElectricalType type) => switch (type) {
    PinElectricalType.input => 'in',
    PinElectricalType.output => 'out',
    PinElectricalType.bidirectional => 'bidi',
    PinElectricalType.triState => 'tri',
    PinElectricalType.passive => 'passive',
    PinElectricalType.free => 'free',
    PinElectricalType.unspecified => 'unspec',
    PinElectricalType.powerIn => 'pwr_in',
    PinElectricalType.powerOut => 'pwr_out',
    PinElectricalType.openCollector => 'open_c',
    PinElectricalType.openEmitter => 'open_e',
    PinElectricalType.noConnect => 'nc',
  };
}
