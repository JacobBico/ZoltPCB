import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  /// Which project the recorded actions belong to. Undoing an edit against
  /// a different project would be nonsense, so opening another one starts
  /// a fresh history.
  String? _projectId;

  @override
  EditHistoryState build() => const EditHistoryState();

  void push(String projectId, EditAction action) {
    if (_projectId != projectId) {
      _projectId = projectId;
      state = const EditHistoryState();
    }
    state = EditHistoryState(
      past: [...state.past, action],
      future: const [],
    );
  }

  /// Reverses the most recent edit and returns its label.
  Future<String?> undo() async {
    if (state.past.isEmpty) return null;
    final action = state.past.last;
    state = EditHistoryState(
      past: state.past.sublist(0, state.past.length - 1),
      future: [...state.future, action],
    );
    await action.undo();
    return action.label;
  }

  /// Re-applies the most recently undone edit and returns its label.
  Future<String?> redo() async {
    if (state.future.isEmpty) return null;
    final action = state.future.last;
    state = EditHistoryState(
      past: [...state.past, action],
      future: state.future.sublist(0, state.future.length - 1),
    );
    await action.redo();
    return action.label;
  }

  void clear() => state = const EditHistoryState();
}
