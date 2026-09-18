import '../models/models.dart';
import '../symbols/symbols.dart';

/// Everything needed to write a schematic out, and nothing else.
///
/// The export layer takes one of these and produces text. It never touches
/// the database, the filesystem or Flutter, which is what lets the exported
/// format be tested against real KiCad from a plain unit test.
class SchematicDocument {
  const SchematicDocument({
    required this.project,
    required this.parts,
    required this.nets,
    this.symbols = const {},
    this.routeHints = const {},
    this.drawnWires = const [],
    this.notes = const [],
    this.generator = 'hintpcb',
    this.generatorVersion = '1.0',
  });

  final Project project;
  final List<PartWithDetails> parts;
  final List<NetWithEndpoints> nets;

  /// Library definitions by `lib_id`. A missing one is not fatal: the writer
  /// synthesises a pins-only symbol from the part's own snapshot, so a
  /// design still exports after its library has been removed.
  final Map<String, SymbolDefinition> symbols;

  /// The adjustments the user made to drawn wire routes, keyed by pin pair.
  ///
  /// Carried through to the export so the wires in the file are the wires
  /// the user arranged on the phone, rather than a fresh automatic route
  /// that would undo their tidying at the moment it leaves the device.
  final Map<String, List<double>> routeHints;

  /// The wires as the user drew them, written exactly as drawn.
  final List<SchematicWire> drawnWires;

  /// Text and boxes on the sheet.
  final List<SchematicNote> notes;

  final String generator;
  final String generatorVersion;

  /// The net a given pin belongs to, keyed by pin id.
  Map<String, NetWithEndpoints> get netByPin => {
    for (final net in nets)
      for (final endpoint in net.endpoints) endpoint.pin.id: net,
  };

  /// Distinct `lib_id`s used, in a stable order.
  List<String> get usedLibIds =>
      parts.map((p) => p.part.libId).toSet().toList()..sort();

  int get placedUnitCount =>
      parts.fold(0, (n, p) => n + p.units.where((u) => u.placed).length);
}
