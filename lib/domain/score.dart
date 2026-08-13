import 'package:flutter/foundation.dart';

import 'finding.dart';
import 'severity.dart';

/// The band a score falls into. Bands, not raw numbers, decide the colour and
/// the headline, so an 88 and a 91 do not feel like different worlds.
enum ScoreBand {
  solid('Solid', 'Your phone is in good shape.'),
  exposed('Exposed', 'A few gaps are worth closing.'),
  atRisk('At risk', 'Something important is open right now.');

  const ScoreBand(this.label, this.headline);
  final String label;
  final String headline;
}

/// A computed security score with everything needed to explain it.
@immutable
class SecurityScore {
  const SecurityScore({
    required this.value,
    required this.band,
    required this.criticalCount,
    required this.cautionCount,
    required this.passedCount,
    required this.scoredCount,
    required this.unansweredCount,
    required this.pointsAvailable,
  });

  /// 0 to 100.
  final int value;
  final ScoreBand band;
  final int criticalCount;
  final int cautionCount;
  final int passedCount;

  /// How many checks actually counted, after excluding ones the platform will
  /// not disclose.
  final int scoredCount;

  final int unansweredCount;

  /// Points the user could still win back by fixing what is open.
  final int pointsAvailable;

  bool get isPerfect => value >= 100;
  int get issueCount => criticalCount + cautionCount;

  /// The highest a phone with an open critical can score. Chosen to sit clear
  /// of the top band rather than to be a round number.
  static const int _criticalCeiling = 74;

  static const SecurityScore empty = SecurityScore(
    value: 0,
    band: ScoreBand.exposed,
    criticalCount: 0,
    cautionCount: 0,
    passedCount: 0,
    scoredCount: 0,
    unansweredCount: 0,
    pointsAvailable: 0,
  );

  /// Weighted pass ratio over the checks that apply to this device.
  ///
  /// Weights are normalised against what was actually measurable, so a phone
  /// that hides half its signals is still scored out of 100 and two devices
  /// stay comparable.
  ///
  /// An open critical scales the whole result into the at-risk range, because
  /// a phone with no lock screen is not a 92 no matter what else passes.
  /// Scaling rather than clamping keeps the ordering intact: two criticals
  /// still score below one, which a flat ceiling would hide.
  factory SecurityScore.from(Iterable<Finding> findings) {
    var totalWeight = 0;
    var earnedWeight = 0;
    var critical = 0;
    var caution = 0;
    var passed = 0;
    var scored = 0;
    var unanswered = 0;
    var recoverable = 0;

    for (final finding in findings) {
      if (finding.needsAnswer && finding.check.countsTowardScore) unanswered++;
      if (!finding.inScope) continue;
      scored++;
      totalWeight += finding.check.weight;
      if (finding.isPass) {
        earnedWeight += finding.check.weight;
        passed++;
      } else {
        recoverable += finding.check.weight;
        switch (finding.severity) {
          case Severity.critical:
            critical++;
          case Severity.caution:
            caution++;
        }
      }
    }

    if (totalWeight == 0) return SecurityScore.empty;

    final raw = 100 * earnedWeight / totalWeight;
    final value =
        (critical > 0 ? raw * _criticalCeiling / 100 : raw).round().clamp(0, 100);

    final band = switch (value) {
      _ when critical > 0 => ScoreBand.atRisk,
      >= 90 => ScoreBand.solid,
      _ => ScoreBand.exposed,
    };

    return SecurityScore(
      value: value,
      band: band,
      criticalCount: critical,
      cautionCount: caution,
      passedCount: passed,
      scoredCount: scored,
      unansweredCount: unanswered,
      pointsAvailable: totalWeight == 0
          ? 0
          : (100 * recoverable / totalWeight).round(),
    );
  }

  /// What fixing one finding would be worth, in score points.
  static int pointsFor(Finding finding, Iterable<Finding> all) {
    final totalWeight = all
        .where((f) => f.inScope)
        .fold<int>(0, (sum, f) => sum + f.check.weight);
    if (totalWeight == 0 || !finding.inScope) return 0;
    return (100 * finding.check.weight / totalWeight).round().clamp(1, 100);
  }
}
