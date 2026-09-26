import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A topic in Learn: a folder of notes under `assets/learn/<id>/`.
class LearnCategory {
  const LearnCategory({
    required this.id,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.articles,
    String? short,
  }) : short = short ?? title;

  final String id;
  final String title;

  /// A word or two, for a chip.
  final String short;
  final String blurb;

  /// A name from `categories.json`, turned into an icon by the screen.
  final String icon;

  /// In file-name order, so `01-…` comes before `02-…`.
  final List<LearnArticle> articles;
}

/// One note: a Markdown file, titled by its first `# heading`.
class LearnArticle {
  const LearnArticle({
    required this.path,
    required this.categoryId,
    required this.title,
    required this.text,
  });

  /// The asset path, which also serves as the note's id.
  final String path;
  final String categoryId;
  final String title;

  /// The Markdown, with the title line taken off.
  final String text;
}

/// Everything in Learn.
class LearnLibrary {
  const LearnLibrary(this.categories);

  final List<LearnCategory> categories;

  LearnArticle? article(String? path) {
    for (final category in categories) {
      for (final article in category.articles) {
        if (article.path == path) return article;
      }
    }
    return null;
  }

  LearnCategory? category(String id) =>
      categories.where((c) => c.id == id).firstOrNull;

  int get articleCount =>
      categories.fold(0, (sum, c) => sum + c.articles.length);

  /// Reads the categories and every note in them from the app's assets.
  ///
  /// A note is any `.md` file in a category's folder: writing one is
  /// writing a text file, with nothing to register.
  static Future<LearnLibrary> load(AssetBundle bundle) async {
    final listed =
        jsonDecode(await bundle.loadString('assets/learn/categories.json'))
            as List<Object?>;
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = manifest.listAssets();

    final categories = <LearnCategory>[];
    for (final entry in listed.cast<Map<String, Object?>>()) {
      final id = entry['id']! as String;
      final paths = [
        for (final path in assets)
          if (path.startsWith('assets/learn/$id/') && path.endsWith('.md'))
            path,
      ]..sort();
      final articles = <LearnArticle>[];
      for (final path in paths) {
        final text = await bundle.loadString(path);
        articles.add(parse(path, id, text));
      }
      categories.add(
        LearnCategory(
          id: id,
          title: entry['title']! as String,
          blurb: entry['blurb'] as String? ?? '',
          icon: entry['icon'] as String? ?? '',
          short: entry['short'] as String?,
          articles: articles,
        ),
      );
    }
    return LearnLibrary(categories);
  }

  /// A note from its Markdown: the first `# heading` is its title.
  static LearnArticle parse(String path, String categoryId, String text) {
    final lines = const LineSplitter().convert(text);
    final at = lines.indexWhere((l) => l.startsWith('# '));
    final title = at < 0
        ? path.split('/').last.replaceFirst(RegExp(r'\.md$'), '')
        : lines[at].substring(2).trim();
    return LearnArticle(
      path: path,
      categoryId: categoryId,
      title: title,
      text: at < 0
          ? text
          : [...lines.take(at), ...lines.skip(at + 1)].join('\n').trim(),
    );
  }
}

final learnLibraryProvider = FutureProvider<LearnLibrary>(
  (ref) => LearnLibrary.load(rootBundle),
);
