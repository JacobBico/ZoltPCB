import 'dart:math' as math;
import 'dart:ui';

/// A small single-stroke font for silkscreen.
///
/// Gerber has no text: silkscreen lettering is drawn line by line, the way
/// a plotter would. KiCad ships its own stroke font for this; that is theirs
/// to ship, so this is a plain one drawn here — capitals, digits and the few
/// symbols designators and board labels use. Lower case prints as capitals.
abstract final class StrokeFont {
  /// Glyphs on a 4 × 6 grid, y up from the baseline. `|` separates strokes.
  static const _glyphs = <String, String>{
    'A': '0,0 0,4 2,6 4,4 4,0|0,3 4,3',
    'B': '0,0 0,6 3,6 4,5 4,4 3,3 0,3|3,3 4,2 4,1 3,0 0,0',
    'C': '4,5 3,6 1,6 0,5 0,1 1,0 3,0 4,1',
    'D': '0,0 0,6 3,6 4,5 4,1 3,0 0,0',
    'E': '4,0 0,0 0,6 4,6|0,3 3,3',
    'F': '0,0 0,6 4,6|0,3 3,3',
    'G': '4,5 3,6 1,6 0,5 0,1 1,0 3,0 4,1 4,3 2,3',
    'H': '0,0 0,6|4,0 4,6|0,3 4,3',
    'I': '1,0 3,0|2,0 2,6|1,6 3,6',
    'J': '0,1 1,0 2,0 3,1 3,6|2,6 4,6',
    'K': '0,0 0,6|4,6 0,2|1,3 4,0',
    'L': '0,6 0,0 4,0',
    'M': '0,0 0,6 2,3 4,6 4,0',
    'N': '0,0 0,6 4,0 4,6',
    'O': '1,0 0,1 0,5 1,6 3,6 4,5 4,1 3,0 1,0',
    'P': '0,0 0,6 3,6 4,5 4,4 3,3 0,3',
    'Q': '1,0 0,1 0,5 1,6 3,6 4,5 4,1 3,0 1,0|2,2 4,0',
    'R': '0,0 0,6 3,6 4,5 4,4 3,3 0,3|2,3 4,0',
    'S': '4,5 3,6 1,6 0,5 0,4 1,3 3,3 4,2 4,1 3,0 1,0 0,1',
    'T': '0,6 4,6|2,6 2,0',
    'U': '0,6 0,1 1,0 3,0 4,1 4,6',
    'V': '0,6 2,0 4,6',
    'W': '0,6 1,0 2,4 3,0 4,6',
    'X': '0,0 4,6|0,6 4,0',
    'Y': '0,6 2,3 4,6|2,3 2,0',
    'Z': '0,6 4,6 0,0 4,0',
    '0': '1,0 0,1 0,5 1,6 3,6 4,5 4,1 3,0 1,0|0,1 4,5',
    '1': '1,5 2,6 2,0|1,0 3,0',
    '2': '0,5 1,6 3,6 4,5 4,4 0,0 4,0',
    '3': '0,5 1,6 3,6 4,5 4,4 3,3 4,2 4,1 3,0 1,0 0,1|1,3 3,3',
    '4': '3,0 3,6 0,2 4,2',
    '5': '4,6 0,6 0,3 3,3 4,2 4,1 3,0 0,0',
    '6': '4,5 3,6 1,6 0,5 0,1 1,0 3,0 4,1 4,2 3,3 0,3',
    '7': '0,6 4,6 1,0',
    '8': '1,3 0,4 0,5 1,6 3,6 4,5 4,4 3,3 1,3 0,2 0,1 1,0 3,0 4,1 4,2 3,3',
    '9': '0,1 1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,4 1,3 4,3',
    '-': '1,3 3,3',
    '+': '0,3 4,3|2,1 2,5',
    '.': '2,0 2,0.4',
    ',': '2,0.5 1,-1',
    ':': '2,1 2,1.4|2,4 2,4.4',
    '/': '0,0 4,6',
    '_': '0,0 4,0',
    '=': '0,2 4,2|0,4 4,4',
    '(': '3,6 2,5 2,1 3,0',
    ')': '1,6 2,5 2,1 1,0',
    '#': '1,0 1,6|3,0 3,6|0,2 4,2|0,4 4,4',
    '~': '0,3 1,4 3,2 4,3',
    '%': '0,0 4,6|0,5 1,6|3,0 4,1',
    '*': '2,1 2,5|0,2 4,4|0,4 4,2',
    '!': '2,6 2,2|2,0 2,0.4',
    '?': '0,5 1,6 3,6 4,5 4,4 2,3 2,2|2,0 2,0.4',
    '<': '4,6 0,3 4,0',
    '>': '0,6 4,3 0,0',
    'Ω': '0,0 1,0 1,1 0,3 0,5 1,6 3,6 4,5 4,3 3,1 3,0 4,0',
    'µ': '0,-1 0,4|0,1 1,0 3,0 4,1|4,4 4,0',
  };

  /// How far apart characters sit, in grid units.
  static const _advance = 5.0;

  /// A comfortable stroke for text [height] millimetres tall.
  static double strokeWidth(double height) => math.max(0.1, height * 0.15);

  /// The strokes of [text], centred on [centre], in board millimetres with
  /// y pointing down.
  ///
  /// [rotation] is degrees counter-clockwise as the board is seen from the
  /// front. [mirror] reverses the text, for the back of the board, where it
  /// is read through the board from the other side.
  static List<List<Offset>> strokes(
    String text, {
    required Offset centre,
    required double height,
    double rotation = 0,
    bool mirror = false,
  }) {
    final unit = height / 6;
    final characters = text.toUpperCase().runes.toList();
    final width = (characters.length * _advance - 1) * unit;
    final radians = rotation * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    Offset place(double u, double v, int index) {
      // Glyph grid to text frame, y up, centred on the middle of the text.
      var x = (index * _advance + u) * unit - width / 2;
      final y = v * unit - 3 * unit;
      if (mirror) x = -x;
      final rx = x * cos - y * sin;
      final ry = x * sin + y * cos;
      return centre + Offset(rx, -ry);
    }

    final result = <List<Offset>>[];
    for (var i = 0; i < characters.length; i++) {
      final glyph = _glyphs[String.fromCharCode(characters[i])];
      if (glyph == null) continue;
      for (final stroke in glyph.split('|')) {
        final points = [
          for (final pair in stroke.split(' '))
            place(
              double.parse(pair.split(',')[0]),
              double.parse(pair.split(',')[1]),
              i,
            ),
        ];
        if (points.length >= 2) result.add(points);
      }
    }
    return result;
  }
}
