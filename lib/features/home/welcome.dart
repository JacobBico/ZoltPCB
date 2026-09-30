import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/app_logo.dart';

/// The hello a new user sees once, the first time the app opens: what Zolt
/// is, and where to go from here. The same three steps the Home page's
/// checklist keeps track of, so the two agree.
class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const WelcomeDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    return AlertDialog(
      key: const ValueKey('welcome-dialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      title: Row(
        children: [
          const AppLogo(height: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome to Zolt!',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, and thanks for trying Zolt. It lets you design circuit '
                'boards on your phone: draw the schematic, lay out the '
                'board, and export files ready to send to a board maker. It '
                'reads and writes KiCad, so you can carry on at your desk.',
                style: body,
              ),
              const SizedBox(height: 14),
              Text(
                'Where to start',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              const _Step(
                icon: Icons.download_outlined,
                text:
                    "Download KiCad's libraries, for the symbols and "
                    'footprints of thousands of parts.',
              ),
              const _Step(
                icon: Icons.add_circle_outline,
                text:
                    'Create your first project, or open a KiCad project '
                    'you already have.',
              ),
              const _Step(
                icon: Icons.school_outlined,
                text:
                    'New to electronics? Learn has short notes, a few '
                    'minutes each.',
              ),
              const SizedBox(height: 8),
              Text(
                "The checklist on the Home page walks you through these. "
                'Have fun building!',
                style: body?.copyWith(color: KicadPalette.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('welcome-start'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("LET'S GO"),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
