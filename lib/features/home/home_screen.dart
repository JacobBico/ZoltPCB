import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/section_rail.dart';
import '../components/component_browser_panel.dart';
import '../libraries/libraries_panel.dart';
import '../pinout/pinout_panel.dart';
import '../projects/projects_panel.dart';
import '../settings/settings_panel.dart';

enum HomeSection {
  projects('Projects'),
  components('Components'),
  pinout('Pinout'),
  libraries('Libraries'),
  settings('Settings');

  const HomeSection(this.label);

  final String label;
}

/// Which section the home screen is showing.
///
/// A provider rather than plain widget state because panels send each other
/// there: the component browser hands a chip to the pinout explorer, which
/// only works if it can change the section it does not own.
final homeSectionProvider = NotifierProvider<HomeSectionNotifier, HomeSection>(
  HomeSectionNotifier.new,
);

class HomeSectionNotifier extends Notifier<HomeSection> {
  @override
  HomeSection build() => HomeSection.projects;

  void show(HomeSection section) => state = section;
}

/// The app's home: projects, the component browser, and imported libraries.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _railOpen = false;

  HomeSection get _section => ref.watch(homeSectionProvider);

  void _show(HomeSection section) =>
      ref.read(homeSectionProvider.notifier).show(section);

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectSummariesProvider).value?.length;
    final libraries = ref.watch(symbolLibrariesProvider).value;

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'HintPCB',
            subtitle: _section.label,
            leading: IconButton(
              icon: Icon(_railOpen ? Icons.close : Icons.menu, size: 20),
              tooltip: _railOpen ? 'Close sections' : 'Sections',
              onPressed: () => setState(() => _railOpen = !_railOpen),
            ),
            actions: [_action()],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: OverlayRail(
                open: _railOpen,
                selectedIndex: _section.index,
                onDismiss: () => setState(() => _railOpen = false),
                onSelect: (index) {
                  _show(HomeSection.values[index]);
                  setState(() => _railOpen = false);
                },
                entries: [
                  RailEntry(
                    label: 'Projects',
                    icon: Icons.developer_board_outlined,
                    badge: projects == null ? null : '$projects',
                  ),
                  const RailEntry(
                    label: 'Components',
                    icon: Icons.memory_outlined,
                  ),
                  const RailEntry(
                    label: 'Pinout',
                    icon: Icons.settings_input_component_outlined,
                  ),
                  RailEntry(
                    label: 'Libraries',
                    icon: Icons.folder_open_outlined,
                    badge: libraries == null ? null : '${libraries.length}',
                  ),
                  const RailEntry(
                    label: 'Settings',
                    icon: Icons.palette_outlined,
                  ),
                ],
                child: _panel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action() => switch (_section) {
    HomeSection.projects => FilledButton.icon(
      onPressed: () => ProjectsPanel.create(context, ref),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('NEW PROJECT'),
    ),
    HomeSection.components => OutlinedButton.icon(
      onPressed: () => _show(HomeSection.libraries),
      icon: const Icon(Icons.folder_open_outlined, size: 16),
      label: const Text('LIBRARIES'),
    ),
    HomeSection.pinout => const SizedBox.shrink(),
    // The libraries panel has its own import button, which follows the
    // Symbols/Footprints tab. One up here would always import symbols —
    // wrong half the time, and a second button for the same job.
    HomeSection.libraries || HomeSection.settings => const SizedBox.shrink(),
  };

  Widget _panel() => switch (_section) {
    HomeSection.projects => const ProjectsPanel(),
    HomeSection.components => const ComponentBrowserPanel(),
    HomeSection.pinout => const PinoutPanel(),
    HomeSection.libraries => const LibrariesPanel(),
    HomeSection.settings => const SettingsPanel(),
  };
}
