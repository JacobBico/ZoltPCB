import 'dart:ui' show Offset;

import 'part.dart';
import 'pin.dart';

/// An electrical net: a set of pins that are connected together.
///
/// Nets are the source of truth for connectivity. Drawn wires are a
/// rendering of a net, never the other way round — which is why removing a
/// connection can never "split" a net the way deleting a wire segment would
/// in a geometry-first editor.
class Net {
  const Net({
    required this.id,
    required this.projectId,
    required this.createdAt,
    this.name,
    this.labelAt,
    this.netClassId,
  });

  /// The board net class this net routes with; null for the default.
  final String? netClassId;

  final String id;
  final String projectId;

  /// User-assigned net label. `null` means the net is unnamed and will be
  /// auto-named on export, the way KiCad names anonymous nets.
  final String? name;

  /// Where the label is drawn on the sheet, in millimetres, once it has been
  /// dragged. `null` leaves it on the drawing's own choice of spot.
  final Offset? labelAt;

  final DateTime createdAt;

  bool get isNamed => name != null && name!.isNotEmpty;

  Net copyWith({
    String? name,
    bool clearName = false,
    Offset? labelAt,
    bool clearLabelAt = false,
  }) => Net(
    id: id,
    projectId: projectId,
    createdAt: createdAt,
    name: clearName ? null : (name ?? this.name),
    labelAt: clearLabelAt ? null : (labelAt ?? this.labelAt),
    netClassId: netClassId,
  );

  @override
  bool operator ==(Object other) =>
      other is Net &&
      other.id == id &&
      other.projectId == projectId &&
      other.name == name &&
      other.labelAt == labelAt &&
      other.netClassId == netClassId &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, projectId, name, labelAt, netClassId, createdAt);

  @override
  String toString() => 'Net($id, ${name ?? "<unnamed>"})';
}

/// Membership of a single pin in a [Net]. A pin belongs to at most one net,
/// enforced by a unique index in the database.
class NetNode {
  const NetNode({
    required this.id,
    required this.netId,
    required this.partPinId,
    required this.createdAt,
  });

  final String id;
  final String netId;
  final String partPinId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is NetNode &&
      other.id == id &&
      other.netId == netId &&
      other.partPinId == partPinId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, netId, partPinId, createdAt);

  @override
  String toString() => 'NetNode($id, pin $partPinId)';
}

/// One endpoint of a net, resolved against the part and pin it refers to.
/// This is what the net list UI renders: `U1 · 7 (VCC)`.
class NetEndpoint {
  const NetEndpoint({
    required this.node,
    required this.part,
    required this.pin,
  });

  final NetNode node;
  final Part part;
  final PartPin pin;

  /// `U1.7` — the compact form used in auto-generated net names.
  String get shortLabel => '${part.reference}.${pin.number}';

  /// `U1 · 7 (VCC)` — the form shown in lists.
  String get displayLabel => '${part.reference} · ${pin.label}';

  @override
  String toString() => 'NetEndpoint($shortLabel)';
}

/// A net together with its resolved endpoints.
class NetWithEndpoints {
  const NetWithEndpoints({required this.net, required this.endpoints});

  final Net net;
  final List<NetEndpoint> endpoints;

  String get id => net.id;

  /// The label to show for this net. Named nets use their label; unnamed
  /// nets fall back to a KiCad-style derived name based on the first
  /// endpoint, e.g. `Net-(R1-Pad1)`.
  String get displayName {
    if (net.isNamed) return net.name!;
    if (endpoints.isEmpty) return 'Net-(empty)';
    final first = endpoints.first;
    return 'Net-(${first.part.reference}-Pad${first.pin.number})';
  }

  bool get isDangling => endpoints.length < 2;

  @override
  String toString() => 'NetWithEndpoints($displayName, ${endpoints.length})';
}
