import 'package:flutter/material.dart';

import '../theme/kicad_palette.dart';

/// The app's fixed 48dp header.
///
/// A custom bar rather than [AppBar]: on a landscape phone every vertical
/// pixel counts, and the layout here is a tight row of identifiers rather
/// than a title with actions.
///
/// Placed as the first child of the screen's body, not in
/// [Scaffold.appBar]. Android 15 draws apps edge-to-edge, and only a real
/// [AppBar] inflates itself to clear the status bar and display cutout;
/// a custom [PreferredSizeWidget] in that slot ends up underneath them.
///
/// The bar takes the system insets itself rather than sitting inside a
/// [SafeArea], so its background reaches the physical edges of the screen
/// while its contents stay clear of the status bar and of a cutout along a
/// side edge. Screens wrap the rest of their body in `SafeArea(top: false)`.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.logo,
    this.actions = const [],
  });

  final String title;

  /// Drawn in place of [title] when given — the app's own mark on the home
  /// screen. [title] still names the bar for screen readers.
  final Widget? logo;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Height of the bar itself, excluding any system inset above it.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KicadPalette.surface,
        border: Border(bottom: BorderSide(color: KicadPalette.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: insets.top,
          left: insets.left,
          right: insets.right,
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              if (leading != null) leading! else const SizedBox(width: 14),
              // Expanded, not Flexible-plus-Spacer: two flex-1 children
              // would split the free space evenly and strand the leftover to
              // the right of the actions, pulling them away from the corner.
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: logo != null
                          ? Semantics(
                              label: title,
                              header: true,
                              child: ExcludeSemantics(child: logo!),
                            )
                          : Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 1,
                        height: 16,
                        color: KicadPalette.borderStrong,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KicadPalette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
