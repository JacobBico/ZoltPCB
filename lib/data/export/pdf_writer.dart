import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Writes a one-page PDF holding a single image, filling the page.
///
/// The smallest PDF that does the job, written by hand rather than through
/// a package: six objects and a cross-reference table. The page is the
/// schematic drawn by the same painter the canvas uses, so what is shared
/// is exactly what was on the screen.
abstract final class RasterPdf {
  static Uint8List single({
    required int pixelWidth,
    required int pixelHeight,
    required Uint8List rgb,
    required double widthPt,
    required double heightPt,
    String title = '',
  }) {
    final compressed = const ZLibEncoder().encodeBytes(rgb, level: 6);
    final out = BytesBuilder(copy: false);
    final offsets = <int>[];

    void text(String s) => out.add(latin1.encode(s));
    void object(int number, void Function() body) {
      offsets.add(out.length);
      text('$number 0 obj\n');
      body();
      text('\nendobj\n');
    }

    String n(double v) => v.toStringAsFixed(2);

    // Header, with the binary marker line PDF readers look for.
    text('%PDF-1.4\n');
    out.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

    object(1, () => text('<< /Type /Catalog /Pages 2 0 R >>'));
    object(2, () => text('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
    object(
      3,
      () => text(
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 ${n(widthPt)} ${n(heightPt)}] '
        '/Resources << /XObject << /Im0 5 0 R >> >> '
        '/Contents 4 0 R >>',
      ),
    );
    final content = 'q ${n(widthPt)} 0 0 ${n(heightPt)} 0 0 cm /Im0 Do Q';
    object(4, () {
      text('<< /Length ${content.length} >>\nstream\n$content\nendstream');
    });
    object(5, () {
      text(
        '<< /Type /XObject /Subtype /Image /Width $pixelWidth '
        '/Height $pixelHeight /ColorSpace /DeviceRGB /BitsPerComponent 8 '
        '/Filter /FlateDecode /Length ${compressed.length} >>\nstream\n',
      );
      out.add(compressed);
      text('\nendstream');
    });
    object(6, () {
      text('<< /Title (${_escape(title)}) /Producer (HintPCB) >>');
    });

    final xref = out.length;
    text('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      text('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    text(
      'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R /Info 6 0 R >>\n'
      'startxref\n$xref\n%%EOF\n',
    );
    return out.toBytes();
  }

  /// A PDF string literal: brackets and backslashes escaped, and anything
  /// outside Latin-1 dropped rather than mangling the file.
  static String _escape(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
}
