import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/core/theme/kicad_palette.dart';
import 'package:hintpcb/rendering/schematic_painter.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colours, 1 to 21.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A rough perceptual distance, enough to tell "the same colour" from "not".
double _distance(Color a, Color b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  for (final palette in AppPalettes.all) {
    group(palette.name, () {
      test('body text is readable on every surface it sits on', () {
        for (final (name, ground) in [
          ('background', palette.background),
          ('surface', palette.surface),
          ('raised', palette.surfaceRaised),
        ]) {
          expect(
            _contrast(palette.textPrimary, ground),
            greaterThanOrEqualTo(7.0),
            reason: 'primary text on $name',
          );
          expect(
            _contrast(palette.textSecondary, ground),
            greaterThanOrEqualTo(3.0),
            reason: 'secondary text on $name',
          );
        }
      });

      test('the drawing stands out from the canvas', () {
        for (final (name, colour) in [
          ('symbols', palette.symbolOutline),
          ('wires', palette.wire),
          ('selection', palette.highlight),
          ('fields', palette.fieldText),
        ]) {
          expect(
            _contrast(colour, palette.canvas),
            greaterThanOrEqualTo(3.0),
            reason: '$name on the schematic canvas',
          );
        }
        for (final (name, colour) in [
          ('front copper', palette.frontCopper),
          ('back copper', palette.backCopper),
          ('board edge', palette.edgeCuts),
          ('silkscreen', palette.silkscreen),
        ]) {
          expect(
            _contrast(colour, palette.boardCanvas),
            greaterThanOrEqualTo(2.5),
            reason: '$name on the board canvas',
          );
        }
      });

      test('things that mean different things look different', () {
        // A wire that looks like the selection, or front copper that looks
        // like back, and the drawing stops saying which is which.
        final roles = {
          'wire': palette.wire,
          'symbol': palette.symbolOutline,
          'selection': palette.highlight,
          'error': palette.error,
        };
        final names = roles.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            // Symbol and error share red in most palettes by convention,
            // and never appear in the same role on screen.
            if ({names[i], names[j]}.containsAll({'symbol', 'error'})) {
              continue;
            }
            expect(
              _distance(roles[names[i]]!, roles[names[j]]!),
              greaterThan(0.15),
              reason: '${names[i]} and ${names[j]} are too alike',
            );
          }
        }
        expect(
          _distance(palette.frontCopper, palette.backCopper),
          greaterThan(0.15),
          reason: 'front and back copper are too alike',
        );
        expect(
          _distance(palette.highlight, palette.backCopper),
          greaterThan(0.15),
          reason: 'the selection looks like back copper',
        );
      });
    });
  }

  test('an unknown palette id falls back rather than failing', () {
    // A setting written by a newer version must not stop this one opening.
    expect(AppPalettes.byId('from-the-future'), AppPalettes.kicad);
    expect(AppPalettes.byId(null), AppPalettes.kicad);
  });

  test('palette ids are unique', () {
    final ids = AppPalettes.all.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  group('which parts get the zigzag', () {
    test('resistors of every kind', () {
      for (final reference in ['R1', 'R12', 'RV3', 'RT1', 'RN2', 'R?']) {
        expect(SchematicPainter.isResistor(reference), isTrue, reason: reference);
      }
    });

    test('and nothing else', () {
      for (final reference in ['C1', 'U1', 'Q1', 'D1', 'L1', 'SW1', 'RLY1']) {
        expect(
          SchematicPainter.isResistor(reference),
          isFalse,
          reason: reference,
        );
      }
    });
  });
}
