import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/features/components/component_browser_panel.dart';
import 'package:zolt/features/components/pinout_view.dart';
import 'package:zolt/features/home/home_screen.dart';
import 'package:zolt/features/libraries/libraries_panel.dart';
import 'package:zolt/domain/symbols/symbols.dart';

import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  testAppWithStorage(
    'the browser explains itself when no library is imported',
    (tester, db, storage) async {
      await pumpApp(
        tester,
        const Scaffold(body: ComponentBrowserPanel()),
        database: db,
        storage: storage,
      );

      expect(find.text('No components to search'), findsOneWidget);
    },
  );

  testAppWithStorage('search finds symbols by name, description and keywords', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());

    await pumpApp(
      tester,
      const Scaffold(body: ComponentBrowserPanel()),
      database: db,
      storage: storage,
    );

    expect(find.text('R'), findsOneWidget);
    expect(find.text('LM2904'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'opamp');
    await tester.pumpAndSettle();

    expect(find.text('LM2904'), findsOneWidget);
    expect(find.text('R'), findsNothing);
  });

  testAppWithStorage('selecting a component shows its pinout', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());

    await pumpApp(
      tester,
      const Scaffold(body: ComponentBrowserPanel()),
      database: db,
      storage: storage,
    );

    await tester.tap(find.text('LM2904'));
    await tester.pumpAndSettle();

    expect(find.text('Device:LM2904'), findsOneWidget);
    // Once in the result row, once in the detail header.
    expect(find.text('Dual Operational Amplifier'), findsNWidgets(2));

    // The first unit's pins are visible straight away.
    expect(find.text('+'), findsWidgets);
    expect(find.text('out'), findsOneWidget);

    // The supply pins live in unit 3, further down the same table.
    await tester.drag(find.byType(PinoutView), const Offset(0, -240));
    await settleApp(tester);
    expect(find.text('V+'), findsOneWidget);
    expect(find.text('V-'), findsOneWidget);
    expect(find.text('pwr_in'), findsNWidgets(2));
  });

  testAppWithStorage('a derived symbol shows its inherited pins', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());

    await pumpApp(
      tester,
      const Scaffold(body: ComponentBrowserPanel()),
      database: db,
      storage: storage,
    );

    await tester.tap(find.text('R_Small'));
    await tester.pumpAndSettle();

    expect(find.text('Device:R_Small'), findsOneWidget);
    expect(find.text('Resistor, small symbol'), findsNWidgets(2));
    expect(find.textContaining('extends'), findsOneWidget);
    expect(find.text('passive'), findsNWidgets(2));
  });

  testAppWithStorage('pick mode offers an add action per result', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());

    final picked = <SymbolIndexEntry>[];
    await pumpApp(
      tester,
      Scaffold(body: ComponentBrowserPanel(onAdd: picked.add)),
      database: db,
      storage: storage,
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(picked, hasLength(1));
    expect(picked.single.libraryNickname, 'Device');
  });

  testAppWithStorage('the libraries panel lists what has been imported', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());
    await repo.import(
      fileName: 'power.kicad_sym',
      bytes: libraryBytes(testPowerLibrarySource),
    );

    await pumpApp(
      tester,
      const Scaffold(body: LibrariesPanel()),
      database: db,
      storage: storage,
    );

    expect(find.text('Device'), findsOneWidget);
    expect(find.text('power'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // Device symbol count
    expect(find.text('2'), findsOneWidget); // power symbol count
    expect(find.text('20251024'), findsNWidgets(2));
  });

  testAppWithStorage('removing a library asks first, then removes it', (
    tester,
    db,
    storage,
  ) async {
    final repo = SymbolLibraryRepository(db, storage);
    await repo.import(fileName: 'Device.kicad_sym', bytes: libraryBytes());

    await pumpApp(
      tester,
      const Scaffold(body: LibrariesPanel()),
      database: db,
      storage: storage,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove "Device"?'), findsOneWidget);

    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();

    expect(await repo.getLibraries(), isEmpty);
    expect(find.text('No symbol libraries yet'), findsOneWidget);
  });

  testAppWithStorage('the home rail reaches every section', (
    tester,
    db,
    storage,
  ) async {
    await pumpApp(tester, const HomeScreen(), database: db, storage: storage);

    // A new install opens on Home, with its getting-started list.
    expect(find.textContaining('GET STARTED'), findsOneWidget);

    await openRail(tester);
    // The side menu's entry; the home page has a Projects tile too.
    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    await openRail(tester);
    // Further down the menu than a landscape phone shows at once.
    await tester.dragUntilVisible(
      find.text('Libraries'),
      find.text('Pinout'),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Libraries'));
    await tester.pumpAndSettle();
    expect(find.text('No symbol libraries yet'), findsOneWidget);
    expect(find.text('IMPORT LIBRARY'), findsWidgets);

    await openRail(tester);
    await tester.dragUntilVisible(
      find.text('Components'),
      find.text('Pinout'),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();
    expect(find.text('No components to search'), findsOneWidget);
  });
}
