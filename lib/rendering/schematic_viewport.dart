import 'dart:ui';

/// The mapping between sheet millimetres and screen pixels.
class SchematicViewport {
  const SchematicViewport({required this.pixelsPerMm, required this.origin});

  /// Zoom, in device-independent pixels per millimetre.
  final double pixelsPerMm;

  /// Screen position of the sheet's top-left corner.
  final Offset origin;

  Offset toScreen(Offset sheetMm) => Offset(
    origin.dx + sheetMm.dx * pixelsPerMm,
    origin.dy + sheetMm.dy * pixelsPerMm,
  );

  Offset toSheet(Offset screen) => Offset(
    (screen.dx - origin.dx) / pixelsPerMm,
    (screen.dy - origin.dy) / pixelsPerMm,
  );

  double lengthToScreen(double mm) => mm * pixelsPerMm;

  SchematicViewport copyWith({double? pixelsPerMm, Offset? origin}) =>
      SchematicViewport(
        pixelsPerMm: pixelsPerMm ?? this.pixelsPerMm,
        origin: origin ?? this.origin,
      );

  /// Zooms about a fixed screen point, so a pinch keeps the pixel under the
  /// fingers where it was.
  SchematicViewport zoomedAbout(Offset focalScreen, double factor) {
    final sheet = toSheet(focalScreen);
    final scaled = pixelsPerMm * factor;
    return SchematicViewport(
      pixelsPerMm: scaled,
      origin: Offset(
        focalScreen.dx - sheet.dx * scaled,
        focalScreen.dy - sheet.dy * scaled,
      ),
    );
  }

  @override
  String toString() =>
      'SchematicViewport(${pixelsPerMm.toStringAsFixed(2)} px/mm, $origin)';
}
