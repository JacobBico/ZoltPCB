import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/editors/own_library_store.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/features/library_editors/footprint_editor_panel.dart';
import 'package:hintpcb/features/library_editors/symbol_editor_panel.dart';

import '../helpers/pump_app.dart';

void main() {
  // "add two new sections where you can make symbols for components and
  // then another separate section to make footprints"
  testAppWithStorage('a symbol made here is saved to your own library', (
    tester,
    db,
    storage,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: SymbolEditorPanel()),
      database: db,
      storage: storage,
    );
    await settleApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name').first,
      'Light_Sensor',
    );
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    final store = OwnLibraryStore(
      symbols: SymbolLibraryRepository(db, storage),
      footprints: FootprintLibraryRepository(db, InMemoryLibraryStorage()),
    );
    final saved = await store.loadSymbols();
    expect(saved.single.name, 'Light_Sensor');
    expect(saved.single.pins.map((p) => p.name).toSet(), {'IN', 'OUT'});
  });

  testAppWithStorage('a footprint is generated to exact numbers and saved', (
    tester,
    db,
    storage,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: FootprintEditorPanel()),
      database: db,
      storage: storage,
      footprintStorage: InMemoryLibraryStorage(),
    );
    await settleApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'SOIC-8_Mine',
    );
    await tester.tap(find.text('Generate'));
    await settleApp(tester);
    // Dual row is the default pattern: 8 pins, 1.27 pitch, 5.4 spacing.
    await tester.tap(find.text('REPLACE PADS'));
    await settleApp(tester);
    // The readout states what was laid, pad 1 selected.
    expect(find.textContaining('pitch 1.270'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await settleApp(tester);

    expect(find.textContaining('My_Footprints:SOIC-8_Mine'), findsOneWidget);
  });
}
