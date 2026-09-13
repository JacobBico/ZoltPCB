import 'dart:io';
import 'dart:typed_data';

/// Where imported library files live — `.kicad_sym` symbols and the
/// `.kicad_mod` footprints packed into a library container alike.
///
/// An interface rather than a concrete class so widget tests can supply an
/// in-memory implementation: `testWidgets` runs under a fake clock, and real
/// `dart:io` futures never complete inside one.
abstract interface class LibraryFileStorage {
  Future<void> ensureExists();

  Future<int> write(String fileName, Uint8List bytes);

  Future<Uint8List> readAll(String fileName);

  /// Reads just the bytes of one entry.
  ///
  /// This is what makes lazy loading worth doing: opening a single symbol or
  /// footprint touches a few kilobytes instead of decoding a multi-megabyte
  /// file.
  Future<Uint8List> readRange(String fileName, int start, int end);

  Future<void> delete(String fileName);

  bool exists(String fileName);
}

/// Library files on the device's filesystem. Symbols and footprints get
/// their own directory, so a nickname clash between the two is impossible.
class FileLibraryStorage implements LibraryFileStorage {
  FileLibraryStorage(this.root);

  final Directory root;

  File fileFor(String fileName) => File('${root.path}/$fileName');

  @override
  Future<void> ensureExists() async {
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
  }

  @override
  Future<int> write(String fileName, Uint8List bytes) async {
    await ensureExists();
    await fileFor(fileName).writeAsBytes(bytes, flush: true);
    return bytes.length;
  }

  @override
  Future<Uint8List> readAll(String fileName) => fileFor(fileName).readAsBytes();

  @override
  Future<Uint8List> readRange(String fileName, int start, int end) async {
    final handle = await fileFor(fileName).open();
    try {
      await handle.setPosition(start);
      return await handle.read(end - start);
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> delete(String fileName) async {
    final file = fileFor(fileName);
    if (file.existsSync()) await file.delete();
  }

  @override
  bool exists(String fileName) => fileFor(fileName).existsSync();
}

/// Library files held in memory. Used by tests.
class InMemoryLibraryStorage implements LibraryFileStorage {
  final _files = <String, Uint8List>{};

  @override
  Future<void> ensureExists() async {}

  @override
  Future<int> write(String fileName, Uint8List bytes) async {
    _files[fileName] = bytes;
    return bytes.length;
  }

  @override
  Future<Uint8List> readAll(String fileName) async {
    final bytes = _files[fileName];
    if (bytes == null) throw StateError('No such library: $fileName');
    return bytes;
  }

  @override
  Future<Uint8List> readRange(String fileName, int start, int end) async {
    final bytes = await readAll(fileName);
    return Uint8List.sublistView(bytes, start, end);
  }

  @override
  Future<void> delete(String fileName) async => _files.remove(fileName);

  @override
  bool exists(String fileName) => _files.containsKey(fileName);
}
