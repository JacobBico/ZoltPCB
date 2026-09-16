import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/editors/own_library_store.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/domain/editors/footprint_design.dart';
import 'package:hintpcb/domain/editors/symbol_design.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/kicad/footprint_parser.dart';
import 'package:hintpcb/kicad/footprint_writer.dart';
import 'package:hintpcb/kicad/sexpr/sexpr_parser.dart';

void main() {
  group('symbols', () {
    const design = SymbolDesign(
      name: 'LDO_3V3',
      reference: 'U',
      value: 'AMS1117-3.3',
      pins: [
        PinDesign(number: '3', name: 'VIN', type: PinElectricalType.powerIn),
        PinDesign(
          number: '2',
          name: 'VOUT',
          type: PinElectricalType.powerOut,
          side: PinSide.right,
        ),
        PinDesign(
          number: '1',
          name: 'GND',
          type: PinElectricalType.powerIn,
          side: PinSide.bottom,
        ),
      ],
    );

    test('every pin lands on the grid, facing out of its own side', () {
      final symbol = design.build();
      for (final pin in symbol.pins) {
        expect(pin.at.x % 1.27, anyOf(closeTo(0, 1e-9), closeTo(1.27, 1e-9)));
        expect(pin.at.y % 1.27, anyOf(closeTo(0, 1e-9), closeTo(1.27, 1e-9)));
      }
      final byName = {for (final pin in symbol.pins) pin.name: pin};
      expect(byName['VIN']!.angle, 0);
      expect(byName['VIN']!.at.x, lessThan(0));
      expect(byName['VOUT']!.angle, 180);
      expect(byName['VOUT']!.at.x, greaterThan(0));
      expect(byName['GND']!.angle, 90);
      expect(byName['GND']!.at.y, lessThan(0));
    });

    test('a symbol reads back into the design it came from', () {
      final again = SymbolDesign.from(design.build());
      expect(again.name, 'LDO_3V3');
      expect(again.value, 'AMS1117-3.3');
      expect(
        [for (final p in again.pins) (p.number, p.name, p.side)],
        [for (final p in design.pins) (p.number, p.name, p.side)],
      );
    });
  });

  group('footprints', () {
    test('a DIP numbers down one side and back up the other', () {
      final pads = PadPatterns.dualRow(
        pins: 8,
        pitch: 2.54,
        rowSpacing: 7.62,
        padWidth: 1.6,
        padHeight: 1.6,
        throughHole: true,
      );
      PadDesign pad(String n) => pads.firstWhere((p) => p.number == n);
      expect(pad('1').x, -3.81);
      expect(pad('1').y, closeTo(-3.81, 1e-9));
      expect(pad('4').y, closeTo(3.81, 1e-9));
      expect(pad('5').x, 3.81);
      expect(pad('5').y, closeTo(3.81, 1e-9));
      expect(pad('8').y, closeTo(-3.81, 1e-9));
      expect(PadPatterns.pitchOf(pad('2'), pads), closeTo(2.54, 1e-9));
      expect(pad('1').shape, PadShape.rect);
    });

    test('a QFN goes counter-clockwise, and its exposed pad comes last', () {
      final pads = PadPatterns.quad(
        pinsPerSide: 4,
        pitch: 0.5,
        span: 3.8,
        padLength: 0.8,
        padWidth: 0.25,
        exposedPad: 2.5,
      );
      expect(pads, hasLength(17));
      expect(pads.first.x, -1.9);
      expect(pads[4].y, 1.9); // first of the bottom side
      expect(pads.last.number, '17');
      expect(pads.last.width, 2.5);
    });

    test('a header is on its pitch, pin 1 square', () {
      final pads = PadPatterns.header(pins: 6, pitch: 2.54, rows: 2);
      expect(pads[0].shape, PadShape.rect);
      expect(pads[1].x - pads[0].x, closeTo(2.54, 1e-9));
      expect(pads[2].y - pads[0].y, closeTo(2.54, 1e-9));
    });

    test('the file written is the footprint read back, to the micron', () {
      final design = FootprintDesign(
        name: 'SOIC-8_Test',
        description: 'Eight leads',
        pads: PadPatterns.dualRow(
          pins: 8,
          pitch: 1.27,
          rowSpacing: 5.4,
          padWidth: 1.55,
          padHeight: 0.6,
        ),
        bodyWidth: 3.9,
        bodyHeight: 4.9,
      );
      final written = design.build();
      final read = FootprintParser.parse(
        SExprParser.parseDocument(FootprintWriter.write(written)),
        'My_Footprints',
      );
      expect(read.name, 'SOIC-8_Test');
      expect(read.isSurfaceMount, isTrue);
      expect(read.pads, hasLength(8));
      for (var i = 0; i < 8; i++) {
        expect(read.pads[i].number, written.pads[i].number);
        expect(read.pads[i].at, written.pads[i].at);
        expect(read.pads[i].sizeX, written.pads[i].sizeX);
        expect(read.pads[i].sizeY, written.pads[i].sizeY);
        expect(read.pads[i].layers.toSet(), written.pads[i].layers.toSet());
      }
      // The courtyard clears the pads by its margin.
      final courtyard = read.graphics.whereType<FootprintRect>().firstWhere(
        (r) => r.layer == BoardLayer.frontCourtyard,
      );
      expect(courtyard.start.x, closeTo(-2.7 - 0.775 - 0.25, 0.011));
    });

    test('silkscreen never crosses a pad', () {
      final built = FootprintDesign(
        name: 'Tight',
        pads: PadPatterns.twoPad(
          centreDistance: 2,
          padWidth: 1,
          padHeight: 1.2,
        ),
        bodyWidth: 2,
        bodyHeight: 1,
      ).build();
      final silk = built.graphics.whereType<FootprintLine>().where(
        (l) => l.layer == BoardLayer.frontSilk,
      );
      for (final line in silk) {
        for (final pad in built.pads) {
          final box = Rect.fromCenter(
            center: Offset(pad.at.x, pad.at.y),
            width: pad.sizeX,
            height: pad.sizeY,
          );
          for (final t in [0.0, 0.5, 1.0]) {
            final p = Offset.lerp(
              Offset(line.start.x, line.start.y),
              Offset(line.end.x, line.end.y),
              t,
            )!;
            expect(box.contains(p), isFalse);
          }
        }
      }
    });
  });

  group('your own libraries', () {
    late AppDatabase db;
    late OwnLibraryStore store;
    late SymbolLibraryRepository symbols;
    late FootprintLibraryRepository footprints;

    setUp(() {
      db = AppDatabase.memory();
      symbols = SymbolLibraryRepository(db, InMemoryLibraryStorage());
      footprints = FootprintLibraryRepository(db, InMemoryLibraryStorage());
      store = OwnLibraryStore(symbols: symbols, footprints: footprints);
    });
    tearDown(() async => db.close());

    test('a saved symbol can be added to a design like any other', () async {
      await store.saveSymbol(
        const SymbolDesign(
          name: 'Sensor',
          pins: [PinDesign(number: '1', name: 'OUT')],
        ).build(),
      );
      await store.saveSymbol(
        const SymbolDesign(
          name: 'Relay',
          pins: [PinDesign(number: '1', name: 'COIL')],
        ).build(),
      );
      expect((await store.loadSymbols()).map((s) => s.name), [
        'Relay',
        'Sensor',
      ]);
      expect(await symbols.loadSymbol('My_Symbols:Sensor'), isNotNull);

      // Renamed, it replaces itself rather than leaving a copy behind.
      await store.saveSymbol(
        const SymbolDesign(
          name: 'Light_Sensor',
          pins: [PinDesign(number: '1', name: 'OUT')],
        ).build(),
        previousName: 'Sensor',
      );
      expect((await store.loadSymbols()).map((s) => s.name), [
        'Light_Sensor',
        'Relay',
      ]);

      await store.deleteSymbol('Relay');
      await store.deleteSymbol('Light_Sensor');
      expect(await store.loadSymbols(), isEmpty);
    });

    test('a saved footprint is found by the footprint search', () async {
      await store.saveFootprint(
        FootprintDesign(
          name: 'Pad_Pair',
          pads: PadPatterns.twoPad(
            centreDistance: 1.9,
            padWidth: 1,
            padHeight: 1.3,
          ),
        ).build(),
      );
      final found = await footprints.search('pad_pair');
      expect(found.single.libId, 'My_Footprints:Pad_Pair');
      final loaded = await footprints.loadFootprint('My_Footprints:Pad_Pair');
      expect(loaded!.pads.map((p) => p.at.x), [-0.95, 0.95]);
    });
  });
}
