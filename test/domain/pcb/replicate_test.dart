import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/domain/pcb/replicate.dart';

void main() {
  final now = DateTime(2026);
  Part part(String ref, String lib) => Part(
    id: ref,
    projectId: 'p',
    libId: lib,
    reference: ref,
    value: '',
    createdAt: now,
  );

  // Two RC channels: IN1 -R1- A1 -C1- GND, IN2 -R2- A2 -C2- GND. R3 is a
  // resistor on its own, which must not be taken for a channel.
  NetWithEndpoints net(String id, List<(String, String)> pins) =>
      NetWithEndpoints(
        net: Net(id: id, projectId: 'p', createdAt: now),
        endpoints: [
          for (final (ref, number) in pins)
            NetEndpoint(
              node: NetNode(
                id: '$id$ref$number',
                netId: id,
                partPinId: '$ref.$number',
                createdAt: now,
              ),
              part: part(ref, ref.startsWith('R') ? 'Device:R' : 'Device:C'),
              pin: PartPin(
                id: '$ref.$number',
                partId: ref,
                unit: 1,
                number: number,
                name: '~',
                electricalType: PinElectricalType.passive,
              ),
            ),
        ],
      );

  final nets = [
    net('in1', [('R1', '1')]),
    net('a1', [('R1', '2'), ('C1', '1')]),
    net('in2', [('R2', '1')]),
    net('a2', [('R2', '2'), ('C2', '1')]),
    net('gnd', [('C1', '2'), ('C2', '2'), ('R3', '2')]),
    net('x', [('R3', '1')]),
  ];
  const footprints = {
    'R1': 'R_0805',
    'R2': 'R_0805',
    'R3': 'R_0805',
    'C1': 'C_0805',
    'C2': 'C_0805',
  };

  test('finds the other channel by how it is wired', () {
    final channels = findReplicaChannels(
      sourcePartIds: {'R1', 'C1'},
      nets: nets,
      footprintOf: footprints,
    );
    expect(channels, hasLength(1));
    expect(channels.single.parts, {'R1': 'R2', 'C1': 'C2'});
    expect(channels.single.nets, {'in1': 'in2', 'a1': 'a2', 'gnd': 'gnd'});
  });

  test('a different footprint is not a copy', () {
    final channels = findReplicaChannels(
      sourcePartIds: {'R1', 'C1'},
      nets: nets,
      footprintOf: {...footprints, 'C2': 'C_0603'},
    );
    expect(channels, isEmpty);
  });
}
