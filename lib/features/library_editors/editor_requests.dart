import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request for the symbol editor to open one of your symbols, by name.
///
/// My Library sets it and switches section; the editor takes it on its next
/// build and clears it, so coming back later does not reopen it again.
final symbolToEditProvider = NotifierProvider<EditRequest, String?>(
  EditRequest.new,
);

/// The same for the footprint editor.
final footprintToEditProvider = NotifierProvider<EditRequest, String?>(
  EditRequest.new,
);

class EditRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String? name) => state = name;
}
