import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../data/repositories/net_repository.dart';
import '../../domain/models/models.dart';
import '../components/pin_type_style.dart';

/// The pin waiting for a partner, while a connection is being made.
final pendingPinProvider = NotifierProvider<PendingPin, String?>(
  PendingPin.new,
);

class PendingPin extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? pinId) => state = pinId;
}

/// Connectivity editing: tap one pin, then tap another, and they are on a
/// net together.
///
/// There is no wire to draw and no junction to place. A net is a set of
/// pins, so the only gesture needed is "these two belong together" — and
/// because nothing is geometric, the same two taps work whether the pins are
/// already on nets, on the same net, or on two nets that should be one.
class NetsPanel extends ConsumerWidget {
  const NetsPanel({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partsAsync = ref.watch(projectPartsProvider(project.id));
    final netsAsync = ref.watch(projectNetsProvider(project.id));

    // Errors are surfaced rather than rendered as an empty pane: a failure
    // to read connectivity looks exactly like "nothing is connected", which
    // is the most misleading thing this screen could show.
    final error = partsAsync.error ?? netsAsync.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read the netlist',
        message: '$error',
      );
    }

    final parts = partsAsync.value;
    final nets = netsAsync.value;
    if (parts == null || nets == null) return const SizedBox.shrink();
    if (parts.isEmpty) {
      return const EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'Nothing to connect yet',
        message:
            'Add components first. Their pins appear here, and tapping two '
            'of them puts them on a net.',
      );
    }

    // A pin belongs to at most one net, so this is a complete picture of
    // the project's connectivity keyed the way the pin list needs it.
    final netByPin = <String, NetWithEndpoints>{
      for (final net in nets)
        for (final endpoint in net.endpoints) endpoint.pin.id: net,
    };

    return Column(
      children: [
        _PendingBanner(project: project),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 55,
                child: _PinList(
                  project: project,
                  parts: parts,
                  netByPin: netByPin,
                ),
              ),
              VerticalDivider(width: 1, color: KicadPalette.border),
              Expanded(flex: 45, child: _NetList(nets: nets)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingBanner extends ConsumerWidget {
  const _PendingBanner({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingId = ref.watch(pendingPinProvider);
    final parts = ref.watch(projectPartsProvider(project.id)).value ?? const [];

    if (pendingId == null) {
      return Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: KicadPalette.border)),
        ),
        child: Text(
          'Tap a pin, then tap another to connect them',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: KicadPalette.textSecondary),
        ),
      );
    }

    String label = pendingId;
    for (final part in parts) {
      for (final pin in part.pins) {
        if (pin.id == pendingId) {
          label = '${part.part.reference} · ${pin.label}';
        }
      }
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: KicadPalette.highlight.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: KicadPalette.highlight)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.electrical_services,
            size: 15,
            color: KicadPalette.highlight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Connecting from $label — tap the other pin',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: KicadPalette.highlight),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(pendingPinProvider.notifier).set(null),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }
}

class _PinList extends ConsumerWidget {
  const _PinList({
    required this.project,
    required this.parts,
    required this.netByPin,
  });

  final Project project;
  final List<PartWithDetails> parts;
  final Map<String, NetWithEndpoints> netByPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingPinProvider);

    // One flat list of headers and pins, so a long design scrolls smoothly
    // rather than nesting a scrollable per part.
    final rows = <Widget>[];
    for (final part in parts) {
      rows.add(_PartHeader(part: part));
      for (final pin in part.pins) {
        rows.add(
          _PinRow(
            key: ValueKey('pin-${pin.id}'),
            part: part.part,
            pin: pin,
            net: netByPin[pin.id],
            pending: pin.id == pending,
            multiUnit: part.part.isMultiUnit,
            onTap: () => _tap(context, ref, pin.id),
            onDisconnect: netByPin[pin.id] == null
                ? null
                : () => ref.read(netRepositoryProvider).disconnectPin(pin.id),
            onToggleNoConnect: netByPin[pin.id] != null
                ? null
                : () => ref
                      .read(partRepositoryProvider)
                      .setPinNoConnect(pin.id, !pin.noConnect),
          ),
        );
      }
    }

    return Column(
      children: [
        _ListHeader(
          label: 'PINS',
          trailing: '${parts.fold<int>(0, (n, p) => n + p.pins.length)}',
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index],
          ),
        ),
      ],
    );
  }

  Future<void> _tap(BuildContext context, WidgetRef ref, String pinId) async {
    final notifier = ref.read(pendingPinProvider.notifier);
    final pending = ref.read(pendingPinProvider);

    if (pending == null) {
      notifier.set(pinId);
      return;
    }
    if (pending == pinId) {
      notifier.set(null);
      return;
    }

    notifier.set(null);
    try {
      await ref.read(netRepositoryProvider).connectPins(pending, pinId);
    } on InvalidConnectionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: KicadPalette.textSecondary,
      letterSpacing: 1.2,
    );
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: KicadPalette.background,
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

class _PartHeader extends StatelessWidget {
  const _PartHeader({required this.part});

  final PartWithDetails part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 14, right: 12),
      color: KicadPalette.surface,
      child: Row(
        children: [
          Text(
            part.part.reference,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: KicadPalette.fieldText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              part.part.value,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
          if (part.part.isMultiUnit)
            Text(
              '${part.part.unitCount} units',
              style: theme.textTheme.bodySmall?.copyWith(
                color: KicadPalette.warning,
              ),
            ),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    super.key,
    required this.part,
    required this.pin,
    required this.net,
    required this.pending,
    required this.multiUnit,
    required this.onTap,
    this.onDisconnect,
    this.onToggleNoConnect,
  });

  final Part part;
  final PartPin pin;
  final NetWithEndpoints? net;
  final bool pending;
  final bool multiUnit;
  final VoidCallback onTap;
  final VoidCallback? onDisconnect;
  final VoidCallback? onToggleNoConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = net != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        // Comfortably above the 48dp minimum: these are the app's most
        // frequently tapped targets and they sit in a dense list.
        height: 48,
        padding: const EdgeInsets.only(left: 26, right: 4),
        decoration: BoxDecoration(
          color: pending
              ? KicadPalette.highlight.withValues(alpha: 0.16)
              : null,
          border: Border(bottom: BorderSide(color: KicadPalette.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Icon(
                connected
                    ? Icons.circle
                    : pin.noConnect
                    ? Icons.close
                    : Icons.circle_outlined,
                size: pin.noConnect ? 13 : 9,
                color: connected
                    ? KicadPalette.wire
                    : pin.noConnect
                    ? KicadPalette.noConnect
                    : KicadPalette.textDisabled,
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                pin.number,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: KicadPalette.pinNumber,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                pin.name == '~' || pin.name.isEmpty ? '—' : pin.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pin.name == '~' || pin.name.isEmpty
                      ? KicadPalette.textDisabled
                      : KicadPalette.pinName,
                ),
              ),
            ),
            SizedBox(
              width: 66,
              child: Text(
                PinTypeStyle.label(pin.electricalType),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PinTypeStyle.color(pin.electricalType),
                ),
              ),
            ),
            if (multiUnit)
              SizedBox(
                width: 34,
                child: Text(
                  pin.unit == 0 ? 'all' : 'u${pin.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pin.unit == 0
                        ? KicadPalette.warning
                        : KicadPalette.textSecondary,
                  ),
                ),
              ),
            Expanded(
              flex: 4,
              child: Text(
                net?.displayName ?? (pin.noConnect ? 'no connect' : ''),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: connected ? KicadPalette.wire : KicadPalette.noConnect,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: switch ((onDisconnect, onToggleNoConnect)) {
                (final disconnect?, _) => IconButton(
                  tooltip: 'Disconnect',
                  icon: const Icon(Icons.link_off, size: 16),
                  onPressed: disconnect,
                ),
                (_, final toggle?) => IconButton(
                  tooltip: pin.noConnect
                      ? 'Clear the no-connect flag'
                      : 'Mark as deliberately unconnected',
                  icon: Icon(
                    pin.noConnect ? Icons.check_box_outlined : Icons.close,
                    size: 16,
                    color: pin.noConnect ? KicadPalette.noConnect : null,
                  ),
                  onPressed: toggle,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NetList extends ConsumerWidget {
  const _NetList({required this.nets});

  final List<NetWithEndpoints> nets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ListHeader(label: 'NETS', trailing: '${nets.length}'),
        Expanded(
          child: nets.isEmpty
              ? const EmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'No nets yet',
                  message: 'Tap two pins on the left to make one.',
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: nets.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: KicadPalette.border),
                  itemBuilder: (context, index) => _NetRow(
                    key: ValueKey('net-${nets[index].id}'),
                    net: nets[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NetRow extends ConsumerWidget {
  const _NetRow({super.key, required this.net});

  final NetWithEndpoints net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _rename(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          net.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: net.net.isNamed
                                ? KicadPalette.label
                                : KicadPalette.textSecondary,
                          ),
                        ),
                      ),
                      if (net.isDangling) ...[
                        const SizedBox(width: 8),
                        Text(
                          'dangling',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    net.endpoints.map((e) => e.shortLabel).join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                tooltip: 'Net actions',
                icon: const Icon(Icons.more_vert, size: 18),
                color: KicadPalette.surfaceRaised,
                onSelected: (value) => switch (value) {
                  'rename' => _rename(context, ref),
                  'clear' =>
                    ref.read(netRepositoryProvider).renameNet(net.id, null),
                  'delete' => ref.read(netRepositoryProvider).deleteNet(net.id),
                  _ => null,
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    height: 44,
                    child: Text('Label…'),
                  ),
                  if (net.net.isNamed)
                    const PopupMenuItem(
                      value: 'clear',
                      height: 44,
                      child: Text('Remove label'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 44,
                    child: Text(
                      'Delete net',
                      style: TextStyle(color: KicadPalette.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NetLabelDialog(initialValue: net.net.name ?? ''),
    );
    if (name == null) return;
    await ref.read(netRepositoryProvider).renameNet(net.id, name);
  }
}

/// Asks for a net label.
///
/// Stateful so the dialog owns its controller and disposes it when the
/// dialog leaves the tree. Disposing it as soon as `showDialog` returns
/// looks equivalent but is not: the dialog is still animating out, and its
/// text field still reads the controller.
class NetLabelDialog extends StatefulWidget {
  const NetLabelDialog({super.key, required this.initialValue});

  final String initialValue;

  @override
  State<NetLabelDialog> createState() => NetLabelDialogState();
}

class NetLabelDialogState extends State<NetLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Net label'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'VCC, GND, SDA…',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
