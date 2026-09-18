import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Writes a file somewhere the user chooses — Downloads, a Drive folder,
/// a USB stick — through the system's own save dialog.
///
/// The share sheet hands a file to an app; this puts it in a folder. On
/// Android that is the Storage Access Framework, which is the only way an
/// app may write outside its own storage without asking for blanket access
/// to every file on the phone.
abstract class FileSaver {
  /// Returns whether the file was saved; false if the user backed out.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

class PickerFileSaver implements FileSaver {
  const PickerFileSaver();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Save $fileName',
    );
    return uri != null;
  }
}

/// Overridden in tests, which cannot open a system dialog.
final fileSaverProvider = Provider<FileSaver>((ref) => const PickerFileSaver());
