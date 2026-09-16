import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart' show FillType;
import '../../rendering/schematic_viewport.dart';

/// Draws the board.
///
/// Layer order matters and is KiCad's: the inactive copper layer goes down
/// first and dimmed, then the active one at full strength, then pads, then
/// silkscreen, then the things that are not really on the board at all —
/// the ratsnest and whatever is being drawn right now.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.scene,
    required this.viewport,
    required this.activeLayer,
    this.selectedFootprintId,
    this.selectedTrackId,
    this.highlightedNetId,
    this.pendingRoute = const [],
    this.pendingLayer,
    this.pendingWidth,
    this.routeClashes = const [],
    this.showRatsnest = true,
    this.showOutlineGrips = false,
    this.draggingOutline = false,
    this.routeTargetPad,
    this.selectedOutlineHandle,
    this.selectedEdgeId,
    this.selectedZoneId,
    this.selectedTextId,
    this.selectedLabelId,
    this.fabPreview = false,
    this.fabBack = false,
  }) : palette = KicadPalette.current;

  /// The extra edge cut the user has hold of, if any.
  final String? selectedEdgeId;

  /// The copper pour the user has hold of, if any.
  final String? selectedZoneId;

  /// The free silkscreen text the user has hold of, if any.
  final String? selectedTextId;

  /// The footprint whose designator the user has hold of, if any.
  final String? selectedLabelId;

  /// Draw the board as it will come back from the fabricator rather than as
  /// an editor draws it. See [_paintFabPreview].
  final bool fabPreview;

  /// In the preview, look at the underside — mirrored, the way it looks
  /// when the board is turned over in your hand.
  final bool fabBack;

  /// The palette in force when this was built. Compared on repaint, so a
  /// theme change repaints the board even when nothing on it moved.
  final AppPalette palette;

  final BoardScene scene;
  final SchematicViewport viewport;
  final CopperLayer activeLayer;
  final String? selectedFootprintId;
  final String? selectedTrackId;
  final String? highlightedNetId;

  /// The route the finger is drawing, in board millimetres.
  final List<Offset> pendingRoute;
  final CopperLayer? pendingLayer;

  /// Width the route will be laid at; the design rule when null.
  final double? pendingWidth;

  /// Where the route being drawn is too close to other copper.
  final List<RouteClash> routeClashes;

  final bool showRatsnest;

  /// Whether the board outline shows the corners that can be dragged.
  /// Only in placement mode — while routing they are one more thing to
  /// catch a finger that was aiming for a pad.
  final bool showOutlineGrips;
  final bool draggingOutline;

  /// The pad a route in progress would finish on. Drawn with a ring so the
  /// finger covering it still knows it has caught.
  final PlacedPad? routeTargetPad;

  /// Which outline handle is selected, so its verbs can apply to it.
  final int? selectedOutlineHandle;

  static Color colorFor(CopperLayer layer) => switch (layer) {
    CopperLayer.front => KicadPalette.frontCopper,
    CopperLayer.back => KicadPalette.backCopper,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (fabPreview) {
      _paintFabPreview(canvas, size);
      return;
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = KicadPalette.boardCanvas,
    );

    _paintGrid(canvas, size);
    // Pours go under everything: they are the background copper, and a
    // track drawn over one has to stay readable.
    _paintZones(canvas);
    _paintOutline(canvas);
    _paintEdges(canvas);

    // The layer you are not working on stays visible but recedes, so it
    // still tells you where you cannot go without competing for attention.
    _paintTracks(canvas, activeLayer.other, dimmed: true);
    _paintTracks(canvas, activeLayer, dimmed: false);
    _paintVias(canvas);

    _paintFootprints(canvas);
    _paintTexts(canvas);
    if (showRatsnest) _paintRatsnest(canvas);
    _paintPendingRoute(canvas);
  }

  // --- fabrication preview ---------------------------------------------

  // Real-world colours, deliberately not from the palette: this view exists
  // to show what the board will physically look like, and a Halloween
  // solder mask is not something a fab will make.
  static const _mask = Color(0xFF1B5E30);
  static const _maskOverCopper = Color(0xFF2E8046);
  static const _gold = Color(0xFFD9B44A);
  static const _silk = Color(0xFFF4F4F0);
  static const _hole = Color(0xFF0A0A0C);

  /// The board as manufactured: green mask cut to the outline, copper just
  /// visible through it, exposed pads in ENIG gold, white silkscreen.
  ///
  /// No ratsnest, no courtyards, no grid — none of that is on a real board,
  /// and the point is to see the one you are about to order.
  void _paintFabPreview(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);

    final side = fabBack ? CopperLayer.back : CopperLayer.front;
    final silkLayer = fabBack ? BoardLayer.backSilk : BoardLayer.frontSilk;

    canvas.save();
    if (fabBack) {
      // Turned over about the board's centre, left to right.
      final centre = viewport.toScreen(scene.outlineBounds.center);
      canvas
        ..translate(centre.dx, 0)
        ..scale(-1, 1)
        ..translate(-centre.dx, 0);
    }

    // The substrate, cut to shape — outline less every closed cutout.
    final outline = _manufacturedPath();
    canvas
      ..save()
      ..clipPath(outline)
      ..drawPath(outline, Paint()..color = _mask);

    // Copper under the mask, a shade lighter — which is how a finished
    // board shows its tracks.
    for (final track in scene.tracks) {
      if (track.layer != side) continue;
      canvas.drawLine(
        viewport.toScreen(Offset(track.startX, track.startY)),
        viewport.toScreen(Offset(track.endX, track.endY)),
        Paint()
          ..color = _maskOverCopper
          ..strokeWidth = math.max(1.0, viewport.lengthToScreen(track.width))
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tented vias: under the mask on both sides.
    for (final via in scene.vias) {
      final centre = viewport.toScreen(Offset(via.x, via.y));
      canvas
        ..drawCircle(
          centre,
          math.max(2.0, viewport.lengthToScreen(via.diameter / 2)),
          Paint()..color = _maskOverCopper,
        )
        ..drawCircle(
          centre,
          math.max(1.0, viewport.lengthToScreen(via.drill / 2)),
          Paint()..color = _hole,
        );
    }

    // Exposed pads.
    for (final pad in scene.pads) {
      if (!pad.reaches(side)) continue;
      _paintFabPad(canvas, pad);
    }

    // Silkscreen for the side being looked at.
    for (final footprint in scene.footprints) {
      final definition = footprint.definition;
      if (definition != null) {
        for (final graphic in definition.graphics) {
          if (footprint.placement.layerOf(graphic.layer) != silkLayer) {
            continue;
          }
          _paintFabGraphic(canvas, footprint, graphic);
        }
      }

      // The designator, as it will be printed. It used to be drawn only
      // when the part happened to be wide enough on screen, which at any
      // ordinary zoom meant a finished board with no R1 or C1 on it.
      final ref = footprint.ref;
      if (ref.side != side || ref.labelHidden) continue;
      final height = viewport.lengthToScreen(ref.labelSize);
      if (height < 2) continue;
      _paintSilkText(
        canvas,
        footprint.part.reference,
        viewport.toScreen(footprint.labelPosition),
        height: height,
        rotation: 0,
        color: _silk,
        weight: FontWeight.w700,
        // The canvas is already turned over for the underside, so back-side
        // text is un-mirrored here to read the right way round, the way it
        // does when you turn the real board over.
        mirror: fabBack,
      );
    }

    for (final text in scene.texts) {
      if (text.back != fabBack) continue;
      final height = viewport.lengthToScreen(text.size);
      if (height < 2) continue;
      _paintSilkText(
        canvas,
        text.content,
        viewport.toScreen(text.position),
        height: height,
        rotation: text.rotation,
        color: _silk,
        weight: FontWeight.w700,
        mirror: fabBack,
      );
    }
    canvas.restore();

    // The milled edge, a hairline — the mask stops here.
    final milled = Paint()
      ..color = const Color(0xFF0F3A1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(outline, milled);

    // Open cuts — a slot, a score line — are a path the router follows
    // rather than a hole, so they are drawn rather than subtracted.
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      if (edge.kind != BoardEdgeKind.line && edge.kind != BoardEdgeKind.arc) {
        continue;
      }
      canvas.drawPath(edge.path.transform(_toScreenMatrix()), milled);
    }
    canvas.restore();
  }

  Path _outlinePath() {
    final outline = scene.outline;
    if (outline.kind == BoardOutlineKind.circle) {
      return Path()..addOval(
        Rect.fromCircle(
          center: viewport.toScreen(outline.center),
          radius: viewport.lengthToScreen(outline.radius),
        ),
      );
    }
    final corners = outline.path;
    final path = Path();
    if (corners.isEmpty) return path;
    final first = viewport.toScreen(corners.first);
    path.moveTo(first.dx, first.dy);
    for (final corner in corners.skip(1)) {
      final point = viewport.toScreen(corner);
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// The board's shape as it will be milled: the outline, less every closed
  /// cut inside it.
  ///
  /// A cutout is a hole in the board, so it has to be a hole in the mask
  /// and the copper too — which means subtracting it from the outline
  /// rather than drawing it on top. Open cuts are a line the router
  /// follows and are drawn as such.
  Path _manufacturedPath() {
    var path = _outlinePath();
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      final closed =
          edge.kind == BoardEdgeKind.circle ||
          edge.kind == BoardEdgeKind.rectangle ||
          edge.kind == BoardEdgeKind.polygon;
      if (!closed) continue;
      path = Path.combine(
        PathOperation.difference,
        path,
        edge.path.transform(_toScreenMatrix()),
      );
    }
    return path;
  }

  void _paintFabPad(Canvas canvas, PlacedPad pad) {
    final centre = viewport.toScreen(pad.position);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(-pad.angle * math.pi / 180);

    final w = viewport.lengthToScreen(pad.pad.sizeX);
    final h = viewport.lengthToScreen(pad.pad.sizeY);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final paint = Paint()..color = _gold;

    switch (pad.pad.shape) {
      case PadShape.circle:
        canvas.drawCircle(Offset.zero, w / 2, paint);
      case PadShape.oval:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(math.min(w, h) / 2)),
          paint,
        );
      case PadShape.roundrect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(w, h) * pad.pad.roundrectRatio),
          ),
          paint,
        );
      case PadShape.rect || PadShape.trapezoid || PadShape.custom:
        canvas.drawRect(rect, paint);
    }
    if (pad.pad.drill > 0) {
      canvas.drawCircle(
        Offset.zero,
        viewport.lengthToScreen(pad.pad.drill / 2),
        Paint()..color = _hole,
      );
    }
    canvas.restore();
  }

  void _paintFabGraphic(
    Canvas canvas,
    PlacedFootprint footprint,
    FootprintGraphic graphic,
  ) {
    final paint = Paint()
      ..color = _silk
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        0.8,
        viewport.lengthToScreen(
          graphic.stroke.width <= 0 ? 0.12 : graphic.stroke.width,
        ),
      );
    Offset at(FootprintPoint point) =>
        viewport.toScreen(footprint.placement.applyPoint(point));

    switch (graphic) {
      case FootprintLine(:final start, :final end):
        canvas.drawLine(at(start), at(end), paint);
      case FootprintRect(:final start, :final end):
        canvas.drawRect(Rect.fromPoints(at(start), at(end)), paint);
      case FootprintCircle(:final center):
        canvas.drawCircle(
          at(center),
          viewport.lengthToScreen(graphic.radius),
          paint,
        );
      case FootprintArc(:final start, :final mid, :final end):
        canvas
          ..drawLine(at(start), at(mid), paint)
          ..drawLine(at(mid), at(end), paint);
      case FootprintPolygon(:final points):
        if (points.length < 2) return;
        final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
        for (final point in points.skip(1)) {
          path.lineTo(at(point).dx, at(point).dy);
        }
        canvas.drawPath(path..close(), paint);
    }
  }

  // --- background ------------------------------------------------------

  void _paintGrid(Canvas canvas, Size size) {
    final step = viewport.lengthToScreen(scene.board.gridMm);
    // Below about four pixels a grid is a wash of colour rather than a
    // reference, so it simply stops being drawn.
    if (step < 4) return;

    final paint = Paint()
      ..color = KicadPalette.boardGrid
      ..strokeWidth = 1;

    final firstX = viewport.origin.dx % step;
    for (var x = firstX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final firstY = viewport.origin.dy % step;
    for (var y = firstY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// The extra shapes on Edge.Cuts: slots, cutouts, rounded corners.
  void _paintEdges(Canvas canvas) {
    if (scene.edges.isEmpty) return;

    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      final selected = edge.id == selectedEdgeId;
      final paint = Paint()
        ..color = selected ? KicadPalette.highlight : KicadPalette.edgeCuts
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.8 : 1.5;

      // Built in board millimetres and then transformed, so an arc stays an
      // arc: rebuilding it from screen points would need the circle solved
      // twice, once in each space.
      canvas.drawPath(edge.path.transform(_toScreenMatrix()), paint);

      if (selected) {
        for (final point in edge.points) {
          canvas.drawCircle(
            viewport.toScreen(point),
            5,
            Paint()..color = KicadPalette.highlight,
          );
        }
      }
    }
  }

  /// Board millimetres to screen pixels, as a matrix, for transforming a
  /// whole path at once.
  Float64List _toScreenMatrix() {
    final scale = viewport.pixelsPerMm;
    final origin = viewport.toScreen(Offset.zero);
    return Matrix4.identity().storage
      ..[0] = scale
      ..[5] = scale
      ..[12] = origin.dx
      ..[13] = origin.dy;
  }

  /// Copper pours, drawn as a translucent wash with a hatched edge.
  ///
  /// Not solid. A pour covers most of the board, and a solid one would hide
  /// every track under it — which is exactly the thing you are looking at
  /// when you have a pour. KiCad hatches them for the same reason.
  void _paintZones(Canvas canvas) {
    if (scene.zones.isEmpty) return;

    for (final zone in scene.zones) {
      if (!zone.isValid) continue;
      final onActive = zone.layer == activeLayer.layer;
      final base = zone.layer == BoardLayer.frontCopper
          ? KicadPalette.frontCopper
          : KicadPalette.backCopper;
      final selected = zone.id == selectedZoneId;

      final path = zone.path.transform(_toScreenMatrix());
      canvas.drawPath(
        path,
        Paint()..color = base.withValues(alpha: onActive ? 0.18 : 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.6 : 1.2
          ..color = selected
              ? KicadPalette.highlight
              : base.withValues(alpha: onActive ? 0.9 : 0.45),
      );

      // The net's name in the middle, which is the only question anyone
      // asks of a pour.
      if (zone.netName.isNotEmpty && viewport.pixelsPerMm > 2) {
        _paintText(
          canvas,
          zone.netName,
          viewport.toScreen(zone.bounds.center),
          color: base.withValues(alpha: onActive ? 0.95 : 0.5),
          size: 10,
        );
      }
    }
  }

  void _paintOutline(Canvas canvas) {
    final outline = scene.outline;
    final color = draggingOutline
        ? KicadPalette.highlight
        : KicadPalette.edgeCuts;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = draggingOutline ? 2.5 : 1.5;

    if (outline.kind == BoardOutlineKind.circle) {
      canvas.drawCircle(
        viewport.toScreen(outline.center),
        viewport.lengthToScreen(outline.radius),
        paint,
      );
    } else {
      final corners = outline.path;
      if (corners.length >= 2) {
        final path = Path()
          ..moveTo(
            viewport.toScreen(corners.first).dx,
            viewport.toScreen(corners.first).dy,
          );
        for (final corner in corners.skip(1)) {
          final screen = viewport.toScreen(corner);
          path.lineTo(screen.dx, screen.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    final bounds = Rect.fromPoints(
      viewport.toScreen(outline.bounds.topLeft),
      viewport.toScreen(outline.bounds.bottomRight),
    );

    // The size, written along the top edge. A board is ordered by its
    // dimensions, so they should never be more than a glance away.
    _paintText(
      canvas,
      outline.kind == BoardOutlineKind.circle
          ? '⌀ ${_mm(outline.radius * 2)} mm'
          : '${_mm(outline.bounds.width)} × '
                '${_mm(outline.bounds.height)} mm',
      Offset(bounds.center.dx, bounds.top - 9),
      color: color,
      size: 9,
    );

    if (!showOutlineGrips) return;

    // Midpoint marks come first so a corner grip drawn over one still wins
    // the eye. Tapping a midpoint is how a polygon gains a corner.
    if (outline.kind == BoardOutlineKind.polygon) {
      final corners = outline.path;
      for (var i = 0; i < corners.length; i++) {
        final middle = Offset.lerp(
          corners[i],
          corners[(i + 1) % corners.length],
          0.5,
        )!;
        canvas.drawCircle(
          viewport.toScreen(middle),
          3.5,
          Paint()..color = color.withValues(alpha: 0.55),
        );
      }
    }

    final handles = outline.handles;
    for (var i = 0; i < handles.length; i++) {
      final screen = viewport.toScreen(handles[i]);
      final selected = i == selectedOutlineHandle;

      // A circle's centre is a different job from its edge, so it gets a
      // different mark: one moves the board, the other resizes it.
      final isCentre = outline.kind == BoardOutlineKind.circle && i == 0;
      final size = selected ? 12.0 : 9.0;

      if (isCentre) {
        canvas
          ..drawCircle(
            screen,
            size / 2,
            Paint()..color = KicadPalette.boardCanvas,
          )
          ..drawCircle(
            screen,
            size / 2,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        continue;
      }

      canvas
        ..drawRect(
          Rect.fromCenter(center: screen, width: size, height: size),
          Paint()..color = KicadPalette.boardCanvas,
        )
        ..drawRect(
          Rect.fromCenter(center: screen, width: size, height: size),
          Paint()
            ..color = selected ? KicadPalette.highlight : color
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2.5 : 1.5,
        );
    }
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  // --- copper ----------------------------------------------------------

  void _paintTracks(Canvas canvas, CopperLayer layer, {required bool dimmed}) {
    for (final track in scene.tracks) {
      if (track.layer != layer) continue;

      final selected = track.id == selectedTrackId;
      final highlighted =
          highlightedNetId != null && track.netId == highlightedNetId;

      var color = colorFor(layer);
      if (dimmed) color = color.withValues(alpha: 0.35);
      if (highlighted) color = KicadPalette.highlight;
      if (selected) color = KicadPalette.highlight;

      canvas.drawLine(
        viewport.toScreen(Offset(track.startX, track.startY)),
        viewport.toScreen(Offset(track.endX, track.endY)),
        Paint()
          ..color = color
          ..strokeWidth = math.max(1.0, viewport.lengthToScreen(track.width))
          ..strokeCap = StrokeCap.round,
      );

      if (selected) {
        canvas.drawLine(
          viewport.toScreen(Offset(track.startX, track.startY)),
          viewport.toScreen(Offset(track.endX, track.endY)),
          Paint()
            ..color = KicadPalette.highlight.withValues(alpha: 0.25)
            ..strokeWidth =
                math.max(1.0, viewport.lengthToScreen(track.width)) + 8
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintVias(Canvas canvas) {
    for (final via in scene.vias) {
      final center = viewport.toScreen(Offset(via.x, via.y));
      canvas.drawCircle(
        center,
        math.max(2.0, viewport.lengthToScreen(via.diameter / 2)),
        Paint()..color = KicadPalette.padThroughHole,
      );
      canvas.drawCircle(
        center,
        math.max(1.0, viewport.lengthToScreen(via.drill / 2)),
        Paint()..color = KicadPalette.drill,
      );
    }
  }

  // --- footprints ------------------------------------------------------

  void _paintFootprints(Canvas canvas) {
    for (final footprint in scene.footprints) {
      final selected = footprint.ref.id == selectedFootprintId;
      final definition = footprint.definition;

      if (definition == null) {
        _paintMissing(canvas, footprint, selected: selected);
        continue;
      }

      for (final graphic in definition.graphics) {
        _paintGraphic(canvas, footprint, graphic);
      }
      for (final pad in footprint.pads) {
        _paintPad(canvas, pad);
      }
      _paintReference(canvas, footprint, selected: selected);

      if (selected) {
        final rect = Rect.fromPoints(
          viewport.toScreen(footprint.bounds.topLeft),
          viewport.toScreen(footprint.bounds.bottomRight),
        ).inflate(3);
        canvas.drawRect(
          rect,
          Paint()
            ..color = KicadPalette.highlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  /// A footprint whose library is gone. Drawn as an explicit gap rather
  /// than left out: a part silently missing from the board is worse than
  /// one that says it is missing.
  void _paintMissing(
    Canvas canvas,
    PlacedFootprint footprint, {
    required bool selected,
  }) {
    final rect = Rect.fromPoints(
      viewport.toScreen(footprint.bounds.topLeft),
      viewport.toScreen(footprint.bounds.bottomRight),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = selected ? KicadPalette.highlight : KicadPalette.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas
      ..drawLine(
        rect.topLeft,
        rect.bottomRight,
        Paint()
          ..color = KicadPalette.error
          ..strokeWidth = 1,
      )
      ..drawLine(
        rect.topRight,
        rect.bottomLeft,
        Paint()
          ..color = KicadPalette.error
          ..strokeWidth = 1,
      );
    _paintReference(canvas, footprint, selected: selected);
  }

  void _paintGraphic(
    Canvas canvas,
    PlacedFootprint footprint,
    FootprintGraphic graphic,
  ) {
    final layer = footprint.placement.layerOf(graphic.layer);
    final color = _graphicColor(layer);
    if (color == null) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        0.7,
        viewport.lengthToScreen(
          graphic.stroke.width <= 0 ? 0.1 : graphic.stroke.width,
        ),
      );

    Offset at(FootprintPoint point) =>
        viewport.toScreen(footprint.placement.applyPoint(point));

    switch (graphic) {
      case FootprintLine(:final start, :final end):
        canvas.drawLine(at(start), at(end), paint);
      case FootprintRect(:final start, :final end, :final fill):
        final rect = Rect.fromPoints(at(start), at(end));
        if (fill != FillType.none) {
          canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.2));
        }
        canvas.drawRect(rect, paint);
      case FootprintCircle(:final center):
        canvas.drawCircle(
          at(center),
          viewport.lengthToScreen(graphic.radius),
          paint,
        );
      case FootprintArc(:final start, :final mid, :final end):
        // Three points, drawn as two chords. An arc this small on a phone
        // screen is a pixel or two from the true curve, and the alternative
        // is solving for the centre on every frame.
        canvas
          ..drawLine(at(start), at(mid), paint)
          ..drawLine(at(mid), at(end), paint);
      case FootprintPolygon(:final points, :final fill):
        if (points.length < 2) return;
        final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
        for (final point in points.skip(1)) {
          path.lineTo(at(point).dx, at(point).dy);
        }
        path.close();
        if (fill != FillType.none) {
          canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
        }
        canvas.drawPath(path, paint);
    }
  }

  Color? _graphicColor(BoardLayer? layer) => switch (layer) {
    BoardLayer.frontSilk ||
    BoardLayer.backSilk => KicadPalette.silkscreen.withValues(
      alpha: layer == BoardLayer.frontSilk ? 0.9 : 0.45,
    ),
    BoardLayer.frontCourtyard ||
    BoardLayer.backCourtyard => KicadPalette.courtyard.withValues(alpha: 0.5),
    BoardLayer.frontFab ||
    BoardLayer.backFab => KicadPalette.fabLine.withValues(alpha: 0.5),
    BoardLayer.edgeCuts => KicadPalette.edgeCuts,
    // Mask and paste describe stencils, not anything you can see on a
    // finished board, so they are left out entirely.
    _ => null,
  };

  void _paintPad(Canvas canvas, PlacedPad pad) {
    final center = viewport.toScreen(pad.position);
    final highlighted =
        highlightedNetId != null && pad.netId == highlightedNetId;

    final color = highlighted
        ? KicadPalette.highlight
        : pad.pad.type.spansLayers
        ? KicadPalette.padThroughHole
        : colorFor(
            pad.layers.contains(BoardLayer.backCopper)
                ? CopperLayer.back
                : CopperLayer.front,
          );

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-pad.angle * math.pi / 180);

    final w = viewport.lengthToScreen(pad.pad.sizeX);
    final h = viewport.lengthToScreen(pad.pad.sizeY);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final paint = Paint()..color = color;

    switch (pad.pad.shape) {
      case PadShape.circle:
        canvas.drawCircle(Offset.zero, w / 2, paint);
      case PadShape.oval:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(math.min(w, h) / 2)),
          paint,
        );
      case PadShape.roundrect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(w, h) * pad.pad.roundrectRatio),
          ),
          paint,
        );
      case PadShape.rect || PadShape.trapezoid || PadShape.custom:
        canvas.drawRect(rect, paint);
    }

    if (pad.pad.drill > 0) {
      canvas.drawCircle(
        Offset.zero,
        viewport.lengthToScreen(pad.pad.drill / 2),
        Paint()..color = KicadPalette.drill,
      );
    }

    canvas.restore();

    // Pad numbers are the thing you aim at when routing, so they appear as
    // soon as there is room for them and not before.
    if (viewport.lengthToScreen(math.min(pad.pad.sizeX, pad.pad.sizeY)) >= 14) {
      _paintText(
        canvas,
        pad.pad.number,
        center,
        color: KicadPalette.boardCanvas,
        size: 8,
      );
    }
  }

  void _paintReference(
    Canvas canvas,
    PlacedFootprint footprint, {
    required bool selected,
  }) {
    final ref = footprint.ref;
    final labelSelected = ref.id == selectedLabelId;

    // A hidden designator is not printed, but it has to stay findable to be
    // shown again: faintly, and only while its part or it is selected.
    if (ref.labelHidden && !selected && !labelSelected) return;

    // Sized in board millimetres like everything else on the board, so a
    // label grows and shrinks with the zoom instead of floating at a fixed
    // pixel size over parts it no longer fits.
    final height = viewport.lengthToScreen(ref.labelSize);
    if (height < 3) return;

    final base = ref.flipped
        ? KicadPalette.silkscreen.withValues(alpha: 0.45)
        : KicadPalette.silkscreen;
    final color = labelSelected || selected ? KicadPalette.highlight : base;

    _paintSilkText(
      canvas,
      footprint.part.reference,
      viewport.toScreen(footprint.labelPosition),
      height: height,
      rotation: 0,
      color: ref.labelHidden ? color.withValues(alpha: 0.35) : color,
      mirror: ref.flipped,
      boxed: labelSelected,
    );
  }

  /// Free silkscreen text.
  void _paintTexts(Canvas canvas) {
    for (final text in scene.texts) {
      final height = viewport.lengthToScreen(text.size);
      if (height < 3) continue;
      final selected = text.id == selectedTextId;
      _paintSilkText(
        canvas,
        text.content,
        viewport.toScreen(text.position),
        height: height,
        rotation: text.rotation,
        color: selected
            ? KicadPalette.highlight
            : KicadPalette.silkscreen.withValues(
                alpha: text.back ? 0.45 : 0.95,
              ),
        mirror: text.back,
        boxed: selected,
      );
    }
  }

  /// Text as silkscreen draws it: centred, turned by [rotation], and
  /// mirrored when it is on the back and being looked at through the board.
  void _paintSilkText(
    Canvas canvas,
    String text,
    Offset centre, {
    required double height,
    required double rotation,
    required Color color,
    bool mirror = false,
    bool boxed = false,
    FontWeight weight = FontWeight.w500,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: height,
          fontFamily: 'monospace',
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      // Board space is Y-down, so counter-clockwise is a negative turn.
      ..rotate(-rotation * math.pi / 180);
    if (mirror) canvas.scale(-1, 1);

    final box = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width,
      height: painter.height,
    );
    painter.paint(canvas, box.topLeft);
    if (boxed) {
      canvas.drawRect(
        box.inflate(2),
        Paint()
          ..color = KicadPalette.highlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    painter.dispose();
  }

  // --- overlays --------------------------------------------------------

  void _paintRatsnest(Canvas canvas) {
    final paint = Paint()
      ..color = KicadPalette.ratsnest.withValues(alpha: 0.75)
      ..strokeWidth = 1;

    for (final line in scene.ratsnest) {
      final highlighted =
          highlightedNetId != null && line.netId == highlightedNetId;
      canvas.drawLine(
        viewport.toScreen(line.from),
        viewport.toScreen(line.to),
        highlighted
            ? (Paint()
                ..color = KicadPalette.highlight
                ..strokeWidth = 1.5)
            : paint,
      );
    }
  }

  void _paintPendingRoute(Canvas canvas) {
    if (pendingRoute.length < 2) return;
    final layer = pendingLayer ?? activeLayer;
    final paint = Paint()
      ..color = colorFor(layer).withValues(alpha: 0.85)
      ..strokeWidth = math.max(
        1.5,
        viewport.lengthToScreen(pendingWidth ?? scene.board.rules.trackWidth),
      )
      ..strokeCap = StrokeCap.round;
    // Too close to another net: the run turns red, and does not stop.
    final clashing = {for (final clash in routeClashes) clash.segment};
    final red = Paint()
      ..color = KicadPalette.error
      ..strokeWidth = paint.strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < pendingRoute.length - 1; i++) {
      canvas.drawLine(
        viewport.toScreen(pendingRoute[i]),
        viewport.toScreen(pendingRoute[i + 1]),
        clashing.contains(i) ? red : paint,
      );
    }
    final ring = Paint()
      ..color = KicadPalette.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final clash in routeClashes) {
      canvas.drawCircle(viewport.toScreen(clash.at), 9, ring);
    }

    // Where the route currently ends, so the finger is not the only thing
    // saying where it is.
    canvas.drawCircle(
      viewport.toScreen(pendingRoute.last),
      4,
      Paint()..color = KicadPalette.highlight,
    );

    final target = routeTargetPad;
    if (target != null) {
      canvas.drawCircle(
        viewport.toScreen(target.position),
        math.max(9.0, viewport.lengthToScreen(target.pad.sizeX) * 0.8),
        Paint()
          ..color = KicadPalette.success
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'monospace',
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.palette != palette ||
      old.scene != scene ||
      old.viewport != viewport ||
      old.activeLayer != activeLayer ||
      old.selectedFootprintId != selectedFootprintId ||
      old.selectedTrackId != selectedTrackId ||
      old.highlightedNetId != highlightedNetId ||
      old.pendingRoute != pendingRoute ||
      old.pendingWidth != pendingWidth ||
      old.routeClashes.length != routeClashes.length ||
      old.pendingLayer != pendingLayer ||
      old.showRatsnest != showRatsnest ||
      old.showOutlineGrips != showOutlineGrips ||
      old.draggingOutline != draggingOutline ||
      old.routeTargetPad != routeTargetPad ||
      old.fabPreview != fabPreview ||
      old.fabBack != fabBack ||
      old.selectedOutlineHandle != selectedOutlineHandle ||
      old.selectedEdgeId != selectedEdgeId ||
      old.selectedZoneId != selectedZoneId ||
      old.selectedTextId != selectedTextId ||
      old.selectedLabelId != selectedLabelId;
}
