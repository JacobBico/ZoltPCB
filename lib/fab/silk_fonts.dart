import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'truetype.dart';

/// A font offered for silkscreen text.
class SilkFontInfo {
  const SilkFontInfo(this.id, this.name, {this.asset});

  /// What a text stores to name it: empty for the stroke font, a bundled
  /// font's own id, or `user:<id>` for one the user added.
  final String id;
  final String name;

  /// Where a bundled font's file is, under `assets/fonts`.
  final String? asset;

  bool get isStroke => id.isEmpty;
}

/// The fonts silkscreen text can be drawn in.
///
/// Held here, once, rather than threaded through every scene: the painter,
/// the Gerber writer and the rule check all ask for a font by the id a text
/// carries, and a font that has not loaded — or was deleted — falls back to
/// the plain stroke font rather than failing.
abstract final class SilkFonts {
  /// KiCad's own plain stroke font, the one text had before fonts.
  static const stroke = SilkFontInfo('', 'Stroke (KiCad)');

  /// Bundled with the app, all under the SIL Open Font License; the
  /// licences are in `assets/fonts/LICENSES.txt`.
  static const bundled = [
    SilkFontInfo('fira-sans', 'Fira Sans Bold', asset: 'FiraSans-Bold.ttf'),
    SilkFontInfo('lato', 'Lato Bold', asset: 'Lato-Bold.ttf'),
    SilkFontInfo('poppins', 'Poppins Bold', asset: 'Poppins-Bold.ttf'),
    SilkFontInfo(
      'ibm-plex-mono',
      'IBM Plex Mono Bold',
      asset: 'IBMPlexMono-Bold.ttf',
    ),
    SilkFontInfo('space-mono', 'Space Mono Bold', asset: 'SpaceMono-Bold.ttf'),
    SilkFontInfo(
      'chakra-petch',
      'Chakra Petch Bold',
      asset: 'ChakraPetch-Bold.ttf',
    ),
    SilkFontInfo('rajdhani', 'Rajdhani Bold', asset: 'Rajdhani-Bold.ttf'),
    SilkFontInfo('bebas-neue', 'Bebas Neue', asset: 'BebasNeue-Regular.ttf'),
    SilkFontInfo('russo-one', 'Russo One', asset: 'RussoOne-Regular.ttf'),
    SilkFontInfo(
      'press-start',
      'Press Start 2P',
      asset: 'PressStart2P-Regular.ttf',
    ),
  ];

  static final _fonts = <String, TrueTypeFont>{};
  static final _userNames = <String, String>{};

  /// Makes font [id] available, from its file's [bytes].
  static TrueTypeFont register(String id, Uint8List bytes, {String? name}) {
    final font = TrueTypeFont.parse(bytes);
    _fonts[id] = font;
    if (id.startsWith('user:')) _userNames[id] = name ?? font.family;
    return font;
  }

  static void unregister(String id) {
    _fonts.remove(id);
    _userNames.remove(id);
  }

  /// The font behind [id], or null for the stroke font or one not loaded.
  static TrueTypeFont? byId(String id) => id.isEmpty ? null : _fonts[id];

  /// Every font that can be picked right now, the stroke font first.
  static List<SilkFontInfo> get available => [
    stroke,
    for (final font in bundled)
      if (_fonts.containsKey(font.id)) font,
    for (final entry in _userNames.entries)
      SilkFontInfo(entry.key, entry.value),
  ];

  /// A readable name for [id].
  static String nameOf(String id) =>
      available.where((f) => f.id == id).firstOrNull?.name ?? stroke.name;
}

/// Silkscreen text drawn in a TrueType font, as the outlines of its letters.
abstract final class SilkText {
  /// The outlines of [text] in [font], centred on [centre], in board
  /// millimetres with y pointing down. [height] is the capital height.
  ///
  /// Laid out exactly as the stroke font lays text out: centred on the
  /// middle of the line and of the capitals, turned [rotation] degrees
  /// counter-clockwise, and reversed with [mirror] for the underside.
  static List<List<Offset>> contours(
    String text,
    TrueTypeFont font, {
    required Offset centre,
    required double height,
    double rotation = 0,
    bool mirror = false,
  }) {
    final scale = height / font.capHeightUnits;
    final glyphs = <(int, double)>[];
    var cursor = 0.0;
    for (final rune in text.runes) {
      final glyph = font.glyphIndex(rune);
      glyphs.add((glyph, cursor));
      cursor += font.advance(glyph);
    }
    final width = cursor;
    final radians = rotation * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    Offset place(Offset p, double at) {
      var x = (at + p.dx - width / 2) * scale;
      final y =
          (p.dy - font.capBottomUnits - font.capHeightUnits / 2) * scale;
      if (mirror) x = -x;
      return centre + Offset(x * cos - y * sin, -(x * sin + y * cos));
    }

    return [
      for (final (glyph, at) in glyphs)
        for (final contour in font.contours(glyph))
          [for (final p in contour) place(p, at)],
    ];
  }

  /// How long [text] runs in [font] at capital height [height].
  static double widthOf(String text, TrueTypeFont font, double height) {
    var cursor = 0.0;
    for (final rune in text.runes) {
      cursor += font.advance(font.glyphIndex(rune));
    }
    return cursor * height / font.capHeightUnits;
  }

  /// [contours] grouped into solid shapes, each with the holes inside it —
  /// the counters of an O, the two of a B. Nesting decides which is which,
  /// not the direction a contour runs, since fonts disagree on that.
  static List<(List<Offset>, List<List<Offset>>)> shapes(
    List<List<Offset>> contours,
  ) {
    final depth = [
      for (var i = 0; i < contours.length; i++)
        [
          for (var j = 0; j < contours.length; j++)
            if (i != j && _inside(contours[i].first, contours[j])) j,
        ],
    ];
    final result = <(List<Offset>, List<List<Offset>>)>[];
    final outerIndex = <int, int>{};
    for (var i = 0; i < contours.length; i++) {
      if (depth[i].length.isEven) {
        outerIndex[i] = result.length;
        result.add((contours[i], []));
      }
    }
    for (var i = 0; i < contours.length; i++) {
      if (depth[i].length.isEven) continue;
      // Its container is the enclosing outer contour nested deepest.
      int? parent;
      for (final j in depth[i]) {
        if (!depth[j].length.isEven) continue;
        if (parent == null || depth[j].length > depth[parent].length) {
          parent = j;
        }
      }
      if (parent != null) result[outerIndex[parent]!].$2.add(contours[i]);
    }
    return result;
  }

  static bool _inside(Offset point, List<Offset> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > point.dy) == (b.dy > point.dy)) continue;
      final x = (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (point.dx < x) inside = !inside;
    }
    return inside;
  }
}
