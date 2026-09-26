import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cross_probe.dart';
import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/ids.dart';
import '../../data/repositories/circuit_paster.dart';
import '../../data/repositories/part_repository.dart' show PartSnapshot;
import '../../core/widgets/panel.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../fab/silk_fonts.dart';
import '../../rendering/schematic_viewport.dart';
import '../project/cross_probe_view.dart';
import 'board_painter.dart';
import 'layer_picker.dart';
import 'board_sync_dialog.dart';
import 'preset_value_sheet.dart';
import 'impedance_dialog.dart';
import 'meander_dialog.dart';
import 'net_lengths_dialog.dart';
import 'stackup_dialog.dart';
import 'board_shape_editor.dart';
import 'crosshair.dart';
import '../project/swap_dialog.dart';
import 'board_feature_dialog.dart';
import 'design_rules_dialog.dart';
import 'drc_sheet.dart';
import 'footprint_sidebar.dart';
import 'object_properties.dart';
import 'net_classes_dialog.dart';
import '../pictures/picture_library.dart';
import 'silk_picture.dart';
import 'silkscreen_dialogs.dart';
import 'track_sizes_dialog.dart';
import 'zone_editor.dart';

/// What the PLACE button is currently placing.
/// How a track being drawn treats other nets' copper.
enum RouteMode {
  /// Goes round it at the clearance, the way KiCad's walk-around does.
  walkaround('Walk around', Icons.alt_route),

  /// Goes straight where it is aimed, and shows in red where it comes too
  /// close — for when the way round is not the way wanted.
  highlight('Highlight', Icons.highlight_alt);

  const RouteMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// What the Route tool lays down.
///
/// One track, a bundle of them, or a track folded into loops on the way.
/// All three are the same act — aim, place a corner, place another — so
/// all three live behind one chip rather than scattered along the strip.
enum RouteStyle {
  track('Track', Icons.timeline, 'One track, corner by corner'),
  bus(
    'Bus',
    Icons.view_week_outlined,
    'Sweep a box round the pads the bundle leaves from',
  ),
  meander(
    'Meander',
    Icons.waves,
    'The run folds into loops as you draw it, to add length',
  ),
  pair(
    'Pair',
    Icons.drag_handle,
    'Two nets named +/- or _P/_N, drawn together at a fixed gap',
  );

  const RouteStyle(this.label, this.icon, this.hint);

  final String label;
  final IconData icon;
  final String hint;
}

/// What the Pour tool lays out.
///
/// Both are a polygon on one copper layer; one says "fill this with GND"
/// and the other says "put nothing here". KiCad calls the second a rule
/// area and stores it as the same object with the fill turned off, which
/// is exactly what makes it belong behind the same chip.
enum PourStyle {
  copper(
    'Pour',
    Icons.format_color_fill_outlined,
    'Place the corners of a copper pour',
  ),
  keepout(
    'Keepout',
    Icons.block_outlined,
    'Place the corners of an area nothing may go in',
  );

  const PourStyle(this.label, this.icon, this.hint);

  final String label;
  final IconData icon;
  final String hint;
}

/// What the Edge cut tool draws.
///
/// The board's own outline is drawn with the same tool: on a board with no
/// outline yet, the first closed shape becomes it. After that a closed
/// shape is a cutout, and lines and arcs are slots and notches.
enum EdgeStyle {
  lines(
    'Lines',
    Icons.polyline_outlined,
    'Place corner by corner; back to the start closes the shape',
    null,
  ),
  rectangle(
    'Rectangle',
    Icons.crop_square,
    'Place one corner, then the opposite one',
    2,
  ),
  circle(
    'Circle',
    Icons.circle_outlined,
    'Place the centre, then a point on the rim',
    2,
  ),
  triangle('Triangle', Icons.change_history, 'Place the three corners', 3),
  arc(
    'Arc',
    Icons.architecture,
    'Place the centre, then where the arc starts, then where it ends',
    3,
  );

  const EdgeStyle(this.label, this.icon, this.hint, this.points);

  final String label;
  final IconData icon;
  final String hint;

  /// How many points make the shape, after which it is finished without
  /// being asked. Null for a chain of lines, which goes on until Finish.
  final int? points;

  /// Whether the shape encloses an area — a board, or a hole in one.
  bool get closed => this != lines && this != arc;
}

/// What the Text tool puts on the silkscreen.
enum SilkStyle {
  text('Text', Icons.text_fields, 'Aim where the text goes'),
  picture(
    'Picture',
    Icons.image_outlined,
    'Aim where the picture goes, then pick it from your pictures',
  );

  const SilkStyle(this.label, this.icon, this.hint);

  final String label;
  final IconData icon;
  final String hint;
}

/// What the Via tool puts down.
///
/// A via is what you want nine times out of ten; a hole, a fiducial and a
/// test point are the tenth, and they all go down the same way.
enum ViaStyle {
  via('Via', Icons.adjust, 'Aim where the via goes'),
  mountingHole(
    'Mounting hole',
    Icons.radio_button_checked,
    'Aim where the screw goes',
  ),
  fiducial(
    'Fiducial',
    Icons.center_focus_strong_outlined,
    'Aim where the camera target goes',
  ),
  testPoint('Test point', Icons.control_point, 'Aim where the probe lands');

  const ViaStyle(this.label, this.icon, this.hint);

  final String label;
  final IconData icon;
  final String hint;

  BoardFeatureKind? get feature => switch (this) {
    ViaStyle.via => null,
    ViaStyle.mountingHole => BoardFeatureKind.mountingHole,
    ViaStyle.fiducial => BoardFeatureKind.fiducial,
    ViaStyle.testPoint => BoardFeatureKind.testPoint,
  };
}

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
  measure('Measure', Icons.straighten, 'Aim at the first point'),
  text('Text', Icons.text_fields, 'Aim where the text goes'),
  bus(
    'Bus',
    Icons.view_week_outlined,
    'Sweep a box round the pads the bus leaves from',
  ),
  feature(
    'Holes',
    Icons.radio_button_checked,
    'Aim where the hole, fiducial or test point goes',
  );

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
  const PrecisionBoardPanel({
    super.key,
    required this.project,
    this.onShowSchematic,
  });

  final Project project;

  /// Goes to the schematic, from the cross-probing live view.
  final VoidCallback? onShowSchematic;

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

  /// Copper turns in 45° steps, always — the way it is routed in KiCad, and
  /// one less choice on a strip with little room. How far corners are
  /// rounded stays the router's call.
  static const _angleLock = TrackAngleLock.deg45;
  double _curveRadius = 0;

  /// The two corners of the area being swept, and what fell inside it.
  Offset? _regionFrom;
  Rect? _region;
  _Selection _selected = const _Selection.empty();

  /// Copies of a laid-out circuit still to be put down, each placed with
  /// the crosshair in turn, and the original they are copied from.
  List<ReplicaChannel> _replicas = const [];
  _ReplicaSource? _replicaSource;

  /// Where the carried thing was picked up, so everything moves by the
  /// same delta rather than jumping its anchor to the crosshair.
  Offset? _carryAnchor;
  String? _carryingEdgeId;
  String? _slidingTrackId;
  bool _carryingOutline = false;

  /// The outline corner, or a circle's edge, riding on the crosshair.
  int? _carryingOutlineHandle;

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

  /// The free text, and the part whose designator, the user has hold of.
  String? _selectedTextId;
  String? _selectedLabelId;

  /// Silkscreen riding on the crosshair: a text, or a part's designator.
  String? _carryingTextId;

  /// The silkscreen picture picked, and the one riding on the crosshair.
  String? _selectedImageId;
  String? _carryingImageId;
  SilkStyle _silkStyle = SilkStyle.text;
  String? _carryingLabelId;

  // Whatever is being drawn, corner by corner.
  final List<Offset> _points = [];
  String? _routeNetId;
  CopperLayer? _routeLayer;

  /// The part being carried on the crosshair, if any. Moving a part is the
  /// same act as drawing a corner: aim, then place.
  String? _carryingId;

  Offset? _measureFrom;

  RouteMode _routeMode = RouteMode.walkaround;

  /// Which of the three routing tools, and which of the four via-ish
  /// things, the two chips on the strip are currently set to.
  RouteStyle _routeStyle = RouteStyle.track;
  ViaStyle _viaStyle = ViaStyle.via;
  PourStyle _pourStyle = PourStyle.copper;
  EdgeStyle _edgeStyle = EdgeStyle.rectangle;

  /// An arc goes the short way round from its start to its end unless this
  /// is set, when it goes the long way.
  bool _arcLong = false;

  /// The arc about [centre] from [start] towards [end], as the start, a
  /// point on it and the end — the three points an arc is stored as. The
  /// end is brought onto the circle [start] sets, and the arc turns the
  /// short way unless [_arcLong] says otherwise.
  List<Offset> arcThrough(Offset centre, Offset start, Offset end) {
    final radius = (start - centre).distance;
    final a0 = math.atan2(start.dy - centre.dy, start.dx - centre.dx);
    final a1 = math.atan2(end.dy - centre.dy, end.dx - centre.dx);
    var sweep = a1 - a0;
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }
    while (sweep <= -math.pi) {
      sweep += 2 * math.pi;
    }
    if (_arcLong) sweep -= sweep.sign * 2 * math.pi;
    Offset on(double angle) =>
        centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    return [start, on(a0 + sweep / 2), on(a0 + sweep)];
  }

  /// The loops a meander draws, while that is what the Route tool is set
  /// to. Kept between runs: the shape you want is a property of the board,
  /// not of one track.
  MeanderShape _meander = const MeanderShape();

  /// The pair being drawn, the pad its partner leaves from, which way
  /// round the two are, and the shape of the pair.
  DiffPair? _pair;
  Offset? _pairFrom;
  double _pairSide = 1;
  DiffPairStyle _pairStyle = DiffPairStyle.mirrored;
  double? _pairGap;

  /// How many points each placed corner put into [_points], so Back takes
  /// a whole leg off. A meandered leg is a hundred points, and nobody is
  /// tapping Back a hundred times.
  final List<int> _legLengths = [];

  /// A bus: the first corner of the box round its start, then the
  /// connections the box caught. The path is drawn into [_points].
  Offset? _busFrom;
  List<BusLane> _busLanes = const [];

  /// The committed board, for working out routes against.
  BoardScene? _routeScene;

  /// The last way round worked out, since the crosshair sits still far
  /// more often than it moves.
  (Offset, Offset, BoardScene, double, List<Offset>)? _walked;

  /// Where copper may go, for the board and route in hand. Kept between
  /// frames; thrown away the moment any of those change.
  WalkaroundField? _walkField;

  /// The last run folded into loops, for the same reason.
  (Offset, MeanderShape, List<Offset>)? _folded;

  /// Which parts are standing on each other, worked out against the board
  /// as it would be if the part on the crosshair were put down here.
  (BoardScene, Offset, String?, List<Courtyard>)? _collided;

  /// What the Holes tool puts down: an M3 mounting hole until changed.
  BoardFeatureSpec _featureSpec = const BoardFeatureSpec();
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
        _routeScene = committed;
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
                      selectedTextId: _carryingTextId ?? _selectedTextId,
                      selectedImageId: _carryingImageId ?? _selectedImageId,
                      selectedLabelId: _carryingLabelId ?? _selectedLabelId,
                      highlightedNetId: _highlightedNetId,
                      pendingRoute: _routeStyle == RouteStyle.pair
                          ? const <Offset>[]
                          : _pendingPath(snap.at),
                      pendingBus: [
                        for (final (_, points)
                            in _busPlan(committed, snap.at)?.tracks ??
                                const <(BusLane, List<Offset>)>[])
                          points,
                        ..._pairPreview(scene, snap.at),
                      ],
                      pendingWidth:
                          _tool == AimTool.route &&
                              _routeStyle != RouteStyle.pair
                          ? _widthFor(scene)
                          : null,
                      pendingClearance: _tool == AimTool.route
                          ? scene.clearanceFor(_routeNetId)
                          : null,
                      routeClashes: _clashes(scene, snap.at),
                      collisions: _collisions(committed, scene, snap.at),
                      pendingLayer: _routeLayer,
                      showRatsnest: _showRatsnest,
                      showOutlineGrips:
                          _outlineSelected || _carryingOutlineHandle != null,
                      draggingOutline:
                          _carryingOutline || _carryingOutlineHandle != null,
                      selectedOutlineHandle: _carryingOutlineHandle,
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
            // The middle of the board — or of the working area, before an
            // outline is drawn — so there is always somewhere to aim from.
            if (!_fabPreview)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CentreMarkPainter(
                      viewport.toScreen(scene.outline.bounds.center),
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
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _topStrip(scene, parts),
            ),
            // A new board has no edge until one is drawn. Said on the board
            // rather than on the strip, which has no room to spare, and only
            // until the Edge cut tool is in hand.
            if (!scene.outline.isDrawn && !_fabPreview && _tool != AimTool.edge)
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: Center(
                  child: ActionChip(
                    key: const ValueKey('draw-outline-chip'),
                    avatar: Icon(
                      Icons.crop_square,
                      size: 16,
                      color: KicadPalette.warning,
                    ),
                    label: const Text('No board outline yet — draw one'),
                    backgroundColor: KicadPalette.surface.withValues(
                      alpha: 0.94,
                    ),
                    side: BorderSide(color: KicadPalette.warning),
                    onPressed: () => _pickEdgeStyle(
                      _edgeStyle.closed ? _edgeStyle : EdgeStyle.rectangle,
                    ),
                  ),
                ),
              ),
            // No parts yet: the board is still here to shape, with a word
            // on where parts come from.
            if (parts.isEmpty && !_fabPreview)
              Positioned(
                top: scene.outline.isDrawn || _tool == AimTool.edge ? 52 : 100,
                left: 0,
                right: 0,
                child: Center(
                  child: ActionChip(
                    key: const ValueKey('no-parts-chip'),
                    avatar: const Icon(Icons.memory_outlined, size: 16),
                    label: const Text(
                      'No parts yet — add them on the schematic',
                    ),
                    backgroundColor: KicadPalette.surface.withValues(
                      alpha: 0.94,
                    ),
                    onPressed: widget.onShowSchematic,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _bottomBar(scene, committed, parts, snap),
            ),
            if (ref.watch(crossProbeOnProvider) && !_fabPreview)
              Positioned(
                top: 52,
                right: 10,
                child: MiniSchematicView(
                  project: widget.project,
                  focus: _probeFocus(scene),
                  onOpen: widget.onShowSchematic,
                ),
              ),
          ],
        );
      },
    );
  }

  /// What the schematic live view follows: the part picked up or selected,
  /// or the net of the copper selected.
  ProbeFocus _probeFocus(BoardScene scene) {
    final footprintId = _carryingId ?? _selectedFootprintId;
    final footprint = scene.footprints
        .where((f) => f.ref.id == footprintId)
        .firstOrNull;
    final netId =
        scene.tracks
            .where((t) => t.id == _selectedTrackId)
            .firstOrNull
            ?.netId ??
        scene.vias.where((v) => v.id == _selectedViaId).firstOrNull?.netId ??
        _routeNetId ??
        _highlightedNetId;
    return ProbeFocus(partId: footprint?.part.id, netId: netId);
  }

  /// The board with whatever is being carried following the crosshair.
  BoardScene _withCarried(BoardScene committed, Offset at) {
    final delta = _carryAnchor == null ? Offset.zero : at - _carryAnchor!;

    if (_carryingTextId != null ||
        _carryingLabelId != null ||
        _carryingImageId != null) {
      return _withSilkMoved(committed, at);
    }

    final handle = _carryingOutlineHandle;
    if (handle != null) {
      return _withBoard(
        committed,
        committed.board.withOutline(_resizedOutline(committed, handle, at)),
      );
    }

    // An edge cut, the board outline, or a whole swept area all move the
    // same way: everything shifts by the same delta, so the shape being
    // carried keeps its proportions instead of collapsing onto the sight.
    // A segment being slid is not translated wholesale: its neighbours
    // absorb the movement, so the whole run has to be recomputed.
    final slidingId = _slidingTrackId;
    if (slidingId != null) {
      final track = committed.tracks
          .where((t) => t.id == slidingId)
          .firstOrNull;
      if (track == null) return committed;
      final slide = slideTrack(
        track: track,
        others: committed.tracks,
        delta: delta,
        anchors: [for (final pad in committed.pads) pad.position],
        lock: _angleLock,
      );
      return _withTracks(committed, slide);
    }

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
      previewOf: committed,
      texts: committed.texts,
      images: committed.images,
      netClasses: committed.netClasses,
      features: [
        for (final feature in committed.features)
          if (feature.ref.id == id)
            feature.copyWith(x: at.dx, y: at.dy, placed: true)
          else
            feature,
      ],
      dimensions: committed.dimensions,
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

  bool get _carryingSelection =>
      _carryAnchor != null && _slidingTrackId == null && !_selected.isEmpty;

  /// The scene with a slide applied, for showing it before it is written.
  BoardScene _withTracks(BoardScene committed, TrackSlide slide) {
    final changed = {for (final track in slide.moved) track.id: track};

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

    final sample = slide.moved.firstOrNull;
    return BoardScene.build(
      previewOf: committed,
      texts: committed.texts,
      images: committed.images,
      netClasses: committed.netClasses,
      features: committed.features,
      dimensions: committed.dimensions,
      board: committed.board,
      parts: parts,
      nets: nets,
      placements: placements,
      definitions: definitions,
      tracks: [
        for (final track in committed.tracks)
          if (!slide.removed.contains(track.id)) changed[track.id] ?? track,
        // The copper that reconnects it, shown exactly as it will be laid.
        if (sample != null)
          for (var i = 0; i < slide.added.length; i++)
            Track(
              id: 'slide-join-$i',
              projectId: widget.project.id,
              layer: sample.layer,
              startX: slide.added[i].from.dx,
              startY: slide.added[i].from.dy,
              endX: slide.added[i].to.dx,
              endY: slide.added[i].to.dy,
              width: sample.width,
              netId: sample.netId,
            ),
      ],
      vias: committed.vias,
      edges: committed.edges,
      zones: committed.zones,
    );
  }

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
      previewOf: committed,
      texts: committed.texts,
      images: committed.images,
      netClasses: committed.netClasses,
      features: committed.features,
      dimensions: committed.dimensions,
      board: _carryingOutline
          ? committed.board.withOutline(_shiftOutline(committed.outline, delta))
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
            edge.copyWith(points: [for (final p in edge.points) p + delta])
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
        BoardOutlineKind.none => outline,
      };

  /// Where the crosshair is pointing, after snapping.
  SnapTarget _snapAt(BoardScene scene, SchematicViewport viewport, Size size) {
    final centre = viewport.toSheet(Offset(size.width / 2, size.height / 2));
    final carriedId = _carryingId;
    if (carriedId != null) {
      final footprint = scene.footprints
          .where((f) => f.ref.id == carriedId)
          .firstOrNull;
      // By the part's middle, not its origin: what lines up with the middle
      // of the board is the middle of the chip.
      final definition = footprint?.definition;
      final middle = definition == null
          ? Offset.zero
          : footprintBounds(definition).center;
      final reference = footprint == null
          ? Offset.zero
          : FootprintPlacement(
              x: 0,
              y: 0,
              rotation: footprint.ref.rotation,
              flipped: footprint.ref.flipped,
            ).apply(middle.dx, middle.dy);
      final guided = boardGuideSnap(
        at: centre,
        board: scene.outline.bounds,
        toleranceMm: snapToleranceMm(viewport),
        reference: reference,
        gridMm: _snap ? _grid : 0,
      );
      if (guided != null) return guided;
    }

    return resolveSnap(
      at: centre,
      scene: scene,
      gridMm: _grid,
      snapToGrid: _snap,
      toleranceMm: snapToleranceMm(viewport),
      // Only copper on the layer being routed is worth catching on.
      layer: _tool == AimTool.route ? ref.read(activeLayerProvider) : null,
      // Nor, while carrying something, on anything: the drop is worked out
      // against the board as it was, so the thing being moved would catch
      // its own old position and the drag would measure from there.
      snapToObjects: _tool != AimTool.region && !_isCarrying,
      // Closing a shape on the point it started from.
      extraPoints: [
        if (_points.isNotEmpty && _tool != AimTool.route)
          (_points.first, 'start'),
      ],
    );
  }

  /// What is being drawn, with the crosshair as its next corner.
  ///
  /// Constrained exactly as the placed point will be, so the line on screen
  /// is the line that lands.
  List<Offset> _pendingPath(Offset at) {
    // A bus shows its lanes, not the one path they follow.
    if (_points.isEmpty || _tool == AimTool.bus) return const [];
    if (_tool == AimTool.edge) return _edgePreview([..._points, at]);
    if (_tool != AimTool.route) return [..._points, at];
    return [..._points, ..._legsTo(at)];
  }

  /// The edge shape [points] make so far, drawn as the shape rather than as
  /// the points: a rectangle from its two corners, a circle round its
  /// centre.
  List<Offset> _edgePreview(List<Offset> points) {
    final shape = _edgeShape(points);
    if (shape == null) return points;
    final (kind, at) = shape;
    if (kind == BoardEdgeKind.line || kind == BoardEdgeKind.polygon) {
      return kind == BoardEdgeKind.polygon ? [...at, at.first] : at;
    }
    final path = BoardEdge(id: '', projectId: '', kind: kind, points: at).path;
    return [
      for (final metric in path.computeMetrics())
        for (var d = 0.0; d <= metric.length; d += metric.length / 64)
          metric.getTangentForOffset(d)!.position,
    ];
  }

  /// What the points placed with the current [EdgeStyle] make, as an edge
  /// of some kind: null while there are not enough of them.
  (BoardEdgeKind, List<Offset>)? _edgeShape(List<Offset> points) {
    switch (_edgeStyle) {
      case EdgeStyle.lines:
        if (points.length < 2) return null;
        final closed =
            points.length >= 4 &&
            (points.last - points.first).distance <= math.max(_grid, 0.2);
        return closed
            ? (BoardEdgeKind.polygon, points.sublist(0, points.length - 1))
            : (BoardEdgeKind.line, points);
      case EdgeStyle.rectangle:
        if (points.length < 2) return null;
        final r = Rect.fromPoints(points[0], points[1]);
        return (
          BoardEdgeKind.polygon,
          [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft],
        );
      case EdgeStyle.circle:
        if (points.length < 2) return null;
        return (BoardEdgeKind.circle, [points[0], points[1]]);
      case EdgeStyle.triangle:
        if (points.length < 3) return null;
        return (BoardEdgeKind.polygon, points.sublist(0, 3));
      case EdgeStyle.arc:
        if (points.length < 3) return null;
        return (BoardEdgeKind.arc, arcThrough(points[0], points[1], points[2]));
    }
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

  Widget _topStrip(BoardScene scene, List<PartWithDetails> parts) {
    final layer = ref.watch(activeLayerProvider);
    final waiting = _waiting(scene, parts).length;

    return Material(
      color: KicadPalette.surface.withValues(alpha: 0.94),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 4),
              // Only while there is something to do about it. Getting
              // parts onto the board is the first thing anyone does here,
              // so it earns a place on the strip — but once they are all
              // down it is just a button taking up room, and changing a
              // footprint later is a More sort of job. It comes back on
              // its own the moment the schematic gains a part.
              if (waiting > 0)
                _StripChip(
                  label: '$waiting to place',
                  icon: Icons.inbox_outlined,
                  colour: KicadPalette.warning,
                  onTap: () => _showParts(scene, parts),
                ),
              // The schematic has moved on since the board last caught up:
              // a new part, a changed footprint, copper on a deleted net.
              if (ref
                      .watch(boardSyncPlanProvider(widget.project.id))
                      .value
                      ?.hasWork ??
                  false)
                _StripChip(
                  key: const ValueKey('board-sync-chip'),
                  label: 'Update from schematic',
                  icon: Icons.sync,
                  colour: KicadPalette.highlight,
                  onTap: _syncFromSchematic,
                ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final tool in _stripTools)
                      if (tool == AimTool.route)
                        _ToolChip(
                          key: const ValueKey('tool-route'),
                          icon: _routeStyle.icon,
                          label: _routeStyle.label,
                          selected: _routing,
                          hasMenu: true,
                          onPressed: _routing
                              ? _chooseRouteStyle
                              : () => _pickRouteStyle(_routeStyle),
                        )
                      else if (tool == AimTool.zone)
                        _ToolChip(
                          key: const ValueKey('tool-zone'),
                          icon: _pourStyle.icon,
                          label: _pourStyle.label,
                          selected: _tool == AimTool.zone,
                          hasMenu: true,
                          onPressed: _tool == AimTool.zone
                              ? _choosePourStyle
                              : () => _pickPourStyle(_pourStyle),
                        )
                      else if (tool == AimTool.text)
                        _ToolChip(
                          key: const ValueKey('tool-silk'),
                          icon: _silkStyle.icon,
                          label: _silkStyle.label,
                          selected: _tool == AimTool.text,
                          hasMenu: true,
                          onPressed: _tool == AimTool.text
                              ? _chooseSilkStyle
                              : () => _pickSilkStyle(_silkStyle),
                        )
                      else if (tool == AimTool.edge)
                        _ToolChip(
                          key: const ValueKey('tool-edge'),
                          icon: _edgeStyle.icon,
                          label: _edgeStyle.label,
                          selected: _tool == AimTool.edge,
                          hasMenu: true,
                          onPressed: _tool == AimTool.edge
                              ? _chooseEdgeStyle
                              : () => _pickEdgeStyle(_edgeStyle),
                        )
                      else if (tool == AimTool.via)
                        _ToolChip(
                          key: const ValueKey('tool-via'),
                          icon: _viaStyle.icon,
                          label: _viaStyle.label,
                          selected: _viaing,
                          hasMenu: true,
                          onPressed: _viaing
                              ? _chooseViaStyle
                              : () => _pickViaStyle(_viaStyle),
                        )
                      else
                        _ToolChip(
                          icon: tool.icon,
                          label: tool.label,
                          selected: tool == _tool,
                          onPressed: () => _pickTool(tool),
                        ),
                    const SizedBox(width: 6),
                    _StripChip(
                      label: layer.label,
                      icon: Icons.layers_outlined,
                      colour: BoardPainter.colorFor(layer),
                      onTap: () => _chooseLayer(scene),
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
                onPressed: () => _showMore(scene, parts),
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
    BoardScene committed,
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
            // A new set of buttons starts from the left. Scrolled along to
            // reach one selection's last button, the row stayed scrolled
            // when that selection went, and Undo sat off the edge.
            key: ValueKey(
              '${_selectedPickId ?? ''}|${_tool.name}|${_points.isEmpty}|'
              '$_isCarrying|${_region != null}',
            ),
            scrollDirection: Axis.horizontal,
            child: Row(children: _contextButtons(scene, parts)),
          ),
        ),
        const SizedBox(width: 8),
        AimBar(
          key: const ValueKey('aim-bar'),
          snap: snap,
          placeLabel: _canPlace
              ? _placeLabel
              : _sightAction(committed)?.label ?? '',
          // The committed scene, never the preview. The preview already has
          // the carried thing moved; handing it to DROP applied the move a
          // second time, so a slid track's neighbours were written from
          // geometry that did not exist and snapped back to where they were.
          onPlace: _canPlace
              ? () => _place(committed, snap)
              : _sightAction(committed)?.onPressed,
        ),
      ],
    );
  }

  String get _placeLabel {
    if (_isCarrying) return 'DROP';
    return switch (_tool) {
      AimTool.select => 'PLACE',
      AimTool.route => _points.isEmpty ? 'START' : 'CORNER',
      AimTool.zone => _points.isEmpty ? 'START' : 'CORNER',
      AimTool.edge => switch (_edgeStyle) {
        EdgeStyle.lines ||
        EdgeStyle.triangle => _points.isEmpty ? 'START' : 'CORNER',
        EdgeStyle.rectangle => _points.isEmpty ? 'CORNER' : 'OPPOSITE',
        EdgeStyle.circle => _points.isEmpty ? 'CENTRE' : 'RIM',
        EdgeStyle.arc => const ['CENTRE', 'START', 'END'][_points.length % 3],
      },
      AimTool.via => 'VIA',
      AimTool.measure => _measureFrom == null ? 'FROM' : 'TO',
      AimTool.region => _regionFrom == null ? 'CORNER' : 'FINISH',
      AimTool.text => 'TEXT',
      AimTool.bus =>
        _busLanes.isEmpty ? (_busFrom == null ? 'BOX' : 'CATCH') : 'CORNER',
      AimTool.feature => switch (_featureSpec.kind) {
        BoardFeatureKind.mountingHole => 'HOLE',
        BoardFeatureKind.fiducial => 'FIDUCIAL',
        BoardFeatureKind.testPoint => 'TEST PT',
      },
    };
  }

  bool get _canPlace => _isCarrying || _tool.places;

  /// Whether anything at all is riding on the crosshair.
  bool get _isCarrying =>
      _carryingId != null ||
      _carryingEdgeId != null ||
      _slidingTrackId != null ||
      _carryingTextId != null ||
      _carryingLabelId != null ||
      _carryingImageId != null ||
      _carryingOutlineHandle != null ||
      _carryingOutline ||
      _carryingSelection;

  /// The buttons that matter right now, and no others.
  List<Widget> _contextButtons(BoardScene scene, List<PartWithDetails> parts) {
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

    if (_carryingEdgeId != null ||
        _slidingTrackId != null ||
        _carryingTextId != null ||
        _carryingLabelId != null ||
        _carryingImageId != null ||
        _carryingOutlineHandle != null ||
        _carryingOutline ||
        _carryingSelection) {
      return [
        _Chip(
          icon: Icons.close,
          label: 'Cancel',
          onPressed: () => setState(_stopCarrying),
        ),
      ];
    }

    // An area has been swept: what is in it can be moved or deleted as one.
    if (_region != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move ${_selected.count}',
          onPressed: _selected.isEmpty ? null : () => _carryRegion(),
        ),
        if (_selected.footprintIds.isNotEmpty)
          _Chip(
            key: const ValueKey('copy-parts'),
            icon: Icons.content_copy_outlined,
            label: 'Copy',
            onPressed: () => _copyAsNewParts(scene),
          ),
        if (_selected.footprintIds.isNotEmpty)
          _Chip(
            key: const ValueKey('replicate'),
            icon: Icons.copy_all_outlined,
            label: 'Replicate',
            onPressed: () => _replicate(scene),
          ),
        if (_selected.trackIds.isNotEmpty || _selected.viaIds.isNotEmpty)
          _Chip(
            key: const ValueKey('selection-net'),
            icon: Icons.polyline_outlined,
            label:
                'Net · '
                '${_selected.trackIds.length + _selected.viaIds.length}',
            onPressed: () => _setSelectionNet(scene),
          ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete ${_selected.count}',
          danger: true,
          onPressed: _selected.isEmpty ? null : () => _deleteSelection(scene),
        ),
        _Chip(
          icon: Icons.close,
          label: 'Clear',
          onPressed: () => setState(_clearSelection),
        ),
        ?_hintText(),
      ];
    }

    // Mid-drawing: finishing and unfinishing is all that matters.
    if (_points.isNotEmpty) {
      return [
        _Chip(icon: Icons.undo, label: 'Back', onPressed: _undoPoint),
        if (_tool == AimTool.edge &&
            _edgeStyle == EdgeStyle.arc &&
            _points.length == 2)
          _Chip(
            key: const ValueKey('arc-other-way'),
            icon: Icons.swap_horiz,
            label: 'Other way',
            onPressed: () => setState(() => _arcLong = !_arcLong),
          ),
        if (_tool == AimTool.route && _routeStyle == RouteStyle.meander)
          _meanderChip(scene)
        else if (_tool == AimTool.route && _routeStyle == RouteStyle.pair)
          _pairChip(scene)
        else if (_tool == AimTool.route)
          _routeModeChip(),
        if (_tool == AimTool.route)
          _Chip(
            icon: Icons.swap_vert,
            label: 'Via + flip',
            onPressed: () => _viaAndSwitch(scene),
          ),
        // A shape with a set number of points finishes on its last one.
        if (_tool != AimTool.edge || _edgeStyle.points == null)
          _Chip(
            icon: Icons.check,
            label: switch (_tool) {
              AimTool.zone => 'Close pour',
              AimTool.edge => 'Finish cut',
              AimTool.bus => 'Lay ${_busLanes.length}',
              _ => 'Finish',
            },
            onPressed: () => _finish(scene),
          ),
        _Chip(
          icon: Icons.close,
          label: 'Cancel',
          onPressed: () => setState(_clearDrawing),
        ),
        if (_tool == AimTool.route)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              switch (_routeStyle) {
                RouteStyle.meander => '+${_mm(_meanderAdded(_lastSnap))} mm',
                RouteStyle.pair =>
                  '${_pair?.label ?? 'Pair'} · '
                      '${_mm(_gapFor(scene))} mm',
                _ => _impedanceLabel(
                  scene,
                  _routeLayer ?? ref.read(activeLayerProvider),
                  _widthFor(scene),
                ),
              },
              key: const ValueKey('route-impedance-readout'),
              style: TextStyle(fontSize: 12, color: KicadPalette.textSecondary),
            ),
          ),
      ];
    }

    final selectedText = scene.texts
        .where((t) => t.id == _selectedTextId)
        .firstOrNull;
    if (selectedText != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: () => setState(() {
            _carryingTextId = selectedText.id;
            _carryAnchor = null;
          }),
        ),
        _Chip(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onPressed: () => _editText(selectedText),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: () => _deleteText(selectedText),
        ),
      ];
    }

    final selectedImage = scene.images
        .where((i) => i.id == _selectedImageId)
        .firstOrNull;
    if (selectedImage != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: () => setState(() {
            _carryingImageId = selectedImage.id;
            _carryAnchor = null;
          }),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Edit',
          onPressed: () => _editPicture(selectedImage),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: () => _deletePicture(selectedImage),
        ),
      ];
    }

    final labelled = scene.footprints
        .where((f) => f.ref.id == _selectedLabelId)
        .firstOrNull;
    if (labelled != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: () => setState(() {
            _carryingLabelId = labelled.ref.id;
            _carryAnchor = null;
          }),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Edit',
          onPressed: () => _editDesignator(labelled),
        ),
        _Chip(
          icon: labelled.ref.labelHidden
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          label: labelled.ref.labelHidden ? 'Show' : 'Hide',
          onPressed: () => _toggleLabel(labelled),
        ),
      ];
    }

    final footprint = scene.footprints
        .where((f) => f.ref.id == _selectedFootprintId)
        .firstOrNull;
    final feature = footprint == null
        ? null
        : scene.featureOf(footprint.ref.id);
    if (footprint != null && feature != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: footprint.ref.locked ? null : () => _carry(footprint),
        ),
        _lockChip(
          key: 'feature-lock',
          locked: footprint.ref.locked,
          onPressed: () => _lockPart(footprint, !footprint.ref.locked),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Edit',
          onPressed: () => _editFeature(feature),
        ),
        if (feature.kind != BoardFeatureKind.mountingHole)
          _Chip(
            icon: Icons.flip,
            label: footprint.ref.flipped ? 'Front' : 'Back',
            onPressed: () => _flip(footprint),
          ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: () => _deleteFeature(feature),
        ),
      ];
    }
    if (footprint != null) {
      return [
        _Chip(
          icon: Icons.open_with,
          label: 'Move',
          onPressed: footprint.ref.locked ? null : () => _carry(footprint),
        ),
        _lockChip(
          key: 'part-lock',
          locked: footprint.ref.locked,
          onPressed: () => _lockPart(footprint, !footprint.ref.locked),
        ),
        _Chip(
          icon: Icons.text_fields,
          label: 'Label',
          onPressed: () => _editDesignator(footprint),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _footprintProperties(scene, footprint),
        ),
        _Chip(
          icon: Icons.flip,
          label: footprint.ref.flipped ? 'Front' : 'Back',
          onPressed: () => _flip(footprint),
        ),
        _Chip(
          icon: Icons.swap_horiz,
          label: 'Footprint',
          onPressed: () => setState(() => _assigningPartId = footprint.part.id),
        ),
        _Chip(
          key: const ValueKey('footprint-swap'),
          icon: Icons.compare_arrows,
          label: 'Swap',
          onPressed: () => runPartSwap(
            context,
            ref,
            projectId: widget.project.id,
            partId: footprint.part.id,
            record: _record,
            notify: _notify,
          ),
        ),
      ];
    }

    final track = scene.tracks
        .where((t) => t.id == _selectedTrackId)
        .firstOrNull;
    if (track != null) {
      final length = track.netId == null
          ? null
          : NetLength.of(scene, track.netId!);
      return [
        _Chip(
          icon: Icons.swap_horiz,
          label: 'Slide',
          onPressed: track.locked ? null : () => _slide(track),
        ),
        _Chip(
          icon: Icons.waves,
          label: 'Tune',
          onPressed: track.locked ? null : () => _tune(scene, track),
        ),
        _lockChip(
          key: 'track-lock',
          locked: track.locked,
          onPressed: () => _lockTrack(track, !track.locked),
        ),
        if (track.netId != null)
          _Chip(
            key: const ValueKey('net-lock'),
            icon: Icons.lock_outline,
            label: _netLocked(scene, track.netId!) ? 'Free net' : 'Lock net',
            onPressed: () => _lockNet(scene, track.netId!),
          ),
        _Chip(
          icon: Icons.tune,
          label: 'Properties',
          onPressed: () => _trackProperties(scene, track),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: track.locked ? null : () => _deleteTrack(track),
        ),
        _Chip(
          icon: Icons.layers_clear_outlined,
          label: 'Rip net',
          danger: true,
          onPressed: track.netId == null ? null : () => _ripUpNet(track.netId!),
        ),
        if (length != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${_netName(scene, track.netId) ?? 'Net'} '
              '${_mm(length.length)} mm · ${length.delayPs.toStringAsFixed(0)} ps'
              ' · ${_impedanceLabel(scene, track.layer, track.width)}',
              key: const ValueKey('track-length-readout'),
              style: TextStyle(fontSize: 12, color: KicadPalette.textSecondary),
            ),
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
        _lockChip(
          key: 'via-lock',
          locked: via.locked,
          onPressed: () => _lockVia(via, !via.locked),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
          onPressed: via.locked ? null : () => _deleteVia(via),
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
          icon: Icons.open_in_full,
          label: 'Resize',
          onPressed: () => _grabOutlineHandle(scene),
        ),
        _Chip(
          icon: Icons.tune,
          label: 'Dimensions',
          onPressed: () => _chooseShape(scene),
        ),
        _Chip(
          key: const ValueKey('delete-outline'),
          icon: Icons.delete_outline,
          label: 'Delete outline',
          danger: true,
          onPressed: () => _deleteOutline(scene),
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
        _lockChip(
          key: 'zone-lock',
          locked: zone.locked,
          onPressed: () => _lockZone(zone, !zone.locked),
        ),
        _Chip(
          icon: Icons.delete_outline,
          label: zone.keepout ? 'Delete keepout' : 'Delete pour',
          danger: true,
          onPressed: zone.locked ? null : () => _deleteZone(zone),
        ),
      ];
    }

    return [
      if (_tool == AimTool.route && _routeStyle == RouteStyle.meander)
        _meanderChip(scene)
      else if (_tool == AimTool.route && _routeStyle == RouteStyle.pair)
        _pairChip(scene)
      else if (_tool == AimTool.route)
        _routeModeChip(),
      if (_tool == AimTool.bus && (_busFrom != null || _busLanes.isNotEmpty))
        _Chip(
          icon: Icons.close,
          label: 'Start over',
          onPressed: () => setState(_clearDrawing),
        ),
      if (_tool == AimTool.feature)
        _Chip(
          key: const ValueKey('feature-choose'),
          icon: Icons.radio_button_checked,
          label: _featureSpec.shortLabel,
          onPressed: _chooseFeature,
        ),
      if (_tool == AimTool.measure && _measureTo != null)
        _Chip(
          key: const ValueKey('measure-keep'),
          icon: Icons.straighten,
          label: 'Keep',
          onPressed: _keepMeasurement,
        ),
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
      // Deletes whatever the sight is over, without selecting it first.
      _Chip(
        icon: Icons.backspace_outlined,
        label: 'Delete',
        danger: true,
        onPressed: _underCrosshair(scene) == null
            ? null
            : () => _deleteUnderCrosshair(scene),
      ),
      ?_hintText(),
    ];
  }

  Widget? _hintText() => _hint == null
      ? null
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _hint!,
            style: TextStyle(color: KicadPalette.highlight, fontSize: 12),
          ),
        );

  /// The chips the strip shows, in order.
  ///
  /// Bus and the board features are not here: a bus is a way of routing and
  /// a mounting hole is a kind of via, and both are reached from the chip
  /// they belong to. Ten chips on a phone strip meant scrolling to find the
  /// one you wanted; eight fit.
  static const _stripTools = [
    AimTool.select,
    AimTool.region,
    AimTool.route,
    AimTool.zone,
    AimTool.edge,
    AimTool.via,
    AimTool.measure,
    AimTool.text,
  ];

  bool get _routing => _tool == AimTool.route || _tool == AimTool.bus;
  bool get _viaing => _tool == AimTool.via || _tool == AimTool.feature;

  void _pickRouteStyle(RouteStyle style) {
    _pickTool(style == RouteStyle.bus ? AimTool.bus : AimTool.route);
    setState(() => _routeStyle = style);
    _notify(style.hint);
  }

  void _pickViaStyle(ViaStyle style) {
    final kind = style.feature;
    setState(() {
      _viaStyle = style;
      if (kind != null && kind != _featureSpec.kind) {
        _featureSpec = BoardFeatureSpec(
          kind: kind,
          size: BoardFeature.defaultSize(kind),
        );
      }
    });
    _pickTool(kind == null ? AimTool.via : AimTool.feature, ask: false);
    _notify(style.hint);
  }

  Future<void> _chooseRouteStyle() async {
    final chosen = await _pickFrom(
      RouteStyle.values,
      selected: _routeStyle,
      icon: (s) => s.icon,
      label: (s) => s.label,
      hint: (s) => s.hint,
    );
    if (chosen == null || !mounted) return;
    _pickRouteStyle(chosen);
  }

  void _pickPourStyle(PourStyle style) {
    _pickTool(AimTool.zone);
    setState(() => _pourStyle = style);
    _notify(style.hint);
  }

  Future<void> _choosePourStyle() async {
    final chosen = await _pickFrom(
      PourStyle.values,
      selected: _pourStyle,
      icon: (s) => s.icon,
      label: (s) => s.label,
      hint: (s) => s.hint,
    );
    if (chosen == null || !mounted) return;
    _pickPourStyle(chosen);
  }

  void _pickEdgeStyle(EdgeStyle style) {
    _pickTool(AimTool.edge);
    setState(() => _edgeStyle = style);
    _notify(style.hint);
  }

  Future<void> _chooseEdgeStyle() async {
    final chosen = await _pickFrom(
      EdgeStyle.values,
      selected: _edgeStyle,
      icon: (s) => s.icon,
      label: (s) => s.label,
      hint: (s) => s.hint,
    );
    if (chosen == null || !mounted) return;
    _pickEdgeStyle(chosen);
  }

  Future<void> _chooseViaStyle() async {
    final chosen = await _pickFrom(
      ViaStyle.values,
      selected: _viaStyle,
      icon: (s) => s.icon,
      label: (s) => s.label,
      hint: (s) => s.hint,
    );
    if (chosen == null || !mounted) return;
    _pickViaStyle(chosen);
  }

  /// A sheet of one line per choice, which is what every one of these
  /// little menus is.
  Future<T?> _pickFrom<T>(
    List<T> options, {
    required T selected,
    required IconData Function(T) icon,
    required String Function(T) label,
    required String Function(T) hint,
  }) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: KicadPalette.surface,
    // As tall as its choices, rather than capped at half a landscape
    // screen with the last of them out of sight.
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          for (final option in options)
            ListTile(
              key: ValueKey('pick-${label(option)}'),
              dense: true,
              leading: Icon(
                icon(option),
                size: 20,
                color: option == selected
                    ? KicadPalette.highlight
                    : KicadPalette.textSecondary,
              ),
              title: Text(label(option)),
              subtitle: Text(
                hint(option),
                style: TextStyle(color: KicadPalette.textSecondary),
              ),
              trailing: option == selected
                  ? Icon(Icons.check, color: KicadPalette.highlight)
                  : null,
              onTap: () => Navigator.of(sheet).pop(option),
            ),
        ],
      ),
    ),
  );

  /// Switches tool. [ask] is what makes the Holes tool put up its "which
  /// one" sheet — off when the menu the tool was picked from has already
  /// said which one, since the chip beside it changes it afterwards.
  void _pickTool(AimTool tool, {bool ask = true}) {
    setState(() {
      _clearDrawing();
      _measureFrom = null;
      _measureTo = null;
      _carryingId = null;
      _tool = tool;
      if (tool != AimTool.select) _clearSelection();
    });
    if (ask && tool == AimTool.feature) _chooseFeature();
  }

  /// What the Holes tool will place next.
  Future<void> _chooseFeature() async {
    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    final spec = await showBoardFeatureDialog(
      context,
      nets: nets,
      initial: _featureSpec,
    );
    if (spec == null || !mounted) return;
    setState(() => _featureSpec = spec);
    _notify('Aim, then press ${_placeLabel.toLowerCase()} for each one');
  }

  Future<void> _addFeature(Offset at) async {
    final spec = _featureSpec;
    final repository = ref.read(boardRepositoryProvider);
    final added = await repository.addFeature(
      projectId: widget.project.id,
      kind: spec.kind,
      x: at.dx,
      y: at.dy,
      size: spec.size,
      plated: spec.plated,
      netId: spec.netId,
      netName: spec.netName,
      back:
          spec.kind != BoardFeatureKind.mountingHole &&
          ref.read(activeLayerProvider) == CopperLayer.back,
    );
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    _record(
      'Add ${added.reference}',
      undo: () => repository.deleteFeature(added.id),
      redo: () => repository.restoreFeature(added),
    );
    _notify('${added.reference} placed');
  }

  Future<void> _editFeature(BoardFeature feature) async {
    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    final spec = await showBoardFeatureDialog(
      context,
      nets: nets,
      initial: BoardFeatureSpec.of(feature),
      fixedKind: true,
    );
    if (spec == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    final after = spec.applyTo(feature);
    await repository.updateFeature(after);
    _record(
      'Edit ${feature.reference}',
      undo: () => repository.updateFeature(feature),
      redo: () => repository.updateFeature(after),
    );
  }

  Future<void> _deleteFeature(BoardFeature feature) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteFeature(feature.id);
    if (mounted) setState(() => _selectedFootprintId = null);
    _record(
      'Delete ${feature.reference}',
      undo: () => repository.restoreFeature(feature),
      redo: () => repository.deleteFeature(feature.id),
    );
  }

  /// A measurement, kept on the board as a dimension line.
  Future<void> _keepMeasurement() async {
    final from = _measureFrom;
    final to = _measureTo;
    if (from == null || to == null || (to - from).distance < 1e-6) return;
    final repository = ref.read(boardRepositoryProvider);
    final added = await repository.addDimension(
      projectId: widget.project.id,
      start: from,
      end: to,
    );
    if (!mounted) return;
    setState(() {
      _measureFrom = null;
      _measureTo = null;
    });
    _record(
      'Add a dimension',
      undo: () => repository.deleteDimension(added.id),
      redo: () => repository.restoreDimension(added),
    );
  }

  Future<void> _deleteDimension(BoardDimension dimension) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteDimension(dimension.id);
    _record(
      'Delete a dimension',
      undo: () => repository.restoreDimension(dimension),
      redo: () => repository.deleteDimension(dimension.id),
    );
  }

  void _placeBus(BoardScene scene, Offset at) {
    HapticFeedback.selectionClick();
    if (_busLanes.isEmpty) {
      final from = _busFrom;
      if (from == null) {
        setState(() => _busFrom = at);
        _notify('Now the opposite corner of the box');
        return;
      }
      final lanes = BusRouter.lanesStartingIn(scene, Rect.fromPoints(from, at));
      setState(() {
        _busFrom = null;
        _busLanes = lanes;
      });
      _notify(
        lanes.isEmpty
            ? 'No unrouted connections start in that box'
            : '${lanes.length} connections — now draw the path they follow',
      );
      return;
    }
    setState(() {
      _points.addAll(
        _points.isEmpty ? [at] : legalCorners(_points.last, at, _angleLock),
      );
    });
  }

  /// What the bus comes to with the path drawn so far and the crosshair.
  BusPlan? _busPlan(BoardScene scene, Offset at) {
    if (_tool != AimTool.bus || _busLanes.isEmpty || _points.isEmpty) {
      return null;
    }
    final spine = [..._points, ...legalCorners(_points.last, at, _angleLock)];
    return BusRouter.plan(
      lanes: _busLanes,
      spine: spine,
      pitch: _busPitch(scene),
    );
  }

  /// Centre to centre: the widest lane's track and the widest clearance.
  double _busPitch(BoardScene scene) {
    final layer = ref.read(activeLayerProvider);
    var width = 0.0;
    var gap = 0.0;
    for (final lane in _busLanes) {
      width = math.max(width, scene.trackWidthFor(lane.netId, layer));
      gap = math.max(gap, scene.clearanceFor(lane.netId));
    }
    return width + gap;
  }

  Future<void> _finishBus(BoardScene scene) async {
    final plan = _points.length < 2
        ? null
        : BusRouter.plan(
            lanes: _busLanes,
            spine: List<Offset>.from(_points),
            pitch: _busPitch(scene),
          );
    setState(_clearDrawing);
    if (plan == null || plan.tracks.isEmpty) return;

    final layer = ref.read(activeLayerProvider);
    final repository = ref.read(boardRepositoryProvider);
    final written = <String>[];
    for (final (lane, points) in plan.tracks) {
      final width = scene.trackWidthFor(lane.netId, layer);
      for (var i = 0; i < points.length - 1; i++) {
        if ((points[i + 1] - points[i]).distance < 1e-9) continue;
        written.add(
          await repository.addTrack(
            projectId: widget.project.id,
            layer: layer,
            startX: points[i].dx,
            startY: points[i].dy,
            endX: points[i + 1].dx,
            endY: points[i + 1].dy,
            width: width,
            netId: lane.netId,
          ),
        );
      }
    }
    if (written.isEmpty || !mounted) return;
    final laid = [
      for (final track in await repository.getTracks(widget.project.id))
        if (written.contains(track.id)) track,
    ];
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Bus of ${plan.tracks.length}',
      undo: () => repository.deleteTracks(written),
      redo: () => repository.restoreCopper(tracks: laid, vias: const []),
    );
    _notify(
      plan.warnings.isEmpty
          ? '${plan.tracks.length} tracks laid'
          : plan.warnings.first,
    );
  }

  /// The dimension whose line or measured span is nearest [at].
  BoardDimension? _nearestDimension(
    BoardScene scene,
    Offset at,
    double tolerance,
  ) {
    BoardDimension? best;
    var bestDistance = tolerance;
    for (final d in scene.dimensions) {
      final (a, b) = d.line;
      final distance = math.min(
        _segmentDistance(at, a, b),
        _segmentDistance(at, d.start, d.end),
      );
      if (distance <= bestDistance) {
        best = d;
        bestDistance = distance;
      }
    }
    return best;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 < 1e-12) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }

  // --- placing ---------------------------------------------------------

  /// The one action. Everything precise goes through here, at the point the
  /// crosshair is showing, which is never under the user's hand.
  Future<void> _place(BoardScene scene, SnapTarget snap) async {
    final at = snap.at;

    if (_isCarrying) {
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

      case AimTool.text:
        switch (_silkStyle) {
          case SilkStyle.text:
            await _addText(at);
          case SilkStyle.picture:
            final picture = await showPictureLibrary(context);
            if (picture != null && mounted) await _placePicture(at, picture);
        }
        return;

      case AimTool.feature:
        await _addFeature(at);
        return;

      case AimTool.bus:
        _placeBus(scene, at);
        return;

      case AimTool.via:
        await _dropVia(scene, at);
        return;

      case AimTool.route:
        _placeRouteCorner(scene, at, snap);
        return;

      case AimTool.zone:
        unawaited(HapticFeedback.selectionClick());
        setState(() => _points.add(at));
        return;

      case AimTool.edge:
        unawaited(HapticFeedback.selectionClick());
        setState(() => _points.add(at));
        if (_points.length == _edgeStyle.points) await _finishEdge(scene);
        return;

      case AimTool.region:
        unawaited(HapticFeedback.selectionClick());
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
      // A track may begin on a pad, on an existing run, or on a via — the
      // last two being how a third part gets joined to copper that is
      // already there without going back to a pad to start from.
      final pad = scene.padNear(at, 0.01);
      if (pad == null && !snap.isCopper) {
        _notify('Start on a pad, a track or a via');
        return;
      }
      HapticFeedback.selectionClick();
      // A net in a class routes at the class width, the way KiCad picks the
      // width up from the net under the cursor.
      final netClass = scene.classOf(pad?.netId ?? snap.netId);
      final CopperLayer layer = pad != null
          ? _layerFor(pad)
          : (snap.layer ?? ref.read(activeLayerProvider));
      final classWidth = netClass?.widthOn(scene.board.stackup, layer);
      if (netClass != null) {
        _notify(
          netClass.impedance == null
              ? netClass.label
              : '${netClass.label} · ${_mm(classWidth!)} mm on '
                    '${layer.shortLabel}',
        );
      }
      // A pair needs both halves before anything is drawn: the net under
      // the crosshair, its partner by name, and the partner's nearest pad.
      DiffPair? pair;
      Offset? partner;
      if (_routeStyle == RouteStyle.pair) {
        pair = DiffPairs.of(scene, pad?.netId ?? snap.netId);
        if (pair == null) {
          _notify('No partner: a pair is named +/-, _P/_N or _p/_n');
          return;
        }
        final otherId = pair.partnerOf(pad?.netId ?? snap.netId ?? '');
        final otherPad = otherId == null
            ? null
            : DiffPairs.padNear(
                scene,
                otherId,
                pad?.position ?? at,
                layer: layer,
              );
        if (otherPad == null) {
          _notify('${pair.label}: the other half has no pad on this layer');
          return;
        }
        partner = otherPad.position;
      }

      setState(() {
        _clearSelection();
        if (classWidth != null) _trackWidth = classWidth;
        _routeNetId = pad?.netId ?? snap.netId;
        _routeLayer = layer;
        _pair = pair;
        _pairFrom = partner;
        _points.add(pad?.position ?? at);
        _legLengths
          ..clear()
          ..add(1);
      });
      if (pair != null) _notify('${pair.label} at ${_mm(_gapFor(scene))} mm');
      return;
    }

    // Landing on a pad of the same net ends the track there.
    final pad = scene.padNear(at, 0.01);
    if (pad != null && (pad.position - _points.first).distance > 1e-6) {
      if (_routeNetId != null &&
          pad.netId != null &&
          pad.netId != _routeNetId) {
        _notify('${pad.label} is on a different net');
        return;
      }
      // Through the same angle machinery as every other corner. Going
      // straight to the pad is what produced a bare diagonal from one pad
      // to the other, at whatever angle the two happened to sit at.
      setState(() {
        final legs = _legsTo(pad.position);
        _points.addAll(legs);
        _legLengths.add(legs.length);
      });
      unawaited(_finish(scene));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      final legs = _legsTo(at);
      final wasStraight = _points.length < 2;
      _points.addAll(legs);
      _legLengths.add(legs.length);
      // Which side each half of a pair runs on is decided once, by where
      // the partner's own pad already is, and then kept for the whole run.
      if (wasStraight && _pair != null && _pairFrom != null) {
        _pairSide = DiffPairs.sideOf(_points, _pairFrom!);
      }
    });
  }

  /// The corners that reach [at] from the end of the route on legal angles.
  ///
  /// Not "the target moved onto a legal bearing": that cannot reach a pad
  /// which is not already on one, which is most of them. KiCad's answer is
  /// two segments — a straight run and a 45 — and so is this.
  ///
  /// The point is deliberately not re-snapped to the grid afterwards. A pad
  /// sits at 30.9125 mm, never on a 0.5 mm grid, and rounding the corner
  /// after computing it is exactly what turned a clean 45 into 23°.
  List<Offset> _legalTo(Offset at) {
    if (_points.isEmpty) return [at];
    final from = _points.last;
    final scene = _routeScene;
    // A meander is a shape folded into a straight run; folding it round
    // another net's pads as well would be neither.
    if (_tool != AimTool.route ||
        _routeMode != RouteMode.walkaround ||
        _routeStyle == RouteStyle.meander ||
        // A pair is two tracks offset from the line drawn; walking that
        // line round an obstacle puts one half inside whatever the other
        // half went round.
        _routeStyle == RouteStyle.pair ||
        scene == null) {
      return legalCorners(from, at, _angleLock);
    }
    final width = _widthFor(scene);
    final cached = _walked;
    if (cached != null &&
        cached.$1 == from &&
        cached.$2 == at &&
        identical(cached.$3, scene) &&
        cached.$4 == width) {
      return cached.$5;
    }
    // The map of where copper may go is kept between frames: it depends on
    // the board, the layer, the net and the width, and none of those move
    // while a finger does. Building it per frame is what made this crawl.
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);
    final field = _walkField;
    final map = field != null && field.matches(scene, layer, width, _routeNetId)
        ? field
        : (_walkField = WalkaroundField.of(
            scene,
            layer: layer,
            width: width,
            netId: _routeNetId,
          ));

    // No way round inside the board: straight, with the clash shown.
    final walked =
        WalkaroundRouter.routeOn(map, from: from, to: at) ??
        legalCorners(from, at, _angleLock);
    _walked = (from, at, scene, width, walked);
    return walked;
  }

  /// The same corners, folded into loops when the Route tool is set to
  /// Meander — so what is drawn on the way to the next corner is exactly
  /// what lands when it is placed.
  List<Offset> _legsTo(Offset at) {
    final legs = _legalTo(at);
    if (_routeStyle != RouteStyle.meander || _points.isEmpty) return legs;
    // Asked for three times a frame — once to draw the route, once to check
    // it for clashes and once for the readout — and a meandered leg is
    // several hundred points of trigonometry.
    final cached = _folded;
    if (cached != null && cached.$1 == at && cached.$2 == _meander) {
      return cached.$3;
    }
    final out = <Offset>[];
    var from = _points.last;
    for (final leg in legs) {
      out.addAll(
        MeanderEngine.alongRun(
          from,
          leg,
          MeanderEngine.serpentine((leg - from).distance, _meander),
        ).skip(1),
      );
      from = leg;
    }
    _folded = (at, _meander, out);
    return out;
  }

  /// How much longer the loops make the run the crosshair is on.
  double _meanderAdded(Offset at) {
    if (_routeStyle != RouteStyle.meander || _points.isEmpty) return 0;
    final from = _points.last;
    final folded = MeanderEngine.polylineLength([from, ..._legsTo(at)]);
    final straight = MeanderEngine.polylineLength([from, ..._legalTo(at)]);
    return math.max(0, folded - straight);
  }

  /// The loops the Route tool is set to draw, and a way to change them.
  Widget _meanderChip(BoardScene scene) => _Chip(
    key: const ValueKey('meander-shape'),
    icon: Icons.waves,
    label:
        '${_meander.style.label} ${_mm(_meander.amplitude)}'
        '×${_mm(_meander.pitch)}',
    onPressed: () => _chooseMeander(scene),
  );

  Future<void> _chooseMeander(BoardScene scene) async {
    final shape = await showMeanderShapeSheet(
      context,
      shape: _meander,
      trackWidth: _widthFor(scene),
      clearance: scene.clearanceFor(_routeNetId),
    );
    if (shape == null || !mounted) return;
    setState(() => _meander = shape);
  }

  /// The gap the pair runs at, and which way the second half follows.
  Widget _pairChip(BoardScene scene) => _Chip(
    key: const ValueKey('pair-shape'),
    icon: Icons.drag_handle,
    label: '${_pairStyle.label} ${_mm(_gapFor(scene))}',
    onPressed: () => _choosePair(scene),
  );

  Future<void> _choosePair(BoardScene scene) async {
    final style = await _pickFrom(
      DiffPairStyle.values,
      selected: _pairStyle,
      icon: (s) => s == DiffPairStyle.mirrored
          ? Icons.drag_handle
          : Icons.content_copy_outlined,
      label: (s) => s.label,
      hint: (s) => s.note,
    );
    if (style == null || !mounted) return;
    setState(() => _pairStyle = style);
    final width = _widthFor(scene);
    final gap = await _pickFrom(
      // Centre to centre, so the narrowest offered still leaves a gap of
      // the clearance between the two pieces of copper.
      [
        for (final multiple in const [1.5, 2.0, 2.5, 3.0, 4.0, 5.0])
          (width * multiple * 100).roundToDouble() / 100,
      ],
      selected: _gapFor(scene),
      icon: (_) => Icons.drag_handle,
      label: (value) => '${_mm(value)} mm',
      hint: (value) =>
          'Edge to edge ${_mm(value - width)} mm — '
          '${(value / width).toStringAsFixed(1)}× the track',
    );
    if (gap == null || !mounted) return;
    setState(() => _pairGap = gap);
  }

  Widget _routeModeChip() => _Chip(
    key: const ValueKey('route-mode'),
    icon: _routeMode.icon,
    label: _routeMode.label,
    onPressed: () => setState(() {
      _routeMode =
          RouteMode.values[(_routeMode.index + 1) % RouteMode.values.length];
      _walked = null;
      _notify(
        _routeMode == RouteMode.walkaround
            ? 'Tracks go round other nets at the clearance'
            : 'Tracks go where aimed; clashes show red',
      );
    }),
  );

  void _undoPoint() => setState(() {
    final leg = _legLengths.isEmpty ? 1 : _legLengths.removeLast();
    if (_points.length - leg <= 0) {
      _clearDrawing();
    } else {
      _points.removeRange(_points.length - leg, _points.length);
    }
  });

  void _clearDrawing() {
    _points.clear();
    _legLengths.clear();
    _pair = null;
    _pairFrom = null;
    _pairSide = 1;
    _busFrom = null;
    _busLanes = const [];
    _routeNetId = null;
    _routeLayer = null;
    _arcLong = false;
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
      case AimTool.bus:
        await _finishBus(scene);
      case AimTool.region:
      case AimTool.text:
      case AimTool.feature:
        setState(_clearDrawing);
    }
  }

  Future<void> _finishRoute(BoardScene scene) async {
    final CopperLayer layer = _routeLayer ?? ref.read(activeLayerProvider);
    final netId = _routeNetId;
    final width = _widthFor(scene);

    // A pair is two runs on two nets; everything else is one run on one.
    final pair = _pair;
    final pairRuns = pair == null
        ? null
        : _pairRuns(scene, List<Offset>.from(_points));
    final runs = pairRuns == null
        ? [
            (
              netId,
              _curveRadius > 0
                  ? roundCorners(
                      List<Offset>.from(_points),
                      radius: _curveRadius,
                    )
                  : List<Offset>.from(_points),
            ),
          ]
        : [(pair!.positiveId, pairRuns.$1), (pair.negativeId, pairRuns.$2)];
    setState(_clearDrawing);

    final repository = ref.read(boardRepositoryProvider);
    final written = <String>[];
    for (final (net, corners) in runs) {
      if (corners.length < 2) continue;
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
            width: width,
            netId: net,
          ),
        );
      }
    }
    if (written.isEmpty) return;

    unawaited(HapticFeedback.lightImpact());
    if (pairRuns != null) {
      _notify(
        '${pair!.label} at '
        '${_mm(DiffPairs.gapBetween(pairRuns.$1, pairRuns.$2))} mm',
      );
    }
    // The rows as laid, so a redo can put back exactly these.
    final laid = [
      for (final track in await repository.getTracks(widget.project.id))
        if (written.contains(track.id)) track,
    ];
    _record(
      pairRuns == null ? 'Route' : 'Route a pair',
      undo: () => repository.deleteTracks(written),
      redo: () => repository.restoreCopper(tracks: laid, vias: const []),
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
      _notify('An area needs at least three corners');
      return;
    }

    final repository = ref.read(boardRepositoryProvider);
    final layer = ref.read(activeLayerProvider).layer;
    final rules = scene.board.rules;

    // A keepout belongs to no net: it claims the area rather than filling
    // it, so there is nothing to ask.
    if (_pourStyle == PourStyle.keepout) {
      final area = await repository.addZone(
        projectId: widget.project.id,
        layer: layer,
        points: points,
        clearance: math.max(rules.clearance, 0.2),
        keepout: true,
      );
      if (!mounted) return;
      setState(() => _selectedZoneId = area.id);
      _notify('Keepout: no tracks, vias or pours');
      _record(
        'Add a keepout',
        undo: () => repository.deleteZone(area.id),
        redo: () => repository.restoreZone(area),
      );
      return;
    }

    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    if (!mounted) return;
    final net = await _chooseNet(nets);
    if (!mounted) return;

    final added = await repository.addZone(
      projectId: widget.project.id,
      layer: layer,
      points: points,
      netId: net?.net.id,
      netName: net?.displayName ?? '',
      clearance: math.max(rules.clearance * 2, 0.4),
      // How a pour joins its own net is a board-wide habit, not a decision
      // to make again for every pour — so a new one starts on the board's
      // settings and can be argued with afterwards.
      padConnection: rules.padConnection,
      viaConnection: rules.viaConnection,
      thermalGap: rules.thermalGap,
      thermalSpoke: rules.thermalSpoke,
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
    // Worked out before the drawing is cleared: clearing also forgets which
    // way round an arc was to go.
    final shape = _edgeShape(List<Offset>.from(_points));
    setState(_clearDrawing);
    if (shape == null) return;
    var (kind, at) = shape;

    final repository = ref.read(boardRepositoryProvider);
    final closed =
        kind == BoardEdgeKind.polygon || kind == BoardEdgeKind.circle;

    // The first closed shape on a board with no outline is the outline.
    if (closed && !scene.outline.isDrawn) {
      final outline = switch (kind) {
        BoardEdgeKind.circle => BoardOutline.circle(
          Rect.fromCircle(center: at[0], radius: (at[1] - at[0]).distance),
        ),
        _ when _edgeStyle == EdgeStyle.rectangle => BoardOutline.rectangle(
          Rect.fromPoints(at[0], at[2]),
        ),
        _ => BoardOutline.polygon(at),
      };
      if (outline.bounds.width < 1 || outline.bounds.height < 1) {
        _notify('Too small for a board');
        return;
      }
      final before = scene.board;
      final after = before.withOutline(outline);
      await repository.updateBoard(after);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      _notify('Board outline drawn — ${outline.kind.label.toLowerCase()}');
      _record(
        'Draw the board outline',
        undo: () => repository.updateBoard(before),
        redo: () => repository.updateBoard(after),
      );
      return;
    }

    // A rectangle cutout is kept as a rectangle, by two opposite corners.
    if (_edgeStyle == EdgeStyle.rectangle) {
      kind = BoardEdgeKind.rectangle;
      at = [at[0], at[2]];
    }

    // A run of more than two corners is several lines, not one.
    if (kind == BoardEdgeKind.line && at.length > 2) {
      final ids = <String>[];
      for (var i = 0; i < at.length - 1; i++) {
        final segment = await repository.addEdge(
          projectId: widget.project.id,
          kind: BoardEdgeKind.line,
          points: [at[i], at[i + 1]],
        );
        ids.add(segment.id);
      }
      final laid = [
        for (final edge in await repository.getEdges(widget.project.id))
          if (ids.contains(edge.id)) edge,
      ];
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      _record(
        'Add edge cuts',
        undo: () async {
          for (final id in ids) {
            await repository.deleteEdge(id);
          }
        },
        redo: () async {
          for (final edge in laid) {
            await repository.restoreEdge(edge);
          }
        },
      );
      return;
    }

    final added = await repository.addEdge(
      projectId: widget.project.id,
      kind: kind,
      points: at,
    );
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _selectedEdgeId = added.id);
    _record(
      'Add an edge cut',
      undo: () => repository.deleteEdge(added.id),
      redo: () => repository.restoreEdge(added),
    );
  }

  Future<NetWithEndpoints?> _chooseNet(
    List<NetWithEndpoints> nets, {
    String title = 'Fill this pour with',
  }) async {
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
                child: Text(title, style: Theme.of(sheet).textTheme.titleSmall),
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

  /// A via at [at], on [netId] if the caller knows it.
  ///
  /// A via that ends up on no net is worse than useless: it is copper in
  /// everyone's way, so the walk-around refuses to come near it and the
  /// rule check calls it a clash — which is exactly what happened to a via
  /// dropped at the end of a run, because the copper it was meant to pick
  /// its net up from had not been written yet. So the net is passed in
  /// wherever it is known, and only guessed at from what is underneath
  /// when it is not.
  Future<void> _dropVia(BoardScene scene, Offset at, {String? netId}) async {
    final repository = ref.read(boardRepositoryProvider);
    final size = _viaFor(scene);
    final under =
        netId ??
        scene.padNear(at, size.diameter / 2)?.netId ??
        scene.trackNear(at, math.max(0.4, size.diameter / 2))?.netId;
    final id = await repository.addVia(
      projectId: widget.project.id,
      x: at.dx,
      y: at.dy,
      diameter: size.diameter,
      drill: size.drill,
      netId: under,
    );
    final laid = [
      for (final via in await repository.getVias(widget.project.id))
        if (via.id == id) via,
    ];
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Add a via',
      undo: () => repository.deleteVias([id]),
      redo: () => repository.restoreCopper(tracks: const [], vias: laid),
    );
  }

  /// Changes the routing layer: turns the board over on two layers, and
  /// asks which on more.
  Future<void> _chooseLayer(BoardScene scene) async {
    final board = scene.board;
    final active = ref.read(activeLayerProvider);
    if (board.copperLayerCount <= 2) {
      ref.read(activeLayerProvider.notifier).next(board);
      return;
    }
    final chosen = await showLayerPicker(context, board: board, active: active);
    if (chosen == null || !mounted) return;
    ref.read(activeLayerProvider.notifier).set(chosen);
  }

  Future<void> _viaAndSwitch(BoardScene scene) async {
    if (_points.isEmpty) return;
    final at = _points.last;
    // Held before the route is written, because writing it clears it.
    final netId = _routeNetId;
    await _finishRoute(scene);
    await _dropVia(scene, at, netId: netId);
    if (!mounted) return;
    setState(() => _routeNetId = netId);

    final before = ref.read(activeLayerProvider);
    await _chooseLayer(scene);
    if (!mounted) return;
    // A picker dismissed without a choice leaves the via in place and the
    // route where it was: nothing to carry on with on the same layer.
    if (ref.read(activeLayerProvider) == before) return;
    // An impedance-controlled net changes width with the layer it is on.
    final netClass = scene.classOf(_routeNetId);
    if (netClass?.impedance != null) {
      _trackWidth = netClass!.widthOn(
        scene.board.stackup,
        ref.read(activeLayerProvider),
      );
    }
    setState(() {
      _points
        ..clear()
        ..add(at);
      _legLengths
        ..clear()
        ..add(1);
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
    if (_carryingTextId != null ||
        _carryingLabelId != null ||
        _carryingImageId != null) {
      await _dropSilk(scene, at);
      return;
    }
    if (_carryingOutlineHandle != null) {
      await _dropOutlineHandle(scene, at);
      return;
    }
    if (_carryingId != null) {
      await _dropCarried(scene, at);
      return;
    }
    if (anchor == null) return;
    final delta = at - anchor;

    final slidingId = _slidingTrackId;
    if (slidingId != null) {
      await _dropSlide(scene, slidingId, delta);
      return;
    }

    if (_carryingSelection && _replicas.isNotEmpty) {
      await _dropMoved(scene, delta);
      if (mounted) await _placeNextReplica();
      return;
    }
    await _dropMoved(scene, delta);
  }

  Future<void> _dropMoved(BoardScene scene, Offset delta) async {
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
    unawaited(HapticFeedback.lightImpact());
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

  Future<void> _dropSlide(
    BoardScene scene,
    String trackId,
    Offset delta,
  ) async {
    final track = scene.tracks.where((t) => t.id == trackId).firstOrNull;
    setState(_stopCarrying);
    if (track == null) return;

    final slide = slideTrack(
      track: track,
      others: scene.tracks,
      delta: delta,
      anchors: [for (final pad in scene.pads) pad.position],
      lock: _angleLock,
    );
    if (slide.isEmpty) return;

    final repository = ref.read(boardRepositoryProvider);
    final before = [
      for (final moved in slide.moved)
        scene.tracks.firstWhere((t) => t.id == moved.id),
      for (final id in slide.removed)
        scene.tracks.firstWhere((t) => t.id == id),
    ];

    for (final moved in slide.moved) {
      await repository.updateTrack(moved);
    }
    // The old connections go, and legal copper replaces them.
    await repository.deleteTracks(slide.removed);
    final laid = <String>[];
    for (final segment in slide.added) {
      laid.add(
        await repository.addTrack(
          projectId: widget.project.id,
          layer: track.layer,
          startX: segment.from.dx,
          startY: segment.from.dy,
          endX: segment.to.dx,
          endY: segment.to.dy,
          width: track.width,
          netId: track.netId,
        ),
      );
    }

    final laidTracks = [
      for (final row in await repository.getTracks(widget.project.id))
        if (laid.contains(row.id)) row,
    ];
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Slide a track',
      undo: () async {
        await repository.deleteTracks(laid);
        await repository.restoreCopper(
          tracks: [
            for (final original in before)
              if (slide.removed.contains(original.id)) original,
          ],
          vias: const [],
        );
        for (final original in before) {
          if (slide.removed.contains(original.id)) continue;
          await repository.updateTrack(original);
        }
      },
      redo: () async {
        for (final moved in slide.moved) {
          await repository.updateTrack(moved);
        }
        await repository.deleteTracks(slide.removed);
        await repository.restoreCopper(tracks: laidTracks, vias: const []);
      },
    );
  }

  Future<void> _dropCarried(BoardScene scene, Offset at) async {
    final id = _carryingId;
    if (id == null) return;
    final footprint = scene.footprints.where((f) => f.ref.id == id).firstOrNull;
    setState(() {
      _carryingId = null;
      _carryAnchor = null;
    });
    // A part coming off the Parts list is not on the board yet, so it is
    // not among the placed footprints; it still drops.

    final repository = ref.read(boardRepositoryProvider);
    final placements =
        ref.read(boardFootprintsProvider(widget.project.id)).value ?? [];
    final before = placements.where((p) => p.id == id).firstOrNull;
    if (before == null) return;

    final after = before.copyWith(x: at.dx, y: at.dy, placed: true);
    await repository.updatePlacement(after);
    unawaited(HapticFeedback.lightImpact());
    _record(
      footprint == null ? 'Place part' : 'Move ${footprint.part.reference}',
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
        .updatePlacement(
          before.copyWith(rotation: (before.rotation + 90) % 360),
        );
  }

  // --- silkscreen ------------------------------------------------------

  /// The scene with the carried text or designator following the crosshair.
  BoardScene _withSilkMoved(BoardScene committed, Offset at) => BoardScene(
    board: committed.board,
    footprints: [
      for (final footprint in committed.footprints)
        if (footprint.ref.id == _carryingLabelId)
          PlacedFootprint(
            ref: footprint.ref.copyWith(
              labelOffset: footprint.placement.invert(at),
            ),
            part: footprint.part,
            placement: footprint.placement,
            pads: footprint.pads,
            definition: footprint.definition,
          )
        else
          footprint,
    ],
    pads: committed.pads,
    tracks: committed.tracks,
    vias: committed.vias,
    ratsnest: committed.ratsnest,
    unplaced: committed.unplaced,
    edges: committed.edges,
    zones: committed.zones,
    texts: [
      for (final text in committed.texts)
        text.id == _carryingTextId ? text.copyWith(position: at) : text,
    ],
    images: [
      for (final image in committed.images)
        image.id == _carryingImageId ? image.copyWith(position: at) : image,
    ],
    features: committed.features,
    dimensions: committed.dimensions,
    staleTrackIds: committed.staleTrackIds,
    staleViaIds: committed.staleViaIds,
    netClasses: committed.netClasses,
    netClassByNet: committed.netClassByNet,
    pourJoins: committed.pourJoins,
    previewOf: committed.previewOf ?? committed,
  );

  Future<void> _dropSilk(BoardScene scene, Offset at) async {
    final textId = _carryingTextId;
    final labelId = _carryingLabelId;
    final imageId = _carryingImageId;
    setState(() {
      _carryingTextId = null;
      _carryingLabelId = null;
      _carryingImageId = null;
    });
    final repository = ref.read(boardRepositoryProvider);

    if (imageId != null) {
      final before = scene.images.where((i) => i.id == imageId).firstOrNull;
      if (before == null) return;
      final after = before.copyWith(position: at);
      await repository.updateImage(after);
      unawaited(HapticFeedback.lightImpact());
      _record(
        'Move ${before.name}',
        undo: () => repository.updateImage(before),
        redo: () => repository.updateImage(after),
      );
      return;
    }

    if (textId != null) {
      final before = scene.texts.where((t) => t.id == textId).firstOrNull;
      if (before == null) return;
      final after = before.copyWith(position: at);
      await repository.updateText(after);
      unawaited(HapticFeedback.lightImpact());
      _record(
        'Move text',
        undo: () => repository.updateText(before),
        redo: () => repository.updateText(after),
      );
      return;
    }

    final footprint = scene.footprints
        .where((f) => f.ref.id == labelId)
        .firstOrNull;
    if (footprint == null) return;
    // Stored in the part's own frame, so the label turns and flips with
    // the part afterwards instead of being left behind on the board.
    final before = footprint.ref;
    final after = before.copyWith(labelOffset: footprint.placement.invert(at));
    await repository.updatePlacement(after);
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Move ${footprint.part.reference} label',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  Future<void> _addText(Offset at) async {
    final result = await showSilkscreenTextDialog(
      context,
      // On whichever side is being worked on, which is nearly always the
      // side the text was meant for.
      back: ref.read(activeLayerProvider) == CopperLayer.back,
      font: _lastFont,
      onAddFont: _addFont,
    );
    if (result == null || result.deleted || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final added = await repository.addText(
      projectId: widget.project.id,
      content: result.content,
      position: at,
      rotation: result.rotation,
      size: result.size,
      back: result.back,
      font: result.font,
    );
    _lastFont = result.font;
    if (!mounted) return;
    setState(() {
      _clearSelection();
      _selectedTextId = added.id;
    });
    _record(
      'Add text',
      undo: () => repository.deleteText(added.id),
      redo: () => repository.restoreText(added),
    );
  }

  Future<void> _editText(BoardText text) async {
    final result = await showSilkscreenTextDialog(
      context,
      content: text.content,
      size: text.size,
      rotation: text.rotation,
      back: text.back,
      existing: true,
      font: text.font,
      onAddFont: _addFont,
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      await _deleteText(text);
      return;
    }

    final repository = ref.read(boardRepositoryProvider);
    final after = text.copyWith(
      content: result.content,
      size: result.size,
      rotation: result.rotation,
      back: result.back,
      font: result.font,
    );
    _lastFont = result.font;
    await repository.updateText(after);
    _record(
      'Edit text',
      undo: () => repository.updateText(text),
      redo: () => repository.updateText(after),
    );
  }

  Future<void> _deleteText(BoardText text) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteText(text.id);
    if (mounted) setState(() => _selectedTextId = null);
    _record(
      'Delete text',
      undo: () => repository.restoreText(text),
      redo: () => repository.deleteText(text.id),
    );
  }

  /// The font the last text was given, offered for the next one.
  String _lastFont = '';

  /// Adds a TrueType font from the phone, for every board to use.
  Future<SilkFontInfo?> _addFont() async {
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Pick a .ttf font',
        type: FileType.any,
      );
      if (picked.isEmpty) return null;
      final file = picked.first;
      final added = await ref
          .read(fontRepositoryProvider)
          .add(file.name, await file.readAsBytes());
      _notify('Added ${added.name}');
      return added;
    } on FormatException catch (error) {
      _notify(error.message);
      return null;
    }
  }

  void _pickSilkStyle(SilkStyle style) {
    _pickTool(AimTool.text);
    setState(() => _silkStyle = style);
    _notify(style.hint);
  }

  Future<void> _chooseSilkStyle() async {
    final chosen = await _pickFrom(
      SilkStyle.values,
      selected: _silkStyle,
      icon: (s) => s.icon,
      label: (s) => s.label,
      hint: (s) => s.hint,
    );
    if (chosen == null || !mounted) return;
    _pickSilkStyle(chosen);
  }

  Future<void> _placePicture(Offset at, PreparedPicture picture) async {
    final repository = ref.read(boardRepositoryProvider);
    final added = await repository.addImage(
      projectId: widget.project.id,
      name: picture.name,
      position: at,
      width: picture.width,
      columns: picture.columns,
      rows: picture.rows,
      bits: picture.bits,
      back: ref.read(activeLayerProvider) == CopperLayer.back,
    );
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _clearSelection();
      _selectedImageId = added.id;
    });
    _record(
      'Add ${picture.name}',
      undo: () => repository.deleteImage(added.id),
      redo: () => repository.restoreImage(added),
    );
  }

  Future<void> _editPicture(BoardImage image) async {
    final result = await showPicturePropertiesDialog(context, image);
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    await repository.updateImage(result);
    _record(
      'Edit ${image.name}',
      undo: () => repository.updateImage(image),
      redo: () => repository.updateImage(result),
    );
  }

  Future<void> _deletePicture(BoardImage image) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteImage(image.id);
    if (mounted) setState(() => _selectedImageId = null);
    _record(
      'Delete ${image.name}',
      undo: () => repository.restoreImage(image),
      redo: () => repository.deleteImage(image.id),
    );
  }

  Future<void> _editDesignator(PlacedFootprint footprint) async {
    final result = await showDesignatorDialog(
      context,
      reference: footprint.part.reference,
      size: footprint.ref.labelSize,
      hidden: footprint.ref.labelHidden,
      moved: footprint.ref.labelOffset != null,
    );
    if (result == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final before = footprint.ref;
    final after = before.copyWith(
      labelSize: result.size,
      labelHidden: result.hidden,
      clearLabelOffset: result.resetPosition,
    );
    await repository.updatePlacement(after);
    _record(
      '${footprint.part.reference} label',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  Future<void> _toggleLabel(PlacedFootprint footprint) async {
    final repository = ref.read(boardRepositoryProvider);
    final before = footprint.ref;
    final after = before.copyWith(labelHidden: !before.labelHidden);
    await repository.updatePlacement(after);
    _record(
      after.labelHidden
          ? 'Hide ${footprint.part.reference} label'
          : 'Show ${footprint.part.reference} label',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(after),
    );
  }

  /// The text whose printed box [board] falls in.
  BoardText? _nearestText(BoardScene scene, Offset board, double tolerance) {
    for (final text in scene.texts.reversed) {
      if (_inTextBox(
        board,
        centre: text.position,
        characters: text.content.length,
        size: text.size,
        rotation: text.rotation,
        // No slack: silkscreen sits over parts and tracks, and a generous
        // box would steal the taps meant for them.
        slack: 0,
      )) {
        return text;
      }
    }
    return null;
  }

  /// The part whose printed designator [board] falls on. A hidden one is
  /// not there to be tapped; it comes back through the part's Label.
  PlacedFootprint? _nearestLabel(
    BoardScene scene,
    Offset board,
    double tolerance,
  ) {
    for (final footprint in scene.footprints.reversed) {
      if (footprint.ref.labelHidden) continue;
      if (_inTextBox(
        board,
        centre: footprint.labelPosition,
        characters: footprint.part.reference.length,
        size: footprint.ref.labelSize,
        rotation: 0,
        // No slack: silkscreen sits over parts and tracks, and a generous
        // box would steal the taps meant for them.
        slack: 0,
      )) {
        return footprint;
      }
    }
    return null;
  }

  static bool _inTextBox(
    Offset point, {
    required Offset centre,
    required int characters,
    required double size,
    required double rotation,
    required double slack,
  }) {
    var halfWidth = characters * size * 0.3 + slack;
    var halfHeight = size * 0.6 + slack;
    final quarter = (rotation % 180 + 180) % 180;
    if (quarter > 45 && quarter < 135) {
      final swap = halfWidth;
      halfWidth = halfHeight;
      halfHeight = swap;
    }
    final d = point - centre;
    return d.dx.abs() <= halfWidth && d.dy.abs() <= halfHeight;
  }

  /// Picks a placed segment up so it can be slid sideways.
  ///
  /// The run stays a run: the neighbours either side keep their own angles
  /// and their far ends, and only the corners between them travel. An end
  /// with nothing to absorb the movement grows a stub rather than coming
  /// off the pad it was on.
  void _slide(Track track) {
    setState(() {
      _slidingTrackId = track.id;
      _selectedTrackId = track.id;
      // Measured from the track's own line, not from wherever the crosshair
      // happened to be: the run goes through the crosshair, so a track picked
      // with a tap does not leap by the distance to the crosshair.
      _carryAnchor = Offset(track.startX, track.startY);
    });
    _notify('Pan to slide the track, then DROP');
  }

  void _stopCarrying() {
    _replicas = const [];
    _replicaSource = null;
    _carryAnchor = null;
    _carryingEdgeId = null;
    _slidingTrackId = null;
    _carryingTextId = null;
    _carryingLabelId = null;
    _carryingImageId = null;
    _carryingOutline = false;
    _carryingOutlineHandle = null;
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

  /// Picks up the outline corner nearest the crosshair, so the board can be
  /// resized by aiming at where that corner should go.
  void _grabOutlineHandle(BoardScene scene) {
    final outline = scene.outline;
    final handles = outline.handles;
    final aim = _lastSnap;
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < handles.length; i++) {
      // A circle's first handle is its centre, which moves it rather than
      // sizing it; Move outline already does that.
      if (outline.kind == BoardOutlineKind.circle && i == 0) continue;
      final distance = (handles[i] - aim).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best < 0) return;
    setState(() {
      _carryingOutlineHandle = best;
      _carryAnchor = aim;
    });
    _notify(
      outline.kind == BoardOutlineKind.circle
          ? 'Pan to size the board, then DROP'
          : 'Pan to where that corner goes, then DROP',
    );
  }

  BoardOutline _resizedOutline(BoardScene scene, int handle, Offset at) => scene
      .outline
      .withHandleAt(handle, at, minimum: math.max(scene.board.gridMm * 2, 0.2));

  Future<void> _dropOutlineHandle(BoardScene scene, Offset at) async {
    final handle = _carryingOutlineHandle;
    setState(() {
      _carryingOutlineHandle = null;
      _carryAnchor = null;
    });
    if (handle == null) return;
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.withOutline(_resizedOutline(scene, handle, at));
    await repository.updateBoard(after);
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Resize board',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  /// The scene with a different board under it.
  BoardScene _withBoard(BoardScene committed, Board board) => BoardScene(
    board: board,
    footprints: committed.footprints,
    pads: committed.pads,
    tracks: committed.tracks,
    vias: committed.vias,
    ratsnest: committed.ratsnest,
    unplaced: committed.unplaced,
    edges: committed.edges,
    zones: committed.zones,
    texts: committed.texts,
    images: committed.images,
    features: committed.features,
    dimensions: committed.dimensions,
    staleTrackIds: committed.staleTrackIds,
    staleViaIds: committed.staleViaIds,
    netClasses: committed.netClasses,
    netClassByNet: committed.netClassByNet,
    pourJoins: committed.pourJoins,
    previewOf: committed.previewOf ?? committed,
  );

  void _carryRegion() {
    setState(() {
      _carryAnchor = _lastSnap;
      _region = null;
      _regionFrom = null;
    });
    _notify('Pan to move ${_selected.count} things, then DROP');
  }

  /// The same layout for every other channel of the circuit.
  ///
  /// The channels are found on the schematic: parts with the same symbols
  /// and footprints, wired to each other the same way. Each copy's parts
  /// take the original's positions and its tracks come along on the copy's
  /// own nets, and then it rides the crosshair to wherever it goes.
  Future<void> _replicate(BoardScene scene) async {
    final placements =
        ref.read(boardFootprintsProvider(widget.project.id)).value ??
        const <PlacedFootprintRef>[];
    final nets = ref.read(projectNetsProvider(widget.project.id)).value;
    if (nets == null) return;
    final source = [
      for (final placement in placements)
        if (_selected.footprintIds.contains(placement.id)) placement,
    ];
    final channels = findReplicaChannels(
      sourcePartIds: {for (final p in source) p.partId},
      nets: nets,
      footprintOf: {for (final p in placements) p.partId: p.libId},
    );
    if (channels.isEmpty) {
      _notify(
        'No other copy of this circuit on the schematic. '
        'Copy it there first, then replicate',
      );
      return;
    }

    _replicaSource = _replicaSourceOf(scene, source);
    _replicas = [...channels];
    await _placeNextReplica();
  }

  /// What is in the swept area, to be copied, and where a copy first
  /// appears: beside the original, clear of it, until placed.
  _ReplicaSource _replicaSourceOf(
    BoardScene scene,
    List<PlacedFootprintRef> source,
  ) {
    final points = [
      for (final p in source) Offset(p.x, p.y),
      for (final t in scene.tracks)
        if (_selected.trackIds.contains(t.id)) ...[
          Offset(t.startX, t.startY),
          Offset(t.endX, t.endY),
        ],
    ];
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    return _ReplicaSource(
      placements: source,
      tracks: [
        for (final t in scene.tracks)
          if (_selected.trackIds.contains(t.id)) t,
      ],
      vias: [
        for (final v in scene.vias)
          if (_selected.viaIds.contains(v.id)) v,
      ],
      offset: Offset(right - left + 5, 0),
    );
  }

  /// The swept parts again, as new parts: added to the schematic wired the
  /// way the originals are among themselves, then laid out on the board
  /// the same way, tracks and all, riding the crosshair until dropped.
  ///
  /// Connections that leave the copied parts come along only when named,
  /// like GND, so the copy joins the same supply and nothing else.
  Future<void> _copyAsNewParts(BoardScene scene) async {
    final projectId = widget.project.id;
    final partRepository = ref.read(partRepositoryProvider);
    final netRepository = ref.read(netRepositoryProvider);
    final boards = ref.read(boardRepositoryProvider);
    final placements = await boards.getFootprints(projectId);
    final parts = await partRepository.getPartsWithDetails(projectId);
    final nets = await netRepository.getNets(projectId);
    final wires = await netRepository.getWires(projectId);
    final source = [
      for (final placement in placements)
        if (_selected.footprintIds.contains(placement.id)) placement,
    ];
    final sourcePartIds = {for (final p in source) p.partId};
    final sourceParts = [
      for (final part in parts)
        if (sourcePartIds.contains(part.part.id)) part,
    ];
    final units = [for (final part in sourceParts) ...part.units];
    final clip = CircuitClip.of(
      parts: parts,
      nets: nets,
      wires: wires,
      unitIds: {for (final unit in units) unit.id},
    );
    if (clip == null || !mounted) return;

    // On the schematic, beside the originals, on the grid.
    final first = sourceParts.first.units.first;
    final xs = [for (final unit in units) unit.x];
    final span = xs.reduce(math.max) - xs.reduce(math.min);
    const grid = 2.54;
    final at = Offset(
      ((first.x + span + 20) / grid).roundToDouble() * grid,
      (first.y / grid).roundToDouble() * grid,
    );

    final pasted = await CircuitPaster(
      partRepository,
      netRepository,
    ).paste(projectId, clip, at: at);
    for (var i = 0; i < pasted.partIds.length && i < sourceParts.length; i++) {
      final original = source.firstWhere(
        (p) => p.partId == sourceParts[i].part.id,
      );
      await boards.assignFootprint(
        projectId: projectId,
        partId: pasted.partIds[i],
        libId: original.libId,
      );
    }
    final snapshots = <PartSnapshot>[];
    for (final id in pasted.partIds) {
      final snapshot = await partRepository.capturePart(id);
      if (snapshot != null) snapshots.add(snapshot);
    }
    if (!mounted) return;
    _record(
      'Copy ${clip.summary} on the schematic',
      undo: () async {
        for (final wire in pasted.wires) {
          await netRepository.deleteWire(wire.id);
        }
        for (final id in pasted.partIds) {
          await partRepository.deletePart(id);
        }
      },
      redo: () async {
        for (final snapshot in snapshots) {
          await partRepository.restorePart(snapshot);
        }
        for (final wire in pasted.wires) {
          await netRepository.restoreWire(wire);
        }
      },
    );

    // Which new net stands in for each old one, pin by pin.
    String pinKey(String partId, PartPin pin) =>
        '$partId|${pin.unit}|${pin.number}';
    final netOfPin = <String, String>{};
    for (final net in await netRepository.getNets(projectId)) {
      for (final endpoint in net.endpoints) {
        netOfPin[pinKey(endpoint.part.id, endpoint.pin)] = net.id;
      }
    }
    final added = await partRepository.getPartsWithDetails(projectId);
    final partMap = <String, String>{};
    final netMap = <String, String>{};
    for (var i = 0; i < pasted.partIds.length && i < sourceParts.length; i++) {
      final from = sourceParts[i];
      final to = added.where((p) => p.part.id == pasted.partIds[i]).first;
      partMap[from.part.id] = to.part.id;
      for (final pin in from.pins) {
        final oldNet = netOfPin[pinKey(from.part.id, pin)];
        final newNet = netOfPin[pinKey(to.part.id, pin)];
        if (oldNet != null && newNet != null) netMap[oldNet] = newNet;
      }
    }

    _replicaSource = _replicaSourceOf(scene, source);
    _replicas = [ReplicaChannel(parts: partMap, nets: netMap)];
    await _placeNextReplica();
  }

  Future<void> _placeNextReplica() async {
    final source = _replicaSource;
    if (source == null || _replicas.isEmpty) return;
    final channel = _replicas.first;
    _replicas = _replicas.sublist(1);
    final repository = ref.read(boardRepositoryProvider);
    final placements = await repository.getFootprints(widget.project.id);
    final offset = source.offset;

    final before = <PlacedFootprintRef>[];
    final after = <PlacedFootprintRef>[];
    for (final original in source.placements) {
      final partId = channel.parts[original.partId];
      final target = placements.where((p) => p.partId == partId).firstOrNull;
      if (target == null) continue;
      before.add(target);
      after.add(
        target.copyWith(
          x: original.x + offset.dx,
          y: original.y + offset.dy,
          rotation: original.rotation,
          flipped: original.flipped,
          placed: true,
        ),
      );
    }
    String? netFor(String? netId) => netId == null ? null : channel.nets[netId];
    // Copper on a net the copy has no counterpart of stays behind: it
    // would only be a short to somewhere else.
    bool follows(String? netId) =>
        netId == null || channel.nets.containsKey(netId);
    final tracks = [
      for (final t in source.tracks.where((t) => follows(t.netId)))
        t
            .copyWith(
              id: newId(),
              startX: t.startX + offset.dx,
              startY: t.startY + offset.dy,
              endX: t.endX + offset.dx,
              endY: t.endY + offset.dy,
            )
            .withNet(netFor(t.netId)),
    ];
    final vias = [
      for (final v in source.vias.where((v) => follows(v.netId)))
        v.copyWith(
          id: newId(),
          x: v.x + offset.dx,
          y: v.y + offset.dy,
          netId: netFor(v.netId),
          clearNet: netFor(v.netId) == null,
        ),
    ];

    Future<void> apply() => ref.read(editTransactionProvider)(() async {
      for (final placement in after) {
        await repository.updatePlacement(placement);
      }
      await repository.restoreCopper(tracks: tracks, vias: vias);
    });
    await apply();
    if (!mounted) return;
    _record(
      'Replicate',
      undo: () => ref.read(editTransactionProvider)(() async {
        await repository.deleteTracks(tracks.map((t) => t.id));
        await repository.deleteVias(vias.map((v) => v.id));
        for (final placement in before) {
          await repository.updatePlacement(placement);
        }
      }),
      redo: apply,
    );

    final parts = await ref
        .read(partRepositoryProvider)
        .getPartsWithDetails(widget.project.id);
    if (!mounted) return;
    final names = [
      for (final placement in after)
        parts
                .where((p) => p.part.id == placement.partId)
                .firstOrNull
                ?.part
                .reference ??
            '',
    ]..sort();
    setState(() {
      _region = null;
      _regionFrom = null;
      _selected = _Selection(
        footprintIds: {for (final p in after) p.id},
        trackIds: {for (final t in tracks) t.id},
        viaIds: {for (final v in vias) v.id},
        edgeIds: const {},
        zoneIds: const {},
      );
      _carryAnchor = _lastSnap;
    });
    unawaited(HapticFeedback.mediumImpact());
    final left = _replicas.length;
    _notify(
      'Pan to place ${names.join(', ')}, then DROP'
      '${left > 0 ? ' ($left more after)' : ''}',
    );
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
          in ref.read(boardFootprintsProvider(widget.project.id)).value ??
              const <PlacedFootprintRef>[])
        if (moving.footprintIds.contains(placement.id)) placement,
    ];

    Future<void> remove() => ref.read(editTransactionProvider)(() async {
      await repository.deleteTracks(tracks.map((t) => t.id));
      await repository.deleteVias(vias.map((v) => v.id));
      for (final edge in edges) {
        await repository.deleteEdge(edge.id);
      }
      for (final zone in zones) {
        await repository.deleteZone(zone.id);
      }
      // A part is taken off the board rather than deleted: it belongs to
      // the schematic, and the board does not get to remove it from the
      // design.
      for (final placement in placements) {
        await repository.updatePlacement(placement.copyWith(placed: false));
      }
    });

    await remove();
    if (!mounted) return;
    final count = moving.count;
    setState(_clearSelection);
    unawaited(HapticFeedback.mediumImpact());
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
      redo: remove,
    );
  }

  /// What the sight is currently over, for the delete button.
  Object? _underCrosshair(BoardScene scene) {
    final at = _lastSnap;
    final viewport = _viewport;
    if (viewport == null) return null;
    final tolerance = math.max(0.3, 16 / viewport.pixelsPerMm);

    final text = _nearestText(scene, at, tolerance);
    if (text != null) return text;
    final via = _nearestVia(scene, at, tolerance);
    if (via != null) return via;
    final edge = _nearestEdge(scene, at, tolerance);
    if (edge != null) return edge;
    final track = scene.trackNear(at, tolerance);
    if (track != null) return track;
    final dimension = _nearestDimension(scene, at, tolerance);
    if (dimension != null) return dimension;
    final zone = _zoneAt(scene, at);
    if (zone != null) return zone;
    return null;
  }

  Future<void> _deleteUnderCrosshair(BoardScene scene) async {
    switch (_underCrosshair(scene)) {
      case final BoardText text:
        await _deleteText(text);
      case final Via via:
        await _deleteVia(via);
      case final BoardEdge edge:
        await _deleteEdge(edge);
      case final Track track:
        await _deleteTrack(track);
      case final BoardZone zone:
        await _deleteZone(zone);
      case final BoardDimension dimension:
        await _deleteDimension(dimension);
      default:
        return;
    }
    unawaited(HapticFeedback.mediumImpact());
  }

  /// The parts that belong on the board but are not on it yet.
  ///
  /// Power symbols are not among them: `#PWR` is a label with a shape, and
  /// KiCad keeps it off the board for the same reason.
  List<PartWithDetails> _waiting(
    BoardScene scene,
    List<PartWithDetails> parts,
  ) {
    final placed = {for (final f in scene.footprints) f.part.id};
    return [
      for (final part in parts)
        if (part.part.onBoard && !placed.contains(part.part.id)) part,
    ];
  }

  /// Every part and where it stands, with the verb that moves it on.
  void _showParts(BoardScene scene, List<PartWithDetails> parts) {
    final onBoard = [
      for (final p in parts)
        if (p.part.onBoard) p,
    ];
    final placed = {for (final f in scene.footprints) f.part.id};
    final assigned = {for (final ref_ in scene.unplaced) ref_.partId: ref_};

    final resolvable = [
      for (final part in onBoard)
        if (!placed.contains(part.part.id) &&
            !assigned.containsKey(part.part.id) &&
            part.part.footprint.trim().contains(':'))
          part,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Parts',
                      style: Theme.of(sheet).textTheme.titleMedium,
                    ),
                  ),
                  // Most parts already name their own footprint — it came
                  // from the symbol library — so there is no reason to ask
                  // for it again one at a time.
                  if (resolvable.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheet).pop();
                        _autoAssign(resolvable);
                      },
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: Text('ASSIGN ${resolvable.length}'),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (onBoard.isEmpty)
                    const ListTile(
                      dense: true,
                      title: Text('Nothing in this project goes on a board'),
                    ),
                  for (final part in onBoard)
                    () {
                      final isPlaced = placed.contains(part.part.id);
                      final ref_ = assigned[part.part.id];
                      final footprint = part.part.footprint.trim();

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isPlaced
                              ? Icons.check_circle
                              : (ref_ != null
                                    ? Icons.inbox_outlined
                                    : Icons.help_outline),
                          size: 18,
                          color: isPlaced
                              ? KicadPalette.success
                              : KicadPalette.warning,
                        ),
                        title: Text(
                          '${part.part.reference}  ${part.part.value}',
                        ),
                        subtitle: Text(
                          isPlaced
                              ? 'On the board'
                              : (ref_ != null
                                    ? 'Ready to place'
                                    : (footprint.contains(':')
                                          ? footprint
                                          : 'No footprint yet')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.of(sheet).pop();
                            if (isPlaced) {
                              _selectPlaced(part.part.id);
                            } else if (ref_ != null) {
                              _pickUp(ref_.id, part.part.reference);
                            } else {
                              setState(() => _assigningPartId = part.part.id);
                            }
                          },
                          child: Text(
                            isPlaced
                                ? 'SHOW'
                                : (ref_ != null ? 'PLACE' : 'FOOTPRINT'),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Gives every part that names an installed footprint its own, so the
  /// only ones left to answer for are the genuinely ambiguous.
  Future<void> _autoAssign(List<PartWithDetails> parts) async {
    final repository = ref.read(boardRepositoryProvider);
    final library = ref.read(footprintLibraryRepositoryProvider);

    var assigned = 0;
    var missing = 0;
    for (final part in parts) {
      final libId = part.part.footprint.trim();
      // Only if the library is actually installed: a footprint that cannot
      // be loaded puts a part on the board with no pads, which is worse
      // than saying so.
      if (await library.loadFootprint(libId) == null) {
        missing++;
        continue;
      }
      await repository.assignFootprint(
        projectId: widget.project.id,
        partId: part.part.id,
        libId: libId,
      );
      assigned++;
    }

    if (!mounted) return;
    _notify(
      missing == 0
          ? '$assigned ready to place'
          : '$assigned ready · $missing need a library importing',
    );
  }

  void _selectPlaced(String partId) {
    final scene = ref.read(boardSceneProvider(widget.project.id)).value;
    final footprint = scene?.footprints
        .where((f) => f.part.id == partId)
        .firstOrNull;
    if (footprint == null) return;

    setState(() {
      _clearSelection();
      _tool = AimTool.select;
      _selectedFootprintId = footprint.ref.id;
    });
    _centreOn(Offset(footprint.ref.x, footprint.ref.y));
  }

  /// Puts a part on the crosshair, ready to be panned into place.
  void _pickUp(String placementId, String reference) {
    setState(() {
      _clearSelection();
      _tool = AimTool.select;
      _carryingId = placementId;
      _carryAnchor = null;
    });
    _notify('Pan to where $reference goes, then DROP');
  }

  void _centreOn(Offset board) {
    final viewport = _viewport;
    if (viewport == null || _canvasSize.isEmpty) return;
    setState(() {
      _viewport = viewport.copyWith(
        origin: Offset(
          _canvasSize.width / 2 - board.dx * viewport.pixelsPerMm,
          _canvasSize.height / 2 - board.dy * viewport.pixelsPerMm,
        ),
      );
    });
  }

  // --- selection -------------------------------------------------------

  void _onTap(BoardScene scene, SchematicViewport viewport, Offset local) {
    if (_fabPreview || _carryingId != null) return;
    final board = viewport.toSheet(local);
    final tolerance = math.max(0.3, 16 / viewport.pixelsPerMm);

    // While drawing, a tap is not a selection — it would only get in the
    // way of the thing being drawn.
    if (_points.isNotEmpty) return;

    final pick = _pickAt(scene, board, tolerance);
    setState(() {
      _clearSelection();
      pick?.select();
    });
  }

  /// What is at [board], within [tolerance], and how to select it — shared
  /// by a tap on the board and by the sight's own button, so the two can
  /// never disagree about what is there.
  ///
  /// Silkscreen first: text is small and sits on top of everything, so it
  /// has first claim on a point that is over both it and what is beneath.
  ({String label, String id, VoidCallback select})? _pickAt(
    BoardScene scene,
    Offset board,
    double tolerance,
  ) {
    final text = _nearestText(scene, board, tolerance);
    if (text != null) {
      return (
        label: 'TEXT',
        id: 'text:${text.id}',
        select: () => _selectedTextId = text.id,
      );
    }
    final image = scene.images.reversed
        .where((i) => i.contains(board))
        .firstOrNull;
    if (image != null) {
      return (
        label: image.name.toUpperCase(),
        id: 'image:${image.id}',
        select: () => _selectedImageId = image.id,
      );
    }
    final labelled = _nearestLabel(scene, board, tolerance);
    if (labelled != null) {
      return (
        label: '${labelled.part.reference} LABEL',
        id: 'label:${labelled.ref.id}',
        select: () => _selectedLabelId = labelled.ref.id,
      );
    }
    final via = _nearestVia(scene, board, tolerance);
    if (via != null) {
      return (
        label: 'VIA',
        id: 'via:${via.id}',
        select: () {
          _selectedViaId = via.id;
          _highlightedNetId = via.netId;
        },
      );
    }
    final edge = _nearestEdge(scene, board, tolerance);
    if (edge != null) {
      return (
        label: 'CUT',
        id: 'edge:${edge.id}',
        select: () => _selectedEdgeId = edge.id,
      );
    }
    final track = scene.trackNear(board, tolerance);
    if (track != null) {
      return (
        label: 'TRACK',
        id: 'track:${track.id}',
        select: () {
          _selectedTrackId = track.id;
          _highlightedNetId = track.netId;
        },
      );
    }
    final footprint = scene.footprintAt(board);
    if (footprint != null) {
      return (
        label: footprint.part.reference,
        id: 'footprint:${footprint.ref.id}',
        select: () => _selectedFootprintId = footprint.ref.id,
      );
    }
    final zone = _zoneAt(scene, board);
    if (zone != null) {
      return (
        label: 'POUR',
        id: 'zone:${zone.id}',
        select: () {
          _selectedZoneId = zone.id;
          _highlightedNetId = zone.netId;
        },
      );
    }
    // The board edge itself, which is as much a drawn thing as the cuts
    // added to it and was the one object that could not be picked up.
    if (_onOutline(scene, board, tolerance)) {
      return (
        label: 'OUTLINE',
        id: 'outline',
        select: () => _outlineSelected = true,
      );
    }
    return null;
  }

  /// What is selected, in the same terms as [_pickAt].
  String? get _selectedPickId => switch (null) {
    _ when _selectedTextId != null => 'text:$_selectedTextId',
    _ when _selectedLabelId != null => 'label:$_selectedLabelId',
    _ when _selectedViaId != null => 'via:$_selectedViaId',
    _ when _selectedEdgeId != null => 'edge:$_selectedEdgeId',
    _ when _selectedTrackId != null => 'track:$_selectedTrackId',
    _ when _selectedFootprintId != null => 'footprint:$_selectedFootprintId',
    _ when _selectedZoneId != null => 'zone:$_selectedZoneId',
    _ when _outlineSelected => 'outline',
    _ => null,
  };

  /// What the sight's button does in Select, where there is nothing to
  /// place: select what the sight is over, so the right thumb can do what
  /// a tap in the middle of the screen does — and, over the thing already
  /// selected, pick it up.
  ({String label, VoidCallback onPressed})? _sightAction(BoardScene scene) {
    if (_tool != AimTool.select || _points.isNotEmpty || _fabPreview) {
      return null;
    }
    final viewport = _viewport;
    if (viewport == null) return null;
    final tolerance = math.max(0.3, 16 / viewport.pixelsPerMm);
    final pick = _pickAt(scene, _lastSnap, tolerance);
    if (pick == null) return null;

    if (pick.id == _selectedPickId) {
      final footprint = scene.footprints
          .where((f) => f.ref.id == _selectedFootprintId)
          .firstOrNull;
      if (footprint != null) {
        // The sight button says what it will do, and a held part says so
        // rather than doing nothing when pressed.
        if (footprint.ref.locked) {
          return (label: 'LOCKED', onPressed: () => _notify('Held in place'));
        }
        return (
          label: 'MOVE ${footprint.part.reference}',
          onPressed: () => _carry(footprint),
        );
      }
      final track = scene.tracks
          .where((t) => t.id == _selectedTrackId)
          .firstOrNull;
      if (track != null) {
        if (track.locked) {
          return (label: 'LOCKED', onPressed: () => _notify('Held in place'));
        }
        return (label: 'SLIDE', onPressed: () => _slide(track));
      }
      return (label: 'DESELECT', onPressed: () => setState(_clearSelection));
    }
    return (
      label: 'SELECT ${pick.label}',
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() {
          _clearSelection();
          pick.select();
        });
      },
    );
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
    _selectedTextId = null;
    _selectedImageId = null;
    _selectedLabelId = null;
    _region = null;
    _regionFrom = null;
    _selected = const _Selection.empty();
  }

  // --- sizes -----------------------------------------------------------

  /// How far apart the two halves of a pair run, centre to centre.
  ///
  /// A default of three times the track width is the rule of thumb for a
  /// loosely coupled pair on FR-4, and it is a starting point rather than
  /// an answer: the number that matters is the differential impedance, and
  /// that is what the gap chip is for.
  double _gapFor(BoardScene scene) =>
      _pairGap ?? math.max(_widthFor(scene) * 3, _widthFor(scene) + 0.2);

  /// The two runs a pair lays for the path drawn so far, each landing on
  /// its own pad at the start.
  (List<Offset>, List<Offset>)? _pairRuns(BoardScene scene, List<Offset> path) {
    final pair = _pair;
    final from = _pairFrom;
    if (pair == null || from == null || path.length < 2) return null;
    final (positive, negative) = DiffPairs.runs(
      path,
      gap: _gapFor(scene),
      style: _pairStyle,
      side: _pairSide,
    );
    // Each half starts on its own pad, whatever the offset put its first
    // corner at: the lead-in from the pad to the run is part of the track.
    final leaving = _points.first;
    final positivePad = _routeNetId == pair.positiveId ? leaving : from;
    final negativePad = _routeNetId == pair.positiveId ? from : leaving;
    return (
      DiffPairs.landOn(positive, positivePad, atEnd: false),
      DiffPairs.landOn(negative, negativePad, atEnd: false),
    );
  }

  /// Both halves of a pair as they would be laid, for drawing.
  ///
  /// The centre line the finger is following is not copper and is not
  /// drawn as copper — what is drawn is the two tracks it produces, which
  /// is the only way to see the gap you are actually laying.
  List<List<Offset>> _pairPreview(BoardScene scene, Offset at) {
    if (_tool != AimTool.route || _routeStyle != RouteStyle.pair) {
      return const [];
    }
    final runs = _pairRuns(scene, _pendingPath(at));
    if (runs == null) return const [];
    return [runs.$1, runs.$2];
  }

  double _widthFor(BoardScene scene) =>
      _trackWidth ??
      scene.trackWidthFor(
        _routeNetId,
        _routeLayer ?? ref.read(activeLayerProvider),
      );

  /// The parts sitting on top of one another, drawn in red.
  ///
  /// Worked out against the preview — the board as it would be if what is
  /// on the crosshair were put down here — so the red appears while the
  /// part is being moved, which is the only time it can still be moved
  /// somewhere else. Cached, because the preview is rebuilt every frame
  /// whether or not anything moved.
  List<Courtyard> _collisions(
    BoardScene committed,
    BoardScene preview,
    Offset at,
  ) {
    final cached = _collided;
    if (cached != null &&
        identical(cached.$1, committed) &&
        cached.$2 == at &&
        cached.$3 == _carryingId) {
      return cached.$4;
    }
    final found = Courtyard.collisions(preview);
    _collided = (committed, at, _carryingId, found);
    return found;
  }

  /// Where the route being drawn comes too close to another net.
  List<RouteClash> _clashes(BoardScene scene, Offset at) {
    if (_tool != AimTool.route || _points.isEmpty) return const [];
    return routeClashes(
      scene,
      route: _pendingPath(at),
      width: _widthFor(scene),
      layer: _routeLayer ?? ref.read(activeLayerProvider),
      netId: _routeNetId,
    );
  }

  ViaSize _viaFor(BoardScene scene) =>
      _viaSize ??
      ViaSize(scene.board.rules.viaDiameter, scene.board.rules.viaDrill);

  Future<void> _chooseWidth(BoardScene scene) async {
    final chosen = await showTrackWidthPicker(
      context,
      widths: scene.board.availableTrackWidths,
      classes: scene.netClasses,
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
  Future<void> _editSizes(BoardScene scene) => _editBoardSizes(scene.board);

  /// The same, from a dialog that stays open while the board changes under
  /// it: the board is read afresh rather than taken from the scene it was
  /// opened on.
  Future<void> _editSizesNow() async {
    final board = await ref
        .read(boardRepositoryProvider)
        .getBoard(widget.project.id);
    if (board == null || !mounted) return;
    await _editBoardSizes(board);
  }

  Future<void> _editBoardSizes(Board board) async {
    final result = await showTrackSizesDialog(
      context,
      widths: board.trackWidths,
      viaSizes: board.viaSizes,
    );
    if (result == null || !mounted) return;

    final repository = ref.read(boardRepositoryProvider);
    final before = board;
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
    final radius = await showPresetValueSheet(
      context,
      kind: cornerRadii,
      projectId: widget.project.id,
      current: _curveRadius,
    );
    if (radius == null || !mounted) return;
    setState(() => _curveRadius = radius);
  }

  Future<void> _chooseGrid() async {
    final grid = await showPresetValueSheet(
      context,
      kind: boardGrids,
      projectId: widget.project.id,
      // Zero is free placement, which is what the sheet shows it as.
      current: _snap ? _grid : 0,
    );
    if (grid == null || !mounted) return;
    setState(() {
      _snap = grid > 0;
      if (grid > 0) _grid = grid;
    });
  }

  CopperLayer _layerFor(PlacedPad pad) {
    final active = ref.read(activeLayerProvider);
    if (pad.reaches(active)) return active;
    return pad.layers.contains(BoardLayer.backCopper)
        ? CopperLayer.back
        : CopperLayer.front;
  }

  // --- the rest --------------------------------------------------------

  void _showMore(BoardScene scene, List<PartWithDetails> parts) {
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
                  Icons.inventory_2_outlined,
                  'Parts and footprints',
                  () => _showParts(scene, parts),
                  subtitle: () {
                    final waiting = _waiting(scene, parts).length;
                    return waiting == 0
                        ? 'All placed — change a footprint here'
                        : '$waiting still to place';
                  }(),
                ),
                item(
                  Icons.crop_square,
                  'Board outline',
                  () => _chooseShape(scene),
                  subtitle: scene.outline.kind.label,
                ),
                item(
                  Icons.straighten,
                  'Track sizes and net classes',
                  () => showNetClassesDialog(
                    context,
                    projectId: widget.project.id,
                    rules: scene.board.rules,
                    stackup: scene.board.stackup,
                    onEditSizes: _editSizesNow,
                  ),
                  subtitle: [
                    '${scene.board.availableTrackWidths.length} widths',
                    '${scene.board.availableViaSizes.length} vias',
                    if (scene.netClasses.isEmpty)
                      'no classes'
                    else
                      for (final c in scene.netClasses) c.name,
                  ].join(' · '),
                ),
                item(
                  Icons.sync,
                  'Update from schematic',
                  _syncFromSchematic,
                  subtitle: () {
                    final plan = ref
                        .read(boardSyncPlanProvider(widget.project.id))
                        .value;
                    if (plan == null) return 'Compare with the schematic';
                    return plan.hasWork
                        ? '${plan.actionCount + (plan.orphanTracks > 0 ? 1 : 0)} changes waiting'
                        : 'Up to date';
                  }(),
                ),
                item(
                  Icons.layers_outlined,
                  'Board build',
                  () => _editBuild(scene),
                  subtitle:
                      '${scene.board.copperLayerCount} layers · '
                      '${_mm(scene.board.stackup.thickness)} mm · '
                      '${scene.board.stackup.copper.first.weight.label} copper',
                ),
                item(
                  Icons.speed,
                  'Impedance calculator',
                  () => _impedance(scene),
                  subtitle: 'Width for 50 Ω, 90 Ω pairs, delay per mm',
                ),
                item(
                  Icons.straighten,
                  'Net lengths',
                  () => showNetLengthsDialog(context, scene: scene),
                  subtitle: netLengthsSummary(scene),
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
                  'Fabrication preview',
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

  Future<void> _footprintProperties(
    BoardScene scene,
    PlacedFootprint footprint,
  ) async {
    final result = await showFootprintProperties(
      context,
      placement: footprint.ref,
      reference: footprint.part.reference,
      value: footprint.part.value,
      board: scene.outline.bounds,
      // In the part's own frame: the dialog turns it with the rotation.
      localCentre: footprint.definition == null
          ? Offset.zero
          : footprintBounds(footprint.definition!).center,
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
      nets: _netChoices(),
      layers: scene.board.copperLayers,
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

  /// Puts every track and via in the swept area on one net.
  ///
  /// The reason this is worth a button rather than a dialog per via: a
  /// grid of vias stitched into the exposed pad under a regulator is there
  /// to move heat, and there may be twenty of them. They have to read as
  /// ground or the pour clears round every one, and nobody is opening
  /// twenty dialogs.
  Future<void> _setSelectionNet(BoardScene scene) async {
    final nets = ref.read(projectNetsProvider(widget.project.id)).value ?? [];
    if (nets.isEmpty) {
      _notify('This project has no nets to put copper on');
      return;
    }
    final chosen = await _chooseNet(nets, title: 'Put this copper on');
    if (!mounted) return;

    final tracks = [
      for (final track in scene.tracks)
        if (_selected.trackIds.contains(track.id)) track,
    ];
    final vias = [
      for (final via in scene.vias)
        if (_selected.viaIds.contains(via.id)) via,
    ];
    if (tracks.isEmpty && vias.isEmpty) return;

    final repository = ref.read(boardRepositoryProvider);
    Future<void> apply(Iterable<Track> t, Iterable<Via> v) async {
      for (final track in t) {
        await repository.updateTrack(track);
      }
      for (final via in v) {
        await repository.updateVia(via);
      }
    }

    final netId = chosen?.net.id;
    await apply(
      [for (final track in tracks) track.withNet(netId)],
      [for (final via in vias) via.withNet(netId)],
    );
    if (!mounted) return;
    _record(
      'Net of ${tracks.length + vias.length} pieces of copper',
      undo: () => apply(tracks, vias),
      redo: () => apply(
        [for (final track in tracks) track.withNet(netId)],
        [for (final via in vias) via.withNet(netId)],
      ),
    );
    _notify(
      '${tracks.length + vias.length} on ${chosen?.displayName ?? 'no net'}',
    );
  }

  Future<void> _viaProperties(BoardScene scene, Via via) async {
    final result = await showViaProperties(
      context,
      via: via,
      netName: _netName(scene, via.netId) ?? '',
      board: scene.board,
      nets: _netChoices(),
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
    final tracks = (await repository.getTracks(
      widget.project.id,
    )).where((t) => t.netId == netId).toList();
    final vias = (await repository.getVias(
      widget.project.id,
    )).where((v) => v.netId == netId).toList();
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
      layers: [for (final l in scene.board.copperLayers) l.layer],
      zone: zone,
    );
    if (result == null || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);

    switch (result) {
      case ZoneDeleted():
        await _deleteZone(zone);
      case final ZoneSaved saved:
        final after = saved.applyTo(zone);
        await repository.updateZone(after);
        _record(
          'Edit a pour',
          undo: () => repository.updateZone(zone),
          redo: () => repository.updateZone(after),
        );
    }
  }

  /// The chip that holds something still, and lets it go again.
  ///
  /// Locking exists because layout is done in passes: the connector that
  /// has to line up with a hole in a case, the run that was tuned to the
  /// picosecond, the pour that took four goes to get right. All of them
  /// have to survive the next hour of nudging everything else around them,
  /// and the way they survive is by refusing to move.
  Widget _lockChip({
    required String key,
    required bool locked,
    required VoidCallback onPressed,
  }) => _Chip(
    key: ValueKey(key),
    icon: locked ? Icons.lock : Icons.lock_open,
    label: locked ? 'Unlock' : 'Lock',
    onPressed: onPressed,
  );

  Future<void> _lockTrack(Track track, bool locked) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.updateTrack(track.copyWith(locked: locked));
    _record(
      locked ? 'Lock a track' : 'Unlock a track',
      undo: () => repository.updateTrack(track),
      redo: () => repository.updateTrack(track.copyWith(locked: locked)),
    );
  }

  Future<void> _lockVia(Via via, bool locked) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.updateVia(via.copyWith(locked: locked));
    _record(
      locked ? 'Lock a via' : 'Unlock a via',
      undo: () => repository.updateVia(via),
      redo: () => repository.updateVia(via.copyWith(locked: locked)),
    );
  }

  Future<void> _lockZone(BoardZone zone, bool locked) async {
    final repository = ref.read(boardRepositoryProvider);
    await repository.updateZone(zone.copyWith(locked: locked));
    _record(
      locked ? 'Lock a pour' : 'Unlock a pour',
      undo: () => repository.updateZone(zone),
      redo: () => repository.updateZone(zone.copyWith(locked: locked)),
    );
  }

  Future<void> _lockPart(PlacedFootprint footprint, bool locked) async {
    final repository = ref.read(boardRepositoryProvider);
    final before = footprint.ref;
    await repository.updatePlacement(before.copyWith(locked: locked));
    _record(
      locked ? 'Lock ${footprint.part.reference}' : 'Unlock',
      undo: () => repository.updatePlacement(before),
      redo: () => repository.updatePlacement(before.copyWith(locked: locked)),
    );
  }

  /// Whether every piece of copper on [netId] is held.
  bool _netLocked(BoardScene scene, String netId) {
    final copper = [
      for (final t in scene.tracks)
        if (t.netId == netId) t.locked,
      for (final v in scene.vias)
        if (v.netId == netId) v.locked,
    ];
    return copper.isNotEmpty && copper.every((l) => l);
  }

  /// Holds, or frees, every track and via on one net at once.
  ///
  /// A net is the unit anyone thinks in: nobody locks the fourth segment
  /// of a clock line, they lock the clock line.
  Future<void> _lockNet(BoardScene scene, String netId) async {
    final locked = !_netLocked(scene, netId);
    final tracks = [
      for (final t in scene.tracks)
        if (t.netId == netId) t,
    ];
    final vias = [
      for (final v in scene.vias)
        if (v.netId == netId) v,
    ];
    if (tracks.isEmpty && vias.isEmpty) return;

    final repository = ref.read(boardRepositoryProvider);
    Future<void> apply(bool held) async {
      for (final track in tracks) {
        await repository.updateTrack(track.copyWith(locked: held));
      }
      for (final via in vias) {
        await repository.updateVia(via.copyWith(locked: held));
      }
    }

    await apply(locked);
    if (!mounted) return;
    final name = _netName(scene, netId) ?? 'net';
    _notify(
      '$name ${locked ? 'held' : 'free'}: '
      '${tracks.length + vias.length} pieces of copper',
    );
    _record(
      locked ? 'Lock $name' : 'Unlock $name',
      undo: () async {
        for (final track in tracks) {
          await repository.updateTrack(track);
        }
        for (final via in vias) {
          await repository.updateVia(via);
        }
      },
      redo: () => apply(locked),
    );
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

  /// Takes the outline away, so a new one can be drawn with the Edge cut
  /// tool. The area it covered stays as the working area.
  Future<void> _deleteOutline(BoardScene scene) async {
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.withOutline(BoardOutline.none(scene.outline.bounds));
    await repository.updateBoard(after);
    if (!mounted) return;
    setState(() => _outlineSelected = false);
    _record(
      'Delete the board outline',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
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

  /// `Z₀ 50.2 Ω` for a track of [width] on [layer], from the build.
  String _impedanceLabel(BoardScene scene, CopperLayer layer, double width) {
    if (!scene.board.hasLayer(layer) || width <= 0) return '';
    final line = ImpedanceCalculator.of(
      scene.board.stackup,
      layer,
      width: width,
    );
    return 'Z₀ ${line.z0.toStringAsFixed(1)} Ω';
  }

  Future<void> _syncFromSchematic() async {
    final message = await showBoardSyncDialog(
      context,
      projectId: widget.project.id,
    );
    if (message != null) _notify(message);
  }

  Future<void> _editBuild(BoardScene scene) async {
    final used = {
      for (final t in scene.tracks) t.layer,
      for (final z in scene.zones) ?CopperLayer.fromToken(z.layer.token),
    };
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
    _notify(
      '${after.copperLayerCount} layers, '
      '${_mm(after.stackup.thickness)} mm',
    );
  }

  Future<void> _impedance(BoardScene scene) async {
    final width = await showImpedanceCalculator(
      context,
      board: scene.board,
      layer: ref.read(activeLayerProvider),
      width: _widthFor(scene),
    );
    if (width == null || !mounted) return;
    setState(() => _trackWidth = width);
    _notify('Routing at ${_mm(width)} mm');
  }

  /// Folds the selected segment into loops until its net is long enough.
  Future<void> _tune(BoardScene scene, Track track) async {
    if (track.netId == null) {
      _notify('This track is on no net — nothing to match it to');
      return;
    }
    final plan = await showMeanderDialog(
      context,
      scene: scene,
      track: track,
      netName: _netName(scene, track.netId) ?? '',
    );
    if (plan == null || !plan.isValid || !mounted) return;
    final repository = ref.read(boardRepositoryProvider);
    await repository.deleteTracks([track.id]);
    final ids = <String>[];
    for (var i = 0; i < plan.points.length - 1; i++) {
      ids.add(
        await repository.addTrack(
          projectId: widget.project.id,
          layer: track.layer,
          startX: plan.points[i].dx,
          startY: plan.points[i].dy,
          endX: plan.points[i + 1].dx,
          endY: plan.points[i + 1].dy,
          width: track.width,
          netId: track.netId,
        ),
      );
    }
    final added = await repository.getTracks(widget.project.id);
    final laid = [
      for (final t in added)
        if (ids.contains(t.id)) t,
    ];
    if (mounted) setState(() => _selectedTrackId = null);
    _record(
      'Tune ${_netName(scene, track.netId) ?? 'track'}',
      undo: () async {
        await repository.deleteTracks(ids);
        await repository.restoreCopper(tracks: [track], vias: const []);
      },
      redo: () async {
        await repository.deleteTracks([track.id]);
        await repository.restoreCopper(tracks: laid, vias: const []);
      },
    );
    _notify(
      '+${_mm(plan.added)} mm in ${plan.loops} loop'
      '${plan.loops == 1 ? '' : 's'}',
    );
  }

  /// The board house this project is being made by, if one is chosen.
  FabPreset? get _fabPreset => FabPresets.byId(
    ref
        .read(projectSettingsProvider(widget.project.id))
        .value?[FabPresets.settingsKey],
  );

  Future<void> _editRules(BoardScene scene) async {
    final result = await showDesignRulesDialog(
      context,
      board: scene.board,
      fabPreset: _fabPreset,
    );
    if (result == null || !mounted) return;
    await ref.read(projectSettingsRepositoryProvider).setAll(
      widget.project.id,
      {FabPresets.settingsKey: result.fabPreset?.id},
    );
    final repository = ref.read(boardRepositoryProvider);
    final before = scene.board;
    final after = before.copyWith(
      rules: result.rules,
      gridMm: result.gridMm,
      teardrops: result.teardrops,
    );
    await repository.updateBoard(after);
    if (mounted) setState(() => _grid = result.gridMm);
    _record(
      'Design rules',
      undo: () => repository.updateBoard(before),
      redo: () => repository.updateBoard(after),
    );
  }

  void _runDrc(BoardScene scene) => showDrcSheet(
    context,
    violations: checkBoard(scene, fab: _fabPreset),
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

  /// Every net on the project, for putting a stray piece of copper on one
  /// by hand.
  List<NetChoice> _netChoices() => [
    for (final net
        in ref.read(projectNetsProvider(widget.project.id)).value ??
            const <NetWithEndpoints>[])
      (id: net.net.id, name: net.displayName),
  ];

  String? _netName(BoardScene scene, String? netId) {
    if (netId == null) return null;
    for (final pad in scene.pads) {
      if (pad.netId == netId) return pad.netName;
    }
    return null;
  }

  Future<void> _undo() async {
    await _stepHistory(backward: true);
    if (mounted) setState(_clearSelection);
  }

  /// Takes a step through the undo history, saying so if it cannot.
  ///
  /// A step that fails has been dropped from the history, and the design
  /// is as it was before the tap: the step ran in one transaction.
  Future<void> _stepHistory({required bool backward}) async {
    final history = ref.read(editHistoryProvider.notifier);
    try {
      await (backward ? history.undo() : history.redo());
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'undo'),
      );
      _notify(backward ? 'That edit could not be undone' : 'Could not redo');
    }
  }

  Future<void> _redo() async {
    await _stepHistory(backward: false);
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
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.hasMenu = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  /// Whether tapping this chip while it is already the tool in hand opens
  /// a menu of what else it can lay down. The caret is only shown once it
  /// is selected, because that is the only time the tap does that.
  final bool hasMenu;

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
                icon,
                size: 16,
                color: selected
                    ? KicadPalette.highlight
                    : KicadPalette.textSecondary,
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: KicadPalette.highlight, fontSize: 12),
                ),
                if (hasMenu)
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: KicadPalette.highlight,
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
    super.key,
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
    super.key,
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

/// A small red plus at the middle of the board.
class _CentreMarkPainter extends CustomPainter {
  _CentreMarkPainter(this.at);

  final Offset at;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 9.0;
    final paint = Paint()
      ..color = const Color(0xFFFF4D4D)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(at - const Offset(arm, 0), at + const Offset(arm, 0), paint)
      ..drawLine(at - const Offset(0, arm), at + const Offset(0, arm), paint);
  }

  @override
  bool shouldRepaint(_CentreMarkPainter old) => old.at != at;
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
    // Anything held is left out of the sweep entirely, rather than caught
    // and then quietly refusing to move. A box that grabs a locked
    // connector and moves everything else is worse than one that never
    // grabbed it.
    return _Selection(
      footprintIds: {
        for (final footprint in scene.footprints)
          if (!footprint.ref.locked &&
              rect.contains(Offset(footprint.ref.x, footprint.ref.y)))
            footprint.ref.id,
      },
      trackIds: {
        for (final track in scene.tracks)
          if (!track.locked &&
              rect.contains(Offset(track.startX, track.startY)) &&
              rect.contains(Offset(track.endX, track.endY)))
            track.id,
      },
      viaIds: {
        for (final via in scene.vias)
          if (!via.locked && rect.contains(Offset(via.x, via.y))) via.id,
      },
      edgeIds: {
        for (final edge in scene.edges)
          if (edge.isValid && edge.points.every(rect.contains)) edge.id,
      },
      zoneIds: {
        for (final zone in scene.zones)
          if (!zone.locked && zone.isValid && zone.points.every(rect.contains))
            zone.id,
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

/// The laid-out original a replicate copies from.
class _ReplicaSource {
  const _ReplicaSource({
    required this.placements,
    required this.tracks,
    required this.vias,
    required this.offset,
  });

  final List<PlacedFootprintRef> placements;
  final List<Track> tracks;
  final List<Via> vias;

  /// Where each copy first appears, relative to the original.
  final Offset offset;
}
