import 'dart:math' as math;
import 'dart:ui';

import '../../data/repositories/net_repository.dart';
import '../../data/repositories/part_repository.dart';
import '../../data/repositories/symbol_library_repository.dart';
import '../../domain/geometry/pin_attachment.dart';
import '../../domain/models/models.dart';
import '../../domain/symbols/symbols.dart';

/// Why attaching a power symbol did not happen.
enum AttachPowerFailure {
  /// The symbol's library is no longer installed, or cannot be read.
  unreadable,

  /// The symbol has no pin, so there is nothing to connect.
  pinless,
}

/// The outcome of [attachPower].
sealed class AttachPowerResult {
  const AttachPowerResult();
}

class AttachPowerPlaced extends AttachPowerResult {
  const AttachPowerPlaced(this.part);

  final PartWithDetails part;
}

class AttachPowerFailed extends AttachPowerResult {
  const AttachPowerFailed(this.reason);

  final AttachPowerFailure reason;
}

/// Places a power symbol facing [pinId] and joins the two.
///
/// The whole point is that it is one action. Placing a ground by hand means
/// opening the picker, searching, placing, dragging it into position, then
/// tapping two pins — six steps for the single most repeated thing anyone
/// does on a schematic.
Future<AttachPowerResult> attachPower({
  required PartRepository parts,
  required NetRepository nets,
  required SymbolLibraryRepository libraries,
  required String projectId,
  required String libId,
  required String pinId,
  required Offset pinPosition,
  required Offset pinExit,
}) async {
  final symbol = await libraries.loadSymbol(libId);
  if (symbol == null) {
    return const AttachPowerFailed(AttachPowerFailure.unreadable);
  }

  final added = await parts.addPart(projectId, symbol.toNewPartSpec());
  final unit = added.units.firstOrNull;
  final supplyPin = added.pins.firstOrNull;
  if (unit == null || supplyPin == null) {
    await parts.deletePart(added.part.id);
    return const AttachPowerFailed(AttachPowerFailure.pinless);
  }

  final radians = supplyPin.angle * math.pi / 180;
  final attachment = attachmentFor(
    targetPosition: pinPosition,
    targetExit: pinExit,
    symbolPin: Offset(supplyPin.x, supplyPin.y),
    symbolBodyEnd: Offset(
      supplyPin.x + supplyPin.length * math.cos(radians),
      supplyPin.y + supplyPin.length * math.sin(radians),
    ),
  );

  await parts.updateUnitPlacement(
    unit.copyWith(
      x: attachment.position.dx,
      y: attachment.position.dy,
      rotation: attachment.rotation,
      placed: true,
    ),
  );
  await nets.connectPins(pinId, supplyPin.id);

  return AttachPowerPlaced((await parts.getPartWithDetails(added.part.id))!);
}
