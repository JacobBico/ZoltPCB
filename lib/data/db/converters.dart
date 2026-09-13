import 'package:drift/drift.dart';

import '../../domain/models/models.dart';

/// Stores [PinElectricalType] using its KiCad token (`power_in`), not the
/// Dart enum name, so the database stays readable and survives renames of
/// the Dart constants.
class PinElectricalTypeConverter
    extends TypeConverter<PinElectricalType, String> {
  const PinElectricalTypeConverter();

  @override
  PinElectricalType fromSql(String fromDb) =>
      PinElectricalType.fromToken(fromDb);

  @override
  String toSql(PinElectricalType value) => value.token;
}

/// Stores [PinGraphicStyle] using its KiCad token.
class PinGraphicStyleConverter extends TypeConverter<PinGraphicStyle, String> {
  const PinGraphicStyleConverter();

  @override
  PinGraphicStyle fromSql(String fromDb) => PinGraphicStyle.fromToken(fromDb);

  @override
  String toSql(PinGraphicStyle value) => value.token;
}

/// Stores [PaperSize] using its KiCad page name (`A4`, `USLetter`).
class PaperSizeConverter extends TypeConverter<PaperSize, String> {
  const PaperSizeConverter();

  @override
  PaperSize fromSql(String fromDb) => PaperSize.fromKicadName(fromDb);

  @override
  String toSql(PaperSize value) => value.kicadName;
}
