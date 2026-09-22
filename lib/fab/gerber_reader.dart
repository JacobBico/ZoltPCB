import 'dart:math' as math;
import 'dart:ui';

/// One thing a Gerber file draws.
sealed class GerberShape {
  const GerberShape({required this.clear});

  /// Drawn in clear polarity: it removes what is under it rather than adding.
  final bool clear;
}

class GerberStroke extends GerberShape {
  const GerberStroke({
    required this.points,
    required this.width,
    required super.clear,
  });

  final List<Offset> points;
  final double width;
}

class GerberFlash extends GerberShape {
  const GerberFlash({
    required this.at,
    required this.aperture,
    required super.clear,
  });

  final Offset at;
  final GerberAperture aperture;
}

class GerberRegion extends GerberShape {
  const GerberRegion({required this.points, required super.clear});

  final List<Offset> points;
}

/// A standard aperture: circle, rectangle or obround.
class GerberAperture {
  const GerberAperture(this.kind, this.width, this.height);

  /// `C`, `R` or `O`.
  final String kind;
  final double width;
  final double height;
}

/// A Gerber layer read back into shapes, in board millimetres with y down.
class GerberImage {
  const GerberImage(this.shapes);

  final List<GerberShape> shapes;

  Rect? get bounds {
    Rect? all;
    void add(Offset p, double reach) {
      final r = Rect.fromCircle(center: p, radius: reach);
      all = all == null ? r : all!.expandToInclude(r);
    }

    for (final shape in shapes) {
      switch (shape) {
        case GerberStroke(:final points, :final width):
          for (final p in points) {
            add(p, width / 2);
          }
        case GerberFlash(:final at, :final aperture):
          add(at, math.max(aperture.width, aperture.height) / 2);
        case GerberRegion(:final points):
          for (final p in points) {
            add(p, 0);
          }
      }
    }
    return all;
  }
}

/// A drill hole read back from an Excellon file.
class DrillHole {
  const DrillHole(this.at, this.diameter);

  final Offset at;
  final double diameter;
}

/// Reads the Gerber and Excellon files this app writes, to show them.
///
/// Deliberately the subset those files use — standard apertures, linear
/// and arc draws, flashes, regions and polarity — rather than the whole of
/// RS-274X.
/// The point of the viewer is to show exactly what goes to the board house,
/// read back from the files themselves, not to open anyone else's.
abstract final class GerberReader {
  static GerberImage parse(String text) {
    final shapes = <GerberShape>[];
    final apertures = <int, GerberAperture>{};
    var scale = 1e-6;
    var clear = false;
    GerberAperture? current;
    var x = 0.0;
    var y = 0.0;
    var inRegion = false;
    var stroke = <Offset>[];
    var contour = <Offset>[];
    // Interpolation: 1 straight, 2 clockwise arc, 3 counter-clockwise.
    var mode = 1;

    void endStroke() {
      final aperture = current;
      if (stroke.length >= 2 && aperture != null) {
        shapes.add(
          GerberStroke(points: stroke, width: aperture.width, clear: clear),
        );
      }
      stroke = <Offset>[];
    }

    void endContour() {
      // A contour closes by returning to where it began; that last point is
      // the first one again, not another corner.
      if (contour.length > 1 &&
          (contour.first - contour.last).distance < 1e-9) {
        contour.removeLast();
      }
      if (contour.length >= 3) {
        shapes.add(GerberRegion(points: contour, clear: clear));
      }
      contour = <Offset>[];
    }

    // Extended commands live between % signs; ordinary ones end at *.
    final pattern = RegExp(r'%([^%]*)%|([^%*]+)\*');
    for (final match in pattern.allMatches(text)) {
      final extended = match.group(1);
      if (extended != null) {
        for (final command in extended.split('*')) {
          final c = command.trim();
          if (c.startsWith('FS')) {
            final decimals = RegExp(r'X\d(\d)').firstMatch(c)?.group(1);
            if (decimals != null) {
              scale = math.pow(10, -int.parse(decimals)).toDouble();
            }
          } else if (c.startsWith('LP')) {
            endStroke();
            clear = c == 'LPC';
          } else if (c.startsWith('ADD')) {
            final m = RegExp(
              r'^ADD(\d+)([CRO]),([\d.]+)(?:X([\d.]+))?',
            ).firstMatch(c);
            if (m != null) {
              final w = double.parse(m.group(3)!);
              apertures[int.parse(m.group(1)!)] = GerberAperture(
                m.group(2)!,
                w,
                m.group(4) == null ? w : double.parse(m.group(4)!),
              );
            }
          }
        }
        continue;
      }

      final command = match.group(2)!.trim();
      if (command.isEmpty) continue;
      if (command == 'G36') {
        endStroke();
        inRegion = true;
        continue;
      }
      if (command == 'G37') {
        endContour();
        inRegion = false;
        continue;
      }
      final setMode = RegExp(r'^G0?([123])$').firstMatch(command);
      if (setMode != null) {
        mode = int.parse(setMode.group(1)!);
        continue;
      }
      final select = RegExp(r'^(?:G54)?D(\d+)$').firstMatch(command);
      if (select != null && int.parse(select.group(1)!) >= 10) {
        endStroke();
        current = apertures[int.parse(select.group(1)!)];
        continue;
      }

      final coordinate = RegExp(
        r'^(?:G0?([123]))?(?:X(-?\d+))?(?:Y(-?\d+))?'
        r'(?:I(-?\d+))?(?:J(-?\d+))?D0?([123])$',
      ).firstMatch(command);
      if (coordinate == null) continue;
      if (coordinate.group(1) != null) mode = int.parse(coordinate.group(1)!);
      final previous = Offset(x, -y);
      if (coordinate.group(2) != null) {
        x = int.parse(coordinate.group(2)!) * scale;
      }
      if (coordinate.group(3) != null) {
        y = int.parse(coordinate.group(3)!) * scale;
      }
      final at = Offset(x, -y);
      // An arc arrives as the corners along it, so everything that draws
      // or measures a stroke keeps working on points.
      final along = mode == 1 || coordinate.group(6) != '1'
          ? [at]
          : _arcPoints(
              previous,
              at,
              previous +
                  Offset(
                    int.parse(coordinate.group(4) ?? '0') * scale,
                    -int.parse(coordinate.group(5) ?? '0') * scale,
                  ),
              clockwise: mode == 2,
            );

      switch (coordinate.group(6)) {
        case '2':
          if (inRegion) {
            endContour();
            contour.add(at);
          } else {
            endStroke();
            stroke.add(at);
          }
        case '1':
          if (inRegion) {
            if (contour.isEmpty) contour.add(previous);
            contour.addAll(along);
          } else {
            if (stroke.isEmpty) stroke.add(previous);
            stroke.addAll(along);
          }
        case '3':
          endStroke();
          final aperture = current;
          if (aperture != null) {
            shapes.add(GerberFlash(at: at, aperture: aperture, clear: clear));
          }
      }
    }
    endStroke();
    endContour();
    return GerberImage(shapes);
  }

  /// Corners along an arc from [from] to [to] around [centre], ending at
  /// [to]. Clockwise as the board is seen (y down); an arc that ends where
  /// it starts is a whole circle.
  static List<Offset> _arcPoints(
    Offset from,
    Offset to,
    Offset centre, {
    required bool clockwise,
  }) {
    final r = (from - centre).distance;
    if (r < 1e-9) return [to];
    double angle(Offset p) => math.atan2(p.dy - centre.dy, p.dx - centre.dx);
    final a0 = angle(from);
    var sweep = angle(to) - a0;
    if (clockwise) {
      while (sweep <= 1e-9) {
        sweep += math.pi * 2;
      }
    } else {
      while (sweep >= -1e-9) {
        sweep -= math.pi * 2;
      }
    }
    final steps = math.max(8, (sweep.abs() * r / 0.1).ceil());
    return [
      for (var i = 1; i < steps; i++)
        centre +
            Offset(
              r * math.cos(a0 + sweep * i / steps),
              r * math.sin(a0 + sweep * i / steps),
            ),
      to,
    ];
  }

  /// The holes in an Excellon drill file.
  static List<DrillHole> parseDrill(String text) {
    final tools = <String, double>{};
    final holes = <DrillHole>[];
    double? diameter;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      final tool = RegExp(r'^T(\d+)C([\d.]+)').firstMatch(line);
      if (tool != null) {
        tools[tool.group(1)!] = double.parse(tool.group(2)!);
        continue;
      }
      final select = RegExp(r'^T(\d+)$').firstMatch(line);
      if (select != null) {
        diameter = tools[select.group(1)!];
        continue;
      }
      final hole = RegExp(r'^X(-?[\d.]+)Y(-?[\d.]+)$').firstMatch(line);
      if (hole != null && diameter != null) {
        holes.add(
          DrillHole(
            Offset(double.parse(hole.group(1)!), -double.parse(hole.group(2)!)),
            diameter,
          ),
        );
      }
    }
    return holes;
  }
}
