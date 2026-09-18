import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// Every routed net's length and delay, longest first — what length
/// matching starts from.
Future<void> showNetLengthsDialog(
  BuildContext context, {
  required BoardScene scene,
}) {
  final names = <String, String>{
    for (final pad in scene.pads)
      if (pad.netId != null) pad.netId!: pad.netName ?? '',
  };
  final ids = {
    for (final t in scene.tracks)
      if (t.netId != null) t.netId!,
  };
  final rows = [
    for (final id in ids) (names[id] ?? 'Net', NetLength.of(scene, id)),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  final longest = rows.isEmpty ? 0.0 : rows.first.$2.length;

  String fmt(double v, [int places = 2]) => v.toStringAsFixed(places);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Net lengths'),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: 520,
        height: 300,
        child: rows.isEmpty
            ? const Center(child: Text('Nothing routed yet'))
            : ListView(
                children: [
                  for (final (name, length) in rows)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(name),
                      subtitle: Text(
                        '${length.trackCount} tracks · ${length.viaCount} vias'
                        '${longest - length.length > 0.005 ? ' · ${fmt(longest - length.length)} mm short of the longest' : ''}',
                        style: TextStyle(color: KicadPalette.textSecondary),
                      ),
                      trailing: Text(
                        '${fmt(length.length)} mm · '
                        '${fmt(length.delayPs, 0)} ps',
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('DONE'),
        ),
      ],
    ),
  );
}
