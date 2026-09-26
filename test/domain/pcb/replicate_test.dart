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

  test('a resistor drawn the other way round still matches', () {
    // R2 meets C2 on its pin 1, where R1 meets C1 on its pin 2.
    final swapped = [
      net('in1', [('R1', '1')]),
      net('a1', [('R1', '2'), ('C1', '1')]),
      net('in2', [('R2', '2')]),
      net('a2', [('R2', '1'), ('C2', '1')]),
      net('gnd', [('C1', '2'), ('C2', '2')]),
    ];
    final twoPin = {
      for (final id in ['R1', 'R2', 'C1', 'C2']) id: ('1', '2'),
    };
    expect(
      findReplicaChannels(
        sourcePartIds: {'R1', 'C1'},
        nets: swapped,
        footprintOf: footprints,
      ),
      isEmpty,
    );
    final channel = findReplicaChannels(
      sourcePartIds: {'R1', 'C1'},
      nets: swapped,
      footprintOf: footprints,
      twoPin: twoPin,
    ).single;
    expect(channel.parts, {'R1': 'R2', 'C1': 'C2'});
    expect(channel.nets['in1'], 'in2');
    expect(channel.turned, {'R1'});
  });

  group('when every channel shares GND', () {
    // Channel 2 is R2 with C3, channel 3 is R3 with C2: going by GND alone
    // would pair R2 with C2 and lose both.
    final crossed = [
      net('gnd', [
        ('C1', '2'),
        ('C2', '2'),
        ('C3', '2'),
        ('R1', '1'),
        ('R2', '1'),
        ('R3', '1'),
      ]),
      net('a1', [('R1', '2'), ('C1', '1')]),
      net('a2', [('R2', '2'), ('C3', '1')]),
      net('a3', [('R3', '2'), ('C2', '1')]),
    ];

    test('the pairs come from the nets only they share', () {
      final channels = findReplicaChannels(
        sourcePartIds: {'R1', 'C1'},
        nets: crossed,
        footprintOf: {...footprints, 'C3': 'C_0805'},
      );
      expect(channels.map((c) => c.parts).toList(), [
        {'C1': 'C2', 'R1': 'R3'},
        {'C1': 'C3', 'R1': 'R2'},
      ]);
      expect(channels.first.nets, {'a1': 'a3', 'gnd': 'gnd'});
    });
  });

  test('two nets of the original never become one on the copy', () {
    // R2's two pins are shorted together: not the same circuit as R1-C1.
    final shorted = [
      net('in1', [('R1', '1')]),
      net('a1', [('R1', '2'), ('C1', '1')]),
      net('a2', [('R2', '1'), ('R2', '2'), ('C2', '1')]),
      net('gnd', [('C1', '2'), ('C2', '2')]),
    ];
    expect(
      findReplicaChannels(
        sourcePartIds: {'R1', 'C1'},
        nets: shorted,
        footprintOf: footprints,
      ),
      isEmpty,
    );
  });

  test('a part wired to nothing still comes along', () {
    final channels = findReplicaChannels(
      sourcePartIds: {'R1', 'C1', 'H1'},
      nets: nets,
      footprintOf: {...footprints, 'H1': 'Hole', 'H2': 'Hole'},
      symbolOf: {'H1': 'Mechanical:Hole', 'H2': 'Mechanical:Hole'},
    );
    expect(channels.single.parts, {'R1': 'R2', 'C1': 'C2', 'H1': 'H2'});
  });
}
