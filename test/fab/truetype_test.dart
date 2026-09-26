import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/fab/silk_fonts.dart';
import 'package:zolt/fab/truetype.dart';

Uint8List _asset(String name) => File('assets/fonts/$name').readAsBytesSync();

void main() {
  group('every bundled font reads', () {
    for (final info in SilkFonts.bundled) {
      test(info.name, () {
        final font = TrueTypeFont.parse(_asset(info.asset!));
        expect(font.unitsPerEm, greaterThan(0));
        expect(font.family, isNotEmpty);

        // Letters have outlines and move the pen on; a space moves it on
        // and has none.
        for (final letter in 'AZOLT0123'.runes) {
          final glyph = font.glyphIndex(letter);
          expect(glyph, isNot(0), reason: String.fromCharCode(letter));
          expect(font.contours(glyph), isNotEmpty);
          expect(font.advance(glyph), greaterThan(0));
        }
        final space = font.glyphIndex(0x20);
        expect(font.contours(space), isEmpty);
        expect(font.advance(space), greaterThan(0));

        // A capital's height is measured from the letter itself.
        final h = font.contours(font.glyphIndex(0x48)).expand((c) => c);
        final bottom = h.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
        final top = h.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
        expect(bottom, closeTo(font.capBottomUnits, 1));
        expect(top - bottom, closeTo(font.capHeightUnits, 1));
      });
    }
  });

  test('an O is one shape with one hole, a B one with two', () {
    final font = TrueTypeFont.parse(_asset('FiraSans-Bold.ttf'));
    List<(List<Offset>, List<List<Offset>>)> shapesOf(String letter) =>
        SilkText.shapes(
          SilkText.contours(
            letter,
            font,
            centre: const Offset(10, 10),
            height: 2,
          ),
        );
    expect(shapesOf('O'), hasLength(1));
    expect(shapesOf('O').single.$2, hasLength(1));
    expect(shapesOf('B').single.$2, hasLength(2));
    expect(shapesOf('i'), hasLength(2)); // the stem and the dot
  });

  test('text is centred and as tall as asked', () {
    final font = TrueTypeFont.parse(_asset('ChakraPetch-Bold.ttf'));
    final points = SilkText.contours(
      'ZOLT',
      font,
      centre: const Offset(50, 20),
      height: 3,
    ).expand((c) => c).toList();
    double min(double Function(Offset) f) =>
        points.map(f).reduce((a, b) => a < b ? a : b);
    double max(double Function(Offset) f) =>
        points.map(f).reduce((a, b) => a > b ? a : b);
    // Capitals only, so the ink spans the capital height, centred on 20.
    expect(max((p) => p.dy) - min((p) => p.dy), closeTo(3, 0.05));
    expect((max((p) => p.dy) + min((p) => p.dy)) / 2, closeTo(20, 0.05));
    // And the line is centred on 50, give or take the side bearings.
    expect((max((p) => p.dx) + min((p) => p.dx)) / 2, closeTo(50, 0.3));
    expect(
      SilkText.widthOf('ZOLT', font, 3),
      greaterThan(max((p) => p.dx) - min((p) => p.dx)),
    );
  });

  test('a font with PostScript outlines is refused, saying why', () {
    final otto = Uint8List.fromList([
      0x4F,
      0x54,
      0x54,
      0x4F,
      ...List.filled(40, 0),
    ]);
    expect(
      () => TrueTypeFont.parse(otto),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('TrueType'),
        ),
      ),
    );
    expect(
      () => TrueTypeFont.parse(Uint8List.fromList('hello'.codeUnits)),
      throwsFormatException,
    );
  });
}
