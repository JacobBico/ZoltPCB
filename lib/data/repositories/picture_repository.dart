import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../domain/pcb/board_image.dart';
import '../db/database.dart';
import '../db/watchers.dart';

/// A picture in the library, ready to be put on a board.
class SilkPicture {
  const SilkPicture({
    required this.id,
    required this.name,
    required this.width,
    required this.columns,
    required this.rows,
    required this.bits,
    this.builtIn = false,
  });

  final String id;
  final String name;

  /// The width it is placed at, in millimetres.
  final double width;
  final int columns;
  final int rows;

  /// One bit a pixel; see [BoardImage.bits].
  final Uint8List bits;

  /// One of the app's own, which cannot be deleted.
  final bool builtIn;
}

/// The pictures saved for the silkscreen, kept on the phone for every
/// board.
class PictureRepository {
  PictureRepository(this._db);

  final AppDatabase _db;

  Future<List<SilkPicture>> getAll() async {
    final query = _db.select(_db.silkPictures)
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return [
      for (final row in await query.get())
        SilkPicture(
          id: row.id,
          name: row.name,
          width: row.width,
          columns: row.columns,
          rows: row.rows,
          bits: BoardImage.decodeBits(row.bits),
        ),
    ];
  }

  Stream<List<SilkPicture>> watchAll() =>
      _db.watchAggregate({_db.silkPictures}, getAll);

  Future<SilkPicture> add({
    required String name,
    required double width,
    required int columns,
    required int rows,
    required Uint8List bits,
  }) async {
    final picture = SilkPicture(
      id: newId(),
      name: name,
      width: width,
      columns: columns,
      rows: rows,
      bits: bits,
    );
    await _db
        .into(_db.silkPictures)
        .insert(
          SilkPicturesCompanion.insert(
            id: picture.id,
            name: name,
            width: width,
            columns: columns,
            rows: rows,
            bits: base64Encode(bits),
            createdAt: DateTime.now(),
          ),
        );
    return picture;
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.silkPictures)..where((t) => t.id.equals(id))).go();
  }
}
