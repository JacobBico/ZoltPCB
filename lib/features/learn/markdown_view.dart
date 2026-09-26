import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/kicad_palette.dart';

/// Markdown, drawn in the app's own style.
///
/// The small part of Markdown notes are written in: headings, paragraphs,
/// bullet and numbered lists, quotes (drawn as a tip), fenced code,
/// pictures on a line of their own (`![caption](images/plates.svg)`, found
/// beside the note in [assetDir]), and **bold**, *italic* and `code` within
/// a line. Anything else shows as the
/// text it is, which is never wrong, only plain.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.markdown, {super.key, this.padding, this.assetDir});

  final String markdown;
  final EdgeInsetsGeometry? padding;

  /// The asset folder a picture's path starts from: the note's own. Null
  /// shows a picture as its caption alone.
  final String? assetDir;

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks(markdown, assetDir);
    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => blocks[index].build(context),
    );
  }

  static List<_Block> _blocks(String markdown, String? assetDir) {
    final lines = markdown.replaceAll('\r', '').split('\n');
    final blocks = <_Block>[];
    var paragraph = <String>[];
    void flush() {
      if (paragraph.isNotEmpty) {
        blocks.add(_Paragraph(paragraph.join(' ')));
        paragraph = [];
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      if (trimmed.startsWith('```')) {
        flush();
        final code = <String>[];
        for (i++; i < lines.length && !lines[i].trim().startsWith('```'); i++) {
          code.add(lines[i]);
        }
        blocks.add(_Code(code.join('\n')));
        continue;
      }
      final picture = RegExp(r'^!\[(.*)\]\((.+)\)$').firstMatch(trimmed);
      if (picture != null) {
        flush();
        blocks.add(
          _Picture(
            caption: picture[1]!,
            asset: assetDir == null ? null : '$assetDir/${picture[2]!}',
          ),
        );
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flush();
        blocks.add(_Heading(heading[2]!, heading[1]!.length));
        continue;
      }
      if (trimmed == '---' || trimmed == '***') {
        flush();
        blocks.add(const _Rule());
        continue;
      }
      if (trimmed.startsWith('>')) {
        flush();
        final quote = <String>[];
        for (; i < lines.length && lines[i].trim().startsWith('>'); i++) {
          quote.add(lines[i].trim().substring(1).trim());
        }
        i--;
        blocks.add(_Quote(quote.join(' ')));
        continue;
      }
      final bullet = RegExp(r'^([-*]|\d+\.)\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flush();
        final numbered = bullet[1]!.endsWith('.');
        final items = <String>[];
        for (; i < lines.length; i++) {
          final item = RegExp(
            r'^([-*]|\d+\.)\s+(.*)$',
          ).firstMatch(lines[i].trim());
          if (item != null) {
            items.add(item[2]!);
          } else if (lines[i].trim().isNotEmpty &&
              lines[i].startsWith(RegExp(r'\s{2,}'))) {
            // A wrapped continuation of the item before.
            items[items.length - 1] = '${items.last} ${lines[i].trim()}';
          } else {
            break;
          }
        }
        i--;
        blocks.add(_List(items, numbered: numbered));
        continue;
      }
      paragraph.add(trimmed);
    }
    flush();
    return blocks;
  }

  /// A line's **bold**, *italic* and `code` as styled spans.
  static TextSpan inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    var at = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      if (match[1] != null) {
        spans.add(
          TextSpan(
            text: match[1],
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: KicadPalette.textPrimary,
            ),
          ),
        );
      } else if (match[2] != null) {
        spans.add(
          TextSpan(
            text: match[2],
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match[3],
            style: TextStyle(
              color: KicadPalette.highlight,
              backgroundColor: KicadPalette.surfaceRaised,
            ),
          ),
        );
      }
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: base, children: spans);
  }
}

sealed class _Block {
  const _Block();

  Widget build(BuildContext context);

  TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        height: 1.55,
        color: KicadPalette.textPrimary.withValues(alpha: 0.9),
      );
}

class _Paragraph extends _Block {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text.rich(MarkdownView.inline(text, body(context)));
}

class _Heading extends _Block {
  const _Heading(this.text, this.level);

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = switch (level) {
      1 => theme.headlineSmall,
      2 => theme.titleMedium,
      _ => theme.titleSmall,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 4 : 8),
      child: Text.rich(MarkdownView.inline(text, style!)),
    );
  }
}

class _List extends _Block {
  const _List(this.items, {required this.numbered});

  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  numbered ? '${i + 1}.' : '•',
                  style: body(context).copyWith(color: KicadPalette.highlight),
                ),
              ),
              Expanded(
                child: Text.rich(MarkdownView.inline(items[i], body(context))),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Quote extends _Block {
  const _Quote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: KicadPalette.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFE8C66A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFE8C66A)),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(MarkdownView.inline(text, body(context)))),
      ],
    ),
  );
}

class _Code extends _Block {
  const _Code(this.code);

  final String code;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: KicadPalette.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: KicadPalette.border),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        code,
        style: body(context).copyWith(color: KicadPalette.highlight),
      ),
    ),
  );
}

class _Picture extends _Block {
  const _Picture({required this.caption, required this.asset});

  final String caption;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return Column(
      children: [
        if (asset != null)
          // A width of its own, measured: the picture's height follows from
          // it, and an unbounded one would make that endless too.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.clamp(0.0, 560.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: asset.endsWith('.svg')
                    ? SvgPicture.asset(
                        asset,
                        width: width,
                        semanticsLabel: caption,
                        placeholderBuilder: (_) =>
                            SizedBox(width: width, height: width * 0.5),
                      )
                    : Image.asset(asset, width: width),
              );
            },
          ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: body(context).copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: KicadPalette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Rule extends _Block {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 8, color: KicadPalette.border);
}
