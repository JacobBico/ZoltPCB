import '../data/editors/own_library_store.dart';
import '../data/import/kicad_project_importer.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/net_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/part_repository.dart';
import '../data/export/project_exporter.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/board_repository.dart';
import '../data/repositories/board_sync.dart';
import '../data/repositories/snapshot_repository.dart';
import '../data/repositories/project_settings_repository.dart';
import '../domain/erc/erc.dart';
import '../data/archive/project_archive.dart';
import '../data/repositories/footprint_library_repository.dart';
import '../data/repositories/symbol_library_repository.dart';
import '../data/libraries/library_file_storage.dart';
import '../domain/models/models.dart';
import '../domain/export/export_preview.dart';
import '../domain/pcb/pcb.dart';
import '../domain/symbols/symbols.dart';

/// The application database. Kept alive for the process lifetime; overridden
/// with an in-memory database in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);

final partRepositoryProvider = Provider<PartRepository>(
  (ref) => PartRepository(ref.watch(databaseProvider)),
);

final netRepositoryProvider = Provider<NetRepository>(
  (ref) => NetRepository(ref.watch(databaseProvider)),
);

/// The schematic wires the user drew, for a project.
final schematicWiresProvider =
    StreamProvider.family<List<SchematicWire>, String>(
      (ref, projectId) =>
          ref.watch(netRepositoryProvider).watchWires(projectId),
      isAutoDispose: true,
    );

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(databaseProvider)),
);

/// Text and boxes on a project's schematic sheet.
final schematicNotesProvider =
    StreamProvider.family<List<SchematicNote>, String>(
      (ref, projectId) => ref.watch(noteRepositoryProvider).watch(projectId),
      isAutoDispose: true,
    );

/// The user's own symbols and footprints.
final ownLibraryStoreProvider = Provider<OwnLibraryStore>(
  (ref) => OwnLibraryStore(
    symbols: ref.watch(symbolLibraryRepositoryProvider),
    footprints: ref.watch(footprintLibraryRepositoryProvider),
  ),
);

/// Opens KiCad projects made on a desktop.
final kicadImporterProvider = Provider<KicadProjectImporter>(
  (ref) => KicadProjectImporter(
    projects: ref.watch(projectRepositoryProvider),
    parts: ref.watch(partRepositoryProvider),
    nets: ref.watch(netRepositoryProvider),
    boards: ref.watch(boardRepositoryProvider),
    symbols: ref.watch(symbolLibraryRepositoryProvider),
    footprints: ref.watch(footprintLibraryRepositoryProvider),
  ),
);

/// Every project, most recently modified first.
final projectListProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

/// A single project, or null once it has been deleted.
final projectProvider = StreamProvider.family<Project?, String>(
  (ref, projectId) => ref.watch(projectRepositoryProvider).watchById(projectId),
  isAutoDispose: true,
);

final projectPartsProvider =
    StreamProvider.family<List<PartWithDetails>, String>(
      (ref, projectId) =>
          ref.watch(partRepositoryProvider).watchPartsWithDetails(projectId),
      isAutoDispose: true,
    );

final projectNetsProvider =
    StreamProvider.family<List<NetWithEndpoints>, String>(
      (ref, projectId) => ref.watch(netRepositoryProvider).watchNets(projectId),
      isAutoDispose: true,
    );

/// The project list with part and net counts.
final projectSummariesProvider = StreamProvider<List<ProjectSummary>>(
  (ref) => ref.watch(projectRepositoryProvider).watchSummaries(),
);

/// Where imported `.kicad_sym` files are stored on the device.
///
/// Overridden with a temporary directory in tests.
final symbolStorageProvider = Provider<LibraryFileStorage>((ref) {
  throw UnimplementedError('symbolStorageProvider must be overridden');
});

final symbolLibraryRepositoryProvider = Provider<SymbolLibraryRepository>(
  (ref) => SymbolLibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(symbolStorageProvider),
  ),
);

/// Every imported library, by nickname.
final symbolLibrariesProvider = StreamProvider<List<SymbolLibraryInfo>>(
  (ref) => ref.watch(symbolLibraryRepositoryProvider).watchLibraries(),
);

/// The current component-search query.
final symbolSearchQueryProvider = NotifierProvider<SymbolSearchQuery, String>(
  SymbolSearchQuery.new,
);

class SymbolSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Restricts the component search to one library, or null for all of them.
final symbolLibraryFilterProvider =
    NotifierProvider<SymbolLibraryFilter, String?>(SymbolLibraryFilter.new);

class SymbolLibraryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? libraryId) => state = libraryId;
}

/// The library filter used when picking a microcontroller, kept apart from
/// the Components section's own so a filter chosen there — Device, say —
/// cannot leave the chip picker empty.
final mcuLibraryFilterProvider = NotifierProvider<SymbolLibraryFilter, String?>(
  SymbolLibraryFilter.new,
);

/// Search results for the current query and filter.
/// Component search results. The flag narrows it to microcontrollers, for
/// the pinout explorer — nobody needs the alternate functions of a diode.
final symbolSearchProvider =
    FutureProvider.family<List<SymbolIndexEntry>, bool>((
      ref,
      microcontrollersOnly,
    ) {
      final query = ref.watch(symbolSearchQueryProvider);
      final libraryId = ref.watch(
        microcontrollersOnly
            ? mcuLibraryFilterProvider
            : symbolLibraryFilterProvider,
      );
      // Re-run whenever the set of imported libraries changes.
      ref.watch(symbolLibrariesProvider);
      return ref
          .watch(symbolLibraryRepositoryProvider)
          .search(
            query,
            libraryId: libraryId,
            microcontrollersOnly: microcontrollersOnly,
          );
    });

/// The fully resolved definition of one symbol.
final symbolDefinitionProvider =
    FutureProvider.family<SymbolDefinition?, String>(
      (ref, libId) =>
          ref.watch(symbolLibraryRepositoryProvider).loadSymbol(libId),
      isAutoDispose: true,
    );

/// The library definitions for every component in a project, keyed by
/// `lib_id`.
///
/// A symbol whose library has since been removed is simply absent: the
/// canvas falls back to drawing the pins the project already owns.
final projectSymbolsProvider =
    FutureProvider.family<Map<String, SymbolDefinition>, String>((
      ref,
      projectId,
    ) async {
      final parts = await ref.watch(projectPartsProvider(projectId).future);
      final libraries = ref.watch(symbolLibraryRepositoryProvider);

      final result = <String, SymbolDefinition>{};
      for (final libId in parts.map((p) => p.part.libId).toSet()) {
        final symbol = await libraries.loadSymbol(libId);
        if (symbol != null) result[libId] = symbol;
      }
      return result;
    }, isAutoDispose: true);

// --- the board -------------------------------------------------------

/// Where imported footprint libraries are stored on the device.
///
/// A separate directory from symbols, so a `Device` symbol library and a
/// `Device` footprint library cannot overwrite one another.
final footprintStorageProvider = Provider<LibraryFileStorage>((ref) {
  throw UnimplementedError('footprintStorageProvider must be overridden');
});

final footprintLibraryRepositoryProvider = Provider<FootprintLibraryRepository>(
  (ref) => FootprintLibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(footprintStorageProvider),
  ),
);

final footprintLibrariesProvider = StreamProvider<List<FootprintLibraryInfo>>(
  (ref) => ref.watch(footprintLibraryRepositoryProvider).watchLibraries(),
);

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(databaseProvider)),
);

/// A project's board, brought into existence the first time it is watched.
final boardProvider = StreamProvider.family<Board, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchBoard(projectId),
  isAutoDispose: true,
);

final boardFootprintsProvider =
    StreamProvider.family<List<PlacedFootprintRef>, String>(
      (ref, projectId) =>
          ref.watch(boardRepositoryProvider).watchFootprints(projectId),
      isAutoDispose: true,
    );

final boardTracksProvider = StreamProvider.family<List<Track>, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchTracks(projectId),
  isAutoDispose: true,
);

final boardViasProvider = StreamProvider.family<List<Via>, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchVias(projectId),
  isAutoDispose: true,
);

/// The footprint definitions a project's board needs, keyed by `lib_id`.
///
/// A footprint whose library has been removed is simply absent. Unlike a
/// symbol there is nothing to fall back on — the project never snapshotted
/// pads — so the board reports the gap rather than drawing something wrong.
final projectFootprintsProvider =
    FutureProvider.family<Map<String, FootprintDefinition>, String>((
      ref,
      projectId,
    ) async {
      final placements = await ref.watch(
        boardFootprintsProvider(projectId).future,
      );
      final libraries = ref.watch(footprintLibraryRepositoryProvider);

      final result = <String, FootprintDefinition>{};
      for (final libId in placements.map((p) => p.libId).toSet()) {
        final footprint = await libraries.loadFootprint(libId);
        if (footprint != null) result[libId] = footprint;
      }
      return result;
    }, isAutoDispose: true);

/// Everything the board canvas draws, assembled from the schematic's parts
/// and nets and the board's own placement and copper.
final boardSceneProvider = FutureProvider.family<BoardScene, String>((
  ref,
  projectId,
) async {
  final board = await ref.watch(boardProvider(projectId).future);
  final parts = await ref.watch(projectPartsProvider(projectId).future);
  final nets = await ref.watch(projectNetsProvider(projectId).future);
  final placements = await ref.watch(boardFootprintsProvider(projectId).future);
  final definitions = await ref.watch(
    projectFootprintsProvider(projectId).future,
  );
  final tracks = await ref.watch(boardTracksProvider(projectId).future);
  final vias = await ref.watch(boardViasProvider(projectId).future);
  final edges = await ref.watch(boardEdgesProvider(projectId).future);
  final zones = await ref.watch(boardZonesProvider(projectId).future);
  final texts = await ref.watch(boardTextsProvider(projectId).future);
  final netClasses = await ref.watch(netClassesProvider(projectId).future);

  return BoardScene.build(
    board: board,
    parts: parts,
    nets: nets,
    placements: placements,
    definitions: definitions,
    tracks: tracks,
    vias: vias,
    edges: edges,
    zones: zones,
    texts: texts,
    netClasses: netClasses,
  );
}, isAutoDispose: true);

/// The project's named net classes.
final netClassesProvider = StreamProvider.family<List<NetClass>, String>(
  (ref, projectId) =>
      ref.watch(boardRepositoryProvider).watchNetClasses(projectId),
  isAutoDispose: true,
);

/// Free silkscreen text on the board.
final boardTextsProvider = StreamProvider.family<List<BoardText>, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchTexts(projectId),
  isAutoDispose: true,
);

/// The extra shapes on the board's Edge.Cuts layer.
final boardEdgesProvider = StreamProvider.family<List<BoardEdge>, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchEdges(projectId),
  isAutoDispose: true,
);

/// The board's copper pours.
final boardZonesProvider = StreamProvider.family<List<BoardZone>, String>(
  (ref, projectId) => ref.watch(boardRepositoryProvider).watchZones(projectId),
  isAutoDispose: true,
);

/// Brings a board up to date with its schematic.
final boardSyncProvider = Provider<BoardSync>(
  (ref) => BoardSync(
    parts: ref.watch(partRepositoryProvider),
    boards: ref.watch(boardRepositoryProvider),
    footprints: ref.watch(footprintLibraryRepositoryProvider),
  ),
);

/// What updating the board from the schematic would do right now — worked
/// out again whenever either side changes, so the board can say when it
/// has fallen behind.
final boardSyncPlanProvider = FutureProvider.family<BoardSyncPlan, String>((
  ref,
  projectId,
) async {
  ref.watch(projectPartsProvider(projectId));
  ref.watch(boardFootprintsProvider(projectId));
  ref.watch(boardTracksProvider(projectId));
  ref.watch(footprintLibrariesProvider);
  return ref.watch(boardSyncProvider).plan(projectId);
}, isAutoDispose: true);

/// Named save points, and restoring them.
final snapshotRepositoryProvider = Provider<SnapshotRepository>(
  (ref) => SnapshotRepository(ref.watch(databaseProvider)),
);

final projectSnapshotsProvider =
    StreamProvider.family<List<ProjectSnapshot>, String>(
      (ref, projectId) =>
          ref.watch(snapshotRepositoryProvider).watch(projectId),
      isAutoDispose: true,
    );

final projectSettingsRepositoryProvider = Provider<ProjectSettingsRepository>(
  (ref) => ProjectSettingsRepository(ref.watch(databaseProvider)),
);

/// Which electrical checks a project cares about, and how much.
final ercSettingsProvider = StreamProvider.family<ErcSettings, String>(
  (ref, projectId) => ref
      .watch(projectSettingsRepositoryProvider)
      .watchAll(projectId)
      .map(ErcSettings.fromSettings),
  isAutoDispose: true,
);

/// Reads whole projects in and out, for backups.
final projectArchiverProvider = Provider<ProjectArchiver>(
  (ref) => ProjectArchiver(ref.watch(databaseProvider)),
);

/// The copper layer routing is currently happening on.
final activeLayerProvider = NotifierProvider<ActiveLayer, CopperLayer>(
  ActiveLayer.new,
  isAutoDispose: true,
);

class ActiveLayer extends Notifier<CopperLayer> {
  @override
  CopperLayer build() => CopperLayer.front;

  void set(CopperLayer layer) => state = layer;

  void toggle() => state = state.other;

  /// Steps down the board's copper, wrapping at the bottom — the layer
  /// button on a board with more than two.
  void next(Board board) => state = board.nextLayer(
    board.hasLayer(state) ? state : CopperLayer.front,
  );
}

/// Where exported files are written on the device.
final exportDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError('exportDirectoryProvider must be overridden');
});

final projectExporterProvider = Provider<ProjectExporter>(
  (ref) => ProjectExporter(
    projects: ref.watch(projectRepositoryProvider),
    parts: ref.watch(partRepositoryProvider),
    nets: ref.watch(netRepositoryProvider),
    libraries: ref.watch(symbolLibraryRepositoryProvider),
    boards: ref.watch(boardRepositoryProvider),
    footprints: ref.watch(footprintLibraryRepositoryProvider),
    notes: ref.watch(noteRepositoryProvider),
    outputDirectory: ref.watch(exportDirectoryProvider),
  ),
);

/// A preview of what an export would contain, without writing anything.
final exportPreviewProvider = FutureProvider.family<ExportPreview, String>((
  ref,
  projectId,
) async {
  // Recompute whenever the design changes.
  ref.watch(projectPartsProvider(projectId));
  ref.watch(projectNetsProvider(projectId));

  final document = await ref
      .watch(projectExporterProvider)
      .buildDocument(projectId);
  return ExportPreview.of(document);
}, isAutoDispose: true);

/// A copied piece of schematic — parts, their wiring among themselves and
/// their drawn wires — held for the life of the session.
///
/// Deliberately in memory rather than the database: a clipboard that
/// survived a restart would be a surprise, and nothing about it needs to be
/// durable.
final circuitClipboardProvider =
    NotifierProvider<CircuitClipboard, CircuitClip?>(CircuitClipboard.new);

class CircuitClipboard extends Notifier<CircuitClip?> {
  @override
  CircuitClip? build() => null;

  void copy(CircuitClip clip) => state = clip;

  void clear() => state = null;
}

/// Whether the schematic's component picker is showing.
final componentPickerOpenProvider = NotifierProvider<ComponentPickerOpen, bool>(
  ComponentPickerOpen.new,
);

class ComponentPickerOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}

/// User adjustments to drawn wire routes, keyed by pin pair. Each entry is
/// the displacement of every movable run of that wire.
final routeHintsProvider =
    StreamProvider.family<Map<String, List<double>>, String>(
      (ref, projectId) =>
          ref.watch(netRepositoryProvider).watchRouteHints(projectId),
      isAutoDispose: true,
    );
