import 'package:flutter/material.dart';

import 'kicad_palette.dart';

/// Typography for the app.
///
/// Everything is monospace. Reference designators, pin numbers and net names
/// are all identifiers where column alignment and unambiguous glyphs matter
/// more than prose readability — and it is what the desktop tool looks like.
/// The platform monospace face is used rather than a bundled font so the app
/// ships without extra assets.
abstract final class AppTypography {
  static const family = 'monospace';
  static const fallback = <String>['monospace', 'Roboto Mono', 'Courier'];

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 26, height: 1.2, letterSpacing: 0.5),
    headlineMedium: TextStyle(fontSize: 20, height: 1.2, letterSpacing: 0.4),
    headlineSmall: TextStyle(fontSize: 17, height: 1.25, letterSpacing: 0.3),
    titleMedium: TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(fontSize: 13, height: 1.3, letterSpacing: 0.2),
    bodyLarge: TextStyle(fontSize: 14, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, height: 1.4),
    bodySmall: TextStyle(fontSize: 11.5, height: 1.35),
    labelLarge: TextStyle(fontSize: 13, letterSpacing: 0.6),
    labelMedium: TextStyle(fontSize: 11, letterSpacing: 0.8),
    labelSmall: TextStyle(fontSize: 10, letterSpacing: 1.2),
  );
}

abstract final class AppTheme {
  /// Minimum edge of a tappable target. Pins and components are fingers-only
  /// controls, so nothing interactive is allowed below this.
  static const double minTouchTarget = 48;

  /// The theme for the palette in force.
  static ThemeData dark() => build(KicadPalette.current);

  /// A complete theme for [p]: Material's colour scheme and every component
  /// theme below it, so a palette change reaches controls the app never
  /// styles by hand.
  static ThemeData build(AppPalette p) {
    final scheme = (p.isDark ? ColorScheme.dark : ColorScheme.light)(
      primary: p.wire,
      onPrimary: p.onAccent,
      secondary: p.symbolOutline,
      onSecondary: p.onAccent,
      // Material 3 draws every *selected* state — a segmented button, a
      // filter chip — in the secondary container. Left to derive from the
      // symbol red above, "selected" looked exactly like "something is
      // wrong", which on a screen of pass/fail checks is the one colour it
      // must not borrow.
      secondaryContainer: p.selectedContainer,
      onSecondaryContainer: p.wire,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceRaised,
      outline: p.border,
      outlineVariant: p.borderStrong,
      error: p.error,
      onError: p.onAccent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      fontFamily: AppTypography.family,
      fontFamilyFallback: AppTypography.fallback,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      textTheme: AppTypography.textTheme.apply(
        fontFamily: AppTypography.family,
        fontFamilyFallback: AppTypography.fallback,
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      extensions: [SchematicColors.of(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 48,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.selectedContainer,
        checkmarkColor: p.wire,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        labelStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontFamilyFallback: AppTypography.fallback,
          fontSize: 12,
          color: p.textPrimary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.textSecondary,
          selectedBackgroundColor: p.selectedContainer,
          selectedForegroundColor: p.wire,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: p.borderStrong),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: _fieldBorder(p.border),
        enabledBorder: _fieldBorder(p.border),
        focusedBorder: _fieldBorder(p.wire),
        errorBorder: _fieldBorder(p.error),
        focusedErrorBorder: _fieldBorder(p.error),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textDisabled),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.wire,
          foregroundColor: const Color(0xFF08201E),
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontFamilyFallback: AppTypography.fallback,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(color: p.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontFamilyFallback: AppTypography.fallback,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textSecondary,
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontFamilyFallback: AppTypography.fallback,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textSecondary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        minVerticalPadding: 10,
        dense: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontFamilyFallback: AppTypography.fallback,
          color: p.textPrimary,
          fontSize: 13,
        ),
        actionTextColor: p.wire,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: p.border),
        ),
      ),
      tooltipTheme: const TooltipThemeData(preferBelow: false),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.borderStrong),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(3),
    borderSide: BorderSide(color: color),
  );
}
