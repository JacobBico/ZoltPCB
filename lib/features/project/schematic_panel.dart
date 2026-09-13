import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/edit_history.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../core/widgets/zoom_controls.dart';
import '../../data/repositories/net_repository.dart';
import '../../domain/models/models.dart';
import '../../rendering/schematic_painter.dart';
import '../../rendering/schematic_scene.dart';
import '../../domain/geometry/placement.dart';
import '../../domain/geometry/placement_finder.dart';
import '../../domain/geometry/wire_router.dart';
import '../../rendering/schematic_viewport.dart';
import '../pinout/pinout_explorer.dart';
import 'nets_panel.dart';
import '../../domain/symbols/symbols.dart';
import 'component_sidebar.dart';
import 'attach_power.dart';
import 'part_editor_dialog.dart';
import 'power_symbol_picker.dart';
import 'canvas_action_bar.dart';

/// The schematic canvas: pan, zoom, move symbols, and connect pins.
///
/// The same tap-to-connect gesture as the net list, on the same shared
/// pending-pin state, so switching between the two views mid-connection
/// keeps its place.
class SchematicPanel extends ConsumerStatefulWidget {
  const SchematicPanel({super.key, required this.project});

  final Project project;

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

  // One run of a wire can be nudged off its automatic route. The run is
  // resolved at grab time so it always slides the way the finger pushes it.
  WireHandleHit? _candidateWire;
  List<double> _wireStartOffsets = const [];

  // The offsets of the wire being dragged right now. Held here and written
  // once when the finger lifts: writing on every move event fired dozens of
  // unawaited database updates that raced each other, so the wire ended up
  // wherever the last one to finish happened to put it rather than under
  // the finger.
  String? _draggingWireKey;
  List<double>? _draggingOffsets;

  // The net label being dragged, and where it has got to. Held live for the
  // same reason as the wire offsets above: one write at the end of the
  // gesture, not one per frame.
  NetLabel? _candidateLabel;
  Offset? _draggingLabelAt;
  Offset _gestureStartLocal = Offset.zero;
  Offset _dragStartSheet = Offset.zero;
  Offset _dragOriginalPosition = Offset.zero;

  // Pan/zoom state.
  Offset _gestureStartFocal = Offset.zero;
  SchematicViewport? _gestureStartViewport;

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
    final partsAsync = ref.watch(projectPartsProvider(widget.project.id));
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

    var scene = _sceneFor(parts, nets, symbols, _routeHints());

    final draggingLabel = _candidateLabel;
    final labelAt = _draggingLabelAt;
    if (draggingLabel != null && labelAt != null) {
      scene = scene.withLabelMoved(draggingLabel.netId, labelAt);
    }

    final pickerOpen = ref.watch(componentPickerOpenProvider);

    // The empty state sits inside the Row rather than short-circuiting it,
    // so the component picker can still open on a blank sheet — which is
    // precisely when it is needed most.
    return Row(
      children: [
        Expanded(
          child: parts.isEmpty ? _emptySheet(pickerOpen) : _canvas(scene),
        ),
        if (pickerOpen)
          ComponentSidebar(
            onAdd: _addFromLibrary,
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
  ) {
    final cached = _cachedScene;
    if (cached != null &&
        identical(parts, _cachedParts) &&
        identical(nets, _cachedNets) &&
        identical(symbols, _cachedSymbols) &&
        identical(hints, _cachedHints)) {
      return cached;
    }

    final scene = SchematicScene.build(
      paper: widget.project.paper,
      parts: parts,
      nets: nets,
      symbols: symbols,
      routeHints: hints,
    );
    _cachedScene = scene;
    _cachedParts = parts;
    _cachedNets = nets;
    _cachedSymbols = symbols;
    _cachedHints = hints;
    return scene;
  }

  /// Stored wire adjustments, with the one being dragged overridden by its
  /// live position so the wire follows the finger.
  Map<String, List<double>> _routeHints() {
    final stored =
        ref.watch(routeHintsProvider(widget.project.id)).value ?? const {};
    final key = _draggingWireKey;
    final live = _draggingOffsets;
    if (key == null || live == null) return stored;
    return {...stored, key: live};
  }

  Widget _emptySheet(bool pickerOpen) => EmptyState(
    icon: Icons.grid_on_outlined,
    title: 'Nothing on the sheet yet',
    message: pickerOpen
        ? 'Pick a component from the list to place it here.'
        : 'Use ADD COMPONENT to place your first part.',
    action: pickerOpen
        ? null
        : OutlinedButton.icon(
            onPressed: () =>
                ref.read(componentPickerOpenProvider.notifier).set(true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ADD COMPONENT'),
          ),
  );

  /// Adds [entry] to the project, landing it where the user last tapped.
  Future<void> _addFromLibrary(SymbolIndexEntry entry) async {
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
    setState(() => _selectedUnitId = added.units.first.id);
    await _recordAddition(added.part.id, 'Add ${added.part.reference}');
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
                        selectedWireKey: _selectedWireKey,
                        pendingPinId: ref.watch(pendingPinProvider),
                        highlightedNetId: _highlightedNetId,
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

  /// The canvas commands.
  ///
  /// Always present, because undo and redo have to be reachable whether or
  /// not something is selected; the object-specific verbs join them when
  /// there is something to apply them to.
  Widget _actionBar(SchematicScene scene) {
    final history = ref.watch(editHistoryProvider);
    final pendingPinId = ref.watch(pendingPinProvider);
    final clipboard = ref.watch(partClipboardProvider);

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
    ];

    var title = '';

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
        actions.addAll(_wireActions(wire, net));
      } else if (clipboard != null) {
        title = 'Copied ${clipboard.value}';
        actions.add(
          CanvasAction(
            label: 'Paste',
            icon: Icons.content_paste,
            onPressed: _paste,
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

  List<CanvasAction> _pinActions(PlacedPin pin) => [
    CanvasAction(
      label: 'GND',
      icon: Icons.vertical_align_bottom,
      onPressed: () => _attachGround(pin),
    ),
    CanvasAction(
      label: 'Power',
      icon: Icons.bolt_outlined,
      onPressed: () => _attachSupply(pin),
    ),
    CanvasAction(
      label: pin.pin.noConnect ? 'Connect' : 'No conn',
      icon: pin.pin.noConnect ? Icons.link : Icons.close,
      onPressed: () => _toggleNoConnect(pin),
    ),
    CanvasAction(
      label: 'Cancel',
      icon: Icons.highlight_off,
      onPressed: () => ref.read(pendingPinProvider.notifier).set(null),
    ),
  ];

  List<CanvasAction> _labelActions(NetLabel label, NetWithEndpoints? net) => [
    CanvasAction(
      label: 'Rename',
      icon: Icons.label_outline,
      onPressed: net == null ? null : () => _labelNet(net),
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
    await repository.renameNet(net.net.id, null);
    if (mounted) setState(() => _selectedLabelNetId = null);
    _record(
      'Unlabel ${before ?? "net"}',
      undo: () => repository.renameNet(net.net.id, before),
      redo: () => repository.renameNet(net.net.id, null),
    );
  }

  List<CanvasAction> _wireActions(RoutedWire wire, NetWithEndpoints? net) => [
    CanvasAction(
      label: 'Straighten',
      icon: Icons.horizontal_rule,
      onPressed: () => _straighten(wire),
    ),
    CanvasAction(
      label: 'Label',
      icon: Icons.label_outline,
      onPressed: net == null ? null : () => _labelNet(net),
    ),
    CanvasAction(
      label: 'Unwire',
      icon: Icons.link_off,
      danger: true,
      onPressed: net == null ? null : () => _deleteNet(net),
    ),
  ];

  /// Puts a wire back on its automatic route.
  Future<void> _straighten(RoutedWire wire) async {
    final repository = ref.read(netRepositoryProvider);
    final before = List<double>.from(
      ref.read(routeHintsProvider(widget.project.id)).value?[wire.key] ??
          const <double>[],
    );
    if (before.isEmpty) return;

    await repository.setRouteHint(
      widget.project.id,
      wire.pinAId,
      wire.pinBId,
      const [],
    );
    _record(
      'Straighten wire',
      undo: () => repository.setRouteHint(
        widget.project.id,
        wire.pinAId,
        wire.pinBId,
        before,
      ),
      redo: () => repository.setRouteHint(
        widget.project.id,
        wire.pinAId,
        wire.pinBId,
        const [],
      ),
    );
  }

  Future<void> _labelNet(NetWithEndpoints net) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NetLabelDialog(initialValue: net.net.name ?? ''),
    );
    if (name == null || !mounted) return;

    final repository = ref.read(netRepositoryProvider);
    final before = net.net.name;
    await repository.renameNet(net.net.id, name);
    _record(
      'Label net',
      undo: () => repository.renameNet(net.net.id, before),
      redo: () => repository.renameNet(net.net.id, name),
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
    CanvasAction(
      label: unit.part.fieldsHidden ? 'Show label' : 'Hide label',
      icon: unit.part.fieldsHidden
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
      onPressed: () => _toggleFields(unit),
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
      label: 'Copy',
      icon: Icons.content_copy,
      onPressed: () => _copy(unit),
    ),
    CanvasAction(
      label: 'Delete',
      icon: Icons.delete_outline,
      danger: true,
      onPressed: () => _delete(unit),
    ),
  ];

  Future<void> _undo() async {
    await ref.read(editHistoryProvider.notifier).undo();
    if (mounted) setState(() => _highlightedNetId = null);
  }

  Future<void> _redo() async {
    await ref.read(editHistoryProvider.notifier).redo();
    if (mounted) setState(() => _highlightedNetId = null);
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

  /// Every power symbol the installed libraries hold.
  Future<List<SymbolIndexEntry>> _powerSymbols() => ref
      .read(symbolLibraryRepositoryProvider)
      .search('', powerOnly: true, limit: 300);

  /// Grounds a pin in one action.
  ///
  /// Ground is placed far more often than everything else put together, so
  /// it skips the chooser entirely: the alternative is six taps — open the
  /// picker, search, place, drag, tap pin, tap pin — repeated across a whole
  /// sheet.
  Future<void> _attachGround(PlacedPin pin) async {
    final entries = await _powerSymbols();
    if (!mounted) return;

    final ground =
        entries.where((e) => e.name.toUpperCase() == 'GND').firstOrNull ??
        entries
            .where((e) => e.name.toUpperCase().startsWith('GND'))
            .firstOrNull;

    if (ground == null) {
      _notify('No ground symbol found — import the KiCad power library');
      return;
    }
    await _attachPower(pin, ground);
  }

  Future<void> _attachSupply(PlacedPin pin) async {
    final entries = await _powerSymbols();
    if (!mounted) return;

    if (entries.isEmpty) {
      _notify('No power symbols found — import the KiCad power library');
      return;
    }
    final chosen = await showPowerSymbolPicker(
      context,
      entries: entries,
      pinLabel: pin.label,
    );
    if (chosen == null || !mounted) return;
    await _attachPower(pin, chosen);
  }

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    );
    await repository.updatePart(after);
    _record(
      'Edit ${after.reference}',
      undo: () => repository.updatePart(before),
      redo: () => repository.updatePart(after),
    );
  }

  /// Takes a symbol's designator and value off the drawing, or puts them
  /// back. Display only — the fields still go into the exported file and
  /// the BOM, so hiding one cannot quietly lose it.
  Future<void> _toggleFields(PlacedUnit unit) async {
    final repository = ref.read(partRepositoryProvider);
    final before = unit.part;
    final after = before.copyWith(fieldsHidden: !before.fieldsHidden);
    await repository.updatePart(after);
    _record(
      after.fieldsHidden
          ? 'Hide ${before.reference} label'
          : 'Show ${before.reference} label',
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

  void _copy(PlacedUnit unit) {
    final details = ref
        .read(projectPartsProvider(widget.project.id))
        .value
        ?.where((p) => p.part.id == unit.part.id)
        .firstOrNull;
    if (details == null) return;
    ref.read(partClipboardProvider.notifier).copy(details.toSpec());
    _notify('${unit.part.reference} copied');
  }

  Future<void> _paste() async {
    final spec = ref.read(partClipboardProvider);
    if (spec == null) return;
    final added = await ref
        .read(partRepositoryProvider)
        .pastePart(widget.project.id, spec, at: _lastTapSheet);
    if (!mounted) return;
    setState(() => _selectedUnitId = added.units.first.id);
    await _recordAddition(added.part.id, 'Paste ${added.part.reference}');
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
    final result = scene.resolveTap(
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
      if (pendingId != null) {
        final wire = scene.wireNear(sheet, _wireToleranceMm(viewport));
        if (wire != null) {
          await _joinPinToNet(scene, pendingId, wire.netId);
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
      }
      // Whichever is actually nearer wins, rather than the symbol always.
      //
      // A symbol's hit box reaches out to the tip of every pin, and wires
      // are deliberately routed to clear the body — which puts them inside
      // that box. Letting the symbol win unconditionally made every wire
      // running close to a part impossible to grab.
      final unit = scene.unitAt(sheet);
      final wire = scene.wireHandleNear(sheet, _wireToleranceMm(viewport));

      final unitDistance = unit == null
          ? double.infinity
          : scene.distanceToBody(unit, sheet);
      final wireDistance = wire == null
          ? double.infinity
          : wire.wire.distanceTo(sheet);

      final wireWins = wire != null && wireDistance < unitDistance;

      setState(() {
        // Tapping the selected symbol again lets go of it. Without a toggle
        // the only way to clear a selection is to find empty sheet, which on
        // a busy drawing can mean hunting for somewhere to tap.
        if (wireWins) {
          final key = wire.wire.key;
          final reselected = key == _selectedWireKey;
          _selectedUnitId = null;
          _selectedWireKey = reselected ? null : key;
          _highlightedNetId = reselected ? null : wire.wire.netId;
        } else {
          _selectedUnitId = (unit == null || unit.unit.id == _selectedUnitId)
              ? null
              : unit.unit.id;
          _selectedWireKey = null;
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
    await _tapPin(scene, pin);
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
    String netId,
  ) async {
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
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _highlightedNetId = netId;
        _selectedWireKey = null;
      });
      _record(
        'Connect ${pin?.label ?? "pin"} to ${net?.displayName ?? "net"}',
        undo: () => repository.restore(snapshot),
        redo: () => repository.addPinToNet(netId, pinId),
      );
    } on InvalidConnectionException catch (e) {
      if (!mounted) return;
      _notify(e.message);
    }
  }

  Future<void> _tapPin(SchematicScene scene, PlacedPin pin) async {
    final notifier = ref.read(pendingPinProvider.notifier);
    final pending = ref.read(pendingPinProvider);

    // A wire was picked first: the tap finishes the connection onto its net,
    // the mirror of tapping the wire second.
    final selectedWire = scene.wires
        .where((w) => w.key == _selectedWireKey)
        .firstOrNull;
    if (pending == null && selectedWire != null) {
      await _joinPinToNet(scene, pin.id, selectedWire.netId);
      return;
    }

    if (pending == null) {
      notifier.set(pin.id);
      setState(() {
        _selectedWireKey = null;
        _highlightedNetId = pin.netId;
      });
      return;
    }
    if (pending == pin.id) {
      notifier.set(null);
      return;
    }

    final fromLabel = scene.pins
        .where((p) => p.id == pending)
        .map((p) => p.label)
        .firstOrNull;

    notifier.set(null);
    final repository = ref.read(netRepositoryProvider);
    try {
      // Taken before the edit: connecting can merge two nets, and afterwards
      // there is no way to reconstruct which pins came from where.
      final snapshot = await repository.capture(widget.project.id, [
        pending,
        pin.id,
      ]);
      final net = await repository.connectPins(pending, pin.id);
      if (!mounted) return;
      // Felt as well as seen: the second pin is under the finger that
      // tapped it.
      HapticFeedback.lightImpact();
      setState(() => _highlightedNetId = net.id);
      _record(
        'Connect ${fromLabel ?? "pin"} to ${pin.label}',
        undo: () => repository.restore(snapshot),
        redo: () async {
          await repository.connectPins(pending, pin.id);
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

    // Note which symbol is under the finger, but do not commit to moving it
    // yet. Deciding here — as this used to, by asking whether the touch was
    // near a pin — meant that on a small part every touch looked like a pin
    // and dragging simply would not start. Whether this is a drag or a tap
    // is a question about movement, so it is answered on movement.
    _candidateWire = null;

    _candidateLabel = null;

    if (details.pointerCount == 1) {
      // Decided where the finger landed, not where the recogniser caught
      // up with it — see [_touchDown].
      final sheet = viewport.toSheet(_touchDown ?? details.localFocalPoint);

      // A label sits on top of everything and is the smallest thing on the
      // sheet you are meant to pick up, so it wins the touch outright.
      final label = _labelAt(scene, sheet);
      if (label != null) {
        _candidateLabel = label;
        _dragStartSheet = sheet;
        _dragOriginalPosition = label.position;
        return;
      }

      final unit = scene.unitAt(sheet);
      final hit = scene.wireHandleNear(sheet, _wireToleranceMm(viewport));

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
        return;
      }

      // The run of a wire under the finger slides instead.
      if (hit != null) {
        _candidateWire = hit;
        _dragStartSheet = sheet;
        _wireStartOffsets = List<double>.from(
          ref
                  .read(routeHintsProvider(widget.project.id))
                  .value?[hit.wire.key] ??
              const <double>[],
        );
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
      halfHeightMm: SchematicPainter.labelHeightMm + slack,
      halfWidthMm: (label) =>
          SchematicPainter.labelHalfWidthMm(label.text) + slack,
    );
  }

  void _onScaleUpdate(SchematicScene scene, ScaleUpdateDetails details) {
    final start = _gestureStartViewport;
    if (start == null) return;

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
        final delta = sheet - _dragStartSheet;
        final shift = candidate.handle.moveAxis == WireAxis.horizontal
            ? delta.dx
            : delta.dy;
        setState(() {
          _draggingWireKey = candidate.wire.key;
          _draggingOffsets = _offsetsWith(candidate.handle.offsetIndex, shift);
        });
      }
      return;
    }

    final candidateId = _candidateUnitId;
    if (candidateId != null && details.pointerCount == 1) {
      final travelled = (details.localFocalPoint - _gestureStartLocal).distance;
      if (!_isDraggingUnit && travelled > _dragSlopPx) {
        setState(() {
          _isDraggingUnit = true;
          _selectedUnitId = candidateId;
        });
      }
      if (_isDraggingUnit) {
        final sheet = start.toSheet(details.localFocalPoint);
        final delta = sheet - _dragStartSheet;
        final moved = _snapToGrid(_dragOriginalPosition + delta);
        final unit = scene.units
            .where((u) => u.unit.id == candidateId)
            .firstOrNull;
        if (unit != null) unawaitedMove(unit.unit, moved);
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
    final movedUnitId = _isDraggingUnit ? _candidateUnitId : null;
    final nudgedWire = _isDraggingUnit ? _candidateWire : null;
    final movedLabel = _isDraggingUnit ? _candidateLabel : null;

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

    if (movedUnitId != null) _recordMove(movedUnitId);
    if (nudgedWire != null) _recordNudge(nudgedWire);
    if (movedLabel != null) _recordLabelMove(movedLabel);
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

  /// Records a completed drag as one undoable step, rather than the hundreds
  /// of intermediate positions the gesture actually wrote.
  void _recordMove(String unitId) {
    final repository = ref.read(partRepositoryProvider);
    final parts = ref.read(projectPartsProvider(widget.project.id)).value;
    if (parts == null) return;

    for (final part in parts) {
      for (final unit in part.units) {
        if (unit.id != unitId) continue;
        final before = unit.copyWith(
          x: _dragOriginalPosition.dx,
          y: _dragOriginalPosition.dy,
        );
        if ((before.x - unit.x).abs() < 1e-6 &&
            (before.y - unit.y).abs() < 1e-6) {
          return;
        }
        final after = unit;
        _record(
          'Move ${part.part.reference}',
          undo: () => repository.updateUnitPlacement(before),
          redo: () => repository.updateUnitPlacement(after),
        );
        return;
      }
    }
  }

  /// The stored offsets with one entry displaced by [shift].
  List<double> _offsetsWith(int index, double shift) {
    final offsets = List<double>.from(_wireStartOffsets);
    while (offsets.length <= index) {
      offsets.add(0);
    }
    offsets[index] = _wireStartOffsets.length > index
        ? _wireStartOffsets[index] + shift
        : shift;
    return offsets;
  }

  Future<void> _recordNudge(WireHandleHit hit) async {
    final repository = ref.read(netRepositoryProvider);
    final before = _wireStartOffsets;
    final after = _draggingOffsets ?? before;
    setState(() {
      _draggingWireKey = null;
      _draggingOffsets = null;
    });
    if (_sameOffsets(before, after)) return;

    await repository.setRouteHint(
      widget.project.id,
      hit.wire.pinAId,
      hit.wire.pinBId,
      after,
    );

    _record(
      'Move wire',
      undo: () => repository.setRouteHint(
        widget.project.id,
        hit.wire.pinAId,
        hit.wire.pinBId,
        before,
      ),
      redo: () => repository.setRouteHint(
        widget.project.id,
        hit.wire.pinAId,
        hit.wire.pinBId,
        after,
      ),
    );
  }

  static bool _sameOffsets(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() >= 1e-6) return false;
    }
    return true;
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

  void unawaitedMove(PartUnit unit, Offset position) {
    ref
        .read(partRepositoryProvider)
        .updateUnitPlacement(
          unit.copyWith(x: position.dx, y: position.dy, placed: true),
        );
  }
}
