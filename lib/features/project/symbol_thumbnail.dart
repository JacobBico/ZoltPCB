import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../domain/geometry/placement.dart';
import '../../domain/symbols/symbols.dart';
import '../../rendering/renderable_pin.dart';
import '../../rendering/schematic_viewport.dart';
import '../../rendering/symbol_renderer.dart';

/// A library symbol drawn small, for picking it by how it looks.
///
/// Loaded once when the widget is first built — the repository keeps the
/// definitions it has read, so a grid of these costs one file read each the
/// first time and nothing after.
class SymbolThumbnail extends ConsumerStatefulWidget {
  const SymbolThumbnail({super.key, required this.libId, this.size = 44});

  final String libId;
  final double size;

  @override
  ConsumerState<SymbolThumbnail> createState() => _SymbolThumbnailState();
}

class _SymbolThumbnailState extends ConsumerState<SymbolThumbnail> {
  late Future<SymbolDefinition?> _symbol = _load();

  Future<SymbolDefinition?> _load() =>
      ref.read(symbolLibraryRepositoryProvider).loadSymbol(widget.libId);

  @override
  void didUpdateWidget(SymbolThumbnail old) {
    super.didUpdateWidget(old);
    if (old.libId != widget.libId) _symbol = _load();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: FutureBuilder<SymbolDefinition?>(
      future: _symbol,
      builder: (context, snapshot) {
        final symbol = snapshot.data;
        if (symbol == null) return const SizedBox.shrink();
        return CustomPaint(
          painter: _ThumbnailPainter(
            symbol,
            SchematicColors.of(KicadPalette.current),
          ),
        );
      },
    ),
  );
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.symbol, this.colors);

  final SymbolDefinition symbol;
  final SchematicColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const origin = Placement(x: 0, y: 0);
    final local = symbolBounds(symbol, 1);
    if (local == Rect.zero || size.isEmpty) return;
    final sheet = Rect.fromPoints(
      origin.apply(local.left, local.top),
      origin.apply(local.right, local.bottom),
    ).inflate(0.6);
    final ppm = math.min(size.width / sheet.width, size.height / sheet.height);
    final viewport = SchematicViewport(
      pixelsPerMm: ppm,
      origin: Offset(
        size.width / 2 - sheet.center.dx * ppm,
        size.height / 2 - sheet.center.dy * ppm,
      ),
    );

    final renderer = SymbolRenderer(
      viewport: viewport,
      colors: colors,
      showPinNames: false,
      showPinNumbers: false,
    );
    renderer.paintGraphics(canvas, symbol: symbol, unit: 1, placement: origin);
    renderer.paintPins(
      canvas,
      pins: [
        for (final pin in symbol.pinsForUnit(1))
          RenderablePin.fromSymbol(pin, unit: 1),
      ],
      placement: origin,
      pinNamesHidden: true,
      pinNumbersHidden: true,
      pinNamesOffset: symbol.pinNamesOffset,
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) =>
      old.symbol != symbol || old.colors != colors;
}
