import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/kicad_palette.dart';
import '../data/repositories/settings_repository.dart';
import 'providers.dart';

/// How resistors are drawn on the schematic.
///
/// Display only. The exported file carries KiCad's own symbol, drawn however
/// the desktop is set up to draw it — this is about which one reads as a
/// resistor to the person holding the phone.
enum ResistorStyle {
  /// The IEC box, which is what KiCad's stock library draws.
  iec('IEC', 'A rectangle — Europe, and KiCad\'s own library'),

  /// The ANSI zigzag.
  ansi('US', 'The zigzag — North America, and most textbooks');

  const ResistorStyle(this.label, this.description);

  final String label;
  final String description;

  static ResistorStyle byName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? iec;
}

/// The look the user has chosen.
@immutable
class Appearance {
  const Appearance({
    this.palette = AppPalettes.kicad,
    this.resistorStyle = ResistorStyle.iec,
    this.boardEditor = BoardEditorStyle.precision,
  });

  final AppPalette palette;
  final ResistorStyle resistorStyle;
  final BoardEditorStyle boardEditor;

  Appearance copyWith({
    AppPalette? palette,
    ResistorStyle? resistorStyle,
    BoardEditorStyle? boardEditor,
  }) => Appearance(
    palette: palette ?? this.palette,
    resistorStyle: resistorStyle ?? this.resistorStyle,
    boardEditor: boardEditor ?? this.boardEditor,
  );

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.palette == palette &&
      other.resistorStyle == resistorStyle &&
      other.boardEditor == boardEditor;

  @override
  int get hashCode => Object.hash(palette, resistorStyle, boardEditor);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Which board editor the PCB section uses.
///
/// [precision] is the one this section is built around: the crosshair
/// stays still and the board moves under it, so a point is never placed
/// under the finger placing it. Three earlier attempts rearranged the
/// controls above a canvas you poked directly and all three felt wrong for
/// the same reason, which was never the controls.
///
/// [classic] is that original poke-the-board editor, kept because it is
/// quicker for rough work where a millimetre either way does not matter.
enum BoardEditorStyle {
  precision(
    'Precision',
    'A crosshair you aim by moving the board — every point placed exactly, '
        'never under your finger',
  ),
  classic(
    'Classic',
    'The original: drag and tap directly on the board',
  );

  const BoardEditorStyle(this.label, this.description);

  final String label;
  final String description;

  static BoardEditorStyle byName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? precision;
}

/// The chosen look, loaded from settings and saved on change.
final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => Appearance(palette: KicadPalette.current);

  /// Reads the saved look. Called before the first frame so the app never
  /// flashes the default theme on the way to the chosen one.
  Future<void> load() async {
    final settings = await ref.read(settingsRepositoryProvider).getAll();
    _apply(
      Appearance(
        palette: AppPalettes.byId(settings[SettingsRepository.paletteKey]),
        resistorStyle: ResistorStyle.byName(
          settings[SettingsRepository.resistorStyleKey],
        ),
        boardEditor: BoardEditorStyle.byName(
          settings[SettingsRepository.boardEditorKey],
        ),
      ),
    );
  }

  Future<void> setPalette(AppPalette palette) async {
    _apply(state.copyWith(palette: palette));
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.paletteKey, palette.id);
  }

  Future<void> setResistorStyle(ResistorStyle style) async {
    _apply(state.copyWith(resistorStyle: style));
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.resistorStyleKey, style.name);
  }

  Future<void> setBoardEditor(BoardEditorStyle style) async {
    _apply(state.copyWith(boardEditor: style));
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.boardEditorKey, style.name);
  }

  void _apply(Appearance next) {
    // The palette is read directly in hundreds of places rather than
    // through the theme, so it has to be in force before anything rebuilds.
    KicadPalette.current = next.palette;
    state = next;
  }
}
