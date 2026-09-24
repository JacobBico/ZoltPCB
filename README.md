# Zolt

A mobile schematic-capture and PCB layout tool for electronic circuit design.
Search for components, check pinouts, decide what connects to what, lay the
board out, and export the result into a normal desktop KiCad workflow — or
straight to a fabricator as Gerbers.

The board started as the smaller half of the app and is no longer: 2 to 8
copper layers, copper pours with thermal reliefs, keepout areas, walk-around
routing, buses, differential pairs, length tuning, teardrops, blind and
buried vias, a design rule check, panelisation and fab-ready output. There is
still no autorouter, and there is no 3D view; both remain desktop work.

## Scope

* **Flutter, Android, landscape only.** Every screen is laid out for a wide,
  short viewport.
* **Fully offline and local-first.** Designs live in an on-device SQLite
  database. No account, no sync, no network dependency for anything in the
  core workflow.
* **Touch-first.** Fingers, not a stylus or mouse. The section rail and the
  canvas action bar are 44 dp — a deliberate step under the usual 48, so
  every section still fits a landscape phone's 360 dp of height.
* **KiCad in and out.** `.kicad_sch`, `.kicad_pcb`, `.kicad_pro`, BOM CSV,
  Gerbers, drill files, a pick-and-place CSV and a schematic PDF go out, plus
  panel Gerbers for a whole array of boards. A desktop KiCad project —
  schematic, board and project file, hierarchical sheets included — can be
  opened too.

## Decisions

| Area | Decision |
| --- | --- |
| Persistence | Drift over SQLite. Typed queries, real migrations, and an in-memory backend so the whole data layer is testable on a workstation. |
| Symbol libraries | The app ships with no component data. The user imports `.kicad_sym` files; an optional on-demand fetch of KiCad's stock libraries may be added later. Core operation stays offline. |
| Symbol storage | Library files are kept on the filesystem; only searchable metadata is indexed in the database. Geometry and pins are parsed on demand and cached. |
| Export target | KiCad 9.x schematic format (`version 20250114`), which KiCad 10 also opens. |
| State management | Riverpod. |
| Connectivity export | Routed wires, with labels as the fallback and the guarantee — see below. |
| Footprint libraries | Same rule as symbols: nothing bundled. The user imports a zipped `.pretty` folder or loose `.kicad_mod` files, and they are packed into one container with byte spans, exactly as `.kicad_sym` libraries are. |
| Board | 2 to 8 copper layers. Manual routing with grid snapping and a 45°/90° constraint, walk-around past other nets, buses and differential pairs; no autorouter. |
| Pours and keepouts | Stored as outlines, never as filled copper: the fill follows from the outline, the clearance and everything else on the layer, and is recomputed for the screen and for the Gerbers alike. A keepout is the same object with the fill turned off. |
| Pour connectivity | The fill's steps are also traced line by line into real pieces of copper. A piece joins whatever pads, tracks and vias it touches, so a pour counts as routing in the ratsnest and the design check; a piece touching none of its net is an island, cleared from the screen and the Gerbers as KiCad clears it. |
| Teardrops | Computed from the track, the pad and two ratios rather than stored, for the same reason. The exported project carries the parameters so KiCad regenerates the same shapes. |
| Board export | `.kicad_pcb` (`version 20241229`) plus a `.kicad_pro`, because KiCad keeps the design rules in the project file. |
| Timestamps | Stored as ISO-8601 text, not drift's default unix-seconds, because second resolution is too coarse to order recent activity. |

## Layers

Deliberately separated, with the dependency arrows pointing one way:

```
domain/          models and geometry — no widgets, no Drift, no KiCad syntax
  ↑
kicad/  fab/     KiCad files in and out; Gerbers, drill and placement files
rendering/       schematic scene and painters
data/            Drift schema, row↔domain mappers, repositories
  ↑
features/        screens and widgets
app/  core/      providers, undo history, theme, shared widgets, utilities
```

`domain/` is the shared vocabulary. The database maps into it and the symbol
parser and the exporters work in terms of it — which is what makes the export
layer testable without a database or a UI. It does use `dart:ui`'s geometry
types (`Offset`, `Rect`, and `Path` for curves), so its tests run under
`flutter test` rather than plain `dart test`.

## Build order

Each stage is independently usable. All ten are built.

- [x] **1 — Data model and local persistence.** Projects, parts, units, pins, nets.
- [x] **2 — Component library.** `.kicad_sym` parser, on-device index, lazy symbol loading.
- [x] **3 — Browse and search components**, with a pinout view.
- [x] **4 — Add components to a project**; reference designators; multi-unit parts.
- [x] **5 — Tap-to-connect netlist editing.**
- [x] **6 — Schematic canvas**: symbols drawn from their vector primitives, pan, zoom, drag.
- [x] **7 — Net labels, power symbols, no-connect flags.**
- [x] **8 — `.kicad_sch` export**, verified against real KiCad.
- [x] **9 — BOM CSV export.**
- [x] **10 — Share sheet** so files can leave the device.

Added afterwards, outside the original plan:

- [x] **Board editor.** Footprint libraries, footprint assignment, placement,
      manual routing with vias, a ratsnest that shrinks as you route, design
      rules, DRC, and `.kicad_pcb` export verified against real KiCad.
- [x] **Multi-layer boards.** 2, 4, 6 or 8 copper layers with an editable
      stackup (copper weight, thickness, dielectric heights and materials),
      written to KiCad's own `stackup` and plotted as `In1_Cu`… Gerbers.
- [x] **Impedance and length.** Closed-form impedance from the stackup,
      net classes routed to a target impedance, net length and delay, and
      meanders that add an exact length.
- [x] **Workflow.** Update board from schematic, courtyard DRC, project
      backups (`.zolt`), snapshots, save-to-folder, and cross-probing
      between schematic and board.
- [x] **Schematic tools.** Label ranges (`D[0..7]`) that join parts by name,
      sheet notes and boxes, bulk field edit, and per-project ERC severities.
- [x] **Hierarchical sheets.** Sub-sheets as real KiCad hierarchy, with the
      schematic section becoming a drop-down of them, and a round trip
      verified against real KiCad.
- [x] **Real copper pours.** Trimmed to the board, cut back round other
      nets, thermal reliefs on pads and on vias, pour priority, and a fill
      that is the same steps on screen and in the Gerbers.
- [x] **Keepout areas.** Drawn from the same chip as a pour; they refuse
      tracks, vias, pours or parts, the routing walks round them and the
      rule check reports what got in. Written as KiCad rule areas.
- [x] **Teardrops.** Fillets where a track meets a pad or a via, with the
      parameters carried into the project file so the desktop agrees.
- [x] **Blind and buried vias.** A span chosen per via, checked against the
      board it is on, and the project file's permission set to match.
- [x] **Differential pairs.** Two nets named `+`/`-`, `_P`/`_N` or `_p`/`_n`
      drawn together at a fixed gap, mirrored about the line you draw or
      copied alongside it.
- [x] **Locking.** Parts, tracks, vias, pours and whole nets held where they
      are — not moved, not slid, not swept into a delete.
- [x] **Board houses.** Preset rules for real fabricators and a
      manufacturability check against what each of them will actually make.
- [x] **Panelisation.** Its own section: an array of the board with mouse-bite
      tabs or V-scoring, rails, fiducials and tooling holes, and its own set
      of fab-ready Gerbers.

## How connectivity is exported

Nets are the source of truth; wires are how they are drawn. Both go into the
exported `.kicad_sch`, and they are not equal partners.

The wires are the ones arranged on the phone, routed by the same code the
canvas uses, so the file opens looking like the sheet that was drawn rather
than a bag of symbols with floating labels. But a wire is only written when
it **cannot change the netlist**: one that runs across a foreign pin, or lies
along another net's copper, would join something the user never joined, so it
is dropped. Labels are the fallback and the guarantee — a net whose pins are
not all reachable through the wires that survived gets a label on every pin,
so dropping a wire costs some tidiness and never costs a connection. A net
the wires do join carries at most one label, and only to keep a name the user
chose.

The board works the same way round. Pads take their net from the schematic
pin with the same number; tracks and vias only refer to nets. Nothing on the
board can create a connection the schematic did not — the one exception is
deliberate and asked for: a track or a via can be put on a net by hand, so a
grid of stitching vias dropped into an exposed pad reads as ground rather
than as copper in everyone's way.

Symbols are embedded in the file's `lib_symbols` block, so an exported
schematic stands alone: it opens correctly on a machine that does not have
the originating library installed. Footprints go the other way — the board
file carries each one's original `(footprint ...)` node, edited in place
rather than rebuilt, so 3D models, custom pad shapes and anything else this
app does not model survive the trip.

## Working on it

```bash
flutter pub get
./tool/codegen.sh          # regenerate Drift code after schema changes
flutter analyze
flutter test
flutter build apk --debug
```

Tests run natively against an in-memory SQLite database — no emulator or
device needed. `test/flutter_test_config.dart` points `package:sqlite3` at
the system `libsqlite3.so.0`, since many Linux distributions ship the
versioned library without the `-dev` symlink.

Two tagged suites depend on a local KiCad install. They run as part of a
plain `flutter test`, and skip themselves on a machine without KiCad; to run
only them:

```bash
flutter test --tags corpus   # parses all 222 stock symbol libraries
flutter test --tags kicad    # exports a design and checks it with kicad-cli
```

The corpus suite is the parser's real test: 22,730 symbols, 804,896 pins, and
the awkward cases that only appear in libraries written by other people. The
`kicad` suite exports a small analogue circuit, runs `kicad-cli sch export
netlist` over it, and asserts that the netlist KiCad extracts matches the one
that was drawn — which is the only check that really settles whether the
exporter works.

It does the same for the board, and that one matters more. A `.kicad_sch`
KiCad merely opens is already useful; a `.kicad_pcb` whose layers, nets or
footprints are wrong opens perfectly and describes the wrong board. So the
board suite lays out a small design — two layers, a flipped part, a pour, a
keepout, locked copper, teardrops, and on a six-layer board a blind via —
writes it, and runs `kicad-cli pcb drc` over it. That is what proves the
syntax written for each of those is the syntax KiCad reads.

One gap worth knowing about: the `.kicad_pcb` path is checked against real
KiCad, but the Gerber path is only checked against this app's own Gerber
reader. Before ordering a board, open the exported zip in GerbView or a
fabricator's online viewer once.

### Edits, undo and transactions

An edit that writes more than once — moving a group, reshaping a net's
wires, deleting a selection, pasting a circuit, importing a project — runs
in one database transaction, and so does every undo and redo. A failure part
way leaves nothing half-done, and the canvas redraws once for the edit
rather than once per write.

Undo steps are closures, so they must not reach back into a widget: the
schematic is gone from the tree once the board is showing, and the history
is shared. Anything a step needs — a repository, the sheet it was made on —
is captured when the edit is recorded. `SheetWires` exists for this: the
wire-tidying rules, bound to one project and one sheet.

Errors the app runs into, including ones from futures nobody awaited, are
kept in `logs/errors.log` in application support, and can be shared from
Settings. Nothing is sent anywhere.

### Two things that will bite

Widget tests must close their database **inside the test body**, not in a
`tearDown`: drift keeps a short-lived timer alive after a query stream is
cancelled, and `flutter_test` checks for pending timers before teardown runs.
The `testApp` and `testAppWithStorage` helpers in
`test/helpers/pump_app.dart` do this.

Widget tests also run under a fake clock, where a real `dart:io` future never
completes — a file write inside `testWidgets` hangs rather than failing. That
is why `SymbolLibraryStorage` is an interface with an in-memory
implementation, and why the export writer is tested from plain `test` cases.

## Data model

`Net` is the source of truth for connectivity — a net is a set of pins, and
drawn wires are a rendering of it. Removing a pin from a net therefore cannot
split the remainder into two nets, which is what makes tap-one-pin-then-
another safe to offer as the only connection gesture.

A `Part` is one physical package with one reference designator. Multi-unit
packages (a dual opamp, a hex inverter) are a single part with several
`PartUnit`s that can be placed independently. Pins carrying unit `0` are
common to every unit — which is how such a package shares its supply pins.

Pins are snapshotted onto the part when it is added to a project, rather than
being looked up in the library on demand. A project stays fully editable and
exportable even if the library it came from is later deleted from the device —
the canvas falls back to drawing pins without a body, and the exporter
synthesises a pins-only symbol so the netlist is still complete.

A pin carrying unit `0` belongs to every unit of the package. That is how a
4000-series logic family shares its supply pins across all four gates, and
678 of KiCad's stock symbols rely on it.
