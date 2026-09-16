import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/erc/erc.dart';

/// What the schematic check found, errors first.
Future<void> showErcSheet(
  BuildContext context, {
  required List<ErcViolation> violations,
  required void Function(ErcViolation violation) onShow,
  required VoidCallback onRenumber,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: KicadPalette.surface,
  isScrollControlled: true,
  builder: (context) =>
      _ErcSheet(violations: violations, onShow: onShow, onRenumber: onRenumber),
);

class _ErcSheet extends StatelessWidget {
  const _ErcSheet({
    required this.violations,
    required this.onShow,
    required this.onRenumber,
  });

  final List<ErcViolation> violations;
  final void Function(ErcViolation violation) onShow;
  final VoidCallback onRenumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = violations.where((v) => v.isError).length;
    final warnings = violations.length - errors;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Icon(
                    violations.isEmpty
                        ? Icons.check_circle_outline
                        : errors == 0
                        ? Icons.warning_amber_outlined
                        : Icons.error_outline,
                    size: 18,
                    color: violations.isEmpty
                        ? KicadPalette.success
                        : errors == 0
                        ? KicadPalette.warning
                        : KicadPalette.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      violations.isEmpty
                          ? 'The schematic checks out'
                          : '$errors ${errors == 1 ? 'error' : 'errors'}, '
                                '$warnings ${warnings == 1 ? 'warning' : 'warnings'}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.format_list_numbered, size: 16),
                    label: const Text('RENUMBER'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRenumber();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: KicadPalette.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: violations.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: KicadPalette.border),
                itemBuilder: (context, index) {
                  final violation = violations[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      violation.isError
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      size: 18,
                      color: violation.isError
                          ? KicadPalette.error
                          : KicadPalette.warning,
                    ),
                    title: Text(violation.message),
                    subtitle: Text(violation.rule.label),
                    trailing: violation.partId == null
                        ? null
                        : const Icon(Icons.center_focus_strong, size: 18),
                    onTap: violation.partId == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onShow(violation);
                          },
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
