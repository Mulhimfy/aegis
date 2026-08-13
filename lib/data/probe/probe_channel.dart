import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/fix_action.dart';
import 'device_signals.dart';

/// Thrown when the OS could not be read at all.
class ProbeFailure implements Exception {
  const ProbeFailure(this.message);
  final String message;
  @override
  String toString() => 'ProbeFailure: $message';
}

/// The one bridge between Dart and the operating system.
///
/// Two operations only: read the device's security state, and open a named
/// settings screen. Keeping the surface this small is what makes the native
/// side auditable.
abstract interface class DeviceProbe {
  Future<DeviceSignals> read();

  /// Opens a system settings screen. Returns false when no screen on this
  /// device matches, in which case the caller falls back to written steps.
  Future<bool> openSettings(SettingsTarget target);
}

class ProbeChannel implements DeviceProbe {
  ProbeChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.aegis/probe');

  final MethodChannel _channel;

  @override
  Future<DeviceSignals> read() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('read');
      if (result == null) {
        throw const ProbeFailure('The device returned nothing.');
      }
      return DeviceSignals.fromMap(result);
    } on PlatformException catch (e) {
      throw ProbeFailure(e.message ?? 'The device could not be read.');
    } on MissingPluginException {
      throw const ProbeFailure(
        'Security checks are not available on this platform.',
      );
    }
  }

  @override
  Future<bool> openSettings(SettingsTarget target) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openSettings',
        {'target': target.name},
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// A probe that returns a fixed reading, so the UI can be exercised for every
/// score band without needing a misconfigured phone.
@visibleForTesting
class FakeProbe implements DeviceProbe {
  FakeProbe(this.signals, {this.settingsOpen = true});

  final DeviceSignals signals;
  final bool settingsOpen;
  final List<SettingsTarget> opened = [];

  @override
  Future<DeviceSignals> read() async => signals;

  @override
  Future<bool> openSettings(SettingsTarget target) async {
    opened.add(target);
    return settingsOpen;
  }
}
