import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Writes a PDF of images, one filling each page.
///
/// The smallest PDF that does the job, written by hand rather than through
/// a package: six objects and a cross-reference table. The page is the
/// schematic drawn by the same painter the canvas uses, so what is shared
/// is exactly what was on the screen.
/// One page of a [RasterPdf]: an image, and the page size it fills.
class RasterPage {
  const RasterPage({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.rgb,
    required this.widthPt,
    required this.heightPt,
  });

  final int pixelWidth;
  final int pixelHeight;
  final Uint8List rgb;
  final double widthPt;
  final double heightPt;
}

abstract final class RasterPdf {
  static Uint8List single({
    required int pixelWidth,
    required int pixelHeight,
    required Uint8List rgb,
    required double widthPt,
    required double heightPt,
    String title = '',
  }) => pages([
    RasterPage(
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      rgb: rgb,
      widthPt: widthPt,
      heightPt: heightPt,
    ),
  ], title: title);

  /// A page per image, in order: one per sheet of a schematic.
  static Uint8List pages(List<RasterPage> pages, {String title = ''}) {
    final out = BytesBuilder(copy: false);
    final offsets = <int, int>{};

    void text(String s) => out.add(latin1.encode(s));
    void object(int number, void Function() body) {
      offsets[number] = out.length;
      text('$number 0 obj\n');
      body();
      text('\nendobj\n');
    }

    String n(double v) => v.toStringAsFixed(2);

    // Header, with the binary marker line PDF readers look for.
    text('%PDF-1.4\n');
    out.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

    // 1 catalog, 2 page tree, 3 info; then three objects per page: the
    // page, its content, its image.
    int pageObject(int i) => 4 + i * 3;
    object(1, () => text('<< /Type /Catalog /Pages 2 0 R >>'));
    object(2, () {
      final kids = [
        for (var i = 0; i < pages.length; i++) '${pageObject(i)} 0 R',
      ].join(' ');
      text('<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>');
    });
    object(3, () {
      text('<< /Title (${_escape(title)}) /Producer (Zolt) >>');
    });
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final number = pageObject(i);
      object(
        number,
        () => text(
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 ${n(page.widthPt)} ${n(page.heightPt)}] '
          '/Resources << /XObject << /Im0 ${number + 2} 0 R >> >> '
          '/Contents ${number + 1} 0 R >>',
        ),
      );
      final content =
          'q ${n(page.widthPt)} 0 0 ${n(page.heightPt)} 0 0 cm /Im0 Do Q';
      object(number + 1, () {
        text('<< /Length ${content.length} >>\nstream\n$content\nendstream');
      });
      final compressed = const ZLibEncoder().encodeBytes(page.rgb, level: 6);
      object(number + 2, () {
        text(
          '<< /Type /XObject /Subtype /Image /Width ${page.pixelWidth} '
          '/Height ${page.pixelHeight} /ColorSpace /DeviceRGB '
          '/BitsPerComponent 8 /Filter /FlateDecode '
          '/Length ${compressed.length} >>\nstream\n',
        );
        out.add(compressed);
        text('\nendstream');
      });
    }

    final count = offsets.length;
    final xref = out.length;
    text('xref\n0 ${count + 1}\n0000000000 65535 f \n');
    for (var number = 1; number <= count; number++) {
      text('${offsets[number].toString().padLeft(10, '0')} 00000 n \n');
    }
    text(
      'trailer\n<< /Size ${count + 1} /Root 1 0 R /Info 3 0 R >>\n'
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
