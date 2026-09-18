import 'dart:math' as math;
import 'dart:ui';

import '../core/util/ids.dart';
import '../domain/export/schematic_document.dart';
import '../domain/geometry/drawn_wire_geometry.dart';
import '../domain/geometry/net_routing.dart';
import '../domain/geometry/placement.dart';
import '../domain/models/models.dart';
import '../domain/symbols/symbols.dart';
import 'sexpr/sexpr.dart';
import 'sexpr/sexpr_writer.dart';
import 'symbol_writer.dart';

/// Writes `.kicad_sch` files.
///
/// ### How connectivity is expressed
///
/// Nets are the source of truth; wires are how they are drawn. Both go into
/// the file, and they are not equal partners:
///
///  * The wires are the ones the user arranged on the phone, routed by the
///    same code the canvas uses, so the file opens looking like the sheet
///    they drew rather than a bag of symbols with floating labels.
///  * A wire is only written when it cannot change the netlist. One that
///    runs across a foreign pin, or lies along another net's wire, would
///    join things the user never joined, so it is dropped.
///  * Labels are the fallback and the guarantee. A net whose pins are not
///    all reachable through the wires that survived gets a label on every
///    pin, exactly as before — which is why dropping a wire costs some
///    tidiness and never costs a connection.
///
/// The result opens in KiCad as a drawn schematic whose netlist is the
/// netlist the user built.
class SchematicWriter {
  const SchematicWriter({
    this.formatVersion = kicad9FormatVersion,
    this.writer = const SExprWriter(),
  });

  /// KiCad 9's schematic format. Version 10 opens these unchanged, so it is
  /// the widest target for a file leaving the phone.
  static const kicad9FormatVersion = 20250114;

  final int formatVersion;
  final SExprWriter writer;

  String write(SchematicDocument document) => writer.write(build(document));

  SList build(SchematicDocument document) {
    final project = document.project;
    final sheetUuid = project.id;
    final connectivity = _Connectivity.of(document);

    return SList([
      SAtom('kicad_sch'),
      S.of('version', [formatVersion]),
      SList([SAtom('generator'), S.text(document.generator)]),
      SList([SAtom('generator_version'), S.text(document.generatorVersion)]),
      SList([SAtom('uuid'), S.text(sheetUuid)]),
      SList([SAtom('paper'), S.text(project.paper.kicadName)]),
      _titleBlock(project),
      _libSymbols(document),
      ..._noConnects(document, connectivity),
      ..._wires(connectivity),
      ..._labels(document, connectivity),
      ..._notes(document),
      ..._symbols(document, sheetUuid),
      S.list('sheet_instances', [
        SList([
          SAtom('path'),
          S.text('/'),
          SList([SAtom('page'), S.text('1')]),
        ]),
      ]),
      S.flag('embedded_fonts', false),
    ]);
  }

  SList _titleBlock(Project project) => S.list('title_block', [
    SList([SAtom('title'), S.text(project.name)]),
    SList([SAtom('date'), S.text('')]),
    SList([SAtom('rev'), S.text(project.revision)]),
    SList([SAtom('company'), S.text(project.company)]),
  ]);

  SList _libSymbols(SchematicDocument document) {
    final entries = <SList>[];
    for (final libId in document.usedLibIds) {
      final symbol = document.symbols[libId] ?? _synthesise(document, libId);
      if (symbol == null) continue;
      entries.add(SymbolWriter.libSymbol(symbol, libId: libId));
    }
    return S.list('lib_symbols', entries);
  }

  SymbolDefinition? _synthesise(SchematicDocument document, String libId) {
    for (final part in document.parts) {
      if (part.part.libId == libId) {
        return SymbolWriter.fromPartSnapshot(part);
      }
    }
    return null;
  }

  // --- placed symbols --------------------------------------------------

  List<SList> _symbols(SchematicDocument document, String sheetUuid) {
    final result = <SList>[];
    for (final part in document.parts) {
      for (final unit in part.units) {
        if (!unit.placed) continue;
        result.add(_symbol(document, part, unit, sheetUuid));
      }
    }
    return result;
  }

  SList _symbol(
    SchematicDocument document,
    PartWithDetails part,
    PartUnit unit,
    String sheetUuid,
  ) {
    final placement = Placement.ofUnit(unit);
    final symbol = document.symbols[part.part.libId];
    final fieldAnchors = _fieldAnchors(symbol, unit, placement);

    return SList([
      SAtom('symbol'),
      SList([SAtom('lib_id'), S.text(part.part.libId)]),
      S.of('at', [unit.x, unit.y, unit.rotation]),
      if (unit.mirrorX) S.of('mirror', [SAtom('x')]),
      if (unit.mirrorY) S.of('mirror', [SAtom('y')]),
      S.of('unit', [unit.unitNumber]),
      S.of('body_style', [unit.bodyStyle]),
      S.flag('exclude_from_sim', false),
      S.flag('in_bom', part.part.inBom),
      S.flag('on_board', part.part.onBoard),
      S.flag('dnp', part.part.dnp),
      S.flag('fields_autoplaced', false),
      SList([SAtom('uuid'), S.text(unit.id)]),
      SymbolWriter.property(
        'Reference',
        part.part.reference,
        x: fieldAnchors.$1.dx,
        y: fieldAnchors.$1.dy,
        // Written from that point rightwards. Text is centred on its
        // position unless told otherwise, which puts half of it back over
        // the symbol however far to the side the point is.
        justify: 'left',
        // A power symbol's designator is bookkeeping — #PWR01 and the like
        // — and KiCad keeps it out of sight. Only its value, the name of
        // the supply, belongs on the drawing.
        hide: part.part.reference.startsWith('#'),
      ),
      SymbolWriter.property(
        'Value',
        part.part.value,
        x: fieldAnchors.$2.dx,
        y: fieldAnchors.$2.dy,
        justify: 'left',
      ),
      SymbolWriter.property(
        'Footprint',
        part.part.footprint,
        x: unit.x,
        y: unit.y,
        hide: true,
      ),
      SymbolWriter.property(
        'Datasheet',
        part.part.datasheet.isEmpty ? '~' : part.part.datasheet,
        x: unit.x,
        y: unit.y,
        hide: true,
      ),
      SymbolWriter.property(
        'Description',
        part.part.description,
        x: unit.x,
        y: unit.y,
        hide: true,
      ),
      ..._symbolPins(part, unit),
      S.list('instances', [
        SList([
          SAtom('project'),
          S.text(_projectToken(document.project.name)),
          SList([
            SAtom('path'),
            S.text('/$sheetUuid'),
            SList([SAtom('reference'), S.text(part.part.reference)]),
            S.of('unit', [unit.unitNumber]),
          ]),
        ]),
      ]),
    ]);
  }

  /// Pins of this unit, plus the package-wide ones.
  ///
  /// A pin marked unit 0 belongs to every unit but must appear exactly once
  /// in the file, so it is attached to the first unit. Connectivity is
  /// carried by labels rather than by position, so nothing is lost by
  /// anchoring it there.
  List<SList> _symbolPins(PartWithDetails part, PartUnit unit) {
    final isFirstUnit = unit.unitNumber == _lowestUnitNumber(part);
    return [
      for (final pin in part.pins)
        if (pin.unit == unit.unitNumber || (pin.unit == 0 && isFirstUnit))
          SList([
            SAtom('pin'),
            S.text(pin.number),
            SList([SAtom('uuid'), S.text(pin.id)]),
          ]),
    ];
  }

  static int _lowestUnitNumber(PartWithDetails part) {
    var lowest = 1 << 30;
    for (final unit in part.units) {
      if (unit.placed && unit.unitNumber < lowest) lowest = unit.unitNumber;
    }
    return lowest == 1 << 30 ? 1 : lowest;
  }

  /// Where the reference and value fields sit, in sheet millimetres.
  (Offset, Offset) _fieldAnchors(
    SymbolDefinition? symbol,
    PartUnit unit,
    Placement placement,
  ) {
    // Beside the body, one above the other — where a schematic puts them,
    // and where the app draws them. Above and below the symbol puts the
    // designator and the value in line with the wires leaving its pins.
    var beside = 2.54;
    if (symbol != null) {
      final bounds = symbolBounds(
        symbol,
        unit.unitNumber,
        bodyStyle: unit.bodyStyle,
        includePins: false,
      );
      if (bounds != Rect.zero) beside = bounds.right + 1.27;
    }
    return (placement.apply(beside, 1.27), placement.apply(beside, -1.27));
  }

  // --- connectivity ----------------------------------------------------

  List<SList> _labels(SchematicDocument document, _Connectivity connectivity) {
    final labels = <SList>[];

    for (final net in document.nets) {
      final name = net.displayName;
      final drawn = connectivity.spannedNetIds.contains(net.id);

      // A supply is named by the symbol sitting on it. Labelling it as well
      // says the same thing twice, and a label on a power net is not
      // something a schematic is ever drawn with.
      if (net.endpoints.any((e) => e.part.reference.startsWith('#PWR'))) {
        continue;
      }

      // A net the wires already join needs a label only to carry a name the
      // user chose. Labelling every pin of a wired net would bury the
      // drawing under text saying nothing the wires do not already say. A
      // named net in separate pieces — a bus label on two chips — gets one
      // label per piece, which is what joins them.
      final endpoints = drawn
          ? (net.net.isNamed ? net.endpoints.take(1) : const <NetEndpoint>[])
          : net.net.isNamed
          ? connectivity.onePerPiece(net)
          : net.endpoints;

      for (final endpoint in endpoints) {
        final at = connectivity.pinPositions[endpoint.pin.id];
        if (at == null) continue;
        labels.add(
          SList([
            SAtom('label'),
            S.text(name),
            S.of('at', [at.dx, at.dy, 0]),
            SymbolWriter.effects(justify: 'left bottom'),
            SList([SAtom('uuid'), S.text(endpoint.node.id)]),
          ]),
        );
      }
    }
    return labels;
  }

  /// Notes as KiCad's own sheet text, and boxes as dashed rectangles with
  /// their caption inside the top-left corner — how KiCad draws a note box.
  List<SList> _notes(SchematicDocument document) {
    final items = <SList>[];
    for (final note in document.notes) {
      final at = note.position;
      if (note.kind == NoteKind.box) {
        items.add(
          S.list('rectangle', [
            S.of('start', [at.dx, at.dy]),
            S.of('end', [at.dx + note.size.width, at.dy + note.size.height]),
            S.list('stroke', [
              S.of('width', [0]),
              S.of('type', [SAtom('dash')]),
            ]),
            S.list('fill', [
              S.of('type', [SAtom('none')]),
            ]),
            SList([SAtom('uuid'), S.text(note.id)]),
          ]),
        );
      }
      if (note.content.isEmpty) continue;
      final inset = note.kind == NoteKind.box
          ? Offset(note.textSize * 0.6, note.textSize * 0.5)
          : Offset.zero;
      items.add(
        SList([
          SAtom('text'),
          S.text(note.content),
          S.flag('exclude_from_sim', false),
          S.of('at', [at.dx + inset.dx, at.dy + inset.dy, 0]),
          SymbolWriter.effects(
            size: note.textSize,
            italic: note.kind == NoteKind.text,
            justify: 'left top',
          ),
          SList([SAtom('uuid'), S.text(derivedId('note-text:${note.id}'))]),
        ]),
      );
    }
    return items;
  }

  /// The drawn connections, as KiCad's two-point wire segments.
  List<SList> _wires(_Connectivity connectivity) {
    final items = <SList>[];
    for (final wire in connectivity.wires) {
      for (var i = 0; i < wire.points.length - 1; i++) {
        final a = wire.points[i];
        final b = wire.points[i + 1];
        items.add(
          S.list('wire', [
            S.list('pts', [
              S.of('xy', [a.dx, a.dy]),
              S.of('xy', [b.dx, b.dy]),
            ]),
            S.list('stroke', [
              S.of('width', [0]),
              S.of('type', [SAtom('default')]),
            ]),
            SList([SAtom('uuid'), S.text(derivedId('wire:${wire.key}:$i'))]),
          ]),
        );
      }
    }
    return items;
  }

  List<SList> _noConnects(
    SchematicDocument document,
    _Connectivity connectivity,
  ) {
    final connected = document.netByPin;

    final items = <SList>[];
    for (final part in document.parts) {
      for (final pin in part.pins) {
        if (!pin.noConnect || connected.containsKey(pin.id)) continue;
        final at = connectivity.pinPositions[pin.id];
        if (at == null) continue;
        items.add(
          S.list('no_connect', [
            S.of('at', [at.dx, at.dy]),
            SList([SAtom('uuid'), S.text(derivedId('no_connect:${pin.id}'))]),
          ]),
        );
      }
    }
    return items;
  }

  /// KiCad stores the project name in instance paths; it must match the
  /// `.kicad_pro` file's base name, so it gets the same treatment a file
  /// name would.
  static String _projectToken(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-. ]'), '');
    final collapsed = cleaned.replaceAll(RegExp(r'\s+'), '_');
    return collapsed.isEmpty ? 'hintpcb' : collapsed;
  }
}

/// Where every pin sits, and which wires may safely be drawn between them.
///
/// The canvas can draw a wire wherever it likes: a picture that clips a pin
/// is untidy and nothing more. A file cannot. KiCad reads geometry as
/// connectivity, so a wire touching a pin the user never joined is not an
/// untidy drawing, it is a different circuit. Everything here exists to make
/// that impossible, and to fall back on labels wherever it has to.
class _Connectivity {
  const _Connectivity({
    required this.pinPositions,
    required this.wires,
    required this.spannedNetIds,
  });

  factory _Connectivity.of(SchematicDocument document) {
    final positions = <String, Offset>{};
    final bodyEnds = <String, Offset>{};
    final obstacles = <Rect>[];

    for (final part in document.parts) {
      final firstUnit = SchematicWriter._lowestUnitNumber(part);
      for (final unit in part.units) {
        if (!unit.placed) continue;
        final placement = Placement.ofUnit(unit);
        final unitPoints = <Offset>[];

        for (final pin in part.pins) {
          final belongsHere =
              pin.unit == unit.unitNumber ||
              (pin.unit == 0 && unit.unitNumber == firstUnit);
          if (!belongsHere) continue;

          final at = placement.apply(pin.x, pin.y);
          final radians = pin.angle * math.pi / 180;
          final bodyEnd = placement.apply(
            pin.x + pin.length * math.cos(radians),
            pin.y + pin.length * math.sin(radians),
          );
          positions[pin.id] = at;
          bodyEnds[pin.id] = bodyEnd;
          unitPoints
            ..add(at)
            ..add(bodyEnd);
        }

        obstacles.add(
          unitBoundsOnSheet(
            symbol: document.symbols[part.part.libId],
            unitNumber: unit.unitNumber,
            bodyStyle: unit.bodyStyle,
            placement: placement,
            sheetPoints: unitPoints,
          ).deflate(0.2),
        );
      }
    }

    final netByPin = document.netByPin;
    final pinsByNet = <String, List<RoutablePin>>{};
    for (final net in document.nets) {
      final routable = <RoutablePin>[];
      final seen = <String>{};
      for (final endpoint in net.endpoints) {
        final at = positions[endpoint.pin.id];
        if (at == null || !seen.add(endpoint.pin.id)) continue;
        routable.add(
          RoutablePin.fromBodyEnd(
            id: endpoint.pin.id,
            position: at,
            bodyEnd: bodyEnds[endpoint.pin.id] ?? at,
          ),
        );
      }
      if (routable.length >= 2) pinsByNet[net.id] = routable;
    }

    final drawnByNet = <String, List<SchematicWire>>{};
    for (final wire in document.drawnWires) {
      (drawnByNet[wire.netId] ??= []).add(wire);
    }
    final labelledPins = {
      for (final net in document.nets)
        for (final e in net.endpoints)
          if (e.node.labelled) e.pin.id,
    };
    final routed = [
      for (final entry in pinsByNet.entries)
        ...NetRouting.routeNetWithDrawn(
          entry.key,
          entry.value,
          drawn: drawnByNet[entry.key] ?? const [],
          obstacles: obstacles,
          hints: document.routeHints,
          labelledPins: labelledPins,
        ),
    ];

    final safe = _dropUnsafe(routed, positions, netByPin);

    return _Connectivity(
      pinPositions: positions,
      wires: safe,
      spannedNetIds: _spannedNets(safe, pinsByNet),
    );
  }

  final Map<String, Offset> pinPositions;
  final List<RoutedWire> wires;

  /// One endpoint from each separately wired piece of [net].
  List<NetEndpoint> onePerPiece(NetWithEndpoints net) {
    final parent = <String, String>{};
    String find(String a) {
      var root = parent.putIfAbsent(a, () => a);
      while (parent[root] != root) {
        root = parent[root]!;
      }
      return root;
    }

    void union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    final netWires = [
      for (final w in wires)
        if (w.netId == net.id) w,
    ];
    for (var i = 0; i < netWires.length; i++) {
      final wire = netWires[i];
      if (wire.pinAId.isNotEmpty) union('w$i', wire.pinAId);
      if (wire.pinBId.isNotEmpty) union('w$i', wire.pinBId);
      for (final e in net.endpoints) {
        final at = pinPositions[e.pin.id];
        if (at == null) continue;
        if ((wire.points.first - at).distance < _touchMm ||
            (wire.points.last - at).distance < _touchMm) {
          union('w$i', e.pin.id);
        }
      }
      for (var j = 0; j < i; j++) {
        final other = netWires[j];
        for (final end in [wire.points.first, wire.points.last]) {
          final (_, d) = DrawnWireGeometry.nearestRun(other.points, end);
          if (d < _touchMm) union('w$i', 'w$j');
        }
        for (final end in [other.points.first, other.points.last]) {
          final (_, d) = DrawnWireGeometry.nearestRun(wire.points, end);
          if (d < _touchMm) union('w$i', 'w$j');
        }
      }
    }
    final seen = <String>{};
    return [
      for (final e in net.endpoints)
        if (seen.add(find(e.pin.id))) e,
    ];
  }

  /// Nets whose every pin is reachable through the wires that survived, and
  /// which therefore need no labels to hold themselves together.
  final Set<String> spannedNetIds;

  /// How close a point has to be to a segment to count as touching it, in
  /// millimetres. Well under the 1.27 mm grid, and far above the rounding
  /// noise of the placement transform.
  static const _touchMm = 0.01;

  /// Removes wires that would join something the user did not.
  static List<RoutedWire> _dropUnsafe(
    List<RoutedWire> wires,
    Map<String, Offset> positions,
    Map<String, NetWithEndpoints> netByPin,
  ) {
    final kept = <RoutedWire>[];

    for (final wire in wires) {
      // A wire that runs over a pin belonging to another net — or to no net
      // at all — connects to it the moment KiCad opens the file.
      var safe = true;
      for (final entry in positions.entries) {
        if (entry.key == wire.pinAId || entry.key == wire.pinBId) continue;
        if (netByPin[entry.key]?.id == wire.netId) continue;
        if (wire.distanceTo(entry.value) <= _touchMm) {
          safe = false;
          break;
        }
      }

      // Two wires of different nets that lie along each other merge, where
      // two that merely cross do not.
      if (safe) {
        for (final other in kept) {
          if (other.netId == wire.netId) continue;
          if (_overlaps(wire, other)) {
            safe = false;
            break;
          }
        }
      }

      if (safe) kept.add(wire);
    }
    return kept;
  }

  /// Whether any segment of [a] lies along any segment of [b] for a
  /// non-zero length.
  static bool _overlaps(RoutedWire a, RoutedWire b) {
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsOverlap(
          a.points[i],
          a.points[i + 1],
          b.points[j],
          b.points[j + 1],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentsOverlap(Offset a1, Offset a2, Offset b1, Offset b2) {
    bool spanOverlaps(double lo1, double hi1, double lo2, double hi2) =>
        math.min(hi1, hi2) - math.max(lo1, lo2) > _touchMm;

    final aVertical = (a1.dx - a2.dx).abs() <= _touchMm;
    final bVertical = (b1.dx - b2.dx).abs() <= _touchMm;
    final aHorizontal = (a1.dy - a2.dy).abs() <= _touchMm;
    final bHorizontal = (b1.dy - b2.dy).abs() <= _touchMm;

    if (aVertical && bVertical && (a1.dx - b1.dx).abs() <= _touchMm) {
      return spanOverlaps(
        math.min(a1.dy, a2.dy),
        math.max(a1.dy, a2.dy),
        math.min(b1.dy, b2.dy),
        math.max(b1.dy, b2.dy),
      );
    }
    if (aHorizontal && bHorizontal && (a1.dy - b1.dy).abs() <= _touchMm) {
      return spanOverlaps(
        math.min(a1.dx, a2.dx),
        math.max(a1.dx, a2.dx),
        math.min(b1.dx, b2.dx),
        math.max(b1.dx, b2.dx),
      );
    }
    return false;
  }

  /// Nets whose pins all end up in one piece once the surviving wires are
  /// taken into account.
  static Set<String> _spannedNets(
    List<RoutedWire> wires,
    Map<String, List<RoutablePin>> pinsByNet,
  ) {
    final joined = <String, List<Set<String>>>{};
    for (final wire in wires) {
      final groups = joined[wire.netId] ??= [];
      final a = groups.where((g) => g.contains(wire.pinAId)).firstOrNull;
      final b = groups.where((g) => g.contains(wire.pinBId)).firstOrNull;

      if (a == null && b == null) {
        groups.add({wire.pinAId, wire.pinBId});
      } else if (a == null) {
        b!.add(wire.pinAId);
      } else if (b == null) {
        a.add(wire.pinBId);
      } else if (!identical(a, b)) {
        a.addAll(b);
        groups.remove(b);
      }
    }

    final spanned = <String>{};
    for (final entry in pinsByNet.entries) {
      final groups = joined[entry.key];
      if (groups == null || groups.length != 1) continue;
      if (groups.single.length == entry.value.length) spanned.add(entry.key);
    }
    return spanned;
  }
}
