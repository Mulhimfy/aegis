import 'package:aegis/domain/catalog.dart';
import 'package:aegis/domain/finding.dart';
import 'package:aegis/domain/severity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

Finding find(List<Finding> findings, String id) =>
    findings.firstWhere((f) => f.check.id == id);

bool has(List<Finding> findings, String id) =>
    findings.any((f) => f.check.id == id);

void main() {
  group('catalog', () {
    test('every check id is unique', () {
      final ids = Catalog.allChecks.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every check explains itself in plain language', () {
      for (final check in Catalog.allChecks) {
        expect(check.why, isNotEmpty, reason: '${check.id} has no reason');
        expect(check.why.length, greaterThan(60),
            reason: '${check.id} explains too little to persuade anyone');
        expect(check.passSummary, isNotEmpty);
        expect(check.failSummary, isNotEmpty);
      }
    });

    test('every attested check asks an answerable question', () {
      for (final check in Catalog.allChecks) {
        if (check.source.name != 'attested') continue;
        expect(check.attestationQuestion, isNotNull, reason: check.id);
        expect(check.attestationQuestion, endsWith('?'), reason: check.id);
      }
    });

    test('android-only checks do not appear on iOS', () {
      final ios = Catalog.evaluate(
        EvalContext(signals: Fixtures.iosHealthy(), now: Fixtures.now),
      );
      for (final id in const [
        'usb_debugging',
        'developer_options',
        'play_protect',
        'storage_encryption',
        'accessibility_services',
        'patch_age',
      ]) {
        expect(has(ios, id), isFalse, reason: '$id leaked onto iOS');
      }
    });

    test('iOS-only checks do not appear on Android', () {
      final android = Catalog.evaluate(
        EvalContext(signals: Fixtures.androidHealthy(), now: Fixtures.now),
      );
      for (final id in const [
        'stolen_device_protection',
        'os_current',
        'lockscreen_access',
      ]) {
        expect(has(android, id), isFalse, reason: '$id leaked onto Android');
      }
    });

    test('exactly one platform variant of a shared concern is evaluated', () {
      final android = Catalog.evaluate(
        EvalContext(signals: Fixtures.androidHealthy(), now: Fixtures.now),
      );
      final ios = Catalog.evaluate(
        EvalContext(signals: Fixtures.iosHealthy(), now: Fixtures.now),
      );

      expect(has(android, 'auto_lock'), isTrue);
      expect(has(android, 'auto_lock_ios'), isFalse);
      expect(has(ios, 'auto_lock_ios'), isTrue);
      expect(has(ios, 'auto_lock'), isFalse);
    });
  });

  group('measured checks', () {
    test('a phone with no lock code fails critically', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(hasScreenLock: false),
        now: Fixtures.now,
      ));
      final lock = find(findings, 'screen_lock');
      expect(lock.status, CheckStatus.fail);
      expect(lock.severity, Severity.critical);
    });

    test('biometrics are held out of the score when there is no lock code', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          hasScreenLock: false,
          hasBiometricsEnrolled: false,
        ),
        now: Fixtures.now,
      ));
      expect(find(findings, 'biometrics').status, CheckStatus.unavailable);
    });

    test('a signal the platform withholds is excluded, not assumed', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(playProtectEnabled: null),
        now: Fixtures.now,
      ));
      final play = find(findings, 'play_protect');
      expect(play.status, CheckStatus.unavailable);
      expect(play.inScope, isFalse);
    });

    test('patch age escalates to critical past a year', () {
      final stale = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          securityPatch: Fixtures.now.subtract(const Duration(days: 400)),
        ),
        now: Fixtures.now,
      ));
      final patch = find(stale, 'patch_age');
      expect(patch.status, CheckStatus.fail);
      expect(patch.severity, Severity.critical);
      expect(patch.detail, contains('13 months'));
    });

    test('patch age six months old is a caution, not a crisis', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          securityPatch: Fixtures.now.subtract(const Duration(days: 180)),
        ),
        now: Fixtures.now,
      ));
      expect(find(findings, 'patch_age').severity, Severity.caution);
    });

    test('an unsupported OS version fails', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(osMajor: 11),
        now: Fixtures.now,
      ));
      expect(find(findings, 'os_supported').status, CheckStatus.fail);
    });

    test('a long screen timeout is reported in the user\'s own units', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(screenLockTimeoutMs: 600000),
        now: Fixtures.now,
      ));
      final auto = find(findings, 'auto_lock');
      expect(auto.status, CheckStatus.fail);
      expect(auto.detail, contains('10 minutes'));
    });
  });

  group('privileged apps', () {
    test('an unreviewed accessibility service is a critical finding', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          accessibilityServices: [Fixtures.unknownApp],
        ),
        now: Fixtures.now,
      ));
      final finding = find(findings, 'accessibility_services');
      expect(finding.status, CheckStatus.fail);
      expect(finding.severity, Severity.critical);
      expect(finding.evidence, contains('Free Battery Saver'));
    });

    test('an app the user has reviewed stops counting against them', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          accessibilityServices: [Fixtures.passwordManager],
        ),
        now: Fixtures.now,
        trustedPackages: {Fixtures.passwordManager.package},
      ));
      final finding = find(findings, 'accessibility_services');
      expect(finding.status, CheckStatus.pass);
      expect(finding.evidence.single, contains('allowed by you'));
    });

    test('one reviewed app does not excuse an unreviewed one', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          accessibilityServices: [Fixtures.passwordManager, Fixtures.unknownApp],
        ),
        now: Fixtures.now,
        trustedPackages: {Fixtures.passwordManager.package},
      ));
      final finding = find(findings, 'accessibility_services');
      expect(finding.status, CheckStatus.fail);
      expect(finding.detail, contains('1 app'));
    });
  });

  group('ordering', () {
    test('criticals come first, then cautions, then questions, then passes', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          hasScreenLock: false,
          developerOptionsEnabled: true,
        ),
        now: Fixtures.now,
      ));

      int tier(Finding f) => switch (f.status) {
            CheckStatus.fail => f.severity.rank,
            CheckStatus.unanswered => 3,
            CheckStatus.pass => 4,
            CheckStatus.unavailable => 5,
          };

      for (var i = 1; i < findings.length; i++) {
        expect(
          tier(findings[i - 1]) <= tier(findings[i]),
          isTrue,
          reason: '${findings[i - 1].check.id} ranked above ${findings[i].check.id}',
        );
      }
      expect(findings.first.check.id, 'screen_lock');
    });
  });
}
