import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/editors/own_library_store.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/domain/editors/footprint_design.dart';
import 'package:hintpcb/domain/editors/symbol_design.dart';
import 'package:hintpcb/features/library_editors/my_library_panel.dart';

import '../helpers/pump_app.dart';

void main() {
  // "select the symbol and MATCH it to a selected footprint ... if the
  // package is sot-23, I should be able to choose that package"
  testAppWithStorage('a symbol is matched to a footprint from My Library', (
    tester,
    db,
    storage,
  ) async {
    final footprintStorage = InMemoryLibraryStorage();
    final store = OwnLibraryStore(
      symbols: SymbolLibraryRepository(db, storage),
      footprints: FootprintLibraryRepository(db, footprintStorage),
    );
    await store.saveSymbol(
      const SymbolDesign(
        name: 'Regulator',
        pins: [
          PinDesign(number: '1', name: 'GND'),
          PinDesign(number: '2', name: 'OUT', side: PinSide.right),
          PinDesign(number: '3', name: 'IN'),
        ],
      ).build(),
    );
    await store.saveFootprint(
      FootprintDesign(
        name: 'SOT-23_Mine',
        pads: const [
          PadDesign(number: '1', x: -0.95, y: 1),
          PadDesign(number: '2', x: 0.95, y: 1),
          PadDesign(number: '3', y: -1),
        ],
      ).build(),
    );

    await pumpApp(
      tester,
      const Scaffold(body: MyLibraryPanel()),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );
    await settleApp(tester);

    expect(find.text('Regulator'), findsOneWidget);
    expect(find.textContaining('no footprint matched'), findsOneWidget);

    await tester.tap(find.text('MATCH'));
    await settleApp(tester);
    await tester.tap(find.text('SOT-23_Mine'));
    await settleApp(tester);
    expect(find.text('Every pin has its pad'), findsOneWidget);
    await tester.tap(find.text('USE'));
    await settleApp(tester);

    expect(find.textContaining('My_Footprints:SOT-23_Mine'), findsOneWidget);
    final saved = await store.loadSymbols();
    expect(saved.single.footprint, 'My_Footprints:SOT-23_Mine');

    // Both halves listed, and the footprint knows who uses it.
    await tester.tap(find.textContaining('My Footprints'));
    await settleApp(tester);
    expect(find.textContaining('used by Regulator'), findsOneWidget);
  });
}
