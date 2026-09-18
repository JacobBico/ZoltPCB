import 'dart:ui';

import '../../domain/pcb/pcb.dart';
import 'board_repository.dart';
import 'footprint_library_repository.dart';
import 'part_repository.dart';

/// What bringing the board up to date with the schematic would do.
enum BoardSyncKind {
  /// A part on the schematic with no footprint on the board yet.
  add('New on the schematic'),

  /// A part whose footprint field no longer matches what is on the board.
  swap('Footprint changed'),

  /// A footprint for a part that should no longer be on the board.
  remove('No longer on the board'),

  /// A part naming a footprint whose library is not installed.
  missingLibrary('Library not installed'),

  /// A part with no footprint named at all.
  noFootprint('No footprint chosen'),

  /// Copper whose net the schematic has since removed.
  orphanCopper('Copper on no net');

  const BoardSyncKind(this.label);

  final String label;

  /// Whether applying the plan does something about it, rather than only
  /// reporting it.
  bool get isAction => this == add || this == swap || this == remove;
}

class BoardSyncChange {
  const BoardSyncChange({
    required this.kind,
    required this.reference,
    this.partId,
    this.libId,
    this.previousLibId,
    this.count = 1,
  });

  final BoardSyncKind kind;
  final String reference;
  final String? partId;

  /// The footprint the part names now.
  final String? libId;

  /// The footprint on the board before, for a swap or removal.
  final String? previousLibId;

  /// How many tracks, for orphaned copper.
  final int count;

  String get description => switch (kind) {
    BoardSyncKind.add => '$reference · ${libId ?? ''}',
    BoardSyncKind.swap => '$reference · $previousLibId → $libId',
    BoardSyncKind.remove => '$reference · $previousLibId',
    BoardSyncKind.missingLibrary => '$reference wants $libId',
    BoardSyncKind.noFootprint => reference,
    BoardSyncKind.orphanCopper => count == 1 ? '1 track' : '$count tracks',
  };
}

class BoardSyncPlan {
  const BoardSyncPlan(this.changes);

  final List<BoardSyncChange> changes;

  static const empty = BoardSyncPlan([]);

  Iterable<BoardSyncChange> of(BoardSyncKind kind) =>
      changes.where((c) => c.kind == kind);

  /// Changes applying would make.
  int get actionCount => changes.where((c) => c.kind.isAction).length;

  int get orphanTracks =>
      of(BoardSyncKind.orphanCopper).fold(0, (sum, c) => sum + c.count);

  /// Whether there is anything to do at all.
  bool get hasWork => actionCount > 0 || orphanTracks > 0;

  bool get isEmpty => changes.isEmpty;
}

/// What an applied sync changed, kept so it can be put back.
class BoardSyncUndo {
  const BoardSyncUndo({
    required this.projectId,
    required this.footprintsBefore,
    required this.footprintsAfter,
    required this.deletedTracks,
  });

  final String projectId;
  final List<PlacedFootprintRef> footprintsBefore;
  final List<PlacedFootprintRef> footprintsAfter;
  final List<Track> deletedTracks;
}

/// Brings the board up to date with the schematic — KiCad's "Update PCB
/// from Schematic".
///
/// Most of the schematic already reaches the board live: nets, reference
/// designators and values are read from it every frame, and a deleted
/// part takes its footprint with it. What does not follow on its own is
/// anything that needs a decision about the board — a new part needs
/// somewhere to go, a changed footprint field needs the old footprint
/// swapping out, and copper left behind by a removed connection needs
/// clearing up. That is what this does, after showing what it will do.
class BoardSync {
  BoardSync({
    required this.parts,
    required this.boards,
    required this.footprints,
  });

  final PartRepository parts;
  final BoardRepository boards;
  final FootprintLibraryRepository footprints;

  Future<BoardSyncPlan> plan(String projectId) async {
    final allParts = await parts.getPartsWithDetails(projectId);
    final placements = {
      for (final f in await boards.getFootprints(projectId)) f.partId: f,
    };
    final installed = <String, bool>{};
    Future<bool> isInstalled(String libId) async =>
        installed[libId] ??= await footprints.findByLibId(libId) != null;

    final changes = <BoardSyncChange>[];
    for (final part in allParts) {
      final p = part.part;
      final existing = placements[p.id];
      final wanted = p.footprint.trim();

      if (!p.onBoard) {
        if (existing != null) {
          changes.add(
            BoardSyncChange(
              kind: BoardSyncKind.remove,
              reference: p.reference,
              partId: p.id,
              previousLibId: existing.libId,
            ),
          );
        }
        continue;
      }

      if (wanted.isEmpty || !wanted.contains(':')) {
        // A part given its footprint on the board directly has nothing to
        // sync from; one with neither is worth mentioning.
        if (existing == null) {
          changes.add(
            BoardSyncChange(
              kind: BoardSyncKind.noFootprint,
              reference: p.reference,
              partId: p.id,
            ),
          );
        }
        continue;
      }
      if (existing?.libId == wanted) continue;
      if (!await isInstalled(wanted)) {
        changes.add(
          BoardSyncChange(
            kind: BoardSyncKind.missingLibrary,
            reference: p.reference,
            partId: p.id,
            libId: wanted,
          ),
        );
        continue;
      }
      changes.add(
        BoardSyncChange(
          kind: existing == null ? BoardSyncKind.add : BoardSyncKind.swap,
          reference: p.reference,
          partId: p.id,
          libId: wanted,
          previousLibId: existing?.libId,
        ),
      );
    }

    // Copper stored on a net that no longer exists. The foreign key has
    // already cleared the net id, which is how it shows up here.
    final orphans = (await boards.getTracks(
      projectId,
    )).where((t) => t.netId == null).length;
    if (orphans > 0) {
      changes.add(
        BoardSyncChange(
          kind: BoardSyncKind.orphanCopper,
          reference: '',
          count: orphans,
        ),
      );
    }

    changes.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : _natural(a.reference, b.reference);
    });
    return BoardSyncPlan(changes);
  }

  /// Carries out [plan]: new parts get footprints (placed in free spots on
  /// the board when [place] is set, otherwise waiting to be placed),
  /// changed ones are swapped where they stand, and removed ones go. Copper
  /// on no net is deleted if [deleteOrphans] is set.
  Future<BoardSyncUndo> apply(
    String projectId,
    BoardSyncPlan plan, {
    bool place = true,
    bool deleteOrphans = true,
  }) async {
    final before = await boards.getFootprints(projectId);
    final board = await boards.ensureBoard(projectId);

    for (final change in plan.of(BoardSyncKind.remove)) {
      await boards.removeFootprint(change.partId!);
    }
    for (final change in plan.of(BoardSyncKind.swap)) {
      await boards.assignFootprint(
        projectId: projectId,
        partId: change.partId!,
        libId: change.libId!,
      );
    }

    // New parts go into free spots, each seeing the ones placed before it.
    final occupied = <Rect>[];
    if (place) {
      for (final f in await boards.getFootprints(projectId)) {
        if (!f.placed) continue;
        final definition = await footprints.loadFootprint(f.libId);
        if (definition == null) continue;
        occupied.add(
          _boardBounds(footprintBounds(definition), f.x, f.y, f.rotation),
        );
      }
    }
    for (final change in plan.of(BoardSyncKind.add)) {
      final assigned = await boards.assignFootprint(
        projectId: projectId,
        partId: change.partId!,
        libId: change.libId!,
      );
      if (!place) continue;
      final definition = await footprints.loadFootprint(change.libId!);
      final local = definition == null
          ? const Rect.fromLTWH(-1, -1, 2, 2)
          : footprintBounds(definition);
      final spot =
          PlacementFinder.findSpot(
            outline: board.outline,
            footprint: local,
            occupied: occupied,
            gridMm: board.gridMm,
          ) ??
          PlacementFinder.besideBoard(
            outline: board.outline,
            footprint: local,
            occupied: occupied,
          );
      await boards.updatePlacement(
        assigned.copyWith(x: spot.dx, y: spot.dy, placed: true),
      );
      occupied.add(local.shift(spot));
    }

    final deleted = <Track>[];
    if (deleteOrphans && plan.orphanTracks > 0) {
      deleted.addAll(
        (await boards.getTracks(projectId)).where((t) => t.netId == null),
      );
      await boards.deleteTracks(deleted.map((t) => t.id));
    }

    return BoardSyncUndo(
      projectId: projectId,
      footprintsBefore: before,
      footprintsAfter: await boards.getFootprints(projectId),
      deletedTracks: deleted,
    );
  }

  Future<void> undo(BoardSyncUndo undo) async {
    await boards.replaceFootprints(undo.projectId, undo.footprintsBefore);
    await boards.restoreCopper(tracks: undo.deletedTracks, vias: const []);
  }

  Future<void> redo(BoardSyncUndo undo) async {
    await boards.replaceFootprints(undo.projectId, undo.footprintsAfter);
    await boards.deleteTracks(undo.deletedTracks.map((t) => t.id));
  }

  static Rect _boardBounds(Rect local, double x, double y, double rotation) {
    final placement = FootprintPlacement(x: x, y: y, rotation: rotation);
    final corners = [
      placement.apply(local.left, local.top),
      placement.apply(local.right, local.top),
      placement.apply(local.right, local.bottom),
      placement.apply(local.left, local.bottom),
    ];
    var rect = Rect.fromPoints(corners.first, corners.first);
    for (final c in corners) {
      rect = rect.expandToInclude(Rect.fromPoints(c, c));
    }
    return rect;
  }

  /// R2 before R10.
  static int _natural(String a, String b) {
    final ma = RegExp(r'^(\D*)(\d+)').firstMatch(a);
    final mb = RegExp(r'^(\D*)(\d+)').firstMatch(b);
    if (ma != null && mb != null && ma.group(1) == mb.group(1)) {
      return int.parse(ma.group(2)!).compareTo(int.parse(mb.group(2)!));
    }
    return a.compareTo(b);
  }
}
