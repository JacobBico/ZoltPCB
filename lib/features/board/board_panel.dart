import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cross_probe.dart';
import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../core/widgets/zoom_controls.dart';
import '../../data/repositories/footprint_library_repository.dart';
import '../../data/repositories/net_repository.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../rendering/schematic_viewport.dart';
import '../project/canvas_action_bar.dart';
import 'board_painter.dart';
import 'board_sync_dialog.dart';
import 'impedance_dialog.dart';
import 'net_lengths_dialog.dart';
import 'stackup_dialog.dart';
import 'board_shape_editor.dart';
import 'edge_cut_editor.dart';
import 'zone_editor.dart';
import 'design_rules_dialog.dart';
import 'drc_sheet.dart';
import 'footprint_sidebar.dart';

/// What a drag and a tap mean right now.
///
/// Two modes rather than one clever gesture. On a phone the same drag has to
/// be either "move this part" or "draw this track", and guessing which gets
/// it wrong often enough to be worse than asking.
enum BoardMode {
  place('Place', Icons.open_with),
  route('Route', Icons.timeline);

  const BoardMode(this.label, this.icon);

  final String label;
  final IconData icon;

  BoardMode get other => this == place ? route : place;
}

/// The board editor: place footprints, draw copper, check the rules.
class BoardPanel extends ConsumerStatefulWidget {
  const BoardPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<BoardPanel> createState() => _BoardPanelState();
}

class _BoardPanelState extends ConsumerState<BoardPanel> {
  SchematicViewport? _viewport;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// A passing message shown in place of the action bar's title.
  String? _hint;
  Timer? _hintTimer;

  /// Where the current touch actually landed, in canvas pixels. See the
  /// [Listener] around the canvas for why the recogniser's own start point
  /// will not do.
  Offset? _touchDown;
  BoardMode _mode = BoardMode.place;

  /// The canvas's last laid-out size, for centring the view on a point.
  Size _canvasSize = Size.zero;

  /// The pad a Place-mode tap landed on, so the action bar can offer to
  /// start a route from it without a trip to the mode switch first.
  PlacedPad? _tappedPad;

  /// Showing the board as it will be made, rather than editing it.
  bool _fabPreview = false;
  bool _fabBack = false;

  /// Whether the board is being looked at in three dimensions.

  String? _selectedFootprintId;
  String? _selectedTrackId;
  String? _highlightedNetId;
  bool _showRatsnest = true;

  /// The part whose footprint is being chosen, if the picker is open.
  String? _assigningPartId;

  // Placement drag. Which footprint is under the finger is decided when the
  // gesture starts; whether it is a drag or a tap only once it has moved.
  String? _candidateFootprintId;
  bool _isDragging = false;
  Offset? _dragStartBoard;
  Offset? _dragOriginalPosition;
  Offset? _dragPosition;

  // The view as it was when the current gesture began.
  //
  // Zoom has to be computed against this rather than against the live
  // viewport: `ScaleUpdateDetails.scale` is cumulative from the start of the
  // gesture, so applying it to the already-zoomed view compounds it on every
  // frame and a slow pinch runs away to either extreme.
  SchematicViewport? _gestureStartViewport;
  Offset _gestureStartFocal = Offset.zero;

  /// The outline handle being dragged, and the shape it started from.
  int? _outlineCorner;
  BoardOutline? _outlineStart;

  /// The handle the user last touched, so its verbs can apply to it.
  int? _selectedOutlineHandle;

  /// The extra edge cut, and the copper pour, the user has hold of.
  String? _selectedEdgeId;
  String? _selectedZoneId;

  // The route being drawn. Corners are tapped rather than dragged: a finger
  // covers the copper it is drawing, and tapping lets you see each corner
  // land before committing to the next.
  final _routePoints = <Offset>[];
  String? _routeNetId;
  String? _routeStartPadId;
  CopperLayer? _routeLayer;
  TrackAngleMode _angleMode = TrackAngleMode.diagonal;
  bool _straightFirst = false;

  /// The segment the finger is drawing right now, ahead of [_routePoints].
  ///
  /// Kept apart from the committed points so a drag can be abandoned by
  /// lifting without moving, and so the preview can be recomputed on every
  /// frame without touching what has already been decided.
  List<Offset> _routePreview = const [];
  bool _isRouteDragging = false;

  /// The pad the finger is currently over, if the route would end there.
  PlacedPad? _routeTarget;

  bool get _isRouting => _routePoints.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final sceneAsync = ref.watch(boardSceneProvider(widget.project.id));

    if (sceneAsync case AsyncError(:final error)) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not draw the board',
        message: '$error',
      );
    }
    final committed = sceneAsync.value;
    if (committed == null) return const SizedBox.shrink();

    // What is on the screen right now, drag included. Without this the
    // committed scene is all that ever gets drawn, so a footprint sits
    // still under the finger and jumps to its new place on release — which
    // reads as the canvas lagging rather than as nothing having moved.
    final scene = _withLiveDrag(committed);
    ref.watch(crossProbeProvider);
    _takeProbe(committed);
    _persistCopperCorrections(committed);

    final parts = ref.watch(projectPartsProvider(widget.project.id)).value;
    final assigning = parts
        ?.where((p) => p.part.id == _assigningPartId)
        .firstOrNull;

    return Row(
      children: [
        Expanded(
          child: parts == null || parts.isEmpty
              ? _noParts()
              : _canvas(scene, parts),
        ),
        if (assigning != null)
          FootprintSidebar(
            part: assigning,
            currentLibId: scene.footprints
                .where((f) => f.part.id == assigning.part.id)
                .firstOrNull
                ?.ref
                .libId,
            onChoose: (entry) => _assignFootprint(scene, assigning, entry),
            onClose: () => setState(() => _assigningPartId = null),
          ),
      ],
    );
  }

  /// Whether a correction write is already on its way, so a rebuild that
  /// lands before it finishes does not issue a second one.
  bool _correctingCopper = false;

  /// Brings stored copper nets into line with what the scene resolved.
  ///
  /// The scene already draws and checks the right nets, so this changes
  /// nothing on screen. It is for everything that goes by the stored id —
  /// ripping up a net, the next export — which would otherwise be working
  /// from the schematic as it was before it changed.
  void _persistCopperCorrections(BoardScene scene) {
    if (!scene.hasStaleCopper || _correctingCopper || _isDragging) return;
    _correctingCopper = true;

    final trackNets = {
      for (final track in scene.tracks)
        if (scene.staleTrackIds.contains(track.id)) track.id: track.netId,
    };
    final viaNets = {
      for (final via in scene.vias)
        if (scene.staleViaIds.contains(via.id)) via.id: via.netId,
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(boardRepositoryProvider)
            .setCopperNets(tracks: trackNets, vias: viaNets);
      } finally {
        _correctingCopper = false;
      }
    });
  }

  /// How long the route is so far, preview included. Worth seeing while
  /// drawing: a clock line or a sense trace is routed to a length, not just
  /// to a destination.
  double get _routeLengthMm {
    final points = _drawnRoute;
    var length = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      length += (points[i + 1] - points[i]).distance;
    }
    return length;
  }

  /// The whole route as it currently looks: decided corners plus whatever
  /// the finger is drawing.
  List<Offset> get _drawnRoute => _routePreview.isEmpty
      ? _routePoints
      : [..._routePoints, ..._routePreview.skip(1)];

  /// The committed scene with the gesture in progress applied.
  ///
  /// Rebuilt from the same inputs the provider uses, so pads, the ratsnest
  /// and hit-testing all follow the finger together rather than the drawing
  /// moving while the geometry behind it stays put.
  BoardScene _withLiveDrag(BoardScene committed) {
    final position = _dragPosition;
    if (!_isDragging || position == null) return committed;

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

    final corner = _outlineCorner;
    final outlineStart = _outlineStart;
    var board = committed.board;
    if (corner != null && outlineStart != null) {
      board = board.withOutline(
        outlineStart.withHandleAt(
          corner,
          position,
          minimum: math.max(board.gridMm * 2, 0.2),
        ),
      );
    }

    final id = _candidateFootprintId;
    return BoardScene.build(
      texts: committed.texts,
      netClasses: committed.netClasses,
      board: board,
      parts: parts,
      nets: nets,
      placements: [
        for (final placement in placements)
          if (id != null && placement.id == id)
            placement.copyWith(x: position.dx, y: position.dy, placed: true)
          else
            placement,
      ],
      definitions: definitions,
      tracks: committed.tracks,
      vias: committed.vias,
    );
  }

  Widget _noParts() => const EmptyState(
    icon: Icons.developer_board_outlined,
    title: 'Nothing to lay out yet',
    message:
        'A board is built from the schematic. Add components and wire '
        'them up first, then come back to place and route them.',
  );

  Widget _canvas(BoardScene scene, List<PartWithDetails> parts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _canvasSize = size;
        final viewport = _viewport ??= _fitToContent(scene, size);

        return Stack(
          children: [
            Positioned.fill(
              // The recogniser only reports a gesture once the finger has
              // travelled past its slop, and it reports it from there — a
              // few millimetres from where the finger actually landed at
              // normal zoom. Asking "what is under the finger" at that point
              // missed a small part entirely and panned instead of dragging.
              // The touch-down point is taken from the raw pointer event.
              child: Listener(
                onPointerDown: (event) => _touchDown = event.localPosition,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      _onTap(scene, viewport, details.localPosition),
                  onScaleStart: (details) =>
                      _onScaleStart(scene, viewport, details),
                  onScaleUpdate: (details) => _onScaleUpdate(scene, details),
                  onScaleEnd: (_) => _onScaleEnd(scene),
                  child: CustomPaint(
                    painter: BoardPainter(
                      scene: scene,
                      viewport: viewport,
                      activeLayer: ref.watch(activeLayerProvider),
                      selectedFootprintId: _selectedFootprintId,
                      selectedTrackId: _selectedTrackId,
                      highlightedNetId: _highlightedNetId,
                      pendingRoute: _drawnRoute,
                      pendingLayer: _routeLayer,
                      showRatsnest: _showRatsnest,
                      routeTargetPad: _routeTarget,
                      selectedOutlineHandle: _selectedOutlineHandle,
                      selectedEdgeId: _selectedEdgeId,
                      selectedZoneId: _selectedZoneId,
                      showOutlineGrips: _mode == BoardMode.place,
                      draggingOutline: _outlineCorner != null,
                      fabPreview: _fabPreview,
                      fabBack: _fabBack,
                    ),
                    size: size,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _BoardStatusBar(
                scene: scene,
                mode: _mode,
                layer: ref.watch(activeLayerProvider),
                parts: parts,
                onAssign: (partId) => setState(() => _assigningPartId = partId),
                onPlace: (footprint) => _place(scene, footprint),
                onPlaceAll: () => _placeAll(scene),
                onBuild: () => _buildBoard(scene, parts),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              // Room for the zoom column and a gap, and no more.
              right: 68,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _actionBar(scene, parts),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: ZoomControls(
                fitTooltip: 'Fit to board',
                onZoom: (factor) => setState(() {
                  _viewport = viewport.zoomedAbout(
                    Offset(size.width / 2, size.height / 2),
                    factor,
                  );
                }),
                onFit: () => setState(() {
                  _viewport = _fitToContent(scene, size);
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- the action bar --------------------------------------------------

  Widget _actionBar(BoardScene scene, List<PartWithDetails> parts) {
    final history = ref.watch(editHistoryProvider);
    final layer = ref.watch(activeLayerProvider);

    final actions = <CanvasAction>[
      CanvasAction(
        label: 'Undo',
        icon: Icons.undo,
        onPressed: history.canUndo ? _undo : null,
      ),
      CanvasAction(
        label: 'Redo',
        icon: Icons.redo,
        onPressed: history.canRedo ? _redo : null,
      ),
      CanvasAction(
        label: _mode.other.label,
        icon: _mode.other.icon,
        onPressed: () => setState(() {
          _cancelRoute();
          _mode = _mode.other;
          _selectedFootprintId = null;
          _selectedTrackId = null;
        }),
      ),
      CanvasAction(
        label: layer.label,
        icon: Icons.layers_outlined,
        onPressed: () {
          final board = ref
              .read(boardSceneProvider(widget.project.id))
              .value
              ?.board;
          if (board == null) {
            ref.read(activeLayerProvider.notifier).toggle();
          } else {
            ref.read(activeLayerProvider.notifier).next(board);
          }
        },
      ),
    ];

    var title = '';

    // The preview is for looking, not editing: every verb that would change
    // the board is out of reach until it is closed, so nothing can be moved
    // by accident while admiring it.
    if (_fabPreview) {
      return CanvasActionBar(
        title: _fabBack ? 'As made · underside' : 'As made · top',
        actions: [
          CanvasAction(
            label: _fabBack ? 'Top' : 'Underside',
            icon: Icons.flip,
            onPressed: () => setState(() => _fabBack = !_fabBack),
          ),
          CanvasAction(
            label: 'Close',
            icon: Icons.close,
            onPressed: () => setState(() {
              _fabPreview = false;
              _fabBack = false;
            }),
          ),
        ],
      );
    }

    if (_isRouting) {
      title =
          'Routing ${_routeNetName(scene) ?? ''} · '
          '${_routeLengthMm.toStringAsFixed(1)} mm';
      actions.addAll(_routingActions(scene));
    } else if (_mode == BoardMode.route) {
      title = 'Drag from a pad';
      actions.addAll([
        CanvasAction(
          label: _angleMode.label,
          icon: Icons.turn_sharp_right_outlined,
          onPressed: () => setState(() => _angleMode = _angleMode.next),
        ),
        _ratsnestAction(scene),
        _drcAction(scene),
      ]);
    } else {
      final footprint = scene.footprints
          .where((f) => f.ref.id == _selectedFootprintId)
          .firstOrNull;
      final track = scene.tracks
          .where((t) => t.id == _selectedTrackId)
          .firstOrNull;
      final handle = _selectedOutlineHandle;

      final edge = scene.edges
          .where((e) => e.id == _selectedEdgeId)
          .firstOrNull;
      final zone = scene.zones
          .where((z) => z.id == _selectedZoneId)
          .firstOrNull;

      if (handle != null) {
        title = '${scene.outline.kind.label} corner';
        actions.addAll(_outlineActions(scene, handle));
      } else if (edge != null) {
        title = '${edge.kind.label} · ${edge.summary}';
        actions.addAll([
          CanvasAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () => _editEdge(scene, edge),
          ),
          CanvasAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteEdge(edge),
          ),
          CanvasAction(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => setState(() => _selectedEdgeId = null),
          ),
        ]);
      } else if (zone != null) {
        title =
            '${zone.label} pour · '
            '${zone.layer == BoardLayer.frontCopper ? "front" : "back"}';
        actions.addAll([
          CanvasAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () => _editZone(scene, zone),
          ),
          CanvasAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteZone(zone),
          ),
          CanvasAction(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => setState(() => _selectedZoneId = null),
          ),
        ]);
      } else if (footprint != null) {
        final pad = _tappedPad;
        title = pad == null ? footprint.part.reference : pad.label;
        if (pad != null) {
          actions.add(
            CanvasAction(
              label: 'Route from ${pad.pad.number}',
              icon: Icons.timeline,
              onPressed: () => setState(() {
                _mode = BoardMode.route;
                _selectedFootprintId = null;
                _tappedPad = null;
                _startRouteAt(pad, _layerFor(pad));
              }),
            ),
          );
        }
        actions.addAll(_footprintActions(footprint, parts));
      } else if (track != null) {
        title = _netName(scene, track.netId) ?? 'Track';
        actions.addAll([
          CanvasAction(
            label: 'Rip up',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteTrack(track),
          ),
          CanvasAction(
            label: 'Rip net',
            icon: Icons.layers_clear_outlined,
            danger: true,
            onPressed: track.netId == null
                ? null
                : () => _ripUpNet(scene, track.netId!),
          ),
        ]);
      } else {
        actions.add(
          CanvasAction(
            label: 'More',
            icon: Icons.more_horiz,
            onPressed: () => _showMore(scene),
          ),
        );
      }
    }

    return CanvasActionBar(
      title: _hint ?? title,
      hinting: _hint != null,
      actions: actions,
    );
  }

  /// What a selected board corner can do.
  List<CanvasAction> _outlineActions(BoardScene scene, int handle) {
    final outline = scene.outline;
    final isPolygon = outline.kind == BoardOutlineKind.polygon;

    return [
      CanvasAction(
        label: 'Shape',
        icon: Icons.crop_square,
        onPressed: () => _chooseShape(scene),
      ),
      CanvasAction(
        label: 'Add',
        icon: Icons.add_circle_outline,
        // Adding a corner is what turns a rectangle into any other shape,
        // so it is offered on every kind and converts as a side effect.
        onPressed: () => _changeOutlinePoints(
          scene,
          outline.as(BoardOutlineKind.polygon).withPointAfter(handle),
          'Add board corner',
        ),
      ),
      CanvasAction(
        label: 'Remove',
        icon: Icons.remove_circle_outline,
        danger: true,
        // A triangle is the floor: below three corners there is no shape.
        onPressed: isPolygon && outline.points.length > 3
            ? () => _changeOutlinePoints(
                scene,
                outline.withoutPoint(handle),
                'Remove board corner',
              )
            : null,
      ),
      CanvasAction(
        label: 'Done',
        icon: Icons.check,
        onPressed: () => setState(() => _selectedOutlineHandle = null),
      ),
    ];
  }

  /// Opens the board edge editor, where every dimension is typed.
  Future<void> _chooseShape(BoardScene scene) async {
    final chosen = await showBoardShapeEditor(context, outline: scene.outline);
    if (chosen == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final original = scene.board;
    final after = original.withOutline(chosen);
    await repository.updateBoard(after);
    if (mounted) setState(() => _selectedOutlineHandle = null);
    _record(
      'Board shape',
      undo: () => repository.updateBoard(original),
      redo: () => repository.updateBoard(after),
    );
  }

  /// Adds an edge cut, or edits the one selected.
  Future<void> _editEdge(BoardScene scene, BoardEdge? edge) async {
    final result = await showEdgeCutEditor(
      context,
      outline: scene.outline,
      edge: edge,
    );
    if (result == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);

    switch (result) {
      case EdgeCutDeleted():
        if (edge != null) await _deleteEdge(edge);
      case EdgeCutSaved(:final kind, :final points, :final width):
        if (edge == null) {
          final added = await repository.addEdge(
            projectId: widget.project.id,
            kind: kind,
            points: points,
            width: width,
          );
          if (!mounted) return;
          setState(() => _selectedEdgeId = added.id);
          _record(
            'Add ${kind.label.toLowerCase()} edge cut',
            undo: () => repository.deleteEdge(added.id),
            redo: () => repository.restoreEdge(added),
          );
        } else {
          final after = edge.copyWith(kind: kind, points: points, width: width);
          await repository.updateEdge(after);
          _record(
            'Edit edge cut',
            undo: () => repository.updateEdge(edge),
            redo: () => repository.updateEdge(after),
          );
        }
    }
  }

  Future<void> _deleteEdge(BoardEdge edge) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteEdge(edge.id);
    if (mounted) setState(() => _selectedEdgeId = null);
    _record(
      'Delete edge cut',
      undo: () => repository.restoreEdge(edge),
      redo: () => repository.deleteEdge(edge.id),
    );
  }

  /// Adds a copper pour, or edits the one selected.
  Future<void> _editZone(BoardScene scene, BoardZone? zone) async {
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
        if (zone != null) await _deleteZone(zone);
      case ZoneSaved(
        :final layer,
        :final points,
        :final netId,
        :final netName,
        :final clearance,
        :final minThickness,
      ):
        if (zone == null) {
          final added = await repository.addZone(
            projectId: widget.project.id,
            layer: layer,
            points: points,
            netId: netId,
            netName: netName,
            clearance: clearance,
            minThickness: minThickness,
          );
          if (!mounted) return;
          setState(() => _selectedZoneId = added.id);
          _record(
            'Add ${added.label} pour',
            undo: () => repository.deleteZone(added.id),
            redo: () => repository.restoreZone(added),
          );
        } else {
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
            'Edit pour',
            undo: () => repository.updateZone(zone),
            redo: () => repository.updateZone(after),
          );
        }
    }
  }

  Future<void> _deleteZone(BoardZone zone) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteZone(zone.id);
    if (mounted) setState(() => _selectedZoneId = null);
    _record(
      'Delete pour',
      undo: () => repository.restoreZone(zone),
      redo: () => repository.deleteZone(zone.id),
    );
  }

  /// The verbs you reach for once a board rather than once a minute.
  ///
  /// They used to sit on the bar beside Undo, all eight of them, which made
  /// a strip of twelve buttons across a screen that is four hundred pixels
  /// tall — a quarter of the board covered by things nobody was about to
  /// press.
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
                  'Board shape',
                  () => _chooseShape(scene),
                  subtitle: scene.outline.kind.label,
                ),
                item(
                  Icons.content_cut,
                  'Add an edge cut',
                  () => _editEdge(scene, null),
                  subtitle: 'Slots, cutouts, rounded corners',
                ),
                item(
                  Icons.format_color_fill_outlined,
                  'Add a copper pour',
                  () => _editZone(scene, null),
                  subtitle: 'A ground plane, usually',
                ),
                item(Icons.sync, 'Update from schematic', () async {
                  final message = await showBoardSyncDialog(
                    context,
                    projectId: widget.project.id,
                  );
                  if (message != null) _notify(message);
                }),
                item(
                  Icons.layers_outlined,
                  'Board build',
                  () => _editBuild(scene),
                  subtitle:
                      '${scene.board.copperLayerCount} layers · '
                      '${scene.board.stackup.thickness.toStringAsFixed(2)} mm',
                ),
                item(
                  Icons.speed,
                  'Impedance calculator',
                  () => showImpedanceCalculator(
                    context,
                    board: scene.board,
                    layer: ref.read(activeLayerProvider),
                  ),
                ),
                item(
                  Icons.straighten,
                  'Net lengths',
                  () => showNetLengthsDialog(context, scene: scene),
                ),
                item(
                  Icons.tune,
                  'Design rules',
                  () => _editSettings(scene),
                  subtitle:
                      '${scene.board.rules.trackWidth} mm track · '
                      '${scene.board.rules.clearance} mm clearance',
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
                  () => setState(() {
                    _cancelRoute();
                    _fabPreview = true;
                    _selectedFootprintId = null;
                    _selectedTrackId = null;
                    _selectedOutlineHandle = null;
                  }),
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

  Future<void> _editBuild(BoardScene scene) async {
    final used = {for (final t in scene.tracks) t.layer};
    final after = await showStackupDialog(
      context,
      board: scene.board,
      usedLayers: used,
    );
    if (after == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    await repository.updateBoard(after);
    if (!after.hasLayer(ref.read(activeLayerProvider))) {
      ref.read(activeLayerProvider.notifier).set(CopperLayer.front);
    }
    _record(
      'Board build',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  CanvasAction _ratsnestAction(BoardScene scene) => CanvasAction(
    label: _showRatsnest ? 'Hide rats' : 'Show rats',
    icon: _showRatsnest ? Icons.visibility_off : Icons.visibility,
    onPressed: () => setState(() => _showRatsnest = !_showRatsnest),
  );

  CanvasAction _drcAction(BoardScene scene) => CanvasAction(
    label: 'Check',
    icon: Icons.rule,
    onPressed: () => _runDrc(scene),
  );

  void _runDrc(BoardScene scene) => showDrcSheet(
    context,
    violations: checkBoard(scene),
    onShow: (violation) => setState(() {
      _highlightedNetId = violation.netId;
      _focusOn(violation.position);
    }),
  );

  /// Centres the view on a point of the board, close enough to see it.
  /// Acts on a probe sent from the schematic: selects the part, or lights
  /// up the net, and brings it into view.
  void _takeProbe(BoardScene scene) {
    if (ref.read(crossProbeProvider)?.target != ProbeTarget.board) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final request = ref
          .read(crossProbeProvider.notifier)
          .take(ProbeTarget.board);
      if (request == null) return;
      final footprint = scene.footprints
          .where((f) => f.part.id == request.partId)
          .firstOrNull;
      final pad = scene.pads.where((p) => p.netId == request.netId).firstOrNull;
      if (footprint == null && pad == null) {
        _notify('Not on the board yet');
        return;
      }
      setState(() {
        _selectedFootprintId = footprint?.ref.id;
        _selectedTrackId = null;
        _highlightedNetId = request.netId;
      });
      _focusOn(
        footprint != null
            ? Offset(footprint.ref.x, footprint.ref.y)
            : pad!.position,
      );
    });
  }

  void _focusOn(Offset board) {
    final viewport = _viewport;
    final size = _canvasSize;
    if (viewport == null || size.isEmpty) return;

    // Zoom in if the view is too far out to make out a 0.2 mm gap, but never
    // zoom out: someone already looking closely wants to stay close.
    final zoom = math.max(viewport.pixelsPerMm, 16.0);
    _viewport = SchematicViewport(
      pixelsPerMm: zoom,
      origin: Offset(
        size.width / 2 - board.dx * zoom,
        size.height / 2 - board.dy * zoom,
      ),
    );
  }

  List<CanvasAction> _routingActions(BoardScene scene) => [
    CanvasAction(
      label: _angleMode.label,
      icon: Icons.turn_sharp_right_outlined,
      onPressed: () => setState(() => _angleMode = _angleMode.next),
    ),
    CanvasAction(
      label: 'Corner',
      icon: Icons.swap_calls,
      onPressed: () => setState(() => _straightFirst = !_straightFirst),
    ),
    CanvasAction(
      label: 'Via',
      icon: Icons.circle_outlined,
      onPressed: () => _dropVia(scene),
    ),
    CanvasAction(
      label: 'Back',
      icon: Icons.undo,
      onPressed: _routePoints.length < 2
          ? null
          : () => setState(() {
              _routePoints.removeLast();
              _routePreview = const [];
            }),
    ),
    CanvasAction(
      label: 'Finish',
      icon: Icons.check,
      onPressed: _routePoints.length < 2 ? null : () => _commitRoute(scene),
    ),
    CanvasAction(
      label: 'Cancel',
      icon: Icons.close,
      danger: true,
      onPressed: () => setState(_cancelRoute),
    ),
  ];

  List<CanvasAction> _footprintActions(
    PlacedFootprint footprint,
    List<PartWithDetails> parts,
  ) => [
    CanvasAction(
      label: 'Rotate',
      icon: Icons.rotate_90_degrees_ccw,
      onPressed: () => _reposition(
        footprint.ref,
        footprint.ref.copyWith(rotation: (footprint.ref.rotation + 90) % 360),
        'Rotate ${footprint.part.reference}',
      ),
    ),
    CanvasAction(
      label: footprint.ref.flipped ? 'To front' : 'To back',
      icon: Icons.flip,
      onPressed: () => _reposition(
        footprint.ref,
        footprint.ref.copyWith(flipped: !footprint.ref.flipped),
        'Flip ${footprint.part.reference}',
      ),
    ),
    CanvasAction(
      label: 'Footprint',
      icon: Icons.dashboard_customize_outlined,
      onPressed: () => setState(() => _assigningPartId = footprint.part.id),
    ),
    CanvasAction(
      label: 'Unplace',
      icon: Icons.output_outlined,
      danger: true,
      onPressed: () => _reposition(
        footprint.ref,
        footprint.ref.copyWith(placed: false),
        'Unplace ${footprint.part.reference}',
      ),
    ),
  ];

  // --- gestures --------------------------------------------------------

  /// How far a tap may land from a pad and still count, in millimetres.
  ///
  /// Pads are often under a millimetre across and a fingertip is eight, so
  /// the target has to be far bigger than the mark — the same lesson the
  /// schematic's wires taught, at a quarter of the scale.
  double _padTolerance(SchematicViewport viewport) =>
      math.max(0.4, 24 / viewport.pixelsPerMm);

  double _trackTolerance(SchematicViewport viewport) =>
      math.max(0.5, 28 / viewport.pixelsPerMm);

  Future<void> _onTap(
    BoardScene scene,
    SchematicViewport viewport,
    Offset screen,
  ) async {
    final board = viewport.toSheet(screen);
    if (_fabPreview) return;

    if (_mode == BoardMode.route) {
      await _routeTap(scene, viewport, board);
      return;
    }

    // A midpoint marker is only ever a request for another corner, so it
    // is checked before anything else can claim the tap.
    final midpoint = _outlineMidpointNear(scene, viewport, board);
    if (midpoint != null) {
      await _changeOutlinePoints(
        scene,
        scene.outline.withPointAfter(midpoint),
        'Add board corner',
      );
      return;
    }

    final handle = _outlineCornerNear(scene, viewport, board);
    if (handle != null) {
      setState(() {
        _selectedOutlineHandle = handle == _selectedOutlineHandle
            ? null
            : handle;
        _selectedFootprintId = null;
        _selectedTrackId = null;
      });
      return;
    }

    // An extra edge cut is a thin line the user put there deliberately, so
    // it outranks the parts it may be drawn across.
    final edge = _edgeNear(scene, viewport, board);
    if (edge != null) {
      setState(() {
        _selectedEdgeId = edge.id == _selectedEdgeId ? null : edge.id;
        _selectedZoneId = null;
        _selectedFootprintId = null;
        _selectedTrackId = null;
        _selectedOutlineHandle = null;
      });
      return;
    }

    final footprint = scene.footprintAt(board);
    if (footprint != null) {
      // A tap squarely on copper is remembered, because the likeliest thing
      // anyone wants from a pad is a track out of it.
      final pad = scene.padNear(board, _padTolerance(viewport) * 0.6);
      setState(() {
        _selectedFootprintId = footprint.ref.id;
        _tappedPad = pad?.footprintId == footprint.ref.id ? pad : null;
        _selectedTrackId = null;
        _highlightedNetId = pad?.netId;
        _selectedOutlineHandle = null;
      });
      return;
    }

    final track = scene.trackNear(board, _trackTolerance(viewport));
    if (track != null) {
      setState(() {
        _selectedFootprintId = null;
        _tappedPad = null;
        _selectedOutlineHandle = null;
        _selectedEdgeId = null;
        _selectedZoneId = null;
        _selectedTrackId = track.id;
        _highlightedNetId = track.netId;
      });
      return;
    }

    // Last of all, the pour: it is the size of the board, so anything drawn
    // on top of it has first claim on a tap that lands on both.
    final zone = _zoneAt(scene, board);
    setState(() {
      _selectedFootprintId = null;
      _tappedPad = null;
      _selectedOutlineHandle = null;
      _selectedEdgeId = null;
      _selectedTrackId = null;
      _selectedZoneId = zone?.id == _selectedZoneId ? null : zone?.id;
      _highlightedNetId = zone?.netId;
    });
  }

  /// The extra edge cut near [board], within a finger's width.
  BoardEdge? _edgeNear(
    BoardScene scene,
    SchematicViewport viewport,
    Offset board,
  ) {
    final tolerance = math.max(0.5, 20 / viewport.pixelsPerMm);
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

  /// The topmost pour containing [board].
  BoardZone? _zoneAt(BoardScene scene, Offset board) {
    for (final zone in scene.zones.reversed) {
      if (zone.isValid && zone.contains(board)) return zone;
    }
    return null;
  }

  Future<void> _routeTap(
    BoardScene scene,
    SchematicViewport viewport,
    Offset board,
  ) async {
    if (!_isRouting) {
      final pad = _padToStartFrom(scene, viewport, board);
      if (pad == null) {
        _notify('Start on a pad — tap it, or drag from it');
        return;
      }
      setState(() => _startRouteAt(pad, _layerFor(pad)));
      return;
    }

    // Tapping still works as a way to drop a corner, for anyone who prefers
    // it or for a spot too tight to drag to.
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);
    final pad = scene.padNear(board, _padTolerance(viewport), layer: layer);
    if (pad != null && pad.id != _routeStartPadId) {
      if (!_canFinishOn(pad)) {
        _notify(
          '${pad.label} is on ${pad.netName ?? 'another net'} — joining it '
          'to ${_routeNetName(scene) ?? 'this net'} would short them',
        );
        return;
      }
      _extendRoute(scene, pad.position, snapToGrid: false);
      await _commitRoute(scene, endPad: pad);
      return;
    }

    _extendRoute(scene, board, snapToGrid: true);
  }

  /// The pad a route should start from, on either side of the board.
  ///
  /// Looked for on both layers. Asking only the active one meant that once
  /// the view had been switched to the back — which dropping a via does by
  /// itself — every surface-mount pad on the front simply stopped
  /// answering, with nothing to say why.
  PlacedPad? _padToStartFrom(
    BoardScene scene,
    SchematicViewport viewport,
    Offset board,
  ) {
    final active = ref.read(activeLayerProvider);
    return scene.padNear(board, _padTolerance(viewport), layer: active) ??
        scene.padNear(board, _padTolerance(viewport));
  }

  /// The layer to route from [pad] on: the active one if the pad reaches
  /// it, otherwise one that it does.
  CopperLayer _layerFor(PlacedPad pad) {
    final active = ref.read(activeLayerProvider);
    if (pad.reaches(active)) return active;
    final other = pad.layers.contains(BoardLayer.backCopper)
        ? CopperLayer.back
        : CopperLayer.front;
    // Following the pad's side here keeps the layer control honest about
    // what is being drawn.
    ref.read(activeLayerProvider.notifier).set(other);
    return other;
  }

  /// Whether a route may end on [pad].
  ///
  /// Anything but joining two different nets. Pads whose pins are not wired
  /// in the schematic yet are fair game: the connection is made there too,
  /// so the board and schematic never disagree about what is connected.
  bool _canFinishOn(PlacedPad pad) {
    final routeNet = _routeNetId;
    final padNet = pad.netId;
    return routeNet == null || padNet == null || routeNet == padNet;
  }

  /// Begins a route at [pad].
  void _startRouteAt(PlacedPad pad, CopperLayer layer) {
    _routePoints
      ..clear()
      ..add(pad.position);
    _routePreview = const [];
    _routeNetId = pad.netId;
    _routeStartPadId = pad.id;
    _routeLayer = layer;
    _routeTarget = null;
    _highlightedNetId = pad.netId;
    _selectedFootprintId = null;
    _selectedTrackId = null;
  }

  /// Recomputes the segment under the finger.
  void _updateRoutePreview(
    BoardScene scene,
    Offset finger,
    SchematicViewport viewport,
  ) {
    if (_routePoints.isEmpty) return;
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);

    // Magnetically finish on a pad of the same net. The finger covers the
    // pad it is reaching for, so without this the last few millimetres of
    // every route are guesswork.
    final target = scene.padNear(
      finger,
      _padTolerance(viewport) * 1.5,
      layer: layer,
    );
    final onTarget =
        target != null && target.id != _routeStartPadId && _canFinishOn(target);

    final to = onTarget
        ? target.position
        : TrackRouter.snap(finger, scene.board.gridMm);

    // A tick the moment the route catches a pad. The finger is over the
    // very thing it is aiming at, so the only way to know it has landed is
    // to feel it.
    final caught = onTarget ? target : null;
    if (caught != null && caught.id != _routeTarget?.id) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _routeTarget = caught;
      _routePreview = TrackRouter.route(
        from: _routePoints.last,
        to: to,
        mode: _angleMode,
        straightFirst: _straightFirst,
        obstacles: _routeObstacles(scene, target),
      );
    });
  }

  /// Turns the drawn segment into decided corners.
  Future<void> _commitPreview(BoardScene scene) async {
    final preview = _routePreview;
    final target = _routeTarget;
    if (preview.length < 2) {
      setState(() {
        _routePreview = const [];
        _routeTarget = null;
      });
      return;
    }

    setState(() {
      _routePoints.addAll(preview.skip(1));
      _routePreview = const [];
      _routeTarget = null;
    });

    // Landing on a pad finishes the whole thing; anywhere else is a
    // corner, and the next drag carries on from it.
    if (target != null) await _commitRoute(scene, endPad: target);
  }

  /// The footprints a route should not be drawn through.
  ///
  /// The parts at either end are left out: a trace leaving a pad starts on
  /// its own footprint every time, and counting that as a collision would
  /// make every route look impossible.
  List<Rect> _routeObstacles(BoardScene scene, PlacedPad? target) {
    final exempt = <String>{
      if (_routeStartPadId != null)
        ...scene.pads
            .where((p) => p.id == _routeStartPadId)
            .map((p) => p.footprintId),
      if (target != null) target.footprintId,
    };

    return [
      for (final footprint in scene.footprints)
        if (!exempt.contains(footprint.ref.id)) footprint.bounds,
    ];
  }

  void _extendRoute(
    BoardScene scene,
    Offset target, {
    required bool snapToGrid,
  }) {
    final to = snapToGrid
        ? TrackRouter.snap(target, scene.board.gridMm)
        : target;
    final corners = TrackRouter.route(
      from: _routePoints.last,
      to: to,
      mode: _angleMode,
      straightFirst: _straightFirst,
      obstacles: _routeObstacles(scene, null),
    );
    if (corners.length < 2) return;
    setState(() => _routePoints.addAll(corners.skip(1)));
  }

  void _onScaleStart(
    BoardScene scene,
    SchematicViewport viewport,
    ScaleStartDetails details,
  ) {
    _candidateFootprintId = null;
    _dragStartBoard = null;
    _dragOriginalPosition = null;
    _outlineCorner = null;
    _outlineStart = null;
    _gestureStartViewport = viewport;
    _gestureStartFocal = details.localFocalPoint;

    if (details.pointerCount > 1 || _fabPreview) return;

    // One finger: what it is working on is decided where it landed.
    final board = viewport.toSheet(_touchDown ?? details.localFocalPoint);

    if (_mode == BoardMode.route) {
      // Routing is a drag, not a series of taps. A tap that jumps the trace
      // to wherever you poked gives no chance to see where it is going;
      // dragging shows the segment forming under the finger and lets you
      // change your mind before letting go.
      if (_isRouting) {
        _isRouteDragging = true;
        return;
      }
      final pad = _padToStartFrom(scene, viewport, board);
      if (pad != null) {
        setState(() {
          _startRouteAt(pad, _layerFor(pad));
          _isRouteDragging = true;
        });
      }
      return;
    }

    if (_mode != BoardMode.place) return;

    // A footprint on top of the outline wins: the outline is a big target
    // and everything sits inside it.
    // An extra edge cut is a thin line the user put there deliberately, so
    // it outranks the parts it may be drawn across.
    final edge = _edgeNear(scene, viewport, board);
    if (edge != null) {
      setState(() {
        _selectedEdgeId = edge.id == _selectedEdgeId ? null : edge.id;
        _selectedZoneId = null;
        _selectedFootprintId = null;
        _selectedTrackId = null;
        _selectedOutlineHandle = null;
      });
      return;
    }

    final footprint = scene.footprintAt(board);
    if (footprint != null) {
      _candidateFootprintId = footprint.ref.id;
      _dragStartBoard = board;
      _dragOriginalPosition = Offset(footprint.ref.x, footprint.ref.y);
      return;
    }

    final corner = _outlineCornerNear(scene, viewport, board);
    if (corner != null) {
      _outlineCorner = corner;
      _outlineStart = scene.outline;
      _dragStartBoard = board;
      setState(() => _selectedOutlineHandle = corner);
    }
  }

  void _onScaleUpdate(BoardScene scene, ScaleUpdateDetails details) {
    final start = _gestureStartViewport;
    if (start == null) return;

    if (_isRouteDragging) {
      // A second finger means the user wants to pan or zoom, not to keep
      // drawing. Drop the half-made segment rather than committing whatever
      // it happened to be when the pinch began.
      if (details.pointerCount > 1) {
        setState(() {
          _isRouteDragging = false;
          _routePreview = const [];
          _routeTarget = null;
        });
      } else {
        _updateRoutePreview(
          scene,
          start.toSheet(details.localFocalPoint),
          start,
        );
        return;
      }
    }

    if (details.pointerCount == 1) {
      final board = start.toSheet(details.localFocalPoint);
      final origin = _dragStartBoard;

      final outlineStart = _outlineStart;
      final corner = _outlineCorner;
      if (outlineStart != null && corner != null && origin != null) {
        setState(() {
          _isDragging = true;
          _dragPosition = TrackRouter.snap(board, scene.board.gridMm);
        });
        return;
      }

      final original = _dragOriginalPosition;
      if (_candidateFootprintId != null && origin != null && original != null) {
        // Whether this is a drag or a pan is decided by movement, not by
        // what was under the finger when it landed: a small footprint is
        // smaller than the slop in a tap.
        if (!_isDragging &&
            (details.localFocalPoint - _gestureStartFocal).distance > 8) {
          setState(() {
            _isDragging = true;
            _selectedFootprintId = _candidateFootprintId;
          });
        }
        if (_isDragging) {
          setState(() {
            _dragPosition = TrackRouter.snap(
              original + (board - origin),
              scene.board.gridMm,
            );
          });
          return;
        }
        return;
      }
    }

    setState(() {
      final zoomed = start.copyWith(
        pixelsPerMm: (start.pixelsPerMm * details.scale).clamp(1.0, 200.0),
      );
      // Keep the point under the fingers fixed while zooming, then apply
      // this gesture's pan on top.
      final anchor = start.toSheet(_gestureStartFocal);
      _viewport = zoomed.copyWith(
        origin: Offset(
          details.localFocalPoint.dx - anchor.dx * zoomed.pixelsPerMm,
          details.localFocalPoint.dy - anchor.dy * zoomed.pixelsPerMm,
        ),
      );
    });
  }

  Future<void> _onScaleEnd(BoardScene scene) async {
    if (_isRouteDragging) {
      _isRouteDragging = false;
      _gestureStartViewport = null;
      await _commitPreview(scene);
      return;
    }

    final wasDragging = _isDragging;
    final position = _dragPosition;
    final id = _candidateFootprintId;
    final corner = _outlineCorner;
    final outlineStart = _outlineStart;
    final original = _dragOriginalPosition;

    // Cleared here rather than at the start of the next gesture: a quick tap
    // can win the arena outright, so `onScaleStart` may never run and a
    // stale flag would survive into it.
    _isDragging = false;
    _candidateFootprintId = null;
    _dragStartBoard = null;
    _dragOriginalPosition = null;
    _dragPosition = null;
    _outlineCorner = null;
    _outlineStart = null;
    _gestureStartViewport = null;

    if (!wasDragging || position == null) {
      if (mounted) setState(() {});
      return;
    }

    if (corner != null && outlineStart != null) {
      await _resizeOutline(scene, corner, outlineStart, position);
      return;
    }

    if (id == null || original == null) return;
    final footprint = scene.footprints.where((f) => f.ref.id == id).firstOrNull;
    if (footprint == null) return;

    // The scene handed in is the live one, so its copy of the footprint is
    // already at the dragged position. Undo has to go back to where the
    // finger started, which only the captured original still knows.
    await _reposition(
      footprint.ref.copyWith(
        x: original.dx,
        y: original.dy,
        placed: footprint.ref.placed,
      ),
      footprint.ref.copyWith(x: position.dx, y: position.dy, placed: true),
      'Move ${footprint.part.reference}',
    );
  }

  /// Which outline handle a touch has hold of, if any.
  ///
  /// Handles rather than edges: an edge is a long thin target that a finger
  /// catches while reaching for something inside the board, and a corner
  /// moves two edges at once anyway.
  int? _outlineCornerNear(
    BoardScene scene,
    SchematicViewport viewport,
    Offset board,
  ) {
    final handles = scene.outline.handles;
    final tolerance = math.max(1.0, 28 / viewport.pixelsPerMm);

    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < handles.length; i++) {
      final distance = (handles[i] - board).distance;
      if (distance <= tolerance && distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  /// The polygon edge whose midpoint marker was touched, if any.
  int? _outlineMidpointNear(
    BoardScene scene,
    SchematicViewport viewport,
    Offset board,
  ) {
    final outline = scene.outline;
    if (outline.kind != BoardOutlineKind.polygon) return null;

    final corners = outline.path;
    final tolerance = math.max(1.0, 24 / viewport.pixelsPerMm);
    for (var i = 0; i < corners.length; i++) {
      final middle = Offset.lerp(
        corners[i],
        corners[(i + 1) % corners.length],
        0.5,
      )!;
      if ((middle - board).distance <= tolerance) return i;
    }
    return null;
  }

  // --- actions ---------------------------------------------------------

  // --- actions ---------------------------------------------------------

  // --- actions ---------------------------------------------------------

  Future<void> _place(BoardScene scene, PlacedFootprintRef ref_) async {
    final spot = await _freeSpotFor(scene, ref_.libId);
    await _reposition(
      ref_,
      ref_.copyWith(x: spot.dx, y: spot.dy, placed: true),
      'Place footprint',
    );
    if (mounted) setState(() => _selectedFootprintId = ref_.id);
  }

  /// Places every footprint still waiting, as one undoable step.
  /// Turns a schematic into a board in one go.
  ///
  /// Every part already names its own footprint — it came from the symbol
  /// library, which is where `Package_QFP:LQFP-48_7x7mm_P0.5mm` on an STM32
  /// comes from — and the board was making the user re-state that part by
  /// part before anything could be placed. This assigns the ones it can
  /// resolve, places everything, and leaves only the genuinely ambiguous
  /// parts to be answered by hand.
  Future<void> _buildBoard(
    BoardScene scene,
    List<PartWithDetails> parts,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    final library = ref.read(footprintLibraryRepositoryProvider);

    final known = {
      for (final footprint in scene.footprints) footprint.part.id,
      for (final ref_ in scene.unplaced) ref_.partId,
    };

    final assigned = <PlacedFootprintRef>[];
    var unresolved = 0;

    for (final part in parts) {
      if (known.contains(part.part.id)) continue;
      // A power symbol is a label with a shape. It is not fitted to
      // anything, and KiCad keeps it off the board for the same reason.
      if (!part.part.onBoard) continue;

      final libId = part.part.footprint.trim();
      if (libId.isEmpty || !libId.contains(':')) {
        unresolved++;
        continue;
      }
      // Only if the library is actually installed. Assigning a footprint
      // that cannot be loaded produces a part on the board with no pads,
      // which is worse than saying so.
      if (await library.loadFootprint(libId) == null) {
        unresolved++;
        continue;
      }

      assigned.add(
        await repository.assignFootprint(
          projectId: widget.project.id,
          partId: part.part.id,
          libId: libId,
        ),
      );
    }

    if (!mounted) return;

    // Placement reads the scene, so it has to see the rows just written.
    final refreshed = await ref.refresh(
      boardSceneProvider(widget.project.id).future,
    );
    if (!mounted) return;

    await _placeAll(refreshed, label: 'Build board');
    if (!mounted) return;

    setState(() {
      _viewport = _canvasSize.isEmpty
          ? _viewport
          : _fitToContent(refreshed, _canvasSize);
    });

    _notify(switch ((assigned.length, unresolved)) {
      (0, 0) => 'Everything was already on the board',
      (final n, 0) => 'Placed $n ${n == 1 ? "part" : "parts"}',
      (final n, final missing) =>
        'Placed $n · $missing ${missing == 1 ? "part needs" : "parts need"} '
            'a footprint',
    });
  }

  Future<void> _placeAll(BoardScene scene, {String? label}) async {
    final repository = ref.read(boardRepositoryProvider);
    final waiting = List<PlacedFootprintRef>.from(scene.unplaced);
    if (waiting.isEmpty) return;

    // Each part has to see the ones placed before it, or they would all
    // find the same free spot in the middle.
    final occupied = [for (final f in scene.footprints) f.bounds];
    final placed = <PlacedFootprintRef>[];
    for (final ref_ in waiting) {
      final local = await _localBoundsOf(ref_.libId);
      final spot =
          PlacementFinder.findSpot(
            outline: scene.outline,
            footprint: local,
            occupied: occupied,
            gridMm: scene.board.gridMm,
          ) ??
          PlacementFinder.besideBoard(
            outline: scene.outline,
            footprint: local,
            occupied: occupied,
          );
      final after = ref_.copyWith(x: spot.dx, y: spot.dy, placed: true);
      await repository.updatePlacement(after);
      occupied.add(local.shift(spot));
      placed.add(after);
    }

    _record(
      label ?? 'Place ${placed.length} footprints',
      undo: () async {
        for (final before in waiting) {
          await repository.updatePlacement(before);
        }
      },
      redo: () async {
        for (final after in placed) {
          await repository.updatePlacement(after);
        }
      },
    );
  }

  /// Somewhere free on the board for a footprint, or beside the board if
  /// there is no room left on it.
  Future<Offset> _freeSpotFor(BoardScene scene, String libId) async {
    final local = await _localBoundsOf(libId);
    final occupied = [for (final f in scene.footprints) f.bounds];
    return PlacementFinder.findSpot(
          outline: scene.outline,
          footprint: local,
          occupied: occupied,
          gridMm: scene.board.gridMm,
        ) ??
        PlacementFinder.besideBoard(
          outline: scene.outline,
          footprint: local,
          occupied: occupied,
        );
  }

  /// A footprint's extent around its own origin.
  Future<Rect> _localBoundsOf(String libId) async {
    final definition = await ref
        .read(footprintLibraryRepositoryProvider)
        .loadFootprint(libId);
    if (definition == null) {
      return Rect.fromCenter(center: Offset.zero, width: 2, height: 2);
    }
    final bounds = footprintBounds(definition);
    return bounds == Rect.zero
        ? Rect.fromCenter(center: Offset.zero, width: 2, height: 2)
        : bounds;
  }

  Future<void> _resizeOutline(
    BoardScene scene,
    int corner,
    BoardOutline before,
    Offset to,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    // The scene handed in already shows the preview, so the board to undo
    // back to is rebuilt from the outline captured when the drag began.
    final original = scene.board.withOutline(before);
    final after = original.withOutline(
      before.withHandleAt(
        corner,
        to,
        minimum: math.max(scene.board.gridMm * 2, 0.2),
      ),
    );

    await repository.updateBoard(after);
    _record(
      'Reshape board',
      undo: () => repository.updateBoard(original),
      redo: () => repository.updateBoard(after),
    );
  }

  /// Adds or removes a polygon corner.
  Future<void> _changeOutlinePoints(
    BoardScene scene,
    BoardOutline after,
    String label,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    final original = scene.board;
    final updated = original.withOutline(after);

    await repository.updateBoard(updated);
    if (mounted) setState(() => _selectedOutlineHandle = null);
    _record(
      label,
      undo: () => repository.updateBoard(original),
      redo: () => repository.updateBoard(updated),
    );
  }

  Future<void> _reposition(
    PlacedFootprintRef before,
    PlacedFootprintRef after,
    String label,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.updatePlacement(after);
    _record(
      label,
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  Future<void> _assignFootprint(
    BoardScene scene,
    PartWithDetails part,
    FootprintIndexEntry entry,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    final before = await repository.footprintForPart(part.part.id);

    final assigned = await repository.assignFootprint(
      projectId: widget.project.id,
      partId: part.part.id,
      libId: entry.libId,
    );

    // Choosing a footprint for a part that is not on the board yet can only
    // mean "put it on the board". Asking for a second tap to place it — and
    // then dropping it on top of whatever was placed last — made every part
    // three steps and a drag.
    PlacedFootprintRef? placed;
    if (!assigned.placed) {
      final spot = await _freeSpotFor(scene, entry.libId);
      placed = assigned.copyWith(x: spot.dx, y: spot.dy, placed: true);
      await repository.updatePlacement(placed);
    }
    if (!mounted) return;
    setState(() {
      _assigningPartId = null;
      if (placed != null) _selectedFootprintId = placed.id;
    });

    _record(
      'Footprint for ${part.part.reference}',
      undo: () async {
        if (before == null) {
          await repository.removeFootprint(part.part.id);
        } else {
          await repository.assignFootprint(
            projectId: widget.project.id,
            partId: part.part.id,
            libId: before.libId,
          );
          await repository.updatePlacement(before);
        }
      },
      redo: () async {
        // Undoing a first assignment deletes the row, so doing it again
        // creates a new one with a new id. Placing by the old id would move
        // nothing at all.
        final again = await repository.assignFootprint(
          projectId: widget.project.id,
          partId: part.part.id,
          libId: entry.libId,
        );
        if (placed != null) {
          await repository.updatePlacement(
            again.copyWith(x: placed.x, y: placed.y, placed: true),
          );
        }
      },
    );
  }

  /// Writes the drawn route as track segments.
  ///
  /// When the route joins pads the schematic has not connected, the
  /// connection is made there as well, and the whole thing — copper and
  /// schematic both — is one step to undo.
  Future<void> _commitRoute(BoardScene scene, {PlacedPad? endPad}) async {
    final points = List<Offset>.from(_routePoints);
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);
    var netId = _routeNetId;
    final startPad = scene.pads
        .where((p) => p.id == _routeStartPadId)
        .firstOrNull;
    setState(_cancelRoute);

    if (points.length < 2) return;

    final nets = ref.read(netRepositoryProvider);
    ConnectionSnapshot? before;
    (String, String)? joined;

    final needsJoin =
        startPad != null &&
        endPad != null &&
        (startPad.netId == null ||
            endPad.netId == null ||
            startPad.netId != endPad.netId);
    if (needsJoin) {
      final a = _pinIdFor(startPad);
      final b = _pinIdFor(endPad);
      if (a != null && b != null) {
        before = await nets.capture(widget.project.id, [a, b]);
        final net = await nets.connectPins(a, b);
        netId = net.id;
        joined = (a, b);
      }
    }

    final repository = ref.read(boardRepositoryProvider);
    final ids = <String>[];
    for (var i = 0; i < points.length - 1; i++) {
      ids.add(
        await repository.addTrack(
          projectId: widget.project.id,
          layer: layer,
          startX: points[i].dx,
          startY: points[i].dy,
          endX: points[i + 1].dx,
          endY: points[i + 1].dy,
          width: scene.trackWidthFor(netId, layer),
          netId: netId,
        ),
      );
    }

    HapticFeedback.lightImpact();

    // The whole route is one action: undoing it should not leave three of
    // the five segments behind, or the schematic connection it made.
    final tracks = (await repository.getTracks(
      widget.project.id,
    )).where((t) => ids.contains(t.id)).toList();

    if (joined != null && startPad != null && endPad != null) {
      _notify(
        'Connected ${startPad.label} to ${endPad.label} in the schematic',
      );
    }

    final snapshot = before;
    final pins = joined;
    _record(
      'Route ${_netName(scene, netId) ?? 'track'}',
      undo: () async {
        await repository.deleteTracks(ids);
        if (snapshot != null) await nets.restore(snapshot);
      },
      redo: () async {
        if (pins == null) {
          await repository.restoreCopper(tracks: tracks, vias: const []);
          return;
        }
        // Connecting again makes a net with a new id; the copper has to go
        // back onto that one, not onto the id the undo threw away.
        final net = await nets.connectPins(pins.$1, pins.$2);
        await repository.restoreCopper(
          tracks: [for (final track in tracks) track.withNet(net.id)],
          vias: const [],
        );
      },
    );
  }

  /// The schematic pin a pad belongs to: the part's pin with the same
  /// number, which is how KiCad matches the two.
  String? _pinIdFor(PlacedPad pad) {
    final parts = ref.read(projectPartsProvider(widget.project.id)).value;
    final part = parts?.where((p) => p.part.id == pad.partId).firstOrNull;
    return part?.pins.where((p) => p.number == pad.pad.number).firstOrNull?.id;
  }

  /// Puts a via at the end of the route and carries on from the other side.
  Future<void> _dropVia(BoardScene scene) async {
    if (_routePoints.length < 2) {
      _notify('Draw some track before changing layer');
      return;
    }
    final at = _routePoints.last;
    final netId = _routeNetId;
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);

    await _commitRoute(scene);

    final repository = ref.read(boardRepositoryProvider);
    final id = await repository.addVia(
      projectId: widget.project.id,
      x: at.dx,
      y: at.dy,
      diameter: scene.board.rules.viaDiameter,
      drill: scene.board.rules.viaDrill,
      netId: netId,
    );
    final vias = (await repository.getVias(
      widget.project.id,
    )).where((v) => v.id == id).toList();

    _record(
      'Via',
      undo: () => repository.deleteVias([id]),
      redo: () => repository.restoreCopper(tracks: const [], vias: vias),
    );

    if (!mounted) return;
    // Carry on from the via, on the other side of the board.
    setState(() {
      _routePoints
        ..clear()
        ..add(at);
      _routeNetId = netId;
      _routeStartPadId = null;
      _routeLayer = scene.board.nextLayer(layer);
    });
    ref.read(activeLayerProvider.notifier).set(scene.board.nextLayer(layer));
  }

  void _cancelRoute() {
    _routePoints.clear();
    _routePreview = const [];
    _isRouteDragging = false;
    _routeTarget = null;
    _routeNetId = null;
    _routeStartPadId = null;
    _routeLayer = null;
    // The net was highlighted to show what was being drawn. Leaving it lit
    // afterwards paints the finished track in the highlight colour, which
    // hides the one thing a track's colour is for — which layer it is on.
    _highlightedNetId = null;
  }

  Future<void> _deleteTrack(Track track) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteTracks([track.id]);
    if (!mounted) return;
    setState(() => _selectedTrackId = null);
    _record(
      'Rip up track',
      undo: () => repository.restoreCopper(tracks: [track], vias: const []),
      redo: () => repository.deleteTracks([track.id]),
    );
  }

  Future<void> _ripUpNet(BoardScene scene, String netId) async {
    final repository = ref.read(boardRepositoryProvider);
    final tracks = scene.tracks.where((t) => t.netId == netId).toList();
    final vias = scene.vias.where((v) => v.netId == netId).toList();

    await repository.ripUpNet(widget.project.id, netId);
    if (!mounted) return;
    setState(() => _selectedTrackId = null);

    _record(
      'Rip up ${_netName(scene, netId) ?? 'net'}',
      undo: () => repository.restoreCopper(tracks: tracks, vias: vias),
      redo: () => repository.ripUpNet(widget.project.id, netId),
    );
  }

  Future<void> _editSettings(BoardScene scene) async {
    final result = await showDesignRulesDialog(context, board: scene.board);
    if (result == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.copyWith(rules: result.rules, gridMm: result.gridMm);
    await repository.updateBoard(after);
    _record(
      'Board settings',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  // --- plumbing --------------------------------------------------------

  String? _netName(BoardScene scene, String? netId) {
    if (netId == null) return null;
    for (final pad in scene.pads) {
      if (pad.netId == netId) return pad.netName;
    }
    return null;
  }

  String? _routeNetName(BoardScene scene) => _netName(scene, _routeNetId);

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

  Future<void> _undo() => ref.read(editHistoryProvider.notifier).undo();

  Future<void> _redo() => ref.read(editHistoryProvider.notifier).redo();

  /// Says something without interrupting.
  ///
  /// These used to be snackbars, and on a canvas that answers every tap
  /// they popped up constantly — "cancelled", "tap a pad", "copied" —
  /// stacking over the very controls being used. The message now takes the
  /// action bar's title for a few seconds instead: where the eye already
  /// is, covering nothing, and replaced rather than queued by the next one.
  void _notify(String message) {
    if (!mounted) return;
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  SchematicViewport _fitToContent(BoardScene scene, Size size) {
    final bounds = scene.contentBounds;
    if (bounds.width <= 0 || bounds.height <= 0 || size.isEmpty) {
      return const SchematicViewport(pixelsPerMm: 6, origin: Offset(20, 40));
    }
    const topInset = 48.0;
    final scale = math.min(
      size.width / bounds.width,
      (size.height - topInset) / bounds.height,
    );
    final clamped = scale.clamp(1.0, 60.0);
    return SchematicViewport(
      pixelsPerMm: clamped,
      origin: Offset(
        (size.width - bounds.width * clamped) / 2 - bounds.left * clamped,
        topInset +
            (size.height - topInset - bounds.height * clamped) / 2 -
            bounds.top * clamped,
      ),
    );
  }
}

/// The strip along the top: what the board still owes, and what to do next.
class _BoardStatusBar extends StatelessWidget {
  const _BoardStatusBar({
    required this.scene,
    required this.mode,
    required this.layer,
    required this.parts,
    required this.onAssign,
    required this.onPlace,
    required this.onPlaceAll,
    required this.onBuild,
  });

  final BoardScene scene;
  final BoardMode mode;
  final CopperLayer layer;
  final List<PartWithDetails> parts;
  final void Function(String partId) onAssign;
  final void Function(PlacedFootprintRef ref) onPlace;
  final VoidCallback onPlaceAll;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parts the board has never heard of. Until these have a footprint
    // there is nothing to place, so they are the first thing to say.
    final placedPartIds = {
      for (final footprint in scene.footprints) footprint.part.id,
      for (final ref in scene.unplaced) ref.partId,
    };
    final unassigned = [
      for (final part in parts)
        // A power symbol is a label with a shape — `#PWR`, kept off the
        // board by KiCad for the same reason. Offering to give one a
        // footprint is asking for work that cannot be done.
        if (part.part.onBoard && !placedPartIds.contains(part.part.id)) part,
    ];

    return Material(
      color: KicadPalette.surface.withValues(alpha: 0.93),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 10),
              _chip(theme, mode.icon, mode.label, KicadPalette.textSecondary),
              _chip(
                theme,
                Icons.layers_outlined,
                layer.label,
                BoardPainter.colorFor(layer),
              ),
              // An empty board is not a finished one. Saying "Routed" before
              // anything has been placed claims work that has not happened.
              if (scene.pads.isEmpty)
                _chip(
                  theme,
                  Icons.inbox_outlined,
                  'Nothing placed',
                  KicadPalette.textSecondary,
                )
              else
                _chip(
                  theme,
                  scene.isFullyRouted ? Icons.check_circle : Icons.timeline,
                  scene.isFullyRouted
                      ? 'Routed'
                      : '${scene.ratsnest.length} to route',
                  scene.isFullyRouted
                      ? KicadPalette.success
                      : KicadPalette.warning,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // The whole board in one tap, for a schematic whose
                    // parts already name their own footprints — which is
                    // most of them, since the symbol library says so.
                    if (unassigned.isNotEmpty || scene.unplaced.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_fix_high, size: 14),
                          label: const Text('BUILD BOARD'),
                          onPressed: onBuild,
                        ),
                      ),
                    // Placing twenty parts one tap at a time is the kind of
                    // chore a phone should do for you.
                    if (scene.unplaced.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.auto_awesome_mosaic_outlined,
                            size: 14,
                          ),
                          label: Text('Place all ${scene.unplaced.length}'),
                          onPressed: onPlaceAll,
                        ),
                      ),
                    for (final part in unassigned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.dashboard_customize_outlined,
                            size: 14,
                          ),
                          label: Text(part.part.reference),
                          onPressed: () => onAssign(part.part.id),
                        ),
                      ),
                    for (final ref in scene.unplaced)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 14,
                          ),
                          label: Text(
                            parts
                                    .where((p) => p.part.id == ref.partId)
                                    .firstOrNull
                                    ?.part
                                    .reference ??
                                'Place',
                          ),
                          onPressed: () => onPlace(ref),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, Color color) =>
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      );
}
