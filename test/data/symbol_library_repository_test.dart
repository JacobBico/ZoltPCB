import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/domain/models/pin.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';

const _library = '''
(kicad_symbol_lib
  (version 20251024)
  (generator "kicad_symbol_editor")
  (generator_version "10.0")
  (symbol "R"
    (property "Reference" "R")
    (property "Value" "R")
    (property "Description" "Resistor")
    (property "ki_keywords" "R res resistor")
    (property "ki_fp_filters" "R_*")
    (symbol "R_0_1" (rectangle (start -1.016 -2.54) (end 1.016 2.54)))
    (symbol "R_1_1"
      (pin passive line (at 0 3.81 270) (length 1.27) (name "") (number "1"))
      (pin passive line (at 0 -3.81 90) (length 1.27) (name "") (number "2"))))
  (symbol "R_Small"
    (extends "R")
    (property "Value" "R_Small")
    (property "Description" "Resistor, small symbol"))
  (symbol "C"
    (property "Reference" "C")
    (property "Value" "C")
    (property "Description" "Unpolarized capacitor")
    (property "ki_keywords" "cap capacitor")
    (symbol "C_1_1"
      (pin passive line (at 0 2.54 270) (length 2.54) (name "~") (number "1"))
      (pin passive line (at 0 -2.54 90) (length 2.54) (name "~") (number "2")))))
''';

const _powerLibrary = '''
(kicad_symbol_lib
  (version 20251024)
  (symbol "GND"
    (power global)
    (property "Reference" "#PWR")
    (property "Value" "GND")
    (property "Description" "ground")
    (symbol "GND_0_1" (polyline (pts (xy 0 0) (xy 0 -1.27))))
    (symbol "GND_1_1"
      (pin power_in line (at 0 0 270) (length 0) (name "") (number "1")))))
''';

Uint8List bytes(String source) => Uint8List.fromList(utf8.encode(source));

void main() {
  late AppDatabase db;
  late Directory root;
  late SymbolLibraryRepository repo;

  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('hintpcb_symbols');
    repo = SymbolLibraryRepository(db, FileLibraryStorage(root));
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('importing', () {
    test('stores the file and indexes every symbol', () async {
      final info = await repo.import(
        fileName: 'Device.kicad_sym',
        bytes: bytes(_library),
      );

      expect(info.nickname, 'Device');
      expect(info.symbolCount, 3);
      expect(info.formatVersion, 20251024);
      expect(info.generator, 'kicad_symbol_editor');
      expect(File('${root.path}/Device.kicad_sym').existsSync(), isTrue);
      expect(await repo.symbolCount(), 3);
    });

    test('the nickname comes from the file name', () async {
      final info = await repo.import(
        fileName:
            '/storage/emulated/0/Download/Amplifier_Operational.kicad_sym',
        bytes: bytes(_library),
      );

      expect(info.nickname, 'Amplifier_Operational');
      final entry = await repo.findByLibId('Amplifier_Operational:R');
      expect(entry, isNotNull);
    });

    test('index rows carry the searchable metadata', () async {
      await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
      final entry = (await repo.findByLibId('Device:R'))!;

      expect(entry.libId, 'Device:R');
      expect(entry.description, 'Resistor');
      expect(entry.keywords, 'R res resistor');
      expect(entry.referencePrefix, 'R');
      expect(entry.footprintFilters, 'R_*');
      expect(entry.pinCount, 2);
      expect(entry.unitCount, 1);
      expect(entry.spanEnd, greaterThan(entry.spanStart));
    });

    test('a derived symbol is indexed with its inherited pin count', () async {
      await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
      final entry = (await repo.findByLibId('Device:R_Small'))!;

      expect(entry.extendsSymbol, 'R');
      expect(entry.pinCount, 2);
      expect(entry.description, 'Resistor, small symbol');
    });

    test('re-importing a library replaces the previous copy', () async {
      await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
      await repo.import(
        fileName: 'Device.kicad_sym',
        bytes: bytes('''
(kicad_symbol_lib (version 20251024)
  (symbol "L"
    (property "Value" "L")
    (symbol "L_1_1"
      (pin passive line (at 0 2.54 270) (name "1") (number "1")))))
'''),
      );

      expect(await repo.getLibraries(), hasLength(1));
      expect(await repo.symbolCount(), 1);
      expect(await repo.findByLibId('Device:R'), isNull);
      expect(await repo.findByLibId('Device:L'), isNotNull);
    });

    test('rejects a file that is not a symbol library', () async {
      await expectLater(
        repo.import(fileName: 'notes.txt', bytes: bytes('hello there')),
        throwsA(isA<LibraryImportException>()),
      );
      expect(await repo.getLibraries(), isEmpty);
    });

    test('rejects a library with no symbols in it', () async {
      await expectLater(
        repo.import(
          fileName: 'Empty.kicad_sym',
          bytes: bytes('(kicad_symbol_lib (version 20251024))'),
        ),
        throwsA(isA<LibraryImportException>()),
      );
    });
  });

  group('searching', () {
    setUp(() async {
      await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
      await repo.import(
        fileName: 'power.kicad_sym',
        bytes: bytes(_powerLibrary),
      );
    });

    test('matches on name, description and keywords', () async {
      expect(
        (await repo.search('resistor')).map((e) => e.libId),
        containsAll(['Device:R', 'Device:R_Small']),
      );
      expect(
        (await repo.search('cap')).map((e) => e.libId),
        contains('Device:C'),
      );
      expect((await repo.search('ground')).single.libId, 'power:GND');
    });

    test('every term has to match, so extra words narrow the result', () async {
      expect((await repo.search('resistor small')).map((e) => e.libId), [
        'Device:R_Small',
      ]);
      expect(await repo.search('resistor banana'), isEmpty);
    });

    test('an exact name match ranks first', () async {
      final results = await repo.search('r');
      expect(results.first.name, 'R');
    });

    test('search is case-insensitive', () async {
      expect((await repo.search('RESISTOR')), isNotEmpty);
    });

    test('an empty query lists everything', () async {
      expect(await repo.search(''), hasLength(4));
    });

    test('results can be limited to one library', () async {
      final libraries = await repo.getLibraries();
      final power = libraries.firstWhere((l) => l.nickname == 'power');

      final results = await repo.search('', libraryId: power.id);
      expect(results.map((e) => e.libId), ['power:GND']);
    });

    test('power symbols can be filtered on their own', () async {
      final results = await repo.search('', powerOnly: true);
      expect(results.map((e) => e.libId), ['power:GND']);
    });
  });

  group('loading a symbol', () {
    setUp(() async {
      await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
    });

    test('reads only that symbol out of the file', () async {
      final symbol = (await repo.loadSymbol('Device:R'))!;

      expect(symbol.libId, 'Device:R');
      expect(symbol.pins.map((p) => p.number), ['1', '2']);
      expect(symbol.pins.first.electricalType, PinElectricalType.passive);
      expect(symbol.graphicsForUnit(1), isNotEmpty);
    });

    test('resolves inheritance across separate reads', () async {
      final symbol = (await repo.loadSymbol('Device:R_Small'))!;

      expect(symbol.value, 'R_Small');
      expect(symbol.description, 'Resistor, small symbol');
      // Pins and graphics come from the parent, read separately.
      expect(symbol.pins.map((p) => p.number), ['1', '2']);
      expect(symbol.graphicsForUnit(1), isNotEmpty);
    });

    test('returns null for an unknown symbol', () async {
      expect(await repo.loadSymbol('Device:Nope'), isNull);
      expect(await repo.loadSymbol('NoLib:R'), isNull);
      expect(await repo.loadSymbol('malformed'), isNull);
    });

    test('a second load is served from cache', () async {
      final first = await repo.loadSymbol('Device:R');
      final second = await repo.loadSymbol('Device:R');
      expect(identical(first, second), isTrue);
    });

    test('deleting a library removes its index, file and cache', () async {
      await repo.loadSymbol('Device:R');
      final library = (await repo.getLibraries()).single;

      await repo.deleteLibrary(library.id);

      expect(await repo.getLibraries(), isEmpty);
      expect(await repo.symbolCount(), 0);
      expect(File('${root.path}/Device.kicad_sym').existsSync(), isFalse);
      expect(await repo.loadSymbol('Device:R'), isNull);
    });
  });

  test('a symbol converts into a part spec ready for a project', () async {
    await repo.import(fileName: 'Device.kicad_sym', bytes: bytes(_library));
    final symbol = (await repo.loadSymbol('Device:R'))!;
    final spec = symbol.toNewPartSpec();

    expect(spec.libId, 'Device:R');
    expect(spec.referencePrefix, 'R');
    expect(spec.value, 'R');
    expect(spec.unitCount, 1);
    expect(spec.pins.map((p) => p.number), ['1', '2']);
    expect(spec.pins.first.electricalType, PinElectricalType.passive);
    expect(spec.pins.first.angle, 270);
  });

  test('a power symbol converts to a part kept out of the BOM', () async {
    await repo.import(fileName: 'power.kicad_sym', bytes: bytes(_powerLibrary));
    final gnd = (await repo.loadSymbol('power:GND'))!;
    final spec = gnd.toNewPartSpec();

    expect(gnd.isPower, isTrue);
    expect(spec.referencePrefix, '#PWR');
    expect(spec.inBom, isFalse);
    expect(spec.onBoard, isFalse);
  });
}
