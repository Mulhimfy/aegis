import 'package:aegis/data/prefs/store.dart';
import 'package:aegis/domain/score.dart';
import 'package:aegis/features/share/milestone.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityScore scoreOf(int value, {int critical = 0, int caution = 0}) =>
    SecurityScore(
      value: value,
      band: critical > 0
          ? ScoreBand.atRisk
          : (value >= 90 ? ScoreBand.solid : ScoreBand.exposed),
      criticalCount: critical,
      cautionCount: caution,
      passedCount: 10,
      scoredCount: 12,
      unansweredCount: 0,
      pointsAvailable: 100 - value,
    );

ScanRecord recordOf(int value, {int critical = 0}) => ScanRecord(
      at: DateTime.utc(2026, 7, 1),
      score: value,
      criticalCount: critical,
      cautionCount: 0,
    );

void main() {
  group('milestones', () {
    test('nothing is claimed when nothing happened', () {
      final milestone = Milestone.detect(
        score: scoreOf(78, caution: 3),
        previous: recordOf(77),
        bestEver: 80,
        alreadyCelebrated: const {},
      );
      expect(milestone, isNull);
    });

    test('a real jump is worth mentioning', () {
      final milestone = Milestone.detect(
        score: scoreOf(88, caution: 1),
        previous: recordOf(70),
        bestEver: 70,
        alreadyCelebrated: const {},
      );
      expect(milestone, isNotNull);
      expect(milestone!.headline, 'Up 18 points');
    });

    test('a perfect score outranks everything else', () {
      final milestone = Milestone.detect(
        score: scoreOf(100),
        previous: recordOf(70),
        bestEver: 70,
        alreadyCelebrated: const {},
      );
      expect(milestone!.id, 'perfect');
    });

    test('a one-off milestone is never celebrated twice', () {
      final milestone = Milestone.detect(
        score: scoreOf(100),
        previous: null,
        bestEver: 100,
        alreadyCelebrated: const {'perfect', 'first_90'},
      );
      expect(milestone, isNull);
    });

    test('clearing the last critical is its own moment', () {
      final milestone = Milestone.detect(
        score: scoreOf(86, caution: 2),
        previous: recordOf(80, critical: 1),
        bestEver: 86,
        alreadyCelebrated: const {'criticals_cleared'},
      );
      expect(milestone!.id, 'criticals_cleared',
          reason: 'a repeatable milestone must be able to fire again');
    });

    test('the first time into the top band counts, later times do not', () {
      final first = Milestone.detect(
        score: scoreOf(92),
        previous: recordOf(89),
        bestEver: 89,
        alreadyCelebrated: const {},
      );
      expect(first!.id, 'first_90');

      final again = Milestone.detect(
        score: scoreOf(92),
        previous: recordOf(91),
        bestEver: 95,
        alreadyCelebrated: const {'first_90'},
      );
      expect(again, isNull);
    });
  });

  group('share prompt', () {
    final now = DateTime.utc(2026, 8, 12);
    const milestone = Milestone(
      id: 'x',
      headline: 'h',
      body: 'b',
      shareLabel: 's',
      repeatable: true,
    );

    test('never asks without a reason', () {
      expect(
        SharePrompt.shouldOffer(milestone: null, lastPrompted: null, now: now),
        isFalse,
      );
    });

    test('asks the first time something happens', () {
      expect(
        SharePrompt.shouldOffer(
            milestone: milestone, lastPrompted: null, now: now),
        isTrue,
      );
    });

    test('will not ask twice in the same week', () {
      expect(
        SharePrompt.shouldOffer(
          milestone: milestone,
          lastPrompted: now.subtract(const Duration(days: 3)),
          now: now,
        ),
        isFalse,
      );
    });

    test('asks again once the cooldown has passed', () {
      expect(
        SharePrompt.shouldOffer(
          milestone: milestone,
          lastPrompted: now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
