import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting_bytes.dart';
import '../../fab/gerber_reader.dart';
import '../../fab/gerber_writer.dart';

/// One layer as the viewer shows it.
class GerberLayer {
  GerberLayer({
    required this.file,
    required this.label,
    required this.color,
    required this.image,
    this.holes = const [],
    this.front,
  });

  final FabricationFile file;
  final String label;
  final Color color;
  final GerberImage? image;
  final List<DrillHole> holes;

  /// True for a top layer, false for a bottom one, null for both sides.
  final bool? front;
}

/// Draws Gerber layers bottom first, each in its own compositing layer so a
/// clear-polarity shape cuts only its own layer.
class GerberPainter extends CustomPainter {
  GerberPainter({
    required this.layers,
    required this.origin,
    required this.pixelsPerMm,
  });

  final List<GerberLayer> layers;
  final Offset origin;
  final double pixelsPerMm;

  Offset _screen(Offset mm) => origin + mm * pixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF14171A),
    );

    for (final layer in layers) {
      final image = layer.image;
      if (image != null) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromARGB(210, 255, 255, 255),
        );
        for (final shape in image.shapes) {
          final paint = Paint()
            ..color = layer.color
            ..blendMode = shape.clear ? BlendMode.clear : BlendMode.srcOver;
          switch (shape) {
            case GerberStroke(:final points, :final width):
              final path = Path()
                ..moveTo(_screen(points.first).dx, _screen(points.first).dy);
              for (final p in points.skip(1)) {
                path.lineTo(_screen(p).dx, _screen(p).dy);
              }
              canvas.drawPath(
                path,
                paint
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(1, width * pixelsPerMm)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
            case GerberFlash(:final at, :final aperture):
              final centre = _screen(at);
              final w = aperture.width * pixelsPerMm;
              final h = aperture.height * pixelsPerMm;
              switch (aperture.kind) {
                case 'C':
                  canvas.drawCircle(centre, w / 2, paint);
                case 'O':
                  canvas.drawRRect(
                    RRect.fromRectAndRadius(
                      Rect.fromCenter(center: centre, width: w, height: h),
                      Radius.circular(math.min(w, h) / 2),
                    ),
                    paint,
                  );
                default:
                  canvas.drawRect(
                    Rect.fromCenter(center: centre, width: w, height: h),
                    paint,
                  );
              }
            case GerberRegion(:final points):
              final path = Path()
                ..moveTo(_screen(points.first).dx, _screen(points.first).dy);
              for (final p in points.skip(1)) {
                path.lineTo(_screen(p).dx, _screen(p).dy);
              }
              path.close();
              canvas.drawPath(path, paint);
          }
        }
        canvas.restore();
      }

      for (final hole in layer.holes) {
        canvas.drawCircle(
          _screen(hole.at),
          math.max(1, hole.diameter * pixelsPerMm / 2),
          Paint()..color = layer.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GerberPainter old) =>
      old.layers.length != layers.length ||
      !List.generate(
        layers.length,
        (i) => identical(layers[i], old.layers[i]),
      ).every((same) => same) ||
      old.origin != origin ||
      old.pixelsPerMm != pixelsPerMm;
}

/// The text of [file], as the board house will get it.
Future<void> showFabricationFile(BuildContext context, FabricationFile file) {
  final lines = file.content.split('\n');
  const shown = 3000;
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(file.name),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 640,
        height: 420,
        child: SingleChildScrollView(
          child: SelectableText(
            [
              ...lines.take(shown),
              if (lines.length > shown)
                '… ${lines.length - shown} more lines in the file',
            ].join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

/// One file in a list of fabrication files: tap to read it, tick to show
/// it.
class GerberFileRow extends StatelessWidget {
  const GerberFileRow({
    super.key,
    required this.label,
    required this.fileName,
    required this.bytes,
    required this.color,
    required this.visible,
    required this.onToggle,
    required this.onOpen,
  });

  final String label;
  final String fileName;
  final int bytes;
  final Color? color;
  final bool visible;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            if (onToggle != null)
              Checkbox(value: visible, onChanged: (_) => onToggle!())
            else
              const SizedBox(
                width: 48,
                child: Icon(Icons.table_rows, size: 18),
              ),
            if (color != null)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: KicadPalette.border),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    '$fileName · ${formatBytes(bytes)}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
