# HintPCB

A mobile schematic-capture tool for electronic circuit design. Search for
components, check pinouts, decide what connects to what, and export the
result into a normal desktop KiCad workflow.

It also lays out the board: place footprints, draw copper on two layers,
check the design rules, and export a `.kicad_pcb` the desktop opens. That was
added after the fact — the original brief put PCB work firmly on the desktop —
so the board deliberately stays the smaller half of the app. Anything
elaborate (zones, inner layers, differential pairs, autorouting) is still
desktop work.

## Scope

* **Flutter, Android, landscape only.** Every screen is laid out for a wide,
  short viewport.
* **Fully offline and local-first.** Designs live in an on-device SQLite
  database. No account, no sync, no network dependency for anything in the
  core workflow.
* **Touch-first.** Fingers, not a stylus or mouse. Nothing interactive is
  smaller than 48dp.
* **Export-only.** `.kicad_sch`, `.kicad_pcb`, `.kicad_pro` and BOM CSV go
  out; nothing comes back in. There is no round-trip editing between phone
  and desktop.

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
| Board | Two copper layers, front and back. Manual routing with grid snapping and a 45°/90° constraint; no autorouter. |
| Board export | `.kicad_pcb` (`version 20241229`) plus a `.kicad_pro`, because KiCad keeps the design rules in the project file. |
| Timestamps | Stored as ISO-8601 text, not drift's default unix-seconds, because second resolution is too coarse to order recent activity. |

## Layers

Deliberately separated, with the dependency arrows pointing one way:

```
domain/          pure Dart models — no Flutter, no Drift, no KiCad syntax
  ↑
data/            Drift schema, row↔domain mappers, repositories
  ↑
features/        screens and widgets
core/            theme, shared widgets, small utilities
```

`domain/` is the shared vocabulary. The database maps into it and, later, the
symbol parser and the exporter both work in terms of it — which is what makes
the export layer testable without a database or a UI.

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
      two-layer manual routing with vias, a ratsnest that shrinks as you
      route, design rules, DRC, and `.kicad_pcb` export verified against real
      KiCad.

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
board can create a connection the schematic did not.

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

Two tagged suites are excluded from the default run because they depend on a
local KiCad install:

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
