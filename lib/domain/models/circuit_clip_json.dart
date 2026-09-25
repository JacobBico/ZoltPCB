import 'dart:ui';

import 'circuit_clip.dart';
import 'part_spec.dart';
import 'pin.dart';

/// A [CircuitClip] as plain JSON, for keeping one past the session — a
/// saved circuit.
///
/// Pin types are written by name, and anything this version does not know
/// reads as a passive pin rather than failing the whole circuit.
abstract final class CircuitClipJson {
  static const version = 1;

  static Map<String, Object?> encode(CircuitClip clip) => {
    'version': version,
    'parts': [for (final part in clip.parts) _part(part)],
    'nets': [
      for (final net in clip.nets)
        {
          'name': net.name,
          'pins': [for (final pin in net.pins) _pin(pin)],
        },
    ],
    'wires': [
      for (final wire in clip.wires)
        {
          'points': [
            for (final p in wire.points) [p.dx, p.dy],
          ],
          'net': wire.net,
          'pinA': wire.pinA == null ? null : _pin(wire.pinA!),
          'pinB': wire.pinB == null ? null : _pin(wire.pinB!),
        },
    ],
  };

  static CircuitClip decode(Map<String, Object?> json) => CircuitClip(
    parts: [for (final raw in json['parts'] as List) _readPart(_map(raw))],
    nets: [
      for (final raw in (json['nets'] as List?) ?? const [])
        ClipNet(
          name: _map(raw)['name'] as String?,
          pins: [
            for (final pin in _map(raw)['pins'] as List) _readPin(_map(pin)),
          ],
        ),
    ],
    wires: [
      for (final raw in (json['wires'] as List?) ?? const [])
        ClipWire(
          points: [
            for (final p in _map(raw)['points'] as List)
              Offset(
                ((p as List)[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ),
          ],
          net: _map(raw)['net'] as int,
          pinA: _map(raw)['pinA'] == null
              ? null
              : _readPin(_map(_map(raw)['pinA'])),
          pinB: _map(raw)['pinB'] == null
              ? null
              : _readPin(_map(_map(raw)['pinB'])),
        ),
    ],
  );

  static Map<String, Object?> _map(Object? raw) =>
      Map<String, Object?>.from(raw! as Map);

  static Map<String, Object?> _pin(ClipPin pin) => {
    'part': pin.part,
    'unit': pin.unit,
    'number': pin.number,
  };

  static ClipPin _readPin(Map<String, Object?> json) => ClipPin(
    part: json['part'] as int,
    unit: json['unit'] as int,
    number: json['number'] as String,
  );

  static Map<String, Object?> _part(ClipPart part) {
    final spec = part.spec;
    return {
      'libId': spec.libId,
      'value': spec.value,
      'referencePrefix': spec.referencePrefix,
      'footprint': spec.footprint,
      'datasheet': spec.datasheet,
      'description': spec.description,
      'unitCount': spec.unitCount,
      'inBom': spec.inBom,
      'onBoard': spec.onBoard,
      'componentId': spec.componentId,
      'pins': [
        for (final pin in spec.pins)
          {
            'number': pin.number,
            'name': pin.name,
            'type': pin.electricalType.name,
            'style': pin.graphicStyle.name,
            'unit': pin.unit,
            'bodyStyle': pin.bodyStyle,
            'x': pin.x,
            'y': pin.y,
            'length': pin.length,
            'angle': pin.angle,
            'hidden': pin.hidden,
          },
      ],
      'units': [
        for (final unit in part.units)
          {
            'unit': unit.unitNumber,
            'x': unit.offset.dx,
            'y': unit.offset.dy,
            'rotation': unit.rotation,
            'mirrorX': unit.mirrorX,
            'mirrorY': unit.mirrorY,
          },
      ],
    };
  }

  static ClipPart _readPart(Map<String, Object?> json) {
    double number(Object? v) => (v as num?)?.toDouble() ?? 0;
    return ClipPart(
      spec: NewPartSpec(
        libId: json['libId'] as String,
        value: json['value'] as String? ?? '',
        referencePrefix: json['referencePrefix'] as String? ?? 'U',
        footprint: json['footprint'] as String? ?? '',
        datasheet: json['datasheet'] as String? ?? '',
        description: json['description'] as String? ?? '',
        unitCount: json['unitCount'] as int? ?? 1,
        inBom: json['inBom'] as bool? ?? true,
        onBoard: json['onBoard'] as bool? ?? true,
        componentId: json['componentId'] as String? ?? '',
        pins: [
          for (final raw in json['pins'] as List)
            () {
              final pin = _map(raw);
              return NewPinSpec(
                number: pin['number'] as String,
                name: pin['name'] as String? ?? '~',
                electricalType:
                    PinElectricalType.values
                        .where((t) => t.name == pin['type'])
                        .firstOrNull ??
                    PinElectricalType.passive,
                graphicStyle:
                    PinGraphicStyle.values
                        .where((s) => s.name == pin['style'])
                        .firstOrNull ??
                    PinGraphicStyle.line,
                unit: pin['unit'] as int? ?? 1,
                bodyStyle: pin['bodyStyle'] as int? ?? 1,
                x: number(pin['x']),
                y: number(pin['y']),
                length: number(pin['length'] ?? 2.54),
                angle: pin['angle'] as int? ?? 0,
                hidden: pin['hidden'] as bool? ?? false,
              );
            }(),
        ],
      ),
      units: [
        for (final raw in json['units'] as List)
          () {
            final unit = _map(raw);
            return ClipUnit(
              unitNumber: unit['unit'] as int? ?? 1,
              offset: Offset(number(unit['x']), number(unit['y'])),
              rotation: unit['rotation'] as int? ?? 0,
              mirrorX: unit['mirrorX'] as bool? ?? false,
              mirrorY: unit['mirrorY'] as bool? ?? false,
            );
          }(),
      ],
    );
  }
}
