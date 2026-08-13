import 'package:flutter/foundation.dart';

import '../core/util/formatters.dart';
import '../data/probe/device_signals.dart';
import 'attestation.dart';
import 'check.dart';
import 'finding.dart';
import 'fix_action.dart';
import 'severity.dart';

/// Everything the evaluator needs to judge one device at one moment.
@immutable
class EvalContext {
  const EvalContext({
    required this.signals,
    required this.now,
    this.attestations = const {},
    this.trustedPackages = const {},
  });

  final DeviceSignals signals;
  final DateTime now;
  final Map<String, Attestation> attestations;

  /// Packages the user has reviewed and deliberately allowed to keep an
  /// elevated permission, such as a password manager using accessibility.
  final Set<String> trustedPackages;
}

/// The check catalog: every security property the app knows how to judge, and
/// the rule that judges it.
///
/// Checks are declared once and evaluated against whatever the OS reported.
/// A check whose signal the platform withheld reports
/// [CheckStatus.unavailable] and drops out of the score rather than being
/// guessed at, which is why the number can be trusted.
abstract final class Catalog {
  static List<Finding> evaluate(EvalContext ctx) {
    final findings = <Finding>[];
    for (final rule in _rules) {
      if (!rule.applies(ctx.signals)) continue;
      findings.add(rule.evaluate(ctx, rule.check));
    }
    findings.sort(_byUrgency);
    return List.unmodifiable(findings);
  }

  /// Every check the app ships, regardless of platform. Used by the reference
  /// list in Settings and by tests.
  static List<Check> get allChecks =>
      List.unmodifiable(_rules.map((r) => r.check));

  static Check? checkById(String id) {
    for (final rule in _rules) {
      if (rule.check.id == id) return rule.check;
    }
    return null;
  }

  /// Open criticals first, then cautions, then unanswered questions, then
  /// everything that passed. Within a tier, heavier checks come first, so the
  /// top of the list is always the highest-value thing to do next.
  static int _byUrgency(Finding a, Finding b) {
    int tier(Finding f) => switch (f.status) {
          CheckStatus.fail => f.severity.rank,
          CheckStatus.unanswered => 3,
          CheckStatus.pass => 4,
          CheckStatus.unavailable => 5,
        };
    final t = tier(a).compareTo(tier(b));
    if (t != 0) return t;
    final w = b.check.weight.compareTo(a.check.weight);
    if (w != 0) return w;
    return a.check.title.compareTo(b.check.title);
  }
}

typedef _Applies = bool Function(DeviceSignals);
typedef _Evaluate = Finding Function(EvalContext, Check);

@immutable
class _Rule {
  const _Rule(this.check, this.evaluate, {_Applies? applies})
      : applies = applies ?? _always;

  final Check check;
  final _Evaluate evaluate;
  final _Applies applies;

  static bool _always(DeviceSignals _) => true;
}

bool _android(DeviceSignals s) => s.isAndroid;
bool _ios(DeviceSignals s) => s.isIOS;

// ---------------------------------------------------------------------------
// Shared evaluator helpers
// ---------------------------------------------------------------------------

Finding _pass(Check check, String detail, {List<String> evidence = const []}) =>
    Finding(
      check: check,
      status: CheckStatus.pass,
      detail: detail,
      evidence: evidence,
    );

Finding _fail(
  Check check,
  String detail, {
  List<String> evidence = const [],
  Severity? severity,
}) =>
    Finding(
      check: check,
      status: CheckStatus.fail,
      detail: detail,
      evidence: evidence,
      severityOverride: severity,
    );

Finding _unavailable(Check check, String reason) => Finding(
      check: check,
      status: CheckStatus.unavailable,
      detail: reason,
      unavailableReason: reason,
    );

/// Evaluates a boolean signal that may be missing.
Finding _boolean(
  Check check,
  bool? value, {
  required bool want,
  required String pass,
  required String fail,
  Severity? failSeverity,
}) {
  if (value == null) {
    return _unavailable(check, 'This version of the OS does not report it.');
  }
  return value == want ? _pass(check, pass) : _fail(check, fail, severity: failSeverity);
}

/// Evaluates a check the OS will not disclose, against the user's remembered
/// answer.
Finding _attested(
  EvalContext ctx,
  Check check, {
  required String pass,
  required String fail,
}) {
  final record = ctx.attestations[check.id];
  if (record == null || !record.isFresh(ctx.now, check.attestationValidFor)) {
    return Finding(
      check: check,
      status: CheckStatus.unanswered,
      detail: record == null
          ? 'Not confirmed yet.'
          : 'Worth confirming again.',
    );
  }
  return record.answer ? _pass(check, pass) : _fail(check, fail);
}

/// Evaluates a list of apps holding an elevated permission against the set the
/// user has reviewed and allowed.
Finding _privileged(
  EvalContext ctx,
  Check check,
  List<PrivilegedService> services, {
  required String noneDetail,
  required String Function(int count) failDetail,
  required String Function(int count) trustedDetail,
}) {
  if (services.isEmpty) return _pass(check, noneDetail);
  final untrusted = services
      .where((s) => !ctx.trustedPackages.contains(s.package))
      .toList(growable: false);
  final names = services
      .map((s) => ctx.trustedPackages.contains(s.package)
          ? '${s.label}  ·  allowed by you'
          : s.label)
      .toList(growable: false);
  if (untrusted.isEmpty) {
    return _pass(check, trustedDetail(services.length), evidence: names);
  }
  return _fail(check, failDetail(untrusted.length), evidence: names);
}

String _plural(int n, String one, String many) => n == 1 ? one : many;

// ---------------------------------------------------------------------------
// The catalog
// ---------------------------------------------------------------------------

final List<_Rule> _rules = [
  // ------------------------------- Lock ------------------------------------
  _Rule(
    const Check(
      id: 'screen_lock',
      title: 'Screen lock',
      area: CheckArea.lock,
      severity: Severity.critical,
      weight: 14,
      source: CheckSource.measured,
      why: 'Anyone holding your phone gets your messages, your photos, your '
          'email, and every account those can reset. Your code also protects '
          'the key your storage is encrypted with.',
      passSummary: 'A code is required to unlock this phone.',
      failSummary: 'This phone opens without a code.',
      fix: OpenSettings(
        SettingsTarget.screenLock,
        buttonLabel: 'Set a lock code',
        steps: ['Settings', 'Security', 'Screen lock', 'PIN or password'],
      ),
    ),
    (ctx, check) => ctx.signals.hasScreenLock
        ? _pass(check, 'A code is required to unlock.')
        : _fail(check, 'Anyone can open this phone right now.'),
  ),

  _Rule(
    const Check(
      id: 'biometrics',
      title: 'Biometric unlock',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'People with a fingerprint or face set up pick much stronger codes, '
          'because they rarely type them. It also stops the most common attack '
          'there is: someone watching you type.',
      passSummary: 'Biometric unlock is enrolled.',
      failSummary: 'No fingerprint or face is enrolled.',
      fix: OpenSettings(
        SettingsTarget.biometrics,
        buttonLabel: 'Set up biometrics',
        steps: ['Settings', 'Security', 'Fingerprint or Face unlock'],
      ),
    ),
    (ctx, check) {
      final s = ctx.signals;
      if (!s.hasScreenLock) {
        return _unavailable(check, 'Set a lock code first.');
      }
      return s.hasBiometricsEnrolled
          ? _pass(
              check,
              s.biometryLabel.isEmpty
                  ? 'Enrolled.'
                  : '${s.biometryLabel} is enrolled.',
            )
          : _fail(check, 'You type your code every time, so it stays short.');
    },
  ),

  _Rule(
    const Check(
      id: 'passcode_strength',
      title: 'Code length',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.attested,
      attestationQuestion: 'Is your unlock code six digits or longer?',
      why: 'Four digits is ten thousand tries. Six is a million. Letters put it '
          'past anything worth attempting.',
      passSummary: 'Your code is six characters or longer.',
      failSummary: 'A four digit code is guessable in an afternoon.',
      fix: OpenSettings(
        SettingsTarget.screenLock,
        buttonLabel: 'Change your code',
        steps: ['Settings', 'Security', 'Screen lock'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Six characters or longer.',
      fail: 'A short code is guessable in an afternoon.',
    ),
  ),

  _Rule(
    const Check(
      id: 'auto_lock',
      title: 'Locks quickly',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'A lock code protects nothing while your screen sits awake on a '
          'table. Phones ship with a long timeout because it demos well.',
      passSummary: 'The screen locks soon after you stop using it.',
      failSummary: 'The screen stays unlocked for a long time.',
      fix: OpenSettings(
        SettingsTarget.displayTimeout,
        buttonLabel: 'Shorten the timeout',
        steps: ['Settings', 'Display', 'Screen timeout'],
      ),
    ),
    (ctx, check) {
      final ms = ctx.signals.screenLockTimeoutMs;
      if (ms == null || ms <= 0) {
        return _unavailable(check, 'Not reported by this device.');
      }
      final timeout = Duration(milliseconds: ms);
      if (timeout.inSeconds <= 60) {
        return _pass(check, 'Locks after ${Say.span(timeout)}.');
      }
      // "Never" is stored as a value near the integer maximum rather than as a
      // flag, which is why a span beyond a day is read as no timeout at all.
      final label = Say.span(timeout);
      return _fail(
        check,
        label == null
            ? 'The screen never locks itself.'
            : 'Stays unlocked for $label after you stop touching it.',
      );
    },
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'auto_lock_ios',
      title: 'Locks quickly',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.attested,
      attestationQuestion: 'Is Auto-Lock set to 1 minute or less?',
      why: 'A lock code protects nothing while your screen sits awake on a '
          'table.',
      passSummary: 'The screen locks soon after you stop using it.',
      failSummary: 'The screen stays unlocked for a long time.',
      fix: GuidedSteps(
        steps: ['Settings', 'Display & Brightness', 'Auto-Lock', '1 Minute'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Auto-Lock is one minute or less.',
      fail: 'The screen stays unlocked long after you put it down.',
    ),
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'lockscreen_privacy',
      title: 'Lock screen previews',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'With previews on, your bank codes are readable on a locked screen. '
          'That is enough to reset accounts without ever unlocking the phone.',
      passSummary: 'Notification contents are hidden until you unlock.',
      failSummary: 'Message and code contents show on the locked screen.',
      fix: OpenSettings(
        SettingsTarget.lockScreenNotifications,
        buttonLabel: 'Hide sensitive content',
        steps: [
          'Settings',
          'Notifications',
          'Notifications on lock screen',
          'Hide sensitive content',
        ],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.lockScreenShowsSensitiveContent,
      want: false,
      pass: 'Contents stay hidden until you unlock.',
      fail: 'One-time codes are readable without unlocking.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'lockscreen_privacy_ios',
      title: 'Lock screen previews',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.attested,
      attestationQuestion: 'Are notification previews set to "When Unlocked"?',
      why: 'With previews on, your bank codes are readable on a locked screen. '
          'That is enough to reset accounts without ever unlocking the phone.',
      passSummary: 'Previews only appear once you have unlocked.',
      failSummary: 'One-time codes are readable on the locked screen.',
      fix: GuidedSteps(
        steps: ['Settings', 'Notifications', 'Show Previews', 'When Unlocked'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Previews appear only once unlocked.',
      fail: 'One-time codes are readable without unlocking.',
    ),
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'stolen_device_protection',
      title: 'Stolen Device Protection',
      area: CheckArea.lock,
      severity: Severity.critical,
      weight: 10,
      source: CheckSource.attested,
      attestationQuestion: 'Is Stolen Device Protection turned on?',
      why: 'The most valuable switch on an iPhone, and it is off by default. '
          'Without it, a thief who watched you type your passcode can change '
          'your Apple Account password and lock you out in a minute. With it '
          'on, that needs your face and an hour of waiting.',
      passSummary: 'A thief who knows your passcode still cannot take over.',
      failSummary: 'Your passcode alone is enough to take over your Apple Account.',
      fix: GuidedSteps(
        steps: [
          'Settings',
          'Face ID & Passcode',
          'Stolen Device Protection',
          'Turn On',
        ],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Passcode alone cannot take over your account.',
      fail: 'Someone who watched you type your passcode could lock you out.',
    ),
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'lockscreen_access',
      title: 'Access while locked',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.attested,
      attestationQuestion:
          'Is Control Centre and Wallet access disabled while locked?',
      why: 'Control Centre on a locked phone lets a thief turn on Aeroplane '
          'Mode, cutting it off the network before you can find or erase it.',
      passSummary: 'A locked phone cannot be put into Aeroplane Mode.',
      failSummary: 'A thief can cut your phone off the network while it is locked.',
      fix: GuidedSteps(
        steps: [
          'Settings',
          'Face ID & Passcode',
          'Allow Access When Locked',
          'Turn off Control Centre',
        ],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'A locked phone cannot be cut off the network.',
      fail: 'A thief can go straight to Aeroplane Mode from your lock screen.',
    ),
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'sim_pin',
      title: 'SIM lock',
      area: CheckArea.lock,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.attested,
      attestationQuestion: 'Is a SIM PIN set on your phone number?',
      why: 'Almost nobody sets this. Without it a thief moves your SIM into '
          'their phone and starts getting your codes, even though your phone is '
          'locked.',
      passSummary: 'Your SIM cannot be moved to another phone.',
      failSummary: 'Your number can be moved to another phone and used to get codes.',
      fix: GuidedSteps(
        steps: ['Settings', 'Network & SIM', 'SIM lock', 'Lock SIM card'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Your SIM is locked to this phone.',
      fail: 'Your number could be moved into a thief\'s phone.',
    ),
  ),

  // ----------------------------- Software ----------------------------------
  _Rule(
    const Check(
      id: 'os_supported',
      title: 'Supported OS version',
      area: CheckArea.software,
      severity: Severity.critical,
      weight: 10,
      source: CheckSource.measured,
      why: 'Once a version stops getting security fixes, every flaw found from '
          'then on stays open for good. No setting works around it.',
      passSummary: 'Your OS version still receives security fixes.',
      failSummary: 'Your OS version no longer receives security fixes.',
      fix: OpenSettings(
        SettingsTarget.systemUpdate,
        buttonLabel: 'Check for updates',
        steps: ['Settings', 'System', 'System update'],
      ),
    ),
    (ctx, check) {
      final s = ctx.signals;
      if (s.osMajor == 0 || s.minimumSupportedOsMajor == 0) {
        return _unavailable(check, 'Could not read the OS version.');
      }
      final name = s.isIOS ? 'iOS' : 'Android';
      return s.osMajor >= s.minimumSupportedOsMajor
          ? _pass(check, '$name ${s.osVersion} still receives security fixes.')
          : _fail(
              check,
              '$name ${s.osVersion} stopped receiving security fixes.',
            );
    },
  ),

  _Rule(
    const Check(
      id: 'patch_age',
      title: 'Security patch level',
      area: CheckArea.software,
      severity: Severity.caution,
      weight: 10,
      source: CheckSource.measured,
      why: 'Android ships fixes monthly, apart from the version number. A phone '
          'can say it is up to date and still be missing a year of patches, '
          'because the maker never sent them.',
      passSummary: 'Your security patches are recent.',
      failSummary: 'Your phone is missing months of security patches.',
      fix: OpenSettings(
        SettingsTarget.systemUpdate,
        buttonLabel: 'Check for updates',
        steps: ['Settings', 'System', 'System update'],
      ),
    ),
    (ctx, check) {
      final days = ctx.signals.patchAgeInDays(ctx.now);
      if (days == null) {
        return _unavailable(check, 'This device does not report a patch level.');
      }
      final months = (days / 30).floor();
      if (days <= 100) {
        return _pass(
          check,
          days <= 35
              ? 'Patched within the last month.'
              : 'Patched $months ${_plural(months, "month", "months")} ago.',
        );
      }
      return _fail(
        check,
        'Missing $months ${_plural(months, "month", "months")} of security patches.',
        severity: days > 365 ? Severity.critical : Severity.caution,
      );
    },
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'os_current',
      title: 'Latest iOS',
      area: CheckArea.software,
      severity: Severity.caution,
      weight: 8,
      source: CheckSource.measured,
      why: 'Apple ships security fixes inside iOS releases. A version behind '
          'means the flaws listed in public release notes are still open on '
          'your phone, and those notes are what attackers read.',
      passSummary: 'You are on the current major version of iOS.',
      failSummary: 'You are behind on iOS.',
      fix: GuidedSteps(steps: ['Settings', 'General', 'Software Update']),
    ),
    (ctx, check) {
      final s = ctx.signals;
      if (s.osMajor == 0 || s.latestKnownOsMajor == 0) {
        return _unavailable(check, 'Could not read the OS version.');
      }
      if (s.osMajor >= s.latestKnownOsMajor) {
        return _pass(check, 'iOS ${s.osVersion} is current.');
      }
      final behind = s.latestKnownOsMajor - s.osMajor;
      return _fail(
        check,
        '$behind major ${_plural(behind, "version", "versions")} behind.',
        severity: behind > 1 ? Severity.critical : Severity.caution,
      );
    },
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'auto_updates',
      title: 'Automatic updates',
      area: CheckArea.software,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.attested,
      attestationQuestion: 'Are automatic system updates turned on?',
      why: 'The gap between a fix shipping and you installing it is the window '
          'attackers use. Automatic updates close it while you sleep.',
      passSummary: 'Updates install themselves.',
      failSummary: 'Updates wait for you to notice them.',
      fix: OpenSettings(
        SettingsTarget.systemUpdate,
        buttonLabel: 'Open update settings',
        steps: ['Settings', 'System', 'System update', 'Auto-update'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'Updates install themselves.',
      fail: 'Fixes sit uninstalled until you notice them.',
    ),
  ),

  // -------------------------- Device integrity -----------------------------
  _Rule(
    const Check(
      id: 'device_integrity',
      title: 'Device integrity',
      area: CheckArea.integrity,
      severity: Severity.critical,
      weight: 12,
      source: CheckSource.measured,
      why: 'Rooting or jailbreaking removes the wall between apps. One bad app '
          'can then read every other app, including your bank. If you did not '
          'do this on purpose, treat it as a break-in.',
      passSummary: 'The OS security model is intact.',
      failSummary: 'The wall between apps has been removed.',
      fix: GuidedSteps(
        steps: [
          'Back up anything you cannot lose',
          'Factory reset the phone',
          'Restore from a backup made before this started',
        ],
      ),
    ),
    (ctx, check) {
      final s = ctx.signals;
      if (!s.isCompromised) {
        return _pass(check, 'No signs of rooting or jailbreaking.');
      }
      return _fail(
        check,
        s.isIOS ? 'This phone appears jailbroken.' : 'This phone appears rooted.',
        evidence: s.compromiseReasons,
      );
    },
  ),

  _Rule(
    const Check(
      id: 'storage_encryption',
      title: 'Storage encryption',
      area: CheckArea.integrity,
      severity: Severity.critical,
      weight: 8,
      source: CheckSource.measured,
      why: 'Encryption is what makes a stolen phone a paperweight instead of a '
          'filing cabinet. Without it the storage is read directly, lock screen '
          'or not.',
      passSummary: 'Your storage is encrypted.',
      failSummary: 'Your storage can be read without your code.',
      fix: OpenSettings(
        SettingsTarget.security,
        buttonLabel: 'Open security settings',
        steps: ['Settings', 'Security', 'Encryption'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.storageEncrypted,
      want: true,
      pass: 'Encrypted at rest.',
      fail: 'Your files can be read straight off the storage.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'usb_debugging',
      title: 'USB debugging',
      area: CheckArea.integrity,
      severity: Severity.critical,
      weight: 8,
      source: CheckSource.measured,
      why: 'USB debugging lets a computer run commands on your phone and pull '
          'app data off it. A public charging port is enough. It is for '
          'developers and should never be left on.',
      passSummary: 'USB debugging is off.',
      failSummary: 'A computer plugged in could take control of this phone.',
      fix: OpenSettings(
        SettingsTarget.developerOptions,
        buttonLabel: 'Turn off USB debugging',
        steps: ['Settings', 'System', 'Developer options', 'USB debugging'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.usbDebuggingEnabled,
      want: false,
      pass: 'Off.',
      fail: 'On. A plugged-in computer could pull your app data.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'developer_options',
      title: 'Developer options',
      area: CheckArea.integrity,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.measured,
      why: 'Developer options unlock a drawer of switches that weaken the phone, '
          'and scam callers talk people into them every day. If you are not '
          'building apps, turn it off.',
      passSummary: 'Developer options are off.',
      failSummary: 'Developer options are enabled.',
      fix: OpenSettings(
        SettingsTarget.developerOptions,
        buttonLabel: 'Turn them off',
        steps: ['Settings', 'System', 'Developer options', 'Off'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.developerOptionsEnabled,
      want: false,
      pass: 'Off.',
      fail: 'Enabled. Turn them off unless you are building apps.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'debugger',
      title: 'Debugger attached',
      area: CheckArea.integrity,
      severity: Severity.caution,
      weight: 3,
      source: CheckSource.measured,
      why: 'A debugger can read everything a running app holds in memory. On a '
          'phone nobody is developing on, this should never be true.',
      passSummary: 'No debugger is attached.',
      failSummary: 'Something is inspecting this app as it runs.',
      fix: GuidedSteps(
        steps: [
          'Unplug the phone from any computer',
          'Restart the phone',
          'Run the check again',
        ],
      ),
    ),
    (ctx, check) => ctx.signals.debuggerAttached
        ? _fail(check, 'Something is inspecting this app as it runs.')
        : _pass(check, 'Nothing is inspecting this app.'),
  ),

  _Rule(
    const Check(
      id: 'screen_capture',
      title: 'Screen not being watched',
      area: CheckArea.integrity,
      severity: Severity.caution,
      weight: 3,
      source: CheckSource.measured,
      why: 'If your screen is recorded or mirrored, everything you type goes '
          'wherever that stream goes. Worth knowing before you open a bank app.',
      passSummary: 'Nothing is recording or mirroring your screen.',
      failSummary: 'Your screen is being recorded or mirrored right now.',
      fix: GuidedSteps(
        steps: [
          'Open Control Centre or the quick settings panel',
          'Stop any screen recording or cast',
          'Run the check again',
        ],
      ),
    ),
    (ctx, check) => ctx.signals.screenBeingCaptured
        ? _fail(check, 'Your screen is being recorded or mirrored right now.')
        : _pass(check, 'Nothing is recording or mirroring your screen.'),
  ),

  // ------------------------------ App reach --------------------------------
  _Rule(
    const Check(
      id: 'accessibility_services',
      title: 'Apps reading your screen',
      area: CheckArea.apps,
      severity: Severity.critical,
      weight: 8,
      source: CheckSource.measured,
      why: 'An accessibility service sees every word on your screen and can tap '
          'for you. It is what banking malware asks for, because it is the one '
          'permission that gets everything at once.',
      passSummary: 'Nothing unexpected can read your screen.',
      failSummary: 'An app can read everything on your screen and tap for you.',
      fix: OpenSettings(
        SettingsTarget.accessibility,
        buttonLabel: 'Review these apps',
        steps: ['Settings', 'Accessibility', 'Downloaded apps'],
      ),
    ),
    (ctx, check) => _privileged(
      ctx,
      check,
      ctx.signals.accessibilityServices,
      noneDetail: 'No app can read your screen.',
      failDetail: (n) =>
          '$n ${_plural(n, "app", "apps")} can read everything on your screen.',
      trustedDetail: (n) =>
          '$n reviewed ${_plural(n, "app", "apps")}, all allowed by you.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'notification_access',
      title: 'Apps reading notifications',
      area: CheckArea.apps,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'The app reads every notification you get, including the one-time '
          'codes your bank sends. That is enough to take over an account '
          'without your password.',
      passSummary: 'Nothing unexpected reads your notifications.',
      failSummary: 'An app reads every notification, including your codes.',
      fix: OpenSettings(
        SettingsTarget.notificationAccess,
        buttonLabel: 'Review these apps',
        steps: ['Settings', 'Notifications', 'Device & app notifications'],
      ),
    ),
    (ctx, check) => _privileged(
      ctx,
      check,
      ctx.signals.notificationListeners,
      noneDetail: 'No app reads your notifications.',
      failDetail: (n) =>
          '$n ${_plural(n, "app", "apps")} ${_plural(n, "reads", "read")} every notification, including codes.',
      trustedDetail: (n) =>
          '$n reviewed ${_plural(n, "app", "apps")}, all allowed by you.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'device_admins',
      title: 'Apps with admin control',
      area: CheckArea.apps,
      severity: Severity.caution,
      weight: 6,
      source: CheckSource.measured,
      why: 'A device administrator can lock you out, wipe the phone, or refuse '
          'to be uninstalled. Stalkerware asks for it so you cannot remove it.',
      passSummary: 'No app holds administrator control.',
      failSummary: 'An app can wipe or lock this phone and resist removal.',
      fix: OpenSettings(
        SettingsTarget.deviceAdmins,
        buttonLabel: 'Review admin apps',
        steps: ['Settings', 'Security', 'Device admin apps'],
      ),
    ),
    (ctx, check) => _privileged(
      ctx,
      check,
      ctx.signals.deviceAdmins,
      noneDetail: 'No app holds administrator control.',
      failDetail: (n) =>
          '$n ${_plural(n, "app", "apps")} can wipe or lock this phone.',
      trustedDetail: (n) =>
          '$n reviewed ${_plural(n, "app", "apps")}, all allowed by you.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'unknown_sources',
      title: 'Apps from outside the store',
      area: CheckArea.apps,
      severity: Severity.caution,
      weight: 6,
      source: CheckSource.attested,
      attestationQuestion:
          'Is "Install unknown apps" switched off for every app?',
      why: 'Almost every piece of Android malware arrives as a file someone '
          'talked you into opening. With this off, a tapped link cannot install '
          'anything, no matter how convincing the page looks. Android only lets '
          'an app see its own setting here and never another app’s, so this '
          'one needs your eyes on the list.',
      passSummary: 'Outside apps cannot install themselves.',
      failSummary: 'An app is allowed to install other apps.',
      fix: OpenSettings(
        SettingsTarget.unknownAppSources,
        buttonLabel: 'Open the list',
        steps: ['Settings', 'Apps', 'Special access', 'Install unknown apps'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'No app can install other apps.',
      fail: 'At least one app can install other apps without the store.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'play_protect',
      title: 'Play Protect',
      area: CheckArea.apps,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'Play Protect scans the apps already on your phone, not just new '
          'ones. Malware asks people to switch it off as a first step.',
      passSummary: 'Play Protect is scanning your apps.',
      failSummary: 'Play Protect has been switched off.',
      fix: OpenSettings(
        SettingsTarget.playProtect,
        buttonLabel: 'Turn Play Protect on',
        steps: ['Play Store', 'Profile', 'Play Protect', 'Settings'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.playProtectEnabled,
      want: true,
      pass: 'Scanning your apps.',
      fail: 'Switched off. Malware asks users to do this.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'account_2fa',
      title: 'Two-factor sign-in',
      area: CheckArea.apps,
      severity: Severity.critical,
      weight: 8,
      source: CheckSource.attested,
      attestationQuestion:
          'Is two-factor authentication on for your Google or Apple Account?',
      why: 'Your phone account is the master key. Whoever has it can find your '
          'phone, read your backups, reset your other accounts and wipe your '
          'devices. A password alone stopped being enough a decade ago.',
      passSummary: 'Your account needs a second factor.',
      failSummary: 'One leaked password would open everything.',
      fix: GuidedSteps(
        steps: [
          'Open your account settings',
          'Security',
          'Two-step or two-factor authentication',
          'Turn it on',
        ],
        learnMoreUrl: 'https://www.google.com/landing/2step/',
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'A second factor is required.',
      fail: 'One leaked password would open everything.',
    ),
  ),

  // ------------------------------- Network ---------------------------------
  _Rule(
    const Check(
      id: 'open_wifi',
      title: 'Wi-Fi network',
      area: CheckArea.network,
      severity: Severity.caution,
      weight: 5,
      source: CheckSource.measured,
      why: 'On an open network everyone nearby is on the same wire as you. Most '
          'traffic is encrypted now, but which sites you visit is not.',
      passSummary: 'You are on an encrypted network.',
      failSummary: 'You are on an open Wi-Fi network.',
      fix: OpenSettings(
        SettingsTarget.wifi,
        buttonLabel: 'Open Wi-Fi settings',
        steps: ['Settings', 'Wi-Fi'],
      ),
    ),
    (ctx, check) {
      final open = ctx.signals.onOpenWifi;
      if (open == null) {
        return _unavailable(check, 'Not on Wi-Fi, or the network is not readable.');
      }
      return open
          ? _fail(check, 'This network has no password, so nothing is protected.')
          : _pass(check, 'This network is encrypted.');
    },
  ),

  _Rule(
    const Check(
      id: 'encrypted_dns',
      title: 'Encrypted DNS',
      area: CheckArea.network,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.measured,
      why: 'Without it, the name of every site you open is sent in the clear, '
          'readable by your network and anyone on it, even when the pages '
          'themselves are encrypted.',
      passSummary: 'The sites you visit are not broadcast in the clear.',
      failSummary: 'Every site you visit is visible to your network.',
      fix: OpenSettings(
        SettingsTarget.privateDns,
        buttonLabel: 'Turn on Private DNS',
        steps: ['Settings', 'Network & internet', 'Private DNS', 'Automatic'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.encryptedDnsEnabled,
      want: true,
      pass: 'On.',
      fail: 'Off. Every site you visit is named in the clear.',
    ),
    applies: _android,
  ),

  // ------------------------------ Recovery ---------------------------------
  _Rule(
    const Check(
      id: 'find_my_device',
      title: 'Find My Device',
      area: CheckArea.recovery,
      severity: Severity.caution,
      weight: 6,
      source: CheckSource.attested,
      attestationQuestion: 'Can you locate and erase this phone remotely?',
      why: 'The five minutes after you lose a phone are the ones that matter, '
          'and they are not the time to find out this was never on. It also '
          'lets you wipe it, which turns a breach back into a lost object.',
      passSummary: 'You can find and erase this phone remotely.',
      failSummary: 'A lost phone would be gone, with its contents.',
      fix: OpenSettings(
        SettingsTarget.findMyDevice,
        buttonLabel: 'Set it up',
        steps: ['Settings', 'Security', 'Find My Device'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'You can locate and erase it remotely.',
      fail: 'A lost phone would be gone, with everything on it.',
    ),
  ),

  _Rule(
    const Check(
      id: 'cloud_backup',
      title: 'Backup',
      area: CheckArea.recovery,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.measured,
      why: 'Backup is a security control, not a convenience. Without one, the '
          'safe answer to malware or theft is one you cannot afford, so people '
          'keep using a phone they know is compromised.',
      passSummary: 'Your phone is backed up.',
      failSummary: 'Wiping this phone would mean losing everything on it.',
      fix: OpenSettings(
        SettingsTarget.backup,
        buttonLabel: 'Turn on backup',
        steps: ['Settings', 'System', 'Backup'],
      ),
    ),
    (ctx, check) => _boolean(
      check,
      ctx.signals.cloudBackupEnabled,
      want: true,
      pass: 'On.',
      fail: 'Off. You could not safely wipe this phone if you had to.',
    ),
    applies: _android,
  ),

  _Rule(
    const Check(
      id: 'cloud_backup_ios',
      title: 'Backup',
      area: CheckArea.recovery,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.attested,
      attestationQuestion: 'Is iCloud Backup turned on?',
      why: 'Backup is a security control. Without one, the safe answer to '
          'malware or theft is one you cannot afford.',
      passSummary: 'Your phone is backed up.',
      failSummary: 'Wiping this phone would mean losing everything on it.',
      fix: GuidedSteps(
        steps: ['Settings', 'Your name', 'iCloud', 'iCloud Backup', 'On'],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'iCloud Backup is on.',
      fail: 'You could not safely wipe this phone if you had to.',
    ),
    applies: _ios,
  ),

  _Rule(
    const Check(
      id: 'recovery_contact',
      title: 'Account recovery',
      area: CheckArea.recovery,
      severity: Severity.caution,
      weight: 4,
      source: CheckSource.attested,
      attestationQuestion:
          'Do you have recovery codes or a recovery contact saved somewhere off this phone?',
      why: 'Two-factor locks attackers out, and locks you out just as hard if '
          'your only factor was the phone you lost. Codes kept somewhere else '
          'are the difference between a bad day and losing the account.',
      passSummary: 'You can get back in without this phone.',
      failSummary: 'Losing this phone would lock you out of your own account.',
      fix: GuidedSteps(
        steps: [
          'Open your account security settings',
          'Find backup or recovery codes',
          'Save them somewhere that is not this phone',
        ],
      ),
    ),
    (ctx, check) => _attested(
      ctx,
      check,
      pass: 'You can get back in without this phone.',
      fail: 'Losing this phone would lock you out of your account too.',
    ),
  ),
];
