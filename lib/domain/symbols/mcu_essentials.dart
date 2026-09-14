import 'symbol_definition.dart';

/// One pin of a microcontroller, as far as finding its essentials goes.
class McuPinInfo {
  const McuPinInfo({
    required this.number,
    required this.name,
    this.alternates = const [],
  });

  final String number;
  final String name;

  /// Alternate functions, where the library lists them. STM32 symbols name
  /// the oscillator pins `PH0`/`PH1` and only say `RCC_OSC_IN` here.
  final List<String> alternates;
}

/// Which way a boot pin has to be pulled to enter the bootloader.
enum BootPolarity {
  /// Held high to boot the ROM bootloader: STM32's `BOOT0`.
  activeHigh,

  /// Held low: ESP32's `GPIO0`, RP2040's `QSPI_SS`.
  activeLow,
}

/// The pins every microcontroller needs something on before it will run.
///
/// Worked out from pin names, because that is all a KiCad symbol reliably
/// says. It is a starting point the user can see and change, not a design
/// review: what it finds is listed in the dialog before anything is added.
class McuEssentials {
  const McuEssentials({
    this.railPins = const [],
    this.corePins = const [],
    this.groundPins = const [],
    this.vcapPins = const [],
    this.oscIn,
    this.oscOut,
    this.reset,
    this.boot,
    this.bootPolarity = BootPolarity.activeLow,
    this.bootNeedsPullUp = false,
    this.names = const {},
  });

  /// Supply pins fed from the board's rail, by pin number.
  final List<String> railPins;

  /// Supply pins fed from inside the chip — RP2040's `DVDD` from its own
  /// regulator. They get a capacitor but must not be joined to the rail.
  final List<String> corePins;

  final List<String> groundPins;

  /// STM32's `VCAP` pins, which take a capacitor to ground and nothing else.
  final List<String> vcapPins;

  final String? oscIn;
  final String? oscOut;
  final String? reset;
  final String? boot;
  final BootPolarity bootPolarity;

  /// Whether the boot pin needs a pull-up of its own to run normally.
  final bool bootNeedsPullUp;

  /// Pin names by number, for saying what was found.
  final Map<String, String> names;

  bool get hasCrystal => oscIn != null && oscOut != null;

  /// Every pin that gets a decoupling capacitor.
  List<String> get decoupledPins => [...railPins, ...corePins];

  bool get isEmpty =>
      railPins.isEmpty &&
      corePins.isEmpty &&
      groundPins.isEmpty &&
      !hasCrystal &&
      reset == null &&
      boot == null;

  /// Reads [symbol]'s pins, alternates included.
  static McuEssentials ofSymbol(SymbolDefinition symbol) => of([
    for (final drawing in symbol.unitDrawings)
      if (drawing.bodyStyle <= 1)
        for (final pin in drawing.pins)
          McuPinInfo(
            number: pin.number,
            name: pin.name,
            alternates: [for (final a in pin.alternates) a.name],
          ),
  ]);

  static McuEssentials of(Iterable<McuPinInfo> pins) {
    final rail = <String>[];
    final core = <String>[];
    final ground = <String>[];
    final vcap = <String>[];
    final names = <String, String>{};
    String? oscIn;
    String? oscOut;
    String? reset;
    String? boot0;
    String? bootLow;
    String? gpio0;
    var espStyleEnable = false;

    for (final pin in pins) {
      // A pin stacked in several units, or listed twice, counts once.
      if (names.containsKey(pin.number)) continue;
      names[pin.number] = pin.name;

      final tokens = {
        ..._tokens(pin.name),
        for (final alternate in pin.alternates) ..._tokens(alternate),
      };
      bool any(bool Function(String token) test) => tokens.any(test);

      if (any(_isGround)) {
        ground.add(pin.number);
        continue;
      }
      if (any((t) => t.startsWith('VCAP'))) {
        vcap.add(pin.number);
        continue;
      }
      if (any(_coreSupplies.contains)) {
        core.add(pin.number);
        continue;
      }
      if (any(_isRail)) {
        rail.add(pin.number);
        continue;
      }
      if (oscIn == null && any(_isOscIn)) {
        oscIn = pin.number;
        continue;
      }
      if (oscOut == null && any(_isOscOut)) {
        oscOut = pin.number;
        continue;
      }
      if (any(_resetNames.contains)) {
        reset ??= pin.number;
        if (any(const {'EN', 'CHIP_PU', 'CHIP_EN'}.contains)) {
          espStyleEnable = true;
        }
        continue;
      }
      if (any((t) => t == 'BOOT0')) {
        boot0 ??= pin.number;
        continue;
      }
      if (any(const {'BOOT', 'BOOTSEL', 'QSPI_SS', 'QSPI_SS_N'}.contains)) {
        bootLow ??= pin.number;
        continue;
      }
      if (any(const {'GPIO0', 'IO0'}.contains)) {
        gpio0 ??= pin.number;
      }
    }

    // GPIO0 is only a boot pin on the ESP32 family, which is also what has
    // an `EN` pin. An RP2040 has a GPIO0 as well and it boots nothing.
    final espBoot = espStyleEnable ? gpio0 : null;
    final boot = boot0 ?? bootLow ?? espBoot;

    return McuEssentials(
      railPins: rail,
      corePins: core,
      groundPins: ground,
      vcapPins: vcap,
      oscIn: oscIn,
      oscOut: oscOut,
      reset: reset,
      boot: boot,
      bootPolarity: boot0 != null
          ? BootPolarity.activeHigh
          : BootPolarity.activeLow,
      bootNeedsPullUp: boot0 == null && bootLow == null && espBoot != null,
      names: names,
    );
  }

  /// `~{RESET}/PC6` → {`RESET`, `PC6`}. KiCad writes an overbar as `~{…}`.
  static Set<String> _tokens(String name) {
    final clean = name
        .toUpperCase()
        .replaceAll('~{', '')
        .replaceAll('}', '')
        .replaceAll('~', '');
    return {
      for (final token in clean.split(RegExp(r'[/\-,\s]+')))
        if (token.isNotEmpty) token,
    };
  }

  static bool _isGround(String t) =>
      t.startsWith('GND') ||
      t.startsWith('VSS') ||
      const {'AGND', 'DGND', 'AVSS', 'DVSS', 'EP'}.contains(t);

  static const _coreSupplies = {
    'DVDD',
    'VDDCORE',
    'VDD_CORE',
    'VCORE',
    'VREG_VOUT',
    'VDDCPU',
  };

  static bool _isRail(String t) =>
      !t.contains('VREF') &&
      (t.startsWith('VDD') ||
          t.startsWith('VCC') ||
          const {
            'AVCC',
            'AVDD',
            'IOVDD',
            'VBAT',
            '3V3',
            'VREG_IN',
          }.contains(t));

  static bool _isOscIn(String t) =>
      t.endsWith('OSC_IN') ||
      const {'XTAL1', 'XIN', 'XTAL_IN', 'XI', 'XTAL_P', 'XTALIN'}.contains(t);

  static bool _isOscOut(String t) =>
      t.endsWith('OSC_OUT') ||
      const {
        'XTAL2',
        'XOUT',
        'XTAL_OUT',
        'XO',
        'XTAL_N',
        'XTALOUT',
      }.contains(t);

  static const _resetNames = {
    'NRST',
    'RESET',
    'RST',
    'NRESET',
    'RSTN',
    'RESETN',
    'RESET_N',
    'RST_N',
    'RUN',
    'EN',
    'CHIP_PU',
    'CHIP_EN',
    'MCLR',
  };
}
