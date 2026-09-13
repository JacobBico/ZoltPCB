import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// What a properties dialog came back with.
sealed class PropertiesResult<T> {
  const PropertiesResult();
}

class PropertiesSaved<T> extends PropertiesResult<T> {
  const PropertiesSaved(this.value);

  final T value;
}

class PropertiesDeleted<T> extends PropertiesResult<T> {
  const PropertiesDeleted();
}

/// A placed part's numbers, typed rather than dragged.
///
/// The rotation is a free angle, not a choice of four. KiCad has allowed
/// any angle on a footprint for years and a board that needs a connector at
/// 30° needs it at 30°; rounding that to the nearest right angle is the app
/// deciding the layout rather than the person doing it.
Future<PropertiesResult<PlacedFootprintRef>?> showFootprintProperties(
  BuildContext context, {
  required PlacedFootprintRef placement,
  required String reference,
  required String value,
}) => showDialog<PropertiesResult<PlacedFootprintRef>>(
  context: context,
  builder: (context) => _FootprintProperties(
    placement: placement,
    reference: reference,
    value: value,
  ),
);

class _FootprintProperties extends StatefulWidget {
  const _FootprintProperties({
    required this.placement,
    required this.reference,
    required this.value,
  });

  final PlacedFootprintRef placement;
  final String reference;
  final String value;

  @override
  State<_FootprintProperties> createState() => _FootprintPropertiesState();
}

class _FootprintPropertiesState extends State<_FootprintProperties> {
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _rotation;
  late bool _flipped;

  @override
  void initState() {
    super.initState();
    _x = TextEditingController(text: _mm(widget.placement.x));
    _y = TextEditingController(text: _mm(widget.placement.y));
    _rotation = TextEditingController(text: _mm(widget.placement.rotation));
    _flipped = widget.placement.flipped;
  }

  @override
  void dispose() {
    for (final c in [_x, _y, _rotation]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _xValue => _parse(_x);
  double? get _yValue => _parse(_y);
  double? get _rotationValue => _parse(_rotation);

  String? get _problem {
    if (_xValue == null || _yValue == null) return 'Position needs numbers';
    if (_rotationValue == null) return 'Rotation needs a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      title: Text('${widget.reference}  ${widget.value}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _NumberField(controller: _x, label: 'X mm')),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(controller: _y, label: 'Y mm')),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: _rotation,
                    label: 'Rotation °',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final angle in const [0, 45, 90, 135, 180, 270])
                  ActionChip(
                    label: Text('$angle°'),
                    onPressed: () =>
                        setState(() => _rotation.text = '$angle'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _flipped,
              onChanged: (value) => setState(() => _flipped = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('On the back of the board'),
            ),
            if (problem != null)
              Text(
                problem,
                style: TextStyle(color: KicadPalette.error, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const PropertiesDeleted<PlacedFootprintRef>()),
          child: Text(
            'UNPLACE',
            style: TextStyle(color: KicadPalette.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(
                  PropertiesSaved(
                    widget.placement.copyWith(
                      x: _xValue,
                      y: _yValue,
                      rotation: _rotationValue,
                      flipped: _flipped,
                      placed: true,
                    ),
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

/// One track's own numbers. Width per segment, because a power track and a
/// signal track on the same board are not the same track.
Future<PropertiesResult<Track>?> showTrackProperties(
  BuildContext context, {
  required Track track,
  required String netName,
}) => showDialog<PropertiesResult<Track>>(
  context: context,
  builder: (context) => _TrackProperties(track: track, netName: netName),
);

class _TrackProperties extends StatefulWidget {
  const _TrackProperties({required this.track, required this.netName});

  final Track track;
  final String netName;

  @override
  State<_TrackProperties> createState() => _TrackPropertiesState();
}

class _TrackPropertiesState extends State<_TrackProperties> {
  late final TextEditingController _startX;
  late final TextEditingController _startY;
  late final TextEditingController _endX;
  late final TextEditingController _endY;
  late final TextEditingController _width;
  late CopperLayer _layer;

  @override
  void initState() {
    super.initState();
    _startX = TextEditingController(text: _mm(widget.track.startX));
    _startY = TextEditingController(text: _mm(widget.track.startY));
    _endX = TextEditingController(text: _mm(widget.track.endX));
    _endY = TextEditingController(text: _mm(widget.track.endY));
    _width = TextEditingController(text: _mm(widget.track.width));
    _layer = widget.track.layer;
  }

  @override
  void dispose() {
    for (final c in [_startX, _startY, _endX, _endY, _width]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _problem {
    for (final c in [_startX, _startY, _endX, _endY]) {
      if (_parse(c) == null) return 'Every coordinate needs a number';
    }
    final width = _parse(_width);
    if (width == null || width <= 0) {
      return 'A track has to have a width';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      title: Text(
        widget.netName.isEmpty ? 'Track' : 'Track · ${widget.netName}',
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _NumberField(controller: _startX, label: 'From X'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(controller: _startY, label: 'From Y'),
                ),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(controller: _endX, label: 'To X')),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(controller: _endY, label: 'To Y')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: _NumberField(controller: _width, label: 'Width mm'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<CopperLayer>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: CopperLayer.front,
                        label: Text('Front'),
                      ),
                      ButtonSegment(
                        value: CopperLayer.back,
                        label: Text('Back'),
                      ),
                    ],
                    selected: {_layer},
                    onSelectionChanged: (value) =>
                        setState(() => _layer = value.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final width in const [0.15, 0.2, 0.25, 0.4, 0.6, 1.0])
                  ActionChip(
                    label: Text('$width'),
                    onPressed: () =>
                        setState(() => _width.text = _mm(width)),
                  ),
              ],
            ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  problem,
                  style: TextStyle(color: KicadPalette.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const PropertiesDeleted<Track>()),
          child: Text('DELETE', style: TextStyle(color: KicadPalette.error)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(
                  PropertiesSaved(
                    widget.track.copyWith(
                      layer: _layer,
                      startX: _parse(_startX),
                      startY: _parse(_startY),
                      endX: _parse(_endX),
                      endY: _parse(_endY),
                      width: _parse(_width),
                    ),
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

/// A via's position and hole.
Future<PropertiesResult<Via>?> showViaProperties(
  BuildContext context, {
  required Via via,
  required String netName,
}) => showDialog<PropertiesResult<Via>>(
  context: context,
  builder: (context) => _ViaProperties(via: via, netName: netName),
);

class _ViaProperties extends StatefulWidget {
  const _ViaProperties({required this.via, required this.netName});

  final Via via;
  final String netName;

  @override
  State<_ViaProperties> createState() => _ViaPropertiesState();
}

class _ViaPropertiesState extends State<_ViaProperties> {
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _diameter;
  late final TextEditingController _drill;

  @override
  void initState() {
    super.initState();
    _x = TextEditingController(text: _mm(widget.via.x));
    _y = TextEditingController(text: _mm(widget.via.y));
    _diameter = TextEditingController(text: _mm(widget.via.diameter));
    _drill = TextEditingController(text: _mm(widget.via.drill));
  }

  @override
  void dispose() {
    for (final c in [_x, _y, _diameter, _drill]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _problem {
    if (_parse(_x) == null || _parse(_y) == null) {
      return 'Position needs numbers';
    }
    final diameter = _parse(_diameter);
    final drill = _parse(_drill);
    if (diameter == null || drill == null) return 'The hole needs numbers';
    if (drill <= 0) return 'A drill has to be bigger than nothing';
    // A hole wider than its pad is not a tight tolerance, it is a hole with
    // no copper round it.
    if (diameter <= drill) return 'The pad has to be wider than the hole';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      title: Text(widget.netName.isEmpty ? 'Via' : 'Via · ${widget.netName}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _NumberField(controller: _x, label: 'X mm')),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(controller: _y, label: 'Y mm')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _diameter,
                    label: 'Pad ⌀ mm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(controller: _drill, label: 'Drill ⌀ mm'),
                ),
              ],
            ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  problem,
                  style: TextStyle(color: KicadPalette.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const PropertiesDeleted<Via>()),
          child: Text('DELETE', style: TextStyle(color: KicadPalette.error)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: problem != null
              ? null
              : () => Navigator.of(context).pop(
                  PropertiesSaved(
                    widget.via.copyWith(
                      x: _parse(_x),
                      y: _parse(_y),
                      diameter: _parse(_diameter),
                      drill: _parse(_drill),
                    ),
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
    ],
    decoration: InputDecoration(labelText: label, isDense: true),
  );
}

String _mm(double value) {
  final text = value.toStringAsFixed(3);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

double? _parse(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', '.'));
