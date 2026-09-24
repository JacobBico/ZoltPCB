import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/libraries/library_file_storage.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/features/project/starter_circuit.dart';

import '../helpers/library_fixture.dart';

const _device = '''
(kicad_symbol_lib
  (version 20251024)
  (symbol "R"
    (property "Reference" "R")
    (property "Value" "R")
    (symbol "R_1_1"
      (pin passive line (at 0 3.81 270) (length 1.27) (name "~") (number "1"))
      (pin passive line (at 0 -3.81 90) (length 1.27) (name "~") (number "2"))))
  (symbol "C"
    (property "Reference" "C")
    (property "Value" "C")
    (symbol "C_1_1"
      (pin passive line (at 0 3.81 270) (length 2.794) (name "~") (number "1"))
      (pin passive line (at 0 -3.81 90) (length 2.794) (name "~") (number "2"))))
  (symbol "Crystal"
    (property "Reference" "Y")
    (property "Value" "Crystal")
    (symbol "Crystal_1_1"
      (pin passive line (at -3.81 0 0) (length 1.27) (name "1") (number "1"))
      (pin passive line (at 3.81 0 180) (length 1.27) (name "2") (number "2")))))
''';

const _switch = '''
(kicad_symbol_lib
  (version 20251024)
  (symbol "SW_Push"
    (property "Reference" "SW")
    (property "Value" "SW_Push")
    (symbol "SW_Push_1_1"
      (pin passive line (at -5.08 0 0) (length 2.54) (name "1") (number "1"))
      (pin passive line (at 5.08 0 180) (length 2.54) (name "2") (number "2")))))
''';

const _mcu = '''
(kicad_symbol_lib
  (version 20251024)
  (symbol "STM32T"
    (property "Reference" "U")
    (property "Value" "STM32T")
    (symbol "STM32T_0_1" (rectangle (start -10.16 10.16) (end 10.16 -10.16)))
    (symbol "STM32T_1_1"
      (pin power_in line (at -2.54 12.7 270) (length 2.54) (name "VDD") (number "1"))
      (pin power_in line (at 0 12.7 270) (length 2.54) (name "VDD") (number "2"))
      (pin power_in line (at 2.54 12.7 270) (length 2.54) (name "VDDA") (number "3"))
      (pin power_in line (at 0 -12.7 90) (length 2.54) (name "VSS") (number "4"))
      (pin power_in line (at 2.54 -12.7 90) (length 2.54) (name "VSSA") (number "5"))
      (pin bidirectional line (at -12.7 2.54 0) (length 2.54) (name "PH0")
        (number "6") (alternate "RCC_OSC_IN" input line))
      (pin bidirectional line (at -12.7 0 0) (length 2.54) (name "PH1")
        (number "7") (alternate "RCC_OSC_OUT" output line))
      (pin input line (at -12.7 -2.54 0) (length 2.54) (name "NRST") (number "8"))
      (pin input line (at 12.7 0 180) (length 2.54) (name "BOOT0") (number "9"))
      (pin bidirectional line (at 12.7 2.54 180) (length 2.54) (name "PA0") (number "10")))))
''';

void main() {
  late AppDatabase db;
  late PartRepository parts;
  late NetRepository nets;
  late SymbolLibraryRepository libraries;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    parts = PartRepository(db);
    nets = NetRepository(db);
    libraries = SymbolLibraryRepository(db, InMemoryLibraryStorage());
    for (final (name, source) in [
      ('power', testPowerLibrarySource),
      ('Device', _device),
      ('MCU_Test', _mcu),
    ]) {
      await libraries.import(
        fileName: '$name.kicad_sym',
        bytes: libraryBytes(source),
      );
    }
    project = await ProjectRepository(db).create(name: 'Starter');
  });

  tearDown(() async => db.close());

  Future<StarterResult> build({StarterOptions? options}) async =>
      buildStarterCircuit(
        parts: parts,
        nets: nets,
        libraries: libraries,
        projectId: project.id,
        mcuSymbol: (await libraries.loadSymbol('MCU_Test:STM32T'))!,
        at: const Offset(100, 80),
        options: options ?? const StarterOptions(supplyLibId: 'power:VCC'),
      );

  /// Every net, as the parts' `reference.pin` names, for reading at a glance.
  Future<List<Set<String>>> netsByName() async {
    final all = await parts.getPartsWithDetails(project.id);
    final nameOf = {
      for (final part in all)
        for (final pin in part.pins)
          pin.id: '${part.part.reference}.${pin.number}',
    };
    return [
      for (final net in await nets.getNets(project.id))
        {for (final e in net.endpoints) nameOf[e.pin.id]!},
    ];
  }

  Set<String> netWith(List<Set<String>> all, String pin) =>
      all.firstWhere((n) => n.contains(pin), orElse: () => const {});

  Future<List<Part>> partsWithLib(String libId) async => [
    for (final p in await parts.getPartsWithDetails(project.id))
      if (p.part.libId == libId) p.part,
  ];

  test('every ground pin is one net, and every rail pin another', () async {
    await build(
      options: const StarterOptions(
        supplyLibId: 'power:VCC',
        crystal: false,
        reset: false,
        boot: false,
      ),
    );
    final all = await netsByName();

    final ground = netWith(all, 'U1.4');
    expect(ground, contains('U1.5'));
    final rail = netWith(all, 'U1.1');
    expect(rail, containsAll(['U1.2', 'U1.3']));
    expect(ground.intersection(rail), isEmpty);

    // One symbol each, not one per capacitor: the board joins by net.
    expect(await partsWithLib('power:GND'), hasLength(1));
    expect(await partsWithLib('power:VCC'), hasLength(1));
  });

  test('each supply pin gets its own 100nF, plus a bulk 10uF', () async {
    await build(
      options: const StarterOptions(
        supplyLibId: 'power:VCC',
        crystal: false,
        reset: false,
        boot: false,
      ),
    );
    final caps = await partsWithLib('Device:C');
    expect(caps.where((c) => c.value == '100nF'), hasLength(3));
    expect(caps.where((c) => c.value == '10uF'), hasLength(1));

    final all = await netsByName();
    final ground = netWith(all, 'U1.4');
    for (final supply in ['U1.1', 'U1.2', 'U1.3']) {
      // Each supply pin's own net also holds a capacitor...
      final net = netWith(all, supply);
      expect(net.where((pin) => pin.startsWith('C')), isNotEmpty);
    }
    // ...and every capacitor's other end is on ground.
    for (final cap in caps) {
      expect(
        ground.where((pin) => pin.startsWith('${cap.reference}.')),
        hasLength(1),
        reason: '${cap.reference} not grounded',
      );
    }
  });

  test('the crystal sits across the oscillator pins with load caps', () async {
    await build();
    final all = await netsByName();
    final crystal = (await partsWithLib('Device:Crystal')).single;
    expect(crystal.value, '8MHz');

    final oscIn = netWith(all, 'U1.6');
    final oscOut = netWith(all, 'U1.7');
    expect(
      oscIn.where((p) => p.startsWith('${crystal.reference}.')),
      hasLength(1),
    );
    expect(
      oscOut.where((p) => p.startsWith('${crystal.reference}.')),
      hasLength(1),
    );
    // Each side also holds one 20pF.
    final loads = await partsWithLib('Device:C');
    final twenty = loads
        .where((c) => c.value == '20pF')
        .map((c) => c.reference);
    expect(twenty, hasLength(2));
    for (final side in [oscIn, oscOut]) {
      expect(
        side.where((p) => twenty.any((r) => p.startsWith('$r.'))),
        hasLength(1),
      );
    }
  });

  test('BOOT0 is held down and a button lifts it to the rail', () async {
    await libraries.import(
      fileName: 'Switch.kicad_sym',
      bytes: libraryBytes(_switch),
    );
    final result = await build();
    expect(result.skipped, isEmpty);

    final all = await netsByName();
    final ground = netWith(all, 'U1.4');
    final rail = netWith(all, 'U1.1');
    final boot = netWith(all, 'U1.9');
    final reset = netWith(all, 'U1.8');

    final buttons = await partsWithLib('Switch:SW_Push');
    final bootButton = buttons.firstWhere((b) => b.value == 'BOOT').reference;
    final resetButton = buttons.firstWhere((b) => b.value == 'RESET').reference;

    expect(boot.where((p) => p.startsWith('$bootButton.')), hasLength(1));
    expect(rail.where((p) => p.startsWith('$bootButton.')), hasLength(1));
    expect(boot.where((p) => p.startsWith('R')), hasLength(1));

    // Reset: button to ground, pull-up to the rail, capacitor to ground.
    expect(reset.where((p) => p.startsWith('$resetButton.')), hasLength(1));
    expect(ground.where((p) => p.startsWith('$resetButton.')), hasLength(1));
    expect(reset.where((p) => p.startsWith('R')), hasLength(1));
    expect(reset.where((p) => p.startsWith('C')), hasLength(1));
  });

  test('a missing library is skipped and said, not guessed at', () async {
    final result = await build();
    expect(result.skipped.single, contains('Switch'));
    expect(await partsWithLib('Switch:SW_Push'), isEmpty);
    // Everything that could be added still was.
    expect(await partsWithLib('Device:Crystal'), hasLength(1));
  });
}
