import '../models/part_spec.dart';
import '../models/pin.dart';
import 'symbol_definition.dart';

/// Turns a library symbol into the spec for adding it to a project.
///
/// This is the seam between the library and the project: after this call the
/// project owns a snapshot of the pins and no longer depends on the library
/// being present.
extension SymbolToPart on SymbolDefinition {
  NewPartSpec toNewPartSpec({
    String? reference,
    String? value,
    String? footprint,
    String componentId = '',
  }) {
    return NewPartSpec(
      libId: libId,
      value: value ?? this.value,
      reference: reference,
      referencePrefix: referencePrefix,
      footprint: footprint ?? this.footprint,
      datasheet: datasheet,
      description: description,
      unitCount: unitCount,
      // A power symbol is a label, not a part: KiCad keeps it out of the
      // BOM and off the board.
      inBom: inBom && !isPower,
      onBoard: onBoard && !isPower,
      componentId: componentId,
      pins: [
        for (final drawing in unitDrawings)
          if (drawing.bodyStyle <= 1)
            for (final pin in drawing.pins)
              NewPinSpec(
                number: pin.number,
                name: pin.name.isEmpty ? '~' : pin.name,
                electricalType: pin.electricalType,
                graphicStyle: pin.graphicStyle,
                unit: drawing.unit,
                bodyStyle: drawing.bodyStyle,
                x: pin.at.x,
                y: pin.at.y,
                length: pin.length,
                angle: pin.angle.round(),
                hidden: pin.hidden,
              ),
      ],
    );
  }

  /// The electrical types present, for the pinout summary line.
  Set<PinElectricalType> get electricalTypes => {
    for (final pin in pins) pin.electricalType,
  };
}
