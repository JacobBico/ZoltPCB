import 'package:flutter/material.dart';
/// One complete set of app colours.
///
/// Everything that paints reads from the palette in force — the chrome, both
/// canvases, the status colours — so a theme is a whole look, not a tint on
/// the toolbar. The semantic roles stay distinct in every palette: a wire, a
/// symbol, a selection and an error must never be the same colour, or the
/// drawing stops saying which is which.
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.canvas,
    required this.grid,
    required this.gridMajor,
    required this.symbolOutline,
    required this.symbolFill,
    required this.pin,
    required this.pinName,
    required this.pinNumber,
    required this.wire,
    required this.bus,
    required this.junction,
    required this.label,
    required this.globalLabel,
    required this.fieldText,
    required this.noConnect,
    required this.notes,
    required this.sheet,
    required this.highlight,
    required this.boardCanvas,
    required this.boardGrid,
    required this.frontCopper,
    required this.backCopper,
    required this.padThroughHole,
    required this.drill,
    required this.silkscreen,
    required this.courtyard,
    required this.fabLine,
    required this.edgeCuts,
    required this.ratsnest,
    required this.warning,
    required this.error,
    required this.success,
  });

  /// Stable identifier, stored in settings.
  final String id;
  final String name;
  final String description;
  final Brightness brightness;

  // Chrome.
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  // Schematic canvas.
  final Color canvas;
  final Color grid;
  final Color gridMajor;
  // Symbols.
  final Color symbolOutline;
  final Color symbolFill;
  final Color pin;
  final Color pinName;
  final Color pinNumber;
  // Connectivity.
  final Color wire;
  final Color bus;
  final Color junction;
  final Color label;
  final Color globalLabel;
  final Color fieldText;
  final Color noConnect;
  final Color notes;
  final Color sheet;
  // Interaction.
  final Color highlight;
  // Board editor.
  final Color boardCanvas;
  final Color boardGrid;
  final Color frontCopper;
  final Color backCopper;
  final Color padThroughHole;
  final Color drill;
  final Color silkscreen;
  final Color courtyard;
  final Color fabLine;
  final Color edgeCuts;
  final Color ratsnest;
  // Status.
  final Color warning;
  final Color error;
  final Color success;

  bool get isDark => brightness == Brightness.dark;

  /// Text drawn on the accent colour.
  Color get onAccent => isDark ? const Color(0xFF08201E) : Colors.white;

  /// The background of anything selected — a chip, a segment. Derived from
  /// the accent so it always belongs to the palette, and never borrowed from
  /// the symbol colour, which in most palettes is the one that reads as
  /// "wrong".
  Color get selectedContainer => Color.lerp(surface, wire, isDark ? 0.24 : 0.18)!;

  @override
  bool operator ==(Object other) => other is AppPalette && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppPalette($id)';
}

/// The palettes the app ships.
abstract final class AppPalettes {
  static const kicad = AppPalette(
    id: 'kicad',
    name: 'KiCad',
    description: 'Dark canvas, red symbols, teal wires — the desktop editor, as close as a phone gets.',
    brightness: Brightness.dark,
    background: Color(0xFF131318),
    surface: Color(0xFF1C1C22),
    surfaceRaised: Color(0xFF24242C),
    border: Color(0xFF32323C),
    borderStrong: Color(0xFF454552),
    textPrimary: Color(0xFFD8D8DE),
    textSecondary: Color(0xFF8E8E9B),
    textDisabled: Color(0xFF5A5A66),
    canvas: Color(0xFF1A1A1A),
    grid: Color(0xFF2A2A2E),
    gridMajor: Color(0xFF34343A),
    symbolOutline: Color(0xFFC94A45),
    symbolFill: Color(0xFF241C1C),
    pin: Color(0xFFC94A45),
    pinName: Color(0xFF5C9BE6),
    pinNumber: Color(0xFFB05C58),
    wire: Color(0xFF35B5A8),
    bus: Color(0xFF5A5AD8),
    junction: Color(0xFF35B5A8),
    label: Color(0xFF35B5A8),
    globalLabel: Color(0xFFC94A45),
    fieldText: Color(0xFF35B5A8),
    noConnect: Color(0xFF5C9BE6),
    notes: Color(0xFF5C9BE6),
    sheet: Color(0xFF9A5AC4),
    highlight: Color(0xFFE8C15A),
    boardCanvas: Color(0xFF14161A),
    boardGrid: Color(0xFF232830),
    frontCopper: Color(0xFFC94A45),
    backCopper: Color(0xFF4C9A54),
    padThroughHole: Color(0xFFC8A24A),
    drill: Color(0xFF14161A),
    silkscreen: Color(0xFFAFAFC0),
    courtyard: Color(0xFF7A5AA8),
    fabLine: Color(0xFF5A6472),
    edgeCuts: Color(0xFFD8C87A),
    ratsnest: Color(0xFF7E8894),
    warning: Color(0xFFD8A657),
    error: Color(0xFFE05252),
    success: Color(0xFF6FBF73),
  );

  static const blueprint = AppPalette(
    id: 'blueprint',
    name: 'Blueprint',
    description: 'White lines on engineering blue.',
    brightness: Brightness.dark,
    background: Color(0xFF0B1E3A),
    surface: Color(0xFF10284A),
    surfaceRaised: Color(0xFF163358),
    border: Color(0xFF24477A),
    borderStrong: Color(0xFF35609A),
    textPrimary: Color(0xFFE6EEF8),
    textSecondary: Color(0xFF9DB3D0),
    textDisabled: Color(0xFF5F7898),
    canvas: Color(0xFF0E2A52),
    grid: Color(0xFF1A3D6E),
    gridMajor: Color(0xFF24518A),
    symbolOutline: Color(0xFFF2F6FF),
    symbolFill: Color(0xFF123460),
    pin: Color(0xFFF2F6FF),
    pinName: Color(0xFF9FD8FF),
    pinNumber: Color(0xFFB8C8E0),
    wire: Color(0xFF7FE3FF),
    bus: Color(0xFFB09CFF),
    junction: Color(0xFF7FE3FF),
    label: Color(0xFF7FE3FF),
    globalLabel: Color(0xFFFFD27F),
    fieldText: Color(0xFF9FD8FF),
    noConnect: Color(0xFFFF9F9F),
    notes: Color(0xFF9FD8FF),
    sheet: Color(0xFFD7A8FF),
    highlight: Color(0xFFFFD84D),
    boardCanvas: Color(0xFF0B1E3A),
    boardGrid: Color(0xFF163358),
    frontCopper: Color(0xFFFF8C7A),
    backCopper: Color(0xFF7FE3A0),
    padThroughHole: Color(0xFFFFD27F),
    drill: Color(0xFF0B1E3A),
    silkscreen: Color(0xFFF2F6FF),
    courtyard: Color(0xFFD7A8FF),
    fabLine: Color(0xFF6F8BB5),
    edgeCuts: Color(0xFFFFE680),
    ratsnest: Color(0xFFA8BCD8),
    warning: Color(0xFFFFC857),
    error: Color(0xFFFF6B6B),
    success: Color(0xFF7FE3A0),
  );

  static const paper = AppPalette(
    id: 'paper',
    name: 'Paper',
    description: 'KiCad\'s own light schematic: dark red on white.',
    brightness: Brightness.light,
    background: Color(0xFFF5F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEFEFEA),
    border: Color(0xFFD5D5CE),
    borderStrong: Color(0xFFB8B8B0),
    textPrimary: Color(0xFF1E1E24),
    textSecondary: Color(0xFF5E5E68),
    textDisabled: Color(0xFF9E9EA6),
    canvas: Color(0xFFFFFFF8),
    grid: Color(0xFFE8E8E0),
    gridMajor: Color(0xFFD8D8CE),
    symbolOutline: Color(0xFF840000),
    symbolFill: Color(0xFFFFFFC2),
    pin: Color(0xFF840000),
    pinName: Color(0xFF006464),
    pinNumber: Color(0xFFA90000),
    wire: Color(0xFF008400),
    bus: Color(0xFF000084),
    junction: Color(0xFF008400),
    label: Color(0xFF006400),
    globalLabel: Color(0xFF840000),
    fieldText: Color(0xFF006464),
    noConnect: Color(0xFF0000C2),
    notes: Color(0xFF0000C2),
    sheet: Color(0xFF840084),
    highlight: Color(0xFFB85500),
    boardCanvas: Color(0xFFF7F7F2),
    boardGrid: Color(0xFFE0E0D8),
    frontCopper: Color(0xFFC83434),
    backCopper: Color(0xFF2E8B3A),
    padThroughHole: Color(0xFFB08A20),
    drill: Color(0xFFF7F7F2),
    silkscreen: Color(0xFF303038),
    courtyard: Color(0xFF7A5AA8),
    fabLine: Color(0xFF8A8A92),
    edgeCuts: Color(0xFFB09A20),
    ratsnest: Color(0xFF6E6E78),
    warning: Color(0xFFC07000),
    error: Color(0xFFC62828),
    success: Color(0xFF2E7D32),
  );

  static const banana = AppPalette(
    id: 'banana',
    name: 'Banana',
    description: 'Ripe yellow, brown ink, leaf-green wires.',
    brightness: Brightness.light,
    background: Color(0xFFFFF4B8),
    surface: Color(0xFFFFEE99),
    surfaceRaised: Color(0xFFFFE680),
    border: Color(0xFFE0C85A),
    borderStrong: Color(0xFFC9AE3C),
    textPrimary: Color(0xFF3A2E00),
    textSecondary: Color(0xFF6E5B12),
    textDisabled: Color(0xFFA08C4A),
    canvas: Color(0xFFFFF8CC),
    grid: Color(0xFFF0E09A),
    gridMajor: Color(0xFFE5D07A),
    symbolOutline: Color(0xFF8A3B00),
    symbolFill: Color(0xFFFFF0B0),
    pin: Color(0xFF8A3B00),
    pinName: Color(0xFF1F5FAF),
    pinNumber: Color(0xFF8A5A2A),
    wire: Color(0xFF1E7A3A),
    bus: Color(0xFF3A3AAF),
    junction: Color(0xFF1E7A3A),
    label: Color(0xFF1E7A3A),
    globalLabel: Color(0xFFB0301F),
    fieldText: Color(0xFF1E7A3A),
    noConnect: Color(0xFF1F5FAF),
    notes: Color(0xFF1F5FAF),
    sheet: Color(0xFF7A3AAF),
    highlight: Color(0xFFB5179E),
    boardCanvas: Color(0xFFFFF4B8),
    boardGrid: Color(0xFFF0E09A),
    frontCopper: Color(0xFFC0392B),
    backCopper: Color(0xFF1E7A3A),
    padThroughHole: Color(0xFFB07A00),
    drill: Color(0xFFFFF4B8),
    silkscreen: Color(0xFF3A2E00),
    courtyard: Color(0xFF7A3AAF),
    fabLine: Color(0xFF9A8A5A),
    edgeCuts: Color(0xFF6E5B12),
    ratsnest: Color(0xFF6E5B12),
    warning: Color(0xFFC06A00),
    error: Color(0xFFC0392B),
    success: Color(0xFF1E7A3A),
  );

  static const halloween = AppPalette(
    id: 'halloween',
    name: 'Halloween',
    description: 'Pumpkin parts, slime wires, purple night.',
    brightness: Brightness.dark,
    background: Color(0xFF120A16),
    surface: Color(0xFF1C1022),
    surfaceRaised: Color(0xFF26162E),
    border: Color(0xFF3A2244),
    borderStrong: Color(0xFF52305F),
    textPrimary: Color(0xFFF3E6D8),
    textSecondary: Color(0xFFB59AA8),
    textDisabled: Color(0xFF6E5A6A),
    canvas: Color(0xFF140C18),
    grid: Color(0xFF24162A),
    gridMajor: Color(0xFF301C38),
    symbolOutline: Color(0xFFFF8A1F),
    symbolFill: Color(0xFF2A1408),
    pin: Color(0xFFFF8A1F),
    pinName: Color(0xFFB77DFF),
    pinNumber: Color(0xFFD9772E),
    wire: Color(0xFF9CFF57),
    bus: Color(0xFFB77DFF),
    junction: Color(0xFF9CFF57),
    label: Color(0xFF9CFF57),
    globalLabel: Color(0xFFFF8A1F),
    fieldText: Color(0xFF9CFF57),
    noConnect: Color(0xFFB77DFF),
    notes: Color(0xFFB77DFF),
    sheet: Color(0xFFB77DFF),
    highlight: Color(0xFFFFE14D),
    boardCanvas: Color(0xFF120A16),
    boardGrid: Color(0xFF24162A),
    frontCopper: Color(0xFFFF8A1F),
    backCopper: Color(0xFFB77DFF),
    padThroughHole: Color(0xFFFFC94D),
    drill: Color(0xFF120A16),
    silkscreen: Color(0xFFF3E6D8),
    courtyard: Color(0xFFB77DFF),
    fabLine: Color(0xFF6E5A6A),
    edgeCuts: Color(0xFF9CFF57),
    ratsnest: Color(0xFFB59AA8),
    warning: Color(0xFFFFC94D),
    error: Color(0xFFFF4D6A),
    success: Color(0xFF9CFF57),
  );

  static const christmas = AppPalette(
    id: 'christmas',
    name: 'Christmas',
    description: 'Holly green, berry red, gold, and snow.',
    brightness: Brightness.dark,
    background: Color(0xFF0B2016),
    surface: Color(0xFF10291D),
    surfaceRaised: Color(0xFF163526),
    border: Color(0xFF214A36),
    borderStrong: Color(0xFF2F6049),
    textPrimary: Color(0xFFF4F1E8),
    textSecondary: Color(0xFFB9CFC2),
    textDisabled: Color(0xFF6E8C7C),
    canvas: Color(0xFF0D2419),
    grid: Color(0xFF173A2A),
    gridMajor: Color(0xFF1F4A36),
    symbolOutline: Color(0xFFE8323F),
    symbolFill: Color(0xFF2A0F12),
    pin: Color(0xFFE8323F),
    pinName: Color(0xFFF4F1E8),
    pinNumber: Color(0xFFE77A80),
    wire: Color(0xFFFFD166),
    bus: Color(0xFFF4F1E8),
    junction: Color(0xFFFFD166),
    label: Color(0xFFFFD166),
    globalLabel: Color(0xFFE8323F),
    fieldText: Color(0xFFFFD166),
    noConnect: Color(0xFFF4F1E8),
    notes: Color(0xFFF4F1E8),
    sheet: Color(0xFFE77A80),
    highlight: Color(0xFF7FDBFF),
    boardCanvas: Color(0xFF0B2016),
    boardGrid: Color(0xFF163526),
    frontCopper: Color(0xFFE8323F),
    backCopper: Color(0xFF9FE870),
    padThroughHole: Color(0xFFFFD166),
    drill: Color(0xFF0B2016),
    silkscreen: Color(0xFFF4F1E8),
    courtyard: Color(0xFFE77A80),
    fabLine: Color(0xFF6E8C7C),
    edgeCuts: Color(0xFFF4F1E8),
    ratsnest: Color(0xFFB9CFC2),
    warning: Color(0xFFFFB347),
    error: Color(0xFFFF5A5F),
    success: Color(0xFF7FE0A0),
  );

  /// In the order the settings screen offers them.
  static const all = [kicad, blueprint, paper, banana, halloween, christmas];

  /// The palette with [id], or the default when it is unknown — a setting
  /// written by a newer version of the app must not stop this one opening.
  static AppPalette byId(String? id) =>
      all.where((p) => p.id == id).firstOrNull ?? kicad;
}
