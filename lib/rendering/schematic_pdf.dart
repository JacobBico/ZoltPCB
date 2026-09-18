import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/theme/kicad_palette.dart';
import '../data/export/pdf_writer.dart';
import 'schematic_painter.dart';
import '../domain/models/schematic_note.dart';
import 'schematic_scene.dart';
import 'schematic_viewport.dart';

/// Colours for paper: the sheet the way KiCad prints one, whatever theme
/// the phone is wearing.
const printColors = SchematicColors(
  canvas: Color(0xFFFFFFFF),
  grid: Color(0xFFE6E6E6),
  gridMajor: Color(0xFFCCCCCC),
  symbolOutline: Color(0xFF840000),
  symbolFill: Color(0xFFFFFFC2),
  pin: Color(0xFF840000),
  pinName: Color(0xFF006464),
  pinNumber: Color(0xFFA90000),
  wire: Color(0xFF008400),
  junction: Color(0xFF008400),
  label: Color(0xFF000000),
  fieldText: Color(0xFF006464),
  noConnect: Color(0xFF0000C2),
  highlight: Color(0xFFFF7F00),
);

/// The whole sheet as a PDF, page-sized, drawn by the canvas's own painter.
///
/// [dpi] is the print resolution; the longest side is capped so an A3
/// sheet does not need more memory than a phone will give it.
Future<Uint8List> renderSchematicPdf(
  SchematicScene scene, {
  required String title,
  List<SchematicNote> notes = const [],
  double dpi = 200,
  int maxPixels = 3600,
}) async {
  final page = scene.pageRect;
  var pxPerMm = dpi / 25.4;
  final longest = math.max(page.width, page.height) * pxPerMm;
  if (longest > maxPixels) pxPerMm *= maxPixels / longest;

  final width = (page.width * pxPerMm).round();
  final height = (page.height * pxPerMm).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  SchematicPainter(
    scene: scene,
    viewport: SchematicViewport(pixelsPerMm: pxPerMm, origin: Offset.zero),
    colors: printColors,
    showGrid: false,
    notes: notes,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));

  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) throw StateError('The sheet could not be drawn');

  final rgba = data.buffer.asUint8List();
  final rgb = Uint8List(width * height * 3);
  for (var i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
    rgb[j] = rgba[i];
    rgb[j + 1] = rgba[i + 1];
    rgb[j + 2] = rgba[i + 2];
  }

  return RasterPdf.single(
    pixelWidth: width,
    pixelHeight: height,
    rgb: rgb,
    widthPt: page.width / 25.4 * 72,
    heightPt: page.height / 25.4 * 72,
    title: title,
  );
}
