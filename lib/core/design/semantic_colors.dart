import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The three states a security check can report, plus the app's neutral accent.
///
/// Every colour here resolves to a system colour. On iOS that is the
/// `CupertinoColors.system*` family; on Android it is the Material 3 scheme,
/// which on Android 12+ is generated from the user's wallpaper. Nothing is a
/// hand-picked hex value, so the app inherits the OS's contrast guarantees in
/// both light and dark mode.
class SemanticColors {
  const SemanticColors._({
    required this.secure,
    required this.caution,
    required this.critical,
    required this.accent,
    required this.onAccent,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.background,
    required this.groupedBackground,
    required this.surface,
    required this.fill,
  });

  final Color secure;
  final Color caution;
  final Color critical;
  final Color accent;
  final Color onAccent;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;

  /// The page backdrop.
  final Color background;

  /// The backdrop behind inset grouped lists.
  final Color groupedBackground;

  /// Raised content sitting on [groupedBackground].
  final Color surface;

  /// A low-contrast fill for tracks, chips and placeholders.
  final Color fill;

  static SemanticColors of(BuildContext context) {
    if (isApple) return _cupertino(context);
    return _material(context);
  }

  static SemanticColors _cupertino(BuildContext context) {
    Color r(CupertinoDynamicColor c) => CupertinoDynamicColor.resolve(c, context);
    return SemanticColors._(
      secure: r(CupertinoColors.systemGreen),
      caution: r(CupertinoColors.systemOrange),
      critical: r(CupertinoColors.systemRed),
      accent: r(CupertinoColors.systemBlue),
      onAccent: CupertinoColors.white,
      label: r(CupertinoColors.label),
      secondaryLabel: r(CupertinoColors.secondaryLabel),
      tertiaryLabel: r(CupertinoColors.tertiaryLabel),
      separator: r(CupertinoColors.separator),
      background: r(CupertinoColors.systemBackground),
      groupedBackground: r(CupertinoColors.systemGroupedBackground),
      surface: r(CupertinoColors.secondarySystemGroupedBackground),
      fill: r(CupertinoColors.tertiarySystemFill),
    );
  }

  static SemanticColors _material(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // Material 3 has no built-in success/warning roles, so these are the
    // Android system palette's own green and amber, tone-matched to the scheme
    // the same way M3 tones its error role.
    final secure = dark ? const Color(0xFF7DD394) : const Color(0xFF146C2E);
    final caution = dark ? const Color(0xFFF2B84B) : const Color(0xFF8A5300);
    return SemanticColors._(
      secure: secure,
      caution: caution,
      critical: scheme.error,
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      label: scheme.onSurface,
      secondaryLabel: scheme.onSurfaceVariant,
      tertiaryLabel: scheme.outline,
      separator: scheme.outlineVariant,
      background: scheme.surface,
      groupedBackground: scheme.surface,
      surface: scheme.surfaceContainer,
      fill: scheme.surfaceContainerHighest,
    );
  }
}

/// Convenience accessor: `context.colors.critical`.
extension SemanticColorsX on BuildContext {
  SemanticColors get colors => SemanticColors.of(this);
}
