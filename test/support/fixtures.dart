import 'package:aegis/data/probe/device_signals.dart';

/// Device readings used across the tests.
///
/// Two baselines, one per platform, each representing a phone with nothing
/// wrong. Every test starts from one of these and breaks exactly the thing it
/// is about, so a failure names its own cause.
abstract final class Fixtures {
  static final DateTime now = DateTime.utc(2026, 8, 12);

  static DeviceSignals androidHealthy({
    bool hasScreenLock = true,
    bool hasBiometricsEnrolled = true,
    bool isCompromised = false,
    bool debuggerAttached = false,
    bool screenBeingCaptured = false,
    bool vpnActive = false,
    bool? onOpenWifi = false,
    DateTime? securityPatch,
    bool? storageEncrypted = true,
    bool? developerOptionsEnabled = false,
    bool? usbDebuggingEnabled = false,
    int? screenLockTimeoutMs = 30000,
    bool? lockScreenShowsSensitiveContent = false,
    bool? playProtectEnabled = true,
    bool? encryptedDnsEnabled = true,
    bool? cloudBackupEnabled = true,
    List<PrivilegedService> accessibilityServices = const [],
    List<PrivilegedService> notificationListeners = const [],
    List<PrivilegedService> deviceAdmins = const [],
    int osMajor = 16,
  }) =>
      DeviceSignals(
        platform: 'android',
        osVersion: '$osMajor',
        osMajor: osMajor,
        deviceModel: 'Test Device',
        hasScreenLock: hasScreenLock,
        hasBiometricsEnrolled: hasBiometricsEnrolled,
        biometryLabel: 'Fingerprint',
        isCompromised: isCompromised,
        compromiseReasons: isCompromised ? const ['A superuser binary.'] : const [],
        isEmulator: false,
        debuggerAttached: debuggerAttached,
        screenBeingCaptured: screenBeingCaptured,
        vpnActive: vpnActive,
        onOpenWifi: onOpenWifi,
        securityPatch: securityPatch ?? now.subtract(const Duration(days: 20)),
        latestKnownOsMajor: 16,
        minimumSupportedOsMajor: 13,
        storageEncrypted: storageEncrypted,
        developerOptionsEnabled: developerOptionsEnabled,
        usbDebuggingEnabled: usbDebuggingEnabled,
        screenLockTimeoutMs: screenLockTimeoutMs,
        lockScreenShowsSensitiveContent: lockScreenShowsSensitiveContent,
        playProtectEnabled: playProtectEnabled,
        encryptedDnsEnabled: encryptedDnsEnabled,
        cloudBackupEnabled: cloudBackupEnabled,
        accessibilityServices: accessibilityServices,
        notificationListeners: notificationListeners,
        deviceAdmins: deviceAdmins,
      );

  static DeviceSignals iosHealthy({
    bool hasScreenLock = true,
    bool hasBiometricsEnrolled = true,
    bool isCompromised = false,
    bool screenBeingCaptured = false,
    bool debuggerAttached = false,
    int osMajor = 26,
  }) =>
      DeviceSignals(
        platform: 'ios',
        osVersion: '$osMajor.0',
        osMajor: osMajor,
        deviceModel: 'iPhone',
        hasScreenLock: hasScreenLock,
        hasBiometricsEnrolled: hasBiometricsEnrolled,
        biometryLabel: 'Face ID',
        isCompromised: isCompromised,
        compromiseReasons: isCompromised ? const ['Cydia is installed.'] : const [],
        isEmulator: false,
        debuggerAttached: debuggerAttached,
        screenBeingCaptured: screenBeingCaptured,
        vpnActive: false,
        onOpenWifi: null,
        securityPatch: null,
        latestKnownOsMajor: 26,
        minimumSupportedOsMajor: 18,
      );

  static const PrivilegedService passwordManager = PrivilegedService(
    package: 'com.example.passwords',
    label: 'Password Manager',
  );

  static const PrivilegedService unknownApp = PrivilegedService(
    package: 'com.unknown.thing',
    label: 'Free Battery Saver',
  );
}
