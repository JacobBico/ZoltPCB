/// Pure Dart domain model for Zolt.
///
/// Nothing in this layer knows about persistence, Flutter or KiCad file
/// syntax. The database maps to these types, and the exporter reads them —
/// which keeps the export layer testable without a database.
library;

export 'circuit_clip.dart';
export 'circuit_clip_json.dart';
export 'net.dart';
export 'part.dart';
export 'part_clone.dart';
export 'part_spec.dart';
export 'pin.dart';
export 'project.dart';
export 'schematic_note.dart';
export 'schematic_sheet.dart';
export 'sheet_connections.dart';
export 'sheet_views.dart';
export 'schematic_wire.dart';
export 'label_pattern.dart';
