import 'dart:convert';
import 'dart:typed_data';

/// A miniature but structurally complete `.kicad_sym` library.
///
/// Covers the cases the UI has to render: a plain part, a derived part, a
/// multi-unit part whose supply pins sit in their own unit, and a power
/// symbol.
const testLibrarySource = '''
(kicad_symbol_lib
  (version 20251024)
  (generator "kicad_symbol_editor")
  (symbol "R"
    (property "Reference" "R")
    (property "Value" "R")
    (property "Description" "Resistor")
    (property "ki_keywords" "R res resistor")
    (symbol "R_0_1" (rectangle (start -1.016 -2.54) (end 1.016 2.54)))
    (symbol "R_1_1"
      (pin passive line (at 0 3.81 270) (length 1.27) (name "") (number "1"))
      (pin passive line (at 0 -3.81 90) (length 1.27) (name "") (number "2"))))
  (symbol "R_Small"
    (extends "R")
    (property "Value" "R_Small")
    (property "Description" "Resistor, small symbol"))
  (symbol "C"
    (property "Reference" "C")
    (property "Value" "C")
    (property "Description" "Unpolarized capacitor")
    (property "ki_keywords" "cap capacitor")
    (symbol "C_1_1"
      (pin passive line (at 0 2.54 270) (length 2.54) (name "~") (number "1"))
      (pin passive line (at 0 -2.54 90) (length 2.54) (name "~") (number "2"))))
  (symbol "LM2904"
    (property "Reference" "U")
    (property "Value" "LM2904")
    (property "Description" "Dual Operational Amplifier")
    (property "ki_keywords" "dual opamp")
    (symbol "LM2904_1_1"
      (polyline (pts (xy -5.08 5.08) (xy 5.08 0) (xy -5.08 -5.08) (xy -5.08 5.08)))
      (pin output line (at 7.62 0 180) (length 2.54) (name "~") (number "1"))
      (pin input line (at -7.62 -2.54 0) (length 2.54) (name "-") (number "2"))
      (pin input line (at -7.62 2.54 0) (length 2.54) (name "+") (number "3")))
    (symbol "LM2904_2_1"
      (polyline (pts (xy -5.08 5.08) (xy 5.08 0) (xy -5.08 -5.08) (xy -5.08 5.08)))
      (pin input line (at -7.62 2.54 0) (length 2.54) (name "+") (number "5"))
      (pin input line (at -7.62 -2.54 0) (length 2.54) (name "-") (number "6"))
      (pin output line (at 7.62 0 180) (length 2.54) (name "~") (number "7")))
    (symbol "LM2904_3_1"
      (pin power_in line (at -2.54 -7.62 90) (length 3.81) (name "V-") (number "4"))
      (pin power_in line (at -2.54 7.62 270) (length 3.81) (name "V+") (number "8")))))
''';

const testPowerLibrarySource = '''
(kicad_symbol_lib
  (version 20251024)
  (symbol "GND"
    (power global)
    (pin_names (offset 0) (hide yes))
    (property "Reference" "#PWR")
    (property "Value" "GND")
    (property "Description" "Power symbol creates a global label, ground")
    (property "ki_keywords" "global power")
    (symbol "GND_0_1"
      (polyline (pts (xy 0 0) (xy 0 -1.27) (xy 1.27 -1.27) (xy 0 -2.54)
        (xy -1.27 -1.27) (xy 0 -1.27))))
    (symbol "GND_1_1"
      (pin power_in line (at 0 0 270) (length 0) (name "") (number "1"))))
  (symbol "VCC"
    (power global)
    (property "Reference" "#PWR")
    (property "Value" "VCC")
    (property "Description" "Power symbol creates a global label, VCC")
    (symbol "VCC_0_1" (polyline (pts (xy -0.762 1.27) (xy 0 2.54) (xy 0.762 1.27))))
    (symbol "VCC_1_1"
      (pin power_in line (at 0 0 90) (length 0) (name "") (number "1")))))
''';

Uint8List libraryBytes([String source = testLibrarySource]) =>
    Uint8List.fromList(utf8.encode(source));
