import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A TrueType font, read far enough to draw text with it: the character
/// map, each glyph's outline and each glyph's advance.
///
/// Silkscreen text is fabricated from outlines, so the same contours are
/// drawn on the screen and written to the Gerbers — what is seen is what is
/// made. Only TrueType outlines (`glyf`) are read; a font with PostScript
/// outlines (an `.otf` beginning `OTTO`) is refused with a message saying
/// so, rather than drawn wrong.
class TrueTypeFont {
  TrueTypeFont._(
    this._data,
    this._tables, {
    required this.family,
    required this.unitsPerEm,
    required this.capHeight,
    required int numGlyphs,
    required int numberOfHMetrics,
    required bool longLoca,
  }) : _numGlyphs = numGlyphs,
       _numberOfHMetrics = numberOfHMetrics,
       _longLoca = longLoca;

  final ByteData _data;
  final Map<String, (int, int)> _tables;
  final int _numGlyphs;
  final int _numberOfHMetrics;
  final bool _longLoca;

  /// The family name the font gives itself.
  final String family;

  final int unitsPerEm;

  /// The height of a capital letter, in font units.
  final double capHeight;

  final _cmap = <int, int>{};
  final _outlines = <int, List<List<Offset>>>{};

  /// Reads [bytes], or throws a [FormatException] saying why it cannot.
  static TrueTypeFont parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12) throw const FormatException('Not a font file');
    final tag = String.fromCharCodes(bytes.sublist(0, 4));
    if (tag == 'OTTO') {
      throw const FormatException(
        'This font uses PostScript (CFF) outlines. Pick the TrueType '
        '(.ttf) version of it instead.',
      );
    }
    if (tag == 'ttcf') {
      throw const FormatException(
        'This is a font collection. Pick a single .ttf font instead.',
      );
    }
    if (data.getUint32(0) != 0x00010000 && tag != 'true') {
      throw const FormatException('Not a TrueType font');
    }

    final tables = <String, (int, int)>{};
    final count = data.getUint16(4);
    for (var i = 0; i < count; i++) {
      final at = 12 + i * 16;
      if (at + 16 > bytes.length) break;
      final name = String.fromCharCodes(bytes.sublist(at, at + 4));
      tables[name] = (data.getUint32(at + 8), data.getUint32(at + 12));
    }
    for (final needed in ['head', 'maxp', 'cmap', 'hhea', 'hmtx', 'loca']) {
      if (!tables.containsKey(needed)) {
        throw FormatException('The font has no $needed table');
      }
    }
    if (!tables.containsKey('glyf')) {
      throw const FormatException(
        'This font has no TrueType outlines. Pick a .ttf font instead.',
      );
    }

    final head = tables['head']!.$1;
    final unitsPerEm = data.getUint16(head + 18);
    final longLoca = data.getInt16(head + 50) == 1;
    final numGlyphs = data.getUint16(tables['maxp']!.$1 + 4);
    final numberOfHMetrics = data.getUint16(tables['hhea']!.$1 + 34);

    var capHeight = unitsPerEm * 0.7;
    final os2 = tables['OS/2'];
    if (os2 != null && os2.$2 >= 90 && data.getUint16(os2.$1) >= 2) {
      final value = data.getInt16(os2.$1 + 88);
      if (value > 0) capHeight = value.toDouble();
    }

    final font = TrueTypeFont._(
      data,
      tables,
      family: _familyName(data, tables['name']) ?? 'Font',
      unitsPerEm: unitsPerEm,
      capHeight: capHeight,
      numGlyphs: numGlyphs,
      numberOfHMetrics: numberOfHMetrics,
      longLoca: longLoca,
    );
    font._readCmap();
    // Measured from the glyph rather than trusted from the header, where
    // one exists: some fonts leave the OS/2 figure at zero or wrong.
    // And from the bottom of the letter too: a pixel font can stand its
    // capitals a pixel above the baseline.
    final h = font.glyphIndex(0x48);
    if (h != 0) {
      final ys = font.contours(h).expand((c) => c).map((p) => p.dy);
      if (ys.isNotEmpty) {
        final top = ys.reduce(math.max);
        final bottom = ys.reduce(math.min);
        if (top > bottom) {
          font
            .._capHeightMeasured = top - bottom
            .._capBottom = bottom;
        }
      }
    }
    return font;
  }

  double? _capHeightMeasured;
  double _capBottom = 0;

  /// The capital height to lay text out by.
  double get capHeightUnits => _capHeightMeasured ?? capHeight;

  /// Where capitals stand, above the baseline: zero for nearly every font.
  double get capBottomUnits => _capBottom;

  /// The glyph for [codepoint]; 0, the "missing" glyph, when there is none.
  int glyphIndex(int codepoint) => _cmap[codepoint] ?? 0;

  /// How far along the line glyph [glyph] moves the next one, in font units.
  double advance(int glyph) {
    final hmtx = _tables['hmtx']!.$1;
    final index = glyph < _numberOfHMetrics ? glyph : _numberOfHMetrics - 1;
    return _data.getUint16(hmtx + index * 4).toDouble();
  }

  /// Glyph [glyph]'s outline as closed contours of points, in font units
  /// with y pointing up. Curves come back as short straight runs.
  List<List<Offset>> contours(int glyph) =>
      _outlines[glyph] ??= _readGlyph(glyph, 0);

  // --- the tables -------------------------------------------------------

  static String? _familyName(ByteData data, (int, int)? table) {
    if (table == null) return null;
    final base = table.$1;
    final count = data.getUint16(base + 2);
    final storage = base + data.getUint16(base + 4);
    String? best;
    var bestRank = 99;
    for (var i = 0; i < count; i++) {
      final at = base + 6 + i * 12;
      final platform = data.getUint16(at);
      final nameId = data.getUint16(at + 6);
      if (nameId != 1 && nameId != 16) continue;
      final length = data.getUint16(at + 8);
      final offset = storage + data.getUint16(at + 10);
      String text;
      if (platform == 3 || platform == 0) {
        final units = <int>[
          for (var j = 0; j + 1 < length; j += 2) data.getUint16(offset + j),
        ];
        text = String.fromCharCodes(units);
      } else {
        text = String.fromCharCodes([
          for (var j = 0; j < length; j++) data.getUint8(offset + j),
        ]);
      }
      // The typographic family (16) before the legacy one (1), Windows
      // names before Mac ones.
      final rank = (nameId == 16 ? 0 : 2) + (platform == 3 ? 0 : 1);
      if (text.trim().isNotEmpty && rank < bestRank) {
        best = text.trim();
        bestRank = rank;
      }
    }
    return best;
  }

  void _readCmap() {
    final base = _tables['cmap']!.$1;
    final count = _data.getUint16(base + 2);
    int? format4;
    int? format12;
    for (var i = 0; i < count; i++) {
      final at = base + 4 + i * 8;
      final platform = _data.getUint16(at);
      final encoding = _data.getUint16(at + 2);
      final offset = base + _data.getUint32(at + 4);
      final format = _data.getUint16(offset);
      final unicode = platform == 0 || (platform == 3 && encoding != 0);
      if (!unicode) continue;
      if (format == 12) format12 ??= offset;
      if (format == 4) format4 ??= offset;
    }
    if (format12 != null) {
      final groups = _data.getUint32(format12 + 12);
      for (var g = 0; g < groups; g++) {
        final at = format12 + 16 + g * 12;
        final start = _data.getUint32(at);
        final end = _data.getUint32(at + 4);
        final glyph = _data.getUint32(at + 8);
        // Past the Basic Multilingual Plane nothing silkscreen needs lives.
        for (var c = start; c <= end && c <= 0xFFFF; c++) {
          _cmap[c] = glyph + (c - start);
        }
      }
      return;
    }
    if (format4 == null) return;
    final segments = _data.getUint16(format4 + 6) ~/ 2;
    final ends = format4 + 14;
    final starts = ends + segments * 2 + 2;
    final deltas = starts + segments * 2;
    final rangeOffsets = deltas + segments * 2;
    for (var s = 0; s < segments; s++) {
      final end = _data.getUint16(ends + s * 2);
      final start = _data.getUint16(starts + s * 2);
      final delta = _data.getInt16(deltas + s * 2);
      final rangeOffset = _data.getUint16(rangeOffsets + s * 2);
      for (var c = start; c <= end && c != 0xFFFF; c++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (c + delta) & 0xFFFF;
        } else {
          final at = rangeOffsets + s * 2 + rangeOffset + (c - start) * 2;
          glyph = _data.getUint16(at);
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) _cmap[c] = glyph;
      }
    }
  }

  (int, int)? _glyphSpan(int glyph) {
    if (glyph < 0 || glyph >= _numGlyphs) return null;
    final loca = _tables['loca']!.$1;
    final int start;
    final int end;
    if (_longLoca) {
      start = _data.getUint32(loca + glyph * 4);
      end = _data.getUint32(loca + glyph * 4 + 4);
    } else {
      start = _data.getUint16(loca + glyph * 2) * 2;
      end = _data.getUint16(loca + glyph * 2 + 2) * 2;
    }
    if (end <= start) return null;
    return (_tables['glyf']!.$1 + start, end - start);
  }

  List<List<Offset>> _readGlyph(int glyph, int depth) {
    final span = _glyphSpan(glyph);
    if (span == null || depth > 8) return const [];
    final at = span.$1;
    final contourCount = _data.getInt16(at);
    return contourCount >= 0
        ? _simpleGlyph(at, contourCount)
        : _compositeGlyph(at, depth);
  }

  List<List<Offset>> _simpleGlyph(int at, int contourCount) {
    if (contourCount == 0) return const [];
    final ends = [
      for (var i = 0; i < contourCount; i++) _data.getUint16(at + 10 + i * 2),
    ];
    final pointCount = ends.last + 1;
    var p = at + 10 + contourCount * 2;
    final instructionLength = _data.getUint16(p);
    p += 2 + instructionLength;

    final flags = <int>[];
    while (flags.length < pointCount) {
      final flag = _data.getUint8(p++);
      flags.add(flag);
      if (flag & 8 != 0) {
        final repeat = _data.getUint8(p++);
        for (var r = 0; r < repeat; r++) {
          flags.add(flag);
        }
      }
    }

    final xs = List<int>.filled(pointCount, 0);
    var x = 0;
    for (var i = 0; i < pointCount; i++) {
      final flag = flags[i];
      if (flag & 2 != 0) {
        final d = _data.getUint8(p++);
        x += flag & 16 != 0 ? d : -d;
      } else if (flag & 16 == 0) {
        x += _data.getInt16(p);
        p += 2;
      }
      xs[i] = x;
    }
    final ys = List<int>.filled(pointCount, 0);
    var y = 0;
    for (var i = 0; i < pointCount; i++) {
      final flag = flags[i];
      if (flag & 4 != 0) {
        final d = _data.getUint8(p++);
        y += flag & 32 != 0 ? d : -d;
      } else if (flag & 32 == 0) {
        y += _data.getInt16(p);
        p += 2;
      }
      ys[i] = y;
    }

    final contours = <List<Offset>>[];
    var first = 0;
    for (final end in ends) {
      final points = [
        for (var i = first; i <= end; i++)
          (Offset(xs[i].toDouble(), ys[i].toDouble()), flags[i] & 1 != 0),
      ];
      final flat = _flatten(points);
      if (flat.length >= 3) contours.add(flat);
      first = end + 1;
    }
    return contours;
  }

  List<List<Offset>> _compositeGlyph(int at, int depth) {
    final result = <List<Offset>>[];
    var p = at + 10;
    while (true) {
      final flags = _data.getUint16(p);
      final component = _data.getUint16(p + 2);
      p += 4;
      double dx;
      double dy;
      if (flags & 1 != 0) {
        dx = _data.getInt16(p).toDouble();
        dy = _data.getInt16(p + 2).toDouble();
        p += 4;
      } else {
        dx = _data.getInt8(p).toDouble();
        dy = _data.getInt8(p + 1).toDouble();
        p += 2;
      }
      // Point-matched placement is rare in text fonts; the offset is then
      // not a distance, so the component is placed unshifted.
      if (flags & 2 == 0) {
        dx = 0;
        dy = 0;
      }
      double f2dot14(int at) => _data.getInt16(at) / 16384;
      var a = 1.0, b = 0.0, c = 0.0, d = 1.0;
      if (flags & 8 != 0) {
        a = d = f2dot14(p);
        p += 2;
      } else if (flags & 0x40 != 0) {
        a = f2dot14(p);
        d = f2dot14(p + 2);
        p += 4;
      } else if (flags & 0x80 != 0) {
        a = f2dot14(p);
        b = f2dot14(p + 2);
        c = f2dot14(p + 4);
        d = f2dot14(p + 6);
        p += 8;
      }
      for (final contour in _readGlyph(component, depth + 1)) {
        result.add([
          for (final q in contour)
            Offset(a * q.dx + c * q.dy + dx, b * q.dx + d * q.dy + dy),
        ]);
      }
      if (flags & 0x20 == 0) break;
    }
    return result;
  }

  /// A contour's on- and off-curve points as a run of straight pieces.
  /// Between two off-curve points lies an implied on-curve one, halfway.
  static List<Offset> _flatten(List<(Offset, bool)> points) {
    if (points.isEmpty) return const [];
    // Start on a point that is on the curve.
    var startIndex = points.indexWhere((p) => p.$2);
    final List<(Offset, bool)> ring;
    if (startIndex < 0) {
      final mid = Offset.lerp(points[0].$1, points[1 % points.length].$1, 0.5)!;
      ring = [(mid, true), ...points.skip(1), points[0]];
      startIndex = 0;
    } else {
      ring = [...points.sublist(startIndex), ...points.sublist(0, startIndex)];
    }

    final out = <Offset>[ring.first.$1];
    var current = ring.first.$1;
    Offset? control;
    void curveTo(Offset end) {
      final ctrl = control!;
      const steps = 6;
      for (var s = 1; s <= steps; s++) {
        final t = s / steps;
        final u = 1 - t;
        out.add(current * (u * u) + ctrl * (2 * u * t) + end * (t * t));
      }
      current = end;
      control = null;
    }

    for (var i = 1; i <= ring.length; i++) {
      final (point, on) = ring[i % ring.length];
      if (on) {
        if (control != null) {
          curveTo(point);
        } else {
          out.add(point);
          current = point;
        }
      } else {
        if (control != null) curveTo(Offset.lerp(control, point, 0.5)!);
        control = point;
      }
    }
    // The ring closes on its first point, which is already the start.
    if (out.length > 1 && (out.last - out.first).distance < 1e-9) {
      out.removeLast();
    }
    return out;
  }
}
