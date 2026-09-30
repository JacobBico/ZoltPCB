import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/app/app.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/settings_repository.dart';

import '../helpers/pump_app.dart';

void main() {
  const welcome = ValueKey('welcome-dialog');

  testApp('a new user is welcomed once, the first time the app opens', (
    tester,
    db,
  ) async {
    await pumpApp(tester, const ZoltApp(), database: db);
    await settleApp(tester);
    expect(find.byKey(welcome), findsOneWidget);
    expect(find.text('Welcome to Zolt!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-start')));
    await settleApp(tester);
    expect(find.byKey(welcome), findsNothing);
    expect(
      await SettingsRepository(db).get(SettingsRepository.welcomedKey),
      isNotNull,
    );

    // Opened again: no second hello.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, const ZoltApp(), database: db);
    await settleApp(tester);
    expect(find.byKey(welcome), findsNothing);
  });

  testApp('someone who already has designs is not greeted as new', (
    tester,
    db,
  ) async {
    await ProjectRepository(db).create(name: 'Already here');
    await pumpApp(tester, const ZoltApp(), database: db);
    await settleApp(tester);
    expect(find.byKey(welcome), findsNothing);
    expect(
      await SettingsRepository(db).get(SettingsRepository.welcomedKey),
      isNotNull,
    );
  });
}
