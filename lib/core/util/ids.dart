import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a v4 UUID.
///
/// Every persisted entity carries one. KiCad requires a UUID on every
/// schematic element, so allocating them at creation time — rather than at
/// export time — keeps identity stable across exports.
String newId() => _uuid.v4();

/// A UUID derived deterministically from [seed].
///
/// Exported schematic elements that have no natural identity of their own —
/// a net label, a no-connect marker — still need a UUID, and re-exporting a
/// design should produce the same file rather than a diff of fresh random
/// values. Hashing the thing the element belongs to gives both.
String derivedId(String seed) {
  // A 128-bit FNV-1a variant: four independent 32-bit hashes over the seed
  // with different offset bases, laid out as a UUID.
  const prime = 0x01000193;
  final words = <int>[];
  for (final base in [0x811c9dc5, 0x01234567, 0x89abcdef, 0xfedcba98]) {
    var hash = base;
    for (final unit in seed.codeUnits) {
      hash = (hash ^ unit) & 0xffffffff;
      hash = (hash * prime) & 0xffffffff;
    }
    words.add(hash);
  }

  String hex(int value, int digits) =>
      value.toRadixString(16).padLeft(digits, '0').substring(0, digits);

  final a = hex(words[0], 8);
  final b = hex(words[1] >> 16, 4);
  // Version 4 and the RFC variant bits, so the result is a well-formed UUID.
  final c = '4${hex(words[1] & 0xffff, 4).substring(1)}';
  final d =
      '${(8 + (words[2] >> 30)).toRadixString(16)}'
      '${hex(words[2] & 0xffffff, 6).substring(0, 3)}';
  final e = '${hex(words[2], 8).substring(2)}${hex(words[3], 8).substring(2)}';

  return '$a-$b-$c-$d-${e.padRight(12, '0').substring(0, 12)}';
}
