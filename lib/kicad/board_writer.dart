import '../core/util/ids.dart';
import '../domain/export/board_document.dart';
import '../domain/pcb/pcb.dart';
import 'sexpr/sexpr.dart';
import 'sexpr/sexpr_writer.dart';

/// Writes `.kicad_pcb` files.
///
/// ### How a footprint gets onto the board
///
/// Not by being rebuilt. The library's own `(footprint ...)` node goes into
/// the file with a handful of things changed: where it sits, which side it
/// is on, what the reference and value say, and which net each pad is on.
/// Everything else — 3D models, custom pad shapes, keepout zones, whatever
/// a future KiCad adds — travels through untouched, because this app does
/// not have to understand a thing in order not to lose it.
class BoardWriter {
  const BoardWriter({
    this.formatVersion = kicad9FormatVersion,
    this.writer = const SExprWriter(),
  });

  /// KiCad 9's board format. Version 10 opens these unchanged.
  static const kicad9FormatVersion = 20241229;

  /// Standard board thickness, in millimetres. Not adjustable in the app:
  /// it changes nothing about a layout and every fabricator defaults to it.
  static const boardThicknessMm = 1.6;

  final int formatVersion;
  final SExprWriter writer;

  String write(BoardDocument document) => writer.write(build(document));

  SList build(BoardDocument document) {
    final netNumbers = _netNumbers(document);

    return SList([
      SAtom('kicad_pcb'),
      S.of('version', [formatVersion]),
      SList([SAtom('generator'), S.text(document.generator)]),
      SList([SAtom('generator_version'), S.text(document.generatorVersion)]),
      S.list('general', [
        S.of('thickness', [boardThicknessMm]),
        S.flag('legacy_teardrops', false),
      ]),
      SList([SAtom('paper'), S.text(document.project.paper.kicadName)]),
      S.list('title_block', [
        SList([SAtom('title'), S.text(document.project.name)]),
        SList([SAtom('rev'), S.text(document.project.revision)]),
        SList([SAtom('company'), S.text(document.project.company)]),
      ]),
      _layers(),
      _setup(document),
      ..._nets(document, netNumbers),
      ..._footprints(document, netNumbers),
      ..._edgeCuts(document),
      ..._extraEdges(document),
      ..._segments(document, netNumbers),
      ..._vias(document, netNumbers),
      ..._zones(document, netNumbers),
      ..._texts(document),
    ]);
  }

  /// The layer table for a two-layer board.
  ///
  /// The numbering is KiCad's own and is not free to invent: a board file
  /// whose layer indices disagree with the ones KiCad expects opens with
  /// its copper on the wrong side.
  SList _layers() => S.list('layers', [
    SList([SAtom('0'), S.text('F.Cu'), SAtom('signal')]),
    SList([SAtom('2'), S.text('B.Cu'), SAtom('signal')]),
    SList([SAtom('9'), S.text('F.Adhes'), SAtom('user'), S.text('F.Adhesive')]),
    SList([
      SAtom('11'),
      S.text('B.Adhes'),
      SAtom('user'),
      S.text('B.Adhesive'),
    ]),
    SList([SAtom('13'), S.text('F.Paste'), SAtom('user')]),
    SList([SAtom('15'), S.text('B.Paste'), SAtom('user')]),
    SList([
      SAtom('5'),
      S.text('F.SilkS'),
      SAtom('user'),
      S.text('F.Silkscreen'),
    ]),
    SList([
      SAtom('7'),
      S.text('B.SilkS'),
      SAtom('user'),
      S.text('B.Silkscreen'),
    ]),
    SList([SAtom('1'), S.text('F.Mask'), SAtom('user')]),
    SList([SAtom('3'), S.text('B.Mask'), SAtom('user')]),
    SList([
      SAtom('17'),
      S.text('Dwgs.User'),
      SAtom('user'),
      S.text('User.Drawings'),
    ]),
    SList([
      SAtom('19'),
      S.text('Cmts.User'),
      SAtom('user'),
      S.text('User.Comments'),
    ]),
    SList([
      SAtom('21'),
      S.text('Eco1.User'),
      SAtom('user'),
      S.text('User.Eco1'),
    ]),
    SList([
      SAtom('23'),
      S.text('Eco2.User'),
      SAtom('user'),
      S.text('User.Eco2'),
    ]),
    SList([SAtom('25'), S.text('Edge.Cuts'), SAtom('user')]),
    SList([SAtom('27'), S.text('Margin'), SAtom('user')]),
    SList([
      SAtom('31'),
      S.text('F.CrtYd'),
      SAtom('user'),
      S.text('F.Courtyard'),
    ]),
    SList([
      SAtom('29'),
      S.text('B.CrtYd'),
      SAtom('user'),
      S.text('B.Courtyard'),
    ]),
    SList([SAtom('35'), S.text('F.Fab'), SAtom('user')]),
    SList([SAtom('33'), S.text('B.Fab'), SAtom('user')]),
  ]);

  /// The board's own settings.
  ///
  /// Deliberately spare. Design rules are not here: KiCad keeps clearance,
  /// track width and via sizes in the `.kicad_pro` project file, and
  /// inventing board-file keys for them produces a file KiCad refuses to
  /// open at all. [BoardProjectWriter] writes them where they belong.
  SList _setup(BoardDocument document) => S.list('setup', [
    S.of('pad_to_mask_clearance', [0]),
    S.flag('allow_soldermask_bridges_in_footprints', false),
    S.of('aux_axis_origin', [
      document.scene.outlineBounds.left,
      document.scene.outlineBounds.top,
    ]),
  ]);

  // --- nets ------------------------------------------------------------

  /// Net numbers, starting at 1. Net 0 is KiCad's "no net".
  Map<String, int> _netNumbers(BoardDocument document) {
    final numbers = <String, int>{};
    var next = 1;
    for (final net in document.boardNets) {
      numbers[net.net.id] = next++;
    }
    return numbers;
  }

  List<SList> _nets(BoardDocument document, Map<String, int> numbers) => [
    SList([SAtom('net'), SAtom('0'), S.text('')]),
    for (final net in document.boardNets)
      SList([
        SAtom('net'),
        SAtom('${numbers[net.net.id]}'),
        S.text(net.displayName),
      ]),
  ];

  // --- footprints ------------------------------------------------------

  List<SList> _footprints(BoardDocument document, Map<String, int> numbers) {
    final result = <SList>[];
    for (final footprint in document.scene.footprints) {
      final source = document.footprintSources[footprint.ref.libId];
      if (source is! SList) continue;
      result.add(_placeFootprint(footprint, source, numbers));
    }
    return result;
  }

  SList _placeFootprint(
    PlacedFootprint footprint,
    SList source,
    Map<String, int> numbers,
  ) {
    final ref = footprint.ref;
    final side = ref.flipped ? 'B.Cu' : 'F.Cu';

    // Everything the library said, minus what placement decides and what
    // only belongs in a standalone `.kicad_mod`. Skipping two items rather
    // than one drops the source's own name as well as its head: the board
    // names a footprint by its full `lib_id`, and leaving both in produces
    // a node with two names that KiCad refuses outright.
    const replaced = {'at', 'layer', 'uuid', 'path', 'tstamp'};
    const fileOnly = {'version', 'generator', 'generator_version'};

    final body = <SExpr>[];
    for (final item in source.items.skip(2)) {
      if (item is SList &&
          (replaced.contains(item.head) || fileOnly.contains(item.head))) {
        continue;
      }
      body.add(ref.flipped && item is SList ? _flipToBack(item) : item);
    }

    final placed = <SExpr>[
      SAtom('footprint'),
      S.text(ref.libId),
      SList([SAtom('layer'), S.text(side)]),
      SList([SAtom('uuid'), S.text(derivedId('footprint:${ref.id}'))]),
      S.of('at', [ref.x, ref.y, ref.rotation]),
    ];

    for (final item in body) {
      if (item is SList && item.head == 'property') {
        final name = item.atom(1);
        if (name == 'Reference') {
          placed.add(
            _asDesignator(_withValue(item, footprint.part.reference), ref),
          );
          continue;
        }
        if (name == 'Value') {
          placed.add(_withValue(item, footprint.part.value));
          continue;
        }
      }
      if (item is SList && item.head == 'pad') {
        placed.add(
          _withNet(_rotatedPad(item, ref.rotation), footprint, numbers),
        );
        continue;
      }
      placed.add(item);
    }

    return SList(placed);
  }

  /// Moves a footprint's geometry to the back of the board.
  ///
  /// Two things change, and KiCad infers neither of them from the
  /// placement. Every layer name swaps side, and every piece of text gains
  /// a mirror: silkscreen on the underside of a board is read through the
  /// board, so unmirrored text on the back comes out backwards — which
  /// KiCad's own DRC calls out, and did.
  SExpr _flipToBack(SExpr node) {
    if (node is! SList) return node;

    // Only the contents of `layer` and `layers` nodes name layers; an
    // arbitrary quoted "F.Cu" elsewhere is a description, not a layer.
    if (node.head == 'layer' || node.head == 'layers') {
      return SList([
        node.items.first,
        for (final item in node.items.skip(1)) _flippedLayerAtom(item),
      ]);
    }

    if (node.head == 'effects') return _mirrored(node);

    return SList([for (final item in node.items) _flipToBack(item)]);
  }

  SExpr _flippedLayerAtom(SExpr node) {
    if (node is! SAtom) return node;
    final layer = BoardLayer.fromToken(node.value);
    if (layer == null) return node;
    return SAtom(layer.flipped.token, quoted: node.quoted);
  }

  /// Adds `mirror` to a text node's justification, keeping whatever
  /// alignment it already had.
  SList _mirrored(SList effects) {
    final justify = effects.child('justify');
    if (justify == null) {
      return SList([
        ...effects.items,
        SList([SAtom('justify'), SAtom('mirror')]),
      ]);
    }
    if (justify.items.skip(1).any((i) => i is SAtom && i.value == 'mirror')) {
      return effects;
    }
    return SList([
      for (final item in effects.items)
        if (item is SList && item.head == 'justify')
          SList([...item.items, SAtom('mirror')])
        else
          item,
    ]);
  }

  /// The designator as the user left it: where they moved it, how big, and
  /// whether it is printed at all.
  ///
  /// Only what was changed is rewritten. A designator nobody touched keeps
  /// the library's own position and size, which is what a footprint's
  /// author chose and what KiCad would show.
  SList _asDesignator(SList property, PlacedFootprintRef ref) {
    final offset = ref.labelOffset;
    final items = <SExpr>[];
    for (final item in property.items) {
      if (item is SList && item.head == 'at' && offset != null) {
        // The angle is kept: KiCad writes it already combined with the
        // footprint's own rotation, and the position is all that moved.
        final angle = item.items.length > 3 ? item.items[3] : SAtom('0');
        items.add(
          SList([
            SAtom('at'),
            SAtom(_number(offset.dx)),
            SAtom(_number(offset.dy)),
            angle,
          ]),
        );
        continue;
      }
      // Replaced below, so the property never ends up with two.
      if (item is SList && item.head == 'hide') continue;
      if (item is SList && item.head == 'effects') {
        items.add(_withFontSize(item, ref.labelSize));
        continue;
      }
      items.add(item);
    }
    if (ref.labelHidden) items.add(S.flag('hide', true));
    return SList(items);
  }

  /// An `effects` node with its font set to [size], and a stroke in the
  /// proportion KiCad's own defaults use.
  SList _withFontSize(SList effects, double size) => SList([
    for (final item in effects.items)
      if (item is SList && item.head == 'font')
        SList([
          for (final part in item.items)
            if (part is SList && part.head == 'size')
              S.of('size', [size, size])
            else if (part is SList && part.head == 'thickness')
              S.of('thickness', [_stroke(size)])
            else
              part,
        ])
      else
        item,
  ]);

  static double _stroke(double size) =>
      double.parse((size * 0.15).toStringAsFixed(4));

  static String _number(double value) {
    final text = value.toStringAsFixed(4);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  /// Free silkscreen text.
  ///
  /// Text on the back carries `mirror`: it is read through the board, and
  /// KiCad's DRC reports unmirrored back-side text as an error — which is
  /// how the footprint flip learned to add it.
  List<SList> _texts(BoardDocument document) => [
    for (final text in document.scene.texts)
      if (text.content.trim().isNotEmpty)
        S.list('gr_text', [
          S.text(text.content),
          S.of('at', [text.position.dx, text.position.dy, text.rotation]),
          SList([SAtom('layer'), S.text(text.layer.token)]),
          SList([SAtom('uuid'), S.text(derivedId('text:${text.id}'))]),
          S.list('effects', [
            S.list('font', [
              S.of('size', [text.size, text.size]),
              S.of('thickness', [_stroke(text.size)]),
            ]),
            if (text.back) SList([SAtom('justify'), SAtom('mirror')]),
          ]),
        ]),
  ];

  SList _withValue(SList property, String value) => SList([
    property.items.first,
    property.items.length > 1 ? property.items[1] : S.text(''),
    S.text(value),
    ...property.items.skip(3),
  ]);

  /// A pad's angle as a board states it: with the footprint's own rotation
  /// added. A library footprint stores each pad relative to itself; the
  /// board file does not, so a pad copied across unchanged opens in KiCad
  /// facing the way the library drew it rather than the way it was placed.
  SList _rotatedPad(SList pad, double rotation) {
    if (rotation % 360 == 0) return pad;
    return SList([
      for (final item in pad.items)
        if (item is SList && item.head == 'at')
          SList([
            SAtom('at'),
            item.items[1],
            item.items[2],
            S.number(((item.number(3) ?? 0) + rotation) % 360),
          ])
        else
          item,
    ]);
  }

  /// Adds the pad's net, which is the whole point of exporting a board.
  SList _withNet(
    SList pad,
    PlacedFootprint footprint,
    Map<String, int> numbers,
  ) {
    final number = pad.atom(1);
    if (number == null) return pad;

    final placed = footprint.pads
        .where((p) => p.pad.number == number)
        .firstOrNull;
    final netId = placed?.netId;
    final netNumber = netId == null ? null : numbers[netId];
    if (netNumber == null) return pad;

    // A pad that already carries a net from the library keeps ours instead.
    final items = [
      for (final item in pad.items)
        if (!(item is SList && item.head == 'net')) item,
    ];
    return SList([
      ...items,
      SList([SAtom('net'), SAtom('$netNumber'), S.text(placed!.netName ?? '')]),
    ]);
  }

  // --- copper and outline ----------------------------------------------

  List<SList> _segments(BoardDocument document, Map<String, int> numbers) => [
    for (final track in document.scene.tracks)
      S.list('segment', [
        S.of('start', [track.startX, track.startY]),
        S.of('end', [track.endX, track.endY]),
        S.of('width', [track.width]),
        SList([SAtom('layer'), S.text(track.layer.layer.token)]),
        S.of('net', [numbers[track.netId] ?? 0]),
        SList([SAtom('uuid'), S.text(derivedId('segment:${track.id}'))]),
      ]),
  ];

  List<SList> _vias(BoardDocument document, Map<String, int> numbers) => [
    for (final via in document.scene.vias)
      S.list('via', [
        S.of('at', [via.x, via.y]),
        S.of('size', [via.diameter]),
        S.of('drill', [via.drill]),
        SList([SAtom('layers'), S.text('F.Cu'), S.text('B.Cu')]),
        S.of('net', [numbers[via.netId] ?? 0]),
        SList([SAtom('uuid'), S.text(derivedId('via:${via.id}'))]),
      ]),
  ];

  /// The board outline on Edge.Cuts.
  ///
  /// A circle is written as a real `gr_circle` rather than as the many-sided
  /// polygon the screen draws: a fabricator's milling path follows the arc,
  /// and a board ordered from a 64-gon has 64 flats on it.
  List<SList> _edgeCuts(BoardDocument document) {
    final outline = document.scene.outline;
    final id = document.board.id;

    SList stroke() => S.list('stroke', [
      S.of('width', [0.1]),
      S.of('type', [SAtom('default')]),
    ]);

    if (outline.kind == BoardOutlineKind.circle) {
      return [
        S.list('gr_circle', [
          S.of('center', [outline.center.dx, outline.center.dy]),
          // KiCad states a circle by a point on its circumference.
          S.of('end', [outline.center.dx + outline.radius, outline.center.dy]),
          stroke(),
          S.flag('fill', false),
          SList([SAtom('layer'), S.text('Edge.Cuts')]),
          SList([SAtom('uuid'), S.text(derivedId('edge:$id:circle'))]),
        ]),
      ];
    }

    final corners = outline.path;
    return [
      for (var i = 0; i < corners.length; i++)
        S.list('gr_line', [
          S.of('start', [corners[i].dx, corners[i].dy]),
          S.of('end', [
            corners[(i + 1) % corners.length].dx,
            corners[(i + 1) % corners.length].dy,
          ]),
          stroke(),
          SList([SAtom('layer'), S.text('Edge.Cuts')]),
          SList([SAtom('uuid'), S.text(derivedId('edge:$id:$i'))]),
        ]),
    ];
  }

  /// The extra edge cuts: the slots, notches and cutouts drawn on top of
  /// the board outline.
  ///
  /// Each kind gets the node KiCad has for it rather than being flattened
  /// to line segments. An arc written as a chain of chords is a curve the
  /// fabricator cannot follow with a router bit, and a circle written as a
  /// polygon is a board with flats on it.
  List<SList> _extraEdges(BoardDocument document) {
    SList stroke(double width) => S.list('stroke', [
      S.of('width', [width]),
      S.of('type', [SAtom('default')]),
    ]);

    SList layerAndId(String uuid) => SList([SAtom('uuid'), S.text(uuid)]);

    final nodes = <SList>[];
    for (final edge in document.scene.edges) {
      if (!edge.isValid) continue;
      final uuid = derivedId('edgecut:${edge.id}');
      final tail = [
        stroke(edge.width),
        SList([SAtom('layer'), S.text('Edge.Cuts')]),
        layerAndId(uuid),
      ];

      switch (edge.kind) {
        case BoardEdgeKind.line:
          nodes.add(
            S.list('gr_line', [
              S.of('start', [edge.start.dx, edge.start.dy]),
              S.of('end', [edge.end.dx, edge.end.dy]),
              ...tail,
            ]),
          );
        case BoardEdgeKind.arc:
          // KiCad states an arc by the three points it passes through,
          // which is exactly how one is stored here.
          nodes.add(
            S.list('gr_arc', [
              S.of('start', [edge.start.dx, edge.start.dy]),
              S.of('mid', [edge.mid.dx, edge.mid.dy]),
              S.of('end', [edge.end.dx, edge.end.dy]),
              ...tail,
            ]),
          );
        case BoardEdgeKind.circle:
          nodes.add(
            S.list('gr_circle', [
              S.of('center', [edge.center.dx, edge.center.dy]),
              // A point on the circumference, which is how KiCad says it.
              S.of('end', [edge.center.dx + edge.radius, edge.center.dy]),
              S.flag('fill', false),
              ...tail,
            ]),
          );
        case BoardEdgeKind.rectangle:
          final rect = edge.bounds;
          nodes.add(
            S.list('gr_rect', [
              S.of('start', [rect.left, rect.top]),
              S.of('end', [rect.right, rect.bottom]),
              S.flag('fill', false),
              ...tail,
            ]),
          );
        case BoardEdgeKind.polygon:
          // As lines rather than a `gr_poly`: a filled polygon on
          // Edge.Cuts is a shape, and what is wanted is a cut path.
          for (var i = 0; i < edge.points.length; i++) {
            final a = edge.points[i];
            final b = edge.points[(i + 1) % edge.points.length];
            nodes.add(
              S.list('gr_line', [
                S.of('start', [a.dx, a.dy]),
                S.of('end', [b.dx, b.dy]),
                stroke(edge.width),
                SList([SAtom('layer'), S.text('Edge.Cuts')]),
                layerAndId(derivedId('edgecut:${edge.id}:$i')),
              ]),
            );
          }
      }
    }
    return nodes;
  }

  /// Copper pours, written as outlines.
  ///
  /// No `filled_polygon` is emitted. The fill is not design data — it is
  /// the result of pouring this outline around every pad, track and
  /// clearance on the layer, and KiCad recomputes it on load and on every
  /// "Fill all zones". Writing a fill computed here would be a second,
  /// worse answer that goes stale the moment anything moves.
  List<SList> _zones(BoardDocument document, Map<String, int> netNumbers) {
    final nodes = <SList>[];
    for (final zone in document.scene.zones) {
      if (!zone.isValid) continue;

      final number = zone.netId == null ? 0 : (netNumbers[zone.netId] ?? 0);
      final name = number == 0 ? '' : zone.netName;

      nodes.add(
        S.list('zone', [
          S.of('net', [number]),
          SList([SAtom('net_name'), S.text(name)]),
          SList([SAtom('layer'), S.text(zone.layer.token)]),
          SList([SAtom('uuid'), S.text(derivedId('zone:${zone.id}'))]),
          S.list('hatch', [SAtom('edge'), SAtom('0.5')]),
          S.list('connect_pads', [
            S.of('clearance', [zone.clearance]),
          ]),
          S.of('min_thickness', [zone.minThickness]),
          S.list('fill', [
            SAtom('yes'),
            S.of('thermal_gap', [0.5]),
            S.of('thermal_bridge_width', [0.5]),
          ]),
          S.list('polygon', [
            S.list('pts', [
              for (final point in zone.points) S.of('xy', [point.dx, point.dy]),
            ]),
          ]),
        ]),
      );
    }
    return nodes;
  }
}
