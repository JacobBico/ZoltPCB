import 'part.dart';
import 'part_spec.dart';

/// Turns a placed part back into the spec that would create another like it.
///
/// Copy, paste and duplicate all work from the part's own pin snapshot
/// rather than going back to the symbol library, so a part can be copied
/// even after the library it came from has been removed from the device.
extension PartToSpec on PartWithDetails {
  NewPartSpec toSpec({String? reference}) => NewPartSpec(
    libId: part.libId,
    value: part.value,
    reference: reference,
    referencePrefix: part.referencePrefix,
    footprint: part.footprint,
    datasheet: part.datasheet,
    description: part.description,
    unitCount: part.unitCount,
    inBom: part.inBom,
    onBoard: part.onBoard,
    pins: [
      for (final pin in pins)
        NewPinSpec(
          number: pin.number,
          name: pin.name,
          electricalType: pin.electricalType,
          graphicStyle: pin.graphicStyle,
          unit: pin.unit,
          bodyStyle: pin.bodyStyle,
          x: pin.x,
          y: pin.y,
          length: pin.length,
          angle: pin.angle,
          hidden: pin.hidden,
        ),
    ],
  );
}
