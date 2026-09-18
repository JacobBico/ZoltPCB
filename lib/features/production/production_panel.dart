import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting_bytes.dart';
import '../../core/widgets/panel.dart';
import '../../data/export/project_exporter.dart';
import '../../domain/models/models.dart';
import '../../domain/pcb/pcb.dart';
import '../../fab/gerber_reader.dart';
import '../../fab/gerber_writer.dart';

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

/// One layer as the viewer shows it.
class _Layer {
  _Layer({
    required this.file,
    required this.label,
    required this.color,
    required this.image,
    this.holes = const [],
    this.front,
  });

  final FabricationFile file;
  final String label;
  final Color color;
  final GerberImage? image;
  final List<DrillHole> holes;

  /// True for a top layer, false for a bottom one, null for both sides.
  final bool? front;
}

class _ProductionPanelState extends ConsumerState<ProductionPanel> {
  final Set<String> _hidden = {};
  BoardScene? _builtFrom;
  List<_Layer> _layers = const [];
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
      _Layer(
        file: named('-Edge_Cuts.gbr'),
        label: 'Board outline',
        color: const Color(0xFFE8D44D),
        image: read('-Edge_Cuts.gbr'),
      ),
      _Layer(
        file: named('-B_Cu.gbr'),
        label: 'Bottom copper',
        color: const Color(0xFF4D7FC4),
        image: read('-B_Cu.gbr'),
        front: false,
      ),
      _Layer(
        file: named('-B_Mask.gbr'),
        label: 'Bottom mask openings',
        color: const Color(0xFF2FA37A),
        image: read('-B_Mask.gbr'),
        front: false,
      ),
      _Layer(
        file: named('-B_Silkscreen.gbr'),
        label: 'Bottom silkscreen',
        color: const Color(0xFFB9A7E0),
        image: read('-B_Silkscreen.gbr'),
        front: false,
      ),
      _Layer(
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
          _Layer(
            file: named('-${layer.layer.token.replaceAll('.', '_')}.gbr'),
            label: '${layer.label} copper',
            color: KicadPalette.innerCopper[layer.index - 1],
            image: read('-${layer.layer.token.replaceAll('.', '_')}.gbr'),
          ),
      _Layer(
        file: named('-F_Cu.gbr'),
        label: 'Top copper',
        color: const Color(0xFFD0503A),
        image: read('-F_Cu.gbr'),
        front: true,
      ),
      _Layer(
        file: named('-F_Mask.gbr'),
        label: 'Top mask openings',
        color: const Color(0xFF3CC08E),
        image: read('-F_Mask.gbr'),
        front: true,
      ),
      _Layer(
        file: named('-F_Paste.gbr'),
        label: 'Top paste',
        color: const Color(0xFFBDBDBD),
        image: read('-F_Paste.gbr'),
        front: true,
      ),
      _Layer(
        file: named('-F_Silkscreen.gbr'),
        label: 'Top silkscreen',
        color: const Color(0xFFF2F2F2),
        image: read('-F_Silkscreen.gbr'),
        front: true,
      ),
      _Layer(
        file: named('-PTH.drl'),
        label: 'Plated holes',
        color: const Color(0xFF101010),
        image: null,
        holes: GerberReader.parseDrill(named('-PTH.drl').content),
      ),
      _Layer(
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
                    painter: _GerberPainter(
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

  Widget _preset(String label, bool Function(_Layer) shows) => ActionChip(
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
                  _LayerRow(
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
                    onOpen: () => _showFile(context, layer.file),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text('FOR ASSEMBLY', style: heading),
                ),
                for (final file in _extras)
                  _LayerRow(
                    label: 'Part positions',
                    fileName: file.name,
                    bytes: file.content.length,
                    color: null,
                    visible: true,
                    onToggle: null,
                    onOpen: () => _showFile(context, file),
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

  Future<void> _showFile(BuildContext context, FabricationFile file) {
    final lines = file.content.split('\n');
    const shown = 3000;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(file.name),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: 640,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                ...lines.take(shown),
                if (lines.length > shown)
                  '… ${lines.length - shown} more lines in the file',
              ].join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('CLOSE'),
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

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.label,
    required this.fileName,
    required this.bytes,
    required this.color,
    required this.visible,
    required this.onToggle,
    required this.onOpen,
  });

  final String label;
  final String fileName;
  final int bytes;
  final Color? color;
  final bool visible;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            if (onToggle != null)
              Checkbox(value: visible, onChanged: (_) => onToggle!())
            else
              const SizedBox(
                width: 48,
                child: Icon(Icons.table_rows, size: 18),
              ),
            if (color != null)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: KicadPalette.border),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    '$fileName · ${formatBytes(bytes)}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Draws Gerber layers bottom first, each in its own compositing layer so a
/// clear-polarity shape cuts only its own layer.
class _GerberPainter extends CustomPainter {
  _GerberPainter({
    required this.layers,
    required this.origin,
    required this.pixelsPerMm,
  });

  final List<_Layer> layers;
  final Offset origin;
  final double pixelsPerMm;

  Offset _screen(Offset mm) => origin + mm * pixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF14171A),
    );

    for (final layer in layers) {
      final image = layer.image;
      if (image != null) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromARGB(210, 255, 255, 255),
        );
        for (final shape in image.shapes) {
          final paint = Paint()
            ..color = layer.color
            ..blendMode = shape.clear ? BlendMode.clear : BlendMode.srcOver;
          switch (shape) {
            case GerberStroke(:final points, :final width):
              final path = Path()
                ..moveTo(_screen(points.first).dx, _screen(points.first).dy);
              for (final p in points.skip(1)) {
                path.lineTo(_screen(p).dx, _screen(p).dy);
              }
              canvas.drawPath(
                path,
                paint
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(1, width * pixelsPerMm)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
            case GerberFlash(:final at, :final aperture):
              final centre = _screen(at);
              final w = aperture.width * pixelsPerMm;
              final h = aperture.height * pixelsPerMm;
              switch (aperture.kind) {
                case 'C':
                  canvas.drawCircle(centre, w / 2, paint);
                case 'O':
                  canvas.drawRRect(
                    RRect.fromRectAndRadius(
                      Rect.fromCenter(center: centre, width: w, height: h),
                      Radius.circular(math.min(w, h) / 2),
                    ),
                    paint,
                  );
                default:
                  canvas.drawRect(
                    Rect.fromCenter(center: centre, width: w, height: h),
                    paint,
                  );
              }
            case GerberRegion(:final points):
              final path = Path()
                ..moveTo(_screen(points.first).dx, _screen(points.first).dy);
              for (final p in points.skip(1)) {
                path.lineTo(_screen(p).dx, _screen(p).dy);
              }
              path.close();
              canvas.drawPath(path, paint);
          }
        }
        canvas.restore();
      }

      for (final hole in layer.holes) {
        canvas.drawCircle(
          _screen(hole.at),
          math.max(1, hole.diameter * pixelsPerMm / 2),
          Paint()..color = layer.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GerberPainter old) =>
      old.layers.length != layers.length ||
      !List.generate(
        layers.length,
        (i) => identical(layers[i], old.layers[i]),
      ).every((same) => same) ||
      old.origin != origin ||
      old.pixelsPerMm != pixelsPerMm;
}
