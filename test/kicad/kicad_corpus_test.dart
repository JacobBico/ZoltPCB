@Tags(['corpus'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/pin.dart';
import 'package:zolt/kicad/symbol_library_reader.dart';

/// Parses every stock KiCad symbol library installed on this machine.
///
/// Hand-written fixtures prove the parser understands the format as
/// documented; this proves it understands the format as actually written.
/// It is the difference between 30 symbols and 22,000, and it is where the
/// awkward cases live — unit 0 pins, De Morgan bodies, symbols whose names
/// contain underscores, escaped quotes, non-ASCII values.
///
/// Skipped automatically where KiCad is not installed. Run explicitly with
/// `flutter test --tags corpus`.
void main() {
  const path = '/usr/share/kicad/symbols';
  final directory = Directory(path);

  if (!directory.existsSync()) {
    test('KiCad symbol libraries are not installed', () {}, skip: true);
    return;
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.kicad_sym'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test(
    'every stock library parses without error',
    () {
      expect(files, isNotEmpty, reason: 'expected libraries at $path');

      final stopwatch = Stopwatch()..start();
      var symbolCount = 0;
      var derivedCount = 0;
      var pinCount = 0;
      var multiUnitCount = 0;
      var unitZeroPinCount = 0;
      var totalBytes = 0;
      final warnings = <String>[];
      final failures = <String>[];

      for (final file in files) {
        final nickname = file.uri.pathSegments.last.replaceAll(
          '.kicad_sym',
          '',
        );
        final bytes = file.readAsBytesSync();
        totalBytes += bytes.length;

        try {
          final library = SymbolLibraryReader.parseLibrary(
            bytes,
            nickname: nickname,
          );

          // The scan and the parse must agree on how many symbols there are.
          expect(
            library.symbols.length,
            library.spans.length,
            reason: '$nickname: span count disagrees with parsed count',
          );

          for (final symbol in library.symbols) {
            symbolCount++;
            if (symbol.isDerived) derivedCount++;
            if (symbol.isMultiUnit) multiUnitCount++;
            pinCount += symbol.pinCount;
            if (symbol.unitDrawings.any(
              (d) => d.unit == 0 && d.pins.isNotEmpty,
            )) {
              unitZeroPinCount++;
            }
          }
          warnings.addAll(library.warnings.map((w) => '$nickname: $w'));
        } catch (error, stack) {
          failures.add('$nickname: $error\n$stack');
        }
      }
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'corpus: ${files.length} libraries, '
        '${(totalBytes / 1024 / 1024).toStringAsFixed(0)} MB, '
        '$symbolCount symbols ($derivedCount derived, '
        '$multiUnitCount multi-unit, $unitZeroPinCount with unit-0 pins), '
        '$pinCount pins in ${stopwatch.elapsedMilliseconds} ms',
      );

      expect(failures, isEmpty, reason: failures.take(3).join('\n\n'));
      expect(warnings, isEmpty, reason: warnings.take(10).join('\n'));

      // Guards against a parser that silently stops finding things.
      expect(symbolCount, greaterThan(20000));
      expect(pinCount, greaterThan(400000));
      expect(derivedCount, greaterThan(10000));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('symbols resolve to usable pin data', () {
    // Device:R — the simplest real symbol.
    final device = SymbolLibraryReader.parseLibrary(
      File('$path/Device.kicad_sym').readAsBytesSync(),
      nickname: 'Device',
    );
    final resistor = device.symbols.firstWhere((s) => s.name == 'R');

    expect(resistor.libId, 'Device:R');
    expect(resistor.referencePrefix, 'R');
    expect(resistor.description, contains('Resistor'));
    expect(resistor.pins.map((p) => p.number), ['1', '2']);
    expect(
      resistor.pins.every((p) => p.electricalType == PinElectricalType.passive),
      isTrue,
    );
    expect(resistor.graphicsForUnit(1), isNotEmpty);
  });

  test('a derived multi-unit symbol carries its parent pins', () {
    // NE5532 extends LM2904: a dual opamp whose supply pins live in unit 3.
    final amplifiers = SymbolLibraryReader.parseLibrary(
      File('$path/Amplifier_Operational.kicad_sym').readAsBytesSync(),
      nickname: 'Amplifier_Operational',
    );
    final ne5532 = amplifiers.symbols.firstWhere((s) => s.name == 'NE5532');

    expect(ne5532.isDerived, isTrue);
    expect(ne5532.value, 'NE5532');
    expect(ne5532.unitCount, 3);
    expect(ne5532.pinCount, 8);

    final supply = ne5532
        .pinsForUnit(3)
        .where((p) => p.electricalType.isPower)
        .map((p) => p.name)
        .toSet();
    expect(supply, {'V+', 'V-'});
  });

  test('power symbols are flagged and carry one power pin', () {
    final power = SymbolLibraryReader.parseLibrary(
      File('$path/power.kicad_sym').readAsBytesSync(),
      nickname: 'power',
    );
    final gnd = power.symbols.firstWhere((s) => s.name == 'GND');

    expect(gnd.isPower, isTrue);
    expect(gnd.reference, '#PWR');
    expect(gnd.pins.single.electricalType, PinElectricalType.powerIn);
    expect(gnd.graphicsForUnit(1), isNotEmpty);
    expect(power.symbols.where((s) => s.isPower).length, greaterThan(50));
  });

  test('a symbol with pins shared across every unit resolves them', () {
    // 4xxx_IEEE puts the supply pins of each logic family in unit 0.
    final logic = SymbolLibraryReader.parseLibrary(
      File('$path/4xxx_IEEE.kicad_sym').readAsBytesSync(),
      nickname: '4xxx_IEEE',
    );
    final quadNand = logic.symbols.firstWhere((s) => s.name == '4011');

    expect(quadNand.isMultiUnit, isTrue);
    final shared = quadNand.unitDrawings
        .where((d) => d.unit == 0)
        .expand((d) => d.pins)
        .map((p) => p.name)
        .toSet();
    expect(shared, isNotEmpty);

    // Every gate sees the shared supply pins.
    for (var unit = 1; unit <= quadNand.unitCount; unit++) {
      final names = quadNand.pinsForUnit(unit).map((p) => p.name).toSet();
      expect(names.containsAll(shared), isTrue, reason: 'unit $unit');
    }
  });
}
