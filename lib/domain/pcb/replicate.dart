import '../models/net.dart';

/// One copy of a laid-out circuit: which part of the copy stands in for
/// each part of the original, and which net for each net.
class ReplicaChannel {
  const ReplicaChannel({
    required this.parts,
    required this.nets,
    this.turned = const {},
  });

  /// Original part id to the copy's part id.
  final Map<String, String> parts;

  /// Original net id to the copy's net id, for every net the original's
  /// pins are on.
  final Map<String, String> nets;

  /// Original part ids whose copy is wired the other way round: a two-pin
  /// part with its pins swapped, which the copy turns half a turn so its
  /// pads still meet the copied tracks.
  final Set<String> turned;
}

/// The other channels of a circuit, found by following the schematic.
///
/// A channel is a set of parts with the same symbols and footprints as
/// [sourcePartIds], wired to each other the same way: every net that joins
/// two parts of the original joins the matching parts of the copy. Pins
/// match by number, except that a part in [twoPin] (a resistor, a
/// capacitor) may be either way round, since nobody draws every channel
/// with its resistors facing the same way. Nets that leave the original
/// map to whatever the copy's pins are on, which is how a copy's tracks end
/// up on its own signal rather than the original's.
///
/// [footprintOf] gives each part's footprint; parts without one are not
/// on the board and never match. Each part belongs to one channel at most,
/// and channels come in order of their first part's reference.
List<ReplicaChannel> findReplicaChannels({
  required Set<String> sourcePartIds,
  required List<NetWithEndpoints> nets,
  required Map<String, String> footprintOf,
  Map<String, (String, String)> twoPin = const {},
}) {
  if (sourcePartIds.isEmpty) return const [];

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

  String otherPin(String partId, String number) {
    final pair = twoPin[partId]!;
    return number == pair.$1 ? pair.$2 : pair.$1;
  }

  bool internal(String net, String except) => endpointsOf[net]!.any(
    (e) => e.part.id != except && sourcePartIds.contains(e.part.id),
  );

  // The part the rest are found from: the one with the most pins wired to
  // the rest of the original, so the search starts where it is most sure.
  final source = sourcePartIds.where((id) => keyOf(id) != null).toList()
    ..sort((a, b) {
      int inner(String id) => (netOf[id]?.values ?? const <String>[])
          .where((net) => internal(net, id))
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

  /// The copy's parts and nets when [anchor] is [start], turned or not,
  /// or null when the wiring differs.
  ReplicaChannel? follow(String start, bool turnStart) {
    final parts = <String, String>{anchor: start};
    final turned = <String>{if (turnStart) anchor};
    final netMap = <String, String>{};
    final queue = [anchor];

    String pinOn(String sourcePart, String number) =>
        turned.contains(sourcePart) ? otherPin(sourcePart, number) : number;

    while (queue.isNotEmpty) {
      final from = queue.removeAt(0);
      final to = parts[from]!;
      for (final pin in (netOf[from] ?? const <String, String>{}).entries) {
        final sourceNet = pin.value;
        final targetNet = netOf[to]?[pinOn(from, pin.key)];
        if (targetNet == null) {
          // An unused pin on the copy only matters when it would join two
          // parts of the original.
          if (internal(sourceNet, from)) return null;
          continue;
        }
        final mapped = netMap[sourceNet];
        if (mapped != null && mapped != targetNet) return null;
        netMap[sourceNet] = targetNet;

        // Every other part of the original on this net needs a partner on
        // the copy's net.
        for (final endpoint in endpointsOf[sourceNet]!) {
          final other = endpoint.part.id;
          if (other == from || !sourcePartIds.contains(other)) continue;
          final number = endpoint.pin.number;
          final known = parts[other];
          if (known != null) {
            final wanted = pinOn(other, number);
            final ok = endpointsOf[targetNet]!.any(
              (e) => e.part.id == known && e.pin.number == wanted,
            );
            if (!ok) return null;
            continue;
          }
          String? partner;
          var turn = false;
          for (final e in endpointsOf[targetNet]!) {
            final id = e.part.id;
            if (taken.contains(id) ||
                parts.containsValue(id) ||
                keyOf(id) != keyOf(other)) {
              continue;
            }
            if (e.pin.number == number) {
              partner = id;
              break;
            }
            if (twoPin.containsKey(other) &&
                twoPin.containsKey(id) &&
                e.pin.number == otherPin(other, number)) {
              partner ??= id;
              turn = true;
            }
          }
          if (partner == null) return null;
          parts[other] = partner;
          if (turn) turned.add(other);
          queue.add(other);
        }
      }
    }
    if (parts.length != sourcePartIds.length) return null;
    return ReplicaChannel(parts: parts, nets: netMap, turned: turned);
  }

  final channels = <ReplicaChannel>[];
  for (final start in candidates) {
    if (taken.contains(start)) continue;
    final channel =
        follow(start, false) ??
        (twoPin.containsKey(anchor) && twoPin.containsKey(start)
            ? follow(start, true)
            : null);
    if (channel == null) continue;
    taken.addAll(channel.parts.values);
    channels.add(channel);
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
