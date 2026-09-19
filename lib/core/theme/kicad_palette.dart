import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// The colours in force.
///
/// Kept under its original name so the three hundred places that paint with
/// it did not all have to change: each entry now reads from [current]
/// rather than being a fixed constant. Changing [current] and rebuilding is
/// how a theme is applied.
abstract final class KicadPalette {
  /// The palette everything is painted with right now.
  static AppPalette current = AppPalettes.hintpcb;

  // Chrome.
  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get surfaceRaised => current.surfaceRaised;
  static Color get border => current.border;
  static Color get borderStrong => current.borderStrong;
  // Text.
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textDisabled => current.textDisabled;
  // Schematic canvas.
  static Color get canvas => current.canvas;
  static Color get grid => current.grid;
  static Color get gridMajor => current.gridMajor;
  // Symbols.
  static Color get symbolOutline => current.symbolOutline;
  static Color get symbolFill => current.symbolFill;
  static Color get pin => current.pin;
  static Color get pinName => current.pinName;
  static Color get pinNumber => current.pinNumber;
  // Connectivity.
  static Color get wire => current.wire;
  static Color get bus => current.bus;
  static Color get junction => current.junction;
  static Color get label => current.label;
  static Color get globalLabel => current.globalLabel;
  static Color get fieldText => current.fieldText;
  static Color get noConnect => current.noConnect;
  static Color get notes => current.notes;
  static Color get sheet => current.sheet;
  // Interaction.
  static Color get highlight => current.highlight;
  // Board editor.
  static Color get boardCanvas => current.boardCanvas;
  static Color get boardGrid => current.boardGrid;
  static Color get frontCopper => current.frontCopper;
  static Color get backCopper => current.backCopper;

  /// Inner copper, In1 to In6. KiCad's own defaults, the same in every
  /// palette: an inner layer is never the one a theme is chosen for, and
  /// keeping them fixed keeps them told apart.
  static const innerCopper = [
    Color(0xFFC2C200),
    Color(0xFFCE7D2C),
    Color(0xFF4FCBCB),
    Color(0xFFDB628B),
    Color(0xFFA7A5C6),
    Color(0xFF28CCD9),
  ];
  static Color get padThroughHole => current.padThroughHole;
  static Color get drill => current.drill;
  static Color get silkscreen => current.silkscreen;
  static Color get courtyard => current.courtyard;
  static Color get fabLine => current.fabLine;
  static Color get edgeCuts => current.edgeCuts;
  static Color get ratsnest => current.ratsnest;
  // Status.
  static Color get warning => current.warning;
  static Color get error => current.error;
  static Color get success => current.success;
}

/// Canvas and schematic-element colours, exposed through the theme so the
/// renderer never reaches for constants directly.
@immutable
class SchematicColors extends ThemeExtension<SchematicColors> {
  const SchematicColors({
    required this.canvas,
    required this.grid,
    required this.gridMajor,
    required this.symbolOutline,
    required this.symbolFill,
    required this.pin,
    required this.pinName,
    required this.pinNumber,
    required this.wire,
    required this.junction,
    required this.label,
    required this.fieldText,
    required this.noConnect,
    required this.highlight,
  });

  /// The schematic colours of [palette].
  factory SchematicColors.of(AppPalette palette) => SchematicColors(
    canvas: palette.canvas,
    grid: palette.grid,
    gridMajor: palette.gridMajor,
    symbolOutline: palette.symbolOutline,
    symbolFill: palette.symbolFill,
    pin: palette.pin,
    pinName: palette.pinName,
    pinNumber: palette.pinNumber,
    wire: palette.wire,
    junction: palette.junction,
    label: palette.label,
    fieldText: palette.fieldText,
    noConnect: palette.noConnect,
    highlight: palette.highlight,
  );

  /// The schematic colours of the palette in force.
  static SchematicColors get dark => SchematicColors.of(KicadPalette.current);

  final Color canvas;
  final Color grid;
  final Color gridMajor;
  final Color symbolOutline;
  final Color symbolFill;
  final Color pin;
  final Color pinName;
  final Color pinNumber;
  final Color wire;
  final Color junction;
  final Color label;
  final Color fieldText;
  final Color noConnect;
  final Color highlight;

  @override
  SchematicColors copyWith({
    Color? canvas,
    Color? grid,
    Color? gridMajor,
    Color? symbolOutline,
    Color? symbolFill,
    Color? pin,
    Color? pinName,
    Color? pinNumber,
    Color? wire,
    Color? junction,
    Color? label,
    Color? fieldText,
    Color? noConnect,
    Color? highlight,
  }) {
    return SchematicColors(
      canvas: canvas ?? this.canvas,
      grid: grid ?? this.grid,
      gridMajor: gridMajor ?? this.gridMajor,
      symbolOutline: symbolOutline ?? this.symbolOutline,
      symbolFill: symbolFill ?? this.symbolFill,
      pin: pin ?? this.pin,
      pinName: pinName ?? this.pinName,
      pinNumber: pinNumber ?? this.pinNumber,
      wire: wire ?? this.wire,
      junction: junction ?? this.junction,
      label: label ?? this.label,
      fieldText: fieldText ?? this.fieldText,
      noConnect: noConnect ?? this.noConnect,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  SchematicColors lerp(ThemeExtension<SchematicColors>? other, double t) {
    if (other is! SchematicColors) return this;
    return SchematicColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      gridMajor: Color.lerp(gridMajor, other.gridMajor, t)!,
      symbolOutline: Color.lerp(symbolOutline, other.symbolOutline, t)!,
      symbolFill: Color.lerp(symbolFill, other.symbolFill, t)!,
      pin: Color.lerp(pin, other.pin, t)!,
      pinName: Color.lerp(pinName, other.pinName, t)!,
      pinNumber: Color.lerp(pinNumber, other.pinNumber, t)!,
      wire: Color.lerp(wire, other.wire, t)!,
      junction: Color.lerp(junction, other.junction, t)!,
      label: Color.lerp(label, other.label, t)!,
      fieldText: Color.lerp(fieldText, other.fieldText, t)!,
      noConnect: Color.lerp(noConnect, other.noConnect, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}

extension SchematicColorsAccess on ThemeData {
  SchematicColors get schematic =>
      extension<SchematicColors>() ?? SchematicColors.dark;
}
