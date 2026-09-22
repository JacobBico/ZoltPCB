import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/editors/own_library_store.dart';
import '../../domain/editors/symbol_design.dart';
import '../../domain/geometry/placement.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart';
import '../../rendering/renderable_pin.dart';
import '../../rendering/schematic_viewport.dart';
import '../../rendering/symbol_renderer.dart';
import 'editor_requests.dart';
import 'footprint_match_dialog.dart';

/// Makes component symbols: a body of any shape, pins put where you want
/// them, and a footprint matched to it.
class SymbolEditorPanel extends ConsumerStatefulWidget {
  const SymbolEditorPanel({super.key});

  @override
  ConsumerState<SymbolEditorPanel> createState() => _SymbolEditorPanelState();
}

class _SymbolEditorPanelState extends ConsumerState<SymbolEditorPanel> {
  SymbolDesign _design = const SymbolDesign(
    name: 'New_Symbol',
    pins: [
      PinDesign(number: '1', name: 'IN'),
      PinDesign(number: '2', name: 'OUT', side: PinSide.right),
    ],
  );

  /// The saved symbol being edited, or null for a new one.
  String? _editing;

  /// Bumped whenever the form is refilled, so its fields start afresh.
  int _generation = 0;
  List<SymbolDefinition> _saved = const [];

  /// The pin being dragged or last touched, by index.
  int? _selectedPin;
  SchematicViewport? _viewport;

  /// The footprint the symbol names, once looked up, for the match check.
  FootprintDefinition? _footprint;
  String _footprintLookedUp = '';

  OwnLibraryStore get _store => ref.read(ownLibraryStoreProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<SymbolDefinition> saved;
    try {
      saved = await _store.loadSymbols();
    } catch (error) {
      if (mounted) _reportLoadError(error);
      return;
    }
    if (!mounted) return;
    setState(() => _saved = saved);
    _takeRequest();
  }

  void _reportLoadError(Object error) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text('Could not read My Library: $error')));

  /// Opens a symbol My Library asked for.
  void _takeRequest() {
    final wanted = ref.read(symbolToEditProvider);
    if (wanted == null) return;
    final symbol = _saved.where((s) => s.name == wanted).firstOrNull;
    if (symbol == null) return;
    ref.read(symbolToEditProvider.notifier).open(null);
    _open(symbol);
  }

  void _update(SymbolDesign design) => setState(() => _design = design);

  void _open(SymbolDefinition? symbol) => setState(() {
    _editing = symbol?.name;
    _design = symbol == null
        ? const SymbolDesign(
            name: 'New_Symbol',
            pins: [
              PinDesign(number: '1', name: 'IN'),
              PinDesign(number: '2', name: 'OUT', side: PinSide.right),
            ],
          )
        : SymbolDesign.from(symbol);
    _selectedPin = null;
    _generation++;
  });

  String? get _problem {
    if (!RegExp(r'^[A-Za-z0-9_.+-]+$').hasMatch(_design.name)) {
      return 'Name: letters, digits, _ . + - and no spaces';
    }
    if (_design.pins.any((p) => p.number.trim().isEmpty)) {
      return 'Every pin needs a number';
    }
    final numbers = _design.pins.map((p) => p.number).toList();
    if (numbers.toSet().length != numbers.length) {
      return 'Two pins share a number';
    }
    if (_editing != _design.name && _saved.any((s) => s.name == _design.name)) {
      return 'You already have a symbol called ${_design.name}';
    }
    return null;
  }

  Future<void> _save() async {
    await _store.saveSymbol(_design.build(), previousName: _editing);
    await _reload();
    if (!mounted) return;
    setState(() => _editing = _design.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${_design.name} to My Symbols — it is in Add component now',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final name = _editing;
    if (name == null) return;
    final sure = await _confirm(
      'Delete $name?',
      'Designs already using it keep their copy of the pins.',
    );
    if (!sure) return;
    await _store.deleteSymbol(name);
    await _reload();
    _open(null);
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _matchFootprint() async {
    final chosen = await showFootprintMatchDialog(
      context,
      pinNumbers: [for (final p in _design.pins) p.number],
      current: _design.footprint,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _design = _design.copyWith(footprint: chosen);
      _generation++;
    });
  }

  Future<void> _lookUpFootprint() async {
    final wanted = _design.footprint;
    if (wanted == _footprintLookedUp) return;
    _footprintLookedUp = wanted;
    final loaded = wanted.isEmpty
        ? null
        : await ref
              .read(footprintLibraryRepositoryProvider)
              .loadFootprint(wanted);
    if (mounted && _footprintLookedUp == wanted) {
      setState(() => _footprint = loaded);
    }
  }

  Future<void> _addPins() async {
    final count = TextEditingController(text: '4');
    final start = TextEditingController(text: '${_nextNumber()}');
    var side = PinSide.left;
    var type = PinElectricalType.passive;
    final added = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add pins'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'How many',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: start,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'First number',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<PinSide>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in PinSide.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {side},
                  onSelectionChanged: (v) => setDialog(() => side = v.first),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PinElectricalType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final entry in _PinRow.types.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (v) => type = v ?? type,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
    final n = int.tryParse(count.text) ?? 0;
    final first = int.tryParse(start.text) ?? _nextNumber();
    count.dispose();
    start.dispose();
    if (added != true || n <= 0) return;
    setState(() {
      _design = _design.copyWith(
        pins: [
          ..._design.pins,
          for (var i = 0; i < n; i++)
            PinDesign(number: '${first + i}', name: '', side: side, type: type),
        ],
      );
      _generation++;
    });
  }

  int _nextNumber() {
    final numbers = _design.pins.map((p) => int.tryParse(p.number) ?? 0);
    return (numbers.isEmpty ? 0 : numbers.reduce(math.max)) + 1;
  }

  // --- dragging pins ---------------------------------------------------

  /// Symbol space (Y up) from a point on the preview.
  SymbolPoint? _toSymbol(Offset local) {
    final viewport = _viewport;
    if (viewport == null) return null;
    final sheet = viewport.toSheet(local);
    return SymbolPoint(sheet.dx, -sheet.dy);
  }

  int? _pinNear(Offset local) {
    final at = _toSymbol(local);
    final viewport = _viewport;
    if (at == null || viewport == null) return null;
    final placed = _design.placedPins();
    final tolerance = math.max(1.5, 28 / viewport.pixelsPerMm);
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < placed.length; i++) {
      final pin = placed[i];
      final radians = pin.angle * math.pi / 180;
      // Anywhere along the stub, not only its tip: the stub is what you see.
      for (final t in [0.0, 0.5, 1.0]) {
        final x = pin.at.x + math.cos(radians) * pin.length * t;
        final y = pin.at.y + math.sin(radians) * pin.length * t;
        final d = math.sqrt(math.pow(x - at.x, 2) + math.pow(y - at.y, 2));
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
    }
    return bestDistance <= tolerance ? best : null;
  }

  /// The pin under the finger, while it is being dragged.
  int? _draggingPin;
  Offset? _dragAt;

  /// Moves the dragged pin round the body after the finger: freely while it
  /// moves, onto the 1.27 mm grid once it lifts, so wires meet the pin on a
  /// grid point without the pin jumping from point to point under the finger.
  void _dragPinTo(int index, Offset local, {required bool snap}) {
    final at = _toSymbol(local);
    if (at == null) return;
    final pins = [..._design.pins];
    pins[index] = _design.slidePin(index, at, snap: snap);
    setState(() => _design = _design.copyWith(pins: pins));
  }

  /// Puts every dragged pin back on its side.
  void _autoArrange() => setState(() {
    _design = _design.copyWith(
      pins: [for (final pin in _design.pins) pin.copyWith(unplace: true)],
    );
    _generation++;
  });

  @override
  Widget build(BuildContext context) {
    final symbol = _design.build();
    final problem = _problem;
    final theme = Theme.of(context);
    _lookUpFootprint();
    final match = _footprint == null
        ? null
        : PinPadMatch.of([for (final p in _design.pins) p.number], _footprint!);

    return Row(
      children: [
        Expanded(child: _preview(symbol, theme.schematic)),
        Container(
          width: 460,
          decoration: BoxDecoration(
            color: KicadPalette.surface,
            border: Border(left: BorderSide(color: KicadPalette.borderStrong)),
          ),
          child: DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _editing,
                          hint: const Text('New symbol'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('New symbol'),
                            ),
                            for (final s in _saved)
                              DropdownMenuItem(
                                value: s.name,
                                child: Text(s.name),
                              ),
                          ],
                          onChanged: (name) => _open(
                            _saved.where((s) => s.name == name).firstOrNull,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'New symbol',
                        icon: const Icon(Icons.add),
                        onPressed: () => _open(null),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Body'),
                    Tab(text: 'Pins'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_detailsTab(match), _bodyTab(), _pinsTab()],
                  ),
                ),
                Divider(height: 1, color: KicadPalette.border),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      if (problem != null)
                        Expanded(
                          child: Text(
                            problem,
                            style: TextStyle(
                              color: KicadPalette.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (_editing != null)
                        TextButton(
                          onPressed: _delete,
                          child: Text(
                            'DELETE',
                            style: TextStyle(color: KicadPalette.error),
                          ),
                        ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: problem == null ? _save : null,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('SAVE'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview(SymbolDefinition symbol, SchematicColors colors) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          // The view holds still while a pin is dragged. Re-fitting it to
          // the symbol every frame zoomed out as the pin went out, which
          // moved the pin away from the finger, which dragged it further.
          if (_draggingPin == null || _viewport == null) {
            _viewport = _SymbolPreview.fit(symbol, size);
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: (d) =>
                      setState(() => _selectedPin = _pinNear(d.localPosition)),
                  onPanStart: (d) {
                    final index = _pinNear(d.localPosition);
                    if (index == null) return;
                    setState(() {
                      _draggingPin = index;
                      _dragAt = d.localPosition;
                      _selectedPin = index;
                    });
                  },
                  onPanUpdate: (d) {
                    final index = _draggingPin;
                    if (index == null) return;
                    _dragAt = d.localPosition;
                    _dragPinTo(index, d.localPosition, snap: false);
                  },
                  onPanEnd: (_) {
                    final index = _draggingPin;
                    final at = _dragAt;
                    if (index != null && at != null) {
                      _dragPinTo(index, at, snap: true);
                    }
                    setState(() {
                      _draggingPin = null;
                      _dragAt = null;
                    });
                  },
                  onPanCancel: () => setState(() {
                    _draggingPin = null;
                    _dragAt = null;
                  }),
                  child: CustomPaint(
                    painter: _SymbolPreview(
                      symbol,
                      colors,
                      viewport: _viewport!,
                      selectedPin: _selectedPin,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 8,
                child: Text(
                  'Drag a pin round the body · it settles on the 1.27 mm '
                  'grid when you let go',
                  style: TextStyle(
                    color: colors.fieldText.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: ActionChip(
                  avatar: const Icon(Icons.auto_awesome_mosaic, size: 16),
                  label: const Text('Auto-arrange pins'),
                  onPressed: _autoArrange,
                ),
              ),
            ],
          );
        },
      );

  Widget _detailsTab(PinPadMatch? match) => ListView(
    key: ValueKey('details-$_generation'),
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    children: [
      Row(
        children: [
          Expanded(
            flex: 3,
            child: _Field(
              label: 'Name',
              value: _design.name,
              onChanged: (v) => _update(_design.copyWith(name: v.trim())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Field(
              label: 'Reference',
              value: _design.reference,
              onChanged: (v) => _update(_design.copyWith(reference: v.trim())),
            ),
          ),
        ],
      ),
      _Field(
        label: 'Value',
        value: _design.value,
        onChanged: (v) => _update(_design.copyWith(value: v)),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOOTPRINT',
                  style: TextStyle(
                    color: KicadPalette.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  _design.footprint.isEmpty ? 'None yet' : _design.footprint,
                  overflow: TextOverflow.ellipsis,
                ),
                if (match != null)
                  Text(
                    match.describe(),
                    style: TextStyle(
                      fontSize: 12,
                      color: match.isExact
                          ? KicadPalette.success
                          : KicadPalette.warning,
                    ),
                  )
                else if (_design.footprint.isNotEmpty)
                  Text(
                    'Not in any library on this phone',
                    style: TextStyle(fontSize: 12, color: KicadPalette.warning),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.link, size: 16),
            label: const Text('MATCH'),
            onPressed: _matchFootprint,
          ),
        ],
      ),
      const SizedBox(height: 6),
      _Field(
        label: 'Description',
        value: _design.description,
        onChanged: (v) => _update(_design.copyWith(description: v)),
      ),
      _Field(
        label: 'Keywords',
        value: _design.keywords,
        onChanged: (v) => _update(_design.copyWith(keywords: v)),
      ),
    ],
  );

  Widget _bodyTab() => ListView(
    key: ValueKey('body-$_generation'),
    padding: const EdgeInsets.all(12),
    children: [
      SegmentedButton<BodyShape>(
        showSelectedIcon: false,
        segments: [
          for (final shape in BodyShape.values)
            ButtonSegment(value: shape, label: Text(shape.label)),
        ],
        selected: {_design.shape},
        onSelectionChanged: (v) => setState(() {
          _design = _design.copyWith(shape: v.first);
          _generation++;
        }),
      ),
      if (_design.shape == BodyShape.polygon)
        Row(
          children: [
            _Number(
              'Sides (3–12)',
              _design.polygonSides.toDouble(),
              (v) => _update(
                _design.copyWith(polygonSides: v.round().clamp(3, 12)),
              ),
              whole: true,
            ),
            const Spacer(flex: 2),
          ],
        ),
      Row(
        children: [
          _Number(
            'Body width mm',
            _design.bodyWidth,
            (v) => _update(_design.copyWith(bodyWidth: v)),
          ),
          _Number(
            'Body height mm',
            _design.bodyHeight,
            (v) => _update(_design.copyWith(bodyHeight: v)),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'A size of 0 fits the body to its pins.',
          style: TextStyle(color: KicadPalette.textSecondary, fontSize: 12),
        ),
      ),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Show pin names'),
        value: _design.showPinNames,
        onChanged: (v) => _update(_design.copyWith(showPinNames: v)),
      ),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Show pin numbers'),
        value: _design.showPinNumbers,
        onChanged: (v) => _update(_design.copyWith(showPinNumbers: v)),
      ),
    ],
  );

  Widget _pinsTab() {
    final theme = Theme.of(context);
    final selected = _selectedPin;
    return ListView(
      key: ValueKey('pins-$_generation-$selected'),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: [
        Row(
          children: [
            Text(
              'PINS (${_design.pins.length})',
              style: theme.textTheme.labelSmall?.copyWith(
                color: KicadPalette.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('ADD PINS'),
              onPressed: _addPins,
            ),
          ],
        ),
        if (selected != null && selected < _design.pins.length)
          _SelectedPin(
            pin: _design.pins[selected],
            placed: _design.placedPins()[selected],
            onChanged: (pin) => setState(() {
              _design = _design.copyWith(
                pins: [..._design.pins]..[selected] = pin,
              );
            }),
          ),
        for (var i = 0; i < _design.pins.length; i++)
          _PinRow(
            pin: _design.pins[i],
            selected: i == selected,
            onSelect: () => setState(() => _selectedPin = i),
            onChanged: (pin) =>
                _update(_design.copyWith(pins: [..._design.pins]..[i] = pin)),
            onDelete: () => setState(() {
              _design = _design.copyWith(pins: [..._design.pins]..removeAt(i));
              _selectedPin = null;
              _generation++;
            }),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: onChanged,
    ),
  );
}

class _Number extends StatelessWidget {
  const _Number(this.label, this.value, this.onChanged, {this.whole = false});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool whole;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
      child: TextFormField(
        initialValue: whole
            ? '${value.round()}'
            : value
                  .toStringAsFixed(2)
                  .replaceFirst(RegExp(r'0+$'), '')
                  .replaceFirst(RegExp(r'\.$'), ''),
        keyboardType: TextInputType.numberWithOptions(
          decimal: !whole,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
        ],
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (text) {
          final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
          if (parsed != null) onChanged(parsed);
        },
      ),
    ),
  );
}

/// The exact numbers of the pin last touched: where it is, which way it
/// faces, how long it is and how it is drawn.
class _SelectedPin extends StatelessWidget {
  const _SelectedPin({
    required this.pin,
    required this.placed,
    required this.onChanged,
  });

  final PinDesign pin;
  final SymbolPin placed;
  final ValueChanged<PinDesign> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 2, 2, 8),
    decoration: BoxDecoration(
      border: Border.all(color: KicadPalette.highlight.withValues(alpha: 0.6)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Number(
              'X mm',
              placed.at.x,
              (v) => onChanged(
                pin.copyWith(x: v, y: placed.at.y, angle: placed.angle),
              ),
            ),
            _Number(
              'Y mm',
              placed.at.y,
              (v) => onChanged(
                pin.copyWith(x: placed.at.x, y: v, angle: placed.angle),
              ),
            ),
            _Number(
              'Length',
              placed.length,
              (v) => onChanged(
                pin.copyWith(
                  x: placed.at.x,
                  y: placed.at.y,
                  angle: placed.angle,
                  length: v,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButton<double>(
                isExpanded: true,
                value: (placed.angle % 360).roundToDouble(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Stub points right')),
                  DropdownMenuItem(value: 90, child: Text('Stub points up')),
                  DropdownMenuItem(value: 180, child: Text('Stub points left')),
                  DropdownMenuItem(value: 270, child: Text('Stub points down')),
                ],
                onChanged: (a) => onChanged(
                  pin.copyWith(x: placed.at.x, y: placed.at.y, angle: a),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<PinGraphicStyle>(
                isExpanded: true,
                value: pin.style,
                items: const [
                  DropdownMenuItem(
                    value: PinGraphicStyle.line,
                    child: Text('Plain'),
                  ),
                  DropdownMenuItem(
                    value: PinGraphicStyle.inverted,
                    child: Text('Inverted (bubble)'),
                  ),
                  DropdownMenuItem(
                    value: PinGraphicStyle.clock,
                    child: Text('Clock'),
                  ),
                  DropdownMenuItem(
                    value: PinGraphicStyle.invertedClock,
                    child: Text('Inverted clock'),
                  ),
                ],
                onChanged: (s) => onChanged(pin.copyWith(style: s)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.pin,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
    required this.onDelete,
  });

  final PinDesign pin;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<PinDesign> onChanged;
  final VoidCallback onDelete;

  static const types = {
    PinElectricalType.input: 'Input',
    PinElectricalType.output: 'Output',
    PinElectricalType.bidirectional: 'Bidir',
    PinElectricalType.passive: 'Passive',
    PinElectricalType.powerIn: 'Pwr in',
    PinElectricalType.powerOut: 'Pwr out',
    PinElectricalType.openCollector: 'Open col',
    PinElectricalType.triState: 'Tri-state',
    PinElectricalType.noConnect: 'NC',
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    color: selected ? KicadPalette.highlight.withValues(alpha: 0.08) : null,
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Select',
            icon: Icon(
              pin.isPlaced ? Icons.push_pin : Icons.push_pin_outlined,
              size: 16,
            ),
            onPressed: onSelect,
          ),
        ),
        SizedBox(
          width: 44,
          child: TextFormField(
            initialValue: pin.number,
            decoration: const InputDecoration(labelText: '#', isDense: true),
            onChanged: (v) => onChanged(pin.copyWith(number: v.trim())),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: pin.name,
            decoration: const InputDecoration(labelText: 'Name', isDense: true),
            onChanged: (v) => onChanged(pin.copyWith(name: v.trim())),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: DropdownButton<PinElectricalType>(
            value: types.containsKey(pin.type)
                ? pin.type
                : PinElectricalType.passive,
            isDense: true,
            isExpanded: true,
            items: [
              for (final entry in types.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (type) => onChanged(pin.copyWith(type: type)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: DropdownButton<PinSide>(
            value: pin.side,
            isDense: true,
            isExpanded: true,
            items: [
              for (final side in PinSide.values)
                DropdownMenuItem(value: side, child: Text(side.label)),
            ],
            // Choosing a side puts a dragged pin back on it.
            onChanged: (side) =>
                onChanged(pin.copyWith(side: side, unplace: true)),
          ),
        ),
        SizedBox(
          width: 32,
          child: IconButton(
            tooltip: 'Remove pin',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDelete,
          ),
        ),
      ],
    ),
  );
}

class _SymbolPreview extends CustomPainter {
  _SymbolPreview(
    this.symbol,
    this.colors, {
    required this.viewport,
    this.selectedPin,
  });

  final SymbolDefinition symbol;
  final SchematicColors colors;
  final SchematicViewport viewport;
  final int? selectedPin;

  /// A view with the whole symbol in it, and room to drag pins beyond.
  static SchematicViewport fit(SymbolDefinition symbol, Size size) {
    final local = symbolBounds(symbol, 1);
    if (local == Rect.zero || size.isEmpty) {
      return SchematicViewport(
        pixelsPerMm: 10,
        origin: Offset(size.width / 2, size.height / 2),
      );
    }
    const origin = Placement(x: 0, y: 0);
    final sheet = Rect.fromPoints(
      origin.apply(local.left, local.top),
      origin.apply(local.right, local.bottom),
    ).inflate(8);
    final ppm = math.min(size.width / sheet.width, size.height / sheet.height);
    return SchematicViewport(
      pixelsPerMm: ppm,
      origin: Offset(
        size.width / 2 - sheet.center.dx * ppm,
        size.height / 2 - sheet.center.dy * ppm,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.canvas);

    // The 2.54 mm grid pins land on, faintly.
    final gridPaint = Paint()..color = colors.grid;
    final step = 2.54 * viewport.pixelsPerMm;
    if (step >= 8) {
      final start = viewport.toSheet(Offset.zero);
      final end = viewport.toSheet(Offset(size.width, size.height));
      for (
        var x = (start.dx / 2.54).floor();
        x <= (end.dx / 2.54).ceil();
        x++
      ) {
        for (
          var y = (start.dy / 2.54).floor();
          y <= (end.dy / 2.54).ceil();
          y++
        ) {
          canvas.drawCircle(
            viewport.toScreen(Offset(x * 2.54, y * 2.54)),
            1,
            gridPaint,
          );
        }
      }
    }

    const origin = Placement(x: 0, y: 0);
    final renderer = SymbolRenderer(viewport: viewport, colors: colors);
    renderer.paintGraphics(canvas, symbol: symbol, unit: 1, placement: origin);
    final pins = symbol.pinsForUnit(1);
    renderer.paintPins(
      canvas,
      pins: [for (final pin in pins) RenderablePin.fromSymbol(pin, unit: 1)],
      placement: origin,
      pinNamesHidden: symbol.pinNamesHidden,
      pinNumbersHidden: symbol.pinNumbersHidden,
      pinNamesOffset: symbol.pinNamesOffset,
    );

    final selected = selectedPin;
    if (selected != null && selected < pins.length) {
      final pin = pins[selected];
      canvas.drawCircle(
        viewport.toScreen(origin.apply(pin.at.x, pin.at.y)),
        8,
        Paint()
          ..color = colors.highlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SymbolPreview old) => true;
}
