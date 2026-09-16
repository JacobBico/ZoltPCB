import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';

/// Shows what the design rule check found.
///
/// Errors first, then warnings, then the reassurance that there is nothing
/// else. A list rather than markers on the canvas: a phone screen has no
/// room to explain a violation where it happened, and the useful question
/// is "what is left to fix", which is a list.
Future<void> showDrcSheet(
  BuildContext context, {
  required List<DrcViolation> violations,
  required void Function(DrcViolation violation) onShow,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: KicadPalette.surface,
    isScrollControlled: true,
    builder: (context) => _DrcSheet(violations: violations, onShow: onShow),
  );
}

class _DrcSheet extends StatelessWidget {
  const _DrcSheet({required this.violations, required this.onShow});

  final List<DrcViolation> violations;
  final void Function(DrcViolation violation) onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = violations.where((v) => v.isError).toList();
    final warnings = violations.where((v) => !v.isError).toList();
    final ordered = [...errors, ...warnings];

    return SafeArea(
      child: ConstrainedBox(
        // Landscape: a sheet taller than this covers the board it is
        // talking about.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Icon(
                    violations.isEmpty
                        ? Icons.check_circle_outline
                        : errors.isEmpty
                        ? Icons.warning_amber_outlined
                        : Icons.error_outline,
                    size: 18,
                    color: violations.isEmpty
                        ? KicadPalette.success
                        : errors.isEmpty
                        ? KicadPalette.warning
                        : KicadPalette.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      violations.isEmpty
                          ? 'Nothing to fix'
                          : '${errors.length} '
                                '${errors.length == 1 ? 'error' : 'errors'}, '
                                '${warnings.length} '
                                '${warnings.length == 1 ? 'warning' : 'warnings'}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (violations.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Every net is routed, every footprint is placed, and no '
                  'copper is closer than the clearance rule. Run KiCad\'s '
                  'own check on the desktop before you order it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: KicadPalette.border),
                  itemBuilder: (context, index) {
                    final violation = ordered[index];
                    return ListTile(
                      dense: true,
                      // The whole row goes to the problem. Knowing that
                      // something is 0.05 mm too close is half the answer;
                      // the other half is which 0.05 mm, on a board that may
                      // have a hundred tracks on it.
                      onTap: () {
                        onShow(violation);
                        Navigator.of(context).pop();
                      },
                      leading: Icon(
                        violation.isError
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                        size: 16,
                        color: violation.isError
                            ? KicadPalette.error
                            : KicadPalette.warning,
                      ),
                      title: Text(
                        violation.rule.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        violation.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KicadPalette.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.center_focus_strong_outlined,
                        size: 18,
                        color: KicadPalette.textSecondary,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
