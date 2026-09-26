import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/providers.dart';
import '../../core/theme/kicad_palette.dart';
import '../../core/util/formatting.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/models.dart';
import '../learn/learn_library.dart';
import '../learn/learn_screen.dart';
import '../libraries/kicad_download_dialog.dart';
import '../project/backup_actions.dart';
import '../project/project_screen.dart';
import '../projects/projects_panel.dart';
import 'whats_new.dart';

const _gold = Color(0xFFE8C66A);

/// The first thing the app shows: where you left off, the way into all
/// your projects and into Learn, and what changed in this version.
///
/// A new install sees a short getting-started list where the recent
/// projects will be, until it has libraries and a project of its own.
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key, required this.onShowProjects});

  /// Goes to the full project list.
  final VoidCallback onShowProjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectSummariesProvider).value;
    final libraries = ref.watch(symbolLibrariesProvider).value;
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    if (projects == null || libraries == null) return const SizedBox.shrink();

    final steps = [
      libraries.isNotEmpty,
      projects.isNotEmpty,
      settings[SettingsRepository.learnOpenedKey] != null,
    ];
    final gettingStarted =
        (libraries.isEmpty || projects.isEmpty) &&
        settings[SettingsRepository.checklistDismissedKey] == null;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 14,
                  child: gettingStarted
                      ? _GettingStarted(done: steps)
                      : _Recent(
                          projects: projects,
                          onShowProjects: onShowProjects,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 10,
                        child: _ProjectsTile(
                          count: projects.length,
                          onOpen: onShowProjects,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 12,
                        child: _LearnTile(
                          lastArticle:
                              settings[SettingsRepository.lastArticleKey],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const _WhatsNewStrip(),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: KicadPalette.textSecondary,
              letterSpacing: 1.4,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// The projects touched most recently, each reopening where it was left.
class _Recent extends ConsumerWidget {
  const _Recent({required this.projects, required this.onShowProjects});

  final List<ProjectSummary> projects;
  final VoidCallback onShowProjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = projects.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          'CONTINUE WHERE YOU LEFT OFF',
          trailing: TextButton(
            onPressed: onShowProjects,
            child: const Text('All projects'),
          ),
        ),
        const SizedBox(height: 6),
        if (recent.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No projects yet. Start one with NEW PROJECT.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textSecondary,
                ),
              ),
            ),
          ),
        for (final project in recent) ...[
          _RecentCard(summary: project),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RecentCard extends ConsumerWidget {
  const _RecentCard({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(projectSettingsProvider(summary.id)).value ?? const {};
    final section = ProjectScreen.lastSectionIn(settings);
    final onBoard = section == ProjectSection.board;
    return Material(
      color: KicadPalette.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: ValueKey('recent-${summary.id}'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.of(
          context,
        ).push(ProjectScreen.route(summary.id, initialSection: section)),
        child: Container(
          height: 60,
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: KicadPalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 46,
                decoration: BoxDecoration(
                  color: KicadPalette.canvas,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: KicadPalette.border),
                ),
                child: Icon(
                  onBoard
                      ? Icons.developer_board_outlined
                      : Icons.schema_outlined,
                  color: onBoard ? _gold : KicadPalette.wire,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      summary.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.label} · '
                      '${plural(summary.partCount, 'part')} · '
                      '${formatTimestamp(summary.project.modifiedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KicadPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: KicadPalette.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first steps, until a new install has what it needs.
class _GettingStarted extends ConsumerWidget {
  const _GettingStarted({required this.done});

  /// Libraries, a first project, and a look at Learn.
  final List<bool> done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = done.where((d) => d).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          'GET STARTED — $count OF ${done.length} DONE',
          trailing: TextButton(
            key: const ValueKey('checklist-dismiss'),
            onPressed: () => ref
                .read(settingsRepositoryProvider)
                .set(SettingsRepository.checklistDismissedKey, 'yes'),
            child: const Text('Hide'),
          ),
        ),
        const SizedBox(height: 6),
        _Step(
          done: done[0],
          title: "Download KiCad's libraries",
          detail: 'The parts and footprints everything is built from',
          action: 'DOWNLOAD',
          onTap: () => showKicadLibraryDownload(context),
        ),
        const SizedBox(height: 8),
        _Step(
          done: done[1],
          title: 'Create your first project',
          detail: 'Or open one you made in desktop KiCad',
          action: 'START',
          onTap: () => ProjectsPanel.create(context, ref),
        ),
        const SizedBox(height: 8),
        _Step(
          done: done[2],
          title: 'Have a look at Learn',
          detail: 'Notes on decoupling, routing, grounding and more',
          action: 'OPEN',
          onTap: () => Navigator.of(context).push(LearnScreen.route()),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KicadPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KicadPalette.border),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? KicadPalette.highlight : KicadPalette.textDisabled,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: done ? KicadPalette.textSecondary : null,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KicadPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ],
      ),
    );
  }
}

/// A tile: an icon block, a title and a line under it, then its extras.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.icon,
    required this.iconColor,
    required this.iconGround,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.children,
  });

  final Key tileKey;
  final IconData icon;
  final Color iconColor;
  final Color iconGround;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: KicadPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KicadPalette.border),
      ),
      // Shrunk a little rather than cut off on a phone too short for it.
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: tileKey,
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconGround,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 22, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: KicadPalette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: KicadPalette.textDisabled,
                      ),
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    onPressed: onTap,
  );
}

class _ProjectsTile extends ConsumerWidget {
  const _ProjectsTile({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Tile(
    tileKey: const ValueKey('home-projects'),
    icon: Icons.folder_outlined,
    iconColor: KicadPalette.highlight,
    iconGround: const Color(0xFF2A1D40),
    title: 'Projects',
    subtitle: count == 0
        ? 'None yet — start one, or bring one in'
        : plural(count, 'project'),
    onOpen: onOpen,
    children: [
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        children: [
          _Chip('Restore backup', () => restoreBackup(context, ref)),
          _Chip('Import KiCad', () => ProjectsPanel.openKicad(context, ref)),
        ],
      ),
    ],
  );
}

class _LearnTile extends ConsumerWidget {
  const _LearnTile({required this.lastArticle});

  /// The note read last, if any.
  final String? lastArticle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(learnLibraryProvider).value;
    final theme = Theme.of(context);
    final last = library?.article(lastArticle);
    final first = library?.categories
        .where((c) => c.articles.isNotEmpty)
        .firstOrNull
        ?.articles
        .first;
    final suggested = last ?? first;
    // On a phone too short for all of it, the chips stay and the line
    // about what to read next goes.
    return LayoutBuilder(
      builder: (context, constraints) => _tile(
        context,
        library,
        theme,
        constraints.maxHeight >= 124 ? suggested : null,
        last != null,
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    LearnLibrary? library,
    ThemeData theme,
    LearnArticle? suggested,
    bool continuing,
  ) {
    return _Tile(
      tileKey: const ValueKey('home-learn'),
      icon: Icons.menu_book_outlined,
      iconColor: _gold,
      iconGround: const Color(0xFF33291A),
      title: 'Learn',
      subtitle: library == null
          ? 'Notes from real boards'
          : '${plural(library.categories.length, 'topic')}, from real boards',
      onOpen: () => Navigator.of(context).push(LearnScreen.route()),
      children: [
        if (suggested != null)
          InkWell(
            key: const ValueKey('home-learn-continue'),
            onTap: () => Navigator.of(context).push(
              LearnCategoryScreen.route(
                suggested.categoryId,
                article: suggested.path,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: continuing ? 'CONTINUE  ' : 'START WITH  ',
                      style: const TextStyle(color: _gold, letterSpacing: 0.8),
                    ),
                    TextSpan(text: suggested.title),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (library != null)
          Wrap(
            spacing: 6,
            children: [
              for (final category in library.categories.take(3))
                _Chip(
                  category.short,
                  () => Navigator.of(
                    context,
                  ).push(LearnCategoryScreen.route(category.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// This version's news, a tap from the full list.
class _WhatsNewStrip extends ConsumerWidget {
  const _WhatsNewStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(changelogProvider).value?.firstOrNull;
    if (current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: KicadPalette.surface,
      child: InkWell(
        key: const ValueKey('home-whats-new'),
        onTap: () => Navigator.of(context).push(WhatsNewScreen.route()),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: KicadPalette.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'NEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: KicadPalette.surface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "What's new in ${current.version}"
                  '${current.title.isEmpty ? '' : ' — ${current.title}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                'v${current.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KicadPalette.textDisabled,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: KicadPalette.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
