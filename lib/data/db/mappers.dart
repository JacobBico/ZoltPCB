import 'dart:ui' show Offset;

import '../../domain/models/models.dart';
import 'database.dart';

/// Translation between generated Drift rows and the pure domain model.
///
/// The domain layer must not import Drift, so every crossing of that
/// boundary happens here.
extension ProjectRowMapper on ProjectRow {
  Project toDomain() => Project(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    paper: paper,
    company: company,
    revision: revision,
  );
}

extension PartRowMapper on PartRow {
  Part toDomain() => Part(
    id: id,
    projectId: projectId,
    libId: libId,
    reference: reference,
    value: value,
    footprint: footprint,
    datasheet: datasheet,
    description: description,
    unitCount: unitCount,
    inBom: inBom,
    onBoard: onBoard,
    dnp: dnp,
    fieldsHidden: fieldsHidden,
    createdAt: createdAt,
  );
}

extension PartUnitRowMapper on PartUnitRow {
  PartUnit toDomain() => PartUnit(
    id: id,
    partId: partId,
    unitNumber: unitNumber,
    bodyStyle: bodyStyle,
    x: x,
    y: y,
    rotation: rotation,
    mirrorX: mirrorX,
    mirrorY: mirrorY,
    placed: placed,
  );
}

extension PartPinRowMapper on PartPinRow {
  PartPin toDomain() => PartPin(
    id: id,
    partId: partId,
    unit: unit,
    bodyStyle: bodyStyle,
    number: number,
    name: name,
    electricalType: electricalType,
    graphicStyle: graphicStyle,
    x: x,
    y: y,
    length: length,
    angle: angle,
    noConnect: noConnect,
    hidden: hidden,
  );
}

extension NetRowMapper on NetRow {
  Net toDomain() => Net(
    id: id,
    projectId: projectId,
    name: name,
    labelAt: labelX == null || labelY == null ? null : Offset(labelX!, labelY!),
    netClassId: netClassId,
    createdAt: createdAt,
  );
}

extension NetNodeRowMapper on NetNodeRow {
  NetNode toDomain() =>
      NetNode(id: id, netId: netId, partPinId: partPinId, createdAt: createdAt);
}
