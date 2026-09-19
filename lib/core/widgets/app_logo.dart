import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/kicad_palette.dart';

/// The app's logo, as drawn on the home screen's bar.
///
/// The artwork cuts the holes in its letters by painting them the colour
/// of the background it was drawn on. That colour is swapped for [ground]
/// as it loads, so the holes are the bar behind it in every theme rather
/// than dark patches on a lighter one.
class AppLogo extends StatefulWidget {
  const AppLogo({super.key, this.height = 30, this.ground});

  static const asset = 'assets/brand/logo.svg';

  /// The colour the artwork itself uses for the holes in its letters.
  static const artworkGround = '#0c0812';

  final double height;

  /// What the logo sits on; the bar's surface when null.
  final Color? ground;

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> {
  /// The artwork once read; kept so returning home draws it at once.
  static String? _loaded;
  late final Future<String> _source = _loaded != null
      ? Future.value(_loaded)
      : rootBundle.loadString(AppLogo.asset).then((s) => _loaded = s);

  @override
  Widget build(BuildContext context) {
    final ground = widget.ground ?? KicadPalette.surface;
    return SizedBox(
      height: widget.height,
      child: FutureBuilder<String>(
        future: _source,
        initialData: _loaded,
        builder: (context, snapshot) {
          final svg = snapshot.data;
          if (svg == null) return SizedBox(height: widget.height);
          return SvgPicture.string(
            svg.replaceAll(AppLogo.artworkGround, _hex(ground)),
            height: widget.height,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          );
        },
      ),
    );
  }

  static String _hex(Color c) {
    String channel(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}';
  }
}
