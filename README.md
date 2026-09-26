<p align="center">
  <img src="docs/images/zolt-banner.svg" alt="Zolt — Design fab-ready circuit boards, right from your pocket." width="100%">
</p>

<p align="center">
  Schematic capture and PCB layout for Android — from the first resistor to
  fab-ready Gerbers, without a desk.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: GPL v3" src="https://img.shields.io/badge/license-GPLv3-blue"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/platform-Android-3DDC84">
  <img alt="Built with Flutter" src="https://img.shields.io/badge/built%20with-Flutter-02569B">
  <img alt="Works with KiCad" src="https://img.shields.io/badge/works%20with-KiCad-314CB0">
</p>

---

Zolt is a complete electronics design tool that fits in your pocket. Draw the
schematic, lay out the board, check it against your fabricator's rules, and
send the files off to be made — all from a phone.

It isn't a viewer or a toy. Zolt speaks **KiCad** natively: open your desktop
projects on the train, keep working on them, and hand them back to KiCad
when you're at a desk. Or skip the desktop entirely and export Gerbers
straight to JLCPCB, PCBWay or any other board house.

Everything runs on the device. No account, no cloud, no subscription — your
designs never leave your phone unless you send them somewhere.

## Why Zolt

**Built for fingers, not ported to them.** Every tool was designed for a
touchscreen from the start. The board editor aims with a crosshair that stays
still while the board moves beneath it, so every point lands exactly where
you meant it — never hidden under your fingertip.

**Real KiCad, both ways.** Zolt reads and writes KiCad's own schematic, board
and project files, hierarchical sheets included. Its exports are tested
against the real `kicad-cli`, so what you draw on the phone is what KiCad
opens on the desktop.

**All the libraries you already know.** Download KiCad's official symbol and
footprint libraries from inside the app — over 20,000 parts — or import your
own.

**Straight to the fab.** Gerbers, drill files, a bill of materials and a
pick-and-place file, zipped and ready to upload. Board-house presets check
your design against what that fabricator can actually make.

## What it can do

### Schematic
- A fast parts palette with the common parts one tap away, plus search across
  every library you have installed
- Drag wires out of pins, or tap them out corner by corner — your choice
- Net labels, power and ground symbols, no-connect flags and label ranges
  such as `D[0..7]`
- Multi-unit parts, hierarchical sheets, notes and boxes
- An electrical rule check with severities you set per project
- Undo and redo for every edit

### Board
- 2, 4, 6 or 8 copper layers, with an editable stackup
- Draw your own board outline: rectangles, circles, triangles, arcs and lines
- Walk-around routing, buses, differential pairs and curved tracks
- Copper pours with thermal reliefs, keepout areas and teardrops
- Through, blind and buried vias
- Impedance-controlled net classes, net lengths and length-tuning meanders
- A design rule check, plus manufacturability checks for real board houses
- Cross-probing: see the schematic and the board side by side

### Manufacturing
- Gerbers, Excellon drill files (with properly routed slots), a BOM CSV and a
  pick-and-place file
- Panelisation with mouse bites or V-scoring, rails, fiducials and tooling
  holes
- A preview of the board as it will be made, and a Gerber viewer to check
  the output
- A schematic PDF, and project backups you can move between phones

## Getting Zolt

Zolt will be on Google Play soon. Until then you can build it yourself:

```bash
git clone https://github.com/JacobBico/ZoltPCB.git
cd ZoltPCB
flutter pub get
flutter build apk --release
```

Then install `build/app/outputs/flutter-apk/app-release.apk` on an Android
phone. Zolt is designed for landscape use.

On first launch, open the component panel and choose **Download from KiCad**
to fetch the parts libraries.

## Status

Zolt is young and moving quickly. Its exports are checked against real KiCad
and accepted by board houses, but please check your design — and the exported Gerbers, in your fabricator's viewer — before
you order. If something looks wrong, [open an issue](../../issues).

Not there yet: a 3D view, and an autorouter. For those, open your project in
desktop KiCad.

## Contributing

Bug reports, ideas and pull requests are all welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; it's short. For how the app is put
together — the architecture, the design decisions and how to run the tests —
see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

Zolt is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. See [LICENSE](LICENSE).

In short: you may use, study, change and share Zolt, including commercially,
but anything you distribute that is built from it must be released under the
same license, with its full source code.

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.

Copyright © 2026 JacobBico.

## Trademarks

"Zolt" and the Zolt logo are trademarks of JacobBico and are not covered by
the license above. You are welcome to fork the code, but a fork that is
distributed — on an app store or anywhere else — must use a different name
and logo, so that nobody mistakes it for the original. Saying that your
project is "based on Zolt" is fine.

KiCad's libraries are © the KiCad Library Team and licensed under CC-BY-SA 4.0
with an exception that leaves the designs you make with them entirely yours.
Zolt downloads them on request; it does not ship them.
