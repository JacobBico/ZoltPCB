import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/repositories/settings_repository.dart';
import '../features/home/home_screen.dart';
import '../features/home/welcome.dart';
import 'appearance.dart';
import 'providers.dart';

class ZoltApp extends ConsumerStatefulWidget {
  const ZoltApp({super.key});

  @override
  ConsumerState<ZoltApp> createState() => _ZoltAppState();
}

class _ZoltAppState extends ConsumerState<ZoltApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  /// A hello, once, the first time the app is opened. Someone who already
  /// has designs is not new, whatever the settings say: an update that
  /// brings the welcome in does not greet them as a stranger.
  Future<void> _welcome() async {
    final settings = ref.read(settingsRepositoryProvider);
    if (await settings.get(SettingsRepository.welcomedKey) != null) return;
    // Marked first, so it is never shown twice, even if the app is closed
    // with the welcome still up.
    await settings.set(SettingsRepository.welcomedKey, 'yes');
    final projects = await ref.read(projectSummariesProvider.future);
    final context = _navigator.currentContext;
    if (projects.isNotEmpty || context == null || !context.mounted) return;
    await WelcomeDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);

    ref.listen(appearanceProvider, (previous, next) {
      if (previous?.palette == next.palette) return;
      _matchSystemBars(next);
      // Most of the app paints with the palette directly rather than
      // through `Theme.of`, so a new theme alone would leave half the
      // screen in the old colours. Marking every element dirty rebuilds the
      // lot on the next frame, keeping all state — the screen you are on,
      // the zoom, the half-drawn route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element element) {
          element.markNeedsBuild();
          element.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    });

    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Zolt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(appearance.palette),
      home: const HomeScreen(),
    );
  }

  static void _matchSystemBars(Appearance appearance) {
    final palette = appearance.palette;
    final icons = palette.isDark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness: icons,
      ),
    );
  }
}
