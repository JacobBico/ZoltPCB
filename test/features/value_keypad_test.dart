import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/features/project/value_keypad.dart';

import '../helpers/pump_app.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, AppDatabase db) => pumpApp(
    tester,
    Scaffold(body: ValueKeypad(controller: controller)),
    database: db,
  );

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.widgetWithText(InkWell, key).first);
    await settleApp(tester);
  }

  testApp('digits type straight into the field', (tester, db) async {
    await pump(tester, db);
    for (final key in ['4', '7', '0']) {
      await press(tester, key);
    }
    expect(controller.text, '470');
  });

  testApp('a prefix takes the place of the decimal point', (tester, db) async {
    // 4.7 µF is written 4u7 on every schematic ever drawn, because a decimal
    // point is the first thing to vanish from a photocopy.
    await pump(tester, db);
    for (final key in ['4', '.', '7']) {
      await press(tester, key);
    }
    await press(tester, 'u');
    expect(controller.text, '4u7');
  });

  testApp('a prefix with no decimal point goes on the end', (tester, db) async {
    await pump(tester, db);
    for (final key in ['1', '0']) {
      await press(tester, key);
    }
    await press(tester, 'k');
    expect(controller.text, '10k');
  });

  testApp('a second prefix replaces the first rather than stacking', (
    tester,
    db,
  ) async {
    await pump(tester, db);
    for (final key in ['1', '0']) {
      await press(tester, key);
    }
    await press(tester, 'k');
    await press(tester, 'n');
    expect(controller.text, '10n');
  });

  testApp('changing the prefix of 4u7 keeps the digits either side', (
    tester,
    db,
  ) async {
    await pump(tester, db);
    controller.text = '4u7';
    await press(tester, 'n');
    expect(controller.text, '4n7');
  });

  testApp('backspace removes the last character', (tester, db) async {
    await pump(tester, db);
    controller.text = '100';
    await press(tester, '⌫');
    expect(controller.text, '10');
  });

  testApp('there are no unit symbols to get in the way', (tester, db) async {
    // A schematic writes 10k, not 10kΩ: the symbol already says which it
    // is. Leaving them out is also what lets the keypad fit on screen.
    await pump(tester, db);
    for (final unit in ['Ω', 'F', 'H', 'V', 'A']) {
      expect(find.text(unit), findsNothing);
    }
  });

  testApp('the whole keypad fits without scrolling', (tester, db) async {
    await pump(tester, db);
    // Every key reachable, on a landscape phone, without a scroll view.
    for (final key in ['7', '0', '⌫', 'p', 'G', 'CLR']) {
      expect(find.text(key), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testApp('CLR empties the field', (tester, db) async {
    await pump(tester, db);
    controller.text = '4u7';
    await press(tester, 'CLR');
    expect(controller.text, isEmpty);
  });
}
