import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui';

import '../../domain/geometry/placement.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart';
import '../../fab/silk_fonts.dart';
import '../../kicad/schematic_writer.dart';
import '../../kicad/board_writer.dart';
import '../../kicad/board_project_writer.dart';
import '../../kicad/sexpr/sexpr.dart';
import '../../kicad/sexpr/sexpr_parser.dart';
import '../../kicad/sexpr/sexpr_writer.dart';
import '../../kicad/symbol_parser.dart';
import '../repositories/board_repository.dart';
import '../repositories/footprint_library_repository.dart';
import '../repositories/net_repository.dart';
import '../repositories/part_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/sheet_repository.dart';
import '../repositories/symbol_library_repository.dart';

class KicadImportException implements Exception {
  const KicadImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KicadImportResult {
  const KicadImportResult({
    required this.project,
    required this.warnings,
    required this.partCount,
    required this.netCount,
    required this.footprintCount,
    required this.trackCount,
  });

  final Project project;
  final List<String> warnings;
  final int partCount;
  final int netCount;
  final int footprintCount;
  final int trackCount;
}

/// Opens a KiCad project made on a desktop.
///
/// The schematic brings the parts, where they sit, and what is connected to
/// what — worked out from the wires, junctions, labels and power symbols the
/// same way KiCad works it out. The board, when there is one, brings the
/// placement, the copper, the pours, the outline and the rules.
///
/// The symbols and footprints a project carries inside itself are the
/// user's own, from their own files. Where the user has not imported that
/// library, the parts the project uses are added as a library so the
/// design draws; where they have, their library is left exactly as it was.
class KicadProjectImporter {
  KicadProjectImporter({
    required this.projects,
    required this.parts,
    required this.nets,
    required this.boards,
    required this.symbols,
    required this.footprints,
    this.sheets,
  });

  /// Where sub-sheets go. Without it, only the top sheet is brought in.
  final SheetRepository? sheets;

  final ProjectRepository projects;
  final PartRepository parts;
  final NetRepository nets;
  final BoardRepository boards;
  final SymbolLibraryRepository symbols;
  final FootprintLibraryRepository footprints;

  /// How close two points must be to be the same point, in millimetres.
  static const _near = 0.01;

  Future<KicadImportResult> import({
    required String name,
    required String schematic,
    String? board,
    String? projectFile,

    /// The project's other `.kicad_sch` files, by file name: the sheets
    /// the top one refers to.
    Map<String, String> sheetFiles = const {},
  }) async {
    final SList root;
    try {
      root = SExprParser.parseDocument(schematic);
    } catch (error) {
      throw KicadImportException('Not a readable schematic: $error');
    }
    if (root.head != 'kicad_sch') {
      throw const KicadImportException('That is not a KiCad schematic');
    }

    final titleBlock = root.child('title_block');

    // One transaction: anything that goes wrong takes the whole project
    // away again, so a failed import never leaves half a design behind, and
    // the project list never shows one half made.
    return projects.transaction(() async {
      final project = await projects.create(
        name: name,
        paper: PaperSize.fromKicadName(root.childAtom('paper') ?? 'A4'),
        company: titleBlock?.childAtom('company') ?? '',
        revision: titleBlock?.childAtom('rev') ?? '',
      );
      return _importInto(project, root, board, projectFile, sheetFiles);
    });
  }

  Future<KicadImportResult> _importInto(
    Project project,
    SList root,
    String? board,
    String? projectFile,
    Map<String, String> sheetFiles,
  ) async {
    final warnings = <String>[];
    if (sheets == null && root.children('sheet').isNotEmpty) {
      warnings.add(
        'This schematic has sub-sheets; only the top sheet was brought in',
      );
    }

    final links = _SheetLinks();
    final partCount = await _importSheet(
      project,
      root,
      sheetId: null,
      instancePath: '/${root.childAtom('uuid') ?? ''}',
      pathName: '/',
      files: sheetFiles,
      opened: const {},
      links: links,
      warnings: warnings,
    );
    await _nameLinkedNets(project, links);
    await _givePinsTheirNets(project, links);
    final netCount = (await nets.getNets(project.id)).length;

    var footprintCount = 0;
    var trackCount = 0;
    if (board != null) {
      (footprintCount, trackCount) = await _importBoard(
        project,
        board,
        projectFile,
        warnings,
      );
    }

    return KicadImportResult(
      project: project,
      warnings: warnings,
      partCount: partCount,
      netCount: netCount,
      footprintCount: footprintCount,
      trackCount: trackCount,
    );
  }

  // --- sheets ----------------------------------------------------------

  /// One sheet's file: its symbols, its parts, the boxes of the sheets on
  /// it, what it connects, and then each of those sheets in turn.
  Future<int> _importSheet(
    Project project,
    SList file, {
    required String? sheetId,
    required String instancePath,
    required String pathName,
    required Map<String, String> files,
    required Set<String> opened,
    required _SheetLinks links,
    required List<String> warnings,
  }) async {
    final definitions = await _installSymbols(file, warnings);
    var count = await _placeParts(
      project,
      file,
      definitions,
      warnings,
      sheetId: sheetId,
      instancePath: instancePath,
    );

    final children = <(String, SList, String, String)>[];
    final pinPoints = <(String, Offset)>[];
    final repository = sheets;
    if (repository != null) {
      for (final node in file.children('sheet')) {
        String property(String key) =>
            node
                .children('property')
                .where((p) => p.atom(1) == key)
                .firstOrNull
                ?.atom(2) ??
            '';
        final name = property('Sheetname').isEmpty
            ? 'Sheet'
            : property('Sheetname');
        final fileName = property('Sheetfile');
        final at = node.child('at');
        final size = node.child('size');
        final added = await repository.add(
          projectId: project.id,
          name: name,
          parentId: sheetId,
          at: Offset(at?.number(1) ?? 0, at?.number(2) ?? 0),
        );
        final box = Rect.fromLTWH(
          at?.number(1) ?? 0,
          at?.number(2) ?? 0,
          size?.number(1) ?? 30.48,
          size?.number(2) ?? 20.32,
        );
        // The box keeps its pins where they were drawn, whether or not the
        // sheet's own file comes in: they are what the wires here end on.
        final boxPins = [
          for (final pin in node.children('pin'))
            if (pin.atom(1) case final pinName?)
              SheetPin.onEdge(
                name: _unescape(pinName),
                box: box,
                point: _at(pin),
                shape: pin.atom(2) ?? 'bidirectional',
              ),
        ];
        final placed = added.copyWith(
          fileName: fileName.isEmpty ? added.fileName : fileName,
          box: box,
          pins: boxPins,
        );
        await repository.update(placed);
        links.boxes[added.id] = placed;
        links.pathOf[added.id] = '$pathName$name/';
        // Each pin of the box is joined, by a name only the import uses,
        // to the hierarchical label of the same name inside the sheet.
        for (final pin in node.children('pin')) {
          final pinName = pin.atom(1);
          if (pinName == null) continue;
          pinPoints.add((links.key(added.id, _unescape(pinName)), _at(pin)));
        }
        children.add((
          added.id,
          node,
          fileName,
          '$instancePath/${node.childAtom('uuid') ?? ''}',
        ));
      }
    }

    await _connect(
      project,
      file,
      sheetId: sheetId,
      pathName: pathName,
      extraLabels: pinPoints,
      links: links,
    );

    for (final (childId, _, fileName, childPath) in children) {
      // A sheet in a folder of its own (`sch/power.kicad_sch`) is picked as
      // plain `power.kicad_sch`.
      final text = files[fileName] ?? files[fileName.split('/').last];
      if (text == null) {
        warnings.add(
          '$fileName was not picked, so the sheet ${links.pathOf[childId]} '
          'is empty — pick it with the other files to bring it in',
        );
        continue;
      }
      if (opened.contains(fileName)) {
        warnings.add('$fileName contains itself; the loop was not followed');
        continue;
      }
      if (links.used.contains(fileName)) {
        warnings.add(
          '$fileName is used more than once; each use came in as its own '
          'copy of the sheet',
        );
      }
      links.used.add(fileName);
      final SList child;
      try {
        child = SExprParser.parseDocument(text);
      } catch (error) {
        warnings.add('$fileName could not be read: $error');
        continue;
      }
      count += await _importSheet(
        project,
        child,
        sheetId: childId,
        instancePath: childPath,
        pathName: links.pathOf[childId]!,
        files: files,
        opened: {...opened, fileName},
        links: links,
        warnings: warnings,
      );
    }
    return count;
  }

  /// The names the import joined sheets by, replaced by real ones: the
  /// name a label gave the net where it had one, or KiCad's own, the
  /// sheet's path and the pin — `/Power/VIN`.
  Future<void> _nameLinkedNets(Project project, _SheetLinks links) async {
    // KiCad's own name for a net nobody named — `Net-(R2-Pad2)` — is a
    // placeholder, and a net that had one comes in unnamed, as it began.
    final placeholder = RegExp(r'(^|/)Net-\(');
    for (final net in await nets.getNets(project.id)) {
      final name = net.net.name;
      if (name == null) continue;
      var wanted = name;
      if (name.startsWith(_SheetLinks.marker)) {
        links.netOf[name] = net.net.id;
        final (sheetId, pin) = links.parse(name);
        wanted = links.preferred[name] ?? '${links.pathOf[sheetId] ?? '/'}$pin';
      }
      if (placeholder.hasMatch(wanted)) {
        await nets.renameNet(net.net.id, null);
      } else if (wanted != name) {
        await nets.renameNet(net.net.id, wanted);
      }
    }
  }

  /// Each box's pins, told which net they carry: the one their joining
  /// name ended up on, however it was renamed after.
  Future<void> _givePinsTheirNets(Project project, _SheetLinks links) async {
    final repository = sheets;
    if (repository == null) return;
    final byName = {
      for (final net in await nets.getNets(project.id))
        ?net.net.name: net.net.id,
    };
    for (final sheet in links.boxes.values) {
      if (sheet.pins.isEmpty) continue;
      String? netOf(SheetPin pin) {
        final key = links.resolve(links.key(sheet.id, pin.name));
        // Named by its joining name until renamed, or by a label on it
        // that it was given instead.
        return links.netOf[key] ??
            switch (links.preferred[key]) {
              final name? => byName[name],
              null => null,
            };
      }

      await repository.update(
        sheet.copyWith(
          pins: [for (final pin in sheet.pins) pin.withNet(netOf(pin))],
        ),
      );
    }
  }

  // --- symbols ---------------------------------------------------------

  /// The definitions embedded in the schematic, keyed by `lib_id`, with any
  /// library the user does not already have added from them.
  Future<Map<String, SymbolDefinition>> _installSymbols(
    SList root,
    List<String> warnings,
  ) async {
    final byLibrary = <String, List<SList>>{};
    final definitions = <String, SymbolDefinition>{};

    for (final node
        in root.child('lib_symbols')?.children('symbol') ?? const <SList>[]) {
      final libId = node.atom(1);
      if (libId == null) continue;
      final colon = libId.indexOf(':');
      final nickname = colon < 0 ? 'Imported' : libId.substring(0, colon);
      final symbolName = colon < 0 ? libId : libId.substring(colon + 1);

      // In a library the symbol is named without its library.
      final renamed = SList([
        SAtom('symbol'),
        S.text(symbolName),
        ...node.items.skip(2),
      ]);
      try {
        definitions[libId] = SymbolParser.parseSymbol(renamed, nickname);
        (byLibrary[nickname] ??= []).add(renamed);
      } catch (error) {
        warnings.add('Could not read the symbol $libId: $error');
      }
    }

    final installed = {
      for (final library in await symbols.getLibraries()) library.nickname,
    };
    for (final entry in byLibrary.entries) {
      if (installed.contains(entry.key)) continue;
      final library = SList([
        SAtom('kicad_symbol_lib'),
        S.of('version', [20241209]),
        SList([SAtom('generator'), S.text('zolt')]),
        ...entry.value,
      ]);
      try {
        await symbols.import(
          fileName: '${entry.key}.kicad_sym',
          bytes: utf8.encode(const SExprWriter().write(library)),
        );
      } catch (error) {
        warnings.add('Could not add the ${entry.key} symbols: $error');
      }
    }
    return definitions;
  }

  // --- parts -----------------------------------------------------------

  Future<int> _placeParts(
    Project project,
    SList root,
    Map<String, SymbolDefinition> definitions,
    List<String> warnings, {
    String? sheetId,
    String? instancePath,
  }) async {
    final groups = <String, List<_Instance>>{};
    var unnumbered = 0;
    for (final node in root.children('symbol')) {
      final libId = node.childAtom('lib_id');
      if (libId == null) continue;
      final at = node.child('at');
      final properties = <String, String>{
        for (final property in node.children('property'))
          if (property.atom(1) != null)
            property.atom(1)!: property.atom(2) ?? '',
      };
      // A sheet used twice gives its parts a reference per use; the one
      // for this use is the path through the boxes to it.
      final paths =
          node.child('instances')?.child('project')?.children('path') ??
          const <SList>[];
      final instanceReference =
          (paths.where((p) => p.atom(1) == instancePath).firstOrNull ??
                  paths.firstOrNull)
              ?.childAtom('reference');
      final reference = instanceReference ?? properties['Reference'] ?? '?';
      final instance = _Instance(
        libId: libId,
        at: Offset(at?.number(1) ?? 0, at?.number(2) ?? 0),
        rotation: at?.number(3) ?? 0,
        unit: node.childInteger('unit') ?? 1,
        mirror: node.childAtom('mirror'),
        reference: reference,
        value: properties['Value'] ?? '',
        footprint: properties['Footprint'] ?? '',
        componentId:
            SchematicWriter.componentIdFields
                .map((name) => properties[name]?.trim() ?? '')
                .where((id) => id.isNotEmpty && id != '~')
                .firstOrNull ??
            '',
      );
      // An unnumbered part is one part per symbol, not all of them one part.
      final key = reference.contains('?') ? '?${unnumbered++}' : reference;
      (groups[key] ??= []).add(instance);
    }

    var count = 0;
    for (final group in groups.values) {
      final first = group.first;
      final definition =
          definitions[first.libId] ?? await symbols.loadSymbol(first.libId);
      if (definition == null) {
        warnings.add('${first.reference}: no symbol for ${first.libId}');
        continue;
      }

      final numbered = !first.reference.contains('?');
      PartWithDetails added;
      try {
        added = await parts.addPart(
          project.id,
          definition.toNewPartSpec(
            reference: numbered ? first.reference : null,
            value: first.value,
            footprint: first.footprint,
            componentId: first.componentId,
          ),
        );
      } on DuplicateReferenceException {
        warnings.add('${first.reference} appears twice; renumbered');
        added = await parts.addPart(
          project.id,
          definition.toNewPartSpec(
            value: first.value,
            footprint: first.footprint,
            componentId: first.componentId,
          ),
        );
      }

      final used = <int>{};
      for (final instance in group) {
        final unit = added.units
            .where((u) => u.unitNumber == instance.unit)
            .firstOrNull;
        if (unit == null) continue;
        used.add(unit.unitNumber);
        await parts.updateUnitPlacement(
          unit.copyWith(
            x: instance.at.dx,
            y: instance.at.dy,
            rotation: _quarterTurn(instance.rotation),
            mirrorX: instance.mirror == 'x',
            mirrorY: instance.mirror == 'y',
            placed: true,
            sheetId: sheetId,
          ),
        );
      }
      // Units the schematic never drew stay off the sheet.
      for (final unit in added.units) {
        if (!used.contains(unit.unitNumber)) {
          await parts.updateUnitPlacement(unit.copyWith(placed: false));
        }
      }
      count++;
    }
    return count;
  }

  static int _quarterTurn(double degrees) {
    final quarter = ((degrees / 90).round() * 90) % 360;
    return quarter < 0 ? quarter + 360 : quarter;
  }

  // --- connectivity ----------------------------------------------------

  /// Works out what is connected the way KiCad does, from geometry, and
  /// stores it as nets and drawn wires.
  Future<int> _connect(
    Project project,
    SList root, {
    String? sheetId,
    String pathName = '/',
    List<(String, Offset)> extraLabels = const [],
    _SheetLinks? links,
  }) async {
    final all = await parts.getPartsWithDetails(project.id);

    final pins = <(Offset, String)>[];
    for (final part in all) {
      for (final unit in part.units) {
        if (!unit.placed || unit.sheetId != sheetId) continue;
        final placement = Placement.ofUnit(unit);
        for (final pin in part.pins) {
          if (pin.unit != unit.unitNumber && pin.unit != 0) continue;
          pins.add((placement.apply(pin.x, pin.y), pin.id));
        }
      }
    }

    final wires = <(Offset, Offset)>[];
    for (final wire in root.children('wire')) {
      final points = wire.child('pts')?.children('xy').toList() ?? const [];
      if (points.length < 2) continue;
      wires.add((_xy(points[0]), _xy(points[1])));
    }

    // Names as the whole project will know them. A global label is the
    // same everywhere. A local label on a sub-sheet is its sheet's own, so
    // it carries the sheet's path the way KiCad names it — two sheets'
    // SDA are two nets. A hierarchical label is joined to the pin of its
    // box on the sheet above.
    String nameOf(String kind, String text) => switch (kind) {
      'hierarchical_label' when sheetId != null && links != null =>
        links.resolve(links.key(sheetId, text)),
      'label' when sheetId != null => '$pathName$text',
      _ => text,
    };
    final labels = <(String, Offset)>[
      for (final kind in const ['label', 'global_label', 'hierarchical_label'])
        for (final label in root.children(kind))
          if (label.atom(1) != null)
            (nameOf(kind, _unescape(label.atom(1)!)), _at(label)),
      for (final (key, at) in extraLabels) (links?.resolve(key) ?? key, at),
    ];
    // The name as written on this sheet, for each label: on one sheet, a
    // local label, a global one, a hierarchical one and a power symbol
    // saying the same thing are one net, as KiCad has it, though the
    // project knows a local one by the sheet's path (`/Battery/BAT-`).
    final written = <String?>[
      for (final kind in const ['label', 'global_label', 'hierarchical_label'])
        for (final label in root.children(kind))
          if (label.atom(1) != null) _unescape(label.atom(1)!),
      for (final _ in extraLabels) null,
    ];
    // A power symbol's pin joins the net named by its value, on every
    // sheet, like a global label: KiCad's rule since version 7, and the only
    // one a KiCad 8 or 9 symbol follows, its pin having no name at all.
    // GND's symbol with its value set to BAT- is on BAT-, not ground.
    //
    // An older symbol's hidden power pins join the net of their own name
    // the same way: a hidden VCC pin is on VCC. KiCad still reads them so.
    for (final part in all) {
      final value = _unescape(part.part.value.trim());
      final powerSymbol =
          part.part.reference.startsWith('#PWR') && value.isNotEmpty;
      for (final unit in part.units) {
        if (!unit.placed || unit.sheetId != sheetId) continue;
        final placement = Placement.ofUnit(unit);
        for (final pin in part.pins) {
          if (pin.unit != unit.unitNumber && pin.unit != 0) continue;
          final String name;
          if (powerSymbol) {
            name = value;
          } else if (pin.hidden &&
              pin.electricalType == PinElectricalType.powerIn &&
              pin.name.isNotEmpty &&
              pin.name != '~') {
            name = pin.name;
          } else {
            continue;
          }
          labels.add((name, placement.apply(pin.x, pin.y)));
          written.add(name);
        }
      }
    }
    final junctions = [for (final j in root.children('junction')) _at(j)];

    // Union-find over pins, then wires, then labels.
    final count = pins.length + wires.length + labels.length;
    final parent = List<int>.generate(count, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    final wireBase = pins.length;
    final labelBase = pins.length + wires.length;

    // The same pin drawn in several places is one pin.
    final firstPin = <String, int>{};
    for (var i = 0; i < pins.length; i++) {
      final seen = firstPin[pins[i].$2];
      if (seen == null) {
        firstPin[pins[i].$2] = i;
      } else {
        union(i, seen);
      }
    }

    for (var i = 0; i < wires.length; i++) {
      final (a1, a2) = wires[i];
      for (var j = i + 1; j < wires.length; j++) {
        final (b1, b2) = wires[j];
        final touching =
            _onSegment(a1, b1, b2) ||
            _onSegment(a2, b1, b2) ||
            _onSegment(b1, a1, a2) ||
            _onSegment(b2, a1, a2);
        if (touching) union(wireBase + i, wireBase + j);
      }
      for (var p = 0; p < pins.length; p++) {
        final at = pins[p].$1;
        if (_same(at, a1) || _same(at, a2)) union(p, wireBase + i);
      }
      for (final junction in junctions) {
        if (!_onSegment(junction, a1, a2)) continue;
        for (var j = 0; j < wires.length; j++) {
          if (j != i && _onSegment(junction, wires[j].$1, wires[j].$2)) {
            union(wireBase + i, wireBase + j);
          }
        }
      }
    }
    for (var p = 0; p < pins.length; p++) {
      for (var q = p + 1; q < pins.length; q++) {
        if (_same(pins[p].$1, pins[q].$1)) union(p, q);
      }
    }
    for (var l = 0; l < labels.length; l++) {
      final (text, at) = labels[l];
      for (var i = 0; i < wires.length; i++) {
        if (_onSegment(at, wires[i].$1, wires[i].$2)) {
          union(labelBase + l, wireBase + i);
        }
      }
      for (var p = 0; p < pins.length; p++) {
        if (_same(at, pins[p].$1)) union(labelBase + l, p);
      }
      for (var m = l + 1; m < labels.length; m++) {
        // The same name, or the same spot: a sheet's pin and the label
        // written at it are one connection.
        if (labels[m].$1 == text ||
            _same(labels[m].$2, at) ||
            (written[l] != null && written[l] == written[m])) {
          union(labelBase + l, labelBase + m);
        }
      }
    }

    final pinsOf = <int, List<String>>{};
    final namesOf = <int, List<String>>{};
    for (var p = 0; p < pins.length; p++) {
      final group = pinsOf[find(p)] ??= [];
      if (!group.contains(pins[p].$2)) group.add(pins[p].$2);
    }
    for (var l = 0; l < labels.length; l++) {
      (namesOf[find(labelBase + l)] ??= []).add(labels[l].$1);
    }

    // A wire on this sheet between the pins of two sheet boxes, with no
    // part of its own on it, still joins them: their joining names become
    // one, though no net here holds them.
    if (links != null) {
      for (final entry in namesOf.entries) {
        if (pinsOf.containsKey(entry.key)) continue;
        final joins = {
          for (final n in entry.value)
            if (n.startsWith(_SheetLinks.marker)) links.resolve(n),
        }.toList();
        if (joins.isEmpty) continue;
        for (final other in joins.skip(1)) {
          if (other != joins.first) links.alias[other] = joins.first;
        }
        final plain = entry.value
            .where((n) => !n.startsWith(_SheetLinks.marker))
            .firstOrNull;
        if (plain != null) links.preferred[joins.first] ??= plain;
      }
    }

    for (final entry in pinsOf.entries) {
      final members = entry.value;
      final names = namesOf[entry.key] ?? const <String>[];
      // A piece joining sheets goes by the import's joining name until
      // every sheet is in, remembering the name it will end up with.
      final joins = [
        for (final n in names)
          if (n.startsWith(_SheetLinks.marker)) n,
      ];
      final plain = names
          .where((n) => !n.startsWith(_SheetLinks.marker))
          .firstOrNull;
      String? name = names.firstOrNull;
      if (joins.isNotEmpty && links != null) {
        name = joins.first;
        for (final other in joins.skip(1)) {
          links.alias[other] = joins.first;
        }
        if (plain != null) links.preferred[joins.first] ??= plain;
      }
      String? netId;
      if (members.length >= 2) {
        netId = (await nets.connectPins(members[0], members[1])).net.id;
        for (final pin in members.skip(2)) {
          await nets.addPinToNet((await nets.netIdForPin(members[0]))!, pin);
        }
        netId = await nets.netIdForPin(members[0]);
      } else if (name != null) {
        netId = await nets.labelPin(
          project.id,
          members[0],
          name,
          joinByName: false,
        );
      }
      if (netId != null && name != null) {
        await nets.renameNet(netId, name);
      }
    }

    for (final mark in root.children('no_connect')) {
      final at = _at(mark);
      for (final (position, pinId) in pins) {
        if (_same(position, at)) await parts.setPinNoConnect(pinId, true);
      }
    }

    // The wires as they were drawn, on the nets they turned out to carry.
    for (var i = 0; i < wires.length; i++) {
      final group = pinsOf[find(wireBase + i)];
      if (group == null || group.isEmpty) continue;
      final netId = await nets.netIdForPin(group.first);
      if (netId == null) continue;
      final (a, b) = wires[i];
      String? pinAt(Offset point) => pins
          .where((p) => _same(p.$1, point) && group.contains(p.$2))
          .map((p) => p.$2)
          .firstOrNull;
      await nets.addWire(
        projectId: project.id,
        points: [a, b],
        pinAId: pinAt(a),
        pinBId: pinAt(b),
        netId: netId,
        sheetId: sheetId,
      );
    }

    return (await nets.getNets(project.id)).length;
  }

  // --- board -----------------------------------------------------------

  Future<(int, int)> _importBoard(
    Project project,
    String text,
    String? projectFile,
    List<String> warnings,
  ) async {
    final SList root;
    try {
      root = SExprParser.parseDocument(text);
    } catch (error) {
      warnings.add('The board could not be read: $error');
      return (0, 0);
    }
    if (root.head != 'kicad_pcb') {
      warnings.add('The board file is not a KiCad board');
      return (0, 0);
    }

    final netNames = <int, String>{
      for (final net in root.children('net'))
        ?int.tryParse(net.atom(1) ?? ''): net.atom(2) ?? '',
    };
    final appNets = await nets.getNets(project.id);
    final netIdByName = {for (final n in appNets) n.displayName: n.net.id};
    String? netOf(SList node) {
      final net = node.child('net');
      if (net == null) return null;
      final raw = net.atom(1);
      final number = int.tryParse(raw ?? '');
      final name = number == null ? raw : netNames[number];
      if (name == null || name.isEmpty) return null;
      return netIdByName[name];
    }

    // --- footprints
    final partIdByReference = {
      for (final part in await parts.getPartsWithDetails(project.id))
        part.part.reference: part.part.id,
    };
    final installedLibraries = {
      for (final library in await footprints.getLibraries()) library.nickname,
    };
    final toEmbed = <String, Map<String, (SList, double, bool)>>{};
    final placements = <(String, String, double, double, double, bool, bool)>[];

    for (final node in root.children('footprint')) {
      var libId = node.atom(1) ?? '';
      if (!libId.contains(':')) libId = 'Imported:$libId';
      final at = node.child('at');
      final flipped = node.childAtom('layer') == 'B.Cu';
      final rotation = at?.number(3) ?? 0;

      final referenceNode = node
          .children('property')
          .where((p) => p.atom(1) == 'Reference')
          .firstOrNull;
      final reference = referenceNode?.atom(2);
      final partId = partIdByReference[reference];
      if (partId == null) {
        warnings.add('Footprint ${reference ?? libId} has no matching part');
        continue;
      }
      final hidden =
          (referenceNode?.flag('hide') ?? false) ||
          (referenceNode?.child('effects')?.flag('hide') ?? false);

      if (await footprints.findByLibId(libId) == null) {
        final colon = libId.indexOf(':');
        final nickname = libId.substring(0, colon);
        final footprintName = libId.substring(colon + 1);
        final forLibrary = toEmbed[nickname] ??= {};
        final known = forLibrary[footprintName];
        // A copy on the front is the one to learn the footprint from.
        if (known == null || (known.$3 && !flipped)) {
          forLibrary[footprintName] = (node, rotation, flipped);
        }
      }
      placements.add((
        partId,
        libId,
        at?.number(1) ?? 0,
        at?.number(2) ?? 0,
        rotation,
        flipped,
        hidden,
      ));
    }

    final renamed = <String, String>{};
    for (final entry in toEmbed.entries) {
      var nickname = entry.key;
      if (installedLibraries.contains(nickname)) {
        nickname =
            '${entry.key}_${project.name.replaceAll(RegExp(r'\W+'), '_')}';
        for (final footprintName in entry.value.keys) {
          renamed['${entry.key}:$footprintName'] = '$nickname:$footprintName';
        }
      }
      try {
        await footprints.import(
          nickname: nickname,
          sources: {
            for (final footprint in entry.value.entries)
              '${footprint.key}.kicad_mod': utf8.encode(
                const SExprWriter().write(
                  _asLibraryFootprint(
                    footprint.value.$1,
                    footprint.key,
                    rotation: footprint.value.$2,
                    flipped: footprint.value.$3,
                  ),
                ),
              ),
          },
        );
      } catch (error) {
        warnings.add('Could not add the ${entry.key} footprints: $error');
      }
    }

    var footprintCount = 0;
    for (final (partId, libId, x, y, rotation, flipped, hidden) in placements) {
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: partId,
        libId: renamed[libId] ?? libId,
      );
      await boards.updatePlacement(
        ref.copyWith(
          x: x,
          y: y,
          rotation: rotation,
          flipped: flipped,
          placed: true,
          labelHidden: hidden,
        ),
      );
      footprintCount++;
    }

    // --- copper
    var trackCount = 0;
    CopperLayer? copper(String? token) =>
        token == null ? null : CopperLayer.fromToken(token);
    for (final kind in const ['segment', 'arc']) {
      for (final node in root.children(kind)) {
        final layer = copper(node.childAtom('layer'));
        if (layer == null) continue;
        final start = _xy(node.child('start'));
        final end = _xy(node.child('end'));
        final corners = kind == 'arc' && node.child('mid') != null
            ? _arcPoints(start, _xy(node.child('mid')), end)
            : [start, end];
        for (var i = 0; i < corners.length - 1; i++) {
          await boards.addTrack(
            projectId: project.id,
            layer: layer,
            startX: corners[i].dx,
            startY: corners[i].dy,
            endX: corners[i + 1].dx,
            endY: corners[i + 1].dy,
            width: node.childNumber('width') ?? 0.25,
            netId: netOf(node),
          );
          trackCount++;
        }
      }
    }
    for (final node in root.children('via')) {
      final at = _at(node);
      await boards.addVia(
        projectId: project.id,
        x: at.dx,
        y: at.dy,
        diameter: node.childNumber('size') ?? 0.8,
        drill: node.childNumber('drill') ?? 0.4,
        netId: netOf(node),
      );
    }
    for (final node in root.children('zone')) {
      final layer = BoardLayer.fromToken(
        node.childAtom('layer') ?? node.child('layers')?.atom(1) ?? '',
      );
      if (layer == null || !layer.isCopper) continue;
      final points = [
        for (final xy
            in node.child('polygon')?.child('pts')?.children('xy') ??
                const <SList>[])
          _xy(xy),
      ];
      if (points.length < 3) continue;
      final netName = node.childAtom('net_name') ?? '';
      final connect = node.child('connect_pads');
      final fill = node.child('fill');
      await boards.addZone(
        projectId: project.id,
        layer: layer,
        points: points,
        netId: netIdByName[netName],
        netName: netName,
        clearance: connect?.childNumber('clearance') ?? 0.5,
        minThickness: node.childNumber('min_thickness') ?? 0.25,
        priority: node.childNumber('priority')?.round() ?? 0,
        padConnection: switch (connect?.atom(1)) {
          'yes' => PadConnection.solid,
          'no' => PadConnection.none,
          _ => PadConnection.thermal,
        },
        thermalGap: fill?.childNumber('thermal_gap') ?? 0.5,
        thermalSpoke: fill?.childNumber('thermal_bridge_width') ?? 0.5,
      );
    }

    // --- silkscreen text
    for (final node in root.children('gr_text')) {
      final layer = node.childAtom('layer');
      if (layer != 'F.SilkS' && layer != 'B.SilkS') continue;
      final content = node.atom(1);
      if (content == null || content.trim().isEmpty) continue;
      final at = node.child('at');
      await boards.addText(
        projectId: project.id,
        content: content,
        position: Offset(at?.number(1) ?? 0, at?.number(2) ?? 0),
        rotation: at?.number(3) ?? 0,
        size:
            node.child('effects')?.child('font')?.child('size')?.number(1) ??
            1.0,
        back: layer == 'B.SilkS',
        font: _fontNamed(
          node.child('effects')?.child('font')?.child('face')?.atom(1),
        ),
      );
    }

    // --- silkscreen pictures: filled shapes, a group of them at a time
    final groupOf = <String, String>{};
    for (final group in root.children('group')) {
      final name = group.atom(1) ?? '';
      for (final member in group.child('members')?.items.skip(1) ?? const []) {
        if (member is SAtom) groupOf[member.value] = name;
      }
    }
    final pictures = <(String, String), List<List<Offset>>>{};
    for (final node in root.children('gr_poly')) {
      final layer = node.childAtom('layer');
      if (layer != 'F.SilkS' && layer != 'B.SilkS') continue;
      final fill = node.childAtom('fill');
      if (fill != 'yes' && fill != 'solid') continue;
      final points = [
        for (final xy in node.child('pts')?.children('xy') ?? const <SList>[])
          _xy(xy),
      ];
      if (points.length < 3) continue;
      final group = groupOf[node.childAtom('uuid') ?? ''] ?? '';
      (pictures[(layer!, group)] ??= []).add(points);
    }
    for (final MapEntry(key: (layer, group), value: shapes)
        in pictures.entries) {
      final picture = _rasterise(shapes, back: layer == 'B.SilkS');
      if (picture == null) continue;
      await boards.addImage(
        projectId: project.id,
        name: group.startsWith(BoardWriter.pictureGroupPrefix)
            ? group.substring(BoardWriter.pictureGroupPrefix.length)
            : (group.isEmpty ? 'Imported artwork' : group),
        position: picture.$1,
        width: picture.$2,
        columns: picture.$3,
        rows: picture.$4,
        bits: picture.$5,
        back: layer == 'B.SilkS',
      );
    }

    // --- the build: layer count and stackup
    final build = BoardWriter.readBuild(root);
    {
      final current = await boards.ensureBoard(project.id);
      await boards.updateBoard(
        current.copyWith(
          copperLayerCount: build.layerCount,
          thickness: build.stackup?.thickness ?? build.thickness,
          stackup: build.stackup,
        ),
      );
    }

    // --- outline, edge cuts and rules
    await _importEdges(project, root);
    DesignRules? rules;
    if (projectFile != null) {
      try {
        rules = BoardProjectWriter.rulesFrom(projectFile);
      } on FormatException {
        // A damaged project file costs its rules, not the whole import.
        warnings.add(
          'The .kicad_pro could not be read; design rules and net classes '
          'were left at their defaults',
        );
      }
    }
    if (rules != null) {
      final current = await boards.ensureBoard(project.id);
      await boards.updateBoard(current.copyWith(rules: rules));
    }
    if (projectFile != null) {
      await _importNetClasses(project, projectFile, netIdByName);
    }

    return (footprintCount, trackCount);
  }

  /// A footprint as it sits on a board, turned back into a library one.
  ///
  /// A board stores pad angles with the footprint's rotation already added,
  /// and a footprint on the back with every layer swapped; a library
  /// footprint has neither.
  static SList _asLibraryFootprint(
    SList node,
    String name, {
    required double rotation,
    required bool flipped,
  }) {
    const placementOnly = {
      'at',
      'layer',
      'uuid',
      'path',
      'tstamp',
      'sheetname',
      'sheetfile',
    };
    SExpr local(SExpr item) {
      if (item is! SList) return item;
      var result = item;
      if (result.head == 'pad' && rotation != 0) {
        result = SList([
          for (final child in result.items)
            if (child is SList && child.head == 'at')
              _withAngle(child, (child.number(3) ?? 0) - rotation)
            else
              child,
        ]);
      }
      return flipped ? _unflip(result) : result;
    }

    return SList([
      SAtom('footprint'),
      S.text(name),
      for (final item in node.items.skip(2))
        if (!(item is SList && placementOnly.contains(item.head))) local(item),
    ]);
  }

  static SList _withAngle(SList at, double angle) {
    var normalised = angle % 360;
    if (normalised < 0) normalised += 360;
    return SList([
      SAtom('at'),
      at.items[1],
      at.items[2],
      if (normalised.abs() > 1e-9) S.number(normalised),
    ]);
  }

  static SExpr _unflip(SExpr node) {
    if (node is! SList) return node;
    if (node.head == 'layer' || node.head == 'layers') {
      return SList([
        node.items.first,
        for (final item in node.items.skip(1))
          if (item is SAtom && BoardLayer.fromToken(item.value) != null)
            SAtom(
              BoardLayer.fromToken(item.value)!.flipped.token,
              quoted: item.quoted,
            )
          else
            item,
      ]);
    }
    if (node.head == 'justify') {
      return SList([
        for (final item in node.items)
          if (!(item is SAtom && item.value == 'mirror')) item,
      ]);
    }
    return SList([for (final item in node.items) _unflip(item)]);
  }

  Future<void> _importEdges(Project project, SList root) async {
    final lines = <(Offset, Offset)>[];
    final arcs = <(Offset, Offset, Offset)>[];
    final rects = <Rect>[];
    final circles = <(Offset, double)>[];
    final polygons = <List<Offset>>[];

    bool onEdge(SList node) => node.childAtom('layer') == 'Edge.Cuts';
    for (final node in root.children('gr_line')) {
      if (onEdge(node)) {
        lines.add((_xy(node.child('start')), _xy(node.child('end'))));
      }
    }
    for (final node in root.children('gr_arc')) {
      if (onEdge(node)) {
        arcs.add((
          _xy(node.child('start')),
          _xy(node.child('mid')),
          _xy(node.child('end')),
        ));
      }
    }
    for (final node in root.children('gr_rect')) {
      if (onEdge(node)) {
        rects.add(
          Rect.fromPoints(_xy(node.child('start')), _xy(node.child('end'))),
        );
      }
    }
    for (final node in root.children('gr_circle')) {
      if (onEdge(node)) {
        final centre = _xy(node.child('center'));
        circles.add((centre, (_xy(node.child('end')) - centre).distance));
      }
    }
    for (final node in root.children('gr_poly')) {
      if (onEdge(node)) {
        polygons.add([
          for (final xy in node.child('pts')?.children('xy') ?? const <SList>[])
            _xy(xy),
        ]);
      }
    }

    // Lines and arcs chained end to end into closed loops.
    final pieces = <List<Offset>>[
      for (final (a, b) in lines) [a, b],
      for (final (s, m, e) in arcs) _arcPoints(s, m, e),
    ];
    final used = List<bool>.filled(pieces.length, false);
    final loops = <(List<Offset>, Set<int>)>[];
    for (var start = 0; start < pieces.length; start++) {
      if (used[start]) continue;
      final chain = [...pieces[start]];
      final members = {start};
      var extended = true;
      while (extended && !_same(chain.first, chain.last)) {
        extended = false;
        for (var i = 0; i < pieces.length; i++) {
          if (used[i] || members.contains(i)) continue;
          final piece = pieces[i];
          if (_same(piece.first, chain.last)) {
            chain.addAll(piece.skip(1));
          } else if (_same(piece.last, chain.last)) {
            chain.addAll(piece.reversed.skip(1));
          } else {
            continue;
          }
          members.add(i);
          extended = true;
          break;
        }
      }
      if (_same(chain.first, chain.last) && chain.length >= 4) {
        for (final member in members) {
          used[member] = true;
        }
        loops.add((chain..removeLast(), members));
      }
    }

    // The biggest closed shape is the board; everything else is a cut in it.
    double area(Rect r) => r.width * r.height;
    Rect boundsOf(List<Offset> points) => points.skip(1).fold(
      Rect.fromPoints(points.first, points.first),
      (r, p) {
        return r.expandToInclude(Rect.fromPoints(p, p));
      },
    );

    BoardOutline? outline;
    Object? chosen;
    var best = 0.0;
    for (final rect in rects) {
      if (area(rect) > best) {
        best = area(rect);
        outline = BoardOutline.rectangle(rect);
        chosen = rect;
      }
    }
    for (final circle in circles) {
      final box = Rect.fromCircle(center: circle.$1, radius: circle.$2);
      if (area(box) > best) {
        best = area(box);
        outline = BoardOutline.circle(box);
        chosen = circle;
      }
    }
    for (final polygon in [...polygons, for (final loop in loops) loop.$1]) {
      if (polygon.length < 3) continue;
      final box = boundsOf(polygon);
      if (area(box) > best) {
        best = area(box);
        outline = BoardOutline.polygon(polygon);
        chosen = polygon;
      }
    }

    if (outline != null) {
      // A four-sided loop at right angles is a rectangle, and is kept as one.
      if (outline.kind == BoardOutlineKind.polygon &&
          outline.points.length == 4 &&
          outline.points.every(
            (p) =>
                (p.dx - outline!.rect.left).abs() < _near ||
                (p.dx - outline.rect.right).abs() < _near,
          ) &&
          outline.points.every(
            (p) =>
                (p.dy - outline!.rect.top).abs() < _near ||
                (p.dy - outline.rect.bottom).abs() < _near,
          )) {
        outline = BoardOutline.rectangle(outline.rect);
      }
      final board = await boards.ensureBoard(project.id);
      await boards.updateBoard(board.withOutline(outline));
    }

    final loopMembers = {
      for (final loop in loops)
        if (!identical(loop.$1, chosen)) ...loop.$2,
    };
    final outlineMembers = {
      for (final loop in loops)
        if (identical(loop.$1, chosen)) ...loop.$2,
    };

    for (var i = 0; i < lines.length; i++) {
      if (outlineMembers.contains(i)) continue;
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.line,
        points: [lines[i].$1, lines[i].$2],
      );
    }
    for (var i = 0; i < arcs.length; i++) {
      if (outlineMembers.contains(lines.length + i)) continue;
      final (s, m, e) = arcs[i];
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.arc,
        points: [s, m, e],
      );
    }
    loopMembers.clear();
    for (final rect in rects) {
      if (identical(rect, chosen)) continue;
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.rectangle,
        points: [rect.topLeft, rect.bottomRight],
      );
    }
    for (final circle in circles) {
      if (identical(circle, chosen)) continue;
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.circle,
        points: [circle.$1, circle.$1 + Offset(circle.$2, 0)],
      );
    }
    for (final polygon in polygons) {
      if (identical(polygon, chosen) || polygon.length < 3) continue;
      await boards.addEdge(
        projectId: project.id,
        kind: BoardEdgeKind.polygon,
        points: polygon,
      );
    }
  }

  Future<void> _importNetClasses(
    Project project,
    String projectFile,
    Map<String, String> netIdByName,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(projectFile);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final settings = decoded['net_settings'];
    if (settings is! Map) return;

    final classIds = <String, String>{};
    for (final entry in (settings['classes'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final name = entry['name'];
      if (name is! String || name == 'Default') continue;
      final width = (entry['track_width'] as num?)?.toDouble();
      if (width == null || width <= 0) continue;
      final created = await boards.addNetClass(
        projectId: project.id,
        name: name,
        trackWidth: width,
        clearance: (entry['clearance'] as num?)?.toDouble(),
      );
      classIds[name] = created.id;
    }
    for (final pattern
        in (settings['netclass_patterns'] as List?) ?? const []) {
      if (pattern is! Map) continue;
      final classId = classIds[pattern['netclass']];
      final netId = netIdByName[pattern['pattern']];
      // Wildcard patterns are KiCad's to expand; exact names are brought in.
      if (classId != null && netId != null) {
        await boards.setNetClass(netId, classId);
      }
    }
  }

  // --- geometry --------------------------------------------------------

  static Offset _xy(SList? node) =>
      Offset(node?.number(1) ?? 0, node?.number(2) ?? 0);

  static Offset _at(SList node) => _xy(node.child('at'));

  /// A name as KiCad means it: characters it cannot keep as they are in a
  /// name are written as `{slash}`, `{colon}` and so on, and a label saying
  /// `VPP{slash}MCLR` is the same net as one saying `VPP/MCLR`.
  static String _unescape(String text) {
    if (!text.contains('{')) return text;
    const escapes = {
      '{slash}': '/',
      '{backslash}': r'\',
      '{colon}': ':',
      '{lt}': '<',
      '{gt}': '>',
      '{dblquote}': '"',
      '{quote}': "'",
      '{tab}': '\t',
      '{return}': '\n',
      '{brace}': '{',
    };
    var out = text;
    for (final e in escapes.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    return out;
  }

  static bool _same(Offset a, Offset b) => (a - b).distance < _near;

  static bool _onSegment(Offset p, Offset a, Offset b) {
    final d = b - a;
    final lengthSquared = d.dx * d.dx + d.dy * d.dy;
    if (lengthSquared < 1e-12) return _same(p, a);
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return (p - (a + d * t)).distance < _near;
  }

  static List<Offset> _arcPoints(Offset a, Offset m, Offset b) {
    final d =
        2 *
        (a.dx * (m.dy - b.dy) + m.dx * (b.dy - a.dy) + b.dx * (a.dy - m.dy));
    if (d.abs() < 1e-9) return [a, b];
    final a2 = a.dx * a.dx + a.dy * a.dy;
    final m2 = m.dx * m.dx + m.dy * m.dy;
    final b2 = b.dx * b.dx + b.dy * b.dy;
    final centre = Offset(
      (a2 * (m.dy - b.dy) + m2 * (b.dy - a.dy) + b2 * (a.dy - m.dy)) / d,
      (a2 * (b.dx - m.dx) + m2 * (a.dx - b.dx) + b2 * (m.dx - a.dx)) / d,
    );
    final r = (a - centre).distance;
    double angle(Offset p) => math.atan2(p.dy - centre.dy, p.dx - centre.dx);
    final a0 = angle(a);
    var sweep = angle(b) - a0;
    var toMid = angle(m) - a0;
    while (sweep < 0) {
      sweep += math.pi * 2;
    }
    while (toMid < 0) {
      toMid += math.pi * 2;
    }
    if (toMid > sweep) sweep -= math.pi * 2;
    final steps = math.max(2, (sweep.abs() / (math.pi / 16)).ceil());
    return [
      for (var i = 0; i <= steps; i++)
        centre +
            Offset(
              r * math.cos(a0 + sweep * i / steps),
              r * math.sin(a0 + sweep * i / steps),
            ),
    ];
  }
}

class _Instance {
  const _Instance({
    required this.libId,
    required this.at,
    required this.rotation,
    required this.unit,
    required this.mirror,
    required this.reference,
    required this.value,
    required this.footprint,
    this.componentId = '',
  });

  final String libId;
  final Offset at;
  final double rotation;
  final int unit;
  final String? mirror;
  final String reference;
  final String value;
  final String footprint;
  final String componentId;
}

/// How the sheets of an import are joined while they come in.
///
/// A hierarchical label inside a sheet and the pin of that sheet's box on
/// the sheet above are the same connection. Each pair is given one name
/// that nothing else could have, and nets with the same name are one net,
/// so the two join. Once every sheet is in, the names are replaced.
class _SheetLinks {
  static const marker = '\u0001';

  /// Each sheet's path, as KiCad names it: `/Power/`.
  final pathOf = <String, String>{};

  /// A joining name that turned out to be the same net as another.
  final alias = <String, String>{};

  /// The name a joined net should end up with, where a label gave one.
  final preferred = <String, String>{};

  /// Sheet files already brought in, to notice one used twice.
  final used = <String>{};

  /// Every sheet brought in, as its box was placed.
  final boxes = <String, SchematicSheet>{};

  /// The net each joining name ended up on, before it was renamed.
  final netOf = <String, String>{};

  String key(String sheetId, String pin) => '$marker$sheetId$marker$pin';

  String resolve(String key) {
    var at = key;
    final seen = <String>{};
    while (seen.add(at)) {
      final next = alias[at];
      if (next == null) break;
      at = next;
    }
    return at;
  }

  (String, String) parse(String key) {
    final parts = key.split(marker);
    return (parts.length > 1 ? parts[1] : '', parts.length > 2 ? parts[2] : '');
  }
}

/// The id of the silkscreen font whose family is [face], or the stroke font.
String _fontNamed(String? face) {
  if (face == null || face.isEmpty) return '';
  final wanted = face.toLowerCase();
  for (final info in SilkFonts.available) {
    if (SilkFonts.byId(info.id)?.family.toLowerCase() == wanted) return info.id;
  }
  return '';
}

/// Filled shapes turned back into a picture: its centre, printed width,
/// pixels across and down, and ink. Null when there is nothing to draw.
///
/// Read at a twentieth of a millimetre, or coarser if the picture is large,
/// and un-mirrored for the underside, where a picture is stored as it reads
/// from the front.
(Offset, double, int, int, Uint8List)? _rasterise(
  List<List<Offset>> shapes, {
  required bool back,
}) {
  var bounds = Rect.fromPoints(shapes.first.first, shapes.first.first);
  for (final shape in shapes) {
    for (final p in shape) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
  }
  if (bounds.width <= 0 || bounds.height <= 0) return null;
  final pixel = math.max(0.05, math.max(bounds.width, bounds.height) / 600);
  final columns = math.max(1, (bounds.width / pixel).round());
  final rows = math.max(1, (bounds.height / pixel).round());
  final ink = List<bool>.filled(columns * rows, false);
  for (var y = 0; y < rows; y++) {
    final sy = bounds.top + (y + 0.5) * bounds.height / rows;
    for (final shape in shapes) {
      final crossings = <double>[];
      for (var i = 0, j = shape.length - 1; i < shape.length; j = i++) {
        final a = shape[i];
        final b = shape[j];
        if ((a.dy > sy) == (b.dy > sy)) continue;
        crossings.add((b.dx - a.dx) * (sy - a.dy) / (b.dy - a.dy) + a.dx);
      }
      crossings.sort();
      for (var k = 0; k + 1 < crossings.length; k += 2) {
        final from = ((crossings[k] - bounds.left) / bounds.width * columns)
            .round()
            .clamp(0, columns);
        final to = ((crossings[k + 1] - bounds.left) / bounds.width * columns)
            .round()
            .clamp(0, columns);
        for (var x = from; x < to; x++) {
          ink[y * columns + (back ? columns - 1 - x : x)] = true;
        }
      }
    }
  }
  if (!ink.contains(true)) return null;
  return (bounds.center, bounds.width, columns, rows, BoardImage.pack(ink));
}
