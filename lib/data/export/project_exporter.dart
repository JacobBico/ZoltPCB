import 'dart:io';

import 'package:archive/archive.dart';

import '../../domain/export/board_document.dart';
import '../../domain/export/schematic_document.dart';
import '../../domain/pcb/pcb.dart';
import '../../domain/symbols/symbols.dart';
import '../../fab/gerber_writer.dart';
import '../../rendering/schematic_pdf.dart';
import '../../rendering/schematic_scene.dart';
import '../../rendering/sheet_overlays.dart';
import '../../domain/models/models.dart';
import '../../kicad/board_project_writer.dart';
import '../../kicad/board_writer.dart';
import '../../kicad/footprint_writer.dart';
import '../../kicad/bom_writer.dart';
import '../../kicad/schematic_writer.dart';
import '../repositories/board_repository.dart';
import '../repositories/footprint_library_repository.dart';
import '../repositories/net_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/part_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/sheet_repository.dart';
import '../repositories/symbol_library_repository.dart';

/// What kind of file an export produced.
enum ExportKind {
  schematic('KiCad schematic', '.kicad_sch'),
  board('KiCad board', '.kicad_pcb'),
  boardProject('KiCad project', '.kicad_pro'),
  bom('Bill of materials', '.csv'),
  fabrication('Gerbers and drill files', '.zip'),
  panel('Panel Gerbers and drill files', '.zip'),
  pdf('Schematic PDF', '.pdf');

  const ExportKind(this.label, this.extension);

  final String label;
  final String extension;
}

/// One written file.
class ExportedFile {
  const ExportedFile({
    required this.kind,
    required this.path,
    required this.fileName,
    required this.byteSize,
  });

  final ExportKind kind;
  final String path;
  final String fileName;
  final int byteSize;

  @override
  String toString() => 'ExportedFile($fileName, $byteSize bytes)';
}

/// Thrown when a project cannot be exported.
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}

/// Turns a stored project into files on disk.
///
/// The assembly step between the repositories and the writers: it gathers a
/// project's parts, nets and symbol definitions into a [SchematicDocument]
/// and hands that to the format writers, which know nothing about storage.
class ProjectExporter {
  ProjectExporter({
    required this.projects,
    required this.parts,
    required this.nets,
    required this.libraries,
    required this.outputDirectory,
    this.boards,
    this.footprints,
    this.notes,
    this.sheets,
  });

  /// The sub-sheets; optional, as a design without them is one sheet.
  final SheetRepository? sheets;

  final ProjectRepository projects;
  final PartRepository parts;
  final NetRepository nets;
  final SymbolLibraryRepository libraries;

  /// The board side. Optional so a build that only ever exports schematics
  /// — and every existing test — needs no board at all.
  final BoardRepository? boards;
  final FootprintLibraryRepository? footprints;

  /// Notes on the sheet; optional for the same reason.
  final NoteRepository? notes;

  /// Where exported files are written. Injected so tests can use a
  /// temporary directory.
  final Directory outputDirectory;

  /// Collects everything the writers need.
  ///
  /// Symbols whose library is no longer installed are simply absent; the
  /// schematic writer falls back to the pin snapshot the project owns, so
  /// the export still describes a complete circuit.
  Future<SchematicDocument> buildDocument(String projectId) async {
    final project = await projects.getById(projectId);
    if (project == null) {
      throw const ExportException('That project no longer exists');
    }

    final partList = await parts.getPartsWithDetails(projectId);
    final netList = await nets.getNets(projectId);
    final hints = await nets.routeHints(projectId);

    final symbols = <String, SymbolDefinition>{};
    for (final libId in partList.map((p) => p.part.libId).toSet()) {
      final symbol = await libraries.loadSymbol(libId);
      if (symbol != null) symbols[libId] = symbol;
    }

    return SchematicDocument(
      project: project,
      parts: partList,
      nets: netList,
      symbols: symbols,
      routeHints: hints,
      drawnWires: await nets.getWires(projectId),
      notes: await notes?.getAll(projectId) ?? const [],
      sheets: await sheets?.getAll(projectId) ?? const [],
    );
  }

  /// Gathers the board, or null when the project has no board worth
  /// writing — nothing placed means nothing to fabricate.
  Future<BoardDocument?> buildBoardDocument(String projectId) async {
    final boards = this.boards;
    final footprints = this.footprints;
    if (boards == null || footprints == null) return null;

    final project = await projects.getById(projectId);
    if (project == null) {
      throw const ExportException('That project no longer exists');
    }

    final placements = await boards.getFootprints(projectId);
    if (placements.where((p) => p.placed).isEmpty &&
        (await boards.getFeatures(projectId)).every((f) => !f.placed)) {
      return null;
    }

    final definitions = <String, FootprintDefinition>{};
    final sources = <String, Object>{};
    for (final libId in placements.map((p) => p.libId).toSet()) {
      final definition = await footprints.loadFootprint(libId);
      if (definition != null) definitions[libId] = definition;
      final node = await footprints.loadFootprintNode(libId);
      if (node != null) sources[libId] = node;
    }

    final netList = await nets.getNets(projectId);
    final scene = BoardScene.build(
      board: await boards.ensureBoard(projectId),
      parts: await parts.getPartsWithDetails(projectId),
      nets: netList,
      placements: placements,
      definitions: definitions,
      tracks: await boards.getTracks(projectId),
      vias: await boards.getVias(projectId),
      edges: await boards.getEdges(projectId),
      zones: await boards.getZones(projectId),
      texts: await boards.getTexts(projectId),
      images: await boards.getImages(projectId),
      netClasses: await boards.getNetClasses(projectId),
      features: await boards.getFeatures(projectId),
      dimensions: await boards.getDimensions(projectId),
    );
    // A feature's footprint is made here, not found in a library.
    for (final feature in scene.features) {
      sources[feature.libId] = FootprintWriter.node(feature.definition);
    }

    final document = BoardDocument(
      project: project,
      scene: scene,
      nets: netList,
      footprintSources: sources,
    );
    // Refused rather than written without them: a board file or a set of
    // Gerbers quietly missing a part is worse than no file at all.
    final missing = document.missingFootprints;
    if (missing.isNotEmpty) {
      throw ExportException(
        'These footprints are not in any installed library, so the board '
        'would be missing them: ${missing.join(', ')}. Re-import the '
        'library or pick another footprint.',
      );
    }
    return document;
  }

  Future<List<ExportedFile>> exportAll(String projectId) async {
    final document = await buildDocument(projectId);
    final files = [
      ...await _writeSchematic(document),
      await _write(document, ExportKind.bom, BomWriter.write(document)),
    ];

    // The board comes out only when there is one. A project that never left
    // the schematic should not produce an empty board file for the user to
    // wonder about.
    final board = await buildBoardDocument(projectId);
    if (board != null) files.addAll(await _writeBoard(board));
    return files;
  }

  /// Everything the project exports, in one zip.
  ///
  /// Sharing several files at once is unreliable on Android — a share sheet
  /// hands some apps only the text, and a `.kicad_sch` has no file type any
  /// of them recognise — whereas one zip is something every app will take.
  /// It is written to [into] (the cache, where the share sheet is allowed
  /// to read from) rather than beside the exported files.
  Future<ExportedFile> exportBundle(
    String projectId, {
    required Directory into,
  }) async {
    final files = await exportAll(projectId);
    if (files.isEmpty) {
      throw const ExportException('There is nothing to export yet');
    }

    final archive = Archive();
    for (final file in files) {
      archive.addFile(
        ArchiveFile.bytes(file.fileName, await File(file.path).readAsBytes()),
      );
    }

    final document = await buildDocument(projectId);
    final name = '${fileNameFor(document.project.name)}.zip';
    if (!into.existsSync()) await into.create(recursive: true);
    final zip = File('${into.path}/$name');
    await zip.writeAsBytes(ZipEncoder().encodeBytes(archive));

    return ExportedFile(
      kind: ExportKind.schematic,
      path: zip.path,
      fileName: name,
      byteSize: await zip.length(),
    );
  }

  Future<List<ExportedFile>> exportBoard(String projectId) async {
    final board = await buildBoardDocument(projectId);
    if (board == null) {
      throw const ExportException('Nothing has been placed on the board yet');
    }
    return _writeBoard(board);
  }

  /// The board and the project file beside it.
  ///
  /// Always both. KiCad keeps the design rules in the project file, so a
  /// `.kicad_pcb` on its own opens with the desktop's default clearance
  /// rather than the one the board was drawn to.
  Future<List<ExportedFile>> _writeBoard(BoardDocument board) async {
    final base = fileNameFor(board.project.name);
    final projectFileName = '$base${ExportKind.boardProject.extension}';

    return [
      await _writeNamed(
        ExportKind.board,
        '$base${ExportKind.board.extension}',
        const BoardWriter().write(board),
      ),
      await _writeNamed(
        ExportKind.boardProject,
        projectFileName,
        BoardProjectWriter.write(board, fileName: projectFileName),
      ),
    ];
  }

  /// Gerbers and drill files, zipped the way a board house takes them.
  Future<ExportedFile> exportFabrication(String projectId) async {
    final board = await buildBoardDocument(projectId);
    if (board == null) {
      throw const ExportException('Nothing has been placed on the board yet');
    }
    final base = fileNameFor(board.project.name);
    final archive = Archive();
    for (final file in [
      ...FabricationWriter.write(board.scene, baseName: base),
      FabricationWriter.positions(board.scene, baseName: base),
    ]) {
      archive.addFile(ArchiveFile.string(file.name, file.content));
    }
    return _writeBytes(
      ExportKind.fabrication,
      '$base-gerbers.zip',
      ZipEncoder().encodeBytes(archive),
    );
  }

  /// Gerbers and drill files for a panel of copies of the board, laid out
  /// by [settings].
  Future<ExportedFile> exportPanel(
    String projectId,
    PanelSettings settings, {
    FabPreset? fab,
  }) async {
    final board = await buildBoardDocument(projectId);
    if (board == null) {
      throw const ExportException('Nothing has been placed on the board yet');
    }
    final base = '${fileNameFor(board.project.name)}-panel';
    final layout = PanelLayout.of(board.scene, settings, fab: fab);
    final archive = Archive();
    for (final file in FabricationWriter.writePanel(
      board.scene,
      layout,
      baseName: base,
      title: board.project.name,
    )) {
      archive.addFile(ArchiveFile.string(file.name, file.content));
    }
    return _writeBytes(
      ExportKind.panel,
      '$base-gerbers.zip',
      ZipEncoder().encodeBytes(archive),
    );
  }

  /// The sheet as a PDF to share with someone who has no KiCad.
  /// A page for each sheet, top sheet first.
  Future<ExportedFile> exportSchematicPdf(String projectId) async {
    final document = await buildDocument(projectId);
    final links = SheetConnections.of(
      parts: document.parts,
      nets: document.nets,
      sheets: document.sheets,
    );
    final pages = <SchematicPdfPage>[];
    for (final sheetId in <String?>[
      null,
      for (final sheet in links.tree.inPageOrder()) sheet.id,
    ]) {
      final sheet = document.onSheet(sheetId);
      final scene = SchematicScene.build(
        paper: document.project.paper,
        parts: sheet.parts,
        nets: sheet.nets,
        symbols: sheet.symbols,
        routeHints: sheet.routeHints,
        drawnWires: sheet.drawnWires,
      );
      final (boxes, labels) = document.sheets.isEmpty
          ? (const <SheetBoxView>[], const <OffSheetLabel>[])
          : sheetOverlays(links: links, scene: scene, sheetId: sheetId);
      pages.add(
        SchematicPdfPage(
          scene: scene,
          notes: sheet.notes,
          sheetBoxes: boxes,
          offSheetLabels: labels,
        ),
      );
    }
    final bytes = await renderSchematicPdfPages(
      pages,
      title: document.project.name,
    );
    return _writeBytes(
      ExportKind.pdf,
      '${fileNameFor(document.project.name)}.pdf',
      bytes,
    );
  }

  Future<ExportedFile> _writeBytes(
    ExportKind kind,
    String fileName,
    List<int> bytes,
  ) async {
    if (!outputDirectory.existsSync()) {
      await outputDirectory.create(recursive: true);
    }
    final file = File('${outputDirectory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return ExportedFile(
      kind: kind,
      path: file.path,
      fileName: fileName,
      byteSize: bytes.length,
    );
  }

  /// The top sheet's file; a hierarchical design's other sheets are
  /// written beside it, where KiCad looks for them.
  Future<ExportedFile> exportSchematic(String projectId) async {
    final document = await buildDocument(projectId);
    return (await _writeSchematic(document)).first;
  }

  /// Every sheet's file, the top one first.
  Future<List<ExportedFile>> _writeSchematic(SchematicDocument document) async {
    final top =
        '${fileNameFor(document.project.name)}'
        '${ExportKind.schematic.extension}';
    final files = const SchematicWriter().writeFiles(document, topFile: top);
    return [
      for (final entry in files.entries)
        await _writeNamed(ExportKind.schematic, entry.key, entry.value),
    ];
  }

  Future<ExportedFile> exportBom(String projectId) async {
    final document = await buildDocument(projectId);
    return _write(document, ExportKind.bom, BomWriter.write(document));
  }

  Future<ExportedFile> _write(
    SchematicDocument document,
    ExportKind kind,
    String contents,
  ) {
    final base = fileNameFor(document.project.name);
    final fileName = kind == ExportKind.bom
        ? '$base-bom${kind.extension}'
        : '$base${kind.extension}';
    return _writeNamed(kind, fileName, contents);
  }

  Future<ExportedFile> _writeNamed(
    ExportKind kind,
    String fileName,
    String contents,
  ) async {
    if (!outputDirectory.existsSync()) {
      await outputDirectory.create(recursive: true);
    }

    final file = File('${outputDirectory.path}/$fileName');
    // A sheet brought in from a folder of its own (`sch/power.kicad_sch`)
    // goes back into that folder, beside the top sheet as KiCad expects.
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);

    return ExportedFile(
      kind: kind,
      path: file.path,
      fileName: fileName,
      byteSize: await file.length(),
    );
  }

  /// Turns a project name into something safe on every filesystem the file
  /// might land on, including the FAT-formatted storage of a phone.
  static String fileNameFor(String projectName) {
    final cleaned = projectName
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (trimmed.isEmpty) return 'schematic';
    return trimmed.length <= 64 ? trimmed : trimmed.substring(0, 64);
  }
}
