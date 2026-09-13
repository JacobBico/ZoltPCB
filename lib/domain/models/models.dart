/// Pure Dart domain model for HintPCB.
///
/// Nothing in this layer knows about persistence, Flutter or KiCad file
/// syntax. The database maps to these types, and the exporter reads them —
/// which keeps the export layer testable without a database.
library;

export 'net.dart';
export 'part.dart';
export 'part_clone.dart';
export 'part_spec.dart';
export 'pin.dart';
export 'project.dart';
