import 'package:flutter/material.dart';

import '../../core/theme/kicad_palette.dart';
import '../../domain/pcb/pcb.dart';
import 'board_painter.dart';

/// Asks which copper layer to work on, for a board with more than two.
///
/// Two layers need no question — the button just turns the board over —
/// but with six, stepping through them one tap at a time to reach In4 is a
/// chore, and the layer's role (plane or signal) is worth seeing before
/// routing onto it.
Future<CopperLayer?> showLayerPicker(
  BuildContext context, {
  required Board board,
  required CopperLayer active,
}) {
  final stackup = board.stackup;
  return showModalBottomSheet<CopperLayer>(
    context: context,
    backgroundColor: KicadPalette.surface,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.9,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            for (final copper in stackup.copper)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: BoardPainter.colorFor(copper.layer),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                title: Text(
                  '${copper.layer.label}  ·  ${copper.layer.layer.token}',
                ),
                subtitle: Text(
                  '${copper.role.label} · ${copper.weight.label}',
                  style: TextStyle(color: KicadPalette.textSecondary),
                ),
                trailing: copper.layer == active
                    ? Icon(Icons.check, color: KicadPalette.highlight)
                    : null,
                onTap: () => Navigator.of(sheet).pop(copper.layer),
              ),
          ],
        ),
      ),
    ),
  );
}
