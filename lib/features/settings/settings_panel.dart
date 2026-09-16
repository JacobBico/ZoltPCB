import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/panel.dart';
import '../../rendering/resistor_zigzag.dart';

/// How the app looks: the colour theme, and how symbols are drawn.
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHeading('Theme'),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Three across on a landscape phone. Each card is a
                    // miniature of the canvas in that palette, because a
                    // row of swatches says nothing about how a schematic
                    // will actually look.
                    const spacing = 10.0;
                    final columns = constraints.maxWidth > 700 ? 3 : 2;
                    final width =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final palette in AppPalettes.all)
                          SizedBox(
                            width: width,
                            child: _PaletteCard(
                              palette: palette,
                              resistorStyle: appearance.resistorStyle,
                              selected: palette == appearance.palette,
                              onTap: () => notifier.setPalette(palette),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHeading('Resistor symbol'),
                const SizedBox(height: 4),
                Text(
                  'How resistors are drawn on the schematic. Only the '
                  'drawing changes — exported files keep KiCad\'s symbol.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final style in ResistorStyle.values) ...[
                      Expanded(
                        child: _ResistorCard(
                          style: style,
                          selected: style == appearance.resistorStyle,
                          onTap: () => notifier.setResistorStyle(style),
                        ),
                      ),
                      if (style != ResistorStyle.values.last)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelHeading('Board editor'),
                const SizedBox(height: 4),
                Text(
                  'Two ways of laying out a board. Both edit the same '
                  'design, so you can switch at any point without losing '
                  'anything.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final style in BoardEditorStyle.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EditorCard(
                      style: style,
                      selected: style == appearance.boardEditor,
                      onTap: () => notifier.setBoardEditor(style),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two board editors, as a card you can pick.
class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final BoardEditorStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? KicadPalette.current.selectedContainer : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? KicadPalette.highlight : KicadPalette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected
                  ? KicadPalette.highlight
                  : KicadPalette.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.label, style: theme.textTheme.bodyLarge),
                  Text(
                    style.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KicadPalette.textSecondary,
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
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.resistorStyle,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final ResistorStyle resistorStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? KicadPalette.highlight
                  : KicadPalette.borderStrong,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 86,
                child: CustomPaint(
                  painter: _MiniSchematicPainter(palette, resistorStyle),
                ),
              ),
              Container(
                color: palette.surface,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          palette.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: palette.highlight,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      palette.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A resistor and a capacitor wired together, in a given palette.
class _MiniSchematicPainter extends CustomPainter {
  const _MiniSchematicPainter(this.palette, this.style);

  final AppPalette palette;
  final ResistorStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.canvas);

    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (var x = 8.0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 8.0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final outline = Paint()
      ..color = palette.symbolOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final wire = Paint()
      ..color = palette.wire
      ..strokeWidth = 2;

    final midY = size.height / 2;
    final rLeft = Offset(size.width * 0.18, midY);
    final rRight = Offset(size.width * 0.48, midY);
    final body = Rect.fromPoints(
      rLeft + const Offset(0, -7),
      rRight + const Offset(0, 7),
    );

    // The resistor, drawn the way the user has chosen.
    if (style == ResistorStyle.ansi) {
      canvas.drawPath(resistorZigzag(rLeft, rRight), outline);
    } else {
      canvas
        ..drawRect(body, Paint()..color = palette.symbolFill)
        ..drawRect(body, outline);
    }

    // A capacitor to its right.
    final capX = size.width * 0.72;
    canvas
      ..drawLine(
        Offset(capX - 4, midY - 14),
        Offset(capX - 4, midY + 14),
        outline,
      )
      ..drawLine(
        Offset(capX + 4, midY - 14),
        Offset(capX + 4, midY + 14),
        outline,
      );

    // Wires, one of them selected so the highlight colour is on show.
    canvas
      ..drawLine(Offset(4, midY), rLeft, wire)
      ..drawLine(rRight, Offset(capX - 4, midY), wire)
      ..drawLine(
        Offset(capX + 4, midY),
        Offset(size.width - 4, midY),
        Paint()
          ..color = palette.highlight
          ..strokeWidth = 3,
      );

    for (final dot in [rLeft, rRight]) {
      canvas.drawCircle(dot, 2.5, Paint()..color = palette.pin);
    }
  }

  @override
  bool shouldRepaint(_MiniSchematicPainter old) =>
      old.palette != palette || old.style != style;
}

class _ResistorCard extends StatelessWidget {
  const _ResistorCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final ResistorStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KicadPalette.canvas,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? KicadPalette.highlight
                  : KicadPalette.borderStrong,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 36,
                child: CustomPaint(painter: _ResistorPainter(style)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(style.label, style: theme.textTheme.bodyMedium),
                    Text(
                      style.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: KicadPalette.highlight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResistorPainter extends CustomPainter {
  _ResistorPainter(this.style) : palette = KicadPalette.current;

  final ResistorStyle style;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final paint = Paint()
      ..color = palette.symbolOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final left = Offset(size.width * 0.2, midY);
    final right = Offset(size.width * 0.8, midY);
    canvas
      ..drawLine(Offset(0, midY), left, paint)
      ..drawLine(right, Offset(size.width, midY), paint);

    if (style == ResistorStyle.ansi) {
      canvas.drawPath(resistorZigzag(left, right), paint);
    } else {
      canvas.drawRect(
        Rect.fromPoints(left + const Offset(0, -8), right + const Offset(0, 8)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ResistorPainter old) =>
      old.style != style || old.palette != palette;
}
