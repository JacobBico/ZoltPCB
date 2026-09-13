import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/home/home_screen.dart';
import 'appearance.dart';

class HintPcbApp extends ConsumerStatefulWidget {
  const HintPcbApp({super.key});

  @override
  ConsumerState<HintPcbApp> createState() => _HintPcbAppState();
}

class _HintPcbAppState extends ConsumerState<HintPcbApp> {
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
      title: 'HintPCB',
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
