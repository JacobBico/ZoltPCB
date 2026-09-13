import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import '../../rendering/schematic_viewport.dart';

/// What the crosshair has locked onto, and why.
///
/// Snapping silently is worse than not snapping: a point that jumped half a
/// millimetre without saying so is a point you cannot trust. The reason is
/// carried so the readout can name it.
class SnapTarget {
  const SnapTarget({
    required this.at,
    required this.label,
    this.strong = false,
  });

  /// Where the point will actually land.
  final Offset at;

  /// What it caught on — "R1.2", "track end", "0.5 mm grid".
  final String label;

  /// Something real on the board, as opposed to the grid. Drawn heavier,
  /// because landing exactly on a pad is the thing you most need to know.
  final bool strong;
}

/// Where a point would land, given everything on the board near it.
///
/// Pads first, then the ends of copper already drawn, then the grid. That
/// is the order they matter in: a track that lands 20 µm off a pad is not
/// connected, and no amount of zoom makes that visible.
SnapTarget resolveSnap({
  required Offset at,
  required BoardScene scene,
  required double gridMm,
  required bool snapToGrid,
  required double toleranceMm,
  CopperLayer? layer,
  bool snapToObjects = true,
}) {
  // Sweeping a box round a track must not catch on the very track it is
  // meant to enclose — the corners would land on its ends and the box would
  // contain nothing.
  if (!snapToObjects) {
    if (snapToGrid && gridMm > 0) {
      return SnapTarget(
        at: Offset(
          (at.dx / gridMm).round() * gridMm,
          (at.dy / gridMm).round() * gridMm,
        ),
        label: '${_mm(gridMm)} grid',
      );
    }
    return SnapTarget(at: at, label: 'free');
  }

  PlacedPad? bestPad;
  var bestDistance = double.infinity;
  for (final pad in scene.pads) {
    if (layer != null && !pad.reaches(layer)) continue;
    final distance = (pad.position - at).distance;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestPad = pad;
    }
  }
  if (bestPad != null && bestDistance <= toleranceMm) {
    return SnapTarget(
      at: bestPad.position,
      label: bestPad.label,
      strong: true,
    );
  }

  Offset? bestEnd;
  bestDistance = double.infinity;
  for (final track in scene.tracks) {
    for (final end in [
      Offset(track.startX, track.startY),
      Offset(track.endX, track.endY),
    ]) {
      final distance = (end - at).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestEnd = end;
      }
    }
  }
  for (final via in scene.vias) {
    final distance = (Offset(via.x, via.y) - at).distance;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestEnd = Offset(via.x, via.y);
    }
  }
  if (bestEnd != null && bestDistance <= toleranceMm) {
    return SnapTarget(at: bestEnd, label: 'copper', strong: true);
  }

  if (snapToGrid && gridMm > 0) {
    return SnapTarget(
      at: Offset(
        (at.dx / gridMm).round() * gridMm,
        (at.dy / gridMm).round() * gridMm,
      ),
      label: '${_mm(gridMm)} grid',
    );
  }

  return SnapTarget(at: at, label: 'free');
}

/// The fixed sight in the middle of the canvas.
///
/// The board moves under it; it does not move over the board. That is the
/// whole idea: on a phone the finger is both the pointer and the thing
/// covering what it points at, and no amount of care fixes that. Panning
/// the board under a target you can see at all times does.
class CrosshairOverlay extends StatelessWidget {
  const CrosshairOverlay({
    super.key,
    required this.snap,
    required this.viewport,
    this.armed = true,
  });

  final SnapTarget snap;
  final SchematicViewport viewport;

  /// Whether a point would actually be placed. Dimmed when the current tool
  /// has nothing to place.
  final bool armed;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _CrosshairPainter(
        snap: snap,
        viewport: viewport,
        armed: armed,
      ),
      size: Size.infinite,
    ),
  );
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({
    required this.snap,
    required this.viewport,
    required this.armed,
  });

  final SnapTarget snap;
  final SchematicViewport viewport;
  final bool armed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final colour = armed
        ? (snap.strong ? KicadPalette.success : KicadPalette.highlight)
        : KicadPalette.textDisabled;

    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // A gap in the middle, so the point being aimed at is never covered by
    // the thing doing the aiming.
    const gap = 7.0;
    const arm = 22.0;
    canvas.drawLine(
      centre.translate(-arm, 0),
      centre.translate(-gap, 0),
      paint,
    );
    canvas.drawLine(centre.translate(gap, 0), centre.translate(arm, 0), paint);
    canvas.drawLine(
      centre.translate(0, -arm),
      centre.translate(0, -gap),
      paint,
    );
    canvas.drawLine(centre.translate(0, gap), centre.translate(0, arm), paint);
    canvas.drawCircle(centre, 2, Paint()..color = colour);

    // Where the point will actually land, when that is not where the sight
    // is pointing.
    final landing = viewport.toScreen(snap.at);
    if ((landing - centre).distance > 1.5) {
      canvas.drawLine(
        centre,
        landing,
        Paint()
          ..color = colour.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        landing,
        snap.strong ? 6 : 4,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.snap.at != snap.at ||
      old.snap.strong != snap.strong ||
      old.armed != armed ||
      old.viewport != viewport;
}

/// The coordinate readout and the button that places a point.
///
/// The button is deliberately large and on the right, where a thumb is.
/// Placing a point is the single most repeated act in laying out a board
/// and it should never require aiming twice.
class AimBar extends StatelessWidget {
  const AimBar({
    super.key,
    required this.snap,
    required this.placeLabel,
    required this.onPlace,
    this.leading = const [],
    this.trailing = const [],
  });

  final SnapTarget snap;
  final String placeLabel;
  final VoidCallback? onPlace;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KicadPalette.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KicadPalette.border),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...leading,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_mm(snap.at.dx)}, ${_mm(snap.at.dy)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: KicadPalette.textPrimary,
                  ),
                ),
                Text(
                  snap.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: snap.strong
                        ? KicadPalette.success
                        : KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            ...trailing,
            if (onPlace != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FilledButton(
                  onPressed: onPlace,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(placeLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _mm(double value) {
  final text = value.toStringAsFixed(2);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

/// How far, in millimetres, the crosshair reaches for something to snap to.
double snapToleranceMm(SchematicViewport viewport) =>
    math.max(0.15, 14 / viewport.pixelsPerMm);
