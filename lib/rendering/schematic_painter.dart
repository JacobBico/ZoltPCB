import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../core/theme/kicad_palette.dart';
import 'schematic_painter_support.dart';
import 'schematic_scene.dart';
import '../domain/geometry/wire_router.dart';
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
    this.selectionBox,
    this.selectedWireKey,
    this.pendingPinId,
    this.highlightedNetId,
    this.showGrid = true,
    this.zigzagResistors = false,
  }) : palette = KicadPalette.current;

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

  /// The box being swept, in sheet millimetres.
  final Rect? selectionBox;

  /// The wire the user has hold of, if any. A selected wire is drawn
  /// heavier and shows a dot on each run that can be moved, so it is clear
  /// both that the wire is a thing you can grab and where to grab it.
  final String? selectedWireKey;

  final String? pendingPinId;
  final String? highlightedNetId;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _paintPage(canvas);
    if (showGrid) _paintGrid(canvas, size);
    _paintConnections(canvas);
    _paintUnits(canvas);
    _paintNetLabels(canvas);
    _paintSelectionBox(canvas);
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

  /// How tall a net label's text is drawn, in millimetres of sheet. Shared
  /// with hit-testing so a label is grabbable exactly where it is drawn.
  static const labelHeightMm = 1.6;

  /// Half the width of a label's box, in millimetres — a rough advance per
  /// character plus the chip's padding. Rough is enough: the box only has
  /// to be finger-sized and to follow the text's length.
  static double labelHalfWidthMm(String text) =>
      text.length * labelHeightMm * 0.34 + 0.9;

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
    for (final wire in scene.wires) {
      final selected = wire.key == selectedWireKey;
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

      final path = Path();
      final first = viewport.toScreen(wire.points.first);
      path.moveTo(first.dx, first.dy);
      for (final point in wire.points.skip(1)) {
        final screen = viewport.toScreen(point);
        path.lineTo(screen.dx, screen.dy);
      }
      canvas.drawPath(path, paint);
    }

    final dot = Paint()..color = colors.junction;
    final radius = math.max(2.0, viewport.lengthToScreen(0.4));
    for (final pins in scene.pinsByNet.values) {
      if (pins.length < 2) continue;
      for (final pin in pins) {
        canvas.drawCircle(viewport.toScreen(pin.sheetPosition), radius, dot);
      }
    }

    _paintWireHandles(canvas);
  }

  /// Marks the runs of the selected wire that can be dragged.
  void _paintWireHandles(Canvas canvas) {
    final key = selectedWireKey;
    if (key == null) return;

    final wire = scene.wires.where((w) => w.key == key).firstOrNull;
    if (wire == null) return;

    final fill = Paint()..color = colors.canvas;
    final ring = Paint()
      ..color = colors.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final handle in wire.handles) {
      final middle = viewport.toScreen(
        Offset(
          (handle.start.dx + handle.end.dx) / 2,
          (handle.start.dy + handle.end.dy) / 2,
        ),
      );
      canvas.drawCircle(middle, 7, fill);
      canvas.drawCircle(middle, 7, ring);

      // A short bar through the dot shows which way that run travels.
      final along = handle.moveAxis == WireAxis.horizontal
          ? const Offset(4, 0)
          : const Offset(0, 4);
      canvas.drawLine(middle - along, middle + along, ring);
    }
  }

  void _paintUnits(Canvas canvas) {
    final renderer = SymbolRenderer(viewport: viewport, colors: colors);

    for (final unit in scene.units) {
      final selected =
          unit.unit.id == selectedUnitId ||
          selectedUnitIds.contains(unit.unit.id);
      final symbol = unit.symbol;

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
    }
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

  /// The name of each named net, drawn once, on the wire.
  ///
  /// Drawn on a small filled chip: a label sitting on the drawing has to be
  /// legible where it crosses a wire, and it has to look like something you
  /// can pick up and move, because it is.
  void _paintNetLabels(Canvas canvas) {
    if (viewport.pixelsPerMm < 3.2) return;

    for (final label in scene.labels) {
      final selected = label.netId == highlightedNetId;
      final centre = viewport.toScreen(label.position);
      final fontSize = math.max(9.0, viewport.lengthToScreen(labelHeightMm));
      final halfWidth = viewport.lengthToScreen(labelHalfWidthMm(label.text));
      final halfHeight = viewport.lengthToScreen(labelHeightMm);

      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: halfWidth * 2,
          height: halfHeight * 2,
        ),
        Radius.circular(halfHeight * 0.45),
      );
      canvas.drawRRect(
        box,
        Paint()..color = colors.canvas.withValues(alpha: 0.88),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.6 : 0.9
          ..color = selected ? colors.highlight : colors.label,
      );
      drawCanvasText(
        canvas,
        text: label.text,
        anchor: Offset(centre.dx, centre.dy - fontSize * 0.5),
        color: selected ? colors.highlight : colors.label,
        fontSize: fontSize,
        align: TextAlign.center,
      );
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
      old.selectionBox != selectionBox ||
      old.selectedWireKey != selectedWireKey ||
      old.pendingPinId != pendingPinId ||
      old.highlightedNetId != highlightedNetId ||
      old.showGrid != showGrid;
}
