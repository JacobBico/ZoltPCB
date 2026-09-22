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
import 'gerber_view.dart';

/// The files a board house gets, shown the way they will read them.
///
/// Everything drawn here is read back out of the generated Gerber and drill
/// files, not taken from the board: if a layer looks wrong here, it is wrong
/// in the file, which is the whole reason to look.
class ProductionPanel extends ConsumerStatefulWidget {
  const ProductionPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProductionPanel> createState() => _ProductionPanelState();
}

class _ProductionPanelState extends ConsumerState<ProductionPanel> {
  final Set<String> _hidden = {};
  BoardScene? _builtFrom;
  List<GerberLayer> _layers = const [];
  List<FabricationFile> _extras = const [];
  Offset _origin = Offset.zero;
  double _pixelsPerMm = 0;
  double _startPixelsPerMm = 0;
  Offset _startFocal = Offset.zero;
  Offset _startOrigin = Offset.zero;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(boardSceneProvider(widget.project.id)).value;
    if (scene == null) return const SizedBox.shrink();
    if (scene.footprints.isEmpty) {
      return const EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'Nothing to make yet',
        message:
            'Place parts on the board and the Gerber, drill and position '
            'files appear here, exactly as they will be sent.',
      );
    }
    if (!identical(scene, _builtFrom)) _build(scene);

    return Row(
      children: [
        Expanded(child: _viewer(scene)),
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: KicadPalette.surface,
            border: Border(left: BorderSide(color: KicadPalette.borderStrong)),
          ),
          child: _sidebar(context),
        ),
      ],
    );
  }

  void _build(BoardScene scene) {
    _builtFrom = scene;
    final base = ProjectExporter.fileNameFor(widget.project.name);
    final files = FabricationWriter.write(scene, baseName: base);
    FabricationFile named(String suffix) =>
        files.firstWhere((f) => f.name.endsWith(suffix));
    GerberImage read(String suffix) =>
        GerberReader.parse(named(suffix).content);

    _layers = [
      GerberLayer(
        file: named('-Edge_Cuts.gbr'),
        label: 'Board outline',
        color: const Color(0xFFE8D44D),
        image: read('-Edge_Cuts.gbr'),
      ),
      GerberLayer(
        file: named('-B_Cu.gbr'),
        label: 'Bottom copper',
        color: const Color(0xFF4D7FC4),
        image: read('-B_Cu.gbr'),
        front: false,
      ),
      GerberLayer(
        file: named('-B_Mask.gbr'),
        label: 'Bottom mask openings',
        color: const Color(0xFF2FA37A),
        image: read('-B_Mask.gbr'),
        front: false,
      ),
      GerberLayer(
        file: named('-B_Silkscreen.gbr'),
        label: 'Bottom silkscreen',
        color: const Color(0xFFB9A7E0),
        image: read('-B_Silkscreen.gbr'),
        front: false,
      ),
      GerberLayer(
        file: named('-B_Paste.gbr'),
        label: 'Bottom paste',
        color: const Color(0xFF9A9A9A),
        image: read('-B_Paste.gbr'),
        front: false,
      ),
      // Inner copper, bottom up so the stack draws the way it is pressed.
      // Hidden to begin with: the view opens on the board as it arrives,
      // and the inner layers are inside it.
      for (final layer in scene.board.copperLayers.reversed)
        if (layer.isInner)
          GerberLayer(
            file: named('-${layer.layer.token.replaceAll('.', '_')}.gbr'),
            label: '${layer.label} copper',
            color: KicadPalette.innerCopper[layer.index - 1],
            image: read('-${layer.layer.token.replaceAll('.', '_')}.gbr'),
          ),
      GerberLayer(
        file: named('-F_Cu.gbr'),
        label: 'Top copper',
        color: const Color(0xFFD0503A),
        image: read('-F_Cu.gbr'),
        front: true,
      ),
      GerberLayer(
        file: named('-F_Mask.gbr'),
        label: 'Top mask openings',
        color: const Color(0xFF3CC08E),
        image: read('-F_Mask.gbr'),
        front: true,
      ),
      GerberLayer(
        file: named('-F_Paste.gbr'),
        label: 'Top paste',
        color: const Color(0xFFBDBDBD),
        image: read('-F_Paste.gbr'),
        front: true,
      ),
      GerberLayer(
        file: named('-F_Silkscreen.gbr'),
        label: 'Top silkscreen',
        color: const Color(0xFFF2F2F2),
        image: read('-F_Silkscreen.gbr'),
        front: true,
      ),
      GerberLayer(
        file: named('-PTH.drl'),
        label: 'Plated holes',
        color: const Color(0xFF101010),
        image: null,
        holes: GerberReader.parseDrill(named('-PTH.drl').content),
      ),
      GerberLayer(
        file: named('-NPTH.drl'),
        label: 'Unplated holes',
        color: const Color(0xFF101010),
        image: null,
        holes: GerberReader.parseDrill(named('-NPTH.drl').content),
      ),
    ];
    _extras = [FabricationWriter.positions(scene, baseName: base)];
    if (_hidden.isEmpty) {
      // Opens looking at the top of the board, as it will arrive.
      _hidden.addAll({
        for (final layer in _layers)
          if (layer.front == false ||
              layer.file.name.contains('Paste') ||
              layer.file.name.contains('-In'))
            layer.file.name,
      });
    }
  }

  // --- viewer ----------------------------------------------------------

  Widget _viewer(BoardScene scene) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_pixelsPerMm <= 0) _fit(scene, size);
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
                      layers: [
                        for (final layer in _layers)
                          if (!_hidden.contains(layer.file.name)) layer,
                      ],
                      origin: _origin,
                      pixelsPerMm: _pixelsPerMm,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Wrap(
                spacing: 6,
                children: [
                  _preset(
                    'Top',
                    (l) => l.front != false && !l.file.name.contains('-In'),
                  ),
                  _preset(
                    'Bottom',
                    (l) => l.front != true && !l.file.name.contains('-In'),
                  ),
                  _preset('All', (_) => true),
                  ActionChip(
                    avatar: const Icon(Icons.fit_screen, size: 16),
                    label: const Text('Fit'),
                    onPressed: () => setState(() => _fit(scene, size)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _preset(String label, bool Function(GerberLayer) shows) => ActionChip(
    label: Text(label),
    onPressed: () => setState(() {
      _hidden
        ..clear()
        ..addAll({
          for (final layer in _layers)
            if (!shows(layer) || layer.file.name.contains('Paste'))
              layer.file.name,
        });
    }),
  );

  void _fit(BoardScene scene, Size size) {
    final bounds = scene.outline.bounds.inflate(3);
    if (size.isEmpty || bounds.isEmpty) return;
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

  Widget _sidebar(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                  child: Text('LAYERS', style: heading),
                ),
                for (final layer in _layers)
                  GerberFileRow(
                    label: layer.label,
                    fileName: layer.file.name,
                    bytes: layer.file.content.length,
                    color: layer.color,
                    visible: !_hidden.contains(layer.file.name),
                    onToggle: () => setState(() {
                      if (!_hidden.remove(layer.file.name)) {
                        _hidden.add(layer.file.name);
                      }
                    }),
                    onOpen: () => showFabricationFile(context, layer.file),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text('FOR ASSEMBLY', style: heading),
                ),
                for (final file in _extras)
                  GerberFileRow(
                    label: 'Part positions',
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
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('SHARE ZIP'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(projectExporterProvider)
          .exportFabrication(widget.project.id);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${widget.project.name} — production files',
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
