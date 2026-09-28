import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/cross_probe.dart';
import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../data/repositories/circuit_paster.dart';
import '../../data/repositories/part_repository.dart';
import '../../data/repositories/saved_circuit_repository.dart';
import '../../data/repositories/sheet_wires.dart';
import '../../domain/geometry/drawn_wire_geometry.dart';
import '../../domain/geometry/polyline_wiring.dart';
import '../../domain/geometry/segment_wiring.dart';
import '../../domain/symbols/mcu_essentials.dart';
import '../../domain/erc/erc.dart';
import 'bulk_edit_dialog.dart';
import 'cross_probe_view.dart';
import 'pin_labels_dialog.dart';
import 'note_dialog.dart';
import 'erc_sheet.dart';
import 'starter_circuit.dart';
import 'swap_dialog.dart';
import 'starter_circuit_dialog.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../core/widgets/zoom_controls.dart';
import '../../data/repositories/net_repository.dart';
import '../../domain/models/models.dart';
import '../../rendering/schematic_painter.dart';
import '../../rendering/schematic_scene.dart';
import '../../domain/geometry/placement.dart';
import '../../domain/geometry/placement_finder.dart';
import '../../rendering/schematic_viewport.dart';
import '../../rendering/sheet_overlays.dart';
import '../pinout/pinout_explorer.dart';
import 'nets_panel.dart';
import '../../domain/symbols/symbols.dart';
import 'component_sidebar.dart';
import 'attach_power.dart';
import 'part_editor_dialog.dart';
import 'canvas_action_bar.dart';

/// The schematic canvas: pan, zoom, move symbols, and connect pins.
///
/// The same tap-to-connect gesture as the net list, on the same shared
/// pending-pin state, so switching between the two views mid-connection
/// keeps its place.
class SchematicPanel extends ConsumerStatefulWidget {
  const SchematicPanel({super.key, required this.project, this.onShowBoard});

  final Project project;

  /// Goes to the board, from the cross-probing live view.
  final VoidCallback? onShowBoard;

  @override
  ConsumerState<SchematicPanel> createState() => _SchematicPanelState();
}

class _SchematicPanelState extends ConsumerState<SchematicPanel> {
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
  String? _selectedUnitId;
  String? _highlightedNetId;

  /// The wire the user has hold of. Wires are objects you can select, the
  /// same as symbols — without that there is no way to tell whether the app
  /// noticed you touching one.
  String? _selectedWireKey;

  /// Which run of that wire is picked: the one that was tapped or dragged.
  /// Commands apply to it rather than to the whole net, the way a segment
  /// is its own thing in KiCad.
  int? _selectedWireRun;

  /// The net whose label is selected, so it can be renamed or sent back to
  /// its default spot without hunting for the wire underneath it.
  String? _selectedLabelNetId;

  /// Where the user last tapped, so a paste lands where they were looking.
  Offset? _lastTapSheet;

  /// The canvas's last laid-out size and scene, so a new part can be put
  /// somewhere on screen rather than wherever the sheet has room.
  Size _canvasSize = Size.zero;
  SchematicScene? _scene;

  // Drag state for moving a symbol. Which unit is under the finger is
  // decided when the gesture starts, but whether it is a drag or a tap is
  // only known once the finger has moved far enough.
  String? _candidateUnitId;
  bool _isDraggingUnit = false;

  // Where the parts being dragged have got to, held here and written once
  // when the finger lifts. Writing every frame sent each move through the
  // database and back and re-drew the sheet from that, which is what made
  // dragging a part feel sticky — worst zoomed out, with most on screen.
  Map<String, Offset>? _draggingUnits;
  Map<String, Offset> _dragOriginals = const {};

  /// How far the group being dragged has moved, which is what the wires
  /// travelling with it follow. A group can be wires alone, with no part in
  /// it to take the shift from.
  Offset _draggingShift = Offset.zero;
  bool _groupDragging = false;

  /// Drawn wires travelling with the parts being dragged: every pin they end
  /// on is on a moving part, so they move whole rather than stretch.
  List<SchematicWire> _dragWires = const [];

  /// What was selected when the edits since it began were made, and how
  /// long the undo history was before the first of them. Undo shows on a
  /// selection only once that selection has been changed.
  (String, int)? _editBase;

  /// Parts swept up together, which move and delete as one.
  Set<String> _selectedUnitIds = const {};

  /// Wires swept up with them. A box round a piece of circuit takes the
  /// wiring too — anything else would be picking the drawing apart.
  Set<String> _selectedWireIds = const {};

  /// In Select mode a drag sweeps a box instead of panning the sheet.
  bool _boxSelecting = false;
  Offset? _boxFrom;
  Offset? _boxTo;

  // The run of a wire under the finger, which slides sideways like a board
  // track when dragged, and the net it belongs to as it was drawn when the
  // finger landed.
  WireRunHit? _candidateWire;
  List<PolylineWire> _dragNet = const [];

  // Where the wire being slid has got to. Held here and written once when
  // the finger lifts, not once per frame.
  String? _draggingWireKey;
  List<Offset>? _draggingWirePoints;

  /// The wires joined to the one being dragged, stretched to stay joined to
  /// it, by their id.
  Map<String, List<Offset>> _draggingNeighbours = const {};

  // In the segment model a drag is worked out for the whole net at once:
  // the piece under the finger moves and everything sharing its ends comes
  // with it. Held here while the finger is down, written when it lifts.
  List<WireSegment>? _draggingSegments;
  String? _draggingSegmentNet;

  /// The wires last tidied into segments, so it is done once rather than
  /// every frame.
  Object? _tidiedWires;
  bool _tidying = false;

  /// The drawn wires last checked for one running through a junction.
  Object? _junctionsCheckedFor;

  /// Corners tapped out so far for the wire being drawn from the pending
  /// pin, in sheet millimetres.
  List<Offset> _wireCorners = const [];

  /// A wire being dragged out: where the finger is now, when it is.
  Offset? _wireDragAt;
  bool _wireDragging = false;

  // A new wire being pulled out of a junction on an existing net. Every
  // corner of a net is a place another wire can start, the way a junction
  // is in KiCad — the net is segments meeting at points, not one object.
  Offset? _branchFrom;
  String? _branchNetId;
  Offset? _branchTo;

  // The net label being dragged, and where it has got to. Held live for the
  // same reason as the wire offsets above: one write at the end of the
  // gesture, not one per frame.
  NetLabel? _candidateLabel;
  Offset? _draggingLabelAt;

  /// The sheet's notes, as last built.
  List<SchematicNote> _notes = const [];

  /// The note picked by a tap, and the one being dragged with where it
  /// has got to.
  String? _selectedNoteId;
  SchematicNote? _candidateNote;
  Offset? _draggingNoteAt;

  /// Sub-sheets on the open sheet, and the one picked or being dragged.
  List<SheetBoxView> _sheetBoxes = const [];
  List<OffSheetLabel> _offSheetLabels = const [];
  List<SchematicLabel> _storedLabels = const [];
  Set<String> _labelledNets = const {};
  String? _selectedSheetId;
  SchematicSheet? _candidateSheet;
  Offset? _draggingSheetAt;
  Offset _gestureStartLocal = Offset.zero;
  Offset _dragStartSheet = Offset.zero;
  Offset _dragOriginalPosition = Offset.zero;

  // Pan/zoom state.
  Offset _gestureStartFocal = Offset.zero;
  SchematicViewport? _gestureStartViewport;

  /// Wires are drawn by tapping pins and corners rather than by dragging.
  /// See [WireGesture].
  bool get _tapWiring =>
      ref.read(appearanceProvider).wireGesture == WireGesture.tap;

  /// Placing parts rather than wiring them: the parts panel is open. Pins
  /// then never start a wire, and a tap on empty sheet puts down another
  /// of the part picked last.
  bool get _placing => ref.read(componentPickerOpenProvider);

  /// The part a tap on empty sheet puts down while placing.
  SymbolIndexEntry? _stamp;

  /// How close a tap has to land, in millimetres of sheet, to count as
  /// hitting a pin. Scaled by zoom so the target stays roughly a finger
  /// wide on screen whatever the magnification.
  double _hitToleranceMm(SchematicViewport viewport) =>
      math.max(1.0, 22 / viewport.pixelsPerMm);

  /// How close a touch has to land to grab a wire.
  ///
  /// Much more generous than the pin target. A wire is a couple of pixels
  /// wide with nothing to aim at, and a fingertip covers far more than
  /// that, so a mouse-sized radius meant most attempts to grab a wire
  /// silently panned the sheet instead.
  double _wireToleranceMm(SchematicViewport viewport) =>
      math.max(1.5, 44 / viewport.pixelsPerMm);

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(sheetPartsProvider(widget.project.id));
    final netsAsync = ref.watch(projectNetsProvider(widget.project.id));
    final symbolsAsync = ref.watch(projectSymbolsProvider(widget.project.id));

    final error = partsAsync.error ?? netsAsync.error ?? symbolsAsync.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not draw the schematic',
        message: '$error',
      );
    }

    final parts = partsAsync.value;
    final nets = netsAsync.value;
    final symbols = symbolsAsync.value;
    if (parts == null || nets == null || symbols == null) {
      return const SizedBox.shrink();
    }

    final hints = _routeHints();
    final drawn =
        ref.watch(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];
    // A sheet from KiCad shows the labels it was drawn with, where they
    // were drawn, and none of the app's own for the nets they name. The
    // pieces of a net they join are joined by name, not by a wire.
    _storedLabels =
        ref.watch(sheetLabelsProvider(widget.project.id)).value ??
        const <SchematicLabel>[];
    final anchors = _labelAnchors(_storedLabels);
    var scene = _sceneFor(parts, nets, symbols, hints, drawn, anchors);

    final live = _draggingUnits;
    final carried = {for (final wire in _dragWires) wire.id};
    final moving =
        (live != null && live.isNotEmpty) ||
        (carried.isNotEmpty && _draggingShift != Offset.zero);
    if (moving) {
      final shift = _draggingShift;
      final drawnLive = carried.isEmpty
          ? drawn
          : [
              for (final wire in drawn)
                if (carried.contains(wire.id))
                  wire.copyWith(
                    points: [for (final p in wire.points) p + shift],
                  )
                else
                  wire,
            ];
      scene = SchematicScene.build(
        paper: widget.project.paper,
        parts: _withUnitsAt(parts, live ?? const {}),
        nets: nets,
        symbols: symbols,
        routeHints: hints,
        drawnWires: drawnLive,
        labelAnchors: anchors,
      );
    }

    // A segment drag is worked out for the whole net, so the sheet is drawn
    // from the pieces as they now stand rather than by nudging one wire.
    if (_draggingSegments case final segments?
        when _draggingSegmentNet != null) {
      final netId = _draggingSegmentNet!;
      var index = 0;
      scene = SchematicScene.build(
        paper: widget.project.paper,
        parts: parts,
        nets: nets,
        symbols: symbols,
        routeHints: hints,
        drawnWires: [
          for (final wire in drawn)
            if (wire.netId != netId) wire,
          for (final segment in segments)
            SchematicWire(
              id: segment.id ?? 'dragging-${index++}',
              projectId: widget.project.id,
              netId: netId,
              points: [segment.a, segment.b],
              pinAId: segment.pinA,
              pinBId: segment.pinB,
            ),
        ],
        labelAnchors: anchors,
      );
    }

    final wireKey = _draggingWireKey;
    final wirePoints = _draggingWirePoints;
    if (wireKey != null && wirePoints != null) {
      scene = scene.withWirePoints(wireKey, wirePoints);
      for (final neighbour in _draggingNeighbours.entries) {
        scene = scene.withWirePoints(neighbour.key, neighbour.value);
      }
    }

    // Wires stored in a shape the wiring rules do not expect — from an
    // older version, a KiCad file or a paste — are repaired once, when the
    // sheet first shows them. Only when the stored wires have changed:
    // every other rebuild would find nothing to do.
    if (ref.watch(appearanceProvider).wiring == WiringModel.segments) {
      if (!identical(drawn, _tidiedWires)) {
        final tidied = scene;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _tidyIntoSegments(drawn, tidied),
        );
      }
    } else if (!identical(drawn, _junctionsCheckedFor)) {
      _junctionsCheckedFor = drawn;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _splitStoredJunctions(drawn),
      );
    }

    final draggingLabel = _candidateLabel;
    final labelAt = _draggingLabelAt;
    if (draggingLabel != null && labelAt != null) {
      scene = scene.withLabelMoved(draggingLabel.netId, labelAt);
    }

    _labelledNets = {
      for (final label in _storedLabels) ?scene.netAt(label.position),
    };
    scene = scene.withoutLabelsFor(_labelledNets);

    final notes =
        ref.watch(sheetNotesProvider(widget.project.id)).value ??
        const <SchematicNote>[];
    final movingNote = _candidateNote;
    final noteAt = _draggingNoteAt;
    _notes = [
      for (final note in notes)
        if (movingNote != null && noteAt != null && note.id == movingNote.id)
          note.copyWith(position: noteAt)
        else
          note,
    ];

    _sheetViews(scene, nets);

    final pickerOpen = ref.watch(componentPickerOpenProvider);
    if (!pickerOpen) _stamp = null;

    // The empty state sits inside the Row rather than short-circuiting it,
    // so the component picker can still open on a blank sheet — which is
    // precisely when it is needed most.
    return Row(
      children: [
        Expanded(
          // An empty sheet is still the sheet: the page is drawn, with a
          // note over it, rather than replaced by a message.
          child: Stack(
            children: [
              Positioned.fill(child: _canvas(scene)),
              if (parts.isEmpty) _emptySheet(pickerOpen),
            ],
          ),
        ),
        if (pickerOpen)
          ComponentSidebar(
            projectId: widget.project.id,
            onAdd: _addFromLibrary,
            onStarter: _addStarter,
            onSavedCircuit: _insertSaved,
            onClose: () =>
                ref.read(componentPickerOpenProvider.notifier).set(false),
          ),
      ],
    );
  }

  // The last scene and what it was built from. Riverpod hands back the same
  // list object until the data behind it actually changes, so identity is
  // enough to tell whether anything has.
  SchematicScene? _cachedScene;
  Object? _cachedParts;
  Object? _cachedNets;
  Object? _cachedSymbols;
  Object? _cachedHints;
  Object? _cachedDrawn;
  Object? _cachedAnchors;
  List<SchematicLabel>? _anchorsFrom;
  List<Offset> _anchors = const [];

  List<Offset> _labelAnchors(List<SchematicLabel> labels) {
    if (!identical(labels, _anchorsFrom)) {
      _anchorsFrom = labels;
      _anchors = [for (final label in labels) label.position];
    }
    return _anchors;
  }

  /// The scene, rebuilt only when something it is drawn from has changed.
  ///
  /// Building it routes every net on the sheet, and it used to happen on
  /// every `setState` — selecting a symbol, a hint appearing, a label being
  /// dragged. None of those change a wire, and on a sheet with any size to
  /// it that work was being done dozens of times a second for nothing.
  SchematicScene _sceneFor(
    List<PartWithDetails> parts,
    List<NetWithEndpoints> nets,
    Map<String, SymbolDefinition> symbols,
    Map<String, List<double>> hints,
    List<SchematicWire> drawn,
    List<Offset> anchors,
  ) {
    final cached = _cachedScene;
    if (cached != null &&
        identical(parts, _cachedParts) &&
        identical(nets, _cachedNets) &&
        identical(symbols, _cachedSymbols) &&
        identical(hints, _cachedHints) &&
        identical(drawn, _cachedDrawn) &&
        identical(anchors, _cachedAnchors)) {
      return cached;
    }

    final scene = SchematicScene.build(
      paper: widget.project.paper,
      parts: parts,
      nets: nets,
      symbols: symbols,
      routeHints: hints,
      drawnWires: drawn,
      labelAnchors: anchors,
    );
    _cachedDrawn = drawn;
    _cachedAnchors = anchors;
    _cachedScene = scene;
    _cachedParts = parts;
    _cachedNets = nets;
    _cachedSymbols = symbols;
    _cachedHints = hints;
    return scene;
  }

  /// [parts] with the units in [positions] moved there.
  static List<PartWithDetails> _withUnitsAt(
    List<PartWithDetails> parts,
    Map<String, Offset> positions,
  ) => [
    for (final part in parts)
      if (part.units.any((u) => positions.containsKey(u.id)))
        PartWithDetails(
          part: part.part,
          units: [
            for (final unit in part.units)
              if (positions[unit.id] case final at?)
                unit.copyWith(x: at.dx, y: at.dy, placed: true)
              else
                unit,
          ],
          pins: part.pins,
        )
      else
        part,
  ];

  /// Stored adjustments to automatic routes, from before wires were drawn.
  Map<String, List<double>> _routeHints() =>
      ref.watch(routeHintsProvider(widget.project.id)).value ?? const {};

  Widget _emptySheet(bool pickerOpen) => Positioned(
    top: 12,
    left: 12,
    right: 12,
    child: Center(
      child: Material(
        color: KicadPalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nothing on the sheet yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      pickerOpen
                          ? 'Pick a component from the list to place it here.'
                          : 'Add your first part to get started.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!pickerOpen) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(componentPickerOpenProvider.notifier).set(true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD COMPONENT'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  /// Adds [entry] to the project, landing it where the user last tapped.
  ///
  /// A ground or supply picked while a pin is held goes on that pin, facing
  /// away from it, already joined.
  Future<void> _addFromLibrary(SymbolIndexEntry entry) async {
    if (entry.isPower) {
      final pendingId = ref.read(pendingPinProvider);
      final pin = _scene?.pins.where((p) => p.id == pendingId).firstOrNull;
      if (pin != null) {
        await _attachPower(pin, entry);
        return;
      }
    }
    final symbol = await ref
        .read(symbolLibraryRepositoryProvider)
        .loadSymbol(entry.libId);
    if (symbol == null) {
      _notify('${entry.libId} could not be read');
      return;
    }
    final added = await ref
        .read(partRepositoryProvider)
        .pastePart(
          widget.project.id,
          symbol.toNewPartSpec(),
          at: _spotInView(symbol),
        );
    if (!mounted) return;
    if (_placing && _stamp?.libId != entry.libId) {
      _stamp = entry;
      _notify('Tap the sheet to place another ${entry.name}');
    }
    setState(() => _selectedUnitId = added.units.first.id);
    await _recordAddition(added.part.id, 'Add ${added.part.reference}');
  }

  /// Adds a microcontroller with what it needs to run round it: decoupling,
  /// crystal, reset and boot buttons, after showing what was found.
  Future<void> _addStarter(SymbolIndexEntry entry) async {
    // The search is done with: without this, closing the dialog hands focus
    // back to the search box and the keyboard comes up over the new circuit.
    FocusManager.instance.primaryFocus?.unfocus();
    final libraries = ref.read(symbolLibraryRepositoryProvider);
    final symbol = await libraries.loadSymbol(entry.libId);
    if (symbol == null) {
      _notify('${entry.libId} could not be read');
      return;
    }
    final power = await _powerSymbols();
    if (!mounted) return;
    bool isGround(SymbolIndexEntry e) => e.name.toUpperCase().startsWith('GND');

    final chosen = await showStarterCircuitDialog(
      context,
      mcuName: entry.name,
      essentials: McuEssentials.ofSymbol(symbol),
      supplies: power.where((e) => !isGround(e)).toList(),
      crystalValue: _crystalFor(entry.name),
    );
    if (chosen == null || !mounted) return;

    final ground =
        power.where((e) => e.name.toUpperCase() == 'GND').firstOrNull ??
        power.where(isGround).firstOrNull;
    final repository = ref.read(partRepositoryProvider);
    final result = await buildStarterCircuit(
      parts: repository,
      nets: ref.read(netRepositoryProvider),
      libraries: libraries,
      projectId: widget.project.id,
      mcuSymbol: symbol,
      at: _spotInView(symbol) ?? const Offset(100, 80),
      options: StarterOptions(
        supplyLibId: chosen.supplyLibId,
        groundLibId: ground?.libId ?? chosen.groundLibId,
        decoupling: chosen.decoupling,
        crystal: chosen.crystal,
        reset: chosen.reset,
        boot: chosen.boot,
        crystalValue: chosen.crystalValue,
      ),
    );

    final snapshots = <PartSnapshot>[];
    for (final id in result.partIds) {
      final snapshot = await repository.capturePart(id);
      if (snapshot != null) snapshots.add(snapshot);
    }
    if (!mounted) return;
    ref.read(componentPickerOpenProvider.notifier).set(false);
    setState(() => _selectedUnitId = null);
    _record(
      '${result.mcu.part.reference} starter circuit',
      undo: () async {
        for (final id in result.partIds) {
          await repository.deletePart(id);
        }
      },
      redo: () async {
        for (final snapshot in snapshots) {
          await repository.restorePart(snapshot);
        }
      },
    );
    _notify(
      result.skipped.isEmpty
          ? '${result.mcu.part.reference} added with '
                '${result.partIds.length - 1} parts round it'
          : 'Skipped: ${result.skipped.join('; ')}',
    );
  }

  /// The crystal each family is usually run from, as a starting value.
  static String _crystalFor(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('RP2040') || upper.contains('RP2350')) return '12MHz';
    if (upper.contains('ESP32')) return '40MHz';
    if (upper.contains('ATMEGA') || upper.contains('ATTINY')) return '16MHz';
    return '8MHz';
  }

  /// Where a newly added symbol should go: on screen, and clear of
  /// everything already there.
  ///
  /// New parts used to be dealt into a fixed grid from the sheet's corner,
  /// 38 mm apart, which put the second one off the edge of the screen — it
  /// was added, and there was no sign of it. The nearest free spot to where
  /// the user last tapped, or to the middle of the view, is always
  /// somewhere they can see.
  Offset? _spotInView(SymbolDefinition? symbol) {
    final viewport = _viewport;
    final scene = _scene;
    final size = _canvasSize;
    if (viewport == null || scene == null || size.isEmpty) {
      return _lastTapSheet;
    }

    // The canvas less the action bar along the bottom, which sits over the
    // drawing.
    final visible = Rect.fromPoints(
      viewport.toSheet(const Offset(0, 8)),
      viewport.toSheet(Offset(size.width, size.height - 80)),
    ).deflate(2.54);

    final extent = _extentOf(symbol);
    final tapped = _lastTapSheet;
    final near = tapped != null && visible.contains(tapped)
        ? tapped
        : visible.center;

    final spot = PlacementFinder.findSpotIn(
      region: visible,
      footprint: extent,
      near: near,
      occupied: [for (final unit in scene.units) scene.boundsOf(unit)],
      gridMm: 2.54,
      margin: 2.54,
    );
    final chosen = spot ?? near;
    // On KiCad's 1.27 mm grid, or the pins of the new part sit between the
    // grid points every wire is routed along.
    return Offset(
      (chosen.dx / 1.27).round() * 1.27,
      (chosen.dy / 1.27).round() * 1.27,
    );
  }

  /// A symbol's extent on the sheet around its own origin.
  static Rect _extentOf(SymbolDefinition? symbol) {
    if (symbol == null) {
      return Rect.fromCenter(center: Offset.zero, width: 10, height: 10);
    }
    final local = symbolBounds(symbol, 1);
    if (local == Rect.zero) {
      return Rect.fromCenter(center: Offset.zero, width: 10, height: 10);
    }
    const origin = Placement(x: 0, y: 0);
    return Rect.fromPoints(
      origin.apply(local.left, local.top),
      origin.apply(local.right, local.bottom),
    );
  }

  Widget _canvas(SchematicScene scene) {
    _scene = scene;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _canvasSize = size;
        final viewport = _viewport ??= _fitToContent(scene, size);
        final colors = Theme.of(context).schematic;

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
                  onLongPressStart: (details) =>
                      _onLongPress(scene, viewport, details.localPosition),
                  onScaleStart: (details) =>
                      _onScaleStart(scene, viewport, details),
                  onScaleUpdate: (details) => _onScaleUpdate(scene, details),
                  onScaleEnd: (_) => _onScaleEnd(),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: SchematicPainter(
                        scene: scene,
                        viewport: viewport,
                        colors: colors,
                        selectedUnitId: _selectedUnitId,
                        selectedUnitIds: _selectedUnitIds,
                        selectedWireIds: _selectedWireIds,
                        selectionBox: _boxFrom != null && _boxTo != null
                            ? Rect.fromPoints(_boxFrom!, _boxTo!)
                            : null,
                        selectedWireKey: _selectedWireKey,
                        selectedWireRun: _selectedWireRun,
                        pendingPinId: ref.watch(pendingPinProvider),
                        pendingWire: _pendingWire(scene),
                        highlightedNetId: _highlightedNetId,
                        notes: _notes,
                        selectedNoteId: _selectedNoteId,
                        sheetBoxes: _sheetBoxes,
                        selectedSheetId: _selectedSheetId,
                        offSheetLabels: _offSheetLabels,
                        storedLabels: _storedLabels,
                        zigzagResistors:
                            ref.watch(appearanceProvider).resistorStyle ==
                            ResistorStyle.ansi,
                      ),
                      size: size,
                    ),
                  ),
                ),
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
                  child: _actionBar(scene),
                ),
              ),
            ),
            if (_sheetPath() case final path?)
              Positioned(top: 8, left: 8, right: 200, child: path),
            if (ref.watch(crossProbeOnProvider))
              Positioned(
                top: 10,
                right: 10,
                child: MiniBoardView(
                  projectId: widget.project.id,
                  focus: _probeFocus(scene),
                  onOpen: widget.onShowBoard,
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: ZoomControls(
                fitTooltip: 'Fit to sheet',
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

  /// What the board live view follows: the part selected, or the net of
  /// the wire, label or pin selected.
  ProbeFocus _probeFocus(SchematicScene scene) {
    final unitId =
        _selectedUnitId ??
        (_selectedUnitIds.length == 1 ? _selectedUnitIds.first : null);
    final unit = scene.units.where((u) => u.unit.id == unitId).firstOrNull;
    final pendingPin = ref.watch(pendingPinProvider);
    final pin = scene.pins.where((p) => p.id == pendingPin).firstOrNull;
    final wireNet = scene.wires
        .where((w) => w.key == _selectedWireKey)
        .firstOrNull
        ?.netId;
    return ProbeFocus(
      partId: unit?.part.id ?? pin?.partId,
      netId: wireNet ?? _selectedLabelNetId ?? pin?.netId ?? _highlightedNetId,
    );
  }

  /// A long press on a part starts picking parts one by one: that part is
  /// the first, and every tap after adds or takes one away. A box sweeps
  /// up whatever is inside it; this picks just what is wanted — the three
  /// resistors to give one value, not the ground symbol between them.
  void _onLongPress(
    SchematicScene scene,
    SchematicViewport viewport,
    Offset local,
  ) {
    if (_isDraggingUnit) return;
    final sheet = viewport.toSheet(local);
    final unit = scene.unitAt(sheet);
    if (unit == null) return;
    HapticFeedback.mediumImpact();
    ref.read(pendingPinProvider.notifier).set(null);
    setState(() {
      _selectedUnitId = null;
      _selectedWireKey = null;
      _selectedWireRun = null;
      _selectedLabelNetId = null;
      _selectedNoteId = null;
      _selectedUnitIds = {..._selectedUnitIds, unit.unit.id};
    });
    _notify('Tap more parts to add them — tap empty sheet when done');
  }

  /// `2 parts · 1 wire selected`, and the sensible variants of it.
  static String _selectionTitle(int parts, int wires) {
    final bits = [
      if (parts > 0) '$parts ${parts == 1 ? "part" : "parts"}',
      if (wires > 0) '$wires ${wires == 1 ? "wire" : "wires"}',
    ];
    return '${bits.join(' · ')} selected';
  }

  /// Which selection is current, as one comparable key; null when nothing is.
  String? get _selectionKey {
    if (_selectedUnitIds.isNotEmpty) {
      return 'group:${(_selectedUnitIds.toList()..sort()).join(',')}';
    }
    if (_selectedUnitId case final id?) return 'unit:$id';
    if (_selectedWireKey case final key?) return 'wire:$key';
    if (_selectedLabelNetId case final id?) return 'label:$id';
    if (_selectedNoteId case final id?) return 'note:$id';
    if (ref.read(pendingPinProvider) case final id?) return 'pin:$id';
    return null;
  }

  /// The canvas commands.
  ///
  /// With nothing selected: undo, redo, the check, box select and paste —
  /// the commands about the whole sheet. With something selected, only what
  /// applies to it; undo joins them once that selection has been changed,
  /// so a move or a turn can be taken straight back, and redo stays with
  /// the sheet, where it is found by letting go.
  Widget _actionBar(SchematicScene scene) {
    final history = ref.watch(editHistoryProvider);
    final pendingPinId = ref.watch(pendingPinProvider);
    final clipboard = ref.watch(circuitClipboardProvider);

    final key = _selectionKey;
    final base = _editBase;
    final editedHere =
        key != null &&
        base != null &&
        base.$1 == key &&
        history.past.length > base.$2;
    final undoHere = CanvasAction(
      label: 'Undo',
      icon: Icons.undo,
      onPressed: _undo,
    );

    final group = scene.units
        .where((u) => _selectedUnitIds.contains(u.unit.id))
        .toList();
    final wires = _selectedWireIds.length;
    if (group.isNotEmpty || wires > 0) {
      return CanvasActionBar(
        title: _hint ?? _selectionTitle(group.length, wires),
        hinting: _hint != null,
        actions: [
          if (editedHere) undoHere,
          CanvasAction(
            label: 'Rotate',
            icon: Icons.rotate_90_degrees_ccw_outlined,
            onPressed: () => _rotateGroup(scene, group),
          ),
          CanvasAction(
            label: 'Edit',
            icon: Icons.edit_note,
            onPressed: _fittedParts(group).isEmpty
                ? null
                : () => _bulkEdit(group),
          ),
          CanvasAction(
            label:
                _fittedParts(group).isNotEmpty &&
                    _fittedParts(group).every((p) => p.dnp)
                ? 'Fit'
                : 'DNP',
            icon: Icons.do_not_disturb_on_outlined,
            onPressed: _fittedParts(group).isEmpty
                ? null
                : () => _toggleDnp(group),
          ),
          CanvasAction(
            label: 'Copy',
            icon: Icons.content_copy,
            // A copy is of parts and their wiring: wires on their own have
            // nothing to be wired to once they are put down.
            onPressed: group.isEmpty ? null : () => _copyGroup(scene, group),
          ),
          CanvasAction(
            label: 'Sheet',
            icon: Icons.layers_outlined,
            // To another page of the schematic, or a new one.
            onPressed: group.isEmpty ? null : () => _moveToSheet(group),
          ),
          CanvasAction(
            label: 'Save',
            icon: Icons.bookmark_add_outlined,
            // Saved to use again in any project, from the component list.
            onPressed: group.isEmpty ? null : () => _saveCircuit(scene, group),
          ),
          CanvasAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteSelection(scene, group),
          ),
        ],
      );
    }
    if (_boxSelecting) {
      return CanvasActionBar(
        title: _hint ?? 'Drag a box round parts',
        hinting: true,
        actions: [
          CanvasAction(
            label: 'Done',
            icon: Icons.check,
            onPressed: _toggleBoxSelect,
          ),
        ],
      );
    }

    var title = '';
    final actions = <CanvasAction>[];

    if (pendingPinId != null) {
      final pin = scene.pins.where((p) => p.id == pendingPinId).firstOrNull;
      if (pin != null) {
        title = pin.label;
        actions.addAll(_pinActions(pin));
      }
    } else {
      final unit = scene.units
          .where((u) => u.unit.id == _selectedUnitId)
          .firstOrNull;
      final wire = scene.wires
          .where((w) => w.key == _selectedWireKey)
          .firstOrNull;
      final label = scene.labels
          .where((l) => l.netId == _selectedLabelNetId)
          .firstOrNull;

      if (label != null) {
        final net = scene.nets
            .where((n) => n.net.id == label.netId)
            .firstOrNull;
        title = '${label.text} label';
        actions.addAll(_labelActions(label, net));
      } else if (unit != null) {
        title = unit.part.isMultiUnit
            ? '${unit.part.reference} · unit ${unit.unit.unitNumber}'
            : unit.part.reference;
        actions.addAll(_unitActions(unit));
      } else if (wire != null) {
        final net = scene.nets.where((n) => n.net.id == wire.netId).firstOrNull;
        title = net?.displayName ?? 'Wire';
        actions.addAll(_wireActions(wire, net, _selectedWireRun));
      } else if (_sheetBoxes
              .where((b) => b.sheet.id == _selectedSheetId)
              .firstOrNull
          case final view?) {
        title = '${view.sheet.name} — drag to move';
        actions.addAll([
          CanvasAction(
            label: 'Open',
            icon: Icons.open_in_new,
            onPressed: () => _openSheet(view.sheet.id),
          ),
          CanvasAction(
            label: 'Rename',
            icon: Icons.drive_file_rename_outline,
            onPressed: () => _renameSheet(view.sheet),
          ),
          CanvasAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteSheet(view.sheet),
          ),
        ]);
      } else if (_notes.where((n) => n.id == _selectedNoteId).firstOrNull
          case final note?) {
        title = note.kind == NoteKind.box
            ? 'Box — drag to move'
            : 'Note — drag to move';
        actions.addAll([
          CanvasAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () => _editNote(note),
          ),
          CanvasAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () => _deleteNote(note),
          ),
        ]);
      }
    }

    if (actions.isEmpty) {
      // Nothing selected: the sheet's own commands.
      if (clipboard != null) title = 'Copied ${clipboard.summary}';
      actions.addAll([
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
          label: 'Check',
          icon: Icons.fact_check_outlined,
          onPressed: () => _check(scene),
        ),
        CanvasAction(
          label: 'Select',
          icon: Icons.highlight_alt,
          onPressed: _toggleBoxSelect,
        ),
        CanvasAction(
          label: 'Note',
          icon: Icons.sticky_note_2_outlined,
          onPressed: () => _addNote(scene),
        ),
        if (clipboard != null)
          CanvasAction(
            label: 'Paste',
            icon: Icons.content_paste,
            onPressed: _paste,
          ),
      ]);
    } else if (editedHere) {
      actions.insert(0, undoHere);
    }

    return CanvasActionBar(
      title: _hint ?? title,
      hinting: _hint != null,
      actions: actions,
    );
  }

  /// Ground and supplies are not here: they are parts like any other, in
  /// the component picker. Picking one while a pin is held puts it on that
  /// pin, which is what the buttons that used to be here did.
  List<CanvasAction> _pinActions(PlacedPin pin) => [
    CanvasAction(
      label: pin.pin.noConnect ? 'Connect' : 'No conn',
      icon: pin.pin.noConnect ? Icons.link : Icons.close,
      onPressed: () => _toggleNoConnect(pin),
    ),
    if (_wireCorners.isNotEmpty)
      CanvasAction(
        label: 'Finish',
        icon: Icons.check,
        onPressed: () {
          final scene = _scene;
          if (scene != null) _finishOpenWire(scene);
        },
      ),
    if (_wireCorners.isNotEmpty)
      CanvasAction(
        label: 'Back',
        icon: Icons.undo,
        onPressed: () => setState(
          () => _wireCorners = _wireCorners.sublist(0, _wireCorners.length - 1),
        ),
      ),
    CanvasAction(
      label: 'Cancel',
      icon: Icons.highlight_off,
      onPressed: () {
        ref.read(pendingPinProvider.notifier).set(null);
        setState(() => _wireCorners = const []);
      },
    ),
  ];

  List<CanvasAction> _labelActions(NetLabel label, NetWithEndpoints? net) => [
    CanvasAction(
      label: 'Rename',
      icon: Icons.label_outline,
      onPressed: net == null ? null : () => _labelNet(net),
    ),
    CanvasAction(
      label: 'Size',
      icon: Icons.format_size,
      onPressed: net == null ? null : () => _resizeLabel(label, net),
    ),
    CanvasAction(
      label: 'Snap back',
      icon: Icons.restart_alt,
      onPressed: label.pinned ? () => _resetLabel(label) : null,
    ),
    CanvasAction(
      label: 'Unlabel',
      icon: Icons.label_off_outlined,
      danger: true,
      onPressed: net == null ? null : () => _clearLabel(net),
    ),
  ];

  /// Text heights offered for a label, in millimetres. 1.27 is KiCad's.
  static const _labelSizes = [1.0, 1.27, 1.5, 2.0, 2.54, 3.5, 5.0];

  /// Changes how large a label's text is drawn.
  Future<void> _resizeLabel(NetLabel label, NetWithEndpoints net) async {
    final chosen = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: KicadPalette.surface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${label.text} label size',
                style: Theme.of(sheet).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final size in _labelSizes)
                    ChoiceChip(
                      key: ValueKey('label-size-$size'),
                      label: Text(
                        size == NetLabel.defaultSize
                            ? '$size mm (KiCad)'
                            : '$size mm',
                      ),
                      selected: (label.size - size).abs() < 1e-6,
                      onSelected: (_) => Navigator.of(sheet).pop(size),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final repository = ref.read(netRepositoryProvider);
    final before = net.net.labelSize;
    final after = chosen == NetLabel.defaultSize ? null : chosen;
    if (before == after) return;
    await repository.setNetLabelSize(net.net.id, after);
    _record(
      '${label.text} label size',
      undo: () => repository.setNetLabelSize(net.net.id, before),
      redo: () => repository.setNetLabelSize(net.net.id, after),
    );
  }

  /// Puts a dragged label back on the wire the drawing chose for it.
  Future<void> _resetLabel(NetLabel label) async {
    final repository = ref.read(netRepositoryProvider);
    final before = label.position;
    await repository.setNetLabelPosition(label.netId, null);
    _record(
      'Reset ${label.text} label',
      undo: () => repository.setNetLabelPosition(label.netId, before),
      redo: () => repository.setNetLabelPosition(label.netId, null),
    );
  }

  /// Takes a net's name off, which also takes its label off the sheet.
  Future<void> _clearLabel(NetWithEndpoints net) async {
    final repository = ref.read(netRepositoryProvider);
    final before = net.net.name;
    final pins = [for (final endpoint in net.endpoints) endpoint.pin.id];
    final snapshot = await repository.capture(widget.project.id, pins);
    await repository.renameNet(net.net.id, null);
    if (mounted) setState(() => _selectedLabelNetId = null);
    _record(
      'Unlabel ${before ?? "net"}',
      undo: () => repository.restore(snapshot),
      redo: () async {
        final id = await repository.netIdForPin(pins.first);
        if (id != null) await repository.renameNet(id, null);
      },
    );
  }

  /// The commands for the run of wire that is picked.
  ///
  /// Cut takes that run away and leaves the rest of the drawing alone,
  /// which is what taking a wire out usually means. Unwire is still there
  /// for the whole net, which is the one thing KiCad has no button for.
  List<CanvasAction> _wireActions(
    RoutedWire wire,
    NetWithEndpoints? net,
    int? run,
  ) => [
    CanvasAction(
      label: 'Label',
      icon: Icons.label_outline,
      onPressed: net == null ? null : () => _labelNet(net),
    ),
    CanvasAction(
      label: 'Cut',
      icon: Icons.content_cut,
      danger: true,
      onPressed: run == null || run >= wire.points.length - 1
          ? null
          : () => _cutWire(wire, run),
    ),
    CanvasAction(
      label: 'Unwire',
      icon: Icons.link_off,
      danger: true,
      onPressed: net == null ? null : () => _deleteNet(net),
    ),
  ];

  Future<void> _labelNet(NetWithEndpoints net) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NetLabelDialog(initialValue: net.net.name ?? ''),
    );
    if (name == null || !mounted) return;

    final repository = ref.read(netRepositoryProvider);
    // Naming a net can join it to another of the same name, which a rename
    // back cannot undo: the snapshot holds both nets as they were.
    final pins = [for (final endpoint in net.endpoints) endpoint.pin.id];
    final snapshot = await repository.capture(widget.project.id, [
      ...pins,
      ...await repository.pinsNamed(widget.project.id, name),
    ]);
    await repository.renameNet(net.net.id, name);
    _record(
      name.trim().isEmpty ? 'Label net' : 'Label ${name.trim()}',
      undo: () => repository.restore(snapshot),
      redo: () async {
        final id = await repository.netIdForPin(pins.first);
        if (id != null) await repository.renameNet(id, name);
      },
    );
  }

  Future<void> _deleteNet(NetWithEndpoints net) async {
    final repository = ref.read(netRepositoryProvider);
    final snapshot = await repository.capture(widget.project.id, [
      for (final endpoint in net.endpoints) endpoint.pin.id,
    ]);
    await repository.deleteNet(net.net.id);
    if (!mounted) return;
    setState(() {
      _selectedWireKey = null;
      _selectedWireRun = null;
      _highlightedNetId = null;
    });
    _record(
      'Disconnect ${net.displayName}',
      undo: () => repository.restore(snapshot),
      redo: () => repository.deleteNet(net.net.id),
    );
  }

  List<CanvasAction> _unitActions(PlacedUnit unit) => [
    CanvasAction(
      label: 'Value',
      icon: Icons.edit_outlined,
      onPressed: () => _editPart(unit),
    ),
    // Only on parts whose library says what their pins can do — in
    // practice, microcontrollers.
    if (unit.symbol case final symbol? when PinFunctions.hasAny(symbol))
      CanvasAction(
        label: 'Functions',
        icon: Icons.developer_board,
        onPressed: () => _showPinFunctions(unit, symbol),
      ),
    // Worth offering only where there are pins enough to label in bulk.
    if (unit.pins.length > 2 &&
        !SchematicScene.isPowerReference(unit.part.reference))
      CanvasAction(
        label: 'Labels',
        icon: Icons.label_outline,
        onPressed: () => _labelPins(unit),
      ),
    // Only on a part picked on its own, and one with pins to trade.
    if (unit.pins.length >= 2 &&
        !SchematicScene.isPowerReference(unit.part.reference))
      CanvasAction(
        label: 'Swap',
        icon: Icons.swap_horiz,
        onPressed: () => _swap(unit.part.id),
      ),
    CanvasAction(
      label: 'Rotate',
      icon: Icons.rotate_90_degrees_ccw_outlined,
      onPressed: () => _rotate(unit),
    ),
    CanvasAction(
      label: 'Mirror',
      icon: Icons.flip_outlined,
      onPressed: () => _mirror(unit),
    ),
    CanvasAction(
      label: 'Duplicate',
      icon: Icons.copy_all_outlined,
      onPressed: () => _duplicate(unit),
    ),
    CanvasAction(
      label: 'Delete',
      icon: Icons.delete_outline,
      danger: true,
      onPressed: () => _delete(unit),
    ),
  ];

  /// Swaps two pins, or two gates, of a part.
  Future<void> _swap(String partId) async {
    await runPartSwap(
      context,
      ref,
      projectId: widget.project.id,
      partId: partId,
      record: _record,
      notify: _notify,
    );
  }

  /// Labels many of a part's pins at once. A label is a connection, so
  /// the same names on another part wire the two together.
  Future<void> _labelPins(PlacedUnit unit) async {
    final parts = ref.read(sheetPartsProvider(widget.project.id)).value;
    final nets = ref.read(projectNetsProvider(widget.project.id)).value;
    final part = parts?.where((p) => p.part.id == unit.part.id).firstOrNull;
    if (part == null || nets == null) return;
    final netNameByPin = <String, String>{
      for (final net in nets)
        if (net.net.isNamed)
          for (final e in net.endpoints) e.pin.id: net.displayName,
    };
    final assignment = await showPinLabelsDialog(
      context,
      part: part,
      netNameByPin: netNameByPin,
    );
    if (assignment == null || assignment.isEmpty || !mounted) return;

    final repository = ref.read(netRepositoryProvider);
    final projectId = widget.project.id;
    // Everything a label might join: the pins themselves, and whatever
    // already carries each name.
    final touched = <String>{...assignment.keys};
    for (final name in assignment.values.toSet()) {
      touched.addAll(await repository.pinsNamed(projectId, name));
    }
    final before = await repository.capture(projectId, touched.toList());
    Future<void> apply() async {
      for (final entry in assignment.entries) {
        await repository.labelPin(projectId, entry.key, entry.value);
      }
    }

    await apply();
    _record(
      'Label ${assignment.length} pins of ${unit.part.reference}',
      undo: () => repository.restore(before),
      redo: apply,
    );
    _notify(
      'Labelled ${assignment.length} pins — the same names elsewhere are '
      'now wired to them',
    );
  }

  /// Runs the schematic check and shows what it found.
  Future<void> _check(SchematicScene scene) async {
    final parts = ref.read(sheetPartsProvider(widget.project.id)).value;
    final nets = ref.read(projectNetsProvider(widget.project.id)).value;
    if (parts == null || nets == null) return;
    final placements = await ref
        .read(boardRepositoryProvider)
        .getFootprints(widget.project.id);
    final settings = ErcSettings.fromSettings(
      await ref
          .read(projectSettingsRepositoryProvider)
          .getAll(widget.project.id),
    );
    if (!mounted) return;
    final violations = checkSchematic(
      parts: parts,
      nets: nets,
      partsWithBoardFootprint: {for (final p in placements) p.partId},
      settings: settings,
    );
    await showErcSheet(
      context,
      violations: violations,
      onShow: (violation) => _showPart(violation.partId, violation.netId),
      onRenumber: _renumber,
      onRules: () => _editErcRules(scene, settings),
      ignoredRules: ErcRule.values
          .where((r) => settings.levelOf(r) == ErcLevel.ignore)
          .length,
    );
  }

  Future<void> _editErcRules(SchematicScene scene, ErcSettings before) async {
    final after = await showErcRulesDialog(context, settings: before);
    if (after == null || !mounted) return;
    final repository = ref.read(projectSettingsRepositoryProvider);
    await repository.setAll(widget.project.id, after.toSettings());
    _record(
      'Change the checks',
      undo: () => repository.setAll(widget.project.id, before.toSettings()),
      redo: () => repository.setAll(widget.project.id, after.toSettings()),
    );
    if (mounted) await _check(scene);
  }

  /// Selects a part and brings it to the middle of the view.
  void _showPart(String? partId, String? netId) {
    final scene = _scene;
    final viewport = _viewport;
    if (scene == null || viewport == null || partId == null) return;
    final unit = scene.units.where((u) => u.part.id == partId).firstOrNull;
    if (unit == null) return;
    final centre = scene.boundsOf(unit).center;
    setState(() {
      _selectedUnitId = unit.unit.id;
      _highlightedNetId = netId;
      _viewport = viewport.copyWith(
        origin: Offset(
          _canvasSize.width / 2 - centre.dx * viewport.pixelsPerMm,
          _canvasSize.height / 2 - centre.dy * viewport.pixelsPerMm,
        ),
      );
    });
  }

  Future<void> _renumber() async {
    final repository = ref.read(partRepositoryProvider);
    final changes = await repository.renumberReferences(widget.project.id);
    if (!mounted) return;
    if (changes.isEmpty) {
      _notify('Already numbered in order');
      return;
    }
    _notify('Renumbered ${changes.length} parts');
    _record(
      'Renumber ${changes.length} parts',
      undo: () => repository.applyReferences({
        for (final e in changes.entries) e.key: e.value.$1,
      }, widget.project.id),
      redo: () => repository.applyReferences({
        for (final e in changes.entries) e.key: e.value.$2,
      }, widget.project.id),
    );
  }

  void _toggleBoxSelect() {
    setState(() {
      _boxSelecting = !_boxSelecting;
      _selectedUnitIds = const {};
      _selectedWireIds = const {};
      _selectedUnitId = null;
      _selectedWireKey = null;
      _selectedWireRun = null;
      _selectedLabelNetId = null;
      _boxFrom = null;
      _boxTo = null;
    });
    if (_boxSelecting) {
      _notify('Drag to box parts in, then drag one to move them all');
    }
  }

  /// The sheet the units in [unitIds] cover, together.
  static Rect? _areaOf(SchematicScene scene, Set<String> unitIds) {
    Rect? area;
    for (final unit in scene.units) {
      if (!unitIds.contains(unit.unit.id)) continue;
      final bounds = scene.boundsOf(unit);
      area = area == null ? bounds : area.expandToInclude(bounds);
    }
    return area;
  }

  /// The drawn wires that go wherever the units in [unitIds] go.
  ///
  /// Every pin a wire ends on has to be on one of those units — which takes
  /// in a wire left hanging from one of their pins, the case that used to
  /// stay behind — and a wire ending on no pin at all has to lie within
  /// them. A loose end resting on a wire that is not moving is joined to
  /// it, though, so that wire stretches rather than comes away.
  List<SchematicWire> _wiresCarriedBy(
    SchematicScene scene,
    Set<String> unitIds,
  ) {
    final drawn =
        ref.read(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];
    final pins = {
      for (final pin in scene.pins)
        if (unitIds.contains(pin.unitId)) pin.id,
    };
    final area = _areaOf(scene, unitIds)?.inflate(0.01);

    final carried = [
      for (final wire in drawn)
        if ((wire.pinAId == null || pins.contains(wire.pinAId)) &&
            (wire.pinBId == null || pins.contains(wire.pinBId)) &&
            (wire.pinAId != null ||
                wire.pinBId != null ||
                (area != null && wire.points.every(area.contains))))
          wire,
    ];
    final ids = {for (final wire in carried) wire.id};

    bool restsOnStayingWire(Offset end) => scene.wires.any(
      (other) =>
          !ids.contains(other.drawnId) &&
          DrawnWireGeometry.nearestRun(other.points, end).$2 < 0.01,
    );
    return [
      for (final wire in carried)
        if (!(wire.pinAId == null && restsOnStayingWire(wire.points.first)) &&
            !(wire.pinBId == null && restsOnStayingWire(wire.points.last)))
          wire,
    ];
  }

  /// The wires a selection takes with it: the ones swept up in their own
  /// right, and the ones belonging to the parts in it.
  List<SchematicWire> _selectionWires(SchematicScene scene) =>
      _selectionWiresOf(scene, _dragOriginals.keys.toSet());

  List<SchematicWire> _selectionWiresOf(
    SchematicScene scene,
    Set<String> unitIds,
  ) {
    final drawn =
        ref.read(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];
    final carried = _wiresCarriedBy(scene, unitIds);
    final ids = {for (final wire in carried) wire.id};
    return [
      ...carried,
      for (final wire in drawn)
        if (_selectedWireIds.contains(wire.id) && !ids.contains(wire.id)) wire,
    ];
  }

  /// Turns a group a quarter about its middle, wires and all, as one step.
  Future<void> _rotateGroup(
    SchematicScene scene,
    List<PlacedUnit> group,
  ) async {
    final ids = {for (final unit in group) unit.unit.id};
    final wiresBefore = _selectionWiresOf(scene, ids);
    var area = _areaOf(scene, ids);
    for (final wire in wiresBefore) {
      for (final point in wire.points) {
        final at = Rect.fromCenter(center: point, width: 0, height: 0);
        area = area == null ? at : area.expandToInclude(at);
      }
    }
    if (area == null) return;
    // On the grid, so parts on the grid stay on it once turned.
    final centre = _snapToGrid(area.center);
    // The same way a single part turns: a positive quarter on screen.
    Offset turn(Offset p) {
      final d = p - centre;
      return centre + Offset(d.dy, -d.dx);
    }

    final parts = ref.read(partRepositoryProvider);
    final nets = ref.read(netRepositoryProvider);
    final before = [for (final unit in group) unit.unit];
    final after = [
      for (final unit in group)
        unit.unit.copyWith(
          x: turn(Offset(unit.unit.x, unit.unit.y)).dx,
          y: turn(Offset(unit.unit.x, unit.unit.y)).dy,
          rotation: (unit.unit.rotation + 90) % 360,
          placed: true,
        ),
    ];
    final wiresAfter = [
      for (final wire in wiresBefore)
        wire.copyWith(points: [for (final p in wire.points) turn(p)]),
    ];

    Future<void> write(List<PartUnit> units, List<SchematicWire> wires) async {
      for (final unit in units) {
        await parts.updateUnitPlacement(unit);
      }
      for (final wire in wires) {
        await nets.updateWire(wire);
      }
    }

    await _atomically(() => write(after, wiresAfter));
    _record(
      group.isEmpty
          ? 'Rotate ${wiresAfter.length} wires'
          : 'Rotate ${group.length} parts',
      undo: () => write(before, wiresBefore),
      redo: () => write(after, wiresAfter),
    );
  }

  /// Copies a group with its wiring, ready to paste somewhere else.
  /// One set of fields for every part in the group.
  /// The parts of [group] that are fitted to a board — every one but the
  /// power symbols, which have no footprint, value or place in a BOM to
  /// change. A multi-unit part is one part, however many units are picked.
  static List<Part> _fittedParts(List<PlacedUnit> group) => {
    for (final unit in group)
      if (!SchematicScene.isPowerReference(unit.part.reference))
        unit.part.id: unit.part,
  }.values.toList();

  /// Marks every part picked do-not-populate — or, when they all already
  /// are, fits them again.
  Future<void> _toggleDnp(List<PlacedUnit> group) async {
    final parts = _fittedParts(group);
    if (parts.isEmpty) return;
    final dnp = !parts.every((p) => p.dnp);
    final repository = ref.read(partRepositoryProvider);
    final after = [for (final p in parts) p.copyWith(dnp: dnp)];
    for (final part in after) {
      await repository.updatePart(part);
    }
    _record(
      dnp ? 'Do not populate ${parts.length}' : 'Fit ${parts.length}',
      undo: () async {
        for (final part in parts) {
          await repository.updatePart(part);
        }
      },
      redo: () async {
        for (final part in after) {
          await repository.updatePart(part);
        }
      },
    );
    _notify(
      dnp
          ? '${parts.length} parts marked do-not-populate — still in the BOM '
                'and on the board'
          : '${parts.length} parts fitted again',
    );
  }

  /// Keeps the picked parts, their wiring and their wires as a circuit to
  /// insert again, in any project.
  Future<void> _saveCircuit(
    SchematicScene scene,
    List<PlacedUnit> group,
  ) async {
    final parts = ref.read(sheetPartsProvider(widget.project.id)).value;
    final nets = ref.read(projectNetsProvider(widget.project.id)).value;
    if (parts == null || nets == null) return;
    final ids = {for (final unit in group) unit.unit.id};
    final clip = CircuitClip.of(
      parts: parts,
      nets: nets,
      wires: _selectionWiresOf(scene, ids),
      unitIds: ids,
      area: _areaOf(scene, ids)?.inflate(0.01),
    );
    if (clip == null) return;
    final name = await _askCircuitName(clip);
    if (name == null || !mounted) return;
    await ref.read(savedCircuitRepositoryProvider).save(name, clip);
    _notify('Saved "$name" — it is under Saved circuits when you add parts');
  }

  Future<String?> _askCircuitName(CircuitClip clip) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Save this circuit'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('save-circuit-name'),
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. 3.3 V LDO',
                  isDense: true,
                ),
                onSubmitted: (text) => Navigator.of(
                  dialog,
                ).pop(text.trim().isEmpty ? null : text.trim()),
              ),
              const SizedBox(height: 8),
              Text(
                '${clip.parts.length} parts, wired as they are here. Add it to '
                'any project from Saved circuits in the component list.',
                style: TextStyle(
                  fontSize: 12,
                  color: KicadPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('save-circuit-confirm'),
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(dialog).pop(text.isEmpty ? 'Circuit' : text);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkEdit(List<PlacedUnit> group) async {
    final parts = _fittedParts(group);
    if (parts.isEmpty) return;
    final edit = await showBulkEditDialog(context, parts: parts);
    if (edit == null || edit.isEmpty || !mounted) return;
    final repository = ref.read(partRepositoryProvider);
    final after = [for (final p in parts) edit.applyTo(p)];
    for (final part in after) {
      await repository.updatePart(part);
    }
    _record(
      'Edit ${parts.length} parts',
      undo: () async {
        for (final part in parts) {
          await repository.updatePart(part);
        }
      },
      redo: () async {
        for (final part in after) {
          await repository.updatePart(part);
        }
      },
    );
    _notify('Edited ${parts.length} parts');
  }

  void _copyGroup(SchematicScene scene, List<PlacedUnit> group) {
    final parts = ref.read(sheetPartsProvider(widget.project.id)).value;
    final nets = ref.read(projectNetsProvider(widget.project.id)).value;
    if (parts == null || nets == null) return;
    final ids = {for (final unit in group) unit.unit.id};
    final clip = CircuitClip.of(
      parts: parts,
      nets: nets,
      wires: _selectionWiresOf(scene, ids),
      unitIds: ids,
      area: _areaOf(scene, ids)?.inflate(0.01),
    );
    if (clip == null) return;
    ref.read(circuitClipboardProvider.notifier).copy(clip);
    _notify('Copied ${clip.summary} — tap where it goes');
  }

  /// Deletes everything selected — parts and the wires swept up with them —
  /// as one undoable step.
  ///
  /// A wire taken away parts the pins it joined, unless another wire still
  /// reaches them. The nets are what the design is, so a drawing with the
  /// wire gone has to say the pins are no longer joined.
  Future<void> _deleteSelection(
    SchematicScene scene,
    List<PlacedUnit> group,
  ) async {
    final parts = ref.read(partRepositoryProvider);
    final nets = ref.read(netRepositoryProvider);
    final projectId = widget.project.id;
    final partIds = {for (final unit in group) unit.part.id}.toList();
    final drawn =
        ref.read(schematicWiresProvider(projectId)).value ??
        const <SchematicWire>[];
    final wires = [
      for (final wire in drawn)
        if (_selectedWireIds.contains(wire.id)) wire,
    ];

    // Everything as it stands, before any of it goes: deleting a part
    // tidies away nets it was on, and a snapshot taken afterwards has lost
    // them.
    final connections = await nets.capture(projectId, [
      for (final wire in wires)
        for (final pin in scene.pinsByNet[wire.netId] ?? const <PlacedPin>[])
          pin.id,
    ]);
    final snapshots = <PartSnapshot>[];
    for (final id in partIds) {
      final snapshot = await parts.capturePart(id);
      if (snapshot != null) snapshots.add(snapshot);
    }

    Future<void> remove() async {
      for (final wire in wires) {
        await nets.deleteWire(wire.id);
        for (final pin in [wire.pinAId, wire.pinBId].nonNulls) {
          final held = drawn.any(
            (other) =>
                !_selectedWireIds.contains(other.id) &&
                (other.pinAId == pin || other.pinBId == pin),
          );
          if (!held) await nets.disconnectPin(pin);
        }
      }
      for (final id in partIds) {
        await parts.deletePart(id);
      }
    }

    await remove();
    if (!mounted) return;
    setState(() {
      _selectedUnitIds = const {};
      _selectedWireIds = const {};
    });
    _record(
      switch ((partIds.length, wires.length)) {
        (final units, 0) => 'Delete $units parts',
        (0, final count) => 'Delete $count ${count == 1 ? "wire" : "wires"}',
        (final units, final count) => 'Delete $units parts, $count wires',
      },
      undo: () async {
        for (final snapshot in snapshots) {
          await parts.restorePart(snapshot);
        }
        await nets.restore(connections);
      },
      redo: remove,
    );
  }

  Future<void> _undo() async {
    await _stepHistory(backward: true);
    if (mounted) setState(() => _highlightedNetId = null);
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
    if (mounted) setState(() => _highlightedNetId = null);
  }

  void _record(
    String label, {
    required Future<void> Function() undo,
    required Future<void> Function() redo,
  }) {
    // The first edit made under this selection marks where its own undo
    // history begins.
    final key = _selectionKey;
    if (key == null) {
      _editBase = null;
    } else if (_editBase?.$1 != key) {
      _editBase = (key, ref.read(editHistoryProvider).past.length);
    }
    ref
        .read(editHistoryProvider.notifier)
        .push(
          widget.project.id,
          EditAction(label: label, undo: undo, redo: redo),
        );
  }

  /// Every power symbol the installed libraries hold.
  Future<List<SymbolIndexEntry>> _powerSymbols() => ref
      .read(symbolLibraryRepositoryProvider)
      .search('', powerOnly: true, limit: 300);

  /// Places [entry] facing [pin] and joins the two.
  Future<void> _attachPower(PlacedPin pin, SymbolIndexEntry entry) async {
    final result = await attachPower(
      parts: ref.read(partRepositoryProvider),
      nets: ref.read(netRepositoryProvider),
      libraries: ref.read(symbolLibraryRepositoryProvider),
      projectId: widget.project.id,
      libId: entry.libId,
      pinId: pin.id,
      pinPosition: pin.sheetPosition,
      pinExit: pin.exitDirection,
    );
    if (!mounted) return;

    switch (result) {
      case AttachPowerFailed(:final reason):
        _notify(switch (reason) {
          AttachPowerFailure.unreadable => '${entry.libId} could not be read',
          AttachPowerFailure.pinless => '${entry.libId} has no pin to connect',
        });
      case AttachPowerPlaced(:final part):
        ref.read(pendingPinProvider.notifier).set(null);
        setState(() => _selectedUnitId = null);
        // Recorded after the connection, so taking it back takes the wire
        // with it and putting it again brings the wire back.
        await _recordAddition(part.part.id, '${entry.name} on ${pin.label}');
    }
  }

  /// Which of this part's pins can serve which peripheral, with the ones
  /// already wired in the design marked.
  Future<void> _showPinFunctions(PlacedUnit unit, SymbolDefinition symbol) {
    final scene = _scene;
    final used = <String>{
      if (scene != null)
        for (final pin in scene.pins)
          if (pin.partId == unit.part.id && pin.isConnected) pin.pin.number,
    };

    return showDialog<void>(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          child: SizedBox(
            width: size.width - 64,
            height: size.height - 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${unit.part.reference} · ${unit.part.value} — '
                          'pin functions',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (used.isNotEmpty)
                        Text(
                          '${used.length} pins already wired',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: KicadPalette.textSecondary),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PinoutExplorer(
                    symbol: symbol,
                    unit: unit.unit.unitNumber,
                    usedPins: used,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleNoConnect(PlacedPin pin) async {
    final repository = ref.read(partRepositoryProvider);
    final was = pin.pin.noConnect;
    await repository.setPinNoConnect(pin.id, !was);
    ref.read(pendingPinProvider.notifier).set(null);
    _record(
      was ? 'Clear no-connect on ${pin.label}' : 'No-connect ${pin.label}',
      undo: () => repository.setPinNoConnect(pin.id, was),
      redo: () => repository.setPinNoConnect(pin.id, !was),
    );
  }

  Future<void> _editPart(PlacedUnit unit) async {
    final result = await showPartEditorDialog(context, part: unit.part);
    if (result == null || !mounted) return;

    final repository = ref.read(partRepositoryProvider);
    final before = unit.part;
    final after = before.copyWith(
      reference: result.reference,
      value: result.value,
      footprint: result.footprint,
      dnp: result.dnp,
      componentId: result.componentId,
      fieldsHidden: result.fieldsHidden,
    );
    await repository.updatePart(after);
    _record(
      'Edit ${after.reference}',
      undo: () => repository.updatePart(before),
      redo: () => repository.updatePart(after),
    );
  }

  Future<void> _rotate(PlacedUnit unit) => _reposition(
    unit,
    unit.unit.copyWith(rotation: (unit.unit.rotation + 90) % 360),
    'Rotate ${unit.part.reference}',
  );

  Future<void> _mirror(PlacedUnit unit) => _reposition(
    unit,
    unit.unit.copyWith(mirrorY: !unit.unit.mirrorY),
    'Mirror ${unit.part.reference}',
  );

  Future<void> _reposition(
    PlacedUnit unit,
    PartUnit after,
    String label,
  ) async {
    final repository = ref.read(partRepositoryProvider);
    final before = unit.unit;
    await repository.updateUnitPlacement(after);
    _record(
      label,
      undo: () => repository.updateUnitPlacement(before),
      redo: () => repository.updateUnitPlacement(after),
    );
  }

  Future<void> _duplicate(PlacedUnit unit) async {
    final repository = ref.read(partRepositoryProvider);
    final copy = await repository.duplicatePart(unit.part.id);
    if (copy == null || !mounted) return;
    setState(() => _selectedUnitId = copy.units.first.id);
    await _recordAddition(copy.part.id, 'Duplicate ${unit.part.reference}');
  }

  /// Puts the copied circuit down where the sheet was last tapped, wired as
  /// it was, and selects it so it can be dragged straight into place.
  Future<void> _paste() async {
    final clip = ref.read(circuitClipboardProvider);
    if (clip == null) return;
    await _pasteClip(clip);
  }

  /// Puts a saved circuit on the sheet, the way a paste does.
  Future<void> _insertSaved(SavedCircuit saved) async {
    await _pasteClip(saved.clip, label: saved.name);
    _notify('Added ${saved.name}');
  }

  Future<void> _pasteClip(CircuitClip clip, {String? label}) async {
    final viewport = _viewport;
    final at =
        _lastTapSheet ??
        viewport?.toSheet(
          Offset(_canvasSize.width / 2, _canvasSize.height / 2),
        ) ??
        Offset.zero;

    final parts = ref.read(partRepositoryProvider);
    final nets = ref.read(netRepositoryProvider);
    final pasted = await CircuitPaster(
      parts,
      nets,
    ).paste(widget.project.id, clip, at: _snapToGrid(at));

    // Taken once everything is joined, so putting it back again restores
    // the connections along with the parts.
    final snapshots = <PartSnapshot>[];
    for (final id in pasted.partIds) {
      final snapshot = await parts.capturePart(id);
      if (snapshot != null) snapshots.add(snapshot);
    }
    if (!mounted) return;
    setState(() {
      if (pasted.unitIds.length == 1) {
        _selectedUnitId = pasted.unitIds.single;
        _selectedUnitIds = const {};
      } else {
        _selectedUnitId = null;
        _selectedUnitIds = pasted.unitIds;
      }
    });
    _record(
      label == null ? 'Paste ${clip.summary}' : 'Add $label',
      undo: () async {
        for (final wire in pasted.wires) {
          await nets.deleteWire(wire.id);
        }
        for (final id in pasted.partIds) {
          await parts.deletePart(id);
        }
      },
      redo: () async {
        for (final snapshot in snapshots) {
          await parts.restorePart(snapshot);
        }
        for (final wire in pasted.wires) {
          await nets.restoreWire(wire);
        }
      },
    );
  }

  Future<void> _delete(PlacedUnit unit) async {
    final repository = ref.read(partRepositoryProvider);
    // Captured first: deleting a part takes its connections with it, and
    // nothing else can reconstruct them afterwards.
    final snapshot = await repository.capturePart(unit.part.id);
    await repository.deletePart(unit.part.id);
    if (!mounted) return;
    setState(() => _selectedUnitId = null);
    if (snapshot == null) return;
    _record(
      'Delete ${unit.part.reference}',
      undo: () => repository.restorePart(snapshot),
      redo: () => repository.deletePart(unit.part.id),
    );
  }

  /// Records a newly created part so it can be taken back and put again.
  Future<void> _recordAddition(String partId, String label) async {
    final repository = ref.read(partRepositoryProvider);
    final snapshot = await repository.capturePart(partId);
    if (snapshot == null) return;
    _record(
      label,
      undo: () => repository.deletePart(partId),
      redo: () => repository.restorePart(snapshot),
    );
  }

  SchematicViewport _fitToContent(SchematicScene scene, Size size) {
    final bounds = scene.contentBounds;
    if (bounds.width <= 0 || bounds.height <= 0 || size.isEmpty) {
      return const SchematicViewport(pixelsPerMm: 4, origin: Offset(20, 40));
    }
    // A little air at the top, and no more: the status strip that used to
    // sit there is gone.
    const topInset = 8.0;
    final scale = math.min(
      size.width / bounds.width,
      (size.height - topInset) / bounds.height,
    );
    final clamped = scale.clamp(0.5, 24.0);
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

  Future<void> _onTap(
    SchematicScene scene,
    SchematicViewport viewport,
    Offset local,
  ) async {
    if (_isDraggingUnit) return;

    final sheet = viewport.toSheet(local);
    _lastTapSheet = sheet;

    // Selecting, a tap adds a part or a wire to the group, or takes it
    // back out. A tap on nothing lets the whole group go.
    if (_boxSelecting ||
        _selectedUnitIds.isNotEmpty ||
        _selectedWireIds.isNotEmpty) {
      final unit = scene.unitAt(sheet);
      final wire = unit != null
          ? null
          : scene.wireRunNear(sheet, _wireToleranceMm(viewport))?.wire.drawnId;
      // The count says more than the how-to hint once picking is going.
      _hintTimer?.cancel();
      setState(() {
        _hint = null;
        if (unit != null) {
          final id = unit.unit.id;
          _selectedUnitIds = _selectedUnitIds.contains(id)
              ? ({..._selectedUnitIds}..remove(id))
              : {..._selectedUnitIds, id};
        } else if (wire != null) {
          _selectedWireIds = _selectedWireIds.contains(wire)
              ? ({..._selectedWireIds}..remove(wire))
              : {..._selectedWireIds, wire};
        } else {
          _selectedUnitIds = const {};
          _selectedWireIds = const {};
        }
      });
      return;
    }
    // Placing: another of the part picked last, wherever the sheet is
    // empty. Pins are not for wiring in this mode.
    final stamp = _stamp;
    if (_placing &&
        stamp != null &&
        scene.unitAt(sheet) == null &&
        scene.wireRunNear(sheet, _wireToleranceMm(viewport)) == null &&
        _labelAt(scene, sheet) == null) {
      await _addFromLibrary(stamp);
      return;
    }
    final result = _placing
        ? const PinTapMissed()
        : scene.resolveTap(
            sheet,
            toleranceMm: _hitToleranceMm(viewport),
            ambiguityMarginMm: _ambiguityMarginPx / viewport.pixelsPerMm,
          );

    if (result is PinTapMissed) {
      // A label is the smallest thing on the sheet and sits on top of it;
      // a tap on one picks it, rather than whatever it happens to cover.
      final label = _labelAt(scene, sheet);
      if (label != null) {
        setState(() {
          _selectedLabelNetId = label.netId;
          _selectedUnitId = null;
          _selectedWireKey = null;
          _selectedWireRun = null;
          _highlightedNetId = label.netId;
        });
        return;
      }
      setState(() => _selectedLabelNetId = null);

      // Half-way through a connection, a tap on a wire joins the pin to
      // that wire's net. Wiring a third part onto an existing run is the
      // ordinary case — a filter's output, a supply rail — and until now it
      // could only be done by finding one of the pins already on the net.
      final pendingId = ref.read(pendingPinProvider);
      // Dragging is how wires are drawn: a tap never adds to one. Half-way
      // through a wire, a stray tap leaves it be rather than throw away the
      // corners already laid.
      if (pendingId != null && !_tapWiring && _wireCorners.isNotEmpty) {
        _notify('Drag on from the loose end, or press Finish');
        return;
      }
      if (pendingId != null && _tapWiring) {
        if (_boxPinNear(sheet, _hitToleranceMm(viewport)) case final boxPin?) {
          await _connectToSheetPin(scene, pendingId, boxPin);
          return;
        }
        final wire = scene.wireNear(sheet, _wireToleranceMm(viewport));
        if (wire != null) {
          final (run, _) = DrawnWireGeometry.nearestRun(wire.points, sheet);
          await _joinPinToNet(
            scene,
            pendingId,
            wire.netId,
            endAt: _onRun(wire.points, run, sheet),
          );
          return;
        }
        // Empty sheet: a corner of the wire being drawn, the way a board
        // track is laid corner by corner.
        if (scene.unitAt(sheet) == null) {
          setState(() => _wireCorners = [..._wireCorners, _snapToGrid(sheet)]);
          return;
        }
      }

      // Tapping away from any pin cancels a half-made connection instead of
      // wiring up whatever happened to be nearest. Connecting the wrong pin
      // is far more annoying to discover than having to tap again.
      // Tapping away from any pin cancels a half-made connection. The pin's
      // highlight going out says so; a message saying it as well was one
      // more pop-up on every stray tap.
      if (pendingId != null) {
        ref.read(pendingPinProvider.notifier).set(null);
        setState(() => _wireCorners = const []);
      }
      // Whichever is actually nearer wins, rather than the symbol always.
      //
      // A symbol's hit box reaches out to the tip of every pin, and wires
      // are deliberately routed to clear the body — which puts them inside
      // that box. Letting the symbol win unconditionally made every wire
      // running close to a part impossible to grab.
      final unit = scene.unitAt(sheet);
      final wire = scene.wireRunNear(sheet, _wireToleranceMm(viewport));

      final unitDistance = unit == null
          ? double.infinity
          : scene.distanceToBody(unit, sheet);
      final wireDistance = wire == null
          ? double.infinity
          : wire.wire.distanceTo(sheet);

      final wireWins = wire != null && wireDistance < unitDistance;

      // Notes lie under the circuit, so they are what a tap means only when
      // it means nothing else.
      if (unit == null && wire == null) {
        // A sheet's box: picked, to open, move or rename.
        final box = _sheetBoxes.where((b) => b.box.contains(sheet)).firstOrNull;
        if (box != null) {
          setState(() {
            _selectedSheetId = box.sheet.id == _selectedSheetId
                ? null
                : box.sheet.id;
            _selectedNoteId = null;
            _selectedUnitId = null;
            _selectedWireKey = null;
            _selectedWireRun = null;
            _highlightedNetId = null;
          });
          return;
        }
        final note = _noteAt(sheet, viewport);
        setState(() {
          _selectedNoteId = note?.id == _selectedNoteId ? null : note?.id;
          _selectedUnitId = null;
          _selectedWireKey = null;
          _selectedWireRun = null;
          _highlightedNetId = null;
        });
        if (note != null) return;
      } else if (_selectedNoteId != null) {
        _selectedNoteId = null;
      }
      _selectedSheetId = null;

      setState(() {
        // Tapping the selected symbol again lets go of it. Without a toggle
        // the only way to clear a selection is to find empty sheet, which on
        // a busy drawing can mean hunting for somewhere to tap.
        if (wireWins) {
          final key = wire.wire.key;
          // Tapping the same run again lets go; tapping another run of the
          // same wire picks that one instead.
          final reselected =
              key == _selectedWireKey && wire.run == _selectedWireRun;
          _selectedUnitId = null;
          _selectedWireKey = reselected ? null : key;
          _selectedWireRun = reselected ? null : wire.run;
          // Only the run tapped, not the whole net: lighting up every wire
          // on the net buried the one piece the commands apply to.
          _highlightedNetId = null;
        } else {
          _selectedUnitId = (unit == null || unit.unit.id == _selectedUnitId)
              ? null
              : unit.unit.id;
          _selectedWireKey = null;
          _selectedWireRun = null;
          _highlightedNetId = null;
        }
      });
      return;
    }

    final pin = switch (result) {
      PinTapHit(:final pin) => pin,
      PinTapAmbiguous(:final candidates) => await _choosePin(candidates, local),
      PinTapMissed() => null,
    };
    if (pin == null || !mounted) return;
    _tapPin(scene, pin);
  }

  /// How much closer the nearest pin must be than the next for a tap to be
  /// taken at face value, in logical pixels. A finger covers several pins on
  /// a dense part, and picking the nearest by a hair is how a schematic
  /// quietly ends up wired wrong.
  static const double _ambiguityMarginPx = 12;

  Future<PlacedPin?> _choosePin(
    List<PlacedPin> candidates,
    Offset local,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return candidates.first;
    final origin = box.localToGlobal(local);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final size = overlay?.size ?? MediaQuery.sizeOf(context);

    return showMenu<PlacedPin>(
      context: context,
      color: KicadPalette.surfaceRaised,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        size.width - origin.dx,
        size.height - origin.dy,
      ),
      items: [
        for (final pin in candidates.take(6))
          PopupMenuItem<PlacedPin>(
            value: pin,
            height: 46,
            child: Row(
              children: [
                Text(
                  pin.label,
                  style: TextStyle(color: KicadPalette.textPrimary),
                ),
                const SizedBox(width: 10),
                if (pin.pin.hasName)
                  Text(
                    pin.pin.name,
                    style: TextStyle(color: KicadPalette.pinName),
                  ),
                const Spacer(),
                if (pin.isConnected)
                  Icon(Icons.link, size: 14, color: KicadPalette.wire),
              ],
            ),
          ),
      ],
    );
  }

  /// Adds one pin to an existing net, which is what tapping a wire means.
  ///
  /// Goes through the same capture/restore as a pin-to-pin connection, so
  /// it undoes the same way — and so that joining a pin that was already on
  /// a net of its own merges the two rather than silently dropping one.
  Future<void> _joinPinToNet(
    SchematicScene scene,
    String pinId,
    String netId, {
    Offset? endAt,
  }) async {
    final sheetId = _currentSheet;
    final corners = _wireCorners;
    setState(() => _wireCorners = const []);
    final pin = scene.pins.where((p) => p.id == pinId).firstOrNull;
    if (pin != null && pin.netId == netId) {
      ref.read(pendingPinProvider.notifier).set(null);
      _notify('${pin.label} is already on that net');
      return;
    }

    final net = scene.nets.where((n) => n.net.id == netId).firstOrNull;
    ref.read(pendingPinProvider.notifier).set(null);

    final repository = ref.read(netRepositoryProvider);
    try {
      final snapshot = await repository.capture(widget.project.id, [pinId]);
      // A pin already on another net has to leave it first: a pin belongs to
      // exactly one net, and addPinToNet is where that is enforced.
      await repository.addPinToNet(netId, pinId);
      // Drawn through its corners onto the wire it was tapped on, when it
      // was drawn at all.
      SchematicWire? drawn;
      if (pin != null && corners.isNotEmpty && endAt != null) {
        drawn = await repository.addWire(
          sheetId: sheetId,
          projectId: widget.project.id,
          points: DrawnWireGeometry.orthogonalPath([
            pin.sheetPosition,
            ...corners,
            endAt,
          ]),
          pinAId: pinId,
          netId: await repository.netIdForPin(pinId),
        );
      }
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _highlightedNetId = netId;
        _selectedWireKey = null;
        _selectedWireRun = null;
      });
      _record(
        'Connect ${pin?.label ?? "pin"} to ${net?.displayName ?? "net"}',
        undo: () => repository.restore(snapshot),
        redo: () async {
          await repository.addPinToNet(netId, pinId);
          final net = await repository.netIdForPin(pinId);
          if (drawn != null && net != null) {
            await repository.restoreWire(drawn.copyWith(netId: net));
          }
        },
      );
    } on InvalidConnectionException catch (e) {
      if (!mounted) return;
      _notify(e.message);
    }
  }

  /// Picks a pin up: highlights its net and puts its own actions on the bar.
  ///
  /// With wires drawn by dragging (the default), that is all a tap does:
  /// two taps a few seconds apart joining things nobody meant to join was
  /// the mistake that made drag the default. With [WireGesture.tap] chosen
  /// in Settings, a tap on a second pin ends the wire there instead.
  void _tapPin(SchematicScene scene, PlacedPin pin) {
    final notifier = ref.read(pendingPinProvider.notifier);

    // A wire was picked first: the tap finishes the connection onto its net,
    // the mirror of tapping the wire second. That one stays — it takes a
    // deliberate wire selection to get into.
    final selectedWire = scene.wires
        .where((w) => w.key == _selectedWireKey)
        .firstOrNull;
    if (selectedWire != null && _tapWiring) {
      unawaited(_joinPinToNet(scene, pin.id, selectedWire.netId));
      return;
    }

    final pendingId = ref.read(pendingPinProvider);
    if (pendingId == pin.id) {
      notifier.set(null);
      setState(() => _wireCorners = const []);
      return;
    }

    // Wiring by taps: the second pin is where the wire ends.
    if (pendingId != null && _tapWiring) {
      unawaited(_connectPins(scene, pendingId, pin));
      return;
    }

    notifier.set(pin.id);
    setState(() {
      _wireCorners = const [];
      _selectedWireKey = null;
      _selectedWireRun = null;
      _highlightedNetId = pin.netId;
    });
  }

  /// Joins two pins, and draws the wire the drag or taps took to get there.
  ///
  /// Reached by letting go of a dragged wire on a pin or, with wiring by
  /// taps chosen, by tapping the pin it ends on.
  /// The pin of a sheet's box nearest [at], within [toleranceMm].
  SheetBoxPin? _boxPinNear(Offset at, double toleranceMm) {
    SheetBoxPin? best;
    var bestDistance = toleranceMm;
    for (final box in _sheetBoxes) {
      for (final pin in box.pins) {
        final distance = (pin.at - at).distance;
        if (distance <= bestDistance) {
          bestDistance = distance;
          best = pin;
        }
      }
    }
    return best;
  }

  /// Why a sheet's pin with nothing behind it cannot be wired.
  String _emptySheetPin(SheetBoxPin pin) =>
      'Nothing inside the sheet is on ${pin.name} yet';

  /// A pin of [netId] on any sheet, for joining a net to it from a sheet
  /// where it has none.
  String? _anyPinOf(String? netId) =>
      (ref.read(projectNetsProvider(widget.project.id)).value ?? const [])
          .where((n) => n.net.id == netId)
          .firstOrNull
          ?.endpoints
          .firstOrNull
          ?.pin
          .id;

  /// Keeps sheets' pins on their nets when those nets are joined into
  /// [to]: a pin named for the net that is gone would otherwise lose it.
  Future<void> _repointSheetPins(Set<String?> from, String to) async {
    final sheets =
        ref.read(projectSheetsProvider(widget.project.id)).value ??
        const <SchematicSheet>[];
    final repository = ref.read(sheetRepositoryProvider);
    for (final sheet in sheets) {
      if (!sheet.pins.any((p) => p.netId != to && from.contains(p.netId))) {
        continue;
      }
      await repository.update(
        sheet.copyWith(
          pins: [
            for (final pin in sheet.pins)
              from.contains(pin.netId) ? pin.withNet(to) : pin,
          ],
        ),
      );
    }
  }

  /// Joins a pin to the net a sheet's pin carries into the sheet, and draws
  /// the wire the drag took there. Drawn always: nothing routes a wire to
  /// a sheet's pin by itself, so without it there would be nothing to see.
  Future<void> _connectToSheetPin(
    SchematicScene scene,
    String fromId,
    SheetBoxPin target,
  ) async {
    final corners = _wireCorners;
    ref.read(pendingPinProvider.notifier).set(null);
    setState(() => _wireCorners = const []);
    final net = target.net;
    final into = net?.endpoints.firstOrNull?.pin.id;
    if (net == null || into == null) {
      _notify(_emptySheetPin(target));
      return;
    }
    final from = scene.pins.where((p) => p.id == fromId).firstOrNull;
    if (from == null) return;

    final repository = ref.read(netRepositoryProvider);
    final projectId = widget.project.id;
    final sheetId = _currentSheet;
    final points = DrawnWireGeometry.orthogonalPath([
      from.sheetPosition,
      ...corners,
      target.at,
    ]);
    try {
      final snapshot = await repository.capture(projectId, [fromId, into]);
      SchematicWire? drawn;
      Future<String> join() async {
        final joined = (await repository.connectPins(fromId, into)).net.id;
        await _repointSheetPins({from.netId, net.id}, joined);
        return joined;
      }

      await _atomically(() async {
        final joined = await join();
        drawn = await repository.addWire(
          sheetId: sheetId,
          projectId: projectId,
          points: points,
          pinAId: fromId,
          netId: joined,
        );
      });
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() => _highlightedNetId = null);
      _notify('Wire to ${target.name}');
      _record(
        'Connect ${from.label} to ${target.name}',
        undo: () async {
          if (drawn case final wire?) await repository.deleteWire(wire.id);
          await repository.restore(snapshot);
        },
        redo: () async {
          final joined = await join();
          if (drawn case final wire?) {
            await repository.restoreWire(wire.copyWith(netId: joined));
          }
        },
      );
    } on InvalidConnectionException catch (e) {
      if (mounted) _notify(e.message);
    }
  }

  Future<void> _connectPins(
    SchematicScene scene,
    String fromId,
    PlacedPin pin,
  ) async {
    if (fromId == pin.id) return;
    final fromLabel = scene.pins
        .where((p) => p.id == fromId)
        .map((p) => p.label)
        .firstOrNull;

    ref.read(pendingPinProvider.notifier).set(null);
    final repository = ref.read(netRepositoryProvider);
    try {
      // Taken before the edit: connecting can merge two nets, and afterwards
      // there is no way to reconstruct which pins came from where.
      final snapshot = await repository.capture(widget.project.id, [
        fromId,
        pin.id,
      ]);
      final net = await repository.connectPins(fromId, pin.id);
      final drawn = await _storeDrawnWire(scene, fromId, pin);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() => _highlightedNetId = net.id);
      _record(
        'Connect ${fromLabel ?? "pin"} to ${pin.label}',
        undo: () => repository.restore(snapshot),
        redo: () async {
          final redone = await repository.connectPins(fromId, pin.id);
          if (drawn != null) {
            await repository.restoreWire(drawn.copyWith(netId: redone.net.id));
          }
        },
      );
    } on InvalidConnectionException catch (e) {
      if (!mounted) return;
      _notify(e.message);
    }
  }

  /// A brief message for things with no visible result of their own, such
  /// as an error or a copy. Anything reversible is reported by the action
  /// bar's undo button instead of by a popup: deleting and connecting happen
  /// often enough that a snackbar after every one was its own annoyance.
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

  void _onScaleStart(
    SchematicScene scene,
    SchematicViewport viewport,
    ScaleStartDetails details,
  ) {
    _gestureStartFocal = details.localFocalPoint;
    _gestureStartLocal = details.localFocalPoint;
    _gestureStartViewport = viewport;
    _isDraggingUnit = false;
    _candidateUnitId = null;
    _dragWires = const [];

    // Note which symbol is under the finger, but do not commit to moving it
    // yet. Deciding here — as this used to, by asking whether the touch was
    // near a pin — meant that on a small part every touch looked like a pin
    // and dragging simply would not start. Whether this is a drag or a tap
    // is a question about movement, so it is answered on movement.
    _candidateWire = null;
    _dragNet = const [];

    _candidateLabel = null;
    _candidateNote = null;
    _candidateSheet = null;

    if (details.pointerCount == 1) {
      // Decided where the finger landed, not where the recogniser caught
      // up with it — see [_touchDown].
      final sheet = viewport.toSheet(_touchDown ?? details.localFocalPoint);

      // A label sits on top of everything and is the smallest thing on the
      // sheet you are meant to pick up, so it wins the touch outright.
      final label = _labelAt(scene, sheet);
      // Only the net's own label moves; a repeat at another piece of the
      // net stays where that piece is.
      if (label != null && label.primary) {
        _candidateLabel = label;
        _dragStartSheet = sheet;
        _dragOriginalPosition = label.position;
        return;
      }

      // A press on a sheet's pin pulls a wire out of it, on the net the pin
      // carries into the sheet — ahead of the box itself, which the pin
      // sits on the edge of.
      if (!_placing && !_boxSelecting && _selectedUnitIds.isEmpty) {
        final grab = math.max(0.6, 14 / viewport.pixelsPerMm);
        if (_boxPinNear(sheet, grab) case final boxPin?) {
          if (boxPin.net case final net?) {
            _branchFrom = boxPin.at;
            _branchNetId = net.id;
            _branchTo = null;
            return;
          }
          _notify(_emptySheetPin(boxPin));
        }
      }

      // A picked sheet's box moves under the finger that lands on it.
      if (_sheetBoxes.where((b) => b.sheet.id == _selectedSheetId).firstOrNull
          case final view? when view.box.contains(sheet)) {
        _candidateSheet = view.sheet;
        _dragStartSheet = sheet;
        _dragOriginalPosition = view.sheet.box.topLeft;
        return;
      }

      // A selected note moves under the finger that lands on it.
      if (_notes.where((n) => n.id == _selectedNoteId).firstOrNull
          case final note? when note.hit(sheet, _hitToleranceMm(viewport))) {
        _candidateNote = note;
        _dragStartSheet = sheet;
        _dragOriginalPosition = note.position;
        return;
      }

      // A press right on a pin — or on the loose end of the wire being
      // drawn — drags a wire out of it. Tighter than a tap's target, so a
      // part can still be picked up by its body right next to its pins.
      // Not with a group selected: a touch on it moves the group.
      if (!_tapWiring &&
          !_placing &&
          !_boxSelecting &&
          _selectedUnitIds.isEmpty) {
        final grab = math.max(0.6, 14 / viewport.pixelsPerMm);
        final pendingId = ref.read(pendingPinProvider);
        final end = _wireEnd(scene);
        if (pendingId != null &&
            end != null &&
            (end - sheet).distance <= grab) {
          _wireDragging = true;
          return;
        }
        final pin = scene.pinNear(sheet, grab);
        if (pin != null) {
          ref.read(pendingPinProvider.notifier).set(pin.id);
          setState(() {
            _wireCorners = const [];
            _selectedWireKey = null;
            _selectedWireRun = null;
            _selectedUnitId = null;
            _highlightedNetId = pin.netId;
          });
          _wireDragging = true;
          return;
        }
      }

      final unit = scene.unitAt(sheet);

      // A drag anywhere on the group — a symbol in it, or one of its
      // wires — moves the whole group.
      final grabbedUnit =
          unit != null && _selectedUnitIds.contains(unit.unit.id);
      final grabbedWire =
          _selectedWireIds.isNotEmpty &&
          _selectedWireIds.contains(
            scene.wireRunNear(sheet, _wireToleranceMm(viewport))?.wire.drawnId,
          );
      if (grabbedUnit || grabbedWire) {
        _groupDragging = true;
        _candidateUnitId = grabbedUnit ? unit.unit.id : null;
        _dragStartSheet = sheet;
        _dragOriginalPosition = grabbedUnit
            ? Offset(unit.unit.x, unit.unit.y)
            : sheet;
        _dragOriginals = {
          for (final member in scene.units)
            if (_selectedUnitIds.contains(member.unit.id))
              member.unit.id: Offset(member.unit.x, member.unit.y),
        };
        _dragWires = _selectionWires(scene);
        return;
      }

      // Anywhere else, in Select mode, sweeps a box.
      if (_boxSelecting) {
        _boxFrom = sheet;
        return;
      }

      final hit = scene.wireRunNear(sheet, _wireToleranceMm(viewport));

      // Nearer wins, the same way a tap resolves. A symbol's hit box
      // stretches to the tip of every pin, so a wire running close beside a
      // part sits inside it; letting the symbol win outright meant that
      // wire could be neither selected nor dragged.
      final unitDistance = unit == null
          ? double.infinity
          : scene.distanceToBody(unit, sheet);
      final wireDistance = hit == null
          ? double.infinity
          : hit.wire.distanceTo(sheet);

      if (unit != null && unitDistance <= wireDistance) {
        _candidateUnitId = unit.unit.id;
        _dragStartSheet = sheet;
        _dragOriginalPosition = Offset(unit.unit.x, unit.unit.y);
        _dragOriginals = {unit.unit.id: _dragOriginalPosition};
        _dragWires = _wiresCarriedBy(scene, {unit.unit.id});
        return;
      }

      // Near the end of the run under the finger, a drag pulls a new wire
      // out of that point instead of moving the wire.
      //
      // Only the wire actually being touched can offer this, and only
      // within a third of the run's length of its own end: anything wider
      // and a touch aimed at a short wire ends up pulling a wire out of a
      // neighbour's corner, which is not what the finger was on.
      if (hit != null && !_boxSelecting && _selectedUnitIds.isEmpty) {
        final ends = [hit.wire.points[hit.run], hit.wire.points[hit.run + 1]];
        final nearest =
            (ends.first - sheet).distance <= (ends.last - sheet).distance
            ? ends.first
            : ends.last;
        final reach = math.min(
          math.max(0.6, 10 / viewport.pixelsPerMm),
          (ends.first - ends.last).distance / 3,
        );
        if ((nearest - sheet).distance < reach &&
            scene.pinNear(nearest, 0.01) == null) {
          _branchFrom = nearest;
          _branchNetId = hit.wire.netId;
          _branchTo = null;
          return;
        }
      }

      // The run of a wire under the finger slides instead.
      if (hit != null) {
        _candidateWire = hit;
        _dragStartSheet = sheet;
        // The net as it is drawn right now, kept for the whole gesture. It
        // has to be the drawn shapes, because the run under the finger is
        // numbered against those; and it has to be taken once, because the
        // sheet acquires the drag as it goes and reading it again would
        // pile each frame's movement on the last.
        _dragNet = _netAsPolylines(scene, hit.wire.netId);
      }
    }
  }

  /// The label under [sheet], with the target grown to a finger's width at
  /// the current zoom.
  NetLabel? _labelAt(SchematicScene scene, Offset sheet) {
    final viewport = _viewport;
    if (viewport == null) return null;
    // At least the drawn box, and at least 8 mm across on screen.
    final slack = math.max(0.0, (16 / viewport.pixelsPerMm));
    return scene.labelNear(
      sheet,
      halfHeightMm: (label) =>
          SchematicPainter.labelHalfHeightMm(label.size) + slack,
      halfWidthMm: (label) =>
          SchematicPainter.labelHalfWidthMm(label.text, label.size) + slack,
    );
  }

  void _onScaleUpdate(SchematicScene scene, ScaleUpdateDetails details) {
    final start = _gestureStartViewport;
    if (start == null) return;

    if (_boxFrom != null && details.pointerCount == 1) {
      setState(() => _boxTo = start.toSheet(details.localFocalPoint));
      return;
    }

    if (_branchFrom != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled < _dragSlopPx) return;
      final sheet = start.toSheet(details.localFocalPoint);
      final pin = scene.pinNear(sheet, _hitToleranceMm(start));
      setState(() {
        _isDraggingUnit = true;
        _branchTo =
            pin?.sheetPosition ??
            _boxPinNear(sheet, _hitToleranceMm(start))?.at ??
            _snapToGrid(sheet);
      });
      return;
    }

    if (_wireDragging && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled < _dragSlopPx) return;
      final sheet = start.toSheet(details.localFocalPoint);
      // Onto a pin under the finger exactly — a part's or a sheet's —
      // otherwise onto the grid.
      final pin = scene.pinNear(sheet, _hitToleranceMm(start));
      setState(() {
        _isDraggingUnit = true;
        _wireDragAt =
            pin?.sheetPosition ??
            _boxPinNear(sheet, _hitToleranceMm(start))?.at ??
            _snapToGrid(sheet);
      });
      return;
    }

    if (_candidateSheet != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() => _isDraggingUnit = true);
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        setState(() {
          _draggingSheetAt = _snapToGrid(
            _dragOriginalPosition + (sheet - _dragStartSheet),
          );
        });
      }
      return;
    }

    if (_candidateNote != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() => _isDraggingUnit = true);
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        setState(() {
          _draggingNoteAt = _snapToGrid(
            _dragOriginalPosition + (sheet - _dragStartSheet),
          );
        });
      }
      return;
    }

    final label = _candidateLabel;
    if (label != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() {
          _isDraggingUnit = true;
          _highlightedNetId = label.netId;
        });
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        setState(() {
          _draggingLabelAt = _snapToGrid(
            _dragOriginalPosition + (sheet - _dragStartSheet),
          );
        });
      }
      return;
    }

    final candidate = _candidateWire;
    if (candidate != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() => _isDraggingUnit = true);
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        final delta = _snapToGrid(sheet - _dragStartSheet);

        // In the segment model the piece goes where the finger goes, and
        // whatever shares its ends is brought along by the rules rather
        // than by this code noticing anything.
        if (_segmentWiring) {
          final segments = _segmentDrag(scene, candidate.wire, delta);
          if (segments != null) {
            setState(() {
              _draggingSegments = segments;
              _draggingSegmentNet = candidate.wire.netId;
            });
            return;
          }
        }

        // Worked out by the wiring rules, which are put through every
        // shape a net can take in their own tests: the wire moves and what
        // is joined to it comes along, or the drag stops short rather than
        // tearing the drawing apart.
        final result = PolylineWiring.drag(
          _dragNet,
          candidate.wire.key,
          candidate.run,
          delta,
        );
        if (result.dragged.isEmpty) return;
        setState(() {
          _draggingWireKey = candidate.wire.key;
          _draggingWirePoints = result.dragged;
          _draggingNeighbours = result.followers;
        });
      }
      return;
    }

    final candidateId = _candidateUnitId;
    if ((candidateId != null || _groupDragging) && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() {
          _isDraggingUnit = true;
          if (_selectedUnitIds.isEmpty && candidateId != null) {
            _selectedUnitId = candidateId;
          }
        });
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        final delta = sheet - _dragStartSheet;
        // The grabbed part snaps and the rest keep their places relative to
        // it, rather than each snapping on its own and shuffling.
        final shift =
            _snapToGrid(_dragOriginalPosition + delta) - _dragOriginalPosition;
        setState(() {
          _draggingShift = shift;
          _draggingUnits = {
            for (final entry in _dragOriginals.entries)
              entry.key: entry.value + shift,
          };
        });
        return;
      }
      // Below the threshold this is still a tap in progress; fall through to
      // panning would fight the finger, so do nothing at all.
      return;
    }

    setState(() {
      final zoomed = start.copyWith(
        pixelsPerMm: (start.pixelsPerMm * details.scale).clamp(0.5, 40.0),
      );
      // Keep the point under the fingers fixed while zooming, then apply the
      // pan for this gesture.
      final anchorSheet = start.toSheet(_gestureStartFocal);
      _viewport = zoomed.copyWith(
        origin: Offset(
          details.localFocalPoint.dx - anchorSheet.dx * zoomed.pixelsPerMm,
          details.localFocalPoint.dy - anchorSheet.dy * zoomed.pixelsPerMm,
        ),
      );
    });
  }

  void _onScaleEnd() {
    if (_branchFrom case final from?) {
      final to = _branchTo;
      final netId = _branchNetId;
      final dragged = _isDraggingUnit;
      _branchFrom = null;
      _branchTo = null;
      _branchNetId = null;
      _isDraggingUnit = false;
      _gestureStartViewport = null;
      final scene = _scene;
      if (dragged && to != null && netId != null && scene != null) {
        _dropBranch(scene, from, to, netId);
      } else {
        setState(() {});
      }
      return;
    }

    if (_wireDragging) {
      final at = _wireDragAt;
      final dragged = _isDraggingUnit;
      _wireDragging = false;
      _wireDragAt = null;
      _isDraggingUnit = false;
      _gestureStartViewport = null;
      final scene = _scene;
      if (dragged && at != null && scene != null) {
        _dropWire(scene, at);
      } else {
        setState(() {});
      }
      return;
    }

    final boxFrom = _boxFrom;
    final boxTo = _boxTo;
    if (boxFrom != null) {
      _boxFrom = null;
      _boxTo = null;
      _gestureStartViewport = null;
      final scene = _scene;
      if (boxTo == null || scene == null) {
        setState(() {});
        return;
      }
      // Wholly inside, the same as the board's box: a part the box only
      // clips was not what was being swept up.
      final box = Rect.fromPoints(boxFrom, boxTo).inflate(1e-6);
      // The hint said how to do this; now it is done, the count says more.
      _hintTimer?.cancel();
      setState(() {
        _hint = null;
        _selectedUnitIds = {
          for (final unit in scene.units)
            if (box.contains(scene.boundsOf(unit).topLeft) &&
                box.contains(scene.boundsOf(unit).bottomRight))
              unit.unit.id,
        };
        // Wholly inside, the same test the parts get: a wire the box only
        // clips is on its way somewhere else.
        _selectedWireIds = {
          for (final wire in scene.wires)
            if (wire.points.every(box.contains)) ?wire.drawnId,
        };
        // Once something is caught, the box has done its job: the bar
        // turns to what can be done with the group, and a tap on empty
        // sheet lets go of it.
        if (_selectedUnitIds.isNotEmpty || _selectedWireIds.isNotEmpty) {
          _boxSelecting = false;
        }
      });
      return;
    }

    final movedGroup = _isDraggingUnit && _groupDragging;
    final movedUnitId = _isDraggingUnit ? _candidateUnitId : null;
    final nudgedWire = _isDraggingUnit ? _candidateWire : null;
    final movedLabel = _isDraggingUnit ? _candidateLabel : null;
    final movedNote = _isDraggingUnit ? _candidateNote : null;
    _candidateNote = null;
    final movedSheet = _isDraggingUnit ? _candidateSheet : null;
    _candidateSheet = null;

    _candidateUnitId = null;
    _candidateWire = null;
    _candidateLabel = null;
    _gestureStartViewport = null;
    // Cleared here, at the end of the gesture that set it, rather than at
    // the start of the next one. A quick tap can win the gesture arena
    // outright, in which case onScaleStart never runs — so a flag left over
    // from an earlier drag was still set and swallowed that tap. That is why
    // a symbol could not be deselected straight after being moved. A real
    // drag rejects the tap recogniser, so clearing it now cannot cause a
    // drag to be mistaken for a tap.
    _isDraggingUnit = false;

    _groupDragging = false;
    if (movedUnitId != null || movedGroup) _commitMove();
    if (nudgedWire != null) _finishWireSlide(nudgedWire);
    if (movedLabel != null) _recordLabelMove(movedLabel);
    if (movedNote != null) {
      _recordNoteMove(movedNote);
    } else if (_draggingNoteAt != null) {
      setState(() => _draggingNoteAt = null);
    }
    if (movedSheet != null) {
      _recordSheetMove(movedSheet);
    } else if (_draggingSheetAt != null) {
      setState(() => _draggingSheetAt = null);
    }
  }

  // --- sheets ----------------------------------------------------------

  /// The boxes for the sheets on this one, and a name at every pin whose
  /// net carries on to another sheet.
  void _sheetViews(SchematicScene scene, List<NetWithEndpoints> nets) {
    final sheets =
        ref.watch(projectSheetsProvider(widget.project.id)).value ??
        const <SchematicSheet>[];
    if (sheets.isEmpty) {
      _sheetBoxes = const [];
      _offSheetLabels = const [];
      return;
    }
    final open = ref.watch(openSheetProvider(widget.project.id));
    final links = SheetConnections.of(
      parts:
          ref.watch(projectPartsProvider(widget.project.id)).value ?? const [],
      nets: nets,
      sheets: sheets,
    );
    final (boxes, labels) = sheetOverlays(
      links: links,
      scene: scene,
      sheetId: open,
      moving: _candidateSheet,
      movedTo: _draggingSheetAt,
    );
    _sheetBoxes = boxes;
    _offSheetLabels = [
      for (final label in labels)
        if (!_labelledNets.contains(label.netId)) label,
    ];
  }

  /// Where on the hierarchy this sheet is — Top › Power › Regulator —
  /// each step back up a tap away. Only once there are sheets at all.
  Widget? _sheetPath() {
    final sheets =
        ref.watch(projectSheetsProvider(widget.project.id)).value ??
        const <SchematicSheet>[];
    if (sheets.isEmpty) return null;
    final tree = SheetTree(sheets);
    final open = ref.watch(openSheetProvider(widget.project.id));
    final steps = <(String?, String)>[
      (null, 'Top'),
      for (final sheet in tree.pathTo(open)) (sheet.id, sheet.name),
    ];
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        key: const ValueKey('sheet-path'),
        color: KicadPalette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 6),
              Icon(Icons.layers_outlined, size: 16, color: KicadPalette.sheet),
              for (final (i, (id, name)) in steps.indexed) ...[
                if (i > 0)
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: KicadPalette.textDisabled,
                  ),
                TextButton(
                  onPressed: i == steps.length - 1
                      ? null
                      : () => _openSheet(id),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: i == steps.length - 1
                          ? KicadPalette.textPrimary
                          : KicadPalette.wire,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(String? sheetId) {
    ref.read(openSheetProvider(widget.project.id).notifier).open(sheetId);
    setState(() {
      _selectedSheetId = null;
      _selectedUnitId = null;
      _selectedUnitIds = const {};
      _selectedWireIds = const {};
      _selectedNoteId = null;
      _selectedWireKey = null;
      _viewport = null;
    });
  }

  Future<String?> _askSheetName(String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('sheet-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sheet name',
            hintText: 'e.g. Power',
            isDense: true,
          ),
          onSubmitted: (text) => Navigator.of(dialog).pop(text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('sheet-name-ok'),
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSheet(SchematicSheet sheet) async {
    final name = await _askSheetName('Rename sheet', sheet.name);
    if (name == null || name.isEmpty || !mounted) return;
    final repository = ref.read(sheetRepositoryProvider);
    final renamed = await repository.rename(sheet, name);
    _record(
      'Rename ${sheet.name}',
      undo: () => repository.update(sheet),
      redo: () => repository.update(renamed),
    );
  }

  Future<void> _deleteSheet(SchematicSheet sheet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete the ${sheet.name} sheet?'),
        content: const Text(
          'Nothing on it is lost: its parts, wires and sheets move up to '
          'the sheet it is on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('sheet-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repository = ref.read(sheetRepositoryProvider);
    await repository.delete(sheet);
    setState(() => _selectedSheetId = null);
    _notify('${sheet.name} deleted — its contents are on this sheet now');
  }

  Future<void> _recordSheetMove(SchematicSheet sheet) async {
    final to = _draggingSheetAt;
    if (to == null || to == sheet.box.topLeft) {
      setState(() => _draggingSheetAt = null);
      return;
    }
    final repository = ref.read(sheetRepositoryProvider);
    final moved = sheet.copyWith(box: to & sheet.box.size);
    await repository.update(moved);
    if (mounted) setState(() => _draggingSheetAt = null);
    _record(
      'Move ${sheet.name}',
      undo: () => repository.update(sheet),
      redo: () => repository.update(moved),
    );
  }

  /// A new sheet on the open one, its box put where the view is.
  Future<SchematicSheet?> _newSheet() async {
    final name = await _askSheetName('New sheet', '');
    if (name == null || name.isEmpty || !mounted) return null;
    final viewport = _viewport;
    final centre = viewport == null
        ? const Offset(25.4, 25.4)
        : viewport.toSheet(
            Offset(_canvasSize.width / 2, _canvasSize.height / 2),
          );
    final repository = ref.read(sheetRepositoryProvider);
    final added = await repository.add(
      projectId: widget.project.id,
      name: name,
      parentId: ref.read(openSheetProvider(widget.project.id)),
      at: _snapToGrid(centre),
    );
    _record(
      'New sheet ${added.name}',
      undo: () => repository.delete(added),
      redo: () => repository.restore(added),
    );
    return added;
  }

  /// Puts the picked parts, and the wires between them, on another sheet.
  Future<void> _moveToSheet(List<PlacedUnit> group) async {
    final sheets = SheetTree(
      ref.read(projectSheetsProvider(widget.project.id)).value ?? const [],
    );
    final open = ref.read(openSheetProvider(widget.project.id));
    const newSheet = '\u0000new';
    final target = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text('Move ${group.length} to'),
        children: [
          if (open != null)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialog).pop(''),
              child: const Text('Top sheet'),
            ),
          for (final sheet in sheets.inPageOrder())
            if (sheet.id != open)
              SimpleDialogOption(
                key: ValueKey('move-to-${sheet.name}'),
                onPressed: () => Navigator.of(dialog).pop(sheet.id),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12.0 * (sheets.depthOf(sheet.id) - 1),
                  ),
                  child: Text(sheets.pathName(sheet.id)),
                ),
              ),
          SimpleDialogOption(
            key: const ValueKey('move-to-new-sheet'),
            onPressed: () => Navigator.of(dialog).pop(newSheet),
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: KicadPalette.wire),
                const SizedBox(width: 8),
                const Text('New sheet…'),
              ],
            ),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    String? sheetId;
    if (target == newSheet) {
      final added = await _newSheet();
      if (added == null) return;
      sheetId = added.id;
    } else {
      sheetId = target.isEmpty ? null : target;
    }

    final repository = ref.read(sheetRepositoryProvider);
    final unitIds = {for (final u in group) u.unit.id};
    final wireIds = {..._selectedWireIds};
    var move = await repository.moveToSheet(
      projectId: widget.project.id,
      unitIds: unitIds,
      wireIds: wireIds,
      sheetId: sheetId,
    );
    final name =
        sheets.byId(sheetId)?.name ??
        (sheetId == null ? 'the top sheet' : 'the new sheet');
    setState(() {
      _selectedUnitIds = const {};
      _selectedWireIds = const {};
    });
    _record(
      'Move ${group.length} to $name',
      undo: () => repository.undoMove(move),
      redo: () async => move = await repository.moveToSheet(
        projectId: widget.project.id,
        unitIds: unitIds,
        wireIds: wireIds,
        sheetId: sheetId,
      ),
    );
    _notify('Moved to $name — connections that cross now show as labels');
  }

  // --- notes -----------------------------------------------------------

  SchematicNote? _noteAt(Offset sheet, SchematicViewport viewport) {
    final tolerance = math.max(0.8, 10 / viewport.pixelsPerMm);
    for (final note in _notes.reversed) {
      if (note.hit(sheet, tolerance)) return note;
    }
    return null;
  }

  Future<void> _addNote(SchematicScene scene) async {
    final viewport = _viewport;
    final result = await showNoteDialog(context);
    if (result == null || !mounted) return;
    // Where the user last tapped the sheet, or the middle of the view.
    final at = _snapToGrid(
      _lastTapSheet ??
          (viewport == null
              ? Offset.zero
              : viewport.toSheet(
                  Offset(_canvasSize.width / 2, _canvasSize.height / 2),
                )),
    );
    final repository = ref.read(noteRepositoryProvider);
    final note = await repository.add(
      projectId: widget.project.id,
      kind: result.kind,
      content: result.content,
      position: at,
      size: result.size,
      textSize: result.textSize,
    );
    if (!mounted) return;
    setState(() => _selectedNoteId = note.id);
    _record(
      note.kind == NoteKind.box ? 'Add a box' : 'Add a note',
      undo: () => repository.delete(note.id),
      redo: () => repository.restore(note),
    );
  }

  Future<void> _editNote(SchematicNote note) async {
    final result = await showNoteDialog(context, existing: note);
    if (result == null || !mounted) return;
    final repository = ref.read(noteRepositoryProvider);
    final after = note.copyWith(
      kind: result.kind,
      content: result.content,
      size: result.size,
      textSize: result.textSize,
    );
    await repository.update(after);
    _record(
      'Edit a note',
      undo: () => repository.update(note),
      redo: () => repository.update(after),
    );
  }

  Future<void> _deleteNote(SchematicNote note) async {
    final repository = ref.read(noteRepositoryProvider);
    await repository.delete(note.id);
    if (mounted) setState(() => _selectedNoteId = null);
    _record(
      'Delete a note',
      undo: () => repository.restore(note),
      redo: () => repository.delete(note.id),
    );
  }

  Future<void> _recordNoteMove(SchematicNote note) async {
    final after = _draggingNoteAt;
    if (after == null || after == note.position) {
      setState(() => _draggingNoteAt = null);
      return;
    }
    final repository = ref.read(noteRepositoryProvider);
    final moved = note.copyWith(position: after);
    await repository.update(moved);
    if (mounted) setState(() => _draggingNoteAt = null);
    _record(
      'Move a note',
      undo: () => repository.update(note),
      redo: () => repository.update(moved),
    );
  }

  /// Writes a dragged label's new home, once, when the finger lifts.
  Future<void> _recordLabelMove(NetLabel label) async {
    final repository = ref.read(netRepositoryProvider);
    final after = _draggingLabelAt;
    setState(() => _draggingLabelAt = null);
    if (after == null || after == label.position) return;

    // Null when the label had never been moved, so undo puts it back on the
    // wire corner rather than pinning it where it already looked pinned.
    final before = label.pinned ? label.position : null;
    await repository.setNetLabelPosition(label.netId, after);
    _record(
      'Move ${label.text} label',
      undo: () => repository.setNetLabelPosition(label.netId, before),
      redo: () => repository.setNetLabelPosition(label.netId, after),
    );
  }

  /// Splits every stored wire that runs straight through a junction.
  ///
  /// A junction is where wires end: two wires either side of one are two
  /// wires, and dragging one leaves the junction, and the other, where
  /// they are. A branch drawn in the app splits the wire it comes off
  /// there and then; wires drawn before that, or brought in from a KiCad
  /// file, a starter circuit or a paste, can still run through one, and
  /// are split here as soon as the sheet sees them. The drawing looks the
  /// same either way, so this is a repair rather than an edit, and is not
  /// put on the undo list.
  Future<void> _splitStoredJunctions(List<SchematicWire> drawn) async {
    if (_tidying || _isDraggingUnit || _wireDragging) return;
    final nets = SheetWires.netsWithUnsplitJunctions(drawn);
    if (nets.isEmpty) return;
    final wires = _sheetWires;
    _tidying = true;
    try {
      await wires.repository.transaction(() async {
        for (final netId in nets) {
          await wires.trimRetracedEnds(netId);
          await wires.splitAtJunctions(netId);
        }
      });
    } finally {
      _tidying = false;
    }
  }

  /// The open sheet's drawn wires and the rules that tidy them. Taken at
  /// the start of an edit and held by its undo steps, so taking the edit
  /// back works on the sheet it was made on, even with another sheet open
  /// or the schematic no longer on screen.
  SheetWires get _sheetWires => SheetWires(
    ref.read(netRepositoryProvider),
    projectId: widget.project.id,
    sheetId: _currentSheet,
  );

  /// Runs a multi-write edit as one change: it lands whole or not at all,
  /// and the sheet redraws once for it rather than once per write.
  Future<void> _atomically(Future<void> Function() edit) =>
      ref.read(editTransactionProvider)(edit);

  /// The sheet open in this project's schematic; null for the top sheet.
  String? get _currentSheet => ref.read(openSheetProvider(widget.project.id));

  /// Whether the segment model is in force.
  bool get _segmentWiring =>
      ref.read(appearanceProvider).wiring == WiringModel.segments;

  /// A net's wires as straight pieces, each keeping the row it came from so
  /// an edit can be written back as an update rather than a delete.
  static List<WireSegment> _segmentsOfNet(List<SchematicWire> wires) => [
    for (final wire in wires)
      for (var i = 0; i < wire.points.length - 1; i++)
        WireSegment(
          id: i == 0 ? wire.id : null,
          a: wire.points[i],
          b: wire.points[i + 1],
          pinA: i == 0 ? wire.pinAId : null,
          pinB: i == wire.points.length - 2 ? wire.pinBId : null,
        ),
  ];

  /// Where the pins of [netId] are, which the segment rules treat as fixed
  /// points.
  List<Offset> _pinsOfNet(SchematicScene scene, String netId) => [
    for (final pin in scene.pinsByNet[netId] ?? const <PlacedPin>[])
      pin.sheetPosition,
  ];

  /// Tidies the drawing into the segment model: pieces split where another
  /// ends against them, pieces in a line joined, pieces lying over each
  /// other rolled into one.
  ///
  /// Nothing is moved — the drawing is the same drawing — so this is not an
  /// edit and does not go on the undo stack. It is how a sheet drawn in the
  /// classic model, or by an older version, comes across.
  Future<void> _tidyIntoSegments(
    List<SchematicWire> drawn,
    SchematicScene scene,
  ) async {
    if (_tidying || identical(drawn, _tidiedWires)) return;
    _tidiedWires = drawn;

    final byNet = <String, List<SchematicWire>>{};
    for (final wire in drawn) {
      (byNet[wire.netId] ??= []).add(wire);
    }

    final work = <String, List<WireSegment>>{};
    for (final entry in byNet.entries) {
      final segments = _segmentsOfNet(entry.value);
      final tidy = SegmentWiring.canonicalise(
        segments,
        pins: _pinsOfNet(scene, entry.key),
      );
      if (!_sameSegments(segments, tidy)) work[entry.key] = tidy;
    }
    if (work.isEmpty || !mounted) return;

    final wires = _sheetWires;
    _tidying = true;
    try {
      await wires.repository.transaction(() async {
        for (final entry in work.entries) {
          await wires.writeSegments(entry.key, byNet[entry.key]!, entry.value);
        }
      });
    } finally {
      _tidying = false;
    }
  }

  static bool _sameSegments(List<WireSegment> a, List<WireSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].a - b[i].a).distance > SegmentWiring.tolerance ||
          (a[i].b - b[i].b).distance > SegmentWiring.tolerance) {
        return false;
      }
    }
    return true;
  }

  /// The whole net as it would be with the piece under the finger moved by
  /// [shift] — everything joined to it coming along.
  List<WireSegment>? _segmentDrag(
    SchematicScene scene,
    RoutedWire wire,
    Offset shift,
  ) {
    final id = wire.drawnId;
    if (id == null) return null;
    final drawn =
        ref.read(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];
    final rows = [
      for (final row in drawn)
        if (row.netId == wire.netId) row,
    ];
    return SegmentWiring.drag(
      _segmentsOfNet(rows),
      id,
      shift,
      pins: _pinsOfNet(scene, wire.netId),
    );
  }

  /// Writes a finished segment drag, as one undoable step.
  Future<void> _commitSegmentDrag(String netId) async {
    final segments = _draggingSegments;
    final repository = ref.read(netRepositoryProvider);
    final wires = _sheetWires;
    setState(() {
      _draggingSegments = null;
      _draggingSegmentNet = null;
      _draggingWireKey = null;
      _draggingWirePoints = null;
    });
    if (segments == null) return;

    final scene = _scene;
    final snapshot = await repository.capture(widget.project.id, [
      for (final pin in _landedPins(scene, segments, netId)) pin,
    ]);

    final before = await wires.ofNet(netId);

    // An end that has come to rest on a pin joins it to the net, the way
    // dropping a wire on a pin does anywhere else.
    final landed = <WireSegment>[];
    for (final segment in segments) {
      var piece = segment;
      if (segment.pinA == null && scene != null) {
        final pin = scene.pinNear(segment.a, _landingMm);
        if (pin != null) piece = piece.copyWith(pinA: pin.id);
      }
      if (segment.pinB == null && scene != null) {
        final pin = scene.pinNear(segment.b, _landingMm);
        if (pin != null) piece = piece.copyWith(pinB: pin.id);
      }
      landed.add(piece);
    }
    await _atomically(() async {
      await _joinLandedPins(scene, landed, netId);
      await wires.writeSegments(netId, before, landed);
    });
    final after = await wires.ofNet(netId);
    if (_sameWires(before, after)) return;

    _record(
      'Move wire',
      undo: () async {
        await wires.restoreNetWires(netId, before);
        await repository.restore(snapshot);
      },
      redo: () => wires.restoreNetWires(netId, after),
    );
  }

  /// The pins the ends of [segments] have come to rest on.
  List<String> _landedPins(
    SchematicScene? scene,
    List<WireSegment> segments,
    String netId,
  ) {
    if (scene == null) return const [];
    return [
      for (final segment in segments)
        for (final end in [segment.a, segment.b])
          ?scene.pinNear(end, _landingMm)?.id,
    ];
  }

  /// Joins whatever pins the wire has landed on to its net.
  Future<void> _joinLandedPins(
    SchematicScene? scene,
    List<WireSegment> segments,
    String netId,
  ) async {
    if (scene == null) return;
    final repository = ref.read(netRepositoryProvider);
    for (final pin in _landedPins(scene, segments, netId).toSet()) {
      final on = await repository.netIdForPin(pin);
      if (on == netId) continue;
      final member = (scene.pinsByNet[netId] ?? const <PlacedPin>[])
          .where((p) => p.id != pin)
          .firstOrNull;
      try {
        if (member == null) {
          await repository.addPinToNet(netId, pin);
        } else {
          await repository.connectPins(member.id, pin);
        }
      } on InvalidConnectionException catch (e) {
        if (mounted) _notify(e.message);
      }
    }
  }

  static bool _sameWires(List<SchematicWire> a, List<SchematicWire> b) {
    if (a.length != b.length) return false;
    for (final wire in a) {
      final other = b.where((w) => w.id == wire.id).firstOrNull;
      if (other == null || !_samePoints(wire.points, other.points)) {
        return false;
      }
    }
    return true;
  }

  /// Writes a finished drag, once, as one undoable step.
  ///
  /// Parts and the wires travelling with them move by the same amount, so
  /// a piece of circuit keeps its shape wherever it is put down.
  Future<void> _commitMove() async {
    final live = _draggingUnits;
    final originals = _dragOriginals;
    final wiresBefore = _dragWires;
    final shift = _draggingShift;
    _dragWires = const [];
    _draggingShift = Offset.zero;

    final repository = ref.read(partRepositoryProvider);
    final nets = ref.read(netRepositoryProvider);
    final parts = ref.read(sheetPartsProvider(widget.project.id)).value;
    if (parts == null) {
      setState(() => _draggingUnits = null);
      return;
    }

    final before = <PartUnit>[];
    final after = <PartUnit>[];
    String? reference;
    for (final part in parts) {
      for (final unit in part.units) {
        final at = live?[unit.id];
        final was = originals[unit.id];
        if (at == null || was == null) continue;
        before.add(unit.copyWith(x: was.dx, y: was.dy));
        after.add(unit.copyWith(x: at.dx, y: at.dy, placed: true));
        reference = part.part.reference;
      }
    }

    final wiresAfter = [
      for (final wire in wiresBefore)
        wire.copyWith(points: [for (final p in wire.points) p + shift]),
    ];
    final moved =
        shift.distance > 1e-6 && (after.isNotEmpty || wiresAfter.isNotEmpty);

    Future<void> write(List<PartUnit> units, List<SchematicWire> wires) async {
      for (final unit in units) {
        await repository.updateUnitPlacement(unit);
      }
      for (final wire in wires) {
        await nets.updateWire(wire);
      }
    }

    if (moved) await _atomically(() => write(after, wiresAfter));
    // Let go of the live positions only once the database holds them, so
    // the part does not flick back to where it started for a frame.
    if (mounted) setState(() => _draggingUnits = null);
    if (!moved) return;

    _record(
      switch ((after.length, wiresAfter.length)) {
        (1, 0) => 'Move $reference',
        (0, final wires) => 'Move $wires ${wires == 1 ? "wire" : "wires"}',
        (final units, _) => 'Move $units parts',
      },
      undo: () => write(before, wiresBefore),
      redo: () => write(after, wiresAfter),
    );
  }

  /// How close a dragged end has to come to a pin to land on it, in
  /// millimetres of sheet. A shade over half the 1.27 mm grid the drag
  /// snaps to, so a deliberate drop onto a pin lands and one a grid square
  /// away does not.
  static const double _landingMm = 0.7;

  /// Writes a finished slide. A wire the app had routed becomes one the
  /// user drew, so it keeps the shape it was given.
  ///
  /// Where its ends come to rest decides what it connects: dropped on a
  /// pin, that pin joins the net; dragged off the pin it was on, it lets go
  /// of it — the way dragging a wire works in KiCad. The ends are written
  /// too, so the wire stays where it was put instead of springing back to
  /// the pins it was first drawn between.
  /// Writes a wire drag down, and whatever happens doing so, lets go of it.
  ///
  /// The dragged shape is drawn over the stored one until this clears it.
  /// A write that failed part-way used to leave it there, so the wire sat
  /// frozen where the finger left it and would not be dragged again.
  Future<void> _finishWireSlide(WireRunHit hit) async {
    try {
      await _commitWireSlide(hit);
    } catch (error) {
      _notify('That move could not be saved: $error');
    } finally {
      if (mounted &&
          (_draggingWireKey != null ||
              _draggingWirePoints != null ||
              _draggingNeighbours.isNotEmpty)) {
        setState(() {
          _draggingWireKey = null;
          _draggingWirePoints = null;
          _draggingNeighbours = const {};
        });
      }
      _dragNet = const [];
    }
  }

  Future<void> _commitWireSlide(WireRunHit hit) async {
    final sheetId = _currentSheet;
    if (_draggingSegments != null && _draggingSegmentNet != null) {
      final netId = _draggingSegmentNet!;
      await _commitSegmentDrag(netId);
      return;
    }

    final repository = ref.read(netRepositoryProvider);
    final scene = _scene;
    final points = _draggingWirePoints;
    if (points == null || _samePoints(points, hit.wire.points)) {
      setState(() {
        _draggingWireKey = null;
        _draggingWirePoints = null;
        _draggingNeighbours = const {};
      });
      return;
    }

    final projectId = widget.project.id;
    final drawn =
        ref.read(schematicWiresProvider(projectId)).value ??
        const <SchematicWire>[];
    final drawnId = hit.wire.drawnId;
    final oldA = hit.wire.pinAId.isEmpty ? null : hit.wire.pinAId;
    final oldB = hit.wire.pinBId.isEmpty ? null : hit.wire.pinBId;
    final newA = scene?.pinNear(points.first, _landingMm)?.id;
    final newB = scene?.pinNear(points.last, _landingMm)?.id;

    // Only worth rewiring when a pin is involved. With no pin at either
    // end there is nothing to hold the net up, and this is an ordinary
    // change of shape.
    if ((newA == oldA && newB == oldB) ||
        (newA == null && newB == null && oldA == null && oldB == null)) {
      await _writeSlide(hit, points);
      return;
    }

    // Taken before anything moves: joining a pin can merge two nets, and
    // afterwards there is no telling where the seam was.
    final snapshot = await repository.capture(projectId, [
      ?oldA,
      ?oldB,
      ?newA,
      ?newB,
    ]);

    /// Whether some other wire still reaches [pin], in which case this one
    /// letting go of it does not take it off the net.
    bool heldElsewhere(String pin) => drawn.any(
      (w) => w.id != drawnId && (w.pinAId == pin || w.pinBId == pin),
    );

    final stored =
        ref.read(schematicWiresProvider(projectId)).value ??
        const <SchematicWire>[];
    final followedBefore = <SchematicWire>[];
    final followedAfter = <SchematicWire>[];
    for (final entry in _draggingNeighbours.entries) {
      final wire = stored.where((w) => w.id == entry.key).firstOrNull;
      if (wire == null) continue;
      followedBefore.add(wire);
      followedAfter.add(wire.copyWith(points: entry.value));
    }

    Future<void> follow(List<SchematicWire> wires) async {
      for (final wire in wires) {
        await repository.updateWire(wire);
      }
    }

    SchematicWire? laid;

    /// Lays the wire again between whatever its ends now rest on.
    ///
    /// Written as a fresh wire rather than edited in place because letting
    /// go of a pin can leave its net with nothing on it, and an empty net
    /// is tidied away — taking any wire still pointing at it along too.
    Future<void> rewire() async {
      await follow(followedAfter);

      // Joined first, so the net the wire is going on exists before
      // anything is taken away, and laid down before the old one is
      // deleted. Letting go of a pin can leave a net with nothing on it,
      // and an emptied net takes every wire pointing at it along with it —
      // which once wiped a whole net's drawing off the sheet.
      final ends = [?newA, ?newB];
      String? netId;
      try {
        netId = switch (ends.length) {
          2 => (await repository.connectPins(ends[0], ends[1])).net.id,
          1 => await repository.netForPin(projectId, ends.single),
          _ => (await repository.getNet(hit.wire.netId))?.net.id,
        };
      } on InvalidConnectionException catch (e) {
        _notify(e.message);
        netId = await repository.netForPin(projectId, ends.first);
      }
      if (netId == null) return;

      final replacement = await repository.addWire(
        sheetId: sheetId,
        projectId: projectId,
        points: points,
        pinAId: newA,
        pinBId: newB,
        netId: netId,
      );
      if (replacement == null) return;
      laid = replacement;

      if (drawnId != null) await repository.deleteWire(drawnId);
      for (final (was, now) in [(oldA, newA), (oldB, newB)]) {
        if (was != null && was != now && !heldElsewhere(was)) {
          await repository.disconnectPin(was);
        }
      }
    }

    await _atomically(rewire);
    if (!mounted) return;

    final landedOn = [
      if (newA != null && newA != oldA) newA,
      if (newB != null && newB != oldB) newB,
    ].firstOrNull;
    final label = scene?.pins
        .where((p) => p.id == landedOn)
        .map((p) => p.label)
        .firstOrNull;
    _notify(label == null ? 'Wire let go of its pin' : 'Wire joined to $label');

    setState(() {
      _draggingWireKey = null;
      _draggingWirePoints = null;
      _draggingNeighbours = const {};
      _selectedWireKey = laid?.id;
      _selectedWireRun = laid == null ? null : hit.run;
    });
    _record(
      'Rewire',
      undo: () async {
        if (laid case final wire?) await repository.deleteWire(wire.id);
        await repository.restore(snapshot);
        await follow(followedBefore);
      },
      redo: rewire,
    );
  }

  /// The net the wire belongs to, as the wiring rules see it: the shapes on
  /// the sheet, with the pins their ends are held by.
  /// A net as it is drawn on the sheet, with the pins each wire's ends are
  /// held by.
  ///
  /// The shapes are the drawn ones rather than the stored ones: a wire is
  /// stored as the user left it and drawn with its ends pulled onto its
  /// pins, so the two can have different corners — and the run under the
  /// finger is numbered against what is drawn.
  List<PolylineWire> _netAsPolylines(SchematicScene scene, String netId) {
    final stored = {
      for (final wire
          in ref.read(sheetWiresProvider(widget.project.id)).value ??
              const <SchematicWire>[])
        wire.id: wire,
    };
    return [
      for (final wire in scene.wires)
        if (wire.netId == netId)
          PolylineWire(
            id: wire.key,
            points: wire.points,
            pinA: wire.pinAId.isEmpty ? null : wire.pinAId,
            pinB: wire.pinBId.isEmpty ? null : wire.pinBId,
          ),
    ]..removeWhere((wire) => stored[wire.id] == null && wire.id.isEmpty);
  }

  /// Writes a slide that only changed a wire's shape.
  Future<void> _writeSlide(WireRunHit hit, List<Offset> points) async {
    final sheetId = _currentSheet;
    final repository = ref.read(netRepositoryProvider);
    final stored =
        ref.read(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];

    // The wire itself and every wire stretched to stay joined to it, all
    // written together so one undo puts the lot back.
    final before = <SchematicWire>[];
    final after = <SchematicWire>[];
    for (final entry in _draggingNeighbours.entries) {
      final wire = stored.where((w) => w.id == entry.key).firstOrNull;
      if (wire == null) continue;
      before.add(wire);
      after.add(wire.copyWith(points: entry.value));
    }
    final drawnId = hit.wire.drawnId;
    if (drawnId != null) {
      final wire = stored.where((w) => w.id == drawnId).firstOrNull;
      if (wire != null) {
        before.add(wire);
        after.add(wire.copyWith(points: points));
      }
    }

    Future<void> write(List<SchematicWire> wires) async {
      for (final wire in wires) {
        await repository.updateWire(wire);
      }
    }

    // Wires brought end to end in a straight line become one, and putting
    // that back is part of taking the move back.
    // The net's wires as they stood before tidying, which is what taking
    // the tidying back puts back.
    var untidied = const <SchematicWire>[];
    final sheet = _sheetWires;

    Future<void> join() async {
      final netId = hit.wire.netId;
      untidied = await sheet.ofNet(netId);
      await sheet.tidyNet(netId);
    }

    Future<void> unjoin() async {
      await sheet.restoreNetWires(hit.wire.netId, untidied);
      untidied = const [];
    }

    if (drawnId != null) {
      if (after.isNotEmpty) {
        await _atomically(() async {
          await write(after);
          await join();
        });
        _record(
          'Move wire',
          undo: () async {
            await unjoin();
            await write(before);
          },
          redo: () async {
            await write(after);
            await join();
          },
        );
      }
    } else {
      // A wire the app had routed becomes one the user drew, so it keeps
      // the shape it was given.
      final added = await ref.read(editTransactionProvider)(() async {
        await write(after);
        final added = await repository.addWire(
          sheetId: sheetId,
          projectId: widget.project.id,
          points: points,
          pinAId: hit.wire.pinAId,
          pinBId: hit.wire.pinBId,
          netId: hit.wire.netId,
        );
        if (added != null) await join();
        return added;
      });
      if (added != null) {
        _record(
          'Move wire',
          undo: () async {
            await unjoin();
            await repository.deleteWire(added.id);
            await write(before);
          },
          redo: () async {
            await write(after);
            await repository.restoreWire(added);
            await join();
          },
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _draggingWireKey = null;
      _draggingWirePoints = null;
      _draggingNeighbours = const {};
      _selectedWireKey = hit.wire.key;
      _selectedWireRun = hit.run;
    });
  }

  /// Takes one run of a wire away, instead of the whole net.
  ///
  /// The rest of the drawing stays exactly where it was. Cutting between
  /// two pins parts them — the far pin leaves the net unless another wire
  /// still reaches it — because the nets are what the design actually is:
  /// a gap drawn in a wire that changed nothing would be a lie.
  Future<void> _cutWire(RoutedWire wire, int run) async {
    final sheetId = _currentSheet;
    final repository = ref.read(netRepositoryProvider);
    final projectId = widget.project.id;
    final pinA = wire.pinAId.isEmpty ? null : wire.pinAId;
    final pinB = wire.pinBId.isEmpty ? null : wire.pinBId;
    final drawn =
        ref.read(schematicWiresProvider(projectId)).value ??
        const <SchematicWire>[];
    final snapshot = await repository.capture(projectId, [?pinA, ?pinB]);

    bool heldElsewhere(String pin) => drawn.any(
      (w) => w.id != wire.drawnId && (w.pinAId == pin || w.pinBId == pin),
    );

    final points = wire.points;
    final head = points.sublist(0, run + 1);
    final tail = points.sublist(run + 1);
    final added = <SchematicWire>[];

    /// The net a piece of the cut wire belongs on afterwards: its pin's
    /// net, made afresh if the parting left that pin on nothing — an
    /// unnamed net of one pin is tidied away, and it would take the piece
    /// of wire with it.
    Future<String?> netFor(String? pin) async {
      if (pin != null) return repository.netForPin(projectId, pin);
      final net = await repository.getNet(wire.netId);
      return net?.net.id;
    }

    Future<void> cut() async {
      added.clear();
      final drawnId = wire.drawnId;
      if (drawnId == null) {
        // Nothing was drawn: this line is the connection itself, so cutting
        // it is taking the connection away.
        final pin = pinB ?? pinA;
        if (pin != null && !heldElsewhere(pin)) {
          await repository.disconnectPin(pin);
        }
        return;
      }

      await repository.deleteWire(drawnId);

      // Pin B is on the far side of the gap, so unless something else still
      // reaches it, it comes off the net. So does pin A when the cut leaves
      // it with no wire at all.
      if (pinB != null && !heldElsewhere(pinB)) {
        await repository.disconnectPin(pinB);
      }
      if (head.length < 2 && pinA != null && !heldElsewhere(pinA)) {
        await repository.disconnectPin(pinA);
      }

      // Both pieces stay exactly where they were drawn.
      if (head.length >= 2) {
        final net = await netFor(pinA);
        final laid = net == null
            ? null
            : await repository.addWire(
                sheetId: sheetId,
                projectId: projectId,
                points: head,
                pinAId: pinA,
                netId: net,
              );
        if (laid != null) added.add(laid);
      }
      if (tail.length >= 2) {
        final net = await netFor(pinB);
        final laid = net == null
            ? null
            : await repository.addWire(
                sheetId: sheetId,
                projectId: projectId,
                points: tail,
                pinBId: pinB,
                netId: net,
              );
        if (laid != null) added.add(laid);
      }
    }

    await cut();
    if (!mounted) return;
    setState(() {
      _selectedWireKey = null;
      _selectedWireRun = null;
      _highlightedNetId = null;
    });
    _record(
      'Cut wire',
      undo: () async {
        for (final piece in added) {
          await repository.deleteWire(piece.id);
        }
        added.clear();
        await repository.restore(snapshot);
      },
      redo: cut,
    );
  }

  static bool _samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distance >= 1e-6) return false;
    }
    return true;
  }

  /// Stores the wire just finished from [fromPinId] through the tapped
  /// corners to [to], if any corners were tapped.
  Future<SchematicWire?> _storeDrawnWire(
    SchematicScene scene,
    String fromPinId,
    PlacedPin to,
  ) async {
    final sheetId = _currentSheet;
    final corners = _wireCorners;
    if (mounted) setState(() => _wireCorners = const []);
    if (corners.isEmpty) return null;
    final from = scene.pins.where((p) => p.id == fromPinId).firstOrNull;
    if (from == null) return null;
    return ref
        .read(netRepositoryProvider)
        .addWire(
          sheetId: sheetId,
          projectId: widget.project.id,
          points: DrawnWireGeometry.orthogonalPath([
            from.sheetPosition,
            ...corners,
            to.sheetPosition,
          ]),
          pinAId: fromPinId,
          pinBId: to.id,
        );
  }

  /// The wire being drawn, from the pending pin through its corners — or
  /// the one being pulled out of a junction.
  List<Offset>? _pendingWire(SchematicScene scene) {
    if (_branchFrom case final from?) {
      final to = _branchTo;
      if (to == null) return null;
      return DrawnWireGeometry.orthogonalPath([from, to]);
    }
    final live = _wireDragAt;
    if (_wireCorners.isEmpty && live == null) return null;
    final pendingId = ref.watch(pendingPinProvider);
    final from = scene.pins.where((p) => p.id == pendingId).firstOrNull;
    if (from == null) return null;
    return DrawnWireGeometry.orthogonalPath([
      from.sheetPosition,
      ..._wireCorners,
      ?live,
    ]);
  }

  /// Where the wire being drawn currently ends: its last corner, or the pin
  /// it started from.
  Offset? _wireEnd(SchematicScene scene) {
    if (_wireCorners.isNotEmpty) return _wireCorners.last;
    final pendingId = ref.read(pendingPinProvider);
    return scene.pins
        .where((p) => p.id == pendingId)
        .firstOrNull
        ?.sheetPosition;
  }

  /// Where a dragged wire was let go: on a pin it connects, on a wire it
  /// joins that net, and anywhere else it leaves a corner to carry on from.
  Future<void> _dropWire(SchematicScene scene, Offset at) async {
    final pendingId = ref.read(pendingPinProvider);
    if (pendingId == null) return;

    final pin = scene.pins
        .where((p) => (p.sheetPosition - at).distance < 1e-6)
        .firstOrNull;
    if (pin != null && pin.id != pendingId) {
      await _connectPins(scene, pendingId, pin);
      return;
    }
    if (_boxPinNear(at, 1e-6) case final boxPin?) {
      await _connectToSheetPin(scene, pendingId, boxPin);
      return;
    }

    final viewport = _viewport;
    final wire = viewport == null
        ? null
        : scene.wireNear(at, _wireToleranceMm(viewport) / 2);
    final pending = scene.pins.where((p) => p.id == pendingId).firstOrNull;
    if (wire != null && wire.netId != pending?.netId) {
      final (run, _) = DrawnWireGeometry.nearestRun(wire.points, at);
      await _joinPinToNet(
        scene,
        pendingId,
        wire.netId,
        endAt: _onRun(wire.points, run, at),
      );
      return;
    }

    if (pending != null && (pending.sheetPosition - at).distance < 1e-6) {
      setState(() {});
      return;
    }
    setState(() => _wireCorners = [..._wireCorners, at]);
  }

  /// Where a wire pulled out of a junction was let go.
  ///
  /// On a pin, that pin joins the net. On a wire of another net, the two
  /// nets become one — which is what drawing a wire between them means. On
  /// empty sheet it is left as a branch of the net it came from, ending in
  /// mid-air, ready to be carried on from its new end.
  Future<void> _dropBranch(
    SchematicScene scene,
    Offset from,
    Offset to,
    String netId,
  ) async {
    final sheetId = _currentSheet;
    final repository = ref.read(netRepositoryProvider);
    final wires = _sheetWires;
    final viewport = _viewport;
    final projectId = widget.project.id;

    final pin = scene.pinNear(to, _landingMm);
    final boxPin = pin == null ? _boxPinNear(to, _landingMm) : null;
    final onto = pin != null || boxPin != null || viewport == null
        ? null
        : scene.wireNear(to, _wireToleranceMm(viewport) / 2);
    if (boxPin != null && boxPin.net == null) {
      _notify(_emptySheetPin(boxPin));
      setState(() {});
      return;
    }

    var end = to;
    if (pin != null) {
      end = pin.sheetPosition;
    } else if (boxPin != null) {
      end = boxPin.at;
    } else if (onto != null) {
      final (run, _) = DrawnWireGeometry.nearestRun(onto.points, to);
      end = _onRun(onto.points, run, to);
    }
    final points = DrawnWireGeometry.orthogonalPath([from, end]);
    if (points.length < 2) {
      setState(() {});
      return;
    }

    // A branch drawn back along the wire it came out of is no branch at
    // all: it lies inside what is already there, and all it leaves behind
    // is a junction dot where nothing actually meets.
    final alongside = [
      for (final wire in scene.wires)
        if (wire.netId == netId) wire.points,
    ];
    final covered =
        [
          for (var i = 0; i < points.length - 1; i++)
            (points[i] + points[i + 1]) / 2,
        ].every(
          (at) => alongside.any(
            (path) => DrawnWireGeometry.nearestRun(path, at).$2 < 0.01,
          ),
        );
    if (covered) {
      _notify('Already wired along there');
      setState(() {});
      return;
    }

    // A net here may have no pin on this sheet at all — one pulled out of
    // a sheet's pin, or dropped on one — so a pin of it is looked for on
    // any sheet.
    final member =
        (scene.pinsByNet[netId] ?? const <PlacedPin>[]).firstOrNull?.id ??
        _anyPinOf(netId);
    final ontoNet = pin?.netId ?? boxPin?.net?.id ?? onto?.netId;
    final joinTo =
        pin?.id ??
        boxPin?.net?.endpoints.firstOrNull?.pin.id ??
        (onto == null
            ? null
            : (scene.pinsByNet[onto.netId] ?? const <PlacedPin>[])
                      .firstOrNull
                      ?.id ??
                  _anyPinOf(onto.netId));
    final joins = joinTo != null && ontoNet != netId;

    final snapshot = await repository.capture(projectId, [?joinTo, ?member]);

    // Carrying a wire on in the direction it was already going makes that
    // wire longer. Two wires in a straight line with nothing between them
    // are one wire, and cutting or dragging them should treat them as one.
    final carriedOn = _wireExtendedBy(from, points, netId, pin?.id);

    SchematicWire? laid;
    var splitBefore = const <SchematicWire>[];
    var splitAdded = const <SchematicWire>[];
    Future<void> draw() async {
      var net = netId;
      if (joins) {
        if (member == null) {
          await repository.addPinToNet(netId, joinTo);
        } else {
          net = (await repository.connectPins(member, joinTo)).net.id;
        }
        net = await repository.netIdForPin(joinTo) ?? net;
        await _repointSheetPins({netId, ontoNet}, net);
      }
      if (carriedOn case (final wire, final longer, final ends)) {
        await repository.updateWire(wire.copyWith(points: longer));
        await repository.setWireEnds(wire.id, pinAId: ends.$1, pinBId: ends.$2);
        laid = null;
        return;
      }
      laid = await repository.addWire(
        sheetId: sheetId,
        projectId: projectId,
        points: points,
        pinBId: pin?.id,
        netId: net,
      );
      // A wire drawn against the middle of another makes a junction, and
      // either side of a junction is a wire of its own.
      final (cut, pieces) = await wires.splitAtJunctions(net);
      splitBefore = cut;
      splitAdded = pieces;
    }

    try {
      await _atomically(draw);
    } on InvalidConnectionException catch (e) {
      if (mounted) _notify(e.message);
      return;
    }
    if (!mounted) return;

    unawaited(HapticFeedback.lightImpact());
    _notify(
      pin != null
          ? 'Wire to ${pin.label}'
          : boxPin != null
          ? 'Wire to ${boxPin.name}'
          : onto != null
          ? 'Nets joined'
          : 'Branch drawn — drag from its end to carry on',
    );
    setState(() {
      _selectedWireKey = laid?.id ?? carriedOn?.$1.id;
      _selectedWireRun = 0;
    });
    _record(
      pin != null ? 'Wire to ${pin.label}' : 'Branch wire',
      undo: () async {
        for (final piece in splitAdded) {
          await repository.deleteWire(piece.id);
        }
        for (final wire in splitBefore) {
          await repository.updateWire(wire);
          await repository.setWireEnds(
            wire.id,
            pinAId: wire.pinAId,
            pinBId: wire.pinBId,
          );
        }
        splitBefore = const [];
        splitAdded = const [];
        if (laid case final wire?) await repository.deleteWire(wire.id);
        if (carriedOn case (final wire, _, _)) {
          await repository.updateWire(wire);
          await repository.setWireEnds(
            wire.id,
            pinAId: wire.pinAId,
            pinBId: wire.pinBId,
          );
        }
        await repository.restore(snapshot);
      },
      redo: draw,
    );
  }

  /// The wire [points] carries straight on from, if it does: the wire as it
  /// stands, the longer shape it becomes, and the pins of its two ends.
  ///
  /// Only a straight continuation counts. A wire that turns a corner where
  /// another ends is still two wires — the corner is a place a third can be
  /// drawn from — but a line carried on in the same direction is one wire,
  /// and dividing it in two would be an invention of the app's own.
  (SchematicWire, List<Offset>, (String?, String?))? _wireExtendedBy(
    Offset from,
    List<Offset> points,
    String netId,
    String? endPin,
  ) {
    final stored =
        ref.read(sheetWiresProvider(widget.project.id)).value ??
        const <SchematicWire>[];
    for (final wire in stored) {
      if (wire.netId != netId || wire.points.length < 2) continue;

      final atEnd =
          (wire.points.last - from).distance < 0.01 &&
          (wire.pinBId ?? '').isEmpty;
      final atStart =
          (wire.points.first - from).distance < 0.01 &&
          (wire.pinAId ?? '').isEmpty;
      if (!atEnd && !atStart) continue;

      // Only a wire carried straight on: one that turns a corner here is
      // still two wires, and the corner is a place a third can start.
      final head = atEnd ? wire.points : points.reversed.toList();
      final tail = atEnd ? points : wire.points;
      if (!SheetWires.carriesStraightOn(head, tail)) continue;
      final tidied = DrawnWireGeometry.simplify([...head, ...tail.skip(1)]);
      if (tidied.length < 2) continue;

      return (
        wire,
        tidied,
        atEnd ? (wire.pinAId, endPin) : (endPin, wire.pinBId),
      );
    }
    return null;
  }

  /// Ends the wire being drawn where its last corner is, joined to nothing
  /// else yet — the way a wire in KiCad can stop short and be carried on
  /// later.
  Future<void> _finishOpenWire(SchematicScene scene) async {
    final sheetId = _currentSheet;
    final pendingId = ref.read(pendingPinProvider);
    final corners = _wireCorners;
    final from = scene.pins.where((p) => p.id == pendingId).firstOrNull;
    ref.read(pendingPinProvider.notifier).set(null);
    setState(() => _wireCorners = const []);
    if (pendingId == null || from == null || corners.isEmpty) return;

    final points = DrawnWireGeometry.orthogonalPath([
      from.sheetPosition,
      ...corners,
    ]);
    if (points.length < 2) return;

    final repository = ref.read(netRepositoryProvider);
    final snapshot = await repository.capture(widget.project.id, [pendingId]);
    Future<SchematicWire?> lay() async => repository.addWire(
      sheetId: sheetId,
      projectId: widget.project.id,
      points: points,
      pinAId: pendingId,
      netId: await repository.netForPin(widget.project.id, pendingId),
    );
    final wire = await lay();
    if (wire == null || !mounted) return;
    unawaited(HapticFeedback.lightImpact());
    _record(
      'Wire from ${from.label}',
      undo: () async {
        await repository.deleteWire(wire.id);
        await repository.restore(snapshot);
      },
      redo: () async {
        await lay();
      },
    );
  }

  /// The point on run [run] of [points] nearest [at].
  static Offset _onRun(List<Offset> points, int run, Offset at) {
    if (run < 0) return at;
    final a = points[run];
    final b = points[run + 1];
    final d = b - a;
    final length = d.dx * d.dx + d.dy * d.dy;
    if (length < 1e-12) return a;
    final t = (((at - a).dx * d.dx + (at - a).dy * d.dy) / length).clamp(
      0.0,
      1.0,
    );
    return a + d * t;
  }

  /// How far the finger must travel before a touch on a symbol becomes a
  /// move rather than a tap, in logical pixels.
  static const double _dragSlopPx = 8;

  /// Symbols land on KiCad's 1.27 mm schematic grid, which is what keeps
  /// pins meeting cleanly when the file is opened on the desktop.
  Offset _snapToGrid(Offset sheet) => Offset(
    (sheet.dx / 1.27).round() * 1.27,
    (sheet.dy / 1.27).round() * 1.27,
  );
}
