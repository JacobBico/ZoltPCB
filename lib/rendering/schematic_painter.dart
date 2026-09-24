import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../core/theme/kicad_palette.dart';
import 'schematic_painter_support.dart';
import 'schematic_scene.dart';
import '../domain/geometry/drawn_wire_geometry.dart';
import '../domain/models/schematic_note.dart';
import '../domain/models/sheet_views.dart';
import 'schematic_viewport.dart';
import 'symbol_renderer.dart';

/// Draws a whole schematic sheet.
class SchematicPainter extends CustomPainter {
  SchematicPainter({
    required this.scene,
    required this.viewport,
    required this.colors,
    this.selectedUnitId,
    this.selectedUnitIds = const {},
    this.selectedWireIds = const {},
    this.selectionBox,
    this.selectedWireKey,
    this.selectedWireRun,
    this.pendingPinId,
    this.pendingWire,
    this.highlightedNetId,
    this.showGrid = true,
    this.zigzagResistors = false,
    this.notes = const [],
    this.selectedNoteId,
    this.sheetBoxes = const [],
    this.selectedSheetId,
    this.offSheetLabels = const [],
  }) : palette = KicadPalette.current;

  /// The sub-sheets on this sheet, as boxes.
  final List<SheetBoxView> sheetBoxes;
  final String? selectedSheetId;

  /// Names at pins whose nets continue on another sheet.
  final List<OffSheetLabel> offSheetLabels;

  /// Text and boxes on the sheet, drawn under everything else.
  final List<SchematicNote> notes;

  /// The note the user has hold of, drawn picked out.
  final String? selectedNoteId;

  /// Draw resistors the American way. See [isResistor].
  final bool zigzagResistors;

  /// Whether a reference names a resistor of some kind: `R`, `RV` for a
  /// potentiometer, `RT` for a thermistor, `RN` for a network. Judged from
  /// the designator rather than the symbol name because that is the one
  /// thing every library agrees on.
  static bool isResistor(String reference) {
    final prefix = reference.replaceFirst(RegExp(r'[0-9?]+$'), '');
    return const {'R', 'RV', 'RT', 'RN'}.contains(prefix);
  }

  /// The palette in force when this was built, for the few colours not
  /// carried by [colors].
  final AppPalette palette;

  final SchematicScene scene;
  final SchematicViewport viewport;
  final SchematicColors colors;
  final String? selectedUnitId;

  /// Parts swept up together with a selection box.
  final Set<String> selectedUnitIds;

  /// The drawn wires swept up with them, drawn as picked out too.
  final Set<String> selectedWireIds;

  /// The box being swept, in sheet millimetres.
  final Rect? selectionBox;

  /// The wire the user has hold of, if any. A selected wire is drawn
  /// heavier and shows a dot on each run that can be moved, so it is clear
  /// both that the wire is a thing you can grab and where to grab it.
  final String? selectedWireKey;

  /// Which run of that wire is picked, when one is: only that run is drawn
  /// as selected, since the commands apply to it alone.
  final int? selectedWireRun;

  final String? pendingPinId;

  /// The wire being drawn, pin first, corners after.
  final List<Offset>? pendingWire;

  final String? highlightedNetId;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _paintPage(canvas);
    if (showGrid) _paintGrid(canvas, size);
    _paintNotes(canvas);
    _paintConnections(canvas);
    _paintUnits(canvas);
    _paintNetLabels(canvas);
    _paintSheetBoxes(canvas);
    _paintOffSheetLabels(canvas);
    _paintPendingWire(canvas);
    _paintSelectionBox(canvas);
  }

  /// Notes in KiCad's note colour: dashed frames for boxes, plain text for
  /// words, both beneath the circuit so they never hide it.
  void _paintNotes(Canvas canvas) {
    for (final note in notes) {
      final selected = note.id == selectedNoteId;
      final colour = selected ? colors.highlight : KicadPalette.notes;
      if (note.kind == NoteKind.box) {
        final rect = _rectToScreen(note.bounds);
        final paint = Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1.2;
        // Dashed, the way KiCad draws a note box.
        const dash = 6.0;
        const gap = 4.0;
        void dashed(Offset a, Offset b) {
          final length = (b - a).distance;
          if (length == 0) return;
          final step = (b - a) / length;
          for (var t = 0.0; t < length; t += dash + gap) {
            canvas.drawLine(
              a + step * t,
              a + step * math.min(t + dash, length),
              paint,
            );
          }
        }

        dashed(rect.topLeft, rect.topRight);
        dashed(rect.topRight, rect.bottomRight);
        dashed(rect.bottomRight, rect.bottomLeft);
        dashed(rect.bottomLeft, rect.topLeft);
      }
      if (note.content.isEmpty) continue;
      final fontSize = viewport.lengthToScreen(note.textSize);
      if (fontSize < 3) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: note.content,
          style: TextStyle(
            color: colour,
            fontSize: fontSize,
            height: 1.25,
            fontStyle: note.kind == NoteKind.text
                ? FontStyle.italic
                : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final inset = note.kind == NoteKind.box
          ? Offset(fontSize * 0.4, fontSize * 0.3)
          : Offset.zero;
      painter.paint(canvas, viewport.toScreen(note.position) + inset);
    }
  }

  TextPainter _label(String text, Color colour, double size) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: colour, fontSize: size, fontFamily: 'monospace'),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Sub-sheets, drawn as KiCad draws them: a box with the sheet's name
  /// above it, its file below, and its pins down the left side.
  void _paintSheetBoxes(Canvas canvas) {
    for (final view in sheetBoxes) {
      final selected = view.sheet.id == selectedSheetId;
      final colour = selected ? colors.highlight : KicadPalette.sheet;
      final rect = _rectToScreen(view.box);
      canvas
        ..drawRect(rect, Paint()..color = colour.withValues(alpha: 0.06))
        ..drawRect(
          rect,
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2.4 : 1.4,
        );
      final size = math.max(8.0, viewport.lengthToScreen(1.5));
      final name = _label(view.sheet.name, colour, size * 1.1);
      name.paint(canvas, rect.topLeft - Offset(0, name.height + 2));
      final file = _label(
        view.sheet.fileName,
        colour.withValues(alpha: 0.7),
        size * 0.85,
      );
      file.paint(canvas, rect.bottomLeft + const Offset(0, 2));
      for (var i = 0; i < view.pins.length; i++) {
        final at = viewport.toScreen(view.pinAt(i));
        final s = math.max(3.0, viewport.lengthToScreen(0.8));
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - s)
            ..lineTo(at.dx + s * 1.4, at.dy)
            ..lineTo(at.dx, at.dy + s)
            ..close(),
          Paint()..color = KicadPalette.globalLabel,
        );
        if (size < 7) continue;
        final text = _label(view.pins[i], KicadPalette.globalLabel, size);
        text.paint(canvas, at + Offset(s * 1.8, -text.height / 2));
      }
    }
  }

  /// Names at pins whose nets carry on elsewhere: a flag shape for a
  /// hierarchical label, as KiCad draws one, and plain text on the top.
  void _paintOffSheetLabels(Canvas canvas) {
    final size = math.max(8.0, viewport.lengthToScreen(1.27));
    for (final label in offSheetLabels) {
      final at = viewport.toScreen(label.at);
      final colour = label.hierarchical
          ? KicadPalette.globalLabel
          : KicadPalette.label;
      final text = _label(label.name, colour, size);
      final h = text.height + 2;
      final box = Rect.fromLTWH(at.dx + 4, at.dy - h / 2, text.width + h, h);
      if (label.hierarchical) {
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..lineTo(box.left + h / 2, box.top)
            ..lineTo(box.right, box.top)
            ..lineTo(box.right, box.bottom)
            ..lineTo(box.left + h / 2, box.bottom)
            ..close(),
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      text.paint(canvas, Offset(box.left + h / 2 + 1, box.top + 1));
    }
  }

  void _paintPendingWire(Canvas canvas) {
    final points = pendingWire;
    if (points == null || points.length < 2) return;
    final path = Path();
    final first = viewport.toScreen(points.first);
    path.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final screen = viewport.toScreen(point);
      path.lineTo(screen.dx, screen.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final corner = Paint()..color = colors.highlight;
    for (final point in points.skip(1)) {
      canvas.drawCircle(viewport.toScreen(point), 4, corner);
    }
  }

  void _paintSelectionBox(Canvas canvas) {
    final box = selectionBox;
    if (box == null) return;
    final rect = _rectToScreen(box);
    canvas
      ..drawRect(
        rect,
        Paint()..color = KicadPalette.highlight.withValues(alpha: 0.12),
      )
      ..drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = KicadPalette.highlight,
      );
  }

  /// How tall a net label's text is drawn unless it has been resized, in
  /// millimetres of sheet.
  static const labelHeightMm = NetLabel.defaultSize;

  /// Half the width of a label's text, in millimetres — a rough advance per
  /// character of the monospaced font. Shared with hit-testing, so a label
  /// is grabbable exactly where it is drawn.
  static double labelHalfWidthMm(String text, [double size = labelHeightMm]) =>
      text.length * size * 0.31 + size * 0.2;

  /// Half the height of a label's text, in millimetres.
  static double labelHalfHeightMm([double size = labelHeightMm]) => size * 0.6;

  void _paintPage(Canvas canvas) {
    final page = _rectToScreen(scene.pageRect);
    canvas.drawRect(page, Paint()..color = colors.canvas);
    canvas.drawRect(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = KicadPalette.borderStrong,
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    // KiCad's schematic grid is 1.27 mm (50 mil). Drawing every line at low
    // zoom would be a grey wash, so the fine grid appears only once it is
    // far enough apart to read.
    const fine = 1.27;
    const coarse = 12.7;

    final page = scene.pageRect;
    if (viewport.lengthToScreen(fine) >= 7) {
      _paintGridLines(canvas, page, fine, colors.grid, 0.5);
    }
    if (viewport.lengthToScreen(coarse) >= 8) {
      _paintGridLines(canvas, page, coarse, colors.gridMajor, 0.8);
    }
  }

  void _paintGridLines(
    Canvas canvas,
    Rect page,
    double stepMm,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;

    for (var x = page.left; x <= page.right; x += stepMm) {
      canvas.drawLine(
        viewport.toScreen(Offset(x, page.top)),
        viewport.toScreen(Offset(x, page.bottom)),
        paint,
      );
    }
    for (var y = page.top; y <= page.bottom; y += stepMm) {
      canvas.drawLine(
        viewport.toScreen(Offset(page.left, y)),
        viewport.toScreen(Offset(page.right, y)),
        paint,
      );
    }
  }

  /// Draws each net as direct lines between its pins.
  ///
  /// Deliberately not routed orthogonal wires. A net is a set of pins, and
  /// showing it as the connections it is — rather than inventing a route
  /// nobody chose — keeps the drawing honest about what the data says. The
  /// exporter says the same thing to KiCad using net labels.
  void _paintConnections(Canvas canvas) {
    final hops = _hops();
    for (var index = 0; index < scene.wires.length; index++) {
      final wire = scene.wires[index];
      final selected =
          (wire.key == selectedWireKey && selectedWireRun == null) ||
          (wire.drawnId != null && selectedWireIds.contains(wire.drawnId));
      final highlighted = selected || wire.netId == highlightedNetId;
      final paint = Paint()
        ..color = highlighted
            ? colors.highlight
            : colors.wire.withValues(alpha: 0.85)
        // Wide enough to be a touch target in its own right: a wire can be
        // dragged to tidy its route, so it has to be easy to land on.
        ..strokeWidth = selected ? 4.0 : (highlighted ? 3.4 : 2.4)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(_wirePath(wire, hops[index]), paint);
    }

    _paintSelectedRun(canvas);
    _paintJunctions(canvas);
    _paintLooseEnds(canvas);
  }

  /// Loose ends, per list of wires: worked out once, not every frame.
  static final _looseEndsCache = Expando<List<Offset>>();

  /// A small open square at every wire end that is joined to nothing, the
  /// way KiCad marks a dangling wire.
  void _paintLooseEnds(Canvas canvas) {
    final wires = scene.wires;
    if (wires.isEmpty) return;
    final ends = _looseEndsCache[wires] ??= DrawnWireGeometry.looseEnds(
      [for (final wire in wires) wire.points],
      anchors: [
        for (final pin in scene.pins) pin.sheetPosition,
        for (final view in sheetBoxes)
          for (var i = 0; i < view.pins.length; i++) view.pinAt(i),
      ],
    );
    if (ends.isEmpty) return;
    final half = math.max(3.5, viewport.lengthToScreen(0.5));
    final paint = Paint()
      ..color = colors.wire.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final end in ends) {
      canvas.drawRect(
        Rect.fromCenter(
          center: viewport.toScreen(end),
          width: half * 2,
          height: half * 2,
        ),
        paint,
      );
    }
  }

  /// Where each wire hops over another, by segment.
  ///
  /// Wires of different nets that cross are not connected, and on paper a
  /// little bridge is how that is said. The horizontal one hops, so that
  /// only one of the pair does.
  List<List<List<Offset>>> _hops() => hopPoints(scene.wires);

  /// Visible for testing: which crossings each wire arches over.
  static List<List<List<Offset>>> hopPoints(List<RoutedWire> wires) {
    final result = [
      for (final wire in wires)
        [for (var i = 0; i < wire.points.length - 1; i++) <Offset>[]],
    ];

    var segments = 0;
    for (final wire in wires) {
      segments += wire.points.length - 1;
    }
    // Every segment against every other, so on a very busy sheet the
    // bridges are dropped rather than the drawing slowed down.
    if (segments > 500) return result;

    for (var i = 0; i < wires.length; i++) {
      for (var s = 0; s < wires[i].points.length - 1; s++) {
        final a1 = wires[i].points[s];
        final a2 = wires[i].points[s + 1];
        if ((a1.dy - a2.dy).abs() > 1e-6) continue; // the horizontal hops
        for (var j = 0; j < wires.length; j++) {
          if (i == j || wires[j].netId == wires[i].netId) continue;
          for (var t = 0; t < wires[j].points.length - 1; t++) {
            final at = DrawnWireGeometry.crossing(
              a1,
              a2,
              wires[j].points[t],
              wires[j].points[t + 1],
            );
            if (at != null) result[i][s].add(at);
          }
        }
      }
    }
    return result;
  }

  /// A wire's path, arching over the wires it crosses without touching.
  Path _wirePath(RoutedWire wire, List<List<Offset>> hops) => hoppedPath(
    [for (final point in wire.points) viewport.toScreen(point)],
    [
      for (final crossings in hops)
        [for (final at in crossings) viewport.toScreen(at)],
    ],
    // Big enough to read as a bridge at arm's length. A hop the width of
    // the wire itself is no hop at all.
    math.max(5.0, viewport.lengthToScreen(0.9)),
  );

  /// Visible for testing: [points] drawn with a semicircle over each of the
  /// crossings in [hops], which are given per segment.
  static Path hoppedPath(
    List<Offset> points,
    List<List<Offset>> hops,
    double radius,
  ) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);

    for (var s = 0; s < points.length - 1; s++) {
      final a = points[s];
      final b = points[s + 1];
      final rightwards = b.dx >= a.dx;
      final crossings = [...?hops.elementAtOrNull(s)]
        ..sort(
          (p, q) => rightwards ? p.dx.compareTo(q.dx) : q.dx.compareTo(p.dx),
        );

      for (final centre in crossings) {
        // Not so near an end that the arch would swallow the corner.
        if ((centre - a).distance < radius * 1.2 ||
            (centre - b).distance < radius * 1.2) {
          continue;
        }
        final before = Offset(
          centre.dx + (rightwards ? -radius : radius),
          centre.dy,
        );
        path.lineTo(before.dx, before.dy);
        // Over the top either way round, so the bridge always arches away
        // from the wire underneath rather than into it.
        path.arcTo(
          Rect.fromCircle(center: centre, radius: radius),
          rightwards ? math.pi : 0,
          rightwards ? math.pi : -math.pi,
          false,
        );
      }
      path.lineTo(b.dx, b.dy);
    }
    return path;
  }

  /// Dots the junctions: where three or more wire ends meet, or a wire ends
  /// on the middle of another.
  ///
  /// Only there. A wire turning a corner is not a junction, and a dot at
  /// every corner says a net is joined up in places it simply is not.
  void _paintJunctions(Canvas canvas) {
    final byNet = <String, List<List<Offset>>>{};
    for (final wire in scene.wires) {
      (byNet[wire.netId] ??= []).add(wire.points);
    }

    final radius = math.max(2.0, viewport.lengthToScreen(0.4));
    final paint = Paint()..color = colors.junction;
    for (final entry in byNet.entries) {
      final dots = DrawnWireGeometry.junctions(
        entry.value,
        pins: [
          for (final pin in scene.pinsByNet[entry.key] ?? const <PlacedPin>[])
            pin.sheetPosition,
        ],
      );
      for (final point in dots) {
        canvas.drawCircle(viewport.toScreen(point), radius, paint);
      }
    }
  }

  /// Picks out the one run of wire the commands apply to.
  void _paintSelectedRun(Canvas canvas) {
    final key = selectedWireKey;
    final run = selectedWireRun;
    if (key == null || run == null) return;
    final wire = scene.wires.where((w) => w.key == key).firstOrNull;
    if (wire == null || run + 1 >= wire.points.length) return;

    canvas.drawLine(
      viewport.toScreen(wire.points[run]),
      viewport.toScreen(wire.points[run + 1]),
      Paint()
        ..color = colors.highlight
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintUnits(Canvas canvas) {
    final renderer = SymbolRenderer(viewport: viewport, colors: colors);

    for (final unit in scene.units) {
      final selected =
          unit.unit.id == selectedUnitId ||
          selectedUnitIds.contains(unit.unit.id);
      final symbol = unit.symbol;

      // A part marked do-not-populate is drawn faded, with a cross over
      // it: still on the sheet, in the BOM and on the board, but plainly
      // not one that gets fitted.
      final dnp = unit.part.dnp;
      if (dnp) {
        canvas.saveLayer(
          null,
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.38),
        );
      }

      if (symbol != null) {
        renderer.paintGraphics(
          canvas,
          symbol: symbol,
          unit: unit.unit.unitNumber,
          placement: unit.placement,
          bodyStyle: unit.unit.bodyStyle,
          selected: selected,
          rectanglesAsZigzag:
              zigzagResistors && isResistor(unit.part.reference),
        );
      } else {
        _paintMissingSymbol(canvas, unit, selected);
      }

      renderer.paintPins(
        canvas,
        pins: unit.pins.map((p) => p.pin),
        placement: unit.placement,
        pinNamesHidden: symbol?.pinNamesHidden ?? false,
        pinNamesOffset: symbol?.pinNamesOffset ?? 0.508,
        pinNumbersHidden: symbol?.pinNumbersHidden ?? false,
        highlightedPinIds: {
          for (final pin in unit.pins)
            if (pin.id == pendingPinId ||
                (highlightedNetId != null && pin.netId == highlightedNetId))
              pin.id,
        },
        selected: selected,
      );

      _paintFields(canvas, unit, selected);
      if (dnp) {
        canvas.restore();
        _paintDnpMark(canvas, unit);
      }
    }
  }

  /// A cross over a do-not-populate part's body, and a small tag saying so.
  void _paintDnpMark(Canvas canvas, PlacedUnit unit) {
    final body = _rectToScreen(scene.bodyBoundsOf(unit)).inflate(2);
    final paint = Paint()
      ..color = KicadPalette.error.withValues(alpha: 0.8)
      ..strokeWidth = math.max(1.2, viewport.lengthToScreen(0.2))
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(body.topLeft, body.bottomRight, paint)
      ..drawLine(body.topRight, body.bottomLeft, paint);
    final fontSize = math.max(8.0, viewport.lengthToScreen(1.0));
    final tag = TextPainter(
      text: TextSpan(
        text: 'DNP',
        style: TextStyle(
          color: KicadPalette.error,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tag.paint(canvas, Offset(body.left, body.bottom + 1));
  }

  /// A dashed outline standing in for a symbol whose library is gone.
  void _paintMissingSymbol(Canvas canvas, PlacedUnit unit, bool selected) {
    final bounds = _rectToScreen(scene.boundsOf(unit));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = selected ? colors.highlight : KicadPalette.warning;
    canvas.drawRect(bounds.inflate(2), paint);
  }

  /// The designator and value beside a symbol.
  ///
  /// Everything here is placed in sheet millimetres and converted once, at
  /// the end. It used to be laid out in screen pixels — a fixed six-pixel
  /// gap, a four-pixel lift — against a box that grows with the zoom, so
  /// the text crept towards the symbol as you zoomed in and away as you
  /// zoomed out. On a power symbol, whose body is a few millimetres across,
  /// that crawl was most of the symbol's width: the label appeared to jump
  /// about as the sheet moved.
  void _paintFields(Canvas canvas, PlacedUnit unit, bool selected) {
    if (viewport.pixelsPerMm < 2.6) return;
    // Taken off the drawing on purpose. Still exported, still in the BOM.
    if (unit.part.fieldsHidden) return;

    final color = selected ? colors.highlight : colors.fieldText;
    final fontSize = math.max(9.0, viewport.lengthToScreen(fieldHeightMm));

    var reference = unit.part.reference;
    if (unit.part.isMultiUnit) {
      // KiCad writes multi-unit designators as U1A, U1B, and so on.
      reference = '$reference${_unitSuffix(unit.unit.unitNumber)}';
    }

    final places = fieldPlacement(
      bounds: scene.boundsOf(unit),
      reference: unit.part.reference,
    );

    if (places.reference case final at?) {
      drawCanvasText(
        canvas,
        text: reference,
        anchor: viewport.toScreen(at),
        color: color,
        fontSize: fontSize,
        align: places.align,
        anchorAtBottom: places.referenceAtBottom,
      );
    }
    if (unit.part.value.isNotEmpty) {
      drawCanvasText(
        canvas,
        text: unit.part.value,
        anchor: viewport.toScreen(places.value),
        color: color.withValues(alpha: 0.85),
        fontSize: fontSize,
        align: places.align,
        anchorAtBottom: places.valueAtBottom,
      );
    }
  }

  /// Where a unit's designator and value sit, in sheet millimetres.
  ///
  /// Sheet millimetres, not screen pixels, is the whole point: anything
  /// measured in pixels against a box that scales with the zoom drifts as
  /// the drawing is zoomed, which is what made a power symbol's label
  /// appear to crawl around it.
  ///
  /// A null [reference] anchor means the designator is not drawn at all.
  /// KiCad's power symbols carry a `#PWR` designator it never shows — the
  /// part is a label with a shape, not a component — and "#PWR03" printed
  /// beside every ground is noise on top of noise.
  static ({
    Offset? reference,
    Offset value,
    TextAlign align,
    bool referenceAtBottom,
    bool valueAtBottom,
  })
  fieldPlacement({required Rect bounds, required String reference}) {
    final isPower = SchematicScene.isPowerReference(reference);

    // Put the fields on whichever axis the pins do not use. A resistor or
    // capacitor has its pins at top and bottom, so a designator centred
    // above the body sits exactly where the wire leaves — and the wire is
    // then drawn straight through the text. KiCad places R and C fields
    // beside the body for the same reason.
    final pinsRunVertically = bounds.height >= bounds.width;

    if (pinsRunVertically) {
      final left = bounds.right + fieldGapMm;
      return (
        reference: isPower
            ? null
            : Offset(left, bounds.center.dy - fieldHeightMm * 0.15),
        value: Offset(
          left,
          bounds.center.dy +
              (isPower ? -fieldHeightMm / 2 : fieldHeightMm * 0.15),
        ),
        align: TextAlign.left,
        referenceAtBottom: true,
        valueAtBottom: false,
      );
    }

    return (
      reference: isPower
          ? null
          : Offset(bounds.center.dx, bounds.top - fieldGapMm),
      value: Offset(
        bounds.center.dx,
        isPower ? bounds.top - fieldGapMm : bounds.bottom + fieldGapMm,
      ),
      align: TextAlign.center,
      referenceAtBottom: true,
      valueAtBottom: isPower,
    );
  }

  /// Field text height, in millimetres of sheet — KiCad's own 1.27 mm.
  static const fieldHeightMm = 1.27;

  /// The gap between a symbol and its fields, in millimetres.
  static const fieldGapMm = 0.9;

  /// The name of each named net, drawn once, just above its wire.
  ///
  /// Plain text, the way KiCad draws a label, with a thin outline in the
  /// sheet's own colour so it stays legible where it crosses a wire. A box
  /// appears round it only while it is picked, to show what a drag will
  /// move.
  void _paintNetLabels(Canvas canvas) {
    if (viewport.pixelsPerMm < 3.2) return;

    for (final label in scene.labels) {
      final selected = label.netId == highlightedNetId;
      final colour = selected ? colors.highlight : colors.label;
      final centre = viewport.toScreen(label.position);
      final fontSize = math.max(8.0, viewport.lengthToScreen(label.size));

      TextPainter text(Paint foreground) => TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            foreground: foreground,
            fontSize: fontSize,
            fontFamily: 'monospace',
            fontFamilyFallback: const ['monospace', 'Roboto Mono', 'Courier'],
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final halo = text(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, fontSize * 0.22)
          ..strokeJoin = StrokeJoin.round
          ..color = colors.canvas.withValues(alpha: 0.9),
      );
      final ink = text(Paint()..color = colour);
      final topLeft = centre - Offset(ink.width / 2, ink.height / 2);
      halo.paint(canvas, topLeft);
      ink.paint(canvas, topLeft);

      if (selected) {
        canvas.drawRect(
          Rect.fromCenter(
            center: centre,
            width: ink.width + 6,
            height: ink.height + 4,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = colors.highlight.withValues(alpha: 0.7),
        );
      }
    }
  }

  Rect _rectToScreen(Rect sheet) => Rect.fromPoints(
    viewport.toScreen(sheet.topLeft),
    viewport.toScreen(sheet.bottomRight),
  );

  static String _unitSuffix(int unit) {
    if (unit < 1) return '';
    // 1 -> A, 26 -> Z, 27 -> AA.
    var value = unit;
    final buffer = StringBuffer();
    while (value > 0) {
      final index = (value - 1) % 26;
      buffer.write(String.fromCharCode(65 + index));
      value = (value - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  bool shouldRepaint(SchematicPainter old) =>
      // A new theme arrives as new colours with the same scene, and would
      // otherwise leave the canvas in the old palette until something moved.
      old.colors != colors ||
      old.palette != palette ||
      old.zigzagResistors != zigzagResistors ||
      old.scene != scene ||
      old.viewport.pixelsPerMm != viewport.pixelsPerMm ||
      old.viewport.origin != viewport.origin ||
      old.selectedUnitId != selectedUnitId ||
      !setEquals(old.selectedUnitIds, selectedUnitIds) ||
      !setEquals(old.selectedWireIds, selectedWireIds) ||
      old.selectionBox != selectionBox ||
      old.selectedWireKey != selectedWireKey ||
      old.selectedWireRun != selectedWireRun ||
      old.pendingPinId != pendingPinId ||
      !listEquals(old.pendingWire, pendingWire) ||
      old.highlightedNetId != highlightedNetId ||
      old.showGrid != showGrid ||
      !listEquals(old.notes, notes) ||
      old.sheetBoxes != sheetBoxes ||
      old.selectedSheetId != selectedSheetId ||
      old.offSheetLabels != offSheetLabels ||
      old.selectedNoteId != selectedNoteId;
}
