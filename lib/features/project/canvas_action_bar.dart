import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';

/// One command in the canvas action bar.
class CanvasAction {
  const CanvasAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;

  /// Null when the command is unavailable, e.g. undo with nothing to undo.
  final VoidCallback? onPressed;
  final bool danger;
}

/// The commands that apply to whatever is currently selected.
///
/// A bar that appears on selection rather than a permanent toolbar: a
/// landscape phone has no vertical room to spare, and these verbs are
/// meaningless with nothing selected. It sits bottom-left so it never
/// collides with the zoom controls.
class CanvasActionBar extends StatelessWidget {
  const CanvasActionBar({
    super.key,
    required this.title,
    required this.actions,
    this.hinting = false,
  });

  /// True when [title] is a passing message rather than the name of what
  /// is selected, so it can be told apart at a glance.
  final bool hinting;

  /// What the commands apply to, e.g. `R1` or `U1.3`. Empty when the bar is
  /// showing only undo and redo, in which case no label is drawn.
  final String title;
  final List<CanvasAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: KicadPalette.surfaceRaised.withValues(alpha: 0.97),
          border: Border.all(color: KicadPalette.borderStrong),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Capped, so a long message cannot push the commands off
                // the side of a phone screen. The bar scrolls, but a button
                // that has to be found by scrolling may as well not be there.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hinting
                          ? KicadPalette.textPrimary
                          : KicadPalette.highlight,
                      fontStyle: hinting ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: KicadPalette.border,
                margin: const EdgeInsets.only(right: 2),
              ),
            ],
            for (final action in actions) _ActionButton(action: action),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final CanvasAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.danger ? KicadPalette.error : KicadPalette.textPrimary;

    return Tooltip(
      message: action.label,
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          // Comfortably above the 48dp minimum in the narrow direction, so
          // these stay usable with a thumb.
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 17, color: color),
              const SizedBox(height: 2),
              Text(
                action.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 8.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
