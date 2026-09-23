import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/error_log.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('hintpcb_log'));
  tearDown(() => dir.delete(recursive: true));

  test('records errors with their stack, and clears', () async {
    final log = ErrorLog(File('${dir.path}/logs/errors.log'));
    expect(await log.hasEntries(), isFalse);

    log.record(StateError('boom'), StackTrace.current, context: 'undo');
    expect(await log.hasEntries(), isTrue);
    final text = await log.file!.readAsString();
    expect(text, contains('(undo)'));
    expect(text, contains('boom'));

    await log.clear();
    expect(await log.hasEntries(), isFalse);
  });

  test('never grows past its limit', () async {
    final log = ErrorLog(File('${dir.path}/errors.log'));
    final big = 'x' * 4000;
    for (var i = 0; i < 200; i++) {
      log.record('$i $big', null);
    }
    await log.hasEntries();
    final length = await log.file!.length();
    expect(length, lessThan(ErrorLog.maxBytes + 10000));
    // The newest entry survives the cut.
    expect(await log.file!.readAsString(), contains('199 '));
  });

  test('a disabled log keeps nothing', () async {
    final log = ErrorLog.disabled();
    log.record('ignored', null);
    expect(await log.hasEntries(), isFalse);
  });
}
