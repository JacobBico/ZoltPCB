import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/panel.dart';
import '../../data/repositories/settings_repository.dart';
import 'learn_library.dart';
import 'markdown_view.dart';

/// A category's icon, by the name `categories.json` gives it.
IconData learnIcon(String name) => switch (name) {
  'chip' => Icons.memory_outlined,
  'capacitor' => Icons.filter_list,
  'wave' => Icons.show_chart,
  'ground' => Icons.vertical_align_bottom,
  'speed' => Icons.speed,
  'factory' => Icons.precision_manufacturing_outlined,
  _ => Icons.menu_book_outlined,
};

/// Learn: notes from real boards, by topic.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LearnScreen());

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Opening Learn is one of the first-launch steps.
    ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.learnOpenedKey, 'yes');
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(learnLibraryProvider);
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Learn',
            subtitle: 'Notes from real boards',
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              SizedBox(
                width: 240,
                child: TextField(
                  key: const ValueKey('learn-search'),
                  decoration: const InputDecoration(
                    hintText: 'Search notes…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: switch (library) {
                AsyncData(:final value) =>
                  _query.trim().isEmpty
                      ? _categories(value)
                      : _results(value, _query.trim().toLowerCase()),
                AsyncError(:final error) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not read the notes',
                  message: '$error',
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categories(LearnLibrary library) => GridView.count(
    crossAxisCount: 3,
    padding: const EdgeInsets.all(14),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 2.2,
    children: [
      for (final category in library.categories)
        _CategoryCard(
          category: category,
          onTap: () => Navigator.of(
            context,
          ).push(LearnCategoryScreen.route(category.id)),
        ),
    ],
  );

  Widget _results(LearnLibrary library, String query) {
    final found = [
      for (final category in library.categories)
        for (final article in category.articles)
          if (article.title.toLowerCase().contains(query) ||
              article.text.toLowerCase().contains(query))
            (category, article),
    ];
    if (found.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No notes match');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        for (final (category, article) in found)
          ListTile(
            leading: Icon(learnIcon(category.icon), size: 20),
            title: Text(article.title),
            subtitle: Text(category.title),
            onTap: () => Navigator.of(context).push(
              LearnCategoryScreen.route(category.id, article: article.path),
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final LearnCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: KicadPalette.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('learn-category-${category.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    learnIcon(category.icon),
                    size: 20,
                    color: KicadPalette.highlight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                category.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category: its notes down the side, the one picked beside them.
class LearnCategoryScreen extends ConsumerStatefulWidget {
  const LearnCategoryScreen({
    super.key,
    required this.categoryId,
    this.article,
  });

  final String categoryId;

  /// The note to open on; the first when null.
  final String? article;

  static Route<void> route(String categoryId, {String? article}) =>
      MaterialPageRoute(
        builder: (_) =>
            LearnCategoryScreen(categoryId: categoryId, article: article),
      );

  @override
  ConsumerState<LearnCategoryScreen> createState() =>
      _LearnCategoryScreenState();
}

class _LearnCategoryScreenState extends ConsumerState<LearnCategoryScreen> {
  String? _open;

  void _read(LearnArticle article) {
    setState(() => _open = article.path);
    ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.lastArticleKey, article.path);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(learnLibraryProvider).value;
    final category = library?.category(widget.categoryId);
    final articles = category?.articles ?? const <LearnArticle>[];
    final open =
        articles
            .where((a) => a.path == (_open ?? widget.article))
            .firstOrNull ??
        articles.firstOrNull;
    if (open != null && _open == null) {
      // Remembered as read the moment it is shown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open == null) _read(open);
      });
    }

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: category?.title ?? 'Learn',
            subtitle: 'Learn',
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: KicadPalette.border),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final article in articles)
                          ListTile(
                            key: ValueKey('learn-article-${article.path}'),
                            dense: true,
                            selected: article.path == open?.path,
                            selectedTileColor: KicadPalette.surfaceRaised,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(article.title),
                            onTap: () => _read(article),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: open == null
                        ? const EmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'No notes here yet',
                          )
                        : MarkdownView(
                            '# ${open.title}\n\n${open.text}',
                            key: ValueKey(open.path),
                            assetDir: open.path.substring(
                              0,
                              open.path.lastIndexOf('/'),
                            ),
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
