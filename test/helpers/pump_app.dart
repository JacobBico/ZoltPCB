import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/appearance.dart';
import 'package:hintpcb/app/providers.dart';
import 'package:hintpcb/core/theme/app_theme.dart';
import 'package:hintpcb/data/db/database.dart';
import 'package:hintpcb/data/libraries/library_file_storage.dart';
import 'package:meta/meta.dart';

/// The viewport every widget test runs at: a landscape phone.
///
/// The app is landscape-locked and every screen is laid out for a wide,
/// short window, so testing at the default 800×600 would exercise a shape
/// the app never actually renders at.
const landscapePhone = Size(1600, 720);

/// A widget test with an in-memory database.
///
/// The database is closed inside the test body rather than in a `tearDown`.
/// Drift keeps a short-lived timer alive after a query stream is cancelled
/// so it can reuse its cache; `flutter_test` checks for pending timers as
/// soon as the body returns, which is before any `tearDown` runs. Unmounting
/// the tree, pumping once to let that timer fire, and only then closing is
/// what keeps the check happy.
@isTest
void testApp(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body, {
  bool? skip,
}) {
  testWidgets(description, skip: skip, (tester) async {
    final db = AppDatabase.memory();
    try {
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await db.close();
    }
  });
}

/// Pumps [child] inside the app's theme and provider scope.
///
/// [padding] simulates system insets — the status bar, a display cutout, the
/// gesture bar. Android draws apps edge-to-edge, so screens have to inset
/// themselves; passing a non-zero padding is how a test proves they do.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  required AppDatabase database,
  LibraryFileStorage? storage,
  LibraryFileStorage? footprintStorage,
  Size size = landscapePhone,
  double devicePixelRatio = 2,
  EdgeInsets padding = EdgeInsets.zero,

  /// The wiring model the schematic uses, for tests about one or the other.
  WiringModel wiring = WiringModel.polyline,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  final libraryStorage = storage ?? InMemoryLibraryStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        symbolStorageProvider.overrideWithValue(libraryStorage),
        // The board's footprint libraries get their own storage, so a test
        // that imports both cannot have one overwrite the other.
        footprintStorageProvider.overrideWithValue(
          footprintStorage ?? InMemoryLibraryStorage(),
        ),
        // Only constructed, never written to: a widget test runs under a
        // fake clock, where a real file write would never complete.
        exportDirectoryProvider.overrideWithValue(
          Directory('${Directory.systemTemp.path}/hintpcb_widget_exports'),
        ),
        appearanceProvider.overrideWith(() => _FixedAppearance(wiring)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: padding, viewPadding: padding),
          child: navigator!,
        ),
        home: child,
      ),
    ),
  );
  await settleApp(tester);
}

/// [WidgetTester.pumpAndSettle] with a short ceiling.
///
/// The default is ten minutes, so a widget that never stops animating hangs
/// the run instead of reporting anything useful. Eight seconds is far longer
/// than any real animation here.
Future<void> settleApp(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 8),
);

/// A widget test that also gets in-memory symbol library storage.
///
/// In-memory rather than a temporary directory because `testWidgets` runs
/// under a fake clock: a real `dart:io` future never completes inside one,
/// so a file-backed import would hang rather than fail.
@isTest
void testAppWithStorage(
  String description,
  Future<void> Function(
    WidgetTester tester,
    AppDatabase db,
    LibraryFileStorage storage,
  )
  body, {
  bool? skip,
}) {
  testWidgets(description, skip: skip, (tester) async {
    final db = AppDatabase.memory();
    final storage = InMemoryLibraryStorage();
    try {
      await body(tester, db, storage);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await db.close();
    }
  });
}

/// Opens the sliding section rail.
///
/// The rail is hidden until asked for, so any test that navigates between
/// sections has to open it first — exactly as a person would.
Future<void> openRail(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await settleApp(tester);
}

/// The appearance, with the wiring model a test asked for and no settings
/// to load: a widget test runs under a fake clock, where a database read on
/// the way to the first frame would never come back.
class _FixedAppearance extends AppearanceNotifier {
  _FixedAppearance(this.wiring);

  final WiringModel wiring;

  @override
  Appearance build() => Appearance(wiring: wiring);
}
