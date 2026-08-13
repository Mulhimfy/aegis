import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Themes for both platforms.
///
/// Deliberately thin. No `fontFamily` is ever set, so text renders in SF Pro on
/// iOS and the device's own Roboto/Noto stack on Android, at the sizes and
/// weights each platform already ships. No custom shapes are imposed on
/// buttons or app bars either: the defaults are the system defaults.
abstract final class AppTheme {
  static CupertinoThemeData cupertino(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: CupertinoColors.systemBlue,
      applyThemeToAll: true,
    );
  }

  static ThemeData material(Brightness brightness, ColorScheme? dynamicScheme) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A6EA5),
          brightness: brightness,
        );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // Let M3 own every component shape; only the page background is set, so
      // grouped content reads as one continuous surface.
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        scrolledUnderElevation: 3,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: null,
        iconColor: scheme.onSurfaceVariant,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
