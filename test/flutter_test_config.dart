import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:sqlite3/open.dart';

/// Runs once before every test in this directory.
///
/// On Android the app gets its SQLite from `sqlite3_flutter_libs`. Host test
/// runs use the system library instead, and many Linux distributions ship
/// only the versioned `libsqlite3.so.0` without the `-dev` symlink that
/// `package:sqlite3` looks for by default.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
  // A focused text field blinks its cursor forever, and pumpAndSettle waits
  // for animations to stop — so any test that types into a field would hang
  // until the 10-minute timeout. Deterministic cursors keep it still.
  EditableText.debugDeterministicCursor = true;

  await testMain();
}
