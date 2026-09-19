import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/cross_probe.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../rendering/schematic_painter.dart';
import '../../rendering/schematic_scene.dart';
import '../../rendering/schematic_viewport.dart';
import '../board/board_painter.dart';

/// Size of the live view, in logical pixels: big enough to read a part on,
/// small enough to leave the sheet it sits over usable.
const crossProbeSize = Size(260, 150);

/// What the live view is to show: a part, a net, or both.
class ProbeFocus {
  const ProbeFocus({this.partId, this.netId});

  final String? partId;
  final String? netId;

  bool get isEmpty => partId == null && netId == null;
}

/// A mini view of the board, following what is selected on the schematic.
class MiniBoardView extends ConsumerWidget {
  const MiniBoardView({
    super.key,
    required this.projectId,
    required this.focus,
    this.onOpen,
  });

  final String projectId;
  final ProbeFocus focus;

  /// Goes to the board itself.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(boardSceneProvider(projectId)).value;
    final footprint = scene?.footprints
        .where((f) => f.part.id == focus.partId)
        .firstOrNull;
    final netPads = scene == null || focus.netId == null
        ? const <PlacedPad>[]
        : [
            for (final pad in scene.pads)
              if (pad.netId == focus.netId) pad,
          ];

    final String caption;
    if (scene == null) {
      caption = 'Board';
    } else if (footprint != null) {
      caption = footprint.part.reference;
    } else if (focus.partId != null) {
      caption = 'Not on the board yet';
    } else if (netPads.isNotEmpty) {
      caption = '${netPads.first.netName ?? 'Net'} · ${netPads.length} pads';
    } else if (focus.netId != null) {
      caption = 'No pads on the board yet';
    } else {
      caption = 'Tap something on the sheet';
    }

    return _ProbeFrame(
      key: const ValueKey('cross-probe-board'),
      title: 'Board',
      caption: caption,
      onOpen: onOpen,
      child: scene == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                final Rect frame;
                if (footprint != null) {
                  frame = footprint.bounds.inflate(
                    math.max(4, footprint.bounds.longestSide),
                  );
                } else if (netPads.isNotEmpty) {
                  var rect = Rect.fromCircle(
                    center: netPads.first.position,
                    radius: 1,
                  );
                  for (final pad in netPads) {
                    rect = rect.expandToInclude(
                      Rect.fromCircle(center: pad.position, radius: 1),
                    );
                  }
                  frame = rect.inflate(4);
                } else {
                  frame = scene.outlineBounds.inflate(2);
                }
                return CustomPaint(
                  size: size,
                  painter: BoardPainter(
                    scene: scene,
                    viewport: fitViewport(frame, size),
                    activeLayer: CopperLayer.front,
                    selectedFootprintId: footprint?.ref.id,
                    highlightedNetId: focus.netId,
                    showRatsnest: focus.netId != null,
                  ),
                );
              },
            ),
    );
  }
}

/// A mini view of the schematic, following what is selected on the board.
class MiniSchematicView extends ConsumerWidget {
  const MiniSchematicView({
    super.key,
    required this.project,
    required this.focus,
    this.onOpen,
  });

  final Project project;
  final ProbeFocus focus;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = ref.watch(projectPartsProvider(project.id)).value;
    final nets = ref.watch(projectNetsProvider(project.id)).value;
    final symbols = ref.watch(projectSymbolsProvider(project.id)).value;
    final hints = ref.watch(routeHintsProvider(project.id)).value;
    final drawn = ref.watch(schematicWiresProvider(project.id)).value;
    final ready =
        parts != null && nets != null && symbols != null && drawn != null;
    final scene = !ready
        ? null
        : SchematicScene.build(
            paper: project.paper,
            parts: parts,
            nets: nets,
            symbols: symbols,
            routeHints: hints ?? const {},
            drawnWires: drawn,
          );

    final units = scene == null
        ? const <PlacedUnit>[]
        : [
            for (final unit in scene.units)
              if (unit.part.id == focus.partId) unit,
          ];
    final pins = scene == null || focus.netId == null
        ? const <PlacedPin>[]
        : scene.pinsByNet[focus.netId] ?? const <PlacedPin>[];
    final net = nets?.where((n) => n.net.id == focus.netId).firstOrNull;

    final String caption;
    if (units.isNotEmpty) {
      caption = units.first.part.reference;
    } else if (net != null) {
      caption = '${net.displayName} · ${net.endpoints.length} pins';
    } else if (focus.isEmpty) {
      caption = 'Tap something on the board';
    } else {
      caption = 'Not on the schematic';
    }

    return _ProbeFrame(
      key: const ValueKey('cross-probe-schematic'),
      title: 'Schematic',
      caption: caption,
      onOpen: onOpen,
      child: scene == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                Rect? frame;
                void include(Rect rect) =>
                    frame = frame == null ? rect : frame!.expandToInclude(rect);
                for (final unit in units) {
                  include(scene.boundsOf(unit));
                }
                if (units.isEmpty) {
                  for (final pin in pins) {
                    include(
                      Rect.fromCircle(center: pin.sheetPosition, radius: 2),
                    );
                  }
                  for (final wire in scene.wires) {
                    if (wire.netId != focus.netId) continue;
                    for (final p in wire.points) {
                      include(Rect.fromCircle(center: p, radius: 1));
                    }
                  }
                }
                final shown = (frame ?? scene.contentBounds).inflate(
                  frame == null ? 2 : 8,
                );
                return CustomPaint(
                  size: size,
                  painter: SchematicPainter(
                    scene: scene,
                    viewport: fitViewport(shown, size),
                    colors: Theme.of(context).schematic,
                    selectedUnitIds: {for (final u in units) u.unit.id},
                    highlightedNetId: focus.netId,
                    showGrid: false,
                    zigzagResistors:
                        ref.watch(appearanceProvider).resistorStyle ==
                        ResistorStyle.ansi,
                  ),
                );
              },
            ),
    );
  }
}

/// A viewport showing all of [frame] in [size], centred.
SchematicViewport fitViewport(Rect frame, Size size) {
  final safe = frame.isEmpty ? frame.inflate(5) : frame;
  final scale = math.min(
    size.width / math.max(safe.width, 1e-3),
    size.height / math.max(safe.height, 1e-3),
  );
  return SchematicViewport(
    pixelsPerMm: scale,
    origin: Offset(
      size.width / 2 - safe.center.dx * scale,
      size.height / 2 - safe.center.dy * scale,
    ),
  );
}

/// The live view's frame: a title, what it is showing, a way to go there,
/// and a way to close it.
class _ProbeFrame extends ConsumerWidget {
  const _ProbeFrame({
    super.key,
    required this.title,
    required this.caption,
    required this.child,
    this.onOpen,
  });

  final String title;
  final String caption;
  final Widget child;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 6,
      color: KicadPalette.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: crossProbeSize.width,
        height: crossProbeSize.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: KicadPalette.highlight.withValues(alpha: 0.6),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 26,
              padding: const EdgeInsets.only(left: 8),
              color: KicadPalette.surfaceRaised,
              child: Row(
                children: [
                  Icon(
                    Icons.picture_in_picture_alt_outlined,
                    size: 14,
                    color: KicadPalette.highlight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      caption,
                      key: const ValueKey('cross-probe-caption'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ),
                  if (onOpen != null)
                    _HeaderButton(
                      icon: Icons.open_in_full,
                      tooltip: 'Go to the $title',
                      onPressed: onOpen!,
                    ),
                  _HeaderButton(
                    icon: Icons.close,
                    tooltip: 'Close the live view',
                    onPressed: () =>
                        ref.read(crossProbeOnProvider.notifier).set(false),
                  ),
                ],
              ),
            ),
            // Only to look at: touches go to the sheet it sits over.
            Expanded(child: IgnorePointer(child: child)),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 26,
    child: IconButton(
      padding: EdgeInsets.zero,
      iconSize: 15,
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    ),
  );
}
