import 'dart:convert';
import 'dart:typed_data';

import 'package:zolt/data/libraries/library_file_storage.dart';

/// A minimal but complete two-pad surface-mount footprint.
///
/// Small enough to read, and structurally what a real `.kicad_mod` is: a
/// courtyard, some silkscreen, and two pads on the front copper.
const twoPadFootprintSource = '''
(footprint "TwoPad"
  (version 20240108)
  (generator "zolt-test")
  (layer "F.Cu")
  (descr "Test footprint, two pads 2mm apart")
  (tags "test")
  (property "Reference" "REF**" (at 0 -1.65 0) (layer "F.SilkS")
    (effects (font (size 1 1) (thickness 0.15))))
  (property "Value" "TwoPad" (at 0 1.65 0) (layer "F.Fab")
    (effects (font (size 1 1) (thickness 0.15))))
  (attr smd)
  (fp_rect (start -1.7 -0.9) (end 1.7 0.9)
    (stroke (width 0.05) (type solid)) (fill no) (layer "F.CrtYd"))
  (fp_line (start -0.3 -0.7) (end 0.3 -0.7)
    (stroke (width 0.12) (type solid)) (layer "F.SilkS"))
  (pad "1" smd rect (at -1 0) (size 1 1.2) (layers "F.Cu" "F.Mask" "F.Paste"))
  (pad "2" smd rect (at 1 0) (size 1 1.2) (layers "F.Cu" "F.Mask" "F.Paste"))
)
''';

Map<String, Uint8List> twoPadFootprintSources() => {
  'TwoPad.kicad_mod': Uint8List.fromList(utf8.encode(twoPadFootprintSource)),
};

/// A named alias so a test can hold on to the same storage it passed to
/// [pumpApp], which is what makes an imported library visible to the widget
/// under test.
class InMemoryLibraryStorageFor extends InMemoryLibraryStorage {}
