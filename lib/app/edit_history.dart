import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// One reversible edit.
///
/// Both directions are closures rather than recorded data so each caller
/// decides what "the same edit again" means — re-connecting two pins, or
/// re-deleting a part it still has a snapshot of.
class EditAction {
  const EditAction({
    required this.label,
    required this.undo,
    required this.redo,
  });

  /// Shown to the user, e.g. `Delete R1`.
  final String label;
  final Future<void> Function() undo;
  final Future<void> Function() redo;
}

class EditHistoryState {
  const EditHistoryState({this.past = const [], this.future = const []});

  final List<EditAction> past;
  final List<EditAction> future;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  String? get undoLabel => past.isEmpty ? null : past.last.label;
  String? get redoLabel => future.isEmpty ? null : future.last.label;
}

/// Runs one undo or redo step as a single change to the design.
///
/// A step is often several writes — a net's wires put back, then its pins —
/// and in a transaction they land together or not at all: a step that fails
/// half way leaves nothing half-done, and the canvas redraws once for the
/// whole step rather than once per write.
final editTransactionProvider =
    Provider<Future<T> Function<T>(Future<T> Function() step)>((ref) {
      final db = ref.watch(databaseProvider);
      return <T>(step) => db.transaction(step);
    });

/// The undo stack for the project currently open.
///
/// Held here rather than in the canvas widget so it survives switching
/// between the schematic and the net list. A snackbar with an UNDO button
/// used to carry this job, but deleting and connecting happen often enough
/// that a popup after every one was worse than the problem it solved.
final editHistoryProvider = NotifierProvider<EditHistory, EditHistoryState>(
  EditHistory.new,
);

class EditHistory extends Notifier<EditHistoryState> {
  /// How many edits are kept. Each holds whatever it needs to put itself
  /// back, so an afternoon of edits must not be kept for ever.
  static const limit = 200;

  /// Which project the recorded actions belong to. Undoing an edit against
  /// a different project would be nonsense, so opening another one starts
  /// a fresh history.
  String? _projectId;

  /// Set while a step runs. A second tap on UNDO before the first has
  /// finished would otherwise take back the same edit twice.
  bool _running = false;

  @override
  EditHistoryState build() => const EditHistoryState();

  void push(String projectId, EditAction action) {
    if (_projectId != projectId) {
      _projectId = projectId;
      state = const EditHistoryState();
    }
    final past = [...state.past, action];
    state = EditHistoryState(
      past: past.length > limit ? past.sublist(past.length - limit) : past,
      future: const [],
    );
  }

  /// Reverses the most recent edit and returns its label, or null if there
  /// was nothing to undo or a step is already running.
  Future<String?> undo() => _step(backward: true);

  /// Re-applies the most recently undone edit and returns its label.
  Future<String?> redo() => _step(backward: false);

  /// Takes one step. The stack only moves once the step has worked. One
  /// that throws is dropped, since it would only fail again, and the error
  /// is passed on so the screen can say so; the rest of the history stays.
  Future<String?> _step({required bool backward}) async {
    if (_running) return null;
    final from = backward ? state.past : state.future;
    if (from.isEmpty) return null;
    final action = from.last;

    List<EditAction> without(List<EditAction> list) => [
      for (final other in list)
        if (!identical(other, action)) other,
    ];

    _running = true;
    try {
      await ref.read(editTransactionProvider)(
        backward ? action.undo : action.redo,
      );
    } catch (_) {
      state = EditHistoryState(
        past: without(state.past),
        future: without(state.future),
      );
      rethrow;
    } finally {
      _running = false;
    }

    state = backward
        ? EditHistoryState(
            past: without(state.past),
            future: [...state.future, action],
          )
        : EditHistoryState(
            past: [...state.past, action],
            future: without(state.future),
          );
    return action.label;
  }

  void clear() => state = const EditHistoryState();
}
