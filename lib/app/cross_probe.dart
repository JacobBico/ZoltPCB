import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which half of the project a probe is sent to.
enum ProbeTarget { schematic, board }

/// "Show this part, or this net, on the other side."
///
/// Sent by one editor and picked up by the other once it is on screen:
/// the schematic selects and centres a part, the board highlights a net's
/// copper. On a phone the question is almost always "which of these is
/// SDA", and finding the answer by eye on the other sheet is where the
/// time goes.
class ProbeRequest {
  const ProbeRequest({required this.target, this.partId, this.netId});

  final ProbeTarget target;
  final String? partId;
  final String? netId;
}

final crossProbeProvider = NotifierProvider<CrossProbe, ProbeRequest?>(
  CrossProbe.new,
);

class CrossProbe extends Notifier<ProbeRequest?> {
  @override
  ProbeRequest? build() => null;

  void send(ProbeRequest request) => state = request;

  /// Takes the waiting request for [target], if there is one, so it is
  /// acted on exactly once.
  ProbeRequest? take(ProbeTarget target) {
    final request = state;
    if (request == null || request.target != target) return null;
    state = null;
    return request;
  }
}
