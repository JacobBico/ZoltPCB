import 'package:flutter/material.dart';

import '../theme/kicad_palette.dart';

/// Zoom out, fit, zoom in — the controls every canvas in the app needs.
///
/// Pinch works everywhere too, but a phone held in one hand has only a
/// thumb, and a pinch needs two fingers.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.onZoom,
    required this.onFit,
    this.fitTooltip = 'Fit to view',
  });

  final ValueChanged<double> onZoom;
  final VoidCallback onFit;
  final String fitTooltip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KicadPalette.surface.withValues(alpha: 0.94),
        border: Border.all(color: KicadPalette.border),
        borderRadius: BorderRadius.circular(3),
      ),
      // Stacked, not side by side. Laid out in a row they took a third of
      // the bottom edge, which is exactly where the action bar needs room —
      // with a component list open beside the canvas, the bar's last verbs
      // scrolled out of sight with nothing to say they were there. Map apps
      // stand their zoom buttons up for the same reason.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onZoom(1.4),
          ),
          IconButton(
            tooltip: fitTooltip,
            icon: const Icon(Icons.fit_screen_outlined, size: 18),
            onPressed: onFit,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => onZoom(1 / 1.4),
          ),
        ],
      ),
    );
  }
}
