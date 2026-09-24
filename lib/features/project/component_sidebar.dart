import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../data/repositories/saved_circuit_repository.dart';
import '../../domain/models/models.dart';
import '../libraries/kicad_download_dialog.dart';
import '../../domain/symbols/symbols.dart';
import 'symbol_thumbnail.dart';

/// A part common enough to be one tap away, by its KiCad library id.
class QuickPart {
  const QuickPart(this.label, this.libId);

  final String label;
  final String libId;
}

/// What most circuits are made of. Anything here that the imported
/// libraries do not have is simply not shown.
const quickParts = [
  QuickPart('Resistor', 'Device:R'),
  QuickPart('Capacitor', 'Device:C'),
  QuickPart('Electrolytic', 'Device:C_Polarized'),
  QuickPart('Inductor', 'Device:L'),
  QuickPart('Diode', 'Device:D'),
  QuickPart('LED', 'Device:LED'),
  QuickPart('Zener', 'Device:D_Zener'),
  QuickPart('Schottky', 'Device:D_Schottky'),
  QuickPart('NPN', 'Transistor_BJT:Q_NPN_BEC'),
  QuickPart('PNP', 'Transistor_BJT:Q_PNP_BEC'),
  QuickPart('N-MOSFET', 'Device:Q_NMOS'),
  QuickPart('P-MOSFET', 'Device:Q_PMOS'),
  QuickPart('Op-amp', 'Amplifier_Operational:LM358'),
  QuickPart('Crystal', 'Device:Crystal'),
  QuickPart('Button', 'Switch:SW_Push'),
  QuickPart('Header', 'Connector_Generic:Conn_01x02'),
  QuickPart('Pot', 'Device:R_Potentiometer'),
  QuickPart('Fuse', 'Device:Fuse'),
  QuickPart('Battery', 'Device:Battery_Cell'),
];

/// Ground and the usual supplies. Picked while a pin is held, one goes
/// straight onto that pin.
const quickPower = [
  QuickPart('GND', 'power:GND'),
  QuickPart('+3V3', 'power:+3V3'),
  QuickPart('+5V', 'power:+5V'),
  QuickPart('VCC', 'power:VCC'),
  QuickPart('+12V', 'power:+12V'),
  QuickPart('GNDA', 'power:GNDA'),
  QuickPart('VBUS', 'power:VBUS'),
  QuickPart('PWR_FLAG', 'power:PWR_FLAG'),
];

/// Which list the picker is showing.
enum _Mode { parts, saved, starters }

/// The component picker that slides in over the schematic.
///
/// Adding a part used to push a full-screen browser, which took the user off
/// the drawing they were working on and back again for every component. This
/// keeps the sheet visible: tap a part, it lands on the sheet, and the list
/// stays open for the next one — so a whole circuit's worth of parts can be
/// put down before any of it is wired.
///
/// It opens on what most circuits are made of, drawn as symbols: the
/// passives, the usual semiconductors, ground and the supplies. Search and
/// the libraries are there for everything else.
class ComponentSidebar extends ConsumerStatefulWidget {
  const ComponentSidebar({
    super.key,
    required this.onAdd,
    required this.onClose,
    this.onStarter,
    this.onSavedCircuit,
    this.projectId,
    this.width = 340,
  });

  /// The project being drawn, whose own parts are offered again. Null
  /// leaves that row out.
  final String? projectId;

  /// Puts a circuit saved from a selection on the sheet. Null hides the tab.
  final void Function(SavedCircuit circuit)? onSavedCircuit;

  /// Adds a microcontroller with its supporting parts. Null hides the tab.
  final void Function(SymbolIndexEntry entry)? onStarter;

  final void Function(SymbolIndexEntry entry) onAdd;
  final VoidCallback onClose;
  final double width;

  @override
  ConsumerState<ComponentSidebar> createState() => _ComponentSidebarState();
}

class _ComponentSidebarState extends ConsumerState<ComponentSidebar> {
  final _controller = TextEditingController();
  String _query = '';
  String? _libraryId;
  _Mode _mode = _Mode.parts;

  /// The quick parts the imported libraries actually have, looked up once
  /// per set of libraries.
  Future<List<(QuickPart, SymbolIndexEntry)>>? _quick;
  Object? _quickFor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<(QuickPart, SymbolIndexEntry)>> _resolve(
    List<QuickPart> wanted,
  ) async {
    final repository = ref.read(symbolLibraryRepositoryProvider);
    return [
      for (final part in wanted)
        if (await repository.findByLibId(part.libId) case final entry?)
          (part, entry),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final libraries = ref.watch(symbolLibrariesProvider).value ?? const [];
    final repository = ref.watch(symbolLibraryRepositoryProvider);
    if (!identical(libraries, _quickFor)) {
      _quickFor = libraries;
      _quick = _resolve([...quickParts, ...quickPower]);
    }
    final browsing =
        _mode == _Mode.parts && _query.trim().isEmpty && _libraryId == null;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: KicadPalette.surface,
        border: Border(left: BorderSide(color: KicadPalette.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
              child: Row(
                children: [
                  Expanded(child: _searchField()),
                  if (_mode == _Mode.parts && libraries.isNotEmpty)
                    IconButton(
                      key: const ValueKey('library-picker'),
                      tooltip: 'Look in one library',
                      isSelected: _libraryId != null,
                      icon: const Icon(Icons.folder_outlined, size: 20),
                      selectedIcon: Icon(
                        Icons.folder,
                        size: 20,
                        color: KicadPalette.highlight,
                      ),
                      onPressed: () => _chooseLibrary(libraries),
                    ),
                ],
              ),
            ),
            if (_mode == _Mode.parts) ?_libraryFilter(libraries),
            Divider(height: 1, color: KicadPalette.border),
            Expanded(
              child: switch (_mode) {
                _Mode.saved => _savedList(),
                _ when browsing && libraries.isNotEmpty => _quickGrid(),
                _ => FutureBuilder<List<SymbolIndexEntry>>(
                  // Keyed by query and category so a change re-runs the
                  // search.
                  key: ValueKey(
                    '$_query|$_libraryId|$_mode|${libraries.length}',
                  ),
                  future: _mode == _Mode.starters
                      ? repository.search(_query, microcontrollersOnly: true)
                      : repository.search(_query, libraryId: _libraryId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _message('Search failed: ${snapshot.error}');
                    }
                    final results = snapshot.data;
                    if (results == null) return const SizedBox.shrink();
                    if (results.isEmpty && libraries.isEmpty) {
                      return _noLibraries();
                    }
                    if (results.isEmpty) {
                      return _message(
                        _mode == _Mode.starters
                            ? 'No microcontrollers. Import one of KiCad\'s '
                                  'MCU_ libraries.'
                            : 'Nothing matches.',
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: KicadPalette.border),
                      itemBuilder: (context, index) => _ResultRow(
                        entry: results[index],
                        onTap: () => _mode == _Mode.starters
                            ? widget.onStarter!(results[index])
                            : widget.onAdd(results[index]),
                      ),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Parts, the circuits saved from a selection, and the microcontroller
  /// starters: three different lists, so three tabs, on the same line as
  /// the close button to leave the most room for the parts themselves.
  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            children: [
              _CategoryChip(
                label: 'Parts',
                selected: _mode == _Mode.parts,
                onTap: () => setState(() => _mode = _Mode.parts),
              ),
              if (widget.onSavedCircuit != null)
                _CategoryChip(
                  key: const ValueKey('saved-circuits-tab'),
                  label: 'Saved',
                  selected: _mode == _Mode.saved,
                  onTap: () => setState(() => _mode = _Mode.saved),
                ),
              if (widget.onStarter != null)
                _CategoryChip(
                  key: const ValueKey('starter-circuits-tab'),
                  label: 'Starters',
                  selected: _mode == _Mode.starters,
                  onTap: () => setState(() => _mode = _Mode.starters),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Close',
          onPressed: widget.onClose,
        ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    controller: _controller,
    autofocus: false,
    decoration: InputDecoration(
      hintText: switch (_mode) {
        _Mode.parts => 'Search all parts…',
        _Mode.saved => 'Search saved circuits…',
        _Mode.starters => 'Search microcontrollers…',
      },
      prefixIcon: const Icon(Icons.search, size: 18),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() {
                _controller.clear();
                _query = '';
              }),
            ),
      isDense: true,
    ),
    onChanged: (value) => setState(() => _query = value),
  );

  /// The one library being looked in, when there is one, with a way back
  /// to all of them.
  Widget? _libraryFilter(List<SymbolLibraryInfo> libraries) {
    final current = libraries.where((l) => l.id == _libraryId).firstOrNull;
    if (current == null) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const ValueKey('library-filter'),
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.folder_outlined, size: 14),
          label: Text('In ${current.nickname}'),
          onDeleted: () => setState(() => _libraryId = null),
        ),
      ),
    );
  }

  /// One library to look in, chosen from a list rather than scrolled for
  /// along a strip of two hundred chips.
  Future<void> _chooseLibrary(List<SymbolLibraryInfo> libraries) async {
    final chosen = await showModalBottomSheet<SymbolLibraryInfo>(
      context: context,
      backgroundColor: KicadPalette.surface,
      isScrollControlled: true,
      builder: (sheet) => _LibraryList(libraries: libraries),
    );
    if (chosen == null || !mounted) return;
    setState(() => _libraryId = chosen.id);
  }

  /// What most circuits are made of, drawn, one tap each.
  Widget _quickGrid() {
    final projectId = widget.projectId;
    final placed = projectId == null
        ? const <PartWithDetails>[]
        : ref.watch(projectPartsProvider(projectId)).value ??
              const <PartWithDetails>[];
    final used = <String>[
      ...{
        for (final part in placed)
          if (!part.part.isPowerSymbol) part.part.libId,
      },
    ];
    return FutureBuilder<List<(QuickPart, SymbolIndexEntry)>>(
      future: _quick,
      builder: (context, snapshot) {
        final found = snapshot.data;
        if (found == null) return const SizedBox.shrink();
        final power = {for (final p in quickPower) p.libId};
        final parts = [
          for (final f in found)
            if (!power.contains(f.$1.libId)) f,
        ];
        final supplies = [
          for (final f in found)
            if (power.contains(f.$1.libId)) f,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: [
            if (used.isNotEmpty) ...[
              _heading('IN THIS PROJECT'),
              _UsedRow(libIds: used, onAdd: _addLibId),
              const SizedBox(height: 10),
            ],
            if (parts.isNotEmpty) ...[
              _heading('COMMON PARTS'),
              _tiles(parts),
              const SizedBox(height: 10),
            ],
            if (supplies.isNotEmpty) ...[
              _heading('POWER AND GROUND'),
              _tiles(supplies),
            ],
            if (parts.isEmpty && supplies.isEmpty)
              _message(
                'None of the usual parts are in the imported libraries. '
                'Search, or pick a library above.',
              ),
          ],
        );
      },
    );
  }

  Future<void> _addLibId(String libId) async {
    final entry = await ref
        .read(symbolLibraryRepositoryProvider)
        .findByLibId(libId);
    if (entry != null && mounted) widget.onAdd(entry);
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: KicadPalette.textSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _tiles(List<(QuickPart, SymbolIndexEntry)> parts) => GridView.count(
    crossAxisCount: widget.width >= 320 ? 4 : 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
    childAspectRatio: 0.9,
    children: [
      for (final (part, entry) in parts)
        _QuickTile(
          key: ValueKey('quick-${part.libId}'),
          label: part.label,
          libId: part.libId,
          onTap: () => widget.onAdd(entry),
        ),
    ],
  );

  /// Circuits saved from a selection — tap one to put it on the sheet.
  Widget _savedList() {
    final saved = ref.watch(savedCircuitsProvider).value;
    if (saved == null) return const SizedBox.shrink();
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final circuit in saved)
        if (query.isEmpty || circuit.name.toLowerCase().contains(query))
          circuit,
    ];
    if (shown.isEmpty) {
      return _message(
        saved.isEmpty
            ? 'Nothing saved yet. Select a circuit on the sheet and press '
                  'Save to keep it here for any project.'
            : 'Nothing matches.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: shown.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: KicadPalette.border),
      itemBuilder: (context, index) => _SavedRow(
        circuit: shown[index],
        onTap: () => widget.onSavedCircuit!(shown[index]),
        onDelete: () => _deleteSaved(shown[index]),
      ),
    );
  }

  Future<void> _deleteSaved(SavedCircuit circuit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${circuit.name}"?'),
        content: const Text(
          'It goes from Saved circuits. Copies already on a sheet stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('saved-circuit-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(savedCircuitRepositoryProvider).delete(circuit.id);
  }

  /// Nothing to search yet: the way to get parts, right here.
  Widget _noLibraries() => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No component libraries yet.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KicadPalette.textDisabled),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('sidebar-kicad-download'),
            onPressed: () => showKicadLibraryDownload(context),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('DOWNLOAD FROM KICAD'),
          ),
        ],
      ),
    ),
  );

  Widget _message(String text) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: KicadPalette.textDisabled),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? KicadPalette.wire.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: selected ? KicadPalette.wire : KicadPalette.border,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? KicadPalette.wire : KicadPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.entry, required this.onTap});

  final SymbolIndexEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: entry.isPower
                                ? KicadPalette.symbolOutline
                                : KicadPalette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.libraryNickname,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  if (entry.description.isNotEmpty)
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.pinCount}p',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textDisabled,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.add, size: 18, color: KicadPalette.wire),
          ],
        ),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.circuit,
    required this.onTap,
    required this.onDelete,
  });

  final SavedCircuit circuit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('saved-circuit-${circuit.id}'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.fromLTRB(12, 7, 0, 7),
        child: Row(
          children: [
            Icon(Icons.bookmark_outline, size: 18, color: KicadPalette.wire),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    circuit.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: KicadPalette.textPrimary,
                    ),
                  ),
                  Text(
                    circuit.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('saved-circuit-delete-${circuit.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: KicadPalette.textDisabled,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// One quick part: its symbol, drawn, over its name.
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    super.key,
    required this.label,
    required this.libId,
    required this.onTap,
  });

  final String label;
  final String libId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KicadPalette.surfaceRaised,
    borderRadius: BorderRadius.circular(4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(
        message: libId,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Column(
            children: [
              Expanded(child: SymbolThumbnail(libId: libId, size: 48)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The parts already in the project, to put down another of.
class _UsedRow extends StatelessWidget {
  const _UsedRow({required this.libIds, required this.onAdd});

  final List<String> libIds;
  final void Function(String libId) onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 78,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: libIds.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, index) {
        final libId = libIds[index];
        final name = libId.substring(libId.indexOf(':') + 1);
        return SizedBox(
          width: 72,
          child: _QuickTile(
            key: ValueKey('used-$libId'),
            label: name,
            libId: libId,
            onTap: () => onAdd(libId),
          ),
        );
      },
    ),
  );
}

/// Every imported library, with a filter, to look in one.
class _LibraryList extends StatefulWidget {
  const _LibraryList({required this.libraries});

  final List<SymbolLibraryInfo> libraries;

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filter = _filter.trim().toLowerCase();
    final shown =
        [
          for (final library in widget.libraries)
            if (filter.isEmpty ||
                library.nickname.toLowerCase().contains(filter))
              library,
        ]..sort(
          (a, b) =>
              a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
        );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Filter libraries…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(shown[index].nickname),
                  onTap: () => Navigator.of(context).pop(shown[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
