import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/app/edit_history.dart';

void main() {
  late ProviderContainer container;
  late List<String> log;

  EditAction action(String label) => EditAction(
    label: label,
    undo: () async => log.add('undo $label'),
    redo: () async => log.add('redo $label'),
  );

  setUp(() {
    container = ProviderContainer.test(
      overrides: [editTransactionProvider.overrideWithValue(<T>(step) => step())],
    );
    log = [];
  });

  EditHistory notifier() => container.read(editHistoryProvider.notifier);
  EditHistoryState state() => container.read(editHistoryProvider);

  test('starts with nothing to undo or redo', () {
    expect(state().canUndo, isFalse);
    expect(state().canRedo, isFalse);
    expect(state().undoLabel, isNull);
  });

  test('undo reverses the most recent edit', () async {
    notifier()
      ..push('p1', action('first'))
      ..push('p1', action('second'));

    expect(state().undoLabel, 'second');

    await notifier().undo();

    expect(log, ['undo second']);
    expect(state().undoLabel, 'first');
    expect(state().redoLabel, 'second');
  });

  test('redo puts it back', () async {
    notifier().push('p1', action('first'));

    await notifier().undo();
    await notifier().redo();

    expect(log, ['undo first', 'redo first']);
    expect(state().canUndo, isTrue);
    expect(state().canRedo, isFalse);
  });

  test('undoing twice walks back through the stack', () async {
    notifier()
      ..push('p1', action('a'))
      ..push('p1', action('b'));

    await notifier().undo();
    await notifier().undo();

    expect(log, ['undo b', 'undo a']);
    expect(state().canUndo, isFalse);
    expect(state().canRedo, isTrue);
  });

  test('a new edit after undoing discards the redo branch', () async {
    notifier().push('p1', action('a'));
    await notifier().undo();
    expect(state().canRedo, isTrue);

    notifier().push('p1', action('b'));

    expect(
      state().canRedo,
      isFalse,
      reason: 'redoing onto a changed document would not make sense',
    );
    expect(state().undoLabel, 'b');
  });

  test('undo and redo are no-ops when the stack is empty', () async {
    expect(await notifier().undo(), isNull);
    expect(await notifier().redo(), isNull);
    expect(log, isEmpty);
  });

  test('a step that fails is dropped, and the rest stays', () async {
    notifier()
      ..push('p1', action('a'))
      ..push(
        'p1',
        EditAction(
          label: 'broken',
          undo: () async => throw StateError('gone'),
          redo: () async {},
        ),
      );

    await expectLater(notifier().undo(), throwsStateError);
    expect(state().undoLabel, 'a');
    expect(state().canRedo, isFalse);

    await notifier().undo();
    expect(log, ['undo a']);
  });

  test('a second undo while one is running is ignored', () async {
    notifier()
      ..push('p1', action('a'))
      ..push('p1', action('b'));

    final first = notifier().undo();
    final second = notifier().undo();
    expect(await second, isNull);
    expect(await first, 'b');
    expect(log, ['undo b']);
    expect(state().undoLabel, 'a');
  });

  test('only the most recent edits are kept', () {
    for (var i = 0; i < EditHistory.limit + 5; i++) {
      notifier().push('p1', action('$i'));
    }
    expect(state().past, hasLength(EditHistory.limit));
    expect(state().undoLabel, '${EditHistory.limit + 4}');
  });

  test('opening a different project starts a fresh history', () {
    notifier().push('p1', action('a'));
    expect(state().canUndo, isTrue);

    notifier().push('p2', action('b'));

    expect(state().past, hasLength(1));
    expect(
      state().undoLabel,
      'b',
      reason: 'undoing an edit made in another project would be nonsense',
    );
  });
}
