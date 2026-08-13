import 'package:flutter/foundation.dart';

/// A named third-party service the OS has granted elevated reach to.
@immutable
class PrivilegedService {
  const PrivilegedService({required this.package, required this.label});

  final String package;
  final String label;

  factory PrivilegedService.fromMap(Map<Object?, Object?> map) => PrivilegedService(
        package: (map['package'] as String?) ?? 'unknown',
        label: (map['label'] as String?) ?? (map['package'] as String?) ?? 'Unknown app',
      );

  Map<String, Object?> toJson() => {'package': package, 'label': label};

  factory PrivilegedService.fromJson(Map<String, Object?> json) =>
      PrivilegedService.fromMap(json);

  @override
  bool operator ==(Object other) =>
      other is PrivilegedService && other.package == package;

  @override
  int get hashCode => package.hashCode;
}

/// The raw, unjudged truth about the device, read from the OS.
///
/// Everything here is a fact the platform reports. All interpretation lives in
/// the check catalog, so the probe layer never has an opinion and the scoring
/// layer never talks to the OS.
@immutable
class DeviceSignals {
  const DeviceSignals({
    required this.platform,
    required this.osVersion,
    required this.osMajor,
    required this.deviceModel,
    required this.hasScreenLock,
    required this.hasBiometricsEnrolled,
    required this.biometryLabel,
    required this.isCompromised,
    required this.compromiseReasons,
    required this.isEmulator,
    required this.debuggerAttached,
    required this.screenBeingCaptured,
    required this.vpnActive,
    required this.onOpenWifi,
    required this.securityPatch,
    required this.latestKnownOsMajor,
    required this.minimumSupportedOsMajor,
    this.storageEncrypted,
    this.developerOptionsEnabled,
    this.usbDebuggingEnabled,
    this.screenLockTimeoutMs,
    this.lockScreenShowsSensitiveContent,
    this.playProtectEnabled,
    this.encryptedDnsEnabled,
    this.cloudBackupEnabled,
    this.accessibilityServices = const [],
    this.notificationListeners = const [],
    this.deviceAdmins = const [],
    this.probeErrors = const {},
  });

  /// `'android'` or `'ios'`.
  final String platform;
  final String osVersion;
  final int osMajor;
  final String deviceModel;

  /// A passcode, PIN, pattern or password is set.
  final bool hasScreenLock;
  final bool hasBiometricsEnrolled;

  /// `'Face ID'`, `'Touch ID'`, `'Fingerprint'`, or empty when none.
  final String biometryLabel;

  /// Rooted (Android) or jailbroken (iOS).
  final bool isCompromised;
  final List<String> compromiseReasons;

  final bool isEmulator;
  final bool debuggerAttached;

  /// The screen is mirrored or recorded right now.
  final bool screenBeingCaptured;

  final bool vpnActive;

  /// Currently joined to a Wi-Fi network with no link-layer encryption.
  /// Null when the platform will not disclose it.
  final bool? onOpenWifi;

  /// Android security patch level. Null on iOS, which ships patches inside the
  /// OS version itself.
  final DateTime? securityPatch;

  /// Newest major OS release the app knows about, used to judge OS currency
  /// without a network call.
  final int latestKnownOsMajor;

  /// Oldest major release still receiving security fixes from the vendor.
  final int minimumSupportedOsMajor;

  // ---- Android-only signals. Null on iOS, where the sandbox forbids them. ----

  final bool? storageEncrypted;
  final bool? developerOptionsEnabled;
  final bool? usbDebuggingEnabled;
  final int? screenLockTimeoutMs;
  final bool? lockScreenShowsSensitiveContent;
  final bool? playProtectEnabled;
  final bool? encryptedDnsEnabled;
  final bool? cloudBackupEnabled;

  /// Apps allowed to read and act on everything on screen. The single most
  /// abused permission on Android.
  final List<PrivilegedService> accessibilityServices;

  /// Apps allowed to read every notification, including one-time codes.
  final List<PrivilegedService> notificationListeners;

  /// Apps holding device administrator rights.
  final List<PrivilegedService> deviceAdmins;

  /// Signals the native side could not read, keyed by signal name. Checks that
  /// depend on an unreadable signal are excluded from the score rather than
  /// guessed at.
  final Map<String, String> probeErrors;

  bool get isAndroid => platform == 'android';
  bool get isIOS => platform == 'ios';

  /// Days since the Android security patch level, or null when unknown.
  int? patchAgeInDays(DateTime now) {
    final patch = securityPatch;
    if (patch == null) return null;
    return now.difference(patch).inDays;
  }

  factory DeviceSignals.fromMap(Map<Object?, Object?> map) {
    List<PrivilegedService> services(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(PrivilegedService.fromMap)
          .toList(growable: false);
    }

    DateTime? patch() {
      final raw = map['securityPatchEpochMs'];
      if (raw is! int || raw <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DeviceSignals(
      platform: (map['platform'] as String?) ?? 'unknown',
      osVersion: (map['osVersion'] as String?) ?? '',
      osMajor: (map['osMajor'] as int?) ?? 0,
      deviceModel: (map['deviceModel'] as String?) ?? '',
      hasScreenLock: (map['hasScreenLock'] as bool?) ?? false,
      hasBiometricsEnrolled: (map['hasBiometricsEnrolled'] as bool?) ?? false,
      biometryLabel: (map['biometryLabel'] as String?) ?? '',
      isCompromised: (map['isCompromised'] as bool?) ?? false,
      compromiseReasons:
          (map['compromiseReasons'] as List?)?.whereType<String>().toList() ??
              const [],
      isEmulator: (map['isEmulator'] as bool?) ?? false,
      debuggerAttached: (map['debuggerAttached'] as bool?) ?? false,
      screenBeingCaptured: (map['screenBeingCaptured'] as bool?) ?? false,
      vpnActive: (map['vpnActive'] as bool?) ?? false,
      onOpenWifi: map['onOpenWifi'] as bool?,
      securityPatch: patch(),
      latestKnownOsMajor: (map['latestKnownOsMajor'] as int?) ?? 0,
      minimumSupportedOsMajor: (map['minimumSupportedOsMajor'] as int?) ?? 0,
      storageEncrypted: map['storageEncrypted'] as bool?,
      developerOptionsEnabled: map['developerOptionsEnabled'] as bool?,
      usbDebuggingEnabled: map['usbDebuggingEnabled'] as bool?,
      screenLockTimeoutMs: map['screenLockTimeoutMs'] as int?,
      lockScreenShowsSensitiveContent:
          map['lockScreenShowsSensitiveContent'] as bool?,
      playProtectEnabled: map['playProtectEnabled'] as bool?,
      encryptedDnsEnabled: map['encryptedDnsEnabled'] as bool?,
      cloudBackupEnabled: map['cloudBackupEnabled'] as bool?,
      accessibilityServices: services('accessibilityServices'),
      notificationListeners: services('notificationListeners'),
      deviceAdmins: services('deviceAdmins'),
      probeErrors: (map['probeErrors'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }
}
