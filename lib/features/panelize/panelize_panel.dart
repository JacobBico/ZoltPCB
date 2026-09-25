import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../data/export/project_exporter.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../fab/gerber_reader.dart';
import '../../fab/gerber_writer.dart';
import '../production/gerber_view.dart';

/// Copies of the board laid out as one panel, and the files to make it.
///
/// Like the Production section, the picture is read back out of the
/// generated files: the milled edge, the perforation and the fiducials
/// shown are the ones the board house will get.
class PanelizePanel extends ConsumerStatefulWidget {
  const PanelizePanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<PanelizePanel> createState() => _PanelizePanelState();
}

class _PanelizePanelState extends ConsumerState<PanelizePanel> {
  PanelSettings? _settings;
  BoardScene? _builtFrom;
  PanelSettings? _builtWith;
  FabPreset? _builtFab;
  PanelLayout? _layout;

  /// The panel's fiducials, ringed on the preview: a 1 mm copper dot is
  /// otherwise hard to find on a whole panel.
  List<(Offset, double)> _fiducialRings = const [];
  List<FabricationFile> _files = const [];
  List<GerberLayer> _layers = const [];
  Size? _fittedTo;

  Offset _origin = Offset.zero;
  double _pixelsPerMm = 0;
  double _startPixelsPerMm = 0;
  Offset _startFocal = Offset.zero;
  Offset _startOrigin = Offset.zero;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(boardSceneProvider(widget.project.id)).value;
    final stored = ref.watch(projectSettingsProvider(widget.project.id)).value;
    if (scene == null || stored == null) return const SizedBox.shrink();
    if (scene.footprints.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_view_outlined,
        title: 'Nothing to panelize yet',
        message:
            'Place parts on the board, and copies of it can be laid out '
            'here as one panel, ready for a board house to make.',
      );
    }
    final settings = _settings ??= PanelSettings.decode(
      stored[PanelSettings.settingsKey],
    );
    final fab = FabPresets.byId(stored[FabPresets.settingsKey]);
    if (!identical(scene, _builtFrom) ||
        !identical(settings, _builtWith) ||
        fab != _builtFab) {
      _build(scene, settings, fab);
    }

    return Row(
      children: [
        Expanded(child: _viewer()),
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: KicadPalette.surface,
            border: Border(left: BorderSide(color: KicadPalette.borderStrong)),
          ),
          child: _sidebar(context, settings),
        ),
      ],
    );
  }

  void _build(BoardScene scene, PanelSettings settings, FabPreset? fab) {
    _builtFrom = scene;
    _builtWith = settings;
    _builtFab = fab;
    final layout = PanelLayout.of(scene, settings, fab: fab);
    if (_layout?.panel.size != layout.panel.size) _pixelsPerMm = 0;
    _layout = layout;
    _fiducialRings = [
      for (final at in layout.fiducials) (at, PanelSettings.fiducialCopper),
    ];
    final base = '${ProjectExporter.fileNameFor(widget.project.name)}-panel';
    _files = FabricationWriter.writePanel(
      scene,
      layout,
      baseName: base,
      title: widget.project.name,
    );
    FabricationFile? named(String suffix) =>
        _files.where((f) => f.name.endsWith(suffix)).firstOrNull;
    GerberLayer? gerber(String suffix, String label, Color color) {
      final file = named(suffix);
      if (file == null) return null;
      return GerberLayer(
        file: file,
        label: label,
        color: color,
        image: GerberReader.parse(file.content),
      );
    }

    GerberLayer? drill(String suffix, String label) {
      final file = named(suffix);
      if (file == null) return null;
      return GerberLayer(
        file: file,
        label: label,
        color: const Color(0xFF101010),
        image: null,
        holes: GerberReader.parseDrill(file.content),
      );
    }

    _layers = [
      ?gerber('-F_Cu.gbr', 'Top copper', const Color(0xFFD0503A)),
      ?gerber('-F_Silkscreen.gbr', 'Top silkscreen', const Color(0xFFF2F2F2)),
      ?gerber('-Edge_Cuts.gbr', 'Milled edge', const Color(0xFFE8D44D)),
      ?gerber('-V_Score.gbr', 'V-score', const Color(0xFF4FC3F7)),
      ?drill('-PTH.drl', 'Plated holes'),
      ?drill('-NPTH.drl', 'Unplated holes'),
    ];
  }

  // --- viewer ----------------------------------------------------------

  Widget _viewer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_pixelsPerMm <= 0 || _fittedTo != size) _fit(size);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: (details) {
                  _startPixelsPerMm = _pixelsPerMm;
                  _startFocal = details.localFocalPoint;
                  _startOrigin = _origin;
                },
                onScaleUpdate: (details) => setState(() {
                  final zoom = (_startPixelsPerMm * details.scale).clamp(
                    0.5,
                    400.0,
                  );
                  final anchor =
                      (_startFocal - _startOrigin) / _startPixelsPerMm;
                  _pixelsPerMm = zoom;
                  _origin = details.localFocalPoint - anchor * zoom;
                }),
                child: ClipRect(
                  child: CustomPaint(
                    size: size,
                    painter: GerberPainter(
                      layers: _layers,
                      origin: _origin,
                      pixelsPerMm: _pixelsPerMm,
                      ringed: _fiducialRings,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
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
  }

  void _fit(Size size) {
    final layout = _layout;
    if (layout == null || size.isEmpty) return;
    final bounds = layout.panel.inflate(3);
    _fittedTo = size;
    _pixelsPerMm = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );
    _origin = Offset(
      (size.width - bounds.width * _pixelsPerMm) / 2 -
          bounds.left * _pixelsPerMm,
      (size.height - bounds.height * _pixelsPerMm) / 2 -
          bounds.top * _pixelsPerMm,
    );
  }

  // --- sidebar ---------------------------------------------------------

  /// Shown at once; written to the project when [save] (a slider saves when
  /// it is let go, not on every step of the drag).
  void _set(PanelSettings settings, {bool save = true}) {
    setState(() => _settings = settings);
    if (save) _save();
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    await ref.read(projectSettingsRepositoryProvider).setAll(
      widget.project.id,
      {PanelSettings.settingsKey: settings.encode()},
    );
  }

  Widget _sidebar(BuildContext context, PanelSettings settings) {
    final theme = Theme.of(context);
    final layout = _layout!;
    final heading = theme.textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(text, style: heading),
    );
    final bites = settings.join == PanelJoin.mouseBites;

    return SafeArea(
      top: false,
      left: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                title('PANEL'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${layout.panel.width.toStringAsFixed(1)} × '
                    '${layout.panel.height.toStringAsFixed(1)} mm · '
                    '${layout.copies.length} '
                    '${layout.copies.length == 1 ? 'board' : 'boards'}',
                    key: const ValueKey('panel-size'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _Count(
                  label: 'Rows',
                  keyName: 'panel-rows',
                  value: settings.rows,
                  onChanged: (v) => _set(settings.copyWith(rows: v)),
                ),
                _Count(
                  label: 'Columns',
                  keyName: 'panel-columns',
                  value: settings.columns,
                  onChanged: (v) => _set(settings.copyWith(columns: v)),
                ),
                title('JOINED BY'),
                _Choice<PanelJoin>(
                  keyName: 'panel-join',
                  values: PanelJoin.values,
                  selected: settings.join,
                  label: (j) => j.label,
                  onChanged: (j) => _set(settings.copyWith(join: j)),
                ),
                if (bites) ...[
                  _Slide(
                    label: 'Milled gap',
                    keyName: 'panel-gap',
                    value: settings.spacing,
                    min: PanelSettings.minSpacing,
                    max: 5,
                    onChanged: (v) =>
                        _set(settings.copyWith(spacing: v), save: false),
                    onChangeEnd: (_) => _save(),
                  ),
                  _Slide(
                    label: 'Tab width',
                    keyName: 'panel-tab-width',
                    value: settings.tabWidth,
                    min: 2,
                    max: 10,
                    onChanged: (v) =>
                        _set(settings.copyWith(tabWidth: v), save: false),
                    onChangeEnd: (_) => _save(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                    child: Text(
                      'Tabs per edge',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  _Choice<int>(
                    keyName: 'panel-tabs',
                    values: const [0, 1, 2, 3],
                    selected: settings.tabsPerEdge.clamp(0, 3),
                    label: (n) => n == 0 ? 'Auto' : '$n',
                    onChanged: (n) => _set(settings.copyWith(tabsPerEdge: n)),
                  ),
                ],
                title('RAILS'),
                _Choice<PanelRails>(
                  keyName: 'panel-rails',
                  values: PanelRails.values,
                  selected: settings.rails,
                  label: (r) => r.label,
                  onChanged: (r) => _set(settings.copyWith(rails: r)),
                ),
                if (settings.rails != PanelRails.none) ...[
                  _Slide(
                    label: 'Rail width',
                    keyName: 'panel-rail-width',
                    value: settings.railWidth,
                    min: 3,
                    max: 15,
                    onChanged: (v) =>
                        _set(settings.copyWith(railWidth: v), save: false),
                    onChangeEnd: (_) => _save(),
                  ),
                  SwitchListTile(
                    key: const ValueKey('panel-fiducials'),
                    dense: true,
                    title: const Text('Fiducials'),
                    subtitle: const Text('Three, for the placement camera'),
                    value: settings.fiducials,
                    onChanged: (v) => _set(settings.copyWith(fiducials: v)),
                  ),
                  SwitchListTile(
                    key: const ValueKey('panel-tooling'),
                    dense: true,
                    title: const Text('Tooling holes'),
                    subtitle: const Text('One in each corner'),
                    value: settings.toolingHoles,
                    onChanged: (v) => _set(settings.copyWith(toolingHoles: v)),
                  ),
                  if (settings.toolingHoles)
                    _Slide(
                      label: 'Tooling hole',
                      keyName: 'panel-tooling-size',
                      value: settings.toolingDiameter,
                      min: 1,
                      max: 3.2,
                      onChanged: (v) => _set(
                        settings.copyWith(toolingDiameter: v),
                        save: false,
                      ),
                      onChangeEnd: (_) => _save(),
                    ),
                ],
                if (layout.warnings.isNotEmpty) ...[
                  title('CHECK'),
                  for (final warning in layout.warnings)
                    ListTile(
                      key: const ValueKey('panel-warning'),
                      dense: true,
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: KicadPalette.warning,
                        size: 20,
                      ),
                      title: Text(warning),
                    ),
                ],
                title('FILES'),
                for (final file in _files)
                  GerberFileRow(
                    label: _describe(file.name),
                    fileName: file.name,
                    bytes: file.content.length,
                    color: null,
                    visible: true,
                    onToggle: null,
                    onOpen: () => showFabricationFile(context, file),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: KicadPalette.border),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton.icon(
              key: const ValueKey('panel-share'),
              onPressed: _busy ? null : () => _share(settings),
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('SHARE PANEL ZIP'),
            ),
          ),
        ],
      ),
    );
  }

  static String _describe(String name) {
    final layer = RegExp(
      r'-([A-Za-z0-9_]+)\.(gbr|drl|txt)$',
    ).firstMatch(name)?.group(1);
    return switch (layer) {
      'F_Cu' => 'Top copper',
      'B_Cu' => 'Bottom copper',
      'F_Mask' => 'Top mask openings',
      'B_Mask' => 'Bottom mask openings',
      'F_Paste' => 'Top paste',
      'B_Paste' => 'Bottom paste',
      'F_Silkscreen' => 'Top silkscreen',
      'B_Silkscreen' => 'Bottom silkscreen',
      'Edge_Cuts' => 'Milled edge',
      'V_Score' => 'V-score lines',
      'PTH' => 'Plated holes',
      'NPTH' => 'Unplated holes and perforation',
      'panel' => 'Notes for the board house',
      final String inner when inner.startsWith('In') =>
        'Inner copper ${inner.substring(2).split('_').first}',
      _ => name,
    };
  }

  Future<void> _share(PanelSettings settings) async {
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(projectExporterProvider)
          .exportPanel(widget.project.id, settings, fab: _builtFab);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${widget.project.name} — panel files',
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A count with a minus and a plus.
class _Count extends StatelessWidget {
  const _Count({
    required this.label,
    required this.keyName,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String keyName;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          key: ValueKey('$keyName-minus'),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            key: ValueKey('$keyName-value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: ValueKey('$keyName-plus'),
          onPressed: value < 20 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

/// One of a few, side by side.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.keyName,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String keyName;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: SegmentedButton<T>(
      key: ValueKey(keyName),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final value in values)
          ButtonSegment(
            value: value,
            label: Text(label(value), style: const TextStyle(fontSize: 12)),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (chosen) => onChanged(chosen.single),
    ),
  );
}

/// A length in millimetres on a slider, a tenth at a time.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.label,
    required this.keyName,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String keyName;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
    child: Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            '$label\n${value.toStringAsFixed(1)} mm',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            key: ValueKey(keyName),
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            onChanged: (v) => onChanged((v * 10).round() / 10),
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    ),
  );
}
