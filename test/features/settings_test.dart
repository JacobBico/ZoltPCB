import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/app/appearance.dart';
import 'package:zolt/core/theme/kicad_palette.dart';
import 'package:zolt/data/repositories/settings_repository.dart';
import 'package:zolt/features/settings/settings_panel.dart';

import '../helpers/pump_app.dart';

void main() {
  tearDown(() => KicadPalette.current = AppPalettes.zolt);

  testApp('choosing a theme applies it and remembers it', (tester, db) async {
    await pumpApp(tester, const Scaffold(body: SettingsPanel()), database: db);

    expect(find.text('Halloween'), findsOneWidget);
    await tester.tap(find.text('Halloween'));
    await settleApp(tester);

    // In force immediately, for everything that paints with the palette.
    expect(KicadPalette.current, AppPalettes.halloween);

    // And saved, so it is the theme the app opens in next time.
    final saved = await SettingsRepository(
      db,
    ).get(SettingsRepository.paletteKey);
    expect(saved, 'halloween');
  });

  testApp('choosing the US resistor remembers it', (tester, db) async {
    await pumpApp(tester, const Scaffold(body: SettingsPanel()), database: db);

    // Below the theme grid on a landscape phone, as it is for a person.
    await tester.scrollUntilVisible(
      find.text('US'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('US'));
    await settleApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPanel)),
    );
    expect(
      container.read(appearanceProvider).resistorStyle,
      ResistorStyle.ansi,
    );
    expect(
      await SettingsRepository(db).get(SettingsRepository.resistorStyleKey),
      'ansi',
    );
  });

  testApp('a saved theme is what loads', (tester, db) async {
    await SettingsRepository(
      db,
    ).set(SettingsRepository.paletteKey, 'blueprint');

    await pumpApp(tester, const Scaffold(body: SettingsPanel()), database: db);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPanel)),
    );
    await container.read(appearanceProvider.notifier).load();
    await settleApp(tester);

    expect(container.read(appearanceProvider).palette, AppPalettes.blueprint);
    expect(KicadPalette.current, AppPalettes.blueprint);
  });

  testApp('every palette is offered', (tester, db) async {
    await pumpApp(tester, const Scaffold(body: SettingsPanel()), database: db);

    for (final palette in AppPalettes.all) {
      await tester.scrollUntilVisible(
        find.text(palette.name),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(palette.name), findsOneWidget, reason: palette.name);
    }
  });
}
