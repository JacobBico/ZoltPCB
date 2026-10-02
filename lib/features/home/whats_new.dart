import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kicad_palette.dart';
import '../../core/widgets/app_top_bar.dart';
import '../learn/markdown_view.dart';

/// One version's changes, from `assets/changelog.md`.
class Release {
  const Release(this.version, this.title, this.notes);

  final String version;
  final String title;

  /// The Markdown under the version's heading.
  final String notes;

  /// Every `## <version> — <title>` section of [markdown], newest first as
  /// written.
  static List<Release> parse(String markdown) {
    final releases = <Release>[];
    String? version;
    var title = '';
    var notes = StringBuffer();
    void close() {
      if (version != null) {
        releases.add(Release(version, title, notes.toString().trim()));
      }
    }

    for (final line in markdown.split('\n')) {
      final heading = RegExp(
        r'^##\s+(\S+)\s*(?:[—-]\s*(.*))?$',
      ).firstMatch(line);
      if (heading != null) {
        close();
        version = heading[1];
        title = heading[2]?.trim() ?? '';
        notes = StringBuffer();
      } else if (version != null) {
        notes.writeln(line);
      }
    }
    close();
    return releases;
  }
}

final changelogProvider = FutureProvider<List<Release>>(
  (ref) async =>
      Release.parse(await rootBundle.loadString('assets/changelog.md')),
);

/// What changed: this version, then the ones before it.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const WhatsNewScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(changelogProvider).value ?? const <Release>[];
    final current = releases.firstOrNull;
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: "What's new",
            subtitle: current == null ? null : 'You have ${current.version}',
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (current != null)
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 13,
                        child: _ReleaseCard(release: current, current: true),
                      ),
                      if (releases.length > 1) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 10,
                          child: ListView.separated(
                            itemCount: releases.length - 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => SizedBox(
                              height: 150,
                              child: _ReleaseCard(release: releases[i + 1]),
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(flex: 10),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Nothing to show yet.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, this.current = false});

  final Release release;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: current ? KicadPalette.surfaceRaised : KicadPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? const Color(0xFFE8C66A) : KicadPalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    release.title.isEmpty
                        ? release.version
                        : '${release.version} — ${release.title}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (current)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8C66A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'THIS VERSION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: KicadPalette.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: MarkdownView(
              release.notes,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            ),
          ),
        ],
      ),
    );
  }
}
