import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/models/models.dart';

/// Values collected by [showProjectEditorDialog].
class ProjectEditorResult {
  const ProjectEditorResult({
    required this.name,
    required this.description,
    required this.paper,
    required this.company,
    required this.revision,
  });

  final String name;
  final String description;
  final PaperSize paper;
  final String company;
  final String revision;
}

/// Creates or edits a project's properties. Returns null if cancelled.
Future<ProjectEditorResult?> showProjectEditorDialog(
  BuildContext context, {
  Project? project,
}) {
  return showDialog<ProjectEditorResult>(
    context: context,
    builder: (context) => _ProjectEditorDialog(project: project),
  );
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({this.project});

  final Project? project;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _company;
  late final TextEditingController _revision;
  late PaperSize _paper;

  bool get _isNew => widget.project == null;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _name = TextEditingController(text: project?.name ?? '');
    _description = TextEditingController(text: project?.description ?? '');
    _company = TextEditingController(text: project?.company ?? '');
    _revision = TextEditingController(text: project?.revision ?? '');
    _paper = project?.paper ?? PaperSize.a4;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _company.dispose();
    _revision.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProjectEditorResult(
        name: _name.text.trim(),
        description: _description.text.trim(),
        paper: _paper,
        company: _company.text.trim(),
        revision: _revision.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Landscape phones are short: the dialog lays its fields out in two
    // columns and scrolls rather than growing tall.
    return AlertDialog(
      title: Text(_isNew ? 'New project' : 'Project properties'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'A project needs a name'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'optional',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PaperSize>(
                        initialValue: _paper,
                        // Without isExpanded the dropdown sizes itself to its
                        // widest entry and overflows a narrow column.
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sheet size',
                        ),
                        dropdownColor: KicadPalette.surfaceRaised,
                        selectedItemBuilder: (context) => [
                          for (final size in PaperSize.values)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                size.kicadName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        items: [
                          for (final size in PaperSize.values)
                            DropdownMenuItem(
                              value: size,
                              child: Text(
                                '${size.kicadName}  '
                                '${size.widthMm.toStringAsFixed(0)}×'
                                '${size.heightMm.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _paper = value ?? _paper),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _company,
                        decoration: const InputDecoration(
                          labelText: 'Company',
                          hintText: 'optional',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: TextFormField(
                        controller: _revision,
                        decoration: const InputDecoration(labelText: 'Rev'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isNew ? 'CREATE' : 'SAVE'),
        ),
      ],
    );
  }
}
