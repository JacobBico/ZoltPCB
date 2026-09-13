import 'package:flutter/material.dart';

import '../theme/kicad_palette.dart';

/// One entry in a [SectionRail].
class RailEntry {
  const RailEntry({
    required this.label,
    required this.icon,
    this.enabled = true,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool enabled;

  /// A small count shown at the right, e.g. the number of imported
  /// libraries.
  final String? badge;
}

/// The vertical navigation strip used by every workspace screen.
///
/// A rail rather than tabs or a drawer: on a landscape phone the horizontal
/// axis is the plentiful one, and a persistent rail keeps the section you
/// are in visible without spending vertical space.
class SectionRail extends StatelessWidget {
  const SectionRail({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onSelect,
    this.header,
    this.width = 152,
  });

  final List<RailEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Shown above the entries, separated by a divider. Used for navigation
  /// that leaves the current place rather than moving within it.
  final Widget? header;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: KicadPalette.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          if (header != null) ...[
            header!,
            Divider(height: 9, color: KicadPalette.border),
          ],
          for (var i = 0; i < entries.length; i++)
            _RailItem(
              entry: entries[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final RailEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? KicadPalette.wire
        : entry.enabled
        ? KicadPalette.textPrimary
        : KicadPalette.textDisabled;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 10, right: 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? KicadPalette.wire : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(entry.icon, size: 17, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            if (entry.badge != null)
              Text(
                entry.badge!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A [SectionRail] that slides in over the content instead of taking a
/// permanent column of the screen.
///
/// A landscape phone has width to spare but not much of it, and a rail that
/// is always there costs 150-odd pixels on every screen for navigation the
/// user only needs between tasks. Sliding it over the content — rather than
/// pushing the content aside — also means the panel underneath never
/// reflows, so a schematic does not jump when the rail opens.
class OverlayRail extends StatelessWidget {
  const OverlayRail({
    super.key,
    required this.open,
    required this.entries,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDismiss,
    required this.child,
    this.header,
    this.width = 176,
  });

  final bool open;
  final List<RailEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onDismiss;
  final Widget child;
  final Widget? header;
  final double width;

  static const _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !open,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: _duration,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: _duration,
          curve: Curves.easeOutCubic,
          left: open ? 0 : -width,
          top: 0,
          bottom: 0,
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: KicadPalette.surface,
              border: Border(
                right: BorderSide(color: KicadPalette.borderStrong),
              ),
            ),
            child: SafeArea(
              top: false,
              right: false,
              child: SectionRail(
                entries: entries,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                header: header,
                width: width,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// A rail entry that navigates away rather than switching section.
class RailLeaveItem extends StatelessWidget {
  const RailLeaveItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: KicadPalette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
