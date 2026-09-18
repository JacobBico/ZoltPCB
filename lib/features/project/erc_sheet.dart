import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/erc/erc.dart';

/// What the schematic check found, errors first.
Future<void> showErcSheet(
  BuildContext context, {
  required List<ErcViolation> violations,
  required void Function(ErcViolation violation) onShow,
  required VoidCallback onRenumber,
  VoidCallback? onRules,
  int ignoredRules = 0,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: KicadPalette.surface,
  isScrollControlled: true,
  builder: (context) => _ErcSheet(
    violations: violations,
    onShow: onShow,
    onRenumber: onRenumber,
    onRules: onRules,
    ignoredRules: ignoredRules,
  ),
);

class _ErcSheet extends StatelessWidget {
  const _ErcSheet({
    required this.violations,
    required this.onShow,
    required this.onRenumber,
    this.onRules,
    this.ignoredRules = 0,
  });

  final List<ErcViolation> violations;
  final void Function(ErcViolation violation) onShow;
  final VoidCallback onRenumber;

  /// Opens the project's choice of which checks matter.
  final VoidCallback? onRules;

  /// How many checks the project has switched off, so a clean result
  /// says what it did not look at.
  final int ignoredRules;

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
                      (violations.isEmpty
                              ? 'The schematic checks out'
                              : '$errors ${errors == 1 ? 'error' : 'errors'}, '
                                    '$warnings ${warnings == 1 ? 'warning' : 'warnings'}') +
                          (ignoredRules == 0
                              ? ''
                              : ' · $ignoredRules '
                                    '${ignoredRules == 1 ? 'check' : 'checks'} off'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (onRules != null)
                    TextButton.icon(
                      key: const ValueKey('erc-rules'),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('RULES'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRules!();
                      },
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

/// Chooses, per check, whether it is an error, a warning or off, for one
/// project. Returns the new settings, or null if cancelled.
Future<ErcSettings?> showErcRulesDialog(
  BuildContext context, {
  required ErcSettings settings,
}) => showDialog<ErcSettings>(
  context: context,
  builder: (_) => _ErcRulesDialog(settings: settings),
);

class _ErcRulesDialog extends StatefulWidget {
  const _ErcRulesDialog({required this.settings});

  final ErcSettings settings;

  @override
  State<_ErcRulesDialog> createState() => _ErcRulesDialogState();
}

class _ErcRulesDialogState extends State<_ErcRulesDialog> {
  late ErcSettings _settings = widget.settings;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Which checks matter'),
    contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rule in ErcRule.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(rule.label)),
                    SegmentedButton<ErcLevel>(
                      key: ValueKey('erc-level-${rule.name}'),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        for (final level in ErcLevel.values)
                          ButtonSegment(
                            value: level,
                            label: Text(
                              level.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      selected: {_settings.levelOf(rule)},
                      onSelectionChanged: (value) => setState(
                        () =>
                            _settings = _settings.withLevel(rule, value.first),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() => _settings = ErcSettings.defaults),
        child: const Text('DEFAULTS'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_settings),
        child: const Text('SAVE'),
      ),
    ],
  );
}
