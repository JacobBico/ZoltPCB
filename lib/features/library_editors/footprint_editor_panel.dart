import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/editors/own_library_store.dart';
import '../../domain/editors/footprint_design.dart';
import '../../domain/pcb/pcb.dart';
import 'editor_requests.dart';

/// Makes footprints, pad by pad, to the hundredth of a millimetre.
///
/// Nothing here is placed by eye. Every pad is a set of numbers, typed in or
/// laid out by a generator from the figures a datasheet gives — pitch, row
/// spacing, pad size — and the preview reads those numbers back as
/// dimensions so they can be checked against the drawing.
class FootprintEditorPanel extends ConsumerStatefulWidget {
  const FootprintEditorPanel({super.key});

  @override
  ConsumerState<FootprintEditorPanel> createState() =>
      _FootprintEditorPanelState();
}

enum _Pattern {
  twoPad('Two pads'),
  header('Header'),
  dualRow('Dual row'),
  quad('Quad');

  const _Pattern(this.label);
  final String label;
}

class _FootprintEditorPanelState extends ConsumerState<FootprintEditorPanel> {
  FootprintDesign _design = FootprintDesign(
    name: 'New_Footprint',
    pads: PadPatterns.twoPad(centreDistance: 1.9, padWidth: 1, padHeight: 1.3),
  );
  String? _editing;
  int? _selected;
  int _generation = 0;
  List<FootprintDefinition> _saved = const [];

  // The generator's own numbers, kept between uses.
  _Pattern _pattern = _Pattern.dualRow;
  final Map<String, double> _numbers = {
    'twoPad.distance': 1.9,
    'twoPad.width': 1.0,
    'twoPad.height': 1.3,
    'header.pins': 6,
    'header.rows': 1,
    'header.pitch': 2.54,
    'header.spacing': 2.54,
    'header.pad': 1.7,
    'header.drill': 1.0,
    'dual.pins': 8,
    'dual.pitch': 1.27,
    'dual.spacing': 5.4,
    'dual.width': 1.55,
    'dual.height': 0.6,
    'dual.drill': 0.8,
    'quad.perSide': 5,
    'quad.pitch': 0.5,
    'quad.span': 4.8,
    'quad.length': 0.8,
    'quad.width': 0.25,
    'quad.exposed': 0,
  };
  bool _dualThroughHole = false;

  double _pixelsPerMm = 0;
  Offset _origin = Offset.zero;
  double _startPixelsPerMm = 0;
  Offset _startFocal = Offset.zero;
  Offset _startOrigin = Offset.zero;

  OwnLibraryStore get _store => ref.read(ownLibraryStoreProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<FootprintDefinition> saved;
    try {
      saved = await _store.loadFootprints();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not read My Library: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saved = saved);
    // A footprint My Library asked to open.
    final wanted = ref.read(footprintToEditProvider);
    if (wanted == null) return;
    final footprint = saved.where((f) => f.name == wanted).firstOrNull;
    ref.read(footprintToEditProvider.notifier).open(null);
    if (footprint != null) _open(footprint);
  }

  /// The grid a dragged pad lands on, in millimetres.
  double _snap = 0.05;

  /// The pad being dragged, and where on it the finger took hold.
  int? _dragging;
  Offset _dragGrip = Offset.zero;

  int? _padAt(Offset local) {
    final mm = (local - _origin) / _pixelsPerMm;
    int? hit;
    var best = double.infinity;
    for (var i = 0; i < _design.pads.length; i++) {
      final pad = _design.pads[i];
      final d = (Offset(pad.x, pad.y) - mm).distance;
      if (pad.bounds.inflate(0.3).contains(mm) && d < best) {
        best = d;
        hit = i;
      }
    }
    return hit;
  }

  double _toGrid(double v) => (v / _snap).round() * _snap;

  /// Every pad shifted, rotated about the origin, or renumbered at once.
  void _transformAll({
    Offset shift = Offset.zero,
    bool quarterTurn = false,
    bool mirror = false,
  }) {
    _refill(
      _design.copyWith(
        pads: [
          for (final pad in _design.pads)
            () {
              var x = pad.x + shift.dx;
              var y = pad.y + shift.dy;
              var w = pad.width;
              var h = pad.height;
              var angle = pad.angle;
              if (quarterTurn) {
                // Board space is Y down: a quarter turn counter-clockwise
                // takes (x, y) to (y, -x).
                final nx = y;
                final ny = -x;
                x = nx;
                y = ny;
                final t = w;
                w = h;
                h = t;
              }
              if (mirror) {
                x = -x;
                angle = -angle;
              }
              return pad.copyWith(
                x: double.parse(x.toStringAsFixed(4)),
                y: double.parse(y.toStringAsFixed(4)),
                width: w,
                height: h,
                angle: angle,
              );
            }(),
        ],
      ),
      select: _selected,
    );
  }

  Future<void> _shiftDialog() async {
    final dx = TextEditingController(text: '0');
    final dy = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Move every pad'),
        content: SizedBox(
          width: 320,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dx,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'X by, mm'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: dy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Y by, mm'),
                ),
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
            child: const Text('MOVE'),
          ),
        ],
      ),
    );
    final x = double.tryParse(dx.text.replaceAll(',', '.')) ?? 0;
    final y = double.tryParse(dy.text.replaceAll(',', '.')) ?? 0;
    dx.dispose();
    dy.dispose();
    if (ok == true) _transformAll(shift: Offset(x, y));
  }

  /// Numbers the pads 1, 2, 3 … in the order they are listed, skipping
  /// unplated holes, which carry no number.
  void _renumber() {
    var next = 1;
    _refill(
      _design.copyWith(
        pads: [
          for (final pad in _design.pads)
            pad.type == PadType.npth ? pad : pad.copyWith(number: '${next++}'),
        ],
      ),
      select: _selected,
    );
  }

  void _refill(FootprintDesign design, {int? select}) => setState(() {
    _design = design;
    _selected = select;
    _generation++;
  });

  void _open(FootprintDefinition? footprint) {
    _editing = footprint?.name;
    _pixelsPerMm = 0;
    _refill(
      footprint == null
          ? const FootprintDesign(name: 'New_Footprint')
          : FootprintDesign.from(footprint),
    );
  }

  String? get _problem {
    if (!RegExp(r'^[A-Za-z0-9_.+-]+$').hasMatch(_design.name)) {
      return 'Name: letters, digits, _ . + - and no spaces';
    }
    if (_design.pads.isEmpty) return 'A footprint needs at least one pad';
    for (final pad in _design.pads) {
      if (pad.width <= 0 || pad.height <= 0) {
        return 'Pad ${pad.number} needs a size above zero';
      }
      if (pad.type != PadType.smd &&
          (pad.drill <= 0 ||
              pad.drill >= math.min(pad.width, pad.height) &&
                  pad.type == PadType.thruHole)) {
        return 'Pad ${pad.number}: the drill must fit inside the pad';
      }
    }
    if (_editing != _design.name && _saved.any((f) => f.name == _design.name)) {
      return 'You already have a footprint called ${_design.name}';
    }
    return null;
  }

  Future<void> _save() async {
    await _store.saveFootprint(_design.build(), previousName: _editing);
    await _reload();
    if (!mounted) return;
    setState(() => _editing = _design.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${_design.name} to ${OwnLibraryStore.footprintLibrary} as '
          '${OwnLibraryStore.footprintLibrary}:${_design.name}',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final name = _editing;
    if (name == null) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'Boards using it will show the part as missing its footprint.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _store.deleteFootprint(name);
    await _reload();
    _open(null);
  }

  void _generate() {
    double n(String key) => _numbers[key] ?? 0;
    final pads = switch (_pattern) {
      _Pattern.twoPad => PadPatterns.twoPad(
        centreDistance: n('twoPad.distance'),
        padWidth: n('twoPad.width'),
        padHeight: n('twoPad.height'),
      ),
      _Pattern.header => PadPatterns.header(
        pins: n('header.pins').round(),
        rows: n('header.rows').round().clamp(1, 2),
        pitch: n('header.pitch'),
        rowSpacing: n('header.spacing'),
        padSize: n('header.pad'),
        drill: n('header.drill'),
      ),
      _Pattern.dualRow => PadPatterns.dualRow(
        pins: n('dual.pins').round(),
        pitch: n('dual.pitch'),
        rowSpacing: n('dual.spacing'),
        padWidth: n('dual.width'),
        padHeight: n('dual.height'),
        throughHole: _dualThroughHole,
        drill: n('dual.drill'),
      ),
      _Pattern.quad => PadPatterns.quad(
        pinsPerSide: n('quad.perSide').round(),
        pitch: n('quad.pitch'),
        span: n('quad.span'),
        padLength: n('quad.length'),
        padWidth: n('quad.width'),
        exposedPad: n('quad.exposed'),
      ),
    };
    _pixelsPerMm = 0;
    _refill(_design.copyWith(pads: pads), select: 0);
  }

  @override
  Widget build(BuildContext context) {
    final built = _design.build();
    final problem = _problem;

    return Row(
      children: [
        Expanded(child: _preview(built)),
        Container(
          width: 440,
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _editing,
                          hint: const Text('New footprint'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('New footprint'),
                            ),
                            for (final f in _saved)
                              DropdownMenuItem(
                                value: f.name,
                                child: Text(f.name),
                              ),
                          ],
                          onChanged: (name) => _open(
                            _saved.where((f) => f.name == name).firstOrNull,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'New footprint',
                        icon: const Icon(Icons.add),
                        onPressed: () => _open(null),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    key: ValueKey('name-$_generation'),
                    initialValue: _design.name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(
                      () => _design = _design.copyWith(name: v.trim()),
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Pads'),
                    Tab(text: 'Generate'),
                    Tab(text: 'Outline'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_padsTab(), _generateTab(), _outlineTab()],
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

  // --- preview ---------------------------------------------------------

  Widget _preview(FootprintDefinition built) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_pixelsPerMm <= 0) _fit(size);
      final selected = _selected == null || _selected! >= _design.pads.length
          ? null
          : _design.pads[_selected!];
      final pitch = selected == null
          ? null
          : PadPatterns.pitchOf(selected, _design.pads);
      final body = _design.body;
      final court = _design.courtyard;

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapUp: (details) {
                final hit = _padAt(details.localPosition);
                setState(() {
                  _selected = hit;
                  _generation++;
                });
              },
              onScaleStart: (details) {
                _startPixelsPerMm = _pixelsPerMm;
                _startFocal = details.localFocalPoint;
                _startOrigin = _origin;
                // One finger on a pad drags the pad; anywhere else pans.
                _dragging = details.pointerCount == 1
                    ? _padAt(details.localFocalPoint)
                    : null;
                final pad = _dragging == null ? null : _design.pads[_dragging!];
                if (pad != null) {
                  final mm = (details.localFocalPoint - _origin) / _pixelsPerMm;
                  _dragGrip = mm - Offset(pad.x, pad.y);
                  setState(() => _selected = _dragging);
                }
              },
              onScaleEnd: (_) {
                if (_dragging != null) {
                  _dragging = null;
                  setState(() => _generation++);
                }
              },
              onScaleUpdate: (details) => setState(() {
                final index = _dragging;
                if (index != null && details.pointerCount == 1) {
                  final mm =
                      (details.localFocalPoint - _origin) / _pixelsPerMm -
                      _dragGrip;
                  final pads = [..._design.pads];
                  pads[index] = pads[index].copyWith(
                    x: double.parse(_toGrid(mm.dx).toStringAsFixed(4)),
                    y: double.parse(_toGrid(mm.dy).toStringAsFixed(4)),
                  );
                  _design = _design.copyWith(pads: pads);
                  return;
                }
                final zoom = (_startPixelsPerMm * details.scale).clamp(
                  2.0,
                  2000.0,
                );
                final anchor = (_startFocal - _startOrigin) / _startPixelsPerMm;
                _pixelsPerMm = zoom;
                _origin = details.localFocalPoint - anchor * zoom;
              }),
              child: CustomPaint(
                painter: _FootprintPreview(
                  footprint: built,
                  selectedPad: _selected,
                  origin: _origin,
                  pixelsPerMm: _pixelsPerMm,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 8,
            right: 10,
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE0E0E0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Body ${_mm(body.width)} × ${_mm(body.height)}   '
                    'Courtyard ${_mm(court.width)} × ${_mm(court.height)} mm',
                  ),
                  if (selected != null)
                    Text(
                      'Pad ${selected.number}  '
                      'at (${_mm(selected.x)}, ${_mm(selected.y)})  '
                      '${_mm(selected.width)} × ${_mm(selected.height)}'
                      '${selected.type == PadType.smd ? '' : '  ⌀${_mm(selected.drill)}'}'
                      '${pitch == null ? '' : '  pitch ${_mm(pitch)}'} mm',
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: ActionChip(
              avatar: const Icon(Icons.fit_screen, size: 16),
              label: const Text('Fit'),
              onPressed: () => setState(() => _fit(size)),
            ),
          ),
        ],
      );
    },
  );

  void _fit(Size size) {
    final area = _design.courtyard.inflate(1.5);
    if (size.isEmpty || area.isEmpty) {
      _pixelsPerMm = 40;
      _origin = Offset(size.width / 2, size.height / 2);
      return;
    }
    _pixelsPerMm = math.min(
      size.width / area.width,
      (size.height - 40) / area.height,
    );
    _origin = Offset(
      size.width / 2 - area.center.dx * _pixelsPerMm,
      size.height / 2 + 16 - area.center.dy * _pixelsPerMm,
    );
  }

  // --- tabs ------------------------------------------------------------

  Widget _padsTab() {
    final pads = _design.pads;
    final index = _selected;
    final pad = index == null || index >= pads.length ? null : pads[index];

    void change(PadDesign updated) => setState(() {
      _design = _design.copyWith(pads: [...pads]..[index!] = updated);
    });

    return ListView(
      key: ValueKey('pads-$_generation'),
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Text('Drag snaps to'),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: _snap,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 0.01, child: Text('0.01 mm')),
                DropdownMenuItem(value: 0.05, child: Text('0.05 mm')),
                DropdownMenuItem(value: 0.1, child: Text('0.1 mm')),
                DropdownMenuItem(value: 0.25, child: Text('0.25 mm')),
                DropdownMenuItem(value: 0.5, child: Text('0.5 mm')),
                DropdownMenuItem(value: 1.27, child: Text('1.27 mm')),
                DropdownMenuItem(value: 2.54, child: Text('2.54 mm')),
              ],
              onChanged: (v) => setState(() => _snap = v ?? _snap),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'All pads',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) => switch (value) {
                'move' => _shiftDialog(),
                'rotate' => _transformAll(quarterTurn: true),
                'mirror' => _transformAll(mirror: true),
                'renumber' => _renumber(),
                'centre' => () {
                  final bounds = _design.padBounds;
                  if (bounds != null) {
                    _transformAll(shift: -bounds.center);
                  }
                }(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'move', child: Text('Move all pads by…')),
                PopupMenuItem(
                  value: 'centre',
                  child: Text('Centre pads on the origin'),
                ),
                PopupMenuItem(
                  value: 'rotate',
                  child: Text('Rotate all 90° about the origin'),
                ),
                PopupMenuItem(
                  value: 'mirror',
                  child: Text('Mirror all left to right'),
                ),
                PopupMenuItem(
                  value: 'renumber',
                  child: Text('Renumber 1, 2, 3… in list order'),
                ),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('ADD PAD'),
              onPressed: () {
                final last = pads.isEmpty ? null : pads.last;
                final next = PadDesign(
                  number: '${pads.length + 1}',
                  x: (last?.x ?? 0) + (last == null ? 0 : 1.27),
                  y: last?.y ?? 0,
                  width: last?.width ?? 1,
                  height: last?.height ?? 1,
                  type: last?.type ?? PadType.smd,
                  shape: last?.shape ?? PadShape.roundrect,
                  drill: last?.drill ?? 0,
                );
                _refill(
                  _design.copyWith(pads: [...pads, next]),
                  select: pads.length,
                );
              },
            ),
            if (pad != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('DUPLICATE'),
                onPressed: () => _refill(
                  _design.copyWith(
                    pads: [
                      ...pads,
                      pad.copyWith(number: '${pads.length + 1}'),
                    ],
                  ),
                  select: pads.length,
                ),
              ),
            if (pad != null)
              OutlinedButton.icon(
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: KicadPalette.error,
                ),
                label: Text(
                  'DELETE',
                  style: TextStyle(color: KicadPalette.error),
                ),
                onPressed: () => _refill(
                  _design.copyWith(pads: [...pads]..removeAt(index!)),
                ),
              ),
          ],
        ),
        if (pad == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Tap a pad in the preview, or in the list, to set its numbers.',
              style: TextStyle(color: KicadPalette.textSecondary),
            ),
          )
        else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: pad.number,
                  decoration: const InputDecoration(
                    labelText: 'Number',
                    isDense: true,
                  ),
                  onChanged: (v) => change(pad.copyWith(number: v.trim())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<PadType>(
                  initialValue: pad.type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: PadType.smd, child: Text('SMD')),
                    DropdownMenuItem(
                      value: PadType.thruHole,
                      child: Text('Through-hole'),
                    ),
                    DropdownMenuItem(
                      value: PadType.npth,
                      child: Text('Unplated hole'),
                    ),
                  ],
                  onChanged: (t) => setState(() {
                    _design = _design.copyWith(
                      pads: [...pads]
                        ..[index!] = pad.copyWith(
                          type: t,
                          drill: t == PadType.smd
                              ? 0
                              : (pad.drill > 0
                                    ? pad.drill
                                    : math.min(pad.width, pad.height) * 0.6),
                        ),
                    );
                    _generation++;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<PadShape>(
                  initialValue: pad.shape,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Shape',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PadShape.roundrect,
                      child: Text('Rounded'),
                    ),
                    DropdownMenuItem(value: PadShape.rect, child: Text('Rect')),
                    DropdownMenuItem(value: PadShape.oval, child: Text('Oval')),
                    DropdownMenuItem(
                      value: PadShape.circle,
                      child: Text('Circle'),
                    ),
                  ],
                  onChanged: (s) => change(pad.copyWith(shape: s)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _Mm('X', pad.x, (v) => change(pad.copyWith(x: v)), signed: true),
              _Mm('Y', pad.y, (v) => change(pad.copyWith(y: v)), signed: true),
              _Mm(
                'Rotation °',
                pad.angle,
                (v) => change(pad.copyWith(angle: v)),
              ),
            ],
          ),
          Row(
            children: [
              _Mm('Width', pad.width, (v) => change(pad.copyWith(width: v))),
              _Mm('Height', pad.height, (v) => change(pad.copyWith(height: v))),
              if (pad.type != PadType.smd)
                _Mm('Drill ⌀', pad.drill, (v) => change(pad.copyWith(drill: v)))
              else if (pad.shape == PadShape.roundrect)
                _Mm(
                  'Corner ratio',
                  pad.roundness,
                  (v) => change(pad.copyWith(roundness: v.clamp(0, 0.5))),
                )
              else
                const Spacer(),
            ],
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < pads.length; i++)
          ListTile(
            dense: true,
            selected: i == index,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Pad ${pads[i].number}  (${_mm(pads[i].x)}, ${_mm(pads[i].y)})',
            ),
            subtitle: Text(
              '${_mm(pads[i].width)} × ${_mm(pads[i].height)} mm'
              '${pads[i].type == PadType.smd ? ' · SMD' : ' · ⌀${_mm(pads[i].drill)}'}',
            ),
            onTap: () => setState(() {
              _selected = i;
              _generation++;
            }),
          ),
      ],
    );
  }

  Widget _generateTab() {
    Widget number(String label, String key, {bool whole = false}) => _Mm(
      label,
      _numbers[key] ?? 0,
      (v) => _numbers[key] = whole ? v.roundToDouble() : v,
      whole: whole,
    );

    return ListView(
      key: ValueKey('generate-$_pattern'),
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<_Pattern>(
          showSelectedIcon: false,
          segments: [
            for (final p in _Pattern.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_pattern},
          onSelectionChanged: (v) => setState(() => _pattern = v.first),
        ),
        const SizedBox(height: 8),
        // At the top, where it is on screen: a phone in landscape shows only
        // a few rows of this tab at once.
        FilledButton.icon(
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('REPLACE PADS'),
          onPressed: _generate,
        ),
        const SizedBox(height: 10),
        ...switch (_pattern) {
          _Pattern.twoPad => [
            Row(children: [number('Centre to centre', 'twoPad.distance')]),
            Row(
              children: [
                number('Pad width', 'twoPad.width'),
                number('Pad height', 'twoPad.height'),
              ],
            ),
          ],
          _Pattern.header => [
            Row(
              children: [
                number('Pins', 'header.pins', whole: true),
                number('Rows (1–2)', 'header.rows', whole: true),
                number('Pitch', 'header.pitch'),
              ],
            ),
            Row(
              children: [
                number('Row spacing', 'header.spacing'),
                number('Pad ⌀', 'header.pad'),
                number('Drill ⌀', 'header.drill'),
              ],
            ),
          ],
          _Pattern.dualRow => [
            Row(
              children: [
                number('Pins', 'dual.pins', whole: true),
                number('Pitch', 'dual.pitch'),
                number('Row spacing', 'dual.spacing'),
              ],
            ),
            Row(
              children: [
                number('Pad width', 'dual.width'),
                number('Pad height', 'dual.height'),
                number('Drill ⌀', 'dual.drill'),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Through-hole (DIP)'),
              value: _dualThroughHole,
              onChanged: (v) => setState(() => _dualThroughHole = v),
            ),
          ],
          _Pattern.quad => [
            Row(
              children: [
                number('Pins per side', 'quad.perSide', whole: true),
                number('Pitch', 'quad.pitch'),
                number('Span, pad centres', 'quad.span'),
              ],
            ),
            Row(
              children: [
                number('Pad length', 'quad.length'),
                number('Pad width', 'quad.width'),
                number('Exposed pad', 'quad.exposed'),
              ],
            ),
          ],
        },
        const SizedBox(height: 8),
        Text(
          'Row spacing and span are measured between pad centres, the way '
          'a land pattern drawing gives them. Everything is in millimetres.',
          style: TextStyle(color: KicadPalette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _outlineTab() => ListView(
    key: ValueKey('outline-$_generation'),
    padding: const EdgeInsets.all(12),
    children: [
      Row(
        children: [
          _Mm(
            'Body width',
            _design.bodyWidth,
            (v) => setState(() => _design = _design.copyWith(bodyWidth: v)),
          ),
          _Mm(
            'Body height',
            _design.bodyHeight,
            (v) => setState(() => _design = _design.copyWith(bodyHeight: v)),
          ),
          _Mm(
            'Courtyard margin',
            _design.courtyardMargin,
            (v) =>
                setState(() => _design = _design.copyWith(courtyardMargin: v)),
          ),
        ],
      ),
      Text(
        'A body size of 0 follows the pads.',
        style: TextStyle(color: KicadPalette.textSecondary, fontSize: 12),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Silkscreen outline'),
        subtitle: const Text('Kept clear of every pad'),
        value: _design.silkscreen,
        onChanged: (v) =>
            setState(() => _design = _design.copyWith(silkscreen: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Pin 1 marker'),
        value: _design.pinOneMarker,
        onChanged: (v) =>
            setState(() => _design = _design.copyWith(pinOneMarker: v)),
      ),
      TextFormField(
        initialValue: _design.description,
        decoration: const InputDecoration(
          labelText: 'Description',
          isDense: true,
        ),
        onChanged: (v) =>
            setState(() => _design = _design.copyWith(description: v)),
      ),
      TextFormField(
        initialValue: _design.keywords,
        decoration: const InputDecoration(labelText: 'Keywords', isDense: true),
        onChanged: (v) =>
            setState(() => _design = _design.copyWith(keywords: v)),
      ),
    ],
  );

  static String _mm(double v) => v.toStringAsFixed(3);
}

/// A number field in millimetres, three decimals, parsed as you type.
class _Mm extends StatelessWidget {
  const _Mm(
    this.label,
    this.value,
    this.onChanged, {
    this.signed = false,
    this.whole = false,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool signed;
  final bool whole;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
      child: TextFormField(
        initialValue: whole
            ? value.round().toString()
            : value
                  .toStringAsFixed(3)
                  .replaceFirst(RegExp(r'0+$'), '')
                  .replaceFirst(RegExp(r'\.$'), ''),
        keyboardType: TextInputType.numberWithOptions(
          decimal: !whole,
          signed: signed,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(whole ? r'[0-9]' : r'[-0-9.,]'),
          ),
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

/// The footprint as a board sees it, on a millimetre grid.
class _FootprintPreview extends CustomPainter {
  _FootprintPreview({
    required this.footprint,
    required this.selectedPad,
    required this.origin,
    required this.pixelsPerMm,
  });

  final FootprintDefinition footprint;
  final int? selectedPad;
  final Offset origin;
  final double pixelsPerMm;

  Offset _s(double x, double y) => origin + Offset(x, y) * pixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101418),
    );

    // Grid: fine lines every 0.1 mm once they are far enough apart to read,
    // stronger ones every millimetre, and the axes through the origin.
    void grid(double step, Color color) {
      if (step * pixelsPerMm < 6) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1;
      final left = (-origin.dx / pixelsPerMm / step).floor();
      final right = ((size.width - origin.dx) / pixelsPerMm / step).ceil();
      final top = (-origin.dy / pixelsPerMm / step).floor();
      final bottom = ((size.height - origin.dy) / pixelsPerMm / step).ceil();
      for (var i = left; i <= right; i++) {
        final x = origin.dx + i * step * pixelsPerMm;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var j = top; j <= bottom; j++) {
        final y = origin.dy + j * step * pixelsPerMm;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    grid(0.1, const Color(0xFF1A2027));
    grid(1, const Color(0xFF28313B));
    final axis = Paint()
      ..color = const Color(0xFF3F5566)
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), axis)
      ..drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), axis);

    for (final graphic in footprint.graphics) {
      final color = switch (graphic.layer) {
        BoardLayer.frontSilk => const Color(0xFFF2F2F2),
        BoardLayer.frontCourtyard => const Color(0xFFE040FB),
        BoardLayer.frontFab => const Color(0xFF8A8F98),
        _ => const Color(0xFF8A8F98),
      };
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, graphic.stroke.width * pixelsPerMm);
      switch (graphic) {
        case FootprintLine(:final start, :final end):
          canvas.drawLine(_s(start.x, start.y), _s(end.x, end.y), paint);
        case FootprintRect(:final start, :final end):
          canvas.drawRect(
            Rect.fromPoints(_s(start.x, start.y), _s(end.x, end.y)),
            paint,
          );
        case FootprintCircle(:final center):
          canvas.drawCircle(
            _s(center.x, center.y),
            math.max(2, graphic.radius * pixelsPerMm),
            paint..style = PaintingStyle.fill,
          );
        case FootprintArc(:final start, :final mid, :final end):
          canvas
            ..drawLine(_s(start.x, start.y), _s(mid.x, mid.y), paint)
            ..drawLine(_s(mid.x, mid.y), _s(end.x, end.y), paint);
        case FootprintPolygon(:final points):
          if (points.length < 2) break;
          final path = Path()
            ..moveTo(
              _s(points[0].x, points[0].y).dx,
              _s(points[0].x, points[0].y).dy,
            );
          for (final p in points.skip(1)) {
            path.lineTo(_s(p.x, p.y).dx, _s(p.x, p.y).dy);
          }
          canvas.drawPath(path..close(), paint);
        case FootprintText(:final text, :final at, :final angle, :final size):
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: color,
                fontSize: math.max(6, size * pixelsPerMm),
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final centre = _s(at.x, at.y);
          canvas
            ..save()
            ..translate(centre.dx, centre.dy)
            ..rotate(-angle * math.pi / 180);
          painter.paint(
            canvas,
            Offset(-painter.width / 2, -painter.height / 2),
          );
          canvas.restore();
      }
    }

    for (var i = 0; i < footprint.pads.length; i++) {
      final pad = footprint.pads[i];
      final centre = _s(pad.at.x, pad.at.y);
      final w = pad.sizeX * pixelsPerMm;
      final h = pad.sizeY * pixelsPerMm;
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(-pad.angle * math.pi / 180);
      final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      final copper = Paint()
        ..color = pad.type == PadType.npth
            ? const Color(0xFF2A3036)
            : pad.type == PadType.smd
            ? const Color(0xFFC8503C)
            : const Color(0xFFC9A227);
      switch (pad.shape) {
        case PadShape.circle:
          canvas.drawCircle(Offset.zero, w / 2, copper);
        case PadShape.oval:
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(math.min(w, h) / 2)),
            copper,
          );
        case PadShape.roundrect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect,
              Radius.circular(math.min(w, h) * pad.roundrectRatio),
            ),
            copper,
          );
        default:
          canvas.drawRect(rect, copper);
      }
      if (pad.drill > 0) {
        canvas.drawCircle(
          Offset.zero,
          pad.drill * pixelsPerMm / 2,
          Paint()..color = const Color(0xFF101418),
        );
      }
      if (i == selectedPad) {
        canvas.drawRect(
          rect.inflate(3),
          Paint()
            ..color = KicadPalette.highlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.restore();

      if (pad.number.isNotEmpty && math.min(w, h) > 12) {
        final text = TextPainter(
          text: TextSpan(
            text: pad.number,
            style: TextStyle(
              color: Colors.white,
              fontSize: math.min(14, math.min(w, h) * 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_FootprintPreview old) => true;
}
