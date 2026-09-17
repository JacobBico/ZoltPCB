import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting_bytes.dart';
import '../../core/widgets/panel.dart';
import '../../data/export/project_exporter.dart';
import '../../domain/export/export_preview.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/models/models.dart';

/// Writes the design out and hands the files to the rest of the phone.
///
/// The export is deliberately one-way. A schematic leaves here for a
/// desktop KiCad workflow; nothing comes back, so there is no import to
/// reconcile and no chance of the phone and the desktop disagreeing about
/// which copy is current.
class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  bool _busy = false;
  List<ExportedFile> _lastExport = const [];

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(exportPreviewProvider(widget.project.id));

    return switch (preview) {
      AsyncData(value: final value) when value.isEmpty => const EmptyState(
        icon: Icons.ios_share_outlined,
        title: 'Nothing to export yet',
        message:
            'Add components and connect some pins, and the schematic and '
            'bill of materials can be written out from here.',
      ),
      AsyncData(value: final value) => _ExportBody(
        project: widget.project,
        preview: value,
        busy: _busy,
        lastExport: _lastExport,
        board: ref.watch(boardSceneProvider(widget.project.id)).value,
        onExport: _export,
        onShare: _share,
        onFabrication: () => _makeAndShare(
          'Gerbers',
          () => ref
              .read(projectExporterProvider)
              .exportFabrication(widget.project.id),
        ),
        onPdf: () => _makeAndShare(
          'Schematic PDF',
          () => ref
              .read(projectExporterProvider)
              .exportSchematicPdf(widget.project.id),
        ),
      ),
      AsyncError(:final error) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not prepare the export',
        message: '$error',
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Writes one file and hands it straight to the share sheet — a zip for
  /// the board house, a PDF for whoever asked to see the circuit.
  /// Where a file goes to be handed to another app.
  ///
  /// The cache, because that is what the share sheet is allowed to read
  /// from; the app's own documents folder is private to it, and a file
  /// left there can be reached by nothing else on the phone.
  Directory get _shareDirectory =>
      Directory('${Directory.systemTemp.path}/hintpcb_share');

  /// Hands one file to another app, with its type spelled out.
  ///
  /// Android decides what a share is by what it is given: a share carrying
  /// text is a text message to most apps, whatever files came with it, and
  /// a file whose type it cannot work out is one the Files app will not
  /// take. So this sends the file, its type, and no text.
  Future<void> _handOver(ExportedFile file, String what) async {
    final directory = _shareDirectory;
    if (!directory.existsSync()) await directory.create(recursive: true);
    final copy = await File(
      file.path,
    ).copy('${directory.path}/${file.fileName}');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copy.path, mimeType: _mimeFor(file.fileName))],
        subject: '${widget.project.name} — $what',
      ),
    );
  }

  static String _mimeFor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.zip')) return 'application/zip';
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.csv')) return 'text/csv';
    // KiCad's own files are text, whatever the extension says, and calling
    // them text is what lets a file manager or mail app accept them.
    return 'text/plain';
  }

  Future<void> _makeAndShare(
    String what,
    Future<ExportedFile> Function() make,
  ) async {
    setState(() => _busy = true);
    try {
      final file = await make();
      if (!mounted) return;
      setState(() => _lastExport = [file]);
      await _handOver(file, what);
    } catch (error) {
      if (mounted) _report('$what failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final files = await ref
          .read(projectExporterProvider)
          .exportAll(widget.project.id);
      if (!mounted) return;
      setState(() => _lastExport = files);
      // Said plainly: the folder they go in belongs to the app and nothing
      // else on the phone can open it, so SHARE is how they get out.
      _report(
        'Wrote ${files.length} files — use SHARE to send them out of the app',
      );
    } catch (error) {
      if (mounted) _report('Export failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sends the whole export out as one zip.
  ///
  /// One file rather than several: a share sheet given a handful of files
  /// with no recognised type hands most apps nothing at all, which is why
  /// the schematic never arrived in a mail or a chat.
  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bundle = await ref
          .read(projectExporterProvider)
          .exportBundle(widget.project.id, into: _shareDirectory);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(bundle.path, mimeType: 'application/zip')],
          subject: '${widget.project.name} — HintPCB export',
        ),
      );
    } catch (error) {
      if (mounted) _report('Could not share: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFF3A1D1D)
              : KicadPalette.surfaceRaised,
        ),
      );
  }
}

class _ExportBody extends StatelessWidget {
  const _ExportBody({
    required this.project,
    required this.preview,
    required this.busy,
    required this.lastExport,
    required this.board,
    required this.onExport,
    required this.onShare,
    required this.onFabrication,
    required this.onPdf,
  });

  final Project project;
  final ExportPreview preview;
  final bool busy;
  final List<ExportedFile> lastExport;

  /// Null until the board has been opened at least once. A project that is
  /// only ever a schematic never grows one, and says so rather than
  /// promising board files it will not write.
  final BoardScene? board;

  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onFabrication;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: _summary(context)),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _actions(context)),
        ],
      ),
    );
  }

  /// Whether there is a board worth writing. Nothing placed means no file.
  bool get hasBoard => board != null && board!.footprints.isNotEmpty;

  Widget _summary(BuildContext context) {
    final base = ProjectExporter.fileNameFor(project.name);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHeading('What will be written'),
          const SizedBox(height: 6),
          FieldRow(label: 'Schematic', value: '$base.kicad_sch'),
          FieldRow(label: 'BOM', value: '$base-bom.csv'),
          if (hasBoard) ...[
            FieldRow(label: 'Board', value: '$base.kicad_pcb'),
            // Written alongside the board rather than instead of anything:
            // KiCad keeps the design rules here, so a board without it
            // opens with the desktop's clearance rather than this one's.
            FieldRow(label: 'Rules', value: '$base.kicad_pro'),
          ],
          const SizedBox(height: 8),
          FieldRow(
            label: 'Components',
            value:
                '${preview.partCount} '
                '(${preview.unitCount} symbols on the sheet)',
          ),
          FieldRow(
            label: 'Nets',
            value: '${preview.netCount}, ${preview.namedNetCount} labelled',
          ),
          FieldRow(label: 'BOM lines', value: '${preview.bomLineCount}'),
          if (hasBoard)
            FieldRow(
              label: 'Board',
              value:
                  '${board!.footprints.length} placed, '
                  '${board!.isFullyRouted ? 'fully routed' : '${board!.ratsnest.length} left to route'}',
            ),
          FieldRow(
            label: 'Pins',
            value:
                '${preview.connectedPinCount} connected, '
                '${preview.unconnectedPinCount} free'
                '${preview.noConnectPinCount > 0 ? ", ${preview.noConnectPinCount} no-connect" : ""}',
          ),
          if (preview.hasWarnings) ...[
            const SizedBox(height: 12),
            const PanelHeading('Worth checking first'),
            const SizedBox(height: 4),
            if (preview.missingSymbols.isNotEmpty)
              _Warning(
                text:
                    'Library missing for ${preview.missingSymbols.join(', ')}. '
                    'The pins stored with the part are used instead, so the '
                    'netlist is complete but the symbol will look plain.',
              ),
            if (preview.partsWithoutFootprint.isNotEmpty)
              _Warning(
                text:
                    'No footprint on '
                    '${preview.partsWithoutFootprint.join(', ')}. '
                    'KiCad will need one before the board can be laid out.',
              ),
            if (preview.danglingNets.isNotEmpty)
              _Warning(
                text: 'Only one pin on ${preview.danglingNets.join(', ')}.',
              ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading('Export'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : onExport,
            icon: const Icon(Icons.save_alt, size: 18),
            label: const Text('WRITE FILES'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onShare,
            icon: const Icon(Icons.ios_share, size: 16),
            label: const Text('SHARE'),
          ),
          const SizedBox(height: 16),
          const PanelHeading('To order or to show'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy || !hasBoard ? null : onFabrication,
            icon: const Icon(Icons.precision_manufacturing_outlined, size: 16),
            label: const Text('GERBERS + DRILL'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('SCHEMATIC PDF'),
          ),
          if (hasBoard && board!.zones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Pours are filled with their clearance, and join pads solidly '
              '— no thermal reliefs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Files are written to this app\'s storage, then shared with '
            'whatever you like — a cloud drive, email, a cable.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: KicadPalette.textSecondary,
            ),
          ),
          if (lastExport.isNotEmpty) ...[
            const SizedBox(height: 14),
            const PanelHeading('Last written'),
            const SizedBox(height: 4),
            for (final file in lastExport)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: KicadPalette.wire,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      formatBytes(file.byteSize),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              File(lastExport.first.path).parent.path,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: KicadPalette.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
