import 'package:aegis/domain/attestation.dart';
import 'package:aegis/domain/catalog.dart';
import 'package:aegis/domain/score.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

/// Answers every attested check yes, so a fixture representing a well
/// configured phone can actually reach the top of the scale.
Map<String, Attestation> allYes() => {
      for (final check in Catalog.allChecks)
        check.id: Attestation(answer: true, answeredAt: Fixtures.now),
    };

void main() {
  group('scoring', () {
    test('a fully healthy, fully answered phone scores 100', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(),
        now: Fixtures.now,
        attestations: allYes(),
      ));
      final score = SecurityScore.from(findings);
      expect(score.value, 100);
      expect(score.band, ScoreBand.solid);
      expect(score.criticalCount, 0);
    });

    test('an unanswered question is held out rather than counted as a failure', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(),
        now: Fixtures.now,
      ));
      final score = SecurityScore.from(findings);
      expect(score.unansweredCount, greaterThan(0));
      expect(score.value, 100,
          reason: 'a fresh install must not look like a broken phone');
    });

    test('an expired answer stops counting and is asked again', () {
      final stale = {
        'sim_pin': Attestation(
          answer: true,
          answeredAt: Fixtures.now.subtract(const Duration(days: 200)),
        ),
      };
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(),
        now: Fixtures.now,
        attestations: stale,
      ));
      final simPin = findings.firstWhere((f) => f.check.id == 'sim_pin');
      expect(simPin.needsAnswer, isTrue);
      expect(simPin.detail, 'Worth confirming again.');
    });

    test('one open critical caps the score out of the top band', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(hasScreenLock: false),
        now: Fixtures.now,
        attestations: allYes(),
      ));
      final score = SecurityScore.from(findings);
      expect(score.criticalCount, greaterThan(0));
      expect(score.band, ScoreBand.atRisk);
      expect(score.value, lessThanOrEqualTo(74));
    });

    test('a phone that hides half its signals is still scored out of 100', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(
          playProtectEnabled: null,
          cloudBackupEnabled: null,
          encryptedDnsEnabled: null,
          storageEncrypted: null,
          onOpenWifi: null,
        ),
        now: Fixtures.now,
        attestations: allYes(),
      ));
      final score = SecurityScore.from(findings);
      expect(score.value, 100);
      expect(score.scoredCount, lessThan(Catalog.allChecks.length));
    });

    test('fixing something is worth the points the app promised', () {
      final broken = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(cloudBackupEnabled: false),
        now: Fixtures.now,
        attestations: allYes(),
      ));
      final finding = broken.firstWhere((f) => f.check.id == 'cloud_backup');
      final promised = SecurityScore.pointsFor(finding, broken);

      final fixed = Catalog.evaluate(EvalContext(
        signals: Fixtures.androidHealthy(),
        now: Fixtures.now,
        attestations: allYes(),
      ));

      final gained =
          SecurityScore.from(fixed).value - SecurityScore.from(broken).value;
      expect(gained, closeTo(promised, 1));
    });

    test('an empty finding list does not divide by zero', () {
      expect(SecurityScore.from(const []).value, 0);
    });

    test('worse phones score lower than better ones, monotonically', () {
      int scoreOf({
        bool lock = true,
        bool usb = false,
        bool dev = false,
        bool backup = true,
      }) =>
          SecurityScore.from(Catalog.evaluate(EvalContext(
            signals: Fixtures.androidHealthy(
              hasScreenLock: lock,
              usbDebuggingEnabled: usb,
              developerOptionsEnabled: dev,
              cloudBackupEnabled: backup,
            ),
            now: Fixtures.now,
            attestations: allYes(),
          ))).value;

      final perfect = scoreOf();
      final oneGap = scoreOf(backup: false);
      final twoGaps = scoreOf(backup: false, dev: true);
      final critical = scoreOf(backup: false, dev: true, usb: true);
      final worst = scoreOf(backup: false, dev: true, usb: true, lock: false);

      expect(perfect, greaterThan(oneGap));
      expect(oneGap, greaterThan(twoGaps));
      expect(twoGaps, greaterThan(critical));
      expect(critical, greaterThan(worst));
    });

    test('iOS scores on its own smaller set of checks, still out of 100', () {
      final findings = Catalog.evaluate(EvalContext(
        signals: Fixtures.iosHealthy(),
        now: Fixtures.now,
        attestations: allYes(),
      ));
      final score = SecurityScore.from(findings);
      expect(score.value, 100);
      expect(score.scoredCount, greaterThan(5));
    });
  });
}
