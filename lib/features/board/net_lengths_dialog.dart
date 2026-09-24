import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// One routed net's length, ready to list.
class _Row {
  const _Row({
    required this.name,
    required this.length,
    this.className,
    this.skew,
  });

  final String name;
  final NetLength length;
  final String? className;

  /// For one half of a differential pair: how much longer this half is than
  /// the other, in millimetres. Negative when it is the shorter.
  final double? skew;
}

/// The routed length summary line for the board menu: how many nets have
/// copper and which is the longest.
String netLengthsSummary(BoardScene scene) {
  final rows = _rows(scene);
  if (rows.isEmpty) return 'Nothing routed yet';
  final longest = rows.first;
  return '${rows.length} routed · longest ${longest.name} '
      '${longest.length.length.toStringAsFixed(1)} mm';
}

List<_Row> _rows(BoardScene scene) {
  final names = <String, String>{
    for (final pad in scene.pads)
      if (pad.netId != null) pad.netId!: pad.netName ?? '',
  };
  final ids = {
    for (final t in scene.tracks)
      if (t.netId != null) t.netId!,
  };
  final lengths = {for (final id in ids) id: NetLength.of(scene, id)};
  return [
    for (final id in ids)
      _Row(
        name: (names[id] ?? '').isEmpty ? 'Unnamed net' : names[id]!,
        length: lengths[id]!,
        className: scene.classOf(id)?.name,
        skew: switch (DiffPairs.of(scene, id)?.partnerOf(id)) {
          final partner? when lengths[partner] != null =>
            lengths[id]!.length - lengths[partner]!.length,
          _ => null,
        },
      ),
  ]..sort((a, b) => b.length.length.compareTo(a.length.length));
}

/// Every routed net's length and delay, longest first — what length
/// matching starts from.
Future<void> showNetLengthsDialog(
  BuildContext context, {
  required BoardScene scene,
}) => showDialog<void>(
  context: context,
  builder: (context) => _NetLengthsDialog(rows: _rows(scene)),
);

class _NetLengthsDialog extends StatefulWidget {
  const _NetLengthsDialog({required this.rows});

  final List<_Row> rows;

  @override
  State<_NetLengthsDialog> createState() => _NetLengthsDialogState();
}

class _NetLengthsDialogState extends State<_NetLengthsDialog> {
  /// Only the nets that are half of a differential pair.
  bool _pairsOnly = false;

  static String _fmt(double v, [int places = 2]) => v.toStringAsFixed(places);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.rows;
    final rows = _pairsOnly
        ? [
            for (final r in all)
              if (r.skew != null) r,
          ]
        : all;
    final longest = all.isEmpty ? 0.0 : all.first.length.length;
    final hasPairs = all.any((r) => r.skew != null);

    return AlertDialog(
      title: const Text('Net lengths'),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: SizedBox(
        width: 540,
        height: 360,
        child: all.isEmpty
            ? Center(
                child: Text(
                  'Nothing routed yet. Lengths appear here as nets are '
                  'routed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${all.length} routed nets · longest '
                          '${_fmt(longest)} mm',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.textSecondary,
                          ),
                        ),
                      ),
                      if (hasPairs)
                        FilterChip(
                          key: const ValueKey('net-lengths-pairs'),
                          label: const Text('Pairs only'),
                          selected: _pairsOnly,
                          onSelected: (on) => setState(() => _pairsOnly = on),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: KicadPalette.border),
                      itemBuilder: (context, index) =>
                          _row(context, rows[index], longest),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'To add length to a net, select one of its tracks and '
                      'press Tune.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textDisabled,
                      ),
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
    );
  }

  Widget _row(BuildContext context, _Row row, double longest) {
    final theme = Theme.of(context);
    final length = row.length;
    final skew = row.skew;
    final details = [
      '${length.trackCount} tracks',
      '${length.viaCount} vias',
      ?row.className,
      if (skew != null)
        skew.abs() < 0.005
            ? 'pair matched'
            : 'pair skew ${skew > 0 ? '+' : '−'}${_fmt(skew.abs())} mm',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${_fmt(length.length)} mm · ${_fmt(length.delayPs, 0)} ps',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: longest <= 0 ? 0 : length.length / longest,
              minHeight: 3,
              backgroundColor: KicadPalette.border,
              color: skew != null && skew.abs() >= 0.005
                  ? KicadPalette.warning
                  : KicadPalette.highlight,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            details,
            style: theme.textTheme.bodySmall?.copyWith(
              color: KicadPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
