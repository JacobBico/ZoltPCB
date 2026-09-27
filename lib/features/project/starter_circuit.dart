import 'dart:math' as math;
import 'dart:ui';

import '../../data/repositories/net_repository.dart';
import '../../data/repositories/part_repository.dart';
import '../../data/repositories/symbol_library_repository.dart';
import '../../domain/geometry/placement.dart';
import '../../domain/models/models.dart';
import '../../domain/symbols/mcu_essentials.dart';
import '../../domain/symbols/symbols.dart';
import 'attach_power.dart';

/// What to put round a microcontroller.
class StarterOptions {
  const StarterOptions({
    required this.supplyLibId,
    this.groundLibId = 'power:GND',
    this.decoupling = true,
    this.crystal = true,
    this.reset = true,
    this.boot = true,
    this.crystalValue = '8MHz',
  });

  final String supplyLibId;
  final String groundLibId;
  final bool decoupling;
  final bool crystal;
  final bool reset;
  final bool boot;
  final String crystalValue;
}

class StarterResult {
  const StarterResult({
    required this.mcu,
    required this.partIds,
    required this.skipped,
  });

  final PartWithDetails mcu;

  /// Everything added, the microcontroller included.
  final List<String> partIds;

  /// What could not be added, and why, in words for the user.
  final List<String> skipped;
}

/// The generic parts come from the user's own libraries, never bundled:
/// KiCad's stock `Device`, `Switch` and `power` libraries, first name that
/// is there wins.
const _capacitors = ['Device:C', 'Device:C_Small'];
const _resistors = ['Device:R', 'Device:R_Small'];
const _crystals = ['Device:Crystal', 'Device:Crystal_Small'];
const _buttons = ['Switch:SW_Push', 'Switch:SW_Push_Small'];

/// Footprints for the generic parts, whose KiCad symbols name none: without
/// them the starter would reach the board as nine parts to choose a
/// footprint for, one at a time. Sizes a hand can still solder; a symbol
/// that names its own footprint keeps it.
const _smallCapFootprint = 'Capacitor_SMD:C_0603_1608Metric';
const _bulkCapFootprint = 'Capacitor_SMD:C_0805_2012Metric';
const _resistorFootprint = 'Resistor_SMD:R_0603_1608Metric';
const _crystalFootprint = 'Crystal:Crystal_SMD_HC49-SD';
const _buttonFootprint = 'Button_Switch_SMD:SW_SPST_TL3342';

/// Places [mcuSymbol] at [at] with what it needs to run.
///
/// Ground pins all go on one net, and rail pins on another, rather than a
/// ground symbol per capacitor. The board works from nets, not from symbol
/// names, and separate ground symbols would reach the board as separate
/// grounds with nothing joining them.
Future<StarterResult> buildStarterCircuit({
  required PartRepository parts,
  required NetRepository nets,
  required SymbolLibraryRepository libraries,
  required String projectId,
  required SymbolDefinition mcuSymbol,
  required Offset at,
  required StarterOptions options,
}) async {
  final added = <String>[];
  final skipped = <String>[];

  final pasted = await parts.pastePart(
    projectId,
    mcuSymbol.toNewPartSpec(),
    at: at,
  );
  final mcu = (await parts.getPartWithDetails(pasted.part.id))!;
  added.add(mcu.part.id);

  final essentials = McuEssentials.ofSymbol(mcuSymbol);

  PartPin? mcuPin(String? number) => number == null
      ? null
      : mcu.pins.where((p) => p.number == number).firstOrNull;

  final bounds = _boundsOf(mcu, mcuSymbol);

  Future<SymbolDefinition?> firstOf(List<String> libIds) async {
    for (final libId in libIds) {
      final symbol = await libraries.loadSymbol(libId);
      if (symbol != null) return symbol;
    }
    return null;
  }

  final capacitor = await firstOf(_capacitors);
  final resistor = await firstOf(_resistors);
  final crystal = await firstOf(_crystals);
  final button = await firstOf(_buttons);

  Future<PartWithDetails> place(
    SymbolDefinition symbol,
    String value,
    Offset position, {
    required String footprint,
    int rotation = 0,
  }) async {
    final part = await parts.addPart(
      projectId,
      symbol.toNewPartSpec(
        value: value,
        footprint: symbol.footprint.trim().isEmpty ? footprint : null,
      ),
    );
    await parts.updateUnitPlacement(
      part.units.first.copyWith(
        x: _onGrid(position.dx),
        y: _onGrid(position.dy),
        rotation: rotation,
        placed: true,
      ),
    );
    added.add(part.part.id);
    return (await parts.getPartWithDetails(part.part.id))!;
  }

  // The first pin on each net carries its symbol; the rest just join.
  String? groundAnchor;
  String? railAnchor;

  Future<void> anchorWith(
    String libId,
    PartWithDetails owner,
    PartPin pin,
  ) async {
    final geometry = _pinGeometry(owner, pin);
    final result = await attachPower(
      parts: parts,
      nets: nets,
      libraries: libraries,
      projectId: projectId,
      libId: libId,
      pinId: pin.id,
      pinPosition: geometry.position,
      pinExit: geometry.exit,
    );
    if (result case AttachPowerPlaced(:final part)) added.add(part.part.id);
  }

  Future<void> toGround(PartWithDetails owner, PartPin pin) async {
    final anchor = groundAnchor;
    if (anchor == null) {
      groundAnchor = pin.id;
      await anchorWith(options.groundLibId, owner, pin);
    } else if (anchor != pin.id) {
      await nets.connectPins(anchor, pin.id);
    }
  }

  Future<void> toRail(PartWithDetails owner, PartPin pin) async {
    final anchor = railAnchor;
    if (anchor == null) {
      railAnchor = pin.id;
      await anchorWith(options.supplyLibId, owner, pin);
    } else if (anchor != pin.id) {
      await nets.connectPins(anchor, pin.id);
    }
  }

  Future<void> join(PartPin a, PartPin b) => nets.connectPins(a.id, b.id);

  /// A two-pin part's pins, top then bottom, or left then right.
  (PartPin, PartPin) ends(PartWithDetails part, {bool horizontal = false}) {
    final pins = [...part.pins]
      ..sort((a, b) {
        final pa = _pinGeometry(part, a).position;
        final pb = _pinGeometry(part, b).position;
        return horizontal ? pa.dx.compareTo(pb.dx) : pa.dy.compareTo(pb.dy);
      });
    return (pins.first, pins.last);
  }

  // --- power pins and decoupling --------------------------------------
  if (options.decoupling) {
    for (final number in essentials.groundPins) {
      final pin = mcuPin(number);
      if (pin != null) await toGround(mcu, pin);
    }
    for (final number in essentials.railPins) {
      final pin = mcuPin(number);
      if (pin != null) await toRail(mcu, pin);
    }

    if (capacitor == null) {
      skipped.add('Decoupling capacitors — import KiCad\'s Device library');
    } else {
      final row = bounds.bottom + 12.7;
      var x = bounds.left + 2.54;
      final decoupled = [
        for (final n in essentials.decoupledPins) (n, '100nF'),
        for (final n in essentials.vcapPins) (n, '2.2uF'),
      ];
      for (final (number, value) in decoupled) {
        final pin = mcuPin(number);
        if (pin == null) continue;
        final cap = await place(
          capacitor,
          value,
          Offset(x, row),
          footprint: _smallCapFootprint,
        );
        final (top, bottom) = ends(cap);
        await join(top, pin);
        await toGround(cap, bottom);
        // Room for "C1 100nF" beside each one before the next.
        x += _labelledPitch;
      }
      // One bulk capacitor on the rail, the way every reference design has.
      final rail = railAnchor;
      if (rail != null) {
        final cap = await place(
          capacitor,
          '10uF',
          Offset(x, row),
          footprint: _bulkCapFootprint,
        );
        final (top, bottom) = ends(cap);
        await nets.connectPins(rail, top.id);
        await toGround(cap, bottom);
      }
    }
  }

  // --- crystal ----------------------------------------------------------
  final oscIn = mcuPin(essentials.oscIn);
  final oscOut = mcuPin(essentials.oscOut);
  if (options.crystal && oscIn != null && oscOut != null) {
    if (crystal == null || capacitor == null) {
      skipped.add('Crystal — import KiCad\'s Device library');
    } else {
      final inAt = _pinGeometry(mcu, oscIn);
      final outAt = _pinGeometry(mcu, oscOut);
      // On whichever side of the chip the oscillator pins come out of.
      final leftSide = inAt.exit.dx + outAt.exit.dx <= 0;
      // Clear of the chip's own name and value, which sit beside its body.
      final x = leftSide
          ? math.min(inAt.position.dx, outAt.position.dx) - 27.94
          : math.max(inAt.position.dx, outAt.position.dx) + 27.94;
      final y = (inAt.position.dy + outAt.position.dy) / 2;

      final part = await place(
        crystal,
        options.crystalValue,
        Offset(x, y),
        footprint: _crystalFootprint,
      );
      final (left, right) = ends(part, horizontal: true);
      await join(left, oscIn);
      await join(right, oscOut);
      for (final end in [left, right]) {
        final position = _pinGeometry(part, end).position;
        // Each out past its own end of the crystal, so their labels have
        // room between them.
        final outward = end == left ? -5.08 : 5.08;
        final cap = await place(
          capacitor,
          '20pF',
          Offset(position.dx + outward, y + 10.16),
          footprint: _smallCapFootprint,
        );
        final (top, bottom) = ends(cap);
        await join(top, end);
        await toGround(cap, bottom);
      }
    }
  }

  // --- reset and boot buttons -------------------------------------------
  final resetPin = mcuPin(essentials.reset);
  final bootPin = mcuPin(essentials.boot);
  final wantsButtons =
      (options.reset && resetPin != null) || (options.boot && bootPin != null);
  if (wantsButtons && (button == null || resistor == null)) {
    skipped.add(
      'Reset and boot buttons — import KiCad\'s Switch and Device libraries',
    );
  } else if (wantsButtons) {
    final row = bounds.top - 15.24;
    var x = bounds.left;

    if (options.reset && resetPin != null) {
      final push = await place(
        button!,
        'RESET',
        Offset(x, row),
        footprint: _buttonFootprint,
      );
      final (left, right) = ends(push, horizontal: true);
      await join(left, resetPin);
      await toGround(push, right);

      final pullUp = await place(
        resistor!,
        '10k',
        Offset(x + _labelledPitch, row),
        footprint: _resistorFootprint,
      );
      final (top, bottom) = ends(pullUp);
      await join(bottom, resetPin);
      await toRail(pullUp, top);

      if (capacitor != null) {
        final cap = await place(
          capacitor,
          '100nF',
          Offset(x + 2 * _labelledPitch, row),
          footprint: _smallCapFootprint,
        );
        final (capTop, capBottom) = ends(cap);
        await join(capTop, resetPin);
        await toGround(cap, capBottom);
      }
      x += 3 * _labelledPitch;
    }

    if (options.boot && bootPin != null) {
      final push = await place(
        button!,
        'BOOT',
        Offset(x, row),
        footprint: _buttonFootprint,
      );
      final (left, right) = ends(push, horizontal: true);
      await join(left, bootPin);

      if (essentials.bootPolarity == BootPolarity.activeHigh) {
        // Pressed pulls it up; the rest of the time it is held down.
        await toRail(push, right);
        final pullDown = await place(
          resistor!,
          '10k',
          Offset(x + _labelledPitch, row),
          footprint: _resistorFootprint,
        );
        final (top, bottom) = ends(pullDown);
        await join(top, bootPin);
        await toGround(pullDown, bottom);
      } else {
        await toGround(push, right);
        if (essentials.bootNeedsPullUp) {
          final pullUp = await place(
            resistor!,
            '10k',
            Offset(x + _labelledPitch, row),
            footprint: _resistorFootprint,
          );
          final (top, bottom) = ends(pullUp);
          await join(bottom, bootPin);
          await toRail(pullUp, top);
        }
      }
    }
  }

  return StarterResult(
    mcu: (await parts.getPartWithDetails(mcu.part.id))!,
    partIds: added,
    skipped: skipped,
  );
}

double _onGrid(double value) => (value / 1.27).round() * 1.27;

/// Between two-pin parts in a row: the part, and its name and value
/// beside it, with a gap before the next.
const _labelledPitch = 12.7;

/// Where [pin] is on the sheet and which way a wire leaves it.
({Offset position, Offset exit}) _pinGeometry(
  PartWithDetails part,
  PartPin pin,
) {
  final unit =
      part.units.where((u) => u.unitNumber == pin.unit).firstOrNull ??
      part.units.first;
  final placement = Placement.ofUnit(unit);
  final radians = pin.angle * math.pi / 180;
  final position = placement.apply(pin.x, pin.y);
  final body = placement.apply(
    pin.x + pin.length * math.cos(radians),
    pin.y + pin.length * math.sin(radians),
  );
  final away = position - body;
  return (
    position: position,
    exit: away.distance < 1e-9 ? const Offset(0, 1) : away / away.distance,
  );
}

/// The extent of every placed unit of [part], on the sheet.
Rect _boundsOf(PartWithDetails part, SymbolDefinition symbol) {
  Rect? all;
  for (final unit in part.units) {
    final local = symbolBounds(symbol, unit.unitNumber);
    if (local == Rect.zero) continue;
    final placement = Placement.ofUnit(unit);
    final a = placement.apply(local.left, local.top);
    final b = placement.apply(local.right, local.bottom);
    final rect = Rect.fromPoints(a, b);
    all = all == null ? rect : all.expandToInclude(rect);
  }
  final unit = part.units.first;
  return all ??
      Rect.fromCenter(center: Offset(unit.x, unit.y), width: 20, height: 20);
}
