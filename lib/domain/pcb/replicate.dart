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
  /// pins are on that the copy's matching pin is on too.
  final Map<String, String> nets;

  /// Original part ids whose copy is wired the other way round: a two-pin
  /// part with its pins swapped, which the copy turns half a turn so its
  /// pads still meet the copied tracks.
  final Set<String> turned;
}

/// The other channels of a circuit, found by following the schematic.
///
/// A channel is a set of parts with the same symbols and footprints as
/// [sourcePartIds], wired the same way: every net of the original maps to
/// one net of the copy and no two to the same one, and a pin of the copy is
/// on the net its original's pin maps to. Pins match by number, except that
/// a part in [twoPin] (a resistor, a capacitor) may be either way round,
/// since nobody draws every channel with its resistors facing the same way.
/// A pin left unwired on a copy is fine unless the original's pin joins two
/// parts of the original: an unused output is still the same circuit.
///
/// The search backs up when a choice leads nowhere, so a shared net like
/// GND, where every channel's capacitor sits, cannot send it down the wrong
/// channel for good. Parts are tried through the most particular net first.
///
/// [footprintOf] gives each part's footprint; parts without one never
/// match. [symbolOf] gives each part's symbol, needed for parts no net
/// reaches; parts on a net are known from it anyway. Each part belongs to
/// one channel at most, and channels come in order of reference.
List<ReplicaChannel> findReplicaChannels({
  required Set<String> sourcePartIds,
  required List<NetWithEndpoints> nets,
  required Map<String, String> footprintOf,
  Map<String, String> symbolOf = const {},
  Map<String, (String, String)> twoPin = const {},
}) {
  if (sourcePartIds.isEmpty) return const [];

  final netOf = <String, Map<String, String>>{};
  final symbols = {...symbolOf};
  final referenceOf = <String, String>{};
  final endpointsOf = <String, List<NetEndpoint>>{};
  for (final net in nets) {
    endpointsOf[net.id] = net.endpoints;
    for (final endpoint in net.endpoints) {
      final part = endpoint.part;
      (netOf[part.id] ??= {})[endpoint.pin.number] = net.id;
      symbols[part.id] ??= part.libId;
      referenceOf[part.id] = part.reference;
    }
  }

  String? keyOf(String partId) {
    final footprint = footprintOf[partId];
    final symbol = symbols[partId];
    if (footprint == null || symbol == null) return null;
    return '$symbol|$footprint';
  }

  if (sourcePartIds.any((id) => keyOf(id) == null)) return const [];

  String pinOn(String partId, String number, bool turn) {
    if (!turn) return number;
    final pair = twoPin[partId]!;
    return number == pair.$1 ? pair.$2 : pair.$1;
  }

  bool internal(String net, String except) => endpointsOf[net]!.any(
    (e) => e.part.id != except && sourcePartIds.contains(e.part.id),
  );

  // The order parts are matched in: outwards from the best-connected one,
  // along nets inside the original, so each is found through one already
  // matched. Parts nothing joins to the rest come last.
  int inner(String id) => (netOf[id]?.values ?? const <String>[])
      .where((net) => internal(net, id))
      .length;
  final ranked = sourcePartIds.toList()
    ..sort((a, b) {
      final byLinks = inner(b).compareTo(inner(a));
      return byLinks != 0
          ? byLinks
          : _naturalCompare(referenceOf[a] ?? '', referenceOf[b] ?? '');
    });
  final order = <String>[];
  for (final root in ranked) {
    if (order.contains(root)) continue;
    order.add(root);
    for (var i = order.length - 1; i < order.length; i++) {
      for (final net in (netOf[order[i]] ?? const <String, String>{}).values) {
        for (final e in endpointsOf[net]!) {
          if (sourcePartIds.contains(e.part.id) && !order.contains(e.part.id)) {
            order.add(e.part.id);
          }
        }
      }
    }
  }

  final byKey = <String, List<String>>{};
  for (final id in footprintOf.keys) {
    final key = keyOf(id);
    if (key == null || sourcePartIds.contains(id)) continue;
    (byKey[key] ??= []).add(id);
  }
  for (final list in byKey.values) {
    list.sort(
      (a, b) => _naturalCompare(referenceOf[a] ?? '', referenceOf[b] ?? ''),
    );
  }

  final taken = <String>{};
  final channels = <ReplicaChannel>[];
  final anchor = order.first;

  for (final start in byKey[keyOf(anchor)] ?? const <String>[]) {
    if (taken.contains(start)) continue;

    final parts = <String, String>{};
    final turned = <String>{};
    final netMap = <String, String>{};
    final image = <String, String>{};
    var budget = 20000;

    /// Matches [s] to [t], recording what it implies; returns the nets it
    /// newly mapped, or null (having recorded nothing) when it clashes.
    List<String>? assign(String s, String t, bool turn) {
      final added = <String>[];
      void undo() {
        for (final n in added) {
          image.remove(netMap.remove(n));
        }
      }

      for (final pin in (netOf[s] ?? const <String, String>{}).entries) {
        final n = pin.value;
        final tn = netOf[t]?[pinOn(s, pin.key, turn)];
        if (tn == null) {
          if (internal(n, s)) {
            undo();
            return null;
          }
          continue;
        }
        final mapped = netMap[n];
        if (mapped != null) {
          if (mapped != tn) {
            undo();
            return null;
          }
          continue;
        }
        if (image.containsKey(tn)) {
          undo();
          return null;
        }
        netMap[n] = tn;
        image[tn] = n;
        added.add(n);
      }
      // And the other way: a pin of the copy on a net the original maps to
      // must be the pin that is on it in the original.
      for (final pin in (netOf[t] ?? const <String, String>{}).entries) {
        final n = image[pin.value];
        if (n == null) continue;
        final number = turn ? pinOn(s, pin.key, true) : pin.key;
        if (netOf[s]?[number] != n) {
          undo();
          return null;
        }
      }
      return added;
    }

    bool search(int index) {
      if (--budget < 0) return false;
      if (index == order.length) return true;
      final s = order[index];

      // Through the matched net with the fewest parts on it, which is the
      // one that says most about where this part's partner is.
      Iterable<String> options = byKey[keyOf(s)] ?? const <String>[];
      if (index == 0) {
        options = [start];
      } else {
        String? narrowest;
        for (final n in (netOf[s] ?? const <String, String>{}).values) {
          final tn = netMap[n];
          if (tn == null) continue;
          if (narrowest == null ||
              endpointsOf[tn]!.length < endpointsOf[narrowest]!.length) {
            narrowest = tn;
          }
        }
        if (narrowest != null) {
          final on = {for (final e in endpointsOf[narrowest]!) e.part.id};
          options = options.where(on.contains);
        }
      }

      for (final t in options) {
        if (taken.contains(t) || parts.containsValue(t)) continue;
        for (final turn in [false, if (twoPin.containsKey(s)) true]) {
          final added = assign(s, t, turn);
          if (added == null) continue;
          parts[s] = t;
          if (turn) turned.add(s);
          if (search(index + 1)) return true;
          parts.remove(s);
          turned.remove(s);
          for (final n in added) {
            image.remove(netMap.remove(n));
          }
        }
      }
      return false;
    }

    if (!search(0)) continue;
    taken.addAll(parts.values);
    channels.add(
      ReplicaChannel(
        parts: Map.of(parts),
        nets: Map.of(netMap),
        turned: Set.of(turned),
      ),
    );
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
