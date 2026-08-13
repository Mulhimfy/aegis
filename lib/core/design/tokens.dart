import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether the running platform uses Apple's human interface conventions.
///
/// Resolved once at startup so every adaptive widget agrees, and overridable in
/// tests via [debugPlatformOverride].
bool get isApple {
  final override = debugPlatformOverride;
  if (override != null) return override == TargetPlatform.iOS;
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isMacOS;
}

/// Test-only override for [isApple].
@visibleForTesting
TargetPlatform? debugPlatformOverride;

/// Spacing scale. Values are the ones both HIG and Material lay out on, kept in
/// one place so nothing in the app invents its own gap.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  /// Standard leading edge for content on each platform.
  static double get gutter => isApple ? 16 : 16;
}

/// Motion durations and curves. Apple leans on a spring-like ease, Material 3
/// on its emphasized set; using the wrong one is the fastest way to make a
/// native app feel foreign.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration dial = Duration(milliseconds: 1100);

  static Curve get emphasized => isApple
      ? Curves.easeOutCubic
      : const Cubic(0.2, 0, 0, 1); // M3 emphasized decelerate

  static Curve get standardCurve =>
      isApple ? Curves.easeInOut : const Cubic(0.2, 0, 0, 1);
}

/// Corner radii, taken from each platform's own shape scale rather than picked
/// by eye.
abstract final class Corners {
  /// Grouped-list container radius: 10pt on iOS, M3 medium (12dp) on Android.
  static double get container => isApple ? 10 : 12;

  /// Small controls: iOS uses a continuous 8pt; M3 small is 8dp.
  static double get control => 8;

  /// Full-height pill, used only where the platform itself uses one.
  static const double pill = 999;
}
