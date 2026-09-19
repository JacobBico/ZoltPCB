import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether cross-probing is on: a small live view of the other half of the
/// project — the board while on the schematic, the schematic while on the
/// board — showing whatever is selected, as it is selected.
///
/// Kept for the session, not saved: it is a way of working on one task,
/// not a preference.
final crossProbeOnProvider = NotifierProvider<CrossProbeOn, bool>(
  CrossProbeOn.new,
);

class CrossProbeOn extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool on) => state = on;
}
