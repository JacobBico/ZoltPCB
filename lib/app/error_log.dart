import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Errors the app ran into, kept in a file on the phone.
///
/// Nothing is sent anywhere — the app has no network in its core. The log is
/// there so a bug can be reported with what actually happened: most edits
/// are asynchronous database writes started from a tap, and an error in one
/// of those otherwise vanishes without a trace.
class ErrorLog {
  ErrorLog(File this.file);

  /// A log that keeps nothing, for tests and before start-up has found
  /// somewhere to write.
  ErrorLog.disabled() : file = null;

  final File? file;

  /// The file is cut back to its newer half once it passes this.
  static const maxBytes = 256 * 1024;

  /// Writes are chained so two errors in quick succession never interleave.
  Future<void> _pending = Future.value();

  bool get isEnabled => file != null;

  void record(Object error, StackTrace? stack, {String? context}) {
    final target = file;
    if (target == null) return;
    final when = DateTime.now().toIso8601String();
    final entry = StringBuffer('--- $when')
      ..write(context == null ? '' : ' ($context)')
      ..writeln()
      ..writeln(error)
      ..writeln(stack ?? '');
    // A log that cannot be written is not worth a second error.
    _pending = _pending
        .then((_) => _append(target, entry.toString()))
        .catchError((Object _) {});
  }

  static Future<void> _append(File target, String entry) async {
    await target.parent.create(recursive: true);
    if (await target.exists() && await target.length() > maxBytes) {
      final text = await target.readAsString();
      final keep = text.substring(text.length ~/ 2);
      final start = keep.indexOf('\n--- ');
      await target.writeAsString(start < 0 ? keep : keep.substring(start + 1));
    }
    await target.writeAsString(entry, mode: FileMode.append, flush: true);
  }

  /// Whether anything has been recorded.
  Future<bool> hasEntries() async {
    await _pending;
    final target = file;
    return target != null && await target.exists() && await target.length() > 0;
  }

  Future<void> clear() async {
    await _pending;
    final target = file;
    if (target != null && await target.exists()) await target.delete();
  }
}

/// The app's error log. Overridden at start-up with one that writes to the
/// application support directory.
final errorLogProvider = Provider<ErrorLog>((ref) => ErrorLog.disabled());
