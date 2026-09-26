import '../models/net.dart';

/// One copy of a laid-out circuit: which part of the copy stands in for
/// each part of the original, and which net for each net.
class ReplicaChannel {
  const ReplicaChannel({required this.parts, required this.nets});

  /// Original part id to the copy's part id.
  final Map<String, String> parts;

  /// Original net id to the copy's net id, for every net the original's
  /// pins are on.
  final Map<String, String> nets;
}

/// The other channels of a circuit, found by following the schematic.
///
/// A channel is a set of parts with the same symbols and footprints as
/// [sourcePartIds], wired to each other the same way: pin for pin, every
/// net that joins two parts of the original joins the matching parts of
/// the copy. Nets that leave the original (to a connector, a supply) map to
/// whatever the copy's pins are on, which is how a copy's tracks end up on
/// its own signal rather than the original's.
///
/// [footprintOf] gives each part's footprint; parts without one are not
/// on the board and never match. Each part belongs to one channel at most,
/// and channels come in order of their first part's reference.
List<ReplicaChannel> findReplicaChannels({
  required Set<String> sourcePartIds,
  required List<NetWithEndpoints> nets,
  required Map<String, String> footprintOf,
}) {
  if (sourcePartIds.isEmpty) return const [];

  // Pin by pin: (part, pin number) -> net, and each net's endpoints.
  final netOf = <String, Map<String, String>>{};
  final symbolOf = <String, String>{};
  final referenceOf = <String, String>{};
  final endpointsOf = <String, List<NetEndpoint>>{};
  for (final net in nets) {
    endpointsOf[net.id] = net.endpoints;
    for (final endpoint in net.endpoints) {
      final part = endpoint.part;
      (netOf[part.id] ??= {})[endpoint.pin.number] = net.id;
      symbolOf[part.id] = part.libId;
      referenceOf[part.id] = part.reference;
    }
  }

  String? keyOf(String partId) {
    final footprint = footprintOf[partId];
    final symbol = symbolOf[partId];
    if (footprint == null || symbol == null) return null;
    return '$symbol|$footprint';
  }

  // The part the rest are found from: the one with the most pins wired to
  // the rest of the original, so the search starts where it is most sure.
  final source = sourcePartIds.where((id) => keyOf(id) != null).toList()
    ..sort((a, b) {
      int inner(String id) => (netOf[id]?.values ?? const <String>[])
          .where(
            (net) => endpointsOf[net]!.any(
              (e) => e.part.id != id && sourcePartIds.contains(e.part.id),
            ),
          )
          .length;
      return inner(b).compareTo(inner(a));
    });
  if (source.length != sourcePartIds.length) return const [];
  final anchor = source.first;

  final taken = <String>{...sourcePartIds};
  final candidates =
      [
        for (final id in footprintOf.keys)
          if (!taken.contains(id) && keyOf(id) == keyOf(anchor)) id,
      ]..sort(
        (a, b) => _naturalCompare(referenceOf[a] ?? '', referenceOf[b] ?? ''),
      );

  final channels = <ReplicaChannel>[];
  for (final start in candidates) {
    if (taken.contains(start)) continue;
    final parts = <String, String>{anchor: start};
    final used = <String>{start};
    final netMap = <String, String>{};
    final queue = [anchor];
    var failed = false;

    while (queue.isNotEmpty && !failed) {
      final from = queue.removeAt(0);
      final to = parts[from]!;
      for (final pin in (netOf[from] ?? const <String, String>{}).entries) {
        final sourceNet = pin.value;
        final targetNet = netOf[to]?[pin.key];
        if (targetNet == null) {
          // The original is wired here and the copy is not.
          failed = true;
          break;
        }
        final mapped = netMap[sourceNet];
        if (mapped != null && mapped != targetNet) {
          failed = true;
          break;
        }
        netMap[sourceNet] = targetNet;

        // Every other part of the original on this net needs a partner on
        // the copy's net, on the same pin.
        for (final endpoint in endpointsOf[sourceNet]!) {
          final other = endpoint.part.id;
          if (other == from || !sourcePartIds.contains(other)) continue;
          final known = parts[other];
          final partner = known != null
              ? (endpointsOf[targetNet]!.any(
                      (e) =>
                          e.part.id == known &&
                          e.pin.number == endpoint.pin.number,
                    )
                    ? known
                    : null)
              : endpointsOf[targetNet]!
                    .where(
                      (e) =>
                          e.pin.number == endpoint.pin.number &&
                          !taken.contains(e.part.id) &&
                          !used.contains(e.part.id) &&
                          keyOf(e.part.id) == keyOf(other),
                    )
                    .map((e) => e.part.id)
                    .firstOrNull;
          if (partner == null) {
            failed = true;
            break;
          }
          if (known == null) {
            parts[other] = partner;
            used.add(partner);
            queue.add(other);
          }
        }
        if (failed) break;
      }
    }

    if (failed || parts.length != sourcePartIds.length) continue;
    taken.addAll(used);
    channels.add(ReplicaChannel(parts: parts, nets: netMap));
  }
  return channels;
}

/// R2 before R10.
int _naturalCompare(String a, String b) {
  final pattern = RegExp(r'^(\D*)(\d*)');
  final ma = pattern.firstMatch(a)!;
  final mb = pattern.firstMatch(b)!;
  final prefix = ma[1]!.compareTo(mb[1]!);
  if (prefix != 0) return prefix;
  final na = int.tryParse(ma[2]!) ?? 0;
  final nb = int.tryParse(mb[2]!) ?? 0;
  return na != nb ? na.compareTo(nb) : a.compareTo(b);
}
