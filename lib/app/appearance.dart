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

/// How the schematic's wires are held and edited.
///
/// [segments] is KiCad's own model: a wire is one straight piece, and wires
/// are joined by sharing an end. Nothing has to work out whether two wires
/// are connected, so dragging one brings everything joined to it along.
///
/// [polyline] is the original: a wire is a chain of corners, and what it
/// touches is worked out as it moves. Kept as the fallback.
enum WiringModel {
  polyline(
    'Classic',
    'A wire is a chain of corners, and what it touches moves with it',
  ),
  segments(
    'Segments',
    'KiCad\'s own: each wire one straight piece, joined by shared ends — '
        'a different feel, worth a try if the classic one misbehaves',
  );

  const WiringModel(this.label, this.description);

  final String label;
  final String description;

  static WiringModel byName(String? name) =>
      values.where((m) => m.name == name).firstOrNull ?? polyline;
}

/// How a wire is drawn out of a pin on the schematic.
///
/// One or the other, never both: with both, a tap meant to look at a pin
/// started a wire, and the next stray tap on the sheet laid a corner of it.
enum WireGesture {
  drag(
    'Drag',
    'Drag out of a pin and let go on another pin or a wire. Let go on '
        'empty sheet for a corner, then drag on from the loose end',
  ),
  tap(
    'Tap',
    'Tap a pin, tap the sheet for each corner, then tap the pin or wire it '
        'ends on. Dragging a pin moves its part',
  );

  const WireGesture(this.label, this.description);

  final String label;
  final String description;

  static WireGesture byName(String? name) =>
      values.where((g) => g.name == name).firstOrNull ?? drag;
}

/// The look the user has chosen.
@immutable
class Appearance {
  const Appearance({
    this.palette = AppPalettes.hintpcb,
    this.resistorStyle = ResistorStyle.iec,
    this.boardEditor = BoardEditorStyle.precision,
    this.wiring = WiringModel.polyline,
    this.wireGesture = WireGesture.drag,
  });

  final AppPalette palette;
  final ResistorStyle resistorStyle;
  final BoardEditorStyle boardEditor;
  final WiringModel wiring;
  final WireGesture wireGesture;

  Appearance copyWith({
    AppPalette? palette,
    ResistorStyle? resistorStyle,
    BoardEditorStyle? boardEditor,
    WiringModel? wiring,
    WireGesture? wireGesture,
  }) => Appearance(
    palette: palette ?? this.palette,
    resistorStyle: resistorStyle ?? this.resistorStyle,
    boardEditor: boardEditor ?? this.boardEditor,
    wiring: wiring ?? this.wiring,
    wireGesture: wireGesture ?? this.wireGesture,
  );

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.palette == palette &&
      other.resistorStyle == resistorStyle &&
      other.boardEditor == boardEditor &&
      other.wiring == wiring &&
      other.wireGesture == wireGesture;

  @override
  int get hashCode =>
      Object.hash(palette, resistorStyle, boardEditor, wiring, wireGesture);
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
  classic('Classic', 'The original: drag and tap directly on the board');

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
        wiring: WiringModel.byName(settings[SettingsRepository.wiringKey]),
        wireGesture: WireGesture.byName(
          settings[SettingsRepository.wireGestureKey],
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

  Future<void> setWiring(WiringModel model) async {
    _apply(state.copyWith(wiring: model));
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.wiringKey, model.name);
  }

  Future<void> setWireGesture(WireGesture gesture) async {
    _apply(state.copyWith(wireGesture: gesture));
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.wireGestureKey, gesture.name);
  }

  void _apply(Appearance next) {
    // The palette is read directly in hundreds of places rather than
    // through the theme, so it has to be in force before anything rebuilds.
    KicadPalette.current = next.palette;
    state = next;
  }
}
