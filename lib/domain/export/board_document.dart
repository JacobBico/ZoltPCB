import '../models/models.dart';
import '../pcb/pcb.dart';

/// Everything needed to write a board out, and nothing else.
///
/// The same contract [SchematicDocument] has: no database, no filesystem,
/// no Flutter, so the exported format can be tested against real KiCad from
/// a plain unit test.
class BoardDocument {
  const BoardDocument({
    required this.project,
    required this.scene,
    required this.nets,
    this.footprintSources = const {},
    this.generator = 'hintpcb',
    this.generatorVersion = '1.0',
  });

  final Project project;
  final BoardScene scene;
  final List<NetWithEndpoints> nets;

  /// The original `(footprint ...)` node of each library footprint used,
  /// keyed by `lib_id`, as raw s-expressions.
  ///
  /// The exporter places these rather than rebuilding them. A footprint
  /// carries far more than this app models — 3D models, custom pad
  /// primitives, keepout zones, solder-paste margins — and a board that
  /// dropped all of it on the way out would be a worse board than the one
  /// the user's own library describes.
  final Map<String, Object> footprintSources;

  final String generator;
  final String generatorVersion;

  Board get board => scene.board;

  /// Parts on the board whose footprint could not be found in any
  /// installed library, as `R3 (Lib:Name)`. The writer has nothing to
  /// place for these, so a file written anyway would be missing them.
  List<String> get missingFootprints => [
    for (final footprint in scene.footprints)
      if (footprintSources[footprint.ref.libId] == null)
        '${footprint.part.reference} (${footprint.ref.libId})',
  ]..sort();

  /// Nets that actually appear on the board, in a stable order.
  ///
  /// A schematic net with no placed pads is not written: KiCad would list it
  /// as an unconnected net that the board never mentions again.
  List<NetWithEndpoints> get boardNets {
    final used = <String>{
      for (final pad in scene.pads) ?pad.netId,
      for (final track in scene.tracks) ?track.netId,
      for (final via in scene.vias) ?via.netId,
    };
    return [
      for (final net in nets)
        if (used.contains(net.net.id)) net,
    ];
  }
}
