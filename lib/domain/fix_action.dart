import 'package:flutter/foundation.dart';

/// A named destination in the operating system's own settings.
///
/// Dart never constructs raw intents or URLs. It names a destination and the
/// native side resolves it, with a fallback chain, so a manufacturer skin that
/// lacks one screen still lands the user somewhere useful.
enum SettingsTarget {
  security,
  screenLock,
  biometrics,
  lockScreenNotifications,
  displayTimeout,
  developerOptions,
  systemUpdate,
  accessibility,
  notificationAccess,
  deviceAdmins,
  privateDns,
  wifi,
  vpn,
  unknownAppSources,
  backup,
  playProtect,
  findMyDevice,
  appSettings,
  appPermissions,
}

/// How the user resolves a failing check.
@immutable
sealed class FixAction {
  const FixAction();
}

/// Open a system settings screen directly. Android resolves [target] to an
/// intent; iOS opens the app's own settings page where [target] refers to it,
/// and otherwise relies on [steps] alone.
@immutable
class OpenSettings extends FixAction {
  const OpenSettings(this.target, {required this.steps, this.buttonLabel});

  final SettingsTarget target;

  /// The exact breadcrumb through the Settings app, shown alongside the
  /// button so the user can still get there if the deep link cannot resolve.
  final List<String> steps;

  final String? buttonLabel;
}

/// No deep link exists. Show precise steps the user follows themselves.
@immutable
class GuidedSteps extends FixAction {
  const GuidedSteps({required this.steps, this.learnMoreUrl});

  final List<String> steps;
  final String? learnMoreUrl;
}

/// Nothing to open. The user reviews something inside the app itself.
@immutable
class ReviewInApp extends FixAction {
  const ReviewInApp(this.prompt);
  final String prompt;
}
