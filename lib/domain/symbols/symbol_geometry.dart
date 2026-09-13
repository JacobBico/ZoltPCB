import 'dart:ui' show Color;

/// A point in symbol space, in millimetres.
///
/// KiCad symbol coordinates are Y-up, unlike screen coordinates. The values
/// are kept exactly as the file states them; flipping is the renderer's job,
/// and the exporter needs the original numbers back.
class SymbolPoint {
  const SymbolPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is SymbolPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// KiCad line styles.
enum StrokeType {
  defaultStyle('default'),
  solid('solid'),
  dash('dash'),
  dashDot('dash_dot'),
  dashDotDot('dash_dot_dot'),
  dot('dot');

  const StrokeType(this.token);

  final String token;

  static StrokeType fromToken(String token) => StrokeType.values.firstWhere(
    (t) => t.token == token,
    orElse: () => StrokeType.defaultStyle,
  );
}

/// KiCad fill modes. `background` means "the theme's body-fill colour",
/// which is why it is a mode rather than a colour.
enum FillType {
  none('none'),
  outline('outline'),
  background('background'),
  color('color');

  const FillType(this.token);

  final String token;

  static FillType fromToken(String token) => FillType.values.firstWhere(
    (t) => t.token == token,
    orElse: () => FillType.none,
  );
}

class StrokeStyle {
  const StrokeStyle({
    this.width = 0,
    this.type = StrokeType.defaultStyle,
    this.color,
  });

  static const defaultStroke = StrokeStyle();

  /// Line width in millimetres. `0` means "use the editor's default", which
  /// KiCad writes for most library graphics.
  final double width;
  final StrokeType type;
  final Color? color;

  @override
  String toString() => 'Stroke($width, ${type.token})';
}

class FillStyle {
  const FillStyle({this.type = FillType.none, this.color});

  static const none = FillStyle();

  final FillType type;
  final Color? color;

  @override
  String toString() => 'Fill(${type.token})';
}

enum TextHorizontalAlign { left, center, right }

enum TextVerticalAlign { top, middle, bottom }

/// Text rendering attributes shared by symbol text, pin names and fields.
class TextEffects {
  const TextEffects({
    this.sizeX = 1.27,
    this.sizeY = 1.27,
    this.bold = false,
    this.italic = false,
    this.hidden = false,
    this.horizontal = TextHorizontalAlign.center,
    this.vertical = TextVerticalAlign.middle,
    this.mirrored = false,
  });

  static const standard = TextEffects();

  final double sizeX;
  final double sizeY;
  final bool bold;
  final bool italic;
  final bool hidden;
  final TextHorizontalAlign horizontal;
  final TextVerticalAlign vertical;
  final bool mirrored;

  @override
  String toString() => 'TextEffects($sizeX×$sizeY, hidden: $hidden)';
}

/// A drawing primitive belonging to one unit of a symbol.
sealed class SymbolGraphic {
  const SymbolGraphic({
    this.stroke = StrokeStyle.defaultStroke,
    this.fill = FillStyle.none,
  });

  final StrokeStyle stroke;
  final FillStyle fill;
}

class SymbolPolyline extends SymbolGraphic {
  const SymbolPolyline({required this.points, super.stroke, super.fill});

  final List<SymbolPoint> points;

  @override
  String toString() => 'Polyline(${points.length} pts)';
}

class SymbolRectangle extends SymbolGraphic {
  const SymbolRectangle({
    required this.start,
    required this.end,
    super.stroke,
    super.fill,
  });

  final SymbolPoint start;
  final SymbolPoint end;

  @override
  String toString() => 'Rectangle($start → $end)';
}

class SymbolCircle extends SymbolGraphic {
  const SymbolCircle({
    required this.center,
    required this.radius,
    super.stroke,
    super.fill,
  });

  final SymbolPoint center;
  final double radius;

  @override
  String toString() => 'Circle($center, r$radius)';
}

/// An arc given by three points on it. KiCad stores start/mid/end rather
/// than centre and angles, so the renderer will have to derive the centre.
class SymbolArc extends SymbolGraphic {
  const SymbolArc({
    required this.start,
    required this.mid,
    required this.end,
    super.stroke,
    super.fill,
  });

  final SymbolPoint start;
  final SymbolPoint mid;
  final SymbolPoint end;

  @override
  String toString() => 'Arc($start → $mid → $end)';
}

class SymbolBezier extends SymbolGraphic {
  const SymbolBezier({required this.points, super.stroke, super.fill});

  final List<SymbolPoint> points;

  @override
  String toString() => 'Bezier(${points.length} pts)';
}

class SymbolText extends SymbolGraphic {
  const SymbolText({
    required this.text,
    required this.at,
    this.angle = 0,
    this.effects = TextEffects.standard,
  });

  final String text;
  final SymbolPoint at;
  final double angle;
  final TextEffects effects;

  @override
  String toString() => 'Text("$text")';
}

class SymbolTextBox extends SymbolGraphic {
  const SymbolTextBox({
    required this.text,
    required this.at,
    required this.size,
    this.angle = 0,
    this.effects = TextEffects.standard,
    super.stroke,
    super.fill,
  });

  final String text;
  final SymbolPoint at;

  /// Box width and height in millimetres. KiCad writes a negative height
  /// for a box that grows upwards.
  final SymbolPoint size;
  final double angle;
  final TextEffects effects;

  @override
  String toString() => 'TextBox("$text")';
}
