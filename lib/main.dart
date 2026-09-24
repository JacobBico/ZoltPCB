import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/appearance.dart';
import 'app/error_log.dart';
import 'app/providers.dart';
import 'data/libraries/library_file_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Landscape only. Schematics are wide, and every layout in the app is
  // designed for a short, wide viewport.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Full screen, the way a game is. A landscape phone is short, and the
  // schematic canvas wants every pixel. Sticky immersive brings the bars
  // back briefly on a swipe from an edge, then hides them again.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF131318),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Imported libraries live beside the database in application support,
  // which is private to the app and not swept by the media scanner.
  final support = await getApplicationSupportDirectory();
  final storage = FileLibraryStorage(
    Directory(p.join(support.path, 'symbols')),
  );
  final footprintStorage = FileLibraryStorage(
    Directory(p.join(support.path, 'footprints')),
  );
  await storage.ensureExists();
  await footprintStorage.ensureExists();

  // Exports go to the documents directory, which on Android is visible to
  // the share sheet and to a file manager.
  final documents = await getApplicationDocumentsDirectory();
  final exports = Directory(p.join(documents.path, 'exports'));

  // Everything that goes wrong is kept, on the phone, so a bug report can
  // say what happened. Flutter's own report still prints as before.
  final errorLog = ErrorLog(File(p.join(support.path, 'logs', 'errors.log')));
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    errorLog.record(details.exception, details.stack, context: details.library);
  };
  // Errors in futures nobody awaited — an edit started from a tap, say.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    errorLog.record(error, stack, context: 'uncaught');
    return true;
  };

  final container = ProviderContainer(
    overrides: [
      errorLogProvider.overrideWithValue(errorLog),
      symbolStorageProvider.overrideWithValue(storage),
      footprintStorageProvider.overrideWithValue(footprintStorage),
      exportDirectoryProvider.overrideWithValue(exports),
    ],
  );

  // The chosen theme is read before the first frame, so the app opens in
  // it rather than flashing the default on the way.
  await container.read(appearanceProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(container: container, child: const ZoltApp()),
  );
}
