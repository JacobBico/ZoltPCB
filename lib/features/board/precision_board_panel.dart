import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../rendering/schematic_viewport.dart';
import 'board_painter.dart';
import 'board_shape_editor.dart';
import 'crosshair.dart';
import 'design_rules_dialog.dart';
import 'drc_sheet.dart';
import 'footprint_sidebar.dart';
import 'object_properties.dart';
import 'track_sizes_dialog.dart';
import 'zone_editor.dart';

/// What the PLACE button is currently placing.
enum AimTool {
  select('Select', Icons.north_west, 'Tap something to pick it up'),
  region(
    'Area',
    Icons.crop_free,
    'Place one corner of the area, then the other',
  ),
  route('Route', Icons.timeline, 'Aim at a pad and place the first corner'),
  zone('Pour', Icons.format_color_fill_outlined, 'Place the corners of a pour'),
  edge('Edge cut', Icons.content_cut, 'Place the corners of a cut'),
  via('Via', Icons.adjust, 'Aim where the via goes'),
  measure('Measure', Icons.straighten, 'Aim at the first point');

  const AimTool(this.label, this.icon, this.hint);

  final String label;
  final IconData icon;
  final String hint;

  bool get places => this != AimTool.select;
}

/// The board editor, aimed rather than poked.
///
/// Three attempts at this screen rearranged the controls and left the same
/// interaction underneath: put your finger on the exact spot you want, on a
/// board a few centimetres across, with a fingertip that covers eight
/// millimetres of it and hides what is underneath. That is the part that
/// felt wrong, and no arrangement of buttons was ever going to fix it.
///
/// So the sight stays still and the board moves under it. Drag to pan,
/// pinch to zoom, and a large button places a point exactly where the
/// crosshair says — which you can see, because your hand is nowhere near
/// it. Everything that needs a precise position is placed this way: track
/// corners, pour outlines, edge cuts, vias, and parts.
class PrecisionBoardPanel extends ConsumerStatefulWidget {
  const PrecisionBoardPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<PrecisionBoardPanel> createState() =>
      _PrecisionBoardPanelState();
}

class _PrecisionBoardPanelState extends ConsumerState<PrecisionBoardPanel> {
  SchematicViewport? _viewport;
  Size _canvasSize = Size.zero;

  AimTool _tool = AimTool.select;

  double _grid = 0.5;
  bool _snap = true;
  double? _trackWidth;
  ViaSize? _viaSize;

  /// What angles copper may leave a corner at, and how far its corners are
  /// rounded. Both belong to the person routing, not to the app.
  TrackAngleLock _angleLock = TrackAngleLock.deg45;
  double _curveRadius = 0;

  /// The two corners of the area being swept, and what fell inside it.
  Offset? _regionFrom;
  Rect? _region;
  _Selection _selected = const _Selection.empty();

  /// Where the carried thing was picked up, so everything moves by the
  /// same delta rather than jumping its anchor to the crosshair.
  Offset? _carryAnchor;
  String? _carryingEdgeId;
  bool _carryingOutline = false;

  // Selection.
  String? _selectedFootprintId;
  String? _selectedTrackId;
  String? _selectedViaId;
  String? _selectedEdgeId;
  String? _selectedZoneId;
  String? _highlightedNetId;

  /// The board edge itself, which is as much a drawn object as the cuts
  /// added to it and was the one thing that could not be picked up.
  bool _outlineSelected = false;

  // Whatever is being drawn, corner by corner.
  final List<Offset> _points = [];
  String? _routeNetId;
  CopperLayer? _routeLayer;

  /// The part being carried on the crosshair, if any. Moving a part is the
  /// same act as drawing a corner: aim, then place.
  String? _carryingId;

  Offset? _measureFrom;
  Offset? _measureTo;

  /// Where the sight last resolved to. Read by the buttons, which are built
  /// outside the frame that computed it.
  Offset _lastSnap = Offset.zero;

  String? _assigningPartId;
  bool _fabPreview = false;
  bool _fabBack = false;
  bool _showRatsnest = true;
  String? _hint;
  Timer? _hintTimer;

  // Panning and zooming, which is all a finger does here.
  SchematicViewport? _gestureStartViewport;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sceneAsync = ref.watch(boardSceneProvider(widget.project.id));
    final partsAsync = ref.watch(projectPartsProvider(widget.project.id));

    final error = sceneAsync.error ?? partsAsync.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not draw the board',
        message: '$error',
      );
    }

    final scene = sceneAsync.value;
    final parts = partsAsync.value;
    if (scene == null || parts == null) return const SizedBox.shrink();

    if (parts.isEmpty) {
      return const EmptyState(
        icon: Icons.developer_board_outlined,
        title: 'Nothing to lay out yet',
        message:
            'A board is built from the schematic. Add components and wire '
            'them up first, then come back.',
      );
    }

    final assigning = parts
        .where((p) => p.part.id == _assigningPartId)
        .firstOrNull;

    return Row(
      children: [
        Expanded(child: _body(scene, parts)),
        if (assigning != null)
          FootprintSidebar(
            part: assigning,
            currentLibId: scene.footprints
                .where((f) => f.part.id == assigning.part.id)
                .firstOrNull
                ?.ref
                .libId,
            onChoose: (entry) => _assign(assigning, entry.libId),
            onClose: () => setState(() => _assigningPartId = null),
          ),
      ],
    );
  }

  Widget _body(BoardScene committed, List<PartWithDetails> parts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _canvasSize = size;
        final viewport = _viewport ??= _fitToContent(committed, size);
        final snap = _snapAt(committed, viewport, size);
        _lastSnap = snap.at;
        final scene = _withCarried(committed, snap.at);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _onTap(scene, viewport, details.localPosition),
                onScaleStart: (details) {
                  _gestureStartViewport = viewport;
                  _gestureStartFocal = details.localFocalPoint;
                },
                onScaleUpdate: (details) => _onPanZoom(details),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: BoardPainter(
                      scene: scene,
                      viewport: viewport,
                      activeLayer: ref.watch(activeLayerProvider),
                      selectedFootprintId: _selectedFootprintId,
                      selectedTrackId: _selectedTrackId,
                      selectedEdgeId: _selectedEdgeId,
                      selectedZoneId: _selectedZoneId,
                      highlightedNetId: _highlightedNetId,
                      pendingRoute: _pendingPath(snap.at),
                      pendingLayer: _routeLayer,
                      showRatsnest: _showRatsnest,
                      showOutlineGrips: false,
                      fabPreview: _fabPreview,
                      fabBack: _fabBack,
                    ),
                    size: size,
                  ),
                ),
              ),
            ),
            if (_regionFrom != null || _region != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RegionPainter(
                      from: _region?.topLeft ?? _regionFrom!,
                      to: _region?.bottomRight ?? snap.at,
                      settled: _region != null,
                      viewport: viewport,
                    ),
                  ),
                ),
              ),
            if (_measureFrom != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MeasurePainter(
                      from: _measureFrom!,
                      to: _measureTo ?? snap.at,
                      viewport: viewport,
                    ),
                  ),
                ),
              ),
            if (!_fabPreview)
              Positioned.fill(
                child: CrosshairOverlay(
                  snap: snap,
                  viewport: viewport,
                  armed: _tool.places || _carryingId != null,
                ),
              ),
            Positioned(left: 0, right: 0, top: 0, child: _topStrip(scene)),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _bottomBar(scene, parts, snap),
            ),
          ],
        );
      },
    );
  }

  /// The board with whatever is being carried following the crosshair.
  BoardScene _withCarried(BoardScene committed, Offset at) {
    final delta = _carryAnchor == null ? Offset.zero : at - _carryAnchor!;

    // An edge cut, the board outline, or a whole swept area all move the
    // same way: everything shifts by the same delta, so the shape being
    // carried keeps its proportions instead of collapsing onto the sight.
    if (_carryingEdgeId != null || _carryingOutline || _carryingSelection) {
      return _shifted(committed, delta);
    }

    final id = _carryingId;
    if (id == null) return committed;

    final parts = ref.watch(projectPartsProvider(widget.project.id)).value;
    final nets = ref.watch(projectNetsProvider(widget.project.id)).value;
    final placements = ref
        .watch(boardFootprintsProvider(widget.project.id))
        .value;
    final definitions = ref
        .watch(projectFootprintsProvider(widget.project.id))
        .value;
    if (parts == null ||
        nets == null ||
        placements == null ||
        definitions == null) {
      return committed;
    }

    return BoardScene.build(
      board: committed.board,
      parts: parts,
      nets: nets,
      placements: [
        for (final placement in placements)
          if (placement.id == id)
            placement.copyWith(x: at.dx, y: at.dy, placed: true)
          else
            placement,
      ],
      definitions: definitions,
      tracks: committed.tracks,
      vias: committed.vias,
      edges: committed.edges,
      zones: committed.zones,
    );
  }

  bool get _carryingSelection => _carryAnchor != null && !_selected.isEmpty;

  /// The scene with everything being carried moved by [delta].
  BoardScene _shifted(BoardScene committed, Offset delta) {
    if (delta == Offset.zero) return committed;

    final parts = ref.watch(projectPartsProvider(widget.project.id)).value;
    final nets = ref.watch(projectNetsProvider(widget.project.id)).value;
    final placements = ref
        .watch(boardFootprintsProvider(widget.project.id))
        .value;
    final definitions = ref
        .watch(projectFootprintsProvider(widget.project.id))
        .value;
    if (parts == null ||
        nets == null ||
        placements == null ||
        definitions == null) {
      return committed;
    }

    final moving = _selected;
    final edgeId = _carryingEdgeId;

    return BoardScene.build(
      board: _carryingOutline
          ? committed.board.withOutline(
              _shiftOutline(committed.outline, delta),
            )
          : committed.board,
      parts: parts,
      nets: nets,
      placements: [
        for (final placement in placements)
          if (moving.footprintIds.contains(placement.id))
            placement.copyWith(
              x: placement.x + delta.dx,
              y: placement.y + delta.dy,
              placed: true,
            )
          else
            placement,
      ],
      definitions: definitions,
      tracks: [
        for (final track in committed.tracks)
          if (moving.trackIds.contains(track.id))
            track.copyWith(
              startX: track.startX + delta.dx,
              startY: track.startY + delta.dy,
              endX: track.endX + delta.dx,
              endY: track.endY + delta.dy,
            )
          else
            track,
      ],
      vias: [
        for (final via in committed.vias)
          if (moving.viaIds.contains(via.id))
            via.copyWith(x: via.x + delta.dx, y: via.y + delta.dy)
          else
            via,
      ],
      edges: [
        for (final edge in committed.edges)
          if (edge.id == edgeId || moving.edgeIds.contains(edge.id))
            edge.copyWith(
              points: [for (final p in edge.points) p + delta],
            )
          else
            edge,
      ],
      zones: [
        for (final zone in committed.zones)
          if (moving.zoneIds.contains(zone.id))
            zone.copyWith(points: [for (final p in zone.points) p + delta])
          else
            zone,
      ],
    );
  }

  static BoardOutline _shiftOutline(BoardOutline outline, Offset delta) =>
      switch (outline.kind) {
        BoardOutlineKind.rectangle => BoardOutline.rectangle(
          outline.rect.shift(delta),
        ),
        BoardOutlineKind.circle => BoardOutline.circle(
          outline.rect.shift(delta),
        ),
        BoardOutlineKind.polygon => BoardOutline.polygon([
          for (final p in outline.points) p + delta,
        ]),
      };

  /// Where the crosshair is pointing, after snapping.
  SnapTarget _snapAt(
    BoardScene scene,
    SchematicViewport viewport,
    Size size,
  ) {
    final centre = viewport.toSheet(
      Offset(size.width / 2, size.height / 2),
    );
    return resolveSnap(
      at: centre,
      scene: scene,
      gridMm: _grid,
      snapToGrid: _snap,
      toleranceMm: snapToleranceMm(viewport),
      // Only copper on the layer being routed is worth catching on.
      layer: _tool == AimTool.route ? ref.read(activeLayerProvider) : null,
      snapToObjects: _tool != AimTool.region,
    );
  }

  /// What is being drawn, with the crosshair as its next corner.
  ///
  /// Constrained exactly as the placed point will be, so the line on screen
  /// is the line that lands.
  List<Offset> _pendingPath(Offset at) {
    if (_points.isEmpty) return const [];
    return [..._points, _tool == AimTool.route ? _constrained(at) : at];
  }

  void _onPanZoom(ScaleUpdateDetails details) {
    final start = _gestureStartViewport;
    if (start == null) return;
    setState(() {
      final zoomed = start.copyWith(
        pixelsPerMm: (start.pixelsPerMm * details.scale).clamp(0.5, 200.0),
      );
      final anchor = start.toSheet(_gestureStartFocal);
      _viewport = zoomed.copyWith(
        origin: Offset(
          details.localFocalPoint.dx - anchor.dx * zoomed.pixelsPerMm,
          details.localFocalPoint.dy - anchor.dy * zoomed.pixelsPerMm,
        ),
      );
    });
  }

  // --- the bars --------------------------------------------------------

  Widget _topStrip(BoardScene scene) {
    final layer = ref.watch(activeLayerProvider);

    return Material(
      color: KicadPalette.surface.withValues(alpha: 0.94),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final tool in AimTool.values)
                      _ToolChip(
                        tool: tool,
                        selected: tool == _tool,
                        onPressed: () => _pickTool(tool),
                      ),
                    const SizedBox(width: 6),
                    _StripChip(
                      label: layer.label,
                      icon: Icons.layers_outlined,
                      colour: BoardPainter.colorFor(layer),
                      onTap: () => ref
                          .read(activeLayerProvider.notifier)
                          .toggle(),
                    ),
                    _StripChip(
                      label: _snap ? '${_mm(_grid)} mm' : 'free',
                      icon: _snap ? Icons.grid_4x4 : Icons.grid_off,
                      colour: _snap
                          ? KicadPalette.textSecondary
                          : KicadPalette.warning,
                      onTap: _chooseGrid,
                    ),
                    _StripChip(
                      label: '${_mm(_widthFor(scene))} mm',
                      icon: Icons.horizontal_rule,
                      colour: KicadPalette.textSecondary,
                      onTap: () => _chooseWidth(scene),
                    ),
                    _StripChip(
                      label: _viaFor(scene).toString(),
                      icon: Icons.adjust,
                      colour: KicadPalette.textSecondary,
                      onTap: () => _chooseVia(scene),
                    ),
                    // What angles copper may turn at. A board routed at 3°
                    // is legal and unreadable; KiCad defaults to 45 and so
                    // does this.
                    _StripChip(
                      label: _angleLock.label,
                      icon: Icons.turn_sharp_right_outlined,
                      colour: _angleLock == TrackAngleLock.any
                          ? KicadPalette.warning
                          : KicadPalette.textSecondary,
                      onTap: () =>
                          setState(() => _angleLock = _angleLock.next),
                    ),
                    _StripChip(
                      label: _curveRadius > 0
                          ? 'r${_mm(_curveRadius)}'
                          : 'sharp',
                      icon: Icons.rounded_corner,
                      colour: _curveRadius > 0
                          ? KicadPalette.highlight
                          : KicadPalette.textSecondary,
                      onTap: () => _chooseCurve(scene),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz, size: 18),
                onPressed: () => _showMore(scene),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(
    BoardScene scene,
    List<PartWithDetails> parts,
    SnapTarget snap,
  ) {
    if (_fabPreview) {
      return Row(
        children: [
          FilledButton.icon(
            onPressed: () => setState(() => _fabBack = !_fabBack),
            icon: const Icon(Icons.flip, size: 16),
            label: Text(_fabBack ? 'TOP' : 'UNDERSIDE'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              _fabPreview = false;
              _fabBack = false;
            }),
            child: const Text('CLOSE'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          // Not reversed: the first button is the one you came for, and
          // scrolling it off the left of the screen to keep the last one
          // in view had it exactly backwards.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _contextButtons(scene, parts)),
          ),
        ),
        const SizedBox(width: 8),
        AimBar(
          snap: snap,
          placeLabel: _placeLabel,
          onPlace: _canPlace ? () => _place(scene, snap) : null,
        ),
      ],
    );
  }

  String get _placeLabel {
    if (_isCarrying) return 'DROP';
    return switch (_tool) {
      AimTool.select => 'PLACE',
      AimTool.route => _points.isEmpty ? 'START' : 'CORNER',
      AimTool.zone || AimTool.edge => _points.isEmpty ? 'START' : 'CORNER',
      AimTool.via => 'VIA',
      AimTool.measure => _measureFrom == null ? 'FROM' : 'TO',
      AimTool.region => _regionFrom == null ? 'CORNER' : 'FINISH',
    };
  }

  bool get _canPlace => _isCarrying || _tool.places;

  /// Whether anything at all is riding on the crosshair.
  bool get _isCarrying =>
      _carryingId != null ||
      _carryingEdgeId != null ||
      _carryingOutline ||
      _carryingSelection;

  /// The buttons that matter right now, and no others.
  List<Widget> _contextButtons(
    BoardScene scene,
    List<PartWithDetails> parts,
  ) {
    final history = ref.watch(editHistoryProvider);

    if (_carryingId != null) {
      return [
        _Chip(
          icon: Icons.rotate_90_degrees_ccw_outlined,
          label: 'Rotate',
          onPressed: () => _rotateCarried(scene),
        ),
        _Chip(
          icon: Icons.close,
          label: 'Cancel',
          onPressed: () => setState(() {
            _carryingId = null;
            _carryAnchor = null;
          }),
        ),
      ];
    }

    if (_carryingEdgeId != null || _carryingOutline || _carryingSelection) {
      return [
        _Chip(
          icon: Icons.close,
          label: 'Cancel',
          onPressed: () => setState(() {
            _carryAnchor = null;
            _carryingEdgeId = null;
            _carryingOutline = false;
          }),
        ),
      ];
    }

    // An area has been swept: what is in it can be moved or deleted as one.
    if (_region != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move ${_selected.count}',
          onPressed: _selected.isEmpty
              ? null
              : () => _carryRegion(),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete ${_selected.count}',
          danger: true,
          onPressed: _selected.isEmpty
              ? null
              : () => _deleteSelection(scene),
        ),
        _Chip(
          icon: Icons.close,
          label: 'Clear',
          onPressed: () => setState(_clearSelection),
        ),
      ];
    }

    // Mid-drawing: finishing and unfinishing is all that matters.
    if (_points.isNotEmpty) {
      return [
        _Chip(icon: Icons.undo, label: 'Back', onPressed: _undoPoint),
        if (_tool == AimTool.route)
          _Chip(
            icon: Icons.swap_vert,
            label: 'Via + flip',
            onPressed: () => _viaAndSwitch(scene),
          ),
        _Chip(
          icon: Icons.check,
          label: switch (_tool) {
            AimTool.zone => 'Close pour',
            AimTool.edge => 'Finish cut',
            _ => 'Finish',
          },
          onPressed: () => _finish(scene),
        ),
        _Chip(
          icon: Icons.close,
          label: 'Cancel',
          onPressed: () => setState(_clearDrawing),
        ),
      ];
    }

    final footprint = scene.footprints
        .where((f) => f.ref.id == _selectedFootprintId)
        .firstOrNull;
    if (footprint != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: () => _carry(footprint),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _footprintProperties(footprint),
        ),
        _Chip(
          icon: Icons.flip,
          label: footprint.ref.flipped ? 'Front' : 'Back',
          onPressed: () => _flip(footprint),
        ),
        _Chip(
          icon: Icons.swap_horiz,
          label: 'Footprint',
          onPressed: () =>
              setState(() => _assigningPartId = footprint.part.id),
        ),
      ];
    }

    final track = scene.tracks
        .where((t) => t.id == _selectedTrackId)
        .firstOrNull;
    if (track != null) {
      return [
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _trackProperties(scene, track),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: () => _deleteTrack(track),
        ),
        _Chip(
          icon: Icons.layers_clear_outlined,
          label: 'Rip net',
          danger: true,
          onPressed: track.netId == null
              ? null
              : () => _ripUpNet(track.netId!),
        ),
      ];
    }

    final via = scene.vias.where((v) => v.id == _selectedViaId).firstOrNull;
    if (via != null) {
      return [
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _viaProperties(scene, via),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: () => _deleteVia(via),
        ),
      ];
    }

    final edge = scene.edges.where((e) => e.id == _selectedEdgeId).firstOrNull;
    if (edge != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: () => _carryEdge(edge),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete cut',
          danger: true,
          onPressed: () => _deleteEdge(edge),
        ),
      ];
    }

    if (_outlineSelected) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move outline',
          onPressed: () => _carryOutline(scene),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Dimensions',
          onPressed: () => _chooseShape(scene),
        ),
        _Chip(
          icon: Icons.close,
          label: 'Done',
          onPressed: () => setState(() => _outlineSelected = false),
        ),
      ];
    }

    final zone = scene.zones.where((z) => z.id == _selectedZoneId).firstOrNull;
    if (zone != null) {
      return [
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _editZone(scene, zone),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete pour',
          danger: true,
          onPressed: () => _deleteZone(zone),
        ),
      ];
    }

    return [
      _Chip(
        icon: Icons.undo,
        label: 'Undo',
        onPressed: history.canUndo ? _undo : null,
      ),
      _Chip(
        icon: Icons.redo,
        label: 'Redo',
        onPressed: history.canRedo ? _redo : null,
      ),
      if (scene.unplaced.isNotEmpty)
        _Chip(
          icon: Icons.inbox_outlined,
          label: '${scene.unplaced.length} to place',
          onPressed: () => _placeNext(scene),
        ),
      // Deletes whatever the sight is over, without selecting it first.
      _Chip(
        icon: Icons.backspace_outlined,
        label: 'Delete',
        danger: true,
        onPressed: _underCrosshair(scene) == null
            ? null
            : () => _deleteUnderCrosshair(scene),
      ),
      if (_hint != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _hint!,
            style: TextStyle(color: KicadPalette.highlight, fontSize: 12),
          ),
        ),
    ];
  }

  void _pickTool(AimTool tool) => setState(() {
    _clearDrawing();
    _measureFrom = null;
    _measureTo = null;
    _carryingId = null;
    _tool = tool;
    if (tool != AimTool.select) _clearSelection();
  });

  // --- placing ---------------------------------------------------------

  /// The one action. Everything precise goes through here, at the point the
  /// crosshair is showing, which is never under the user's hand.
  Future<void> _place(BoardScene scene, SnapTarget snap) async {
    final at = snap.at;

    if (_carryingId != null ||
        _carryingEdgeId != null ||
        _carryingOutline ||
        _carryingSelection) {
      await _drop(scene, at);
      return;
    }

    switch (_tool) {
      case AimTool.select:
        return;

      case AimTool.measure:
        setState(() {
          if (_measureFrom == null || _measureTo != null) {
            _measureFrom = at;
            _measureTo = null;
          } else {
            _measureTo = at;
          }
        });
        if (_measureTo != null) {
          _notify('${_mm((_measureTo! - _measureFrom!).distance)} mm');
        }
        return;

      case AimTool.via:
        await _dropVia(scene, at);
        return;

      case AimTool.route:
        _placeRouteCorner(scene, at, snap);
        return;

      case AimTool.zone:
      case AimTool.edge:
        HapticFeedback.selectionClick();
        setState(() => _points.add(at));
        return;

      case AimTool.region:
        HapticFeedback.selectionClick();
        setState(() {
          if (_regionFrom == null) {
            _regionFrom = at;
            _region = null;
            _selected = const _Selection.empty();
          } else {
            _region = Rect.fromPoints(_regionFrom!, at);
            _regionFrom = null;
            _selected = _Selection.inside(scene, _region!);
          }
        });
        if (_region != null && _selected.isEmpty) {
          _notify('Nothing in that area');
        }
        return;
    }
  }

  void _placeRouteCorner(BoardScene scene, Offset at, SnapTarget snap) {
    if (_points.isEmpty) {
      final pad = scene.padNear(at, 0.01);
      if (pad == null) {
        _notify('A track has to start on a pad');
        return;
      }
      HapticFeedback.selectionClick();
      setState(() {
        _clearSelection();
        _routeNetId = pad.netId;
        _routeLayer = _layerFor(pad);
        _points.add(pad.position);
      });
      return;
    }

    // Landing on a pad of the same net ends the track there, which is the
    // only way a track is ever actually finished.
    final pad = scene.padNear(at, 0.01);
    if (pad != null && (pad.position - _points.first).distance > 1e-6) {
      if (_routeNetId != null &&
          pad.netId != null &&
          pad.netId != _routeNetId) {
        _notify('${pad.label} is on a different net');
        return;
      }
      setState(() => _points.add(pad.position));
      unawaited(_finish(scene));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _points.add(_constrained(at)));
  }

  /// A point moved onto an allowed angle from the corner before it.
  Offset _constrained(Offset at) {
    if (_points.isEmpty) return at;
    final constrained = _angleLock.constrain(_points.last, at);
    // Still on the grid afterwards, when there is one: an angle lock that
    // throws away the grid is two settings fighting.
    if (!_snap || _grid <= 0) return constrained;
    return Offset(
      (constrained.dx / _grid).round() * _grid,
      (constrained.dy / _grid).round() * _grid,
    );
  }

  void _undoPoint() => setState(() {
    if (_points.length <= 1) {
      _clearDrawing();
    } else {
      _points.removeLast();
    }
  });

  void _clearDrawing() {
    _points.clear();
    _routeNetId = null;
    _routeLayer = null;
  }

  /// Writes whatever was being drawn.
  Future<void> _finish(BoardScene scene) async {
    switch (_tool) {
      case AimTool.route:
        await _finishRoute(scene);
      case AimTool.zone:
        await _finishZone(scene);
      case AimTool.edge:
        await _finishEdge(scene);
      case AimTool.select:
      case AimTool.via:
      case AimTool.measure:
      case AimTool.region:
        setState(_clearDrawing);
    }
  }

  Future<void> _finishRoute(BoardScene scene) async {
    final corners = _curveRadius > 0
        ? roundCorners(List<Offset>.from(_points), radius: _curveRadius)
        : List<Offset>.from(_points);
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);
    final netId = _routeNetId;
    setState(_clearDrawing);
    if (corners.length < 2) return;

    final repository = ref.read(boardRepositoryProvider);
    final written = <String>[];
    for (var i = 0; i < corners.length - 1; i++) {
      if ((corners[i + 1] - corners[i]).distance < 1e-9) continue;
      written.add(
        await repository.addTrack(
          projectId: widget.project.id,
          layer: layer,
          startX: corners[i].dx,
          startY: corners[i].dy,
          endX: corners[i + 1].dx,
          endY: corners[i + 1].dy,
          width: _widthFor(scene),
          netId: netId,
        ),
      );
    }
    if (written.isEmpty) return;

    HapticFeedback.lightImpact();
    _record(
      'Route',
      undo: () => repository.deleteTracks(written),
      redo: () async {},
    );
  }

  /// A pour of whatever shape was drawn.
  ///
  /// The old one could only fill the whole board, which is one pour out of
  /// the many a board wants: a patch of ground under a regulator, a
  /// triangle in a corner, a bar down one edge. Any polygon, anywhere.
  Future<void> _finishZone(BoardScene scene) async {
    final points = List<Offset>.from(_points);
    setState(_clearDrawing);
    if (points.length < 3) {
      _notify('A pour needs at least three corners');
      return;
    }

    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    if (!mounted) return;
    final net = await _chooseNet(nets);
    if (!mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final layer = ref.read(activeLayerProvider) == CopperLayer.front
        ? BoardLayer.frontCopper
        : BoardLayer.backCopper;

    final added = await repository.addZone(
      projectId: widget.project.id,
      layer: layer,
      points: points,
      netId: net?.net.id,
      netName: net?.displayName ?? '',
      clearance: math.max(scene.board.rules.clearance * 2, 0.4),
    );
    if (!mounted) return;
    setState(() => _selectedZoneId = added.id);
    _record(
      'Add a pour',
      undo: () => repository.deleteZone(added.id),
      redo: () => repository.restoreZone(added),
    );
  }

  /// An edge cut drawn corner to corner.
  ///
  /// Chained line segments, the way KiCad draws one — including an internal
  /// cutout, which is just a chain that comes back to where it started.
  /// Typing exact dimensions into a form is still there for when the number
  /// is what you have, but it is no longer the only way in.
  Future<void> _finishEdge(BoardScene scene) async {
    final points = List<Offset>.from(_points);
    setState(_clearDrawing);
    if (points.length < 2) return;

    final repository = ref.read(boardRepositoryProvider);
    // A chain that comes back to its start is a closed shape — a cutout —
    // and goes in as one polygon rather than a pile of loose lines.
    final closed =
        points.length >= 3 &&
        (points.last - points.first).distance <= math.max(_grid, 0.2);
    final added = await repository.addEdge(
      projectId: widget.project.id,
      kind: closed ? BoardEdgeKind.polygon : BoardEdgeKind.line,
      points: closed ? points.sublist(0, points.length - 1) : points,
    );

    // A run of more than two corners is several lines, not one.
    if (!closed && points.length > 2) {
      await repository.deleteEdge(added.id);
      final ids = <String>[];
      for (var i = 0; i < points.length - 1; i++) {
        final segment = await repository.addEdge(
          projectId: widget.project.id,
          kind: BoardEdgeKind.line,
          points: [points[i], points[i + 1]],
        );
        ids.add(segment.id);
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _record(
        'Add edge cuts',
        undo: () async {
          for (final id in ids) {
            await repository.deleteEdge(id);
          }
        },
        redo: () async {},
      );
      return;
    }

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedEdgeId = added.id);
    _record(
      'Add an edge cut',
      undo: () => repository.deleteEdge(added.id),
      redo: () => repository.restoreEdge(added),
    );
  }

  Future<NetWithEndpoints?> _chooseNet(List<NetWithEndpoints> nets) async {
    // Ground first: it is what a pour is for, nine times in ten.
    final ordered = [...nets]
      ..sort((a, b) {
        int rank(NetWithEndpoints n) {
          final name = (n.net.name ?? '').toUpperCase();
          if (name == 'GND') return 0;
          if (name.startsWith('GND') || name == 'VSS') return 1;
          return 2;
        }

        return rank(a).compareTo(rank(b));
      });

    return showModalBottomSheet<NetWithEndpoints>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'Fill this pour with',
                  style: Theme.of(sheet).textTheme.titleSmall,
                ),
              ),
              for (final net in ordered)
                ListTile(
                  dense: true,
                  title: Text(net.displayName),
                  onTap: () => Navigator.of(sheet).pop(net),
                ),
              ListTile(
                dense: true,
                title: const Text('No net'),
                subtitle: const Text('Unconnected copper'),
                onTap: () => Navigator.of(sheet).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dropVia(BoardScene scene, Offset at) async {
    final repository = ref.read(boardRepositoryProvider);
    final size = _viaFor(scene);
    final track = scene.trackNear(at, 0.4);
    final id = await repository.addVia(
      projectId: widget.project.id,
      x: at.dx,
      y: at.dy,
      diameter: size.diameter,
      drill: size.drill,
      netId: track?.netId,
    );
    HapticFeedback.lightImpact();
    _record(
      'Add a via',
      undo: () => repository.deleteVias([id]),
      redo: () async {},
    );
  }

  Future<void> _viaAndSwitch(BoardScene scene) async {
    if (_points.isEmpty) return;
    final at = _points.last;
    await _finishRoute(scene);
    await _dropVia(scene, at);
    if (!mounted) return;

    ref.read(activeLayerProvider.notifier).toggle();
    setState(() {
      _points
        ..clear()
        ..add(at);
      _routeLayer = ref.read(activeLayerProvider);
    });
  }

  // --- carrying a part -------------------------------------------------

  /// Picks a part up onto the crosshair. Panning then moves it, and PLACE
  /// puts it down — so a 1.6 mm part can be positioned to a hundredth of a
  /// millimetre without ever being hidden under a fingertip.
  void _carry(PlacedFootprint footprint) {
    setState(() {
      _carryingId = footprint.ref.id;
      _selectedFootprintId = footprint.ref.id;
      _carryAnchor = _lastSnap;
    });
    _notify('Pan to move ${footprint.part.reference}, then DROP');
  }

  /// Puts down whatever was picked up, wherever it was picked up from.
  Future<void> _drop(BoardScene scene, Offset at) async {
    final anchor = _carryAnchor;
    if (_carryingId != null) {
      await _dropCarried(scene, at);
      return;
    }
    if (anchor == null) return;
    final delta = at - anchor;

    final edgeId = _carryingEdgeId;
    final outline = _carryingOutline;
    final moving = _selected;
    setState(() {
      _carryAnchor = null;
      _carryingEdgeId = null;
      _carryingOutline = false;
    });
    if (delta == Offset.zero) return;

    final repository = ref.read(boardRepositoryProvider);
    final undos = <Future<void> Function()>[];
    final redos = <Future<void> Function()>[];

    if (outline) {
      final before = scene.board;
      final after = before.withOutline(_shiftOutline(scene.outline, delta));
      await repository.updateBoard(after);
      undos.add(() => repository.updateBoard(before));
      redos.add(() => repository.updateBoard(after));
    }

    for (final edge in scene.edges) {
      if (edge.id != edgeId && !moving.edgeIds.contains(edge.id)) continue;
      final after = edge.copyWith(
        points: [for (final p in edge.points) p + delta],
      );
      await repository.updateEdge(after);
      undos.add(() => repository.updateEdge(edge));
      redos.add(() => repository.updateEdge(after));
    }

    final placements =
        ref.read(boardFootprintsProvider(widget.project.id)).value ?? [];
    for (final placement in placements) {
      if (!moving.footprintIds.contains(placement.id)) continue;
      final after = placement.copyWith(
        x: placement.x + delta.dx,
        y: placement.y + delta.dy,
        placed: true,
      );
      await repository.updatePlacement(after);
      undos.add(() => repository.updatePlacement(placement));
      redos.add(() => repository.updatePlacement(after));
    }

    for (final track in scene.tracks) {
      if (!moving.trackIds.contains(track.id)) continue;
      final after = track.copyWith(
        startX: track.startX + delta.dx,
        startY: track.startY + delta.dy,
        endX: track.endX + delta.dx,
        endY: track.endY + delta.dy,
      );
      await repository.updateTrack(after);
      undos.add(() => repository.updateTrack(track));
      redos.add(() => repository.updateTrack(after));
    }

    for (final via in scene.vias) {
      if (!moving.viaIds.contains(via.id)) continue;
      final after = via.copyWith(x: via.x + delta.dx, y: via.y + delta.dy);
      await repository.updateVia(after);
      undos.add(() => repository.updateVia(via));
      redos.add(() => repository.updateVia(after));
    }

    for (final zone in scene.zones) {
      if (!moving.zoneIds.contains(zone.id)) continue;
      final after = zone.copyWith(
        points: [for (final p in zone.points) p + delta],
      );
      await repository.updateZone(after);
      undos.add(() => repository.updateZone(zone));
      redos.add(() => repository.updateZone(after));
    }

    if (undos.isEmpty) return;
    HapticFeedback.lightImpact();
    _record(
      outline ? 'Move the board outline' : 'Move',
      undo: () async {
        for (final undo in undos) {
          await undo();
        }
      },
      redo: () async {
        for (final redo in redos) {
          await redo();
        }
      },
    );
  }

  Future<void> _dropCarried(BoardScene scene, Offset at) async {
    final id = _carryingId;
    if (id == null) return;
    final footprint = scene.footprints
        .where((f) => f.ref.id == id)
        .firstOrNull;
    setState(() {
      _carryingId = null;
      _carryAnchor = null;
    });
    if (footprint == null) return;

    final repository = ref.read(boardRepositoryProvider);
    final placements =
        ref.read(boardFootprintsProvider(widget.project.id)).value ?? [];
    final before = placements.where((p) => p.id == id).firstOrNull;
    if (before == null) return;

    final after = before.copyWith(x: at.dx, y: at.dy, placed: true);
    await repository.updatePlacement(after);
    HapticFeedback.lightImpact();
    _record(
      'Move ${footprint.part.reference}',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  Future<void> _rotateCarried(BoardScene scene) async {
    final id = _carryingId;
    if (id == null) return;
    final placements =
        ref.read(boardFootprintsProvider(widget.project.id)).value ?? [];
    final before = placements.where((p) => p.id == id).firstOrNull;
    if (before == null) return;
    await ref
        .read(boardRepositoryProvider)
        .updatePlacement(before.copyWith(rotation: (before.rotation + 90) % 360));
  }

  void _carryEdge(BoardEdge edge) {
    setState(() {
      _carryAnchor = _lastSnap;
      _carryingEdgeId = edge.id;
    });
    _notify('Pan to move the cut, then DROP');
  }

  void _carryOutline(BoardScene scene) {
    setState(() {
      _carryAnchor = _lastSnap;
      _carryingOutline = true;
    });
    _notify('Pan to move the board, then DROP');
  }

  void _carryRegion() {
    setState(() {
      _carryAnchor = _lastSnap;
      _region = null;
      _regionFrom = null;
    });
    _notify('Pan to move ${_selected.count} things, then DROP');
  }

  /// Everything in the swept area, gone in one step.
  Future<void> _deleteSelection(BoardScene scene) async {
    final moving = _selected;
    if (moving.isEmpty) return;
    final repository = ref.read(boardRepositoryProvider);

    final tracks = [
      for (final track in scene.tracks)
        if (moving.trackIds.contains(track.id)) track,
    ];
    final vias = [
      for (final via in scene.vias)
        if (moving.viaIds.contains(via.id)) via,
    ];
    final edges = [
      for (final edge in scene.edges)
        if (moving.edgeIds.contains(edge.id)) edge,
    ];
    final zones = [
      for (final zone in scene.zones)
        if (moving.zoneIds.contains(zone.id)) zone,
    ];
    final placements = [
      for (final placement
          in ref.read(boardFootprintsProvider(widget.project.id)).value ?? [])
        if (moving.footprintIds.contains(placement.id)) placement,
    ];

    await repository.deleteTracks(tracks.map((t) => t.id));
    await repository.deleteVias(vias.map((v) => v.id));
    for (final edge in edges) {
      await repository.deleteEdge(edge.id);
    }
    for (final zone in zones) {
      await repository.deleteZone(zone.id);
    }
    // A part is taken off the board rather than deleted: it belongs to the
    // schematic, and the board does not get to remove it from the design.
    for (final placement in placements) {
      await repository.updatePlacement(placement.copyWith(placed: false));
    }

    if (!mounted) return;
    final count = moving.count;
    setState(_clearSelection);
    HapticFeedback.mediumImpact();
    _record(
      'Delete $count',
      undo: () async {
        await repository.restoreCopper(tracks: tracks, vias: vias);
        for (final edge in edges) {
          await repository.restoreEdge(edge);
        }
        for (final zone in zones) {
          await repository.restoreZone(zone);
        }
        for (final placement in placements) {
          await repository.updatePlacement(placement);
        }
      },
      redo: () async {},
    );
  }

  /// What the sight is currently over, for the delete button.
  Object? _underCrosshair(BoardScene scene) {
    final at = _lastSnap;
    final viewport = _viewport;
    if (viewport == null) return null;
    final tolerance = math.max(0.3, 16 / viewport.pixelsPerMm);

    final via = _nearestVia(scene, at, tolerance);
    if (via != null) return via;
    final edge = _nearestEdge(scene, at, tolerance);
    if (edge != null) return edge;
    final track = scene.trackNear(at, tolerance);
    if (track != null) return track;
    final zone = _zoneAt(scene, at);
    if (zone != null) return zone;
    return null;
  }

  Future<void> _deleteUnderCrosshair(BoardScene scene) async {
    switch (_underCrosshair(scene)) {
      case final Via via:
        await _deleteVia(via);
      case final BoardEdge edge:
        await _deleteEdge(edge);
      case final Track track:
        await _deleteTrack(track);
      case final BoardZone zone:
        await _deleteZone(zone);
      default:
        return;
    }
    HapticFeedback.mediumImpact();
  }

  /// Picks up the next part waiting to go on the board.
  void _placeNext(BoardScene scene) {
    final next = scene.unplaced.firstOrNull;
    if (next == null) return;
    setState(() {
      _carryingId = next.id;
      _tool = AimTool.select;
    });
    _notify('Pan to where it goes, then DROP');
  }

  // --- selection -------------------------------------------------------

  void _onTap(
    BoardScene scene,
    SchematicViewport viewport,
    Offset local,
  ) {
    if (_fabPreview || _carryingId != null) return;
    final board = viewport.toSheet(local);
    final tolerance = math.max(0.3, 16 / viewport.pixelsPerMm);

    // While drawing, a tap is not a selection — it would only get in the
    // way of the thing being drawn.
    if (_points.isNotEmpty) return;

    final via = _nearestVia(scene, board, tolerance);
    if (via != null) {
      setState(() {
        _clearSelection();
        _selectedViaId = via.id;
        _highlightedNetId = via.netId;
      });
      return;
    }

    final edge = _nearestEdge(scene, board, tolerance);
    if (edge != null) {
      setState(() {
        _clearSelection();
        _selectedEdgeId = edge.id;
      });
      return;
    }

    final track = scene.trackNear(board, tolerance);
    if (track != null) {
      setState(() {
        _clearSelection();
        _selectedTrackId = track.id;
        _highlightedNetId = track.netId;
      });
      return;
    }

    final footprint = scene.footprintAt(board);
    if (footprint != null) {
      setState(() {
        _clearSelection();
        _selectedFootprintId = footprint.ref.id;
      });
      return;
    }

    final zone = _zoneAt(scene, board);
    if (zone != null) {
      setState(() {
        _clearSelection();
        _selectedZoneId = zone.id;
        _highlightedNetId = zone.netId;
      });
      return;
    }

    // The board edge itself, which is as much a drawn thing as the cuts
    // added to it and was the one object that could not be picked up.
    if (_onOutline(scene, board, tolerance)) {
      setState(() {
        _clearSelection();
        _outlineSelected = true;
      });
      return;
    }

    setState(_clearSelection);
  }

  /// Whether [board] is on the board edge, within [tolerance].
  bool _onOutline(BoardScene scene, Offset board, double tolerance) {
    final outline = scene.outline;
    if (outline.kind == BoardOutlineKind.circle) {
      return ((board - outline.center).distance - outline.radius).abs() <=
          tolerance;
    }
    final corners = outline.path;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      if (_distanceToSegment(board, a, b) <= tolerance) return true;
    }
    return false;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-12) return (p - a).distance;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  void _clearSelection() {
    _selectedFootprintId = null;
    _selectedTrackId = null;
    _selectedViaId = null;
    _selectedEdgeId = null;
    _selectedZoneId = null;
    _highlightedNetId = null;
    _outlineSelected = false;
    _region = null;
    _regionFrom = null;
    _selected = const _Selection.empty();
  }

  // --- sizes -----------------------------------------------------------

  double _widthFor(BoardScene scene) =>
      _trackWidth ?? scene.board.rules.trackWidth;

  ViaSize _viaFor(BoardScene scene) =>
      _viaSize ??
      ViaSize(scene.board.rules.viaDiameter, scene.board.rules.viaDrill);

  Future<void> _chooseWidth(BoardScene scene) async {
    final chosen = await showTrackWidthPicker(
      context,
      widths: scene.board.availableTrackWidths,
      selected: _widthFor(scene),
      rule: scene.board.rules.trackWidth,
    );
    if (chosen == null || !mounted) return;
    if (chosen.edit) {
      await _editSizes(scene);
      return;
    }
    setState(() => _trackWidth = chosen.width);
  }

  Future<void> _chooseVia(BoardScene scene) async {
    final chosen = await showViaSizePicker(
      context,
      sizes: scene.board.availableViaSizes,
      selected: _viaFor(scene),
    );
    if (chosen == null || !mounted) return;
    if (chosen.edit) {
      await _editSizes(scene);
      return;
    }
    setState(() => _viaSize = chosen.size);
  }

  /// The board's own list of widths and via sizes, the way KiCad keeps one
  /// in Board Setup.
  Future<void> _editSizes(BoardScene scene) async {
    final result = await showTrackSizesDialog(
      context,
      widths: scene.board.trackWidths,
      viaSizes: scene.board.viaSizes,
    );
    if (result == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.copyWith(
      trackWidths: result.widths,
      viaSizes: result.viaSizes,
    );
    await repository.updateBoard(after);
    _record(
      'Track and via sizes',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  /// How far a track's corners are rounded.
  ///
  /// The copper that comes out is still ordinary straight segments — a
  /// short chain of them following the bend — so a curved track can still
  /// be selected, nudged and ripped up a piece at a time.
  Future<void> _chooseCurve(BoardScene scene) async {
    final width = _widthFor(scene);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'Corner rounding',
                  style: Theme.of(sheet).textTheme.titleSmall,
                ),
              ),
              for (final radius in [0.0, width, width * 2, width * 4, 2.0])
                ListTile(
                  dense: true,
                  leading: Icon(
                    radius == _curveRadius
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: radius == _curveRadius
                        ? KicadPalette.highlight
                        : KicadPalette.textSecondary,
                  ),
                  title: Text(
                    radius == 0 ? 'Sharp corners' : '${_mm(radius)} mm radius',
                  ),
                  subtitle: radius == 0
                      ? const Text('Straight segments meeting at a point')
                      : null,
                  onTap: () {
                    setState(() => _curveRadius = radius);
                    Navigator.of(sheet).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseGrid() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: _snap,
                onChanged: (value) {
                  setState(() => _snap = value);
                  Navigator.of(sheet).pop();
                },
                title: const Text('Snap to the grid'),
                subtitle: const Text(
                  'Off puts points exactly where the crosshair is',
                ),
              ),
              Divider(height: 1, color: KicadPalette.border),
              for (final grid in const [
                0.05,
                0.1,
                0.25,
                0.5,
                1.0,
                1.27,
                2.54,
              ])
                ListTile(
                  dense: true,
                  leading: Icon(
                    grid == _grid
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: grid == _grid
                        ? KicadPalette.highlight
                        : KicadPalette.textSecondary,
                  ),
                  title: Text('${_mm(grid)} mm'),
                  subtitle: switch (grid) {
                    1.27 => const Text('0.05 inch'),
                    2.54 => const Text('0.1 inch — headers and DIP'),
                    _ => null,
                  },
                  onTap: () {
                    setState(() {
                      _grid = grid;
                      _snap = true;
                    });
                    Navigator.of(sheet).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  CopperLayer _layerFor(PlacedPad pad) {
    final active = ref.read(activeLayerProvider);
    if (pad.reaches(active)) return active;
    return pad.layers.contains(BoardLayer.backCopper)
        ? CopperLayer.back
        : CopperLayer.front;
  }

  // --- the rest --------------------------------------------------------

  void _showMore(BoardScene scene) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) {
        Widget item(
          IconData icon,
          String label,
          VoidCallback onTap, {
          String? subtitle,
        }) => ListTile(
          dense: true,
          leading: Icon(icon, size: 20),
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: () {
            Navigator.of(sheet).pop();
            onTap();
          },
        );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                item(
                  Icons.crop_square,
                  'Board outline',
                  () => _chooseShape(scene),
                  subtitle: scene.outline.kind.label,
                ),
                item(
                  Icons.straighten,
                  'Track and via sizes',
                  () => _editSizes(scene),
                  subtitle:
                      '${scene.board.availableTrackWidths.length} widths · '
                      '${scene.board.availableViaSizes.length} vias',
                ),
                item(
                  Icons.tune,
                  'Design rules',
                  () => _editRules(scene),
                  subtitle:
                      '${_mm(scene.board.rules.trackWidth)} mm track · '
                      '${_mm(scene.board.rules.clearance)} mm clearance',
                ),
                Divider(height: 1, color: KicadPalette.border),
                item(
                  _showRatsnest ? Icons.visibility_off : Icons.visibility,
                  _showRatsnest ? 'Hide the ratsnest' : 'Show the ratsnest',
                  () => setState(() => _showRatsnest = !_showRatsnest),
                ),
                item(
                  Icons.photo_filter,
                  'As it will be made',
                  () => setState(() => _fabPreview = true),
                ),
                item(Icons.rule, 'Check the rules', () => _runDrc(scene)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assign(PartWithDetails part, String libId) async {
    await ref
        .read(boardRepositoryProvider)
        .assignFootprint(
          projectId: widget.project.id,
          partId: part.part.id,
          libId: libId,
        );
    if (mounted) setState(() => _assigningPartId = null);
  }

  Future<void> _footprintProperties(PlacedFootprint footprint) async {
    final result = await showFootprintProperties(
      context,
      placement: footprint.ref,
      reference: footprint.part.reference,
      value: footprint.part.value,
    );
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    final before = footprint.ref;

    switch (result) {
      case PropertiesDeleted<PlacedFootprintRef>():
        final after = before.copyWith(placed: false);
        await repository.updatePlacement(after);
        if (mounted) setState(() => _selectedFootprintId = null);
        _record(
          'Unplace ${footprint.part.reference}',
          undo: () => repository.updatePlacement(before),
          redo: () => repository.updatePlacement(after),
        );
      case PropertiesSaved<PlacedFootprintRef>(:final value):
        await repository.updatePlacement(value);
        _record(
          '${footprint.part.reference} properties',
          undo: () => repository.updatePlacement(before),
          redo: () => repository.updatePlacement(value),
        );
    }
  }

  Future<void> _trackProperties(BoardScene scene, Track track) async {
    final result = await showTrackProperties(
      context,
      track: track,
      netName: _netName(scene, track.netId) ?? '',
    );
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);

    switch (result) {
      case PropertiesDeleted<Track>():
        await _deleteTrack(track);
      case PropertiesSaved<Track>(:final value):
        await repository.updateTrack(value);
        if (mounted) setState(() => _trackWidth = value.width);
        _record(
          'Track properties',
          undo: () => repository.updateTrack(track),
          redo: () => repository.updateTrack(value),
        );
    }
  }

  Future<void> _viaProperties(BoardScene scene, Via via) async {
    final result = await showViaProperties(
      context,
      via: via,
      netName: _netName(scene, via.netId) ?? '',
    );
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);

    switch (result) {
      case PropertiesDeleted<Via>():
        await _deleteVia(via);
      case PropertiesSaved<Via>(:final value):
        await repository.updateVia(value);
        _record(
          'Via properties',
          undo: () => repository.updateVia(via),
          redo: () => repository.updateVia(value),
        );
    }
  }

  Future<void> _flip(PlacedFootprint footprint) async {
    final repository = ref.read(boardRepositoryProvider);
    final before = footprint.ref;
    final after = before.copyWith(flipped: !before.flipped);
    await repository.updatePlacement(after);
    _record(
      '${footprint.part.reference} to the ${after.flipped ? "back" : "front"}',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  Future<void> _deleteTrack(Track track) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteTracks([track.id]);
    if (mounted) setState(() => _selectedTrackId = null);
    _record(
      'Delete a track',
      undo: () => repository.restoreCopper(tracks: [track], vias: const []),
      redo: () => repository.deleteTracks([track.id]),
    );
  }

  Future<void> _deleteVia(Via via) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteVias([via.id]);
    if (mounted) setState(() => _selectedViaId = null);
    _record(
      'Delete a via',
      undo: () => repository.restoreCopper(tracks: const [], vias: [via]),
      redo: () => repository.deleteVias([via.id]),
    );
  }

  Future<void> _ripUpNet(String netId) async {
    final repository = ref.read(boardRepositoryProvider);
    final tracks = (await repository.getTracks(widget.project.id))
        .where((t) => t.netId == netId)
        .toList();
    final vias = (await repository.getVias(widget.project.id))
        .where((v) => v.netId == netId)
        .toList();
    await repository.ripUpNet(widget.project.id, netId);
    if (mounted) setState(() => _selectedTrackId = null);
    _record(
      'Rip up a net',
      undo: () => repository.restoreCopper(tracks: tracks, vias: vias),
      redo: () => repository.ripUpNet(widget.project.id, netId),
    );
  }

  Future<void> _deleteEdge(BoardEdge edge) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteEdge(edge.id);
    if (mounted) setState(() => _selectedEdgeId = null);
    _record(
      'Delete an edge cut',
      undo: () => repository.restoreEdge(edge),
      redo: () => repository.deleteEdge(edge.id),
    );
  }

  Future<void> _editZone(BoardScene scene, BoardZone zone) async {
    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    final result = await showZoneEditor(
      context,
      outline: scene.outline,
      nets: nets,
      defaultClearance: scene.board.rules.clearance,
      zone: zone,
    );
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);

    switch (result) {
      case ZoneDeleted():
        await _deleteZone(zone);
      case ZoneSaved(
        :final layer,
        :final points,
        :final netId,
        :final netName,
        :final clearance,
        :final minThickness,
      ):
        final after = zone.copyWith(
          layer: layer,
          points: points,
          netId: netId,
          clearNet: netId == null,
          netName: netName,
          clearance: clearance,
          minThickness: minThickness,
        );
        await repository.updateZone(after);
        _record(
          'Edit a pour',
          undo: () => repository.updateZone(zone),
          redo: () => repository.updateZone(after),
        );
    }
  }

  Future<void> _deleteZone(BoardZone zone) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteZone(zone.id);
    if (mounted) setState(() => _selectedZoneId = null);
    _record(
      'Delete a pour',
      undo: () => repository.restoreZone(zone),
      redo: () => repository.deleteZone(zone.id),
    );
  }

  Future<void> _chooseShape(BoardScene scene) async {
    final chosen = await showBoardShapeEditor(context, outline: scene.outline);
    if (chosen == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.withOutline(chosen);
    await repository.updateBoard(after);
    _record(
      'Board outline',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  Future<void> _editRules(BoardScene scene) async {
    final result = await showDesignRulesDialog(context, board: scene.board);
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.copyWith(rules: result.rules, gridMm: result.gridMm);
    await repository.updateBoard(after);
    _record(
      'Design rules',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  void _runDrc(BoardScene scene) => showDrcSheet(
    context,
    violations: checkBoard(scene),
    onShow: (violation) {
      final viewport = _viewport;
      if (viewport == null || _canvasSize.isEmpty) return;
      setState(() {
        _highlightedNetId = violation.netId;
        _viewport = viewport.copyWith(
          origin: Offset(
            _canvasSize.width / 2 -
                violation.position.dx * viewport.pixelsPerMm,
            _canvasSize.height / 2 -
                violation.position.dy * viewport.pixelsPerMm,
          ),
        );
      });
    },
  );

  Via? _nearestVia(BoardScene scene, Offset board, double tolerance) {
    Via? best;
    var bestDistance = double.infinity;
    for (final via in scene.vias) {
      final distance = (Offset(via.x, via.y) - board).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = via;
      }
    }
    return bestDistance <= math.max(tolerance, (best?.diameter ?? 0) / 2)
        ? best
        : null;
  }

  BoardEdge? _nearestEdge(BoardScene scene, Offset board, double tolerance) {
    BoardEdge? best;
    var bestDistance = double.infinity;
    for (final edge in scene.edges) {
      if (!edge.isValid) continue;
      final distance = edge.distanceTo(board);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = edge;
      }
    }
    return bestDistance <= tolerance ? best : null;
  }

  BoardZone? _zoneAt(BoardScene scene, Offset board) {
    for (final zone in scene.zones.reversed) {
      if (zone.isValid && zone.contains(board)) return zone;
    }
    return null;
  }

  String? _netName(BoardScene scene, String? netId) {
    if (netId == null) return null;
    for (final pad in scene.pads) {
      if (pad.netId == netId) return pad.netName;
    }
    return null;
  }

  Future<void> _undo() async {
    await ref.read(editHistoryProvider.notifier).undo();
    if (mounted) setState(_clearSelection);
  }

  Future<void> _redo() async {
    await ref.read(editHistoryProvider.notifier).redo();
    if (mounted) setState(_clearSelection);
  }

  void _record(
    String label, {
    required Future<void> Function() undo,
    required Future<void> Function() redo,
  }) {
    ref
        .read(editHistoryProvider.notifier)
        .push(
          widget.project.id,
          EditAction(label: label, undo: undo, redo: redo),
        );
  }

  void _notify(String message) {
    if (!mounted) return;
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  SchematicViewport _fitToContent(BoardScene scene, Size size) {
    final bounds = scene.contentBounds;
    if (bounds.width <= 0 || bounds.height <= 0 || size.isEmpty) {
      return const SchematicViewport(pixelsPerMm: 8, origin: Offset(20, 20));
    }
    const top = 52.0;
    const bottom = 70.0;
    final scale = math
        .min(
          (size.width - 40) / bounds.width,
          (size.height - top - bottom) / bounds.height,
        )
        .clamp(0.5, 80.0);
    return SchematicViewport(
      pixelsPerMm: scale,
      origin: Offset(
        (size.width - bounds.width * scale) / 2 - bounds.left * scale,
        top +
            (size.height - top - bottom - bounds.height * scale) / 2 -
            bounds.top * scale,
      ),
    );
  }

  static String _mm(double value) {
    final text = value.toStringAsFixed(3);
    return text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.tool,
    required this.selected,
    required this.onPressed,
  });

  final AimTool tool;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
    child: Material(
      color: selected
          ? KicadPalette.current.selectedContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? KicadPalette.highlight : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tool.icon,
                size: 16,
                color: selected
                    ? KicadPalette.highlight
                    : KicadPalette.textSecondary,
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Text(
                  tool.label,
                  style: TextStyle(
                    color: KicadPalette.highlight,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _StripChip extends StatelessWidget {
  const _StripChip({
    required this.label,
    required this.icon,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colour),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: colour, fontSize: 12)),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = onPressed == null
        ? KicadPalette.textDisabled
        : (danger ? KicadPalette.error : KicadPalette.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: KicadPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KicadPalette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: colour),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: colour, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasurePainter extends CustomPainter {
  _MeasurePainter({
    required this.from,
    required this.to,
    required this.viewport,
  });

  final Offset from;
  final Offset to;
  final SchematicViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final a = viewport.toScreen(from);
    final b = viewport.toScreen(to);
    final paint = Paint()
      ..color = KicadPalette.highlight
      ..strokeWidth = 1.5;
    canvas.drawLine(a, b, paint);
    canvas.drawCircle(a, 4, paint);

    final distance = (to - from).distance;
    final painter = TextPainter(
      text: TextSpan(
        text:
            '${distance.toStringAsFixed(2)} mm\n'
            'dx ${(to.dx - from.dx).abs().toStringAsFixed(2)}  '
            'dy ${(to.dy - from.dy).abs().toStringAsFixed(2)}',
        style: TextStyle(
          color: KicadPalette.highlight,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset((a.dx + b.dx) / 2 + 8, (a.dy + b.dy) / 2 - 8));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_MeasurePainter old) =>
      old.from != from || old.to != to || old.viewport != viewport;
}

/// Everything swept up by the area tool.
///
/// Held as ids rather than objects: the scene is rebuilt on every frame,
/// and a selection that pointed at last frame's objects would go stale the
/// moment anything moved.
class _Selection {
  const _Selection({
    required this.footprintIds,
    required this.trackIds,
    required this.viaIds,
    required this.edgeIds,
    required this.zoneIds,
  });

  const _Selection.empty()
    : footprintIds = const {},
      trackIds = const {},
      viaIds = const {},
      edgeIds = const {},
      zoneIds = const {};

  final Set<String> footprintIds;
  final Set<String> trackIds;
  final Set<String> viaIds;
  final Set<String> edgeIds;
  final Set<String> zoneIds;

  bool get isEmpty =>
      footprintIds.isEmpty &&
      trackIds.isEmpty &&
      viaIds.isEmpty &&
      edgeIds.isEmpty &&
      zoneIds.isEmpty;

  int get count =>
      footprintIds.length +
      trackIds.length +
      viaIds.length +
      edgeIds.length +
      zoneIds.length;

  /// What a dragged box on a desktop would have caught.
  ///
  /// Wholly inside, not merely touching: a box that grabs everything it
  /// brushes past is a box that deletes a track you could not see.
  factory _Selection.inside(BoardScene scene, Rect area) {
    // A hair of slack, so something whose corner sits exactly on the
    // boundary counts as inside rather than falling through the crack in
    // Rect's half-open right and bottom edges.
    final rect = Rect.fromLTRB(
      math.min(area.left, area.right),
      math.min(area.top, area.bottom),
      math.max(area.left, area.right),
      math.max(area.top, area.bottom),
    ).inflate(1e-6);
    return _Selection(
      footprintIds: {
        for (final footprint in scene.footprints)
          if (rect.contains(Offset(footprint.ref.x, footprint.ref.y)))
            footprint.ref.id,
      },
      trackIds: {
        for (final track in scene.tracks)
          if (rect.contains(Offset(track.startX, track.startY)) &&
              rect.contains(Offset(track.endX, track.endY)))
            track.id,
      },
      viaIds: {
        for (final via in scene.vias)
          if (rect.contains(Offset(via.x, via.y))) via.id,
      },
      edgeIds: {
        for (final edge in scene.edges)
          if (edge.isValid && edge.points.every(rect.contains)) edge.id,
      },
      zoneIds: {
        for (final zone in scene.zones)
          if (zone.isValid && zone.points.every(rect.contains)) zone.id,
      },
    );
  }

  String get summary {
    final parts = <String>[
      if (footprintIds.isNotEmpty)
        '${footprintIds.length} '
            '${footprintIds.length == 1 ? "part" : "parts"}',
      if (trackIds.isNotEmpty)
        '${trackIds.length} ${trackIds.length == 1 ? "track" : "tracks"}',
      if (viaIds.isNotEmpty)
        '${viaIds.length} ${viaIds.length == 1 ? "via" : "vias"}',
      if (edgeIds.isNotEmpty)
        '${edgeIds.length} ${edgeIds.length == 1 ? "cut" : "cuts"}',
      if (zoneIds.isNotEmpty)
        '${zoneIds.length} ${zoneIds.length == 1 ? "pour" : "pours"}',
    ];
    return parts.isEmpty ? 'Nothing selected' : parts.join(' · ');
  }
}

/// The box being swept, and what it has caught.
class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.from,
    required this.to,
    required this.settled,
    required this.viewport,
  });

  final Offset from;
  final Offset to;

  /// Whether both corners are down, or the second is still following the
  /// crosshair.
  final bool settled;

  final SchematicViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(
      viewport.toScreen(from),
      viewport.toScreen(to),
    );
    canvas.drawRect(
      rect,
      Paint()..color = KicadPalette.highlight.withValues(alpha: 0.12),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = settled ? 1.6 : 1.0
        ..color = KicadPalette.highlight,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.from != from || old.to != to || old.settled != settled;
}
